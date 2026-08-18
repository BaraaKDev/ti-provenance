<#
.SYNOPSIS
    Extracts plain text from an ATT&CK mapping held in .docx, .xlsx, .csv, .md or .txt
    so it can be read directly. No third-party modules required.

.DESCRIPTION
    .docx / .xlsx are ZIP containers of XML. This reads them with the .NET
    compression classes built into Windows PowerShell 5.1 and flattens the
    content to pipe-delimited lines, one table row per line.

.EXAMPLE
    .\Extract-Mapping.ps1 -Path .\agrius-mapping.docx
    .\Extract-Mapping.ps1 -Path .\ttp-matrix.xlsx -Sheet 2
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,

    # 1-based worksheet index, .xlsx only.
    [int]$Sheet = 1
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Path)) {
    throw "File not found: $Path"
}
$full = (Resolve-Path -LiteralPath $Path).Path
$ext = [System.IO.Path]::GetExtension($full).ToLowerInvariant()

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-ZipEntryText {
    param([string]$ZipPath, [string]$EntryName)
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entry = $zip.Entries | Where-Object { $_.FullName -eq $EntryName } | Select-Object -First 1
        if ($null -eq $entry) { return $null }
        $stream = $entry.Open()
        try {
            $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
            try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
        } finally { $stream.Dispose() }
    } finally { $zip.Dispose() }
}

function Get-ZipEntryNames {
    param([string]$ZipPath)
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try { return @($zip.Entries | ForEach-Object { $_.FullName }) } finally { $zip.Dispose() }
}

function ConvertFrom-XmlEntity {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    $Text = $Text -replace '&lt;', '<'
    $Text = $Text -replace '&gt;', '>'
    $Text = $Text -replace '&quot;', '"'
    $Text = $Text -replace '&apos;', "'"
    # Ampersand last, so decoded text is not re-decoded.
    $Text = $Text -replace '&amp;', '&'
    return $Text
}

function Convert-DocxToText {
    param([string]$ZipPath)

    $xml = Get-ZipEntryText -ZipPath $ZipPath -EntryName 'word/document.xml'
    if ($null -eq $xml) { throw "Not a valid .docx (word/document.xml missing): $ZipPath" }

    # Drop deleted revision text so tracked changes do not pollute output.
    $xml = $xml -replace '(?s)<w:delText[^>]*>.*?</w:delText>', ''

    # Structural markers -> delimiters, before tags are stripped.
    $xml = $xml -replace '<w:tab[^>]*/>', "`t"
    $xml = $xml -replace '<w:br[^>]*/>', "`n"

    # Inside a table cell a paragraph break is just a space, so a multi-paragraph
    # cell does not break its row across several output lines.
    $xml = [regex]::Replace($xml, '(?s)<w:tc[^>]*>.*?</w:tc>', {
        param($m) $m.Value -replace '</w:p>', ' '
    })

    $xml = $xml -replace '</w:tc>', ' | '
    $xml = $xml -replace '</w:tr>', "`n"
    $xml = $xml -replace '</w:p>', "`n"
    $xml = $xml -replace '<[^>]+>', ''
    $xml = ConvertFrom-XmlEntity -Text $xml

    $lines = $xml -split "`n" | ForEach-Object {
        # Collapse the trailing ' | ' each table row picks up from its last cell.
        $line = $_ -replace '\s*\|\s*$', ''
        $line = $line -replace '[ ]{2,}', ' '
        $line.Trim()
    }
    return ($lines | Where-Object { $_ -ne '' })
}

function Convert-XlsxToText {
    param([string]$ZipPath, [int]$SheetIndex)

    $names = Get-ZipEntryNames -ZipPath $ZipPath
    $sheets = @($names | Where-Object { $_ -match '^xl/worksheets/sheet\d+\.xml$' } | Sort-Object)
    if ($sheets.Count -eq 0) { throw "Not a valid .xlsx (no worksheets found): $ZipPath" }
    if ($SheetIndex -lt 1 -or $SheetIndex -gt $sheets.Count) {
        throw "Sheet $SheetIndex out of range; workbook has $($sheets.Count) sheet(s)."
    }
    $target = $sheets[$SheetIndex - 1]

    # Shared string table: cells with t="s" index into this.
    $shared = @()
    $ssXml = Get-ZipEntryText -ZipPath $ZipPath -EntryName 'xl/sharedStrings.xml'
    if ($null -ne $ssXml) {
        foreach ($m in [regex]::Matches($ssXml, '(?s)<si>(.*?)</si>')) {
            $parts = [regex]::Matches($m.Groups[1].Value, '(?s)<t[^>]*>(.*?)</t>')
            $buf = ''
            foreach ($p in $parts) { $buf += $p.Groups[1].Value }
            $shared += (ConvertFrom-XmlEntity -Text $buf)
        }
    }

    $sheetXml = Get-ZipEntryText -ZipPath $ZipPath -EntryName $target
    $out = @()
    foreach ($rowMatch in [regex]::Matches($sheetXml, '(?s)<row[^>]*>(.*?)</row>')) {
        $cells = @()
        foreach ($cellMatch in [regex]::Matches($rowMatch.Groups[1].Value, '(?s)<c\b([^>]*)>(.*?)</c>')) {
            $attrs = $cellMatch.Groups[1].Value
            $body = $cellMatch.Groups[2].Value
            $value = ''
            if ($attrs -match 't="s"') {
                if ($body -match '(?s)<v>(.*?)</v>') {
                    $idx = [int]$Matches[1]
                    if ($idx -ge 0 -and $idx -lt $shared.Count) { $value = $shared[$idx] }
                }
            }
            elseif ($attrs -match 't="inlineStr"') {
                $buf = ''
                foreach ($p in [regex]::Matches($body, '(?s)<t[^>]*>(.*?)</t>')) { $buf += $p.Groups[1].Value }
                $value = ConvertFrom-XmlEntity -Text $buf
            }
            else {
                if ($body -match '(?s)<v>(.*?)</v>') { $value = ConvertFrom-XmlEntity -Text $Matches[1] }
            }
            $cells += ($value -replace '[\r\n]+', ' ').Trim()
        }
        $line = ($cells -join ' | ').Trim()
        if ($line -replace '[\s|]', '') { $out += $line }
    }
    return $out
}

switch ($ext) {
    '.docx' { Convert-DocxToText  -ZipPath $full }
    '.xlsx' { Convert-XlsxToText  -ZipPath $full -SheetIndex $Sheet }
    '.csv'  { Get-Content -LiteralPath $full -Encoding UTF8 }
    '.md'   { Get-Content -LiteralPath $full -Encoding UTF8 }
    '.txt'  { Get-Content -LiteralPath $full -Encoding UTF8 }
    default { throw "Unsupported extension '$ext'. Supported: .docx .xlsx .csv .md .txt" }
}
