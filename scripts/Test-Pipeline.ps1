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
    is written to samples/ or output/. Real samples are read for the positive cases only.

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
    $src = Join-Path $root "samples\$From"
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
Write-Host "TI-Provenance pipeline regression"
Write-Host "fixtures: $fixRoot"

# ================================================================ 1. invocation forms
Set-Group '1. Documented invocation forms'

$realSamples = @(Get-ChildItem (Join-Path $root 'samples') -Directory)
$realFlows    = @(Get-ChildItem (Join-Path $root 'samples\*\reports\*-flow.html'))

$r = Invoke-Target $VM_MAP @{ Path = (Join-Path $root 'samples\akira') }
Assert 'Verify-Mapping -Path <subject>' ($r.Code -eq 0) "exit $($r.Code)"

# The $TACTICS regression. begin{} runs once here, so state that leaks between items shows up
# on the second subject and later - which is why this must pipe, not ForEach-Object.
$r = Invoke-Target $VM_MAP -UsePipe -PipeIn $realSamples
Assert 'Verify-Mapping | pipeline over every subject' ($r.Code -eq 0 -and -not $r.Threw) $(
    if ($r.Threw) { "threw: $($r.Error)" } else { "exit $($r.Code), $($realSamples.Count) samples" })

$r = Invoke-Target $VFLOW @{ Path = $realFlows[0].FullName }
Assert 'Verify-Flow -Path <file>' ($r.Code -eq 0) "exit $($r.Code)"

$r = Invoke-Target $VFLOW -UsePipe -PipeIn $realFlows
Assert 'Verify-Flow | pipeline over every report' ($r.Code -eq 0 -and -not $r.Threw) $(
    if ($r.Threw) { "threw: $($r.Error)" } else { "$($realFlows.Count) files" })

$r = Invoke-Target $VBULL @{ Path = (Join-Path $root 'samples\akira') }
Assert 'Verify-Bulletin -Path <subject>' ($r.Code -eq 0) "exit $($r.Code)"

$r = Invoke-Target $VBULL -UsePipe -PipeIn $realSamples
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

# Sources moved out of the footer into a real section headed by an .eyebrow label. The merge
# relabels both halves so a reader can tell which part cited what, and Verify-Bulletin fails
# any bare "Sources" heading. The old <h3> shape is covered by the real reports above; this
# proves the current template shape is handled too, so the two cannot drift apart silently.
$ey = New-Fixture 'sources-eyebrow' -WithReports
$eySec = '<section><div class="wrap"><div class="section-head">' +
         '<p class="eyebrow">Sources</p><h2>What this is built on</h2></div>' +
         '<ol class="sources"><li id="s1">A vendor writeup</li></ol></div></section>'
foreach ($p in @(Get-ChildItem (Join-Path $ey 'reports') -File)) {
    $t = Read-Text $p.FullName
    $t = [regex]::Replace($t, '(?i)<h3[^>]*>\s*Sources\s*</h3>', '<p class="eyebrow">Sources</p>')
    if ($t -notmatch '(?i)eyebrow[^>]*>\s*Sources\s*<') { $t = $t -replace '</main>', "$eySec</main>" }
    Write-Text $p.FullName $t
}
$r = Invoke-Target $MERGE @{ Path = $ey }
$mb = Read-Text (Join-Path $ey 'bulletin\sources-eyebrow-threat-bulletin.html')
$bare = ([regex]::Matches($mb, '(?i)>\s*Sources\s*[<:]')).Count
$ok = ($mb -match '(?i)>\s*Part 1 sources\s*<') -and ($mb -match '(?i)>\s*Part 2 sources\s*<') -and $bare -eq 0
Assert 'eyebrow-headed Sources are attributed to their part' ($r.Code -eq 0 -and $ok) $(
    if ($ok) { 'both halves labelled, 0 bare' } else { "exit $($r.Code), $bare bare heading(s)" })
$dupIds = ([regex]::Matches($mb, 'id="(s\d+)"') | ForEach-Object { $_.Groups[1].Value } |
           Group-Object | Where-Object Count -gt 1).Count
Assert 'both halves numbering sources from 1 does not collide' ($dupIds -eq 0) "$dupIds duplicate id(s)"

