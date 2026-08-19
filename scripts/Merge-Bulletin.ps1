<#
.SYNOPSIS
    Merges analysis.html and the ATT&CK flow report into a single threat bulletin.

.DESCRIPTION
    Step 4 of the pipeline. Point it at a subject folder. It reads reports/analysis.html and
    exactly one reports/*-flow.html, and writes bulletin/<slug>-threat-bulletin.html. The
    bulletin carries the subject's name because it is the artefact that leaves the project.

    Both inputs are HTML fragments (title + style + content, no document wrapper), so the
    merge is not a concatenation problem but a CSS collision problem: the two halves share
    class names - 'high' and 'low' mean risk level in one and severity in the other. The flow
    report's CSS is therefore rewritten to sit under a .flowpart wrapper, including its :root
    custom properties, which land on .flowpart and cascade to its descendants.

    Two editorial regions are left for a human (or the orchestrating step) to fill:
    BULLETIN:SUMMARY and BULLETIN:DEFENCE. Re-running the merge PRESERVES whatever is inside
    them, so regenerating either half does not cost you the written sections.

    Exit 0 = written, 1 = refused.

.EXAMPLE
    .\scripts\Merge-Bulletin.ps1 -Path .\subjects\agrius
    .\scripts\Merge-Bulletin.ps1 -Path .\subjects\agrius -Force
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [Alias('FullName')]
    [string]$Path,

    # Overwrite an existing bulletin. Editorial regions are carried over either way.
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$SCOPE = '.flowpart'

# ---------------------------------------------------------------- helpers

function Read-Text {
    param([string]$File)
    # PS 5.1 Get-Content defaults to ANSI, which shreds non-ASCII before anything sees it.
    return Get-Content -LiteralPath $File -Raw -Encoding UTF8
}

function Write-Text {
    param([string]$File, [string]$Text)
    # Set-Content -Encoding utf8 emits a BOM. Downstream parsers choke on it.
    [System.IO.File]::WriteAllText($File, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Split-Fragment {
    param([string]$Text)
    $title = ''
    if ($Text -match '(?s)<title>(.*?)</title>') { $title = $matches[1].Trim() }
    $css = ''
    $si = $Text.IndexOf('<style>')
    $ei = $Text.IndexOf('</style>')
    if ($si -ge 0 -and $ei -gt $si) { $css = $Text.Substring($si + 7, $ei - $si - 7) }
    $body = if ($ei -ge 0) { $Text.Substring($ei + 8) } else { $Text }
    return [pscustomobject]@{ Title = $title; Css = $css; Body = $body.Trim() }
}

# Rewrites every selector so it only applies inside $Prefix. Handles nested at-rules by
# recursing into them; leaves @keyframes / @font-face / @page bodies alone.
function ConvertTo-ScopedCss {
    param([string]$Css, [string]$Prefix, [System.Collections.ArrayList]$Warnings)

    $Css = [regex]::Replace($Css, '(?s)/\*.*?\*/', '')
    $out = New-Object System.Text.StringBuilder
    $i = 0
    $n = $Css.Length

    while ($i -lt $n) {
        $brace = $Css.IndexOf('{', $i)
        if ($brace -lt 0) { [void]$out.Append($Css.Substring($i)); break }

        $head = $Css.Substring($i, $brace - $i).Trim()

        $depth = 0
        $j = $brace
        $closed = $false
        while ($j -lt $n) {
            if ($Css[$j] -eq '{') { $depth++ }
            elseif ($Css[$j] -eq '}') { $depth--; if ($depth -eq 0) { $closed = $true; break } }
            $j++
        }
        if (-not $closed) {
            [void]$Warnings.Add("unbalanced braces after '$head'")
            [void]$out.Append($Css.Substring($i))
            break
        }

        $inner = $Css.Substring($brace + 1, $j - $brace - 1)

        if ($head.StartsWith('@')) {
            if ($head -match '^@(media|supports|layer|container)\b') {
                $nested = ConvertTo-ScopedCss -Css $inner -Prefix $Prefix -Warnings $Warnings
                [void]$out.Append("$head {`n$nested`n}`n")
            }
            else {
                [void]$Warnings.Add("at-rule left unscoped: $head")
                [void]$out.Append("$head {$inner}`n")
            }
        }
        else {
            $scoped = @()
            foreach ($sel in ($head -split ',')) {
                $s = $sel.Trim()
                if ($s.Length -eq 0) { continue }
                if ($s -match '^(?::root|html|body)\b') {
                    # :root must become the wrapper itself, or the custom properties defined
                    # there would never reach the flow content.
                    $s = $s -replace '^(?::root|html|body)\b', $Prefix
                    $s = $s.Trim()
                }
                else {
                    $s = "$Prefix $s"
                }
                $scoped += $s
            }
            [void]$out.Append(($scoped -join ",`n") + " {$inner}`n")
        }

        $i = $j + 1
    }

    return $out.ToString()
}

