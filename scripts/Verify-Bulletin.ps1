<#
.SYNOPSIS
    Validates a merged threat bulletin.

.DESCRIPTION
    Structural checks only. It cannot tell you whether the executive summary is any good, or
    whether the defensive priorities match the mapped techniques. Those stay human judgment.

    The check that matters most is CSS scoping: the two halves of a bulletin share class
    names, so a rule from the flow report that escaped the .flowpart wrapper will silently
    restyle the analysis half. That failure is invisible until someone reads the rendered
    page and notices the risk meters look wrong.

    Exit 0 = clean, 1 = at least one failure.

.EXAMPLE
    .\scripts\Verify-Bulletin.ps1 -Path .\subjects\agrius
    Get-ChildItem .\subjects -Directory | .\scripts\Verify-Bulletin.ps1
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
    $SCOPE = '.flowpart'
    # Counted so a pipeline that matched nothing cannot report success. Without this a stale
    # glob returns zero folders, process never runs, and the script prints "clean" and exits
    # 0 - a verifier that passes because it checked nothing is worse than no verifier.
    $checked = 0

    function Test-Check {
        param([string]$Name, [bool]$Ok, [string]$Detail)
        $mark = if ($Ok) { 'PASS' } else { 'FAIL' }
        $line = "  [{0}] {1}" -f $mark, $Name
        if ($Detail) { $line += " - $Detail" }
        Write-Host $line
        return $Ok
    }

    function Get-Selectors {
        param([string]$Css)
        $Css = [regex]::Replace($Css, '(?s)/\*.*?\*/', '')
        $sels = @()
        foreach ($m in [regex]::Matches($Css, '(?m)([^{}]+)\{')) {
            $h = $m.Groups[1].Value.Trim()
            if ($h.Length -eq 0) { continue }
            if ($h.StartsWith('@')) { continue }
            foreach ($s in ($h -split ',')) {
                $t = $s.Trim()
                if ($t.Length -gt 0) { $sels += $t }
            }
        }
        return $sels
    }
}

