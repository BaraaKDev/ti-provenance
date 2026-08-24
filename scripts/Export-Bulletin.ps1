<#
.SYNOPSIS
    Renders a merged threat bulletin to PDF in output/ - the deliverable a reader receives.

.DESCRIPTION
    Step 5, the last one. Point it at a subject folder. It reads
    bulletin/<slug>-threat-bulletin.html and writes output/<slug>-threat-bulletin.pdf at the
    project root, so every finished bulletin lands in one place regardless of subject.

    Conversion runs through headless Edge or Chrome. This machine has no Python and no
    wkhtmltopdf; the browser engine is already installed and renders the same CSS the HTML
    was designed against, so it is the only route that guarantees the PDF matches the page.

    Two things the wrapper has to fix before printing:

      1. The bulletin is an HTML FRAGMENT - no doctype, html, head or body. A browser will
         render it in quirks mode, so it is wrapped in a real document first.
      2. Print defaults would destroy the report. Backgrounds are off by default, and this
         design encodes meaning in colour - risk meters, severity chips, phase heat. The
         wrapper forces print-color-adjust and stops cards breaking across pages.

    Exit 0 = written, 1 = refused or the engine failed.

.EXAMPLE
    .\scripts\Export-Bulletin.ps1 -Path .\samples\akira
    .\scripts\Export-Bulletin.ps1 -Path .\samples\akira -Force
    Get-ChildItem .\samples -Directory | .\scripts\Export-Bulletin.ps1 -Force
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [Alias('FullName')]
    [string[]]$Path,

    # Overwrite an existing PDF.
    [switch]$Force,

    # Letter by default - this project is North American. A4 for everywhere else.
    [ValidateSet('Letter', 'A4')]
    [string]$PageSize = 'Letter',

    # Export without running Verify-Bulletin first. The gate exists because the PDF is a
    # faithful render of whatever it is handed, including a bulletin with a surviving
    # placeholder or no remediation guidance at all - and the PDF is the artefact that
    # leaves the project, so an unchecked one is the expensive kind of mistake.
    [switch]$SkipVerify
)