$two = New-Fixture 'two-bulletins' -WithReports
Invoke-Target $MERGE @{ Path = $two } | Out-Null
Copy-Item (Join-Path $two 'bulletin\two-bulletins-threat-bulletin.html') (Join-Path $two 'bulletin\extra-threat-bulletin.html')
$r = Invoke-Target $VBULL @{ Path = $two }
Assert 'two bulletins in one folder' ($r.Code -eq 1 -and $r.Out -match 'expected exactly one') "exit $($r.Code)"

$r = Invoke-Target $VBULL @{ Path = $f }
Assert 'freshly merged bulletin still has placeholders' ($r.Code -eq 1 -and $r.Out -match 'placeholder') "exit $($r.Code)"

# A filled editorial region that lost its heading renders as an unlabelled slab of prose,
# reading as a continuation of whatever preceded it. That happened for real when a hand-edit
# replaced the placeholder body and dropped the eyebrow with it, and every other check passed.
$hf = New-Fixture 'headless-region' -WithReports
Invoke-Target $MERGE @{ Path = $hf } | Out-Null
$hp = Join-Path $hf 'bulletin\headless-region-threat-bulletin.html'
$body = (Read-Text $hp) -replace '\{\{[^}]*\}\}', 'filled'
$body = [regex]::Replace($body, '(?s)(<!-- BULLETIN:DEFENCE -->.*?)<p class="eyebrow">[^<]*</p>', '$1')
Write-Text $hp $body
$r = Invoke-Target $VBULL @{ Path = $hf }
Assert 'editorial region stripped of its heading' ($r.Code -eq 1 -and $r.Out -match 'no eyebrow') "exit $($r.Code)"

# The worse variant of the same failure: the whole defence section deleted rather than just its
# heading. For a subject whose part 2 has no Remediation this leaves a bulletin with no
# remediation guidance anywhere, and the earlier check reported that as "written into the
# bulletin" - a pass that asserted the opposite of the truth.
$nf = New-Fixture 'no-remediation' -WithReports
Invoke-Target $MERGE @{ Path = $nf } | Out-Null
$np = Join-Path $nf 'bulletin\no-remediation-threat-bulletin.html'
$nb = (Read-Text $np) -replace '\{\{[^}]*\}\}', 'filled'
$mk = 'BULLETIN:DEFENCE'
$a = $nb.IndexOf($mk); $b = $nb.IndexOf($mk, $a + 1)
$nb = $nb.Substring(0, $nb.IndexOf('>', $a) + 1) + $nb.Substring($nb.LastIndexOf('<', $b))
# Strip part 2's own Remediation too, so nothing supplies guidance from either half.
$nb = [regex]::Replace($nb, '(?i)(<p class="eyebrow">)\s*Remediation\s*(</p>)', '${1}Fixes${2}')
Write-Text $np $nb
$r = Invoke-Target $VBULL @{ Path = $nf }
Assert 'a bulletin with no remediation guidance at all' ($r.Code -eq 1 -and $r.Out -match 'NONE') "exit $($r.Code)"

# Export must not ship a bulletin the verifier would reject.
$r = Invoke-Target $EXPORT @{ Path = $nf; Force = $true }
Assert 'export refuses a bulletin that fails verification' ($r.Code -eq 1 -and $r.Out -match 'not exporting an unchecked') "exit $($r.Code)"

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

# The accent is per-objective, but everything under it is not. A template left on an old
# accent is invisible in review - it renders fine, it just quietly stops matching the rest of
# the set. That is what happened to the vulnerability template, so pin both halves here.
$NEUTRALS = 'ground','surface','surface-2','ink','muted','hair','hair-strong','steel','steel-wash','spine'
$ACCENTS  = @{ '#1d4ed8' = 'signal blue'; '#7c3aed' = 'violet' }
$palettes = @{}
$accentOf = [ordered]@{}
foreach ($h in ($tpl + @(Get-ChildItem (Join-Path $root '.claude\skills\ti-analysis\references') -Filter *.html))) {
    $rootBlock = [regex]::Match((Read-Text $h.FullName), '(?s):root\s*\{.*?\n  \}').Value
    $sig = ($NEUTRALS | ForEach-Object {
        "$_=" + [regex]::Match($rootBlock, "--$_\s*:\s*([^;]+);").Groups[1].Value.Trim()
    }) -join ' '
    if (-not $palettes.ContainsKey($sig)) { $palettes[$sig] = @() }
    $palettes[$sig] += $h.Name
    $accentOf[$h.Name] = [regex]::Match($rootBlock, '--ember\s*:\s*([^;]+);').Groups[1].Value.Trim()
}
Assert 'every template shares one neutral palette' ($palettes.Count -eq 1) $(
    if ($palettes.Count -eq 1) { "$(@($palettes.Values)[0].Count) templates agree" }
    else { (@($palettes.Values) | ForEach-Object { $_ -join '+' }) -join '  VS  ' })