process {
    foreach ($p in $Path) {
        if (-not (Test-Path -LiteralPath $p)) { throw "Not found: $p" }
        $checked++
        $item = Get-Item -LiteralPath $p
        $dir  = if ($item.PSIsContainer) { $item.FullName } else { $item.DirectoryName }
        $slug = Split-Path $dir -Leaf
        # The merged output is subjects/<slug>/bulletin/<slug>-threat-bulletin.html. Fall
        # back to the older flat 'bulletin.html' name, then to the subject root, so folders
        # written before the rename - or assembled by hand - still validate.
        $file = $null
        if ($item.PSIsContainer) {
            $bDir = Join-Path $dir 'bulletin'
            if (Test-Path -LiteralPath $bDir) {
                $found = @(Get-ChildItem -LiteralPath $bDir -Filter '*-threat-bulletin.html' -File)
                if ($found.Count -gt 1) {
                    Write-Host ""
                    Write-Host "=== subjects/$slug ==="
                    Write-Host "  [FAIL] $($found.Count) bulletins in bulletin/ - expected exactly one:"
                    $found | ForEach-Object { Write-Host "         $($_.Name)" }
                    $anyFailed = $true
                    continue
                }
                if ($found.Count -eq 1) { $file = $found[0].FullName }
                elseif (Test-Path -LiteralPath (Join-Path $bDir 'bulletin.html')) { $file = Join-Path $bDir 'bulletin.html' }
            }
            if ($null -eq $file) { $file = Join-Path $dir 'bulletin.html' }
        }
        else { $file = $item.FullName }

        Write-Host ""
        Write-Host "=== subjects/$slug ==="

        if (-not (Test-Path -LiteralPath $file)) {
            Write-Host "  [SKIP] no bulletin present - run Merge-Bulletin.ps1 first"
            continue
        }

        $t = Get-Content -LiteralPath $file -Raw -Encoding UTF8
        $results = @()

        # ---- 1. document shape
        $titles = [regex]::Matches($t, '<title>')
        $results += Test-Check 'exactly one <title>' ($titles.Count -eq 1) $(
            if ($titles.Count -eq 1) { ([regex]::Match($t, '<title>(.*?)</title>')).Groups[1].Value } else { "$($titles.Count) found" })

        $wrapper = [regex]::Matches($t, '(?i)<(html|head|body)[\s>]')
        $results += Test-Check 'no document wrapper tags' ($wrapper.Count -eq 0) $(
            if ($wrapper.Count) { "found: " + (($wrapper | ForEach-Object { $_.Value }) -join ' ') })

        $styles = [regex]::Matches($t, '<style>')
        $results += Test-Check 'exactly one <style> block' ($styles.Count -eq 1) "$($styles.Count)"

        # ---- 2. both halves present
        $hasCover = $t -match 'class="cover"'
        $hasFlow  = $t -match 'class="flowpart"'
        $hasRule  = $t -match 'class="partrule"'
        $results += Test-Check 'both parts present' ($hasCover -and $hasFlow -and $hasRule) $(
            $miss = @()
            if (-not $hasCover) { $miss += 'analysis cover' }
            if (-not $hasFlow)  { $miss += 'flow wrapper' }
            if (-not $hasRule)  { $miss += 'part divider' }
            if ($miss.Count) { "missing: " + ($miss -join ', ') } else { 'cover, divider, flow' })

        # ---- 3. CSS scoping. The whole reason this script exists.
        $css = ''
        if ($t -match '(?s)<style>(.*?)</style>') { $css = $matches[1] }

        $p2 = ''
        $marker = 'part 2: attack flow'
        $mi = $css.IndexOf($marker)
        if ($mi -ge 0) {
            # The marker sits inside a comment. Start after that comment closes, or the
            # dangling '*/' parses as part of the first selector.
            $tail = $css.Substring($mi)
            $ct = $tail.IndexOf('*/')
            if ($ct -ge 0) { $tail = $tail.Substring($ct + 2) }
            $endMi = $tail.IndexOf('bulletin chrome')
            if ($endMi -gt 0) {
                $head = $tail.Substring(0, $endMi)
                $co = $head.LastIndexOf('/*')
                $p2 = if ($co -ge 0) { $head.Substring(0, $co) } else { $head }
            }
            else { $p2 = $tail }
        }
        if ($mi -lt 0) {
            $results += Test-Check 'flow CSS is scoped' $false 'part 2 CSS marker not found'
        }
        else {
            $leaked = @(Get-Selectors $p2 | Where-Object { -not $_.StartsWith($SCOPE) })
            $results += Test-Check 'flow CSS is scoped' ($leaked.Count -eq 0) $(
                if ($leaked.Count) { "$($leaked.Count) leaked: " + (($leaked | Select-Object -First 5) -join ' | ') }
                else { "$((Get-Selectors $p2).Count) selectors, all under $SCOPE" })
        }

        $rootBlocks = [regex]::Matches($css, '(?m)^\s*:root\s*\{')
        $results += Test-Check 'exactly one unscoped :root' ($rootBlocks.Count -eq 1) "$($rootBlocks.Count)"

        # ---- 4. tokens resolve
        $defined = @{}
        foreach ($m in [regex]::Matches($css, '(--[\w-]+)\s*:')) { $defined[$m.Groups[1].Value] = $true }
        $used = @{}
        foreach ($m in [regex]::Matches($t, 'var\(\s*(--[\w-]+)')) { $used[$m.Groups[1].Value] = $true }
        $undef = @($used.Keys | Where-Object { -not $defined.ContainsKey($_) } | Sort-Object)
        $results += Test-Check 'all var() tokens defined' ($undef.Count -eq 0) $(
            if ($undef.Count) { $undef -join ', ' } else { "$($used.Count) tokens" })

        # ---- 5. editorial regions
        $sumM = [regex]::Match($t, '(?s)<!-- BULLETIN:SUMMARY -->(.*?)<!-- /BULLETIN:SUMMARY -->')
        $defM = [regex]::Match($t, '(?s)<!-- BULLETIN:DEFENCE -->(.*?)<!-- /BULLETIN:DEFENCE -->')
        $results += Test-Check 'editorial regions intact' ($sumM.Success -and $defM.Success) $(
            $miss = @()
            if (-not $sumM.Success) { $miss += 'SUMMARY' }
            if (-not $defM.Success) { $miss += 'DEFENCE' }
            if ($miss.Count) { "markers lost: " + ($miss -join ', ') })

        $sumFilled = $sumM.Success -and ($sumM.Groups[1].Value -notmatch '\{\{')
        $results += Test-Check 'executive summary written' $sumFilled $(
            if (-not $sumFilled) { 'still a placeholder' })

        # Defence is legitimately EMPTY when the flow report already carries Remediation, but a
        # surviving placeholder is a failure either way.
        # Scoped to part 2 deliberately: a hand-written defence section may use the word
        # "Remediation" in its own heading, and searching the whole page would then report that
        # the flow carries it when the bulletin does.
        # Bounded at the DEFENCE marker, not run to end of file: the defence region sits AFTER
        # the flow wrapper closes, so an unbounded capture swallows it and reports the flow as
        # carrying a Remediation section that the bulletin actually wrote itself.
        $flowHalf = ''
        if ($t -match '(?s)<div class="flowpart">(.*?)<!-- BULLETIN:DEFENCE -->') { $flowHalf = $matches[1] }
        elseif ($t -match '(?s)<div class="flowpart">(.*)')                        { $flowHalf = $matches[1] }
        $hasRemed = $flowHalf -match '(?i)>\s*Remediation'
        $defOk = (-not $defM.Success) -or [string]::IsNullOrWhiteSpace($defM.Groups[1].Value) -or ($defM.Groups[1].Value -notmatch '\{\{')
        $results += Test-Check 'defensive guidance resolved' $defOk $(
            if (-not $defOk -and $hasRemed) { 'still a placeholder - the flow carries Remediation, so empty the region' }
            elseif (-not $defOk) { 'still a placeholder, and the flow has no Remediation part' }
            elseif ($hasRemed) { 'carried by the flow report' } else { 'written into the bulletin' })

        # A filled editorial region must carry its own heading. Without one the section renders
        # as an unlabelled slab of prose that reads as a continuation of whatever preceded it -
        # which is exactly what happened when a hand-edit replaced the placeholder body and
        # dropped the eyebrow with it. Every other check passed.
        $headBad = @()
        if ($sumM.Success -and $sumM.Groups[1].Value -match '<section' -and $sumM.Groups[1].Value -notmatch 'class="eyebrow"') { $headBad += 'SUMMARY' }
        if ($defM.Success -and $defM.Groups[1].Value -match '<section' -and $defM.Groups[1].Value -notmatch 'class="eyebrow"') { $headBad += 'DEFENCE' }
        $results += Test-Check 'filled editorial regions carry a heading' ($headBad.Count -eq 0) $(
            if ($headBad.Count) { "no eyebrow in: " + ($headBad -join ', ') } else { 'headings present' })

        # ---- 6. leftovers and duplicates
        $ph = [regex]::Matches($t, '\{\{[A-Za-z0-9_ .,:;\-]+\}\}')
        $results += Test-Check 'no {{PLACEHOLDER}} left' ($ph.Count -eq 0) $(
            if ($ph.Count) { "$($ph.Count): " + (($ph | Select-Object -First 3 | ForEach-Object { $_.Value }) -join ' ') })

        $ids = @([regex]::Matches($t, 'id="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
        $dupIds = @($ids | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
        $results += Test-Check 'no duplicate id attributes' ($dupIds.Count -eq 0) $(
            if ($dupIds.Count) { $dupIds -join ', ' } else { "$($ids.Count) ids" })

        $results += Test-Check 'no dark-theme block' ($t -notmatch 'prefers-color-scheme')

        # ---- 7. tags balanced
        $unbal = @()
        foreach ($tag in @('div', 'span', 'svg', 'details', 'section', 'table', 'ol', 'ul')) {
            $open  = ([regex]::Matches($t, "<$tag[\s>]")).Count
            $close = ([regex]::Matches($t, "</$tag>")).Count
            if ($open -ne $close) { $unbal += "$tag $open/$close" }
        }
        $results += Test-Check 'tags balanced' ($unbal.Count -eq 0) $(
            if ($unbal.Count) { $unbal -join ', ' } else { 'div, span, svg, details, section, table, ol, ul' })

        # ---- 8. sources reconciled
        # Both halves carry citations and both must stand alone, so a bulletin legitimately
        # holds two lists. What it must not hold is two blocks both called "Sources" with
        # nothing saying which half they belong to. Count BOTH forms - a heading (>Sources<)
        # and a prose lead-in (>Sources:) - or the check passes while the page has two.
        $srcBare = ([regex]::Matches($t, '(?i)>\s*Sources\s*[<:]')).Count
        $results += Test-Check 'source lists attributed to their part' ($srcBare -eq 0) $(
            if ($srcBare -gt 0) { "$srcBare unattributed 'Sources' block(s) - the merge should label them per part" }
            else { 'both labelled' })

        $failed = @($results | Where-Object { -not $_ }).Count
        if ($failed -gt 0) {
            $anyFailed = $true
            Write-Host "  --> $failed check(s) FAILED"
        }
        else {
            Write-Host "  --> all $($results.Count) checks passed"
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
