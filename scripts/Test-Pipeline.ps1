<#
.SYNOPSIS
    Regression harness for the whole pipeline. Run it before committing a script change.

.DESCRIPTION
    Every bug that has actually shipped in this project was invisible to the checks in place
    at the time. Two examples, both now locked in below:

      - Verify-Mapping.ps1 crashed on the SECOND subject under true pipeline binding, because
        a local $tactics silently replaced the $TACTICS lookup table built in begin{}. Every
        test until then used ForEach-Object, which re-runs the script per item and hides it.
      - All four verifiers printed "clean" and exited 0 when their input matched zero files,
        so a stale glob read as a pass.

    Neither was findable by running the happy path. This harness exists to run the paths
    nobody runs: the documented invocation forms, and deliberately broken input.

    SAFETY: fixtures are built under the user TEMP directory and deleted afterwards. Nothing
    is written to subjects/ or output/. Real subjects are read for the positive cases only.

    Exit 0 = all passed, 1 = at least one failure.

.EXAMPLE
    .\scripts\Test-Pipeline.ps1
    .\scripts\Test-Pipeline.ps1 -IncludeExport
    .\scripts\Test-Pipeline.ps1 -IncludeExport -KeepFixtures
#>
[CmdletBinding()]
param(
    # Also exercise Export-Bulletin end to end. Invokes headless Edge, so it costs ~15s and
    # is off by default; turn it on when you have touched the exporter or its print CSS.
    [switch]$IncludeExport,

    # Leave the fixture tree on disk so a failure can be inspected.
    [switch]$KeepFixtures
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

$VM_VIS = Join-Path $root '.claude\skills\mitre-visualizer\scripts\Verify-Mapping.ps1'
$VM_MAP = Join-Path $root '.claude\skills\mitre-mapping\scripts\Verify-Mapping.ps1'
$VM_ANA = Join-Path $root '.claude\skills\ti-analysis\scripts\Verify-Mapping.ps1'
$VFLOW  = Join-Path $root '.claude\skills\mitre-visualizer\scripts\Verify-Flow.ps1'
$VBULL  = Join-Path $root 'scripts\Verify-Bulletin.ps1'
$MERGE  = Join-Path $root 'scripts\Merge-Bulletin.ps1'
$EXPORT = Join-Path $root 'scripts\Export-Bulletin.ps1'

$fixRoot = Join-Path $env:TEMP ("ti-tests-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $fixRoot -Force | Out-Null

# ---------------------------------------------------------------- harness

$script:pass = 0
$script:fail = 0
$script:failed = @()
$script:group = ''

function Set-Group {
    param([string]$Name)
    $script:group = $Name
    Write-Host ""
    Write-Host "== $Name =="
}

function Assert {
    param([string]$Name, [bool]$Ok, [string]$Detail)
    if ($Ok) {
        $script:pass++
        $line = "  [PASS] $Name"
        if ($Detail) { $line += " - $Detail" }
        Write-Host $line
    }
    else {
        $script:fail++
        $script:failed += "$($script:group) / $Name"
        $line = "  [FAIL] $Name"
        if ($Detail) { $line += " - $Detail" }
        Write-Host $line
    }
}

# Runs a pipeline script in-process and returns its exit code plus everything it printed.
# & sets $LASTEXITCODE for a .ps1 that calls exit N, and Write-Host lands on stream 6, so
# both are recoverable without spawning a child shell.
function Invoke-Target {
    param([string]$Script, [hashtable]$Params = @{}, [object[]]$PipeIn, [switch]$UsePipe)
    $global:LASTEXITCODE = 0
    $text = ''
    try {
        if ($UsePipe) { $text = ($PipeIn | & $Script @Params 6>&1 | Out-String) }
        else          { $text = (& $Script @Params 6>&1 | Out-String) }
    }
    catch {
        return [pscustomobject]@{ Code = -1; Out = $text; Threw = $true; Error = $_.Exception.Message }
    }
    return [pscustomobject]@{ Code = $LASTEXITCODE; Out = $text; Threw = $false; Error = '' }
}

function Read-Text  { param([string]$F) Get-Content -LiteralPath $F -Raw -Encoding UTF8 }
function Write-Text { param([string]$F, [string]$T) [System.IO.File]::WriteAllText($F, $T, (New-Object System.Text.UTF8Encoding($false))) }

# Builds a throwaway subject from a real one, rewriting the slug so the folder-match check
# passes. Mutations are then applied on top to make a specific check fail.
function New-Fixture {
    param([string]$Name, [string]$From = 'akira', [switch]$WithReports, [switch]$WithBulletin)
    $src = Join-Path $root "subjects\$From"
    $dst = Join-Path $fixRoot $Name
    New-Item -ItemType Directory -Path (Join-Path $dst 'handoff') -Force | Out-Null
    foreach ($j in @('analysis.json', 'mapping.json')) {
        $p = Join-Path $src "handoff\$j"
        if (Test-Path -LiteralPath $p) {
            Write-Text (Join-Path $dst "handoff\$j") ((Read-Text $p) -replace "`"slug`":\s*`"$From`"", "`"slug`": `"$Name`"")
        }
    }
    if ($WithReports -or $WithBulletin) {
        New-Item -ItemType Directory -Path (Join-Path $dst 'reports') -Force | Out-Null
        Get-ChildItem (Join-Path $src 'reports') -File | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $dst "reports\$($_.Name)")
        }
    }
    return $dst
}

function Edit-Fixture {
    param([string]$Dir, [string]$File, [string]$Find, [string]$Replace)
    $p = Join-Path $Dir $File
    Write-Text $p ((Read-Text $p) -replace $Find, $Replace)
}

Write-Host ""
Write-Host "TI-Reporting pipeline regression"
Write-Host "fixtures: $fixRoot"

# ================================================================ 1. invocation forms
Set-Group '1. Documented invocation forms'

$realSubjects = @(Get-ChildItem (Join-Path $root 'subjects') -Directory)
$realFlows    = @(Get-ChildItem (Join-Path $root 'subjects\*\reports\*-flow.html'))

$r = Invoke-Target $VM_MAP @{ Path = (Join-Path $root 'subjects\akira') }
Assert 'Verify-Mapping -Path <subject>' ($r.Code -eq 0) "exit $($r.Code)"

# The $TACTICS regression. begin{} runs once here, so state that leaks between items shows up
# on the second subject and later - which is why this must pipe, not ForEach-Object.
$r = Invoke-Target $VM_MAP -UsePipe -PipeIn $realSubjects
Assert 'Verify-Mapping | pipeline over every subject' ($r.Code -eq 0 -and -not $r.Threw) $(
    if ($r.Threw) { "threw: $($r.Error)" } else { "exit $($r.Code), $($realSubjects.Count) subjects" })

$r = Invoke-Target $VFLOW @{ Path = $realFlows[0].FullName }
Assert 'Verify-Flow -Path <file>' ($r.Code -eq 0) "exit $($r.Code)"

$r = Invoke-Target $VFLOW -UsePipe -PipeIn $realFlows
Assert 'Verify-Flow | pipeline over every report' ($r.Code -eq 0 -and -not $r.Threw) $(
    if ($r.Threw) { "threw: $($r.Error)" } else { "$($realFlows.Count) files" })

$r = Invoke-Target $VBULL @{ Path = (Join-Path $root 'subjects\akira') }
Assert 'Verify-Bulletin -Path <subject>' ($r.Code -eq 0) "exit $($r.Code)"

$r = Invoke-Target $VBULL -UsePipe -PipeIn $realSubjects
Assert 'Verify-Bulletin | pipeline over every subject' ($r.Code -eq 0 -and -not $r.Threw) $(
    if ($r.Threw) { "threw: $($r.Error)" } else { "exit $($r.Code)" })

# ================================================================ 2. zero input
Set-Group '2. Zero input must refuse, never report clean'

foreach ($t in @(
    @{ N = 'Verify-Mapping';  S = $VM_MAP },
    @{ N = 'Verify-Flow';     S = $VFLOW  },
    @{ N = 'Verify-Bulletin'; S = $VBULL  },
    @{ N = 'Export-Bulletin'; S = $EXPORT }
)) {
    $r = Invoke-Target $t.S -UsePipe -PipeIn @()
    $refused = ($r.Code -eq 1) -and ($r.Out -match 'NOTHING')
    Assert "$($t.N) on empty pipeline" $refused $(
        if ($r.Code -ne 1) { "exit $($r.Code), expected 1" } elseif ($r.Out -notmatch 'NOTHING') { 'no NOTHING message' } else { 'exit 1' })
}

# ================================================================ 3. malformed handoff
Set-Group '3. Malformed handoff must fail validation'

$f = New-Fixture 'broken-json'
Write-Text (Join-Path $f 'handoff\analysis.json') '{ "schema": "analysis/1.0", oops'
$r = Invoke-Target $VM_VIS @{ Path = $f }
Assert 'invalid JSON' ($r.Code -eq 1) "exit $($r.Code)"

$f = New-Fixture 'stale-tactic'
Edit-Fixture $f 'handoff\mapping.json' '"tactic": "Stealth"' '"tactic": "Defense Evasion"'
$r = Invoke-Target $VM_VIS @{ Path = $f }
Assert 'pre-rename tactic name in an enterprise mapping' ($r.Code -eq 1 -and $r.Out -match 'Defense Evasion') "exit $($r.Code)"

$f = New-Fixture 'undeclared-cve'
Edit-Fixture $f 'handoff\mapping.json' '"via_cve": "CVE-2024-40766"' '"via_cve": "CVE-1999-0001"'
$r = Invoke-Target $VM_VIS @{ Path = $f }
Assert 'via_cve naming a CVE the analysis never declared' ($r.Code -eq 1 -and $r.Out -match 'undeclared') "exit $($r.Code)"

$f = New-Fixture 'lone-cve-chain'
Edit-Fixture $f 'handoff\analysis.json' '"cves": \[[^\]]*\]' '"cves": ["CVE-2024-40766"]'
Edit-Fixture $f 'handoff\analysis.json' '"vuln_relationship": "none"' '"vuln_relationship": "exploit-chain"'
$r = Invoke-Target $VM_VIS @{ Path = $f }
Assert 'a single CVE marked as an exploit chain' ($r.Code -eq 1) "exit $($r.Code)"

$f = New-Fixture 'blank-usage'
Edit-Fixture $f 'handoff\mapping.json' '"usage": "Logs in to remote-access VPN accounts[^"]*"' '"usage": "   "'
$r = Invoke-Target $VM_VIS @{ Path = $f }
Assert 'technique with a blank usage' ($r.Code -eq 1) "exit $($r.Code)"

$f = New-Fixture 'blank-name'
Edit-Fixture $f 'handoff\mapping.json' '"name": "Valid Accounts"' '"name": ""'
$r = Invoke-Target $VM_VIS @{ Path = $f }
Assert 'technique with a blank name' ($r.Code -eq 1) "exit $($r.Code)"

$f = New-Fixture 'bad-order'
$j = Read-Text (Join-Path $f 'handoff\analysis.json') | ConvertFrom-Json
$j.chronology = @($j.chronology | Sort-Object { $_.date } -Descending)
Write-Text (Join-Path $f 'handoff\analysis.json') ($j | ConvertTo-Json -Depth 12)
$r = Invoke-Target $VM_VIS @{ Path = $f }
Assert 'chronology newest-first instead of oldest-first' ($r.Code -eq 1 -and $r.Out -match 'oldest-first') "exit $($r.Code)"

$f = New-Fixture 'slug-mismatch'
Edit-Fixture $f 'handoff\analysis.json' '"slug": "slug-mismatch"' '"slug": "something-else"'
$r = Invoke-Target $VM_VIS @{ Path = $f }
Assert 'slug that does not match its folder' ($r.Code -eq 1) "exit $($r.Code)"

$f = New-Fixture 'no-handoff'
Remove-Item (Join-Path $f 'handoff\*') -Force
$r = Invoke-Target $VM_VIS @{ Path = $f }
Assert 'absent handoff is skipped, not failed' ($r.Code -eq 0 -and $r.Out -match 'SKIP') "exit $($r.Code)"

# An actor with no CVEs is the ordinary case, not an edge case. PowerShell wraps $null into a
# one-element array, so an absent optional field read as @(Get-Val ...) reports Count 1 - which
# made the CVE cross-field rule fire on a file carrying no cves key at all.
$f = New-Fixture 'no-cves'
$j = Read-Text (Join-Path $f 'handoff\analysis.json') | ConvertFrom-Json
$j.PSObject.Properties.Remove('cves')
$j.PSObject.Properties.Remove('vuln_relationship')
$j.subject_type = 'actor'
Write-Text (Join-Path $f 'handoff\analysis.json') ($j | ConvertTo-Json -Depth 12)
$r = Invoke-Target $VM_VIS @{ Path = $f }
$ok = ($r.Code -eq 1) -and ($r.Out -notmatch 'cves present but')   # mapping.json still has via_cve
Assert 'an actor with no cves does not trip the CVE cross-field rule' $ok $(
    if ($r.Out -match 'cves present but') { 'absent field read as present' } else { 'absent field reads as empty' })

$f = New-Fixture 'no-cves-clean'
Remove-Item (Join-Path $f 'handoff\mapping.json') -Force
$j = Read-Text (Join-Path $f 'handoff\analysis.json') | ConvertFrom-Json
$j.PSObject.Properties.Remove('cves')
$j.PSObject.Properties.Remove('vuln_relationship')
$j.subject_type = 'actor'
Write-Text (Join-Path $f 'handoff\analysis.json') ($j | ConvertTo-Json -Depth 12)
$r = Invoke-Target $VM_VIS @{ Path = $f }
Assert 'a CVE-free actor analysis validates cleanly' ($r.Code -eq 0) "exit $($r.Code)"

# ================================================================ 4. merge and bulletin
Set-Group '4. Merge and bulletin refusals'

$f = New-Fixture 'no-analysis' -WithReports
Remove-Item (Join-Path $f 'reports\analysis.html') -Force
$r = Invoke-Target $MERGE @{ Path = $f }
Assert 'merge with no analysis.html' ($r.Code -eq 1 -and $r.Out -match 'REFUSED') "exit $($r.Code)"

$f = New-Fixture 'no-flow' -WithReports
Get-ChildItem (Join-Path $f 'reports') -Filter '*-flow.html' | Remove-Item -Force
$r = Invoke-Target $MERGE @{ Path = $f }
Assert 'merge with no flow report' ($r.Code -eq 1 -and $r.Out -match 'REFUSED') "exit $($r.Code)"

$f = New-Fixture 'two-flows' -WithReports
$one = (Get-ChildItem (Join-Path $f 'reports') -Filter '*-flow.html')[0]
Copy-Item $one.FullName (Join-Path $f 'reports\duplicate-flow.html')
$r = Invoke-Target $MERGE @{ Path = $f }
Assert 'merge with two flow reports' ($r.Code -eq 1 -and $r.Out -match 'expected exactly one') "exit $($r.Code)"

$f = New-Fixture 'merge-ok' -WithReports
$r = Invoke-Target $MERGE @{ Path = $f }
$made = Test-Path (Join-Path $f 'bulletin\merge-ok-threat-bulletin.html')
Assert 'merge produces <slug>-threat-bulletin.html' ($r.Code -eq 0 -and $made) "exit $($r.Code)"

$r = Invoke-Target $MERGE @{ Path = $f }
Assert 'merge refuses to overwrite without -Force' ($r.Code -eq 1 -and $r.Out -match 'Re-run with -Force') "exit $($r.Code)"

# Editorial regions are the only hand-written content in a bulletin. Losing them on a
# regenerate would be silent and expensive, so prove they survive.
$bp = Join-Path $f 'bulletin\merge-ok-threat-bulletin.html'
$marker = 'SENTINEL-EDITORIAL-CONTENT-42'
Write-Text $bp ((Read-Text $bp) -replace '(?s)(<!-- BULLETIN:SUMMARY -->).*?(<!-- /BULLETIN:SUMMARY -->)', "`${1}$marker`${2}")
$r = Invoke-Target $MERGE @{ Path = $f; Force = $true }
$kept = (Read-Text $bp) -match $marker
Assert 'forced re-merge preserves the editorial regions' ($r.Code -eq 0 -and $kept) $(if ($kept) { 'sentinel survived' } else { 'SENTINEL LOST' })

$two = New-Fixture 'two-bulletins' -WithReports
Invoke-Target $MERGE @{ Path = $two } | Out-Null
Copy-Item (Join-Path $two 'bulletin\two-bulletins-threat-bulletin.html') (Join-Path $two 'bulletin\extra-threat-bulletin.html')
$r = Invoke-Target $VBULL @{ Path = $two }
Assert 'two bulletins in one folder' ($r.Code -eq 1 -and $r.Out -match 'expected exactly one') "exit $($r.Code)"

$r = Invoke-Target $VBULL @{ Path = $f }
Assert 'freshly merged bulletin still has placeholders' ($r.Code -eq 1 -and $r.Out -match 'placeholder') "exit $($r.Code)"

# ================================================================ 5. contract drift
Set-Group '5. Contract drift'

$copies = @($VM_VIS, $VM_MAP, $VM_ANA)
$hashes = @($copies | ForEach-Object { (Get-FileHash $_).Hash } | Select-Object -Unique)
Assert 'Verify-Mapping.ps1 byte-identical in all three skills' ($hashes.Count -eq 1) $(if ($hashes.Count -eq 1) { $hashes[0].Substring(0, 12) } else { "$($hashes.Count) distinct" })

$skills = @('ti-analysis', 'mitre-mapping', 'mitre-visualizer')
$xref = @()
foreach ($s in $skills) {
    foreach ($file in (Get-ChildItem (Join-Path $root ".claude\skills\$s") -Recurse -File)) {
        foreach ($o in ($skills | Where-Object { $_ -ne $s })) {
            if (Select-String -Path $file.FullName -SimpleMatch $o -Quiet) { $xref += "$s/$($file.Name) -> $o" }
        }
    }
}
Assert 'no skill references another skill' ($xref.Count -eq 0) $(if ($xref.Count) { $xref[0] } else { '0 references' })

$leak = @(Get-ChildItem (Join-Path $root '.claude\skills') -Recurse -File |
    ForEach-Object { Select-String -Path $_.FullName -Pattern 'Merge-Bulletin|Verify-Bulletin|Export-Bulletin|Test-Pipeline' })
Assert 'no skill references a project-level script' ($leak.Count -eq 0) $(if ($leak.Count) { "$($leak.Count) hit(s)" } else { '0 references' })

$allScripts = @(Get-ChildItem (Join-Path $root 'scripts') -Filter *.ps1) +
              @(Get-ChildItem (Join-Path $root '.claude\skills') -Recurse -Filter *.ps1)
$nonAscii = @(); $noParse = @()
foreach ($s in $allScripts) {
    $t = [System.IO.File]::ReadAllText($s.FullName)
    foreach ($ch in $t.ToCharArray()) { if ([int]$ch -gt 127) { $nonAscii += $s.Name; break } }
    $err = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($s.FullName, [ref]$null, [ref]$err)
    if ($err -and $err.Count) { $noParse += $s.Name }
}
Assert 'every script is pure ASCII' ($nonAscii.Count -eq 0) $(if ($nonAscii.Count) { $nonAscii -join ', ' } else { "$($allScripts.Count) scripts" })
Assert 'every script parses' ($noParse.Count -eq 0) $(if ($noParse.Count) { $noParse -join ', ' } else { "$($allScripts.Count) scripts" })

$boms = @()
Get-ChildItem $root -Recurse -File -Include *.md, *.html, *.json, *.ps1, *.yaml |
    Where-Object { $_.FullName -notmatch '\\\.git\\' } | ForEach-Object {
        $b = [System.IO.File]::ReadAllBytes($_.FullName)
        if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { $boms += $_.Name }
    }
Assert 'no file carries a UTF-8 BOM' ($boms.Count -eq 0) $(if ($boms.Count) { $boms -join ', ' } else { 'none' })

# The $TACTICS trap, generalised. A begin{} constant and a process{} local that differ only in
# casing are THE SAME VARIABLE, and the collision only bites under pipeline binding.
$shadowed = @()
foreach ($s in $allScripts) {
    $t = [System.IO.File]::ReadAllText($s.FullName)
    $consts = @([regex]::Matches($t, '(?m)^\s{4}\$([A-Z][A-Z0-9_]{2,})\s*=') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
    foreach ($c in $consts) {
        $spell = @([regex]::Matches($t, "(?im)\`$($c)\s*=") | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
        if ($spell.Count -gt 1) { $shadowed += "$($s.Name): `$$c vs $($spell -join '/')" }
    }
}
Assert 'no local shadows a begin{} constant by casing' ($shadowed.Count -eq 0) $(if ($shadowed.Count) { $shadowed[0] } else { 'none' })

# Trap 2: an unqualified Get-Content in a script that reads project data decodes as ANSI.
# Comments are stripped first - these scripts carry comments that mention Get-Content in
# order to explain the trap, and matching those would flag the documentation as the defect.
$ansiReads = @()
foreach ($s in @($VM_VIS, $VFLOW, $VBULL, $MERGE)) {
    foreach ($line in ([System.IO.File]::ReadAllText($s) -split "`r?`n")) {
        $code = ($line -replace '#.*$', '').Trim()
        if ($code -match 'Get-Content' -and $code -notmatch '-Encoding') {
            $ansiReads += "$(Split-Path $s -Leaf): $code"
        }
    }
}
Assert 'every data read passes -Encoding UTF8' ($ansiReads.Count -eq 0) $(if ($ansiReads.Count) { $ansiReads[0] } else { 'all qualified' })

# What the schema docs promise must be what the validator enforces.
$vt = [System.IO.File]::ReadAllText($VM_VIS)
$vReq = @()
if ($vt -match "\`$req = @\('schema','subject','slug','subject_type'([^)]*)\)") {
    $vReq = @(([regex]::Matches($matches[0], "'([a-z_]+)'") | ForEach-Object { $_.Groups[1].Value }))
}
foreach ($doc in @('.claude\skills\ti-analysis\references\analysis-schema.md', '.claude\skills\mitre-visualizer\references\handoff-schema.md')) {
    $dt = Read-Text (Join-Path $root $doc)
    $dReq = @([regex]::Matches($dt, '\|\s*`([a-z_]+)`\s*\|\s*yes\s*\|') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
    $missing = @($vReq | Where-Object { $dReq -notcontains $_ })
    Assert "$(Split-Path $doc -Leaf) documents every enforced required field" ($missing.Count -eq 0) $(
        if ($missing.Count) { "undocumented: " + ($missing -join ', ') } else { "$($vReq.Count) fields" })
}

$tpl = @(Get-ChildItem (Join-Path $root '.claude\skills\mitre-visualizer\references\templates') -Filter *.html)
Assert 'three flow templates present' ($tpl.Count -eq 3) "$($tpl.Count)"

$dark = @()
foreach ($h in ($tpl + @(Get-ChildItem (Join-Path $root '.claude\skills\ti-analysis\references') -Filter *.html))) {
    $t = [regex]::Replace((Read-Text $h.FullName), '(?s)/\*.*?\*/', '')
    if ($t -match 'prefers-color-scheme|\[data-theme|color-scheme:\s*dark') { $dark += $h.Name }
}
Assert 'templates are light-theme only' ($dark.Count -eq 0) $(if ($dark.Count) { $dark -join ', ' } else { 'no dark blocks' })

# ================================================================ 6. export (opt-in)
if ($IncludeExport) {
    Set-Group '6. PDF export'
    $f = New-Fixture 'export-test' -WithReports
    Invoke-Target $MERGE @{ Path = $f } | Out-Null
    $bp = Join-Path $f 'bulletin\export-test-threat-bulletin.html'
    Write-Text $bp ((Read-Text $bp) -replace '\{\{[^}]*\}\}', 'filled')
    $r = Invoke-Target $EXPORT @{ Path = $f; Force = $true }
    $pdf = Join-Path $root 'output\export-test-threat-bulletin.pdf'
    Assert 'export produces a PDF' ($r.Code -eq 0 -and (Test-Path $pdf)) "exit $($r.Code)"
    if (Test-Path $pdf) {
        $b = [System.IO.File]::ReadAllBytes($pdf)
        $magic = [System.Text.Encoding]::ASCII.GetString($b, 0, 5)
        $raw = [System.Text.Encoding]::ASCII.GetString($b)
        Assert 'PDF header is %PDF-' ($magic -eq '%PDF-') $magic
        Assert 'page size is Letter (612x792)' ($raw -match '/MediaBox\s*\[\s*0\s+0\s+612\s+792') 'MediaBox'
        Assert 'more than one page' (([regex]::Matches($raw, '/Type\s*/Page[^s]')).Count -gt 1) "$(([regex]::Matches($raw,'/Type\s*/Page[^s]')).Count) pages"
        # This fixture is a test artefact; it must not be left in the deliverable folder.
        Remove-Item $pdf -Force
    }
}

# ================================================================ summary

if (-not $KeepFixtures) { Remove-Item -LiteralPath $fixRoot -Recurse -Force -ErrorAction SilentlyContinue }
else { Write-Host ""; Write-Host "fixtures kept at $fixRoot" }

Write-Host ""
Write-Host "-------------------------------------------"
if ($script:fail -gt 0) {
    Write-Host "FAILED: $($script:fail) of $($script:pass + $script:fail)"
    $script:failed | ForEach-Object { Write-Host "  - $_" }
    Write-Host "-------------------------------------------"
    exit 1
}
Write-Host "PASSED: all $($script:pass) checks"
if (-not $IncludeExport) { Write-Host "         (PDF export skipped - add -IncludeExport)" }
Write-Host "-------------------------------------------"
exit 0
