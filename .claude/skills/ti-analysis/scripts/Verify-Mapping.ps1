<#
.SYNOPSIS
    Validates the JSON handoff files against this skill's schema reference.

.DESCRIPTION
    Point it at a subject folder. It validates whichever of analysis.json and mapping.json
    are present, then cross-checks them against each other when both exist.

    A MISSING file is not an error - handoff files only exist when a pipeline run produced
    them, and a skill invoked on its own works from whatever the analyst supplied directly.
    A file that is present and malformed IS an error.

    Structure and vocabulary only. It cannot tell you whether a technique sits under the
    right tactic, or whether the usage text is any good. Those stay human judgment.

    Exit 0 = clean, 1 = at least one failure.

.EXAMPLE
    .\Verify-Mapping.ps1 -Path .\subjects\agrius
    Get-ChildItem .\subjects -Directory | .\Verify-Mapping.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [Alias('FullName')]
    [string[]]$Path
)

begin {
    $ErrorActionPreference = 'Stop'
    $anyFailed = $false
    # Counted so a pipeline that matched nothing cannot report success. A stale glob returns
    # zero folders, process never runs, and without this the script prints "clean" and exits
    # 0 - a validator that passes because it checked nothing is worse than no validator.
    $checked = 0

    $TACTICS = @{
        'enterprise' = @('Reconnaissance','Resource Development','Initial Access','Execution',
                         'Persistence','Privilege Escalation','Stealth','Defense Impairment',
                         'Credential Access','Discovery','Lateral Movement','Collection',
                         'Command and Control','Exfiltration','Impact')
        'ics'        = @('Initial Access','Execution','Persistence','Privilege Escalation',
                         'Evasion','Discovery','Lateral Movement','Collection',
                         'Command and Control','Inhibit Response Function',
                         'Impair Process Control','Impact')
        'mobile'     = @('Initial Access','Execution','Persistence','Privilege Escalation',
                         'Defense Evasion','Credential Access','Discovery','Lateral Movement',
                         'Collection','Command and Control','Exfiltration','Impact')
    }
    $SUBJECT_TYPES = @('actor','vulnerability','campaign')
    $OBJECTIVES    = @('destruction','extortion','espionage','collection','disruption','unknown')
    $RELATIONSHIPS = @('none','exploit-chain','remediation-cascade')
    $CONFIDENCE    = @('published','derived')
    $RISK_LEVELS   = @('critical','high','moderate','low','minimal')

    function Test-Check {
        param([string]$Name, [bool]$Ok, [string]$Detail)
        $mark = if ($Ok) { 'PASS' } else { 'FAIL' }
        $line = "  [{0}] {1}" -f $mark, $Name
        if ($Detail) { $line += " - $Detail" }
        Write-Host $line
        return $Ok
    }

    function Test-Prop {
        param($Obj, [string]$Name)
        if ($null -eq $Obj) { return $false }
        return [bool]($Obj.PSObject.Properties.Name -contains $Name)
    }

    function Get-Val {
        param($Obj, [string]$Name)
        if (Test-Prop $Obj $Name) { return $Obj.$Name }
        return $null
    }

    # Reads an array field as a REAL array. PowerShell wraps $null into a one-element array -
    # @($null).Count is 1, not 0 - so an absent optional field otherwise reads as present with
    # one entry. That fired the CVE cross-field rule on the first subject that legitimately
    # carried no CVEs, reporting "cves present" for a file with no cves key at all. Every
    # array field must be read through this helper, never by array-wrapping Get-Val directly.
    function Get-Arr {
        param($Obj, [string]$Name)
        $v = Get-Val $Obj $Name
        if ($null -eq $v) { return @() }
        return @($v)
    }

    # A subject folder holds its artefacts in subfolders - handoff/ for the JSON, reports/
    # for the rendered halves, bulletin/ for the merged output. Falls back to the subject
    # root so a folder an analyst assembled by hand still validates.
    function Resolve-Artefact {
        param([string]$Dir, [string]$SubDir, [string]$Name)
        $nested = Join-Path (Join-Path $Dir $SubDir) $Name
        if (Test-Path -LiteralPath $nested) { return $nested }
        return (Join-Path $Dir $Name)
    }

    # Reads JSON as UTF8 explicitly. PS 5.1 Get-Content defaults to ANSI, which mangles
    # non-ASCII before ConvertFrom-Json ever sees it.
    function Read-Json {
        param([string]$File)
        $raw = Get-Content -LiteralPath $File -Raw -Encoding UTF8
        return $raw | ConvertFrom-Json
    }
}