$offAccent = @($accentOf.Keys | Where-Object { -not $ACCENTS.ContainsKey($accentOf[$_]) })
Assert 'every template accent is one flow-craft.md documents' ($offAccent.Count -eq 0) $(
    if ($offAccent.Count -eq 0) { 'all documented' }
    else { ($offAccent | ForEach-Object { "$_ uses $($accentOf[$_])" }) -join '; ' })

# Nothing about how a report was built belongs in the report. A reader has no idea what
# mitre-visualizer, analysis.json or MODE CHAIN are, and every one of these strings describes
# the pipeline rather than the subject. Checked against VISIBLE text only - the same words are
# legitimate in HTML and CSS comments, which is where authoring guidance is supposed to live.
$FORBIDDEN = 'ti-analysis', 'mitre-visualizer', 'mitre-mapping', 'TI-Provenance',
             'analysis\.json', 'mapping\.json', 'samples/', 'MODE CHAIN', 'MODE SET',
             '[a-z0-9-]+-flow\.html', 'analysis\.html', '[a-z0-9-]+-template\.html'
$leaks = @()
$scanned = 0
$reportFiles = @(Get-ChildItem (Join-Path $root 'samples\*\reports\*.html')) +
               @(Get-ChildItem (Join-Path $root 'samples\*\bulletin\*.html')) +
               $tpl +
               @(Get-ChildItem (Join-Path $root '.claude\skills\ti-analysis\references') -Filter *.html)
foreach ($h in $reportFiles) {
    $scanned++
    $vis = Read-Text $h.FullName
    $vis = [regex]::Replace($vis, '(?s)<!--.*?-->', '')      # HTML comments are not rendered
    $vis = [regex]::Replace($vis, '(?s)/\*.*?\*/', '')        # nor are CSS comments
    $vis = [regex]::Replace($vis, '(?s)<style.*?</style>', '')
    $vis = $vis -replace '<[^>]*>', ''
    foreach ($f in $FORBIDDEN) {
        if ($vis -match $f) { $leaks += "$($h.Name): $($Matches[0])" }
    }
}
Assert 'no build-pipeline or skill names in visible report text' ($leaks.Count -eq 0 -and $scanned -gt 0) $(
    if ($leaks.Count) { ($leaks | Select-Object -First 4) -join '; ' } else { "$scanned file(s) clean" })

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
        # Page numbering rides on @page margin boxes, which is an engine feature rather than
        # anything this project controls - a Chromium regression would drop the numbers
        # silently. Needs poppler to read the text back, so it is skipped when absent.
        # The number is not reliably the LAST extracted line: pdftotext orders the margin box
        # against the content by position, so on some pages body text follows it. Testing for
        # a standalone line anywhere on the page is what actually holds.
        if (Get-Command pdftotext -ErrorAction SilentlyContinue) {
            $tf = Join-Path $fixRoot 'export-test.txt'
            & pdftotext $pdf $tf 2>$null | Out-Null
            $pp = @((Read-Text $tf) -split "`f" | Where-Object { $_.Trim() -ne '' })
            $numbered = 0
            $coverBare = $true
            for ($i = 0; $i -lt $pp.Count; $i++) {
                $lines = @($pp[$i] -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                $has = @($lines | Where-Object { $_ -eq [string]($i + 1) }).Count -gt 0
                if ($i -eq 0) { $coverBare = -not $has } elseif ($has) { $numbered++ }
            }
            $ok = $coverBare -and $pp.Count -gt 1 -and $numbered -eq $pp.Count - 1
            Assert 'every page but the cover carries its number' $ok $(
                if ($ok) { "$numbered numbered, cover bare" }
                else { "$numbered of $($pp.Count - 1) numbered, cover bare: $coverBare" })
        }
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