# Carries hand-written editorial content across a re-merge.
function Get-Region {
    param([string]$Text, [string]$Name)
    $m = [regex]::Match($Text, "(?s)<!-- $Name -->(.*?)<!-- /$Name -->")
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

# ---------------------------------------------------------------- inputs

if (-not (Test-Path -LiteralPath $Path)) { throw "Not found: $Path" }
$dir  = (Get-Item -LiteralPath $Path).FullName
$slug = Split-Path $dir -Leaf

# A subject folder holds its artefacts in subfolders - handoff/ for the JSON, reports/ for
# the rendered halves, bulletin/ for the merged output. Each falls back to the subject root
# so a folder an analyst assembled by hand still merges.
function Resolve-Dir {
    param([string]$Dir, [string]$SubDir)
    $nested = Join-Path $Dir $SubDir
    if (Test-Path -LiteralPath $nested) { return $nested }
    return $Dir
}

$reportsDir  = Resolve-Dir $dir 'reports'
$handoffDir  = Resolve-Dir $dir 'handoff'
$bulletinDir = Join-Path $dir 'bulletin'

$aPath = Join-Path $reportsDir 'analysis.html'
if (-not (Test-Path -LiteralPath $aPath)) {
    Write-Host "REFUSED: no reports/analysis.html in subjects/$slug - run the analysis step first."
    exit 1
}

$flows = @(Get-ChildItem -LiteralPath $reportsDir -Filter '*-flow.html' -File)
if ($flows.Count -eq 0) {
    Write-Host "REFUSED: no reports/*-flow.html in subjects/$slug - run the visualization step first."
    exit 1
}
if ($flows.Count -gt 1) {
    Write-Host "REFUSED: $($flows.Count) flow reports in subjects/$slug/reports - expected exactly one:"
    $flows | ForEach-Object { Write-Host "         $($_.Name)" }
    exit 1
}
$fPath = $flows[0].FullName

if (-not (Test-Path -LiteralPath $bulletinDir)) {
    New-Item -ItemType Directory -Path $bulletinDir | Out-Null
}
$outName = "$slug-threat-bulletin.html"
$outPath = Join-Path $bulletinDir $outName

# Editorial regions are carried across a re-merge, so the prior file has to be found even if
# it was written under the older flat 'bulletin.html' name.
$legacyPath = Join-Path $bulletinDir 'bulletin.html'
$priorPath = $null
if (Test-Path -LiteralPath $outPath)         { $priorPath = $outPath }
elseif (Test-Path -LiteralPath $legacyPath)  { $priorPath = $legacyPath }

$existing = $null
if ($null -ne $priorPath) {
    if (-not $Force) {
        Write-Host "REFUSED: subjects/$slug/bulletin/$(Split-Path $priorPath -Leaf) exists. Re-run with -Force."
        Write-Host "         Editorial regions are preserved across a forced re-merge."
        exit 1
    }
    $existing = Read-Text $priorPath
}

$subject = $slug
$aJson = Join-Path $handoffDir 'analysis.json'
if (Test-Path -LiteralPath $aJson) {
    try {
        $meta = (Read-Text $aJson) | ConvertFrom-Json
        if ($meta.subject) { $subject = $meta.subject }
    } catch { }
}

# ---------------------------------------------------------------- merge

$warnings = New-Object System.Collections.ArrayList

$A = Split-Fragment (Read-Text $aPath)
$F = Split-Fragment (Read-Text $fPath)

if ([string]::IsNullOrWhiteSpace($A.Css)) { [void]$warnings.Add('analysis.html has no <style> block') }
if ([string]::IsNullOrWhiteSpace($F.Css)) { [void]$warnings.Add("$($flows[0].Name) has no <style> block") }

$scopedFlowCss = ConvertTo-ScopedCss -Css $F.Css -Prefix $SCOPE -Warnings $warnings

# Both halves cite their own sources and both must stand alone as documents, so the merged
# page ends up with two lists. Label them per part in the DERIVED file only - editing either
# source report to be bulletin-aware would break its standalone use.
$aBodyRaw = $A.Body
$fBodyRaw = $F.Body
# Sources is a real section headed by an .eyebrow label in the current templates; older
# reports carried it as a plain <h3>. Handle both so a bulletin can still be re-merged from
# a report generated before the templates changed.
$srcEyebrow = '(?i)(<p[^>]*class="[^"]*\beyebrow\b[^"]*"[^>]*>)\s*Sources\s*(</p>)'
$srcHeading = '(?i)(<h3[^>]*>)\s*Sources\s*(</h3>)'
$aBodyRaw = [regex]::Replace($aBodyRaw, $srcEyebrow, '${1}Part 1 sources${2}')
$aBodyRaw = [regex]::Replace($aBodyRaw, $srcHeading, '${1}Part 1 sources${2}')
$fBodyRaw = [regex]::Replace($fBodyRaw, $srcEyebrow, '${1}Part 2 sources${2}')
$fBodyRaw = [regex]::Replace($fBodyRaw, $srcHeading, '${1}Part 2 sources${2}')
$fBodyRaw = [regex]::Replace($fBodyRaw, '(?i)(>)(\s*)Sources:', '${1}${2}Part 2 sources:')

# Both halves number their own sources from 1, so the merged page would carry two id="s1".
# Namespace part 2's, and any in-page reference to them, so the ids stay unique and every
# marker still lands on the right entry.
$fBodyRaw = [regex]::Replace($fBodyRaw, '(?i)\bid="s(\d+)"', 'id="fs${1}"')
$fBodyRaw = [regex]::Replace($fBodyRaw, '(?i)href="#s(\d+)"', 'href="#fs${1}"')
$A.Body = $aBodyRaw
$F.Body = $fBodyRaw

# The executive summary belongs after the cover, not before it.
$aBody = $A.Body
$cut = $aBody.IndexOf('</header>')
if ($cut -lt 0) {
    [void]$warnings.Add('analysis.html has no </header>; summary placed at the top')
    $aCover = ''
    $aRest  = $aBody
}
else {
    $aCover = $aBody.Substring(0, $cut + 9)
    $aRest  = $aBody.Substring($cut + 9)
}

$summary = Get-Region $existing 'BULLETIN:SUMMARY'
$defence = Get-Region $existing 'BULLETIN:DEFENCE'
$carried = @()
if ($null -ne $summary) { $carried += 'summary' } else { $summary = @"

  <section class="bsummary">
    <div class="wrap">
      <p class="eyebrow">Executive summary</p>
      <p class="bslede">{{ONE PARAGRAPH: what this subject is, what it does, who should care.
        Written last, from both halves, for a reader who will not read further.}}</p>
      <ul class="bskey">
        <li>{{THREE TO FIVE BOTTOM LINES}}</li>
      </ul>
    </div>
  </section>
"@ }
if ($null -ne $defence) { $carried += 'defence' } else { $defence = @"

  <section class="bdefence">
    <div class="wrap">
      <p class="eyebrow">Defensive priorities</p>
      <p class="bslede">{{ORDERED BY THE TACTICS ACTUALLY MAPPED, NOT BY GENERAL BEST PRACTICE.
        Delete this whole section if the flow report already carries a Remediation part.}}</p>
      <ol class="bsteps">
        <li><span class="bwhat">{{ACTION}}</span><span class="bwhy">{{WHICH MAPPED TECHNIQUE IT DENIES}}</span></li>
      </ol>
    </div>
  </section>
"@ }

$bulletinCss = @"
/* ---------- bulletin chrome (step 4 only) ---------- */
.partrule { border-top: 1px solid var(--hair); background: var(--ground); }
.partrule .wrap { padding: 46px 0 8px; }
.partrule .pnum {
  display: inline-block; font-size: .68rem; letter-spacing: .16em; text-transform: uppercase;
  color: var(--ember); border: 1px solid var(--ember); border-radius: 2px;
  padding: 3px 8px; margin-bottom: 12px;
}
.partrule h2 { font-size: 1.5rem; margin: 0; color: var(--ink); }
.partrule p  { color: var(--muted); margin: 6px 0 0; max-width: 62ch; }

.bsummary, .bdefence { border-top: 1px solid var(--hair); background: var(--surface); }
.bsummary .wrap, .bdefence .wrap { padding: 40px 0; }
.bslede { color: var(--ink); max-width: 68ch; }
.bskey { margin: 18px 0 0; padding: 0; list-style: none; }
.bskey li {
  border-left: 2px solid var(--ember); padding: 4px 0 4px 14px;
  margin-bottom: 10px; color: var(--ink); max-width: 68ch;
}
.bsteps { margin: 18px 0 0; padding-left: 20px; color: var(--ink); max-width: 68ch; }
.bsteps li { margin-bottom: 10px; }
.bwhat { display: block; font-weight: 600; }
.bwhy  { display: block; color: var(--muted); font-size: .9rem; }

/* The flow report carries its own hero. Inside a bulletin the cover already introduced the
   subject, so the hero is demoted rather than repeated at cover scale. */
$SCOPE > header { padding-top: 0; }
$SCOPE header h1 { font-size: 1.9rem; }
$SCOPE header .lede { font-size: 1rem; }
"@

$title = "$subject - Threat Bulletin"

$doc = @"
<title>$title</title>
<style>
/* ============================================================================
   BULLETIN - $subject
   Merged by scripts/Merge-Bulletin.ps1. Do not hand-edit the CSS: regenerate.
   Part 1 CSS is verbatim from analysis.html.
   Part 2 CSS is rewritten to sit under $SCOPE, because the two halves share
   class names ('high' and 'low' mean different things in each).
   ============================================================================ */

/* ---------- part 1: analysis (unscoped) ---------- */
$($A.Css)

/* ---------- part 2: attack flow (scoped under $SCOPE) ---------- */
$scopedFlowCss

$bulletinCss
</style>

$aCover

<!-- BULLETIN:SUMMARY -->$summary<!-- /BULLETIN:SUMMARY -->

$aRest

<section class="partrule">
  <div class="wrap">
    <span class="pnum">Part 2</span>
    <h2>ATT&amp;CK attack flow</h2>
    <p>How a compromise unfolds, tactic by tactic and in order. Part 1 established who is at
       risk and why; this part is how they get hit.</p>
  </div>
</section>

<div class="flowpart">
$($F.Body)
</div>

<!-- BULLETIN:DEFENCE -->$defence<!-- /BULLETIN:DEFENCE -->
"@

Write-Text $outPath $doc

# ---------------------------------------------------------------- report

Write-Host ""
Write-Host "=== subjects/$slug ==="
Write-Host "  part 1   reports/analysis.html  $($A.Body.Length) chars"
Write-Host "  part 2   reports/$($flows[0].Name)  $($F.Body.Length) chars"
Write-Host "  scoped   $($F.Css.Length) chars of CSS rewritten under $SCOPE"
if ($carried.Count -gt 0) {
    Write-Host "  carried  editorial regions preserved: $($carried -join ', ')"
} else {
    Write-Host "  editorial regions are placeholders - fill BULLETIN:SUMMARY and BULLETIN:DEFENCE"
}
Write-Host "  WROTE    subjects/$slug/bulletin/$outName  ($($doc.Length) chars)"
if ($priorPath -eq $legacyPath -and $legacyPath -ne $outPath) {
    [void]$warnings.Add("carried the editorial regions over from the old name; delete subjects/$slug/bulletin/bulletin.html")
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "  warnings:"
    $warnings | ForEach-Object { Write-Host "    - $_" }
}

Write-Host ""
Write-Host "Now run: .\scripts\Verify-Bulletin.ps1 -Path .\subjects\$slug"
exit 0