process {
    foreach ($p in $Path) {
        if (-not (Test-Path -LiteralPath $p)) { throw "Not found: $p" }
        $checked++
        $item = Get-Item -LiteralPath $p
        $dir  = if ($item.PSIsContainer) { $item.FullName } else { $item.DirectoryName }
        $slug = Split-Path $dir -Leaf

        $aPath = Resolve-Artefact $dir 'handoff' 'analysis.json'
        $mPath = Resolve-Artefact $dir 'handoff' 'mapping.json'
        $aExists = Test-Path -LiteralPath $aPath
        $mExists = Test-Path -LiteralPath $mPath

        Write-Host ""
        Write-Host "=== subjects/$slug ==="

        if (-not $aExists -and -not $mExists) {
            Write-Host "  [SKIP] no handoff files present - nothing to validate"
            continue
        }

        $results = @()
        $analysis = $null
        $mapping  = $null

        # ---------------- analysis.json ----------------
        if ($aExists) {
            $parsed = $true
            try { $analysis = Read-Json $aPath } catch { $parsed = $false }
            $results += Test-Check 'analysis.json is valid JSON' $parsed

            if ($parsed) {
                $req = @('schema','subject','slug','subject_type','matrix','objective','severity','confidence','sources','background','chronology')
                $missing = @($req | Where-Object { -not (Test-Prop $analysis $_) })
                $results += Test-Check 'analysis.json required fields' ($missing.Count -eq 0) $(if ($missing.Count) { "missing: " + ($missing -join ', ') } else { "$($req.Count) present" })

                $st  = Get-Val $analysis 'subject_type'
                $mx  = Get-Val $analysis 'matrix'
                $obj = Get-Val $analysis 'objective'
                $cf  = Get-Val $analysis 'confidence'
                $rel = Get-Val $analysis 'vuln_relationship'
                $sev = Get-Val $analysis 'severity'
                $cves = (Get-Arr $analysis 'cves')

                $bad = @()
                if ($st  -and $SUBJECT_TYPES -notcontains $st)  { $bad += "subject_type '$st'" }
                if ($mx  -and -not $TACTICS.ContainsKey($mx))   { $bad += "matrix '$mx'" }
                if ($obj -and $OBJECTIVES -notcontains $obj)    { $bad += "objective '$obj'" }
                if ($cf  -and $CONFIDENCE -notcontains $cf)     { $bad += "confidence '$cf'" }
                if ($rel -and $RELATIONSHIPS -notcontains $rel) { $bad += "vuln_relationship '$rel'" }
                # severity shares the sector vocabulary on purpose - one scale per document.
                if ($sev -and $RISK_LEVELS -notcontains $sev)     { $bad += "severity '$sev'" }
                $results += Test-Check 'analysis.json values in vocabulary' ($bad.Count -eq 0) $(if ($bad.Count) { $bad -join '; ' })

                $xf = @()
                if ($cves.Count -gt 0 -and -not $rel) { $xf += "cves present but vuln_relationship missing" }
                if ($st -eq 'campaign'      -and $cves.Count -eq 0) { $xf += "campaign with no cves" }
                if ($st -eq 'vulnerability' -and $cves.Count -eq 0) { $xf += "vulnerability with no cves" }
                if ($st -eq 'actor' -and $rel -and $rel -ne 'none') { $xf += "actor declaring vuln_relationship '$rel'" }
                if ($cves.Count -eq 1 -and $rel -and $rel -ne 'none') { $xf += "single CVE cannot be '$rel'" }
                $results += Test-Check 'analysis.json CVE cross-field rules' ($xf.Count -eq 0) $(if ($xf.Count) { $xf -join '; ' } else { "$($cves.Count) CVE(s)" })

                $slugVal = Get-Val $analysis 'slug'
                $results += Test-Check 'analysis.json slug matches folder' ($slugVal -eq $slug) $(if ($slugVal -ne $slug) { "'$slugVal' vs folder '$slug'" })

                $src = (Get-Arr $analysis 'sources')
                $results += Test-Check 'analysis.json has at least one source' ($src.Count -gt 0) "$($src.Count)"

                $bg = (Get-Arr $analysis 'background')
                $bgOk = ($bg.Count -gt 0) -and -not ($bg | Where-Object { [string]::IsNullOrWhiteSpace($_) })
                $results += Test-Check 'analysis.json background is present and non-empty' $bgOk $(if ($bgOk) { "$($bg.Count) paragraph(s)" })

                # chronology: dated evidence, oldest first. The mapping step derives
                # techniques from .detail, so an entry without it breaks the next stage.
                $chron = (Get-Arr $analysis 'chronology')
                $chronBad = @(); $prev = $null; $outOfOrder = $false; $badSrc = @()
                foreach ($c in $chron) {
                    $d = Get-Val $c 'date'
                    if ($d -notmatch '^\d{4}(-\d{2}(-\d{2})?)?$') { $chronBad += "date '$d'" }
                    if ([string]::IsNullOrWhiteSpace((Get-Val $c 'event')))  { $chronBad += "'$d' has no event" }
                    if ([string]::IsNullOrWhiteSpace((Get-Val $c 'detail'))) { $chronBad += "'$d' has no detail" }
                    # zero-padded ISO dates sort chronologically as plain strings
                    if ($null -ne $prev -and $d -lt $prev) { $outOfOrder = $true }
                    $prev = $d
                    foreach ($si in (Get-Arr $c 'sources')) {
                        if ($si -isnot [int] -or $si -lt 0 -or $si -ge $src.Count) { $badSrc += "$si (in '$d')" }
                    }
                }
                $results += Test-Check 'analysis.json chronology entries well formed' ($chronBad.Count -eq 0) $(if ($chronBad.Count) { ($chronBad | Select-Object -Unique) -join '; ' } else { "$($chron.Count) entry(s)" })
                $results += Test-Check 'analysis.json chronology is oldest-first' (-not $outOfOrder) $(if ($outOfOrder) { "entries are not in ascending date order" })
                $results += Test-Check 'analysis.json chronology source indices resolve' ($badSrc.Count -eq 0) $(if ($badSrc.Count) { "out of range: " + (($badSrc | Select-Object -Unique) -join ', ') })

                $riskBad = @()
                $riskRows = (Get-Arr $analysis 'risk')
                foreach ($r in $riskRows) {
                    if (-not (Test-Prop $r 'sector') -or -not (Test-Prop $r 'level')) { $riskBad += 'entry missing sector/level'; continue }
                    if ($RISK_LEVELS -notcontains $r.level) { $riskBad += "level '$($r.level)'" }
                    if ([string]::IsNullOrWhiteSpace((Get-Val $r 'why'))) { $riskBad += "$($r.sector) has no 'why'" }
                }
                $results += Test-Check 'analysis.json risk entries well formed' ($riskBad.Count -eq 0) $(if ($riskBad.Count) { ($riskBad | Select-Object -Unique) -join '; ' } else { "$($riskRows.Count) sector(s)" })
            }
        } else {
            Write-Host "  [ -- ] analysis.json absent - skipped"
        }

        # ---------------- mapping.json ----------------
        if ($mExists) {
            $parsed = $true
            try { $mapping = Read-Json $mPath } catch { $parsed = $false }
            $results += Test-Check 'mapping.json is valid JSON' $parsed

            if ($parsed) {
                $req = @('schema','subject','slug','matrix','tactics')
                $missing = @($req | Where-Object { -not (Test-Prop $mapping $_) })
                $results += Test-Check 'mapping.json required fields' ($missing.Count -eq 0) $(if ($missing.Count) { "missing: " + ($missing -join ', ') } else { "$($req.Count) present" })

                $mx = Get-Val $mapping 'matrix'
                $mxOk = [bool]($mx -and $TACTICS.ContainsKey($mx))
                $results += Test-Check 'mapping.json matrix is known' $mxOk $(if (-not $mxOk) { "matrix '$mx'" } else { $mx })

                $allowed = if ($mxOk) { $TACTICS[$mx] } else { @() }
                # NOT $tactics: PowerShell variable names are case-insensitive, so that name
                # is the same variable as the $TACTICS lookup table built in begin{}. Under
                # true pipeline binding begin{} runs once, so assigning here would replace the
                # table with this subject's array and every later subject would die on
                # $TACTICS.ContainsKey(). ForEach-Object hides it by re-running the script.
                $tacticList = (Get-Arr $mapping 'tactics')

                $badT = @(); $techCount = 0; $badIds = @(); $noUsage = 0; $noName = @(); $emptyTac = 0
                foreach ($t in $tacticList) {
                    $tn = Get-Val $t 'tactic'
                    if ($allowed -notcontains $tn) { $badT += $tn }
                    $techs = (Get-Arr $t 'techniques')
                    if ($techs.Count -eq 0) { $emptyTac++ }
                    foreach ($tech in $techs) {
                        $techCount++
                        $id = Get-Val $tech 'id'
                        if ($id -notmatch '^T\d{4}(\.\d{3})?$') { $badIds += $id }
                        if ([string]::IsNullOrWhiteSpace((Get-Val $tech 'usage'))) { $noUsage++ }
                        # name is required by the schema; without it a report renders a blank row
                        if ([string]::IsNullOrWhiteSpace((Get-Val $tech 'name'))) { $noName += $id }
                    }
                }
                $results += Test-Check 'mapping.json tactic names valid for matrix' ($badT.Count -eq 0) $(if ($badT.Count) { "not in '$mx': " + (($badT | Select-Object -Unique) -join ', ') } else { "$($tacticList.Count) tactic(s)" })
                $results += Test-Check 'mapping.json every tactic has techniques' ($emptyTac -eq 0) $(if ($emptyTac) { "$emptyTac empty" } else { "$techCount technique(s)" })
                $results += Test-Check 'mapping.json technique IDs well formed' ($badIds.Count -eq 0) $(if ($badIds.Count) { "malformed: " + (($badIds | Select-Object -Unique) -join ', ') })
                $results += Test-Check 'mapping.json every technique has usage' ($noUsage -eq 0) $(if ($noUsage) { "$noUsage missing" })
                $results += Test-Check 'mapping.json every technique has a name' ($noName.Count -eq 0) $(if ($noName.Count) { "missing on: " + (($noName | Select-Object -Unique) -join ', ') })

                $slugVal = Get-Val $mapping 'slug'
                $results += Test-Check 'mapping.json slug matches folder' ($slugVal -eq $slug) $(if ($slugVal -ne $slug) { "'$slugVal' vs folder '$slug'" })
            }
        } else {
            Write-Host "  [ -- ] mapping.json absent - skipped"
        }

        # ---------------- cross-file ----------------
        if ($analysis -and $mapping) {
            $mismatch = @()
            foreach ($k in @('subject','slug','matrix')) {
                $a = Get-Val $analysis $k; $b = Get-Val $mapping $k
                if ($a -ne $b) { $mismatch += "$k ('$a' vs '$b')" }
            }
            $results += Test-Check 'the two files agree on subject/slug/matrix' ($mismatch.Count -eq 0) $(if ($mismatch.Count) { $mismatch -join '; ' })

            $declared = (Get-Arr $analysis 'cves')
            $used = @()
            foreach ($t in (Get-Arr $mapping 'tactics')) {
                foreach ($tech in (Get-Arr $t 'techniques')) {
                    $vc = Get-Val $tech 'via_cve'
                    if ($vc) { $used += $vc }
                }
            }
            $unknown = @($used | Where-Object { $declared -notcontains $_ } | Select-Object -Unique)
            $results += Test-Check 'every via_cve is declared in analysis.json' ($unknown.Count -eq 0) $(if ($unknown.Count) { "undeclared: " + ($unknown -join ', ') } else { "$($used.Count) tagged" })
        }

        $failed = @($results | Where-Object { -not $_ }).Count
        if ($failed) {
            $anyFailed = $true
            Write-Host "  --> $failed check(s) FAILED" -ForegroundColor Red
        } else {
            Write-Host "  --> all $($results.Count) checks passed" -ForegroundColor Green
        }
    }
}

end {
    Write-Host ""
    if ($checked -eq 0) {
        Write-Host "RESULT: NOTHING CHECKED - no input matched."
        Write-Host "        Point this at a subject folder, e.g. .\subjects\<slug>."
        exit 1
    }
    if ($anyFailed) { Write-Host "RESULT: failures present."; exit 1 }
    Write-Host "RESULT: clean. $checked subject(s) checked."
    exit 0
}