begin {
    $ErrorActionPreference = 'Stop'
    $anyFailed = $false
    # Counted so a pipeline that matched nothing cannot report success - see the verifiers.
    $checked = 0

    $projectRoot = Split-Path $PSScriptRoot -Parent
    $outputDir   = Join-Path $projectRoot 'output'

    function Find-Engine {
        $candidates = @(
            (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
            (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
            (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
            (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
            (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
        )
        foreach ($c in $candidates) {
            if ($c -and (Test-Path -LiteralPath $c)) { return $c }
        }
        return $null
    }

    # Print rules appended AFTER the bulletin's own CSS so they win on equal specificity.
    function Get-PrintCss {
        param([string]$Size)
        return @"
/* Page numbering lives in the page margin, which is the only place a running element can
   sit: string-set is unimplemented everywhere, but Chromium does honour @page margin boxes,
   and this export is Chromium-only by design. The bottom margin is wider than the top to
   make room for it. The cover is page one and carries no furniture. */
@page {
  size: $Size;
  margin: 12mm 10mm 16mm;
  @bottom-left {
    content: counter(page);
    font-family: ui-monospace, Consolas, monospace;
    font-size: 8pt;
    color: #55607a;
    vertical-align: top;
  }
}
@page :first { @bottom-left { content: ""; } }

/* The whole report encodes meaning in colour - sector risk meters, CVSS severity chips,
   phase heat, the accent that asserts the actor's objective. Printing it monochrome does
   not just look worse, it removes information. */
*, *::before, *::after {
  -webkit-print-color-adjust: exact !important;
  print-color-adjust: exact !important;
}

/* The screen layout centres content in a 940px column. A Letter page minus margins is
   about 740px, so without this the right edge is clipped rather than reflowed. */
.wrap { max-width: 100% !important; padding: 0 !important; }

/* Screen section padding is generous; on paper it wastes most of a page. */
section { padding: 26px 0 !important; }
.cover .wrap { padding-top: 34px !important; padding-bottom: 30px !important; }
.hero { padding: 30px 0 26px !important; }

/* Horizontal scroll containers cannot scroll on paper - let them reflow instead. */
.table-wrap { overflow-x: visible !important; }
table { font-size: 12px !important; }

/* Anything boxed should survive intact or move whole to the next page. */
.card, .phase, .sector, .takeaway, .weapon, .fix, .state, .entry,
.bskey li, .bsteps li, .sources li, .callout, .note, .legend, .risklegend {
  break-inside: avoid !important;
  page-break-inside: avoid !important;
}

/* A heading stranded at the foot of a page is the classic print defect. break-after alone
   is not enough: a .section-head holds an eyebrow, an h2 and a standfirst, and the page can
   break BETWEEN them - leaving the eyebrow alone at the foot of a page with its own heading
   overleaf. It has to move as one block. */
h1, h2, h3, .section-head, .partrule { break-after: avoid !important; page-break-after: avoid !important; }
.section-head { break-inside: avoid !important; page-break-inside: avoid !important; }

/* EVERY SECTION STARTS A PAGE.
   A bulletin is a reference document - printed, filed, and flipped through to find one
   part. A section that begins two thirds down a page is hard to locate and reads as a
   continuation of the section above it rather than a new subject. On screen the coloured
   band and the rule above each .section-head carry that separation; on paper a page break
   is what does it. The cost is trailing whitespace at the foot of some pages, which is the
   correct trade for a document meant to be navigated rather than scrolled. */
section, footer { break-before: page !important; page-break-before: always !important; }

/* Two deliberate exceptions.
   The cover is page one, so nothing precedes it to break from.
   The Part 2 divider is an introduction to the flow hero, not a section in its own right -
   left alone it would take a whole page to say two lines, so the hero is pinned to it. */
.cover { break-before: auto !important; page-break-before: auto !important; }
.flowpart > header { break-before: avoid !important; page-break-before: avoid !important; }

/* The hero fact grids are auto-fit at minmax(150px, 1fr). On screen that gives three columns
   for six fields - two tidy rows. The narrower print column fits four, so six fields leave
   two orphan slots, and because the container paints --hair behind a 1px gap those orphans
   render as a solid grey panel that reads as a mistake. Both grids carry exactly six fields,
   so pinning three columns restores the intended two rows. .covermeta now pins three columns
   itself; it is kept here so a report built before that change still prints right. */
.covermeta, .facts { grid-template-columns: repeat(3, 1fr) !important; }

/* URLs are long; let them wrap rather than overflow the text column. */
a { word-break: break-word; }
"@
    }

    function Write-Text {
        param([string]$File, [string]$Text)
        [System.IO.File]::WriteAllText($File, $Text, (New-Object System.Text.UTF8Encoding($false)))
    }

    $engine = Find-Engine
    if ($null -eq $engine) {
        Write-Host "REFUSED: no Edge or Chrome found - one of them provides the PDF engine."
        Write-Host "         Looked in Program Files, Program Files (x86) and LocalAppData."
        exit 1
    }
    $engineName = Split-Path $engine -Leaf
    Write-Host ""
    Write-Host "engine: $engineName ($((Get-Item $engine).VersionInfo.ProductVersion))  page: $PageSize"
}

process {
    foreach ($p in $Path) {
        if (-not (Test-Path -LiteralPath $p)) { throw "Not found: $p" }
        $checked++
        $item = Get-Item -LiteralPath $p
        $dir  = if ($item.PSIsContainer) { $item.FullName } else { $item.DirectoryName }
        $slug = Split-Path $dir -Leaf
        $area = Split-Path (Split-Path $dir -Parent) -Leaf

        Write-Host ""
        Write-Host "=== $area/$slug ==="

        $bDir = Join-Path $dir 'bulletin'
        $src = $null
        if (Test-Path -LiteralPath $bDir) {
            $found = @(Get-ChildItem -LiteralPath $bDir -Filter '*-threat-bulletin.html' -File)
            if ($found.Count -gt 1) {
                Write-Host "  REFUSED: $($found.Count) bulletins in bulletin/ - expected exactly one."
                $anyFailed = $true
                continue
            }
            if ($found.Count -eq 1) { $src = $found[0].FullName }
        }
        if ($null -eq $src) {
            Write-Host "  SKIP: no bulletin to export - run Merge-Bulletin.ps1 first."
            continue
        }

        if (-not (Test-Path -LiteralPath $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir | Out-Null
        }
        $pdfName = "$slug-threat-bulletin.pdf"
        $pdfPath = Join-Path $outputDir $pdfName

        if ((Test-Path -LiteralPath $pdfPath) -and -not $Force) {
            Write-Host "  REFUSED: output/$pdfName exists. Re-run with -Force."
            $anyFailed = $true
            continue
        }

        # Gate on the verifier rather than trusting the operator to have run it. Its output is
        # suppressed unless it fails, so a clean export stays quiet.
        if (-not $SkipVerify) {
            $vb = Join-Path $PSScriptRoot 'Verify-Bulletin.ps1'
            if (Test-Path -LiteralPath $vb) {
                $global:LASTEXITCODE = 0
                $vout = (& $vb -Path $dir 6>&1 | Out-String)
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  REFUSED: Verify-Bulletin failed - not exporting an unchecked bulletin."
                    ($vout -split "`r?`n" | Where-Object { $_ -match '\[FAIL\]' }) | ForEach-Object { Write-Host "         $($_.Trim())" }
                    Write-Host "         Fix it, or pass -SkipVerify if you know why you are overriding."
                    $anyFailed = $true
                    continue
                }
            }
        }

        # Wrap the fragment in a real document and append the print rules.
        $fragment = Get-Content -LiteralPath $src -Raw -Encoding UTF8
        $title = $slug
        if ($fragment -match '(?s)<title>(.*?)</title>') { $title = $matches[1].Trim() }
        $printCss = Get-PrintCss -Size $PageSize
        $doc = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>$title</title>
</head>
<body>
$fragment
<style>
/* ===== print rules appended by Export-Bulletin.ps1 ===== */
$printCss
</style>
</body>
</html>
"@

        $stamp   = [Guid]::NewGuid().ToString('N').Substring(0, 8)
        $tmpHtml = Join-Path $env:TEMP "tirep-$slug-$stamp.html"
        $tmpProf = Join-Path $env:TEMP "tirep-profile-$stamp"
        Write-Text $tmpHtml $doc

        # A dedicated user-data-dir matters: without it, headless will attach to an already
        # running browser instance and exit without ever printing.
        $uri = ([Uri]$tmpHtml).AbsoluteUri
        $argLine = '--headless=new --disable-gpu --disable-extensions --no-first-run ' +
                   '--no-pdf-header-footer --run-all-compositor-stages-before-draw ' +
                   '--virtual-time-budget=15000 --log-level=3 ' +
                   ('--user-data-dir="{0}" --print-to-pdf="{1}" "{2}"' -f $tmpProf, $pdfPath, $uri)

        # Chromium writes its byte count to stdout and benign task-manager warnings to
        # stderr. Captured to files so this script's own output stays readable; stderr is
        # surfaced only if the run actually fails.
        $outLog = Join-Path $env:TEMP "tirep-out-$stamp.log"
        $errLog = Join-Path $env:TEMP "tirep-err-$stamp.log"
        $proc = Start-Process -FilePath $engine -ArgumentList $argLine -NoNewWindow -Wait -PassThru `
                              -RedirectStandardOutput $outLog -RedirectStandardError $errLog
        $code = $proc.ExitCode
        $engineErr = ''
        if (Test-Path -LiteralPath $errLog) { $engineErr = (Get-Content -LiteralPath $errLog -Raw -ErrorAction SilentlyContinue) }

        Remove-Item -LiteralPath $tmpHtml -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tmpProf -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $outLog  -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $errLog  -Force -ErrorAction SilentlyContinue

        if (-not (Test-Path -LiteralPath $pdfPath)) {
            Write-Host "  FAIL: $engineName exited $code and produced no PDF."
            if ($engineErr) { Write-Host "        engine said: $(($engineErr -split "`n" | Select-Object -First 3) -join ' / ')" }
            $anyFailed = $true
            continue
        }

        # A browser that fails mid-render can still leave a truncated file behind, so check
        # the header rather than trusting the exit code.
        $bytes = [System.IO.File]::ReadAllBytes($pdfPath)
        $magic = [System.Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min(5, $bytes.Length))
        if ($magic -ne '%PDF-') {
            Write-Host "  FAIL: output/$pdfName is not a PDF (header '$magic')."
            $anyFailed = $true
            continue
        }

        $raw = [System.Text.Encoding]::ASCII.GetString($bytes)
        $pages = ([regex]::Matches($raw, '/Type\s*/Page[^s]')).Count
        $kb = [Math]::Round($bytes.Length / 1KB)

        Write-Host "  source   bulletin/$(Split-Path $src -Leaf)"
        Write-Host "  WROTE    output/$pdfName  ($kb KB$(if ($pages -gt 0) { ", ~$pages pages" }))"
    }
}

end {
    Write-Host ""
    if ($checked -eq 0) {
        Write-Host "RESULT: NOTHING EXPORTED - no input matched."
        Write-Host "        Point this at a subject folder, e.g. .\samples\<slug>."
        exit 1
    }
    if ($anyFailed) { Write-Host "RESULT: failures present."; exit 1 }
    Write-Host "RESULT: clean. $checked subject(s) processed."
    exit 0
}
