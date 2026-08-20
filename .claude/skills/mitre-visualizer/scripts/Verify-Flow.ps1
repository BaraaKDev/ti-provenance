<#
.SYNOPSIS
    Runs the SKILL.md "Step 4 - Verify" checks against a finished attack-flow page.

.DESCRIPTION
    Mechanical checks only: structure, tokens, formatting. It cannot tell you whether a
    technique is mapped to the right tactic or whether the phase copy is any good; those
    stay human judgment. Exit code 0 = all passed, 1 = at least one failure.

.EXAMPLE
    .\Verify-Flow.ps1 -Path .\subjects\andariel\reports\andariel-G0138-attack-flow.html
    Get-ChildItem .\subjects\*\reports\*-flow.html | .\Verify-Flow.ps1
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
    # zero files, process never runs, and without this the script prints "clean" and exits 0
    # - a verifier that passes because it checked nothing is worse than no verifier.
    $checked = 0

    function Test-Check {
        param([string]$Name, [bool]$Ok, [string]$Detail)
        $mark = if ($Ok) { 'PASS' } else { 'FAIL' }
        $line = "  [{0}] {1}" -f $mark, $Name
        if ($Detail) { $line += " - $Detail" }
        Write-Host $line
        return $Ok
    }
}

process {
    foreach ($p in $Path) {
        if (-not (Test-Path -LiteralPath $p)) { throw "File not found: $p" }
        $checked++
        $full = (Resolve-Path -LiteralPath $p).Path
        $name = Split-Path $full -Leaf
        # -Encoding UTF8 is REQUIRED. Without it PS 5.1 decodes a BOM-less UTF-8 file as
        # ANSI, mangling every non-ASCII character before the regexes run.
        $t = Get-Content -LiteralPath $full -Raw -Encoding UTF8

        Write-Host ""
        Write-Host "=== $name ==="
        $results = @()

        # --- 1. Title -------------------------------------------------------
        $title = [regex]::Match($t, '(?is)<title>(.*?)</title>')
        $results += Test-Check 'has <title>' $title.Success $(if ($title.Success) { $title.Groups[1].Value.Trim() })

        # --- 2. No unreplaced placeholders ----------------------------------
        $ph = [regex]::Matches($t, '\{\{[A-Z0-9_]+\}\}')
        $results += Test-Check 'no {{PLACEHOLDER}} left' ($ph.Count -eq 0) $(if ($ph.Count) { "$($ph.Count) remaining: " + (($ph | ForEach-Object { $_.Value } | Select-Object -Unique) -join ', ') })

        # --- 3-5. Per-flow structure ----------------------------------------
        # A page may hold more than one .flow container: in MODE SET of
        # vulnerability-flow-template.html every vulnerability gets its own. Each is
        # checked independently, because node numbering restarts per flow and a
        # vulnerability that reaches no objective legitimately has no impact phase.
        $flowHits = [regex]::Matches($t, 'class="flow"')
        $segments = @()
        if ($flowHits.Count -eq 0) {
            $segments = @($t)
        } else {
            for ($i = 0; $i -lt $flowHits.Count; $i++) {
                $start = $flowHits[$i].Index
                if (($i + 1) -lt $flowHits.Count) { $end = $flowHits[$i + 1].Index } else { $end = $t.Length }
                $segments += $t.Substring($start, $end - $start)
            }
        }
        $multi = $segments.Count -gt 1

        $parityBad = @(); $seqBad = @(); $impactBad = @(); $totalPhases = 0
        for ($s = 0; $s -lt $segments.Count; $s++) {
            $seg = $segments[$s]
            if ($multi) { $lbl = "flow $($s + 1)" } else { $lbl = "flow" }

            $pm = [regex]::Matches($seg, 'class="phase[^"]*"')
            # Matches "transition" and its variants such as "transition handoff",
            # so a styled boundary transition still counts toward parity.
            $tr = ([regex]::Matches($seg, 'class="transition[^"]*"')).Count
            $totalPhases += $pm.Count
            if ($pm.Count -gt 0 -and $tr -ne ($pm.Count - 1)) {
                $parityBad += "$lbl has $($pm.Count) phases / $tr transitions"
            }

            $nd = @([regex]::Matches($seg, 'class="node">\s*(\d+)\s*<') | ForEach-Object { [int]$_.Groups[1].Value })
            $ok = $nd.Count -gt 0
            for ($i = 0; $i -lt $nd.Count; $i++) { if ($nd[$i] -ne ($i + 1)) { $ok = $false } }
            if (-not $ok) { $seqBad += "$lbl : $($nd -join ',')" }

            $ii = @()
            for ($i = 0; $i -lt $pm.Count; $i++) { if ($pm[$i].Value -match 'impact') { $ii += $i } }
            # An impact phase is OPTIONAL everywhere. A flow whose objective is unknown or
            # unreported correctly has none, and demanding one would push the author to
            # invent an objective - the exact failure this skill exists to prevent. Whether
            # a flow *should* carry an objective is editorial judgment, not a mechanical
            # check; this only validates placement.
            if ($ii.Count -gt 1) {
                $impactBad += "$lbl has $($ii.Count) impact phases"
            } elseif ($ii.Count -eq 1 -and $ii[0] -ne ($pm.Count - 1)) {
                $impactBad += "$lbl impact is phase $($ii[0] + 1) of $($pm.Count), not last"
            }
        }

        $results += Test-Check 'transitions = phases - 1, per flow' ($parityBad.Count -eq 0) $(if ($parityBad.Count) { $parityBad -join '; ' } else { "$($segments.Count) flow(s), $totalPhases phases" })
        $results += Test-Check 'nodes numbered 1..n, per flow' ($seqBad.Count -eq 0) $(if ($seqBad.Count) { $seqBad -join '; ' })
        $results += Test-Check 'impact phase placement' ($impactBad.Count -eq 0) $(if ($impactBad.Count) { $impactBad -join '; ' })

        # --- 6. Tag balance --------------------------------------------------
        $tagBad = @()
        foreach ($tag in 'div', 'span', 'svg', 'details', 'section', 'table') {
            $open = ([regex]::Matches($t, "<$tag\b")).Count
            $close = ([regex]::Matches($t, "</$tag>")).Count
            if ($open -ne $close) { $tagBad += "$tag $open/$close" }
        }
        $results += Test-Check 'tags balanced' ($tagBad.Count -eq 0) $(if ($tagBad.Count) { $tagBad -join '; ' } else { 'div, span, svg, details, section, table' })

        # --- 7. Every token resolves from :root -----------------------------
        # Gather from every :root block, not just the first. Reading only the first turns
        # one stray block into a false "every token is undefined" cascade.
        $defined = @(
            [regex]::Matches($t, '(?s):root[^{]*\{(.*?)\}') |
                ForEach-Object { [regex]::Matches($_.Groups[1].Value, '(--[a-z0-9-]+)\s*:') } |
                ForEach-Object { $_.Groups[1].Value } |
                Sort-Object -Unique
        )
        $used = @([regex]::Matches($t, 'var\((--[a-z0-9-]+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $undef = @($used | Where-Object { $defined -notcontains $_ })
        $results += Test-Check 'all var() tokens defined in :root' ($undef.Count -eq 0) $(if ($undef.Count) { "undefined: " + ($undef -join ', ') } else { "$($used.Count) tokens" })

        # --- 8. Light-theme only --------------------------------------------
        # Strip CSS comments first: the template documents the dark rules it does not use.
        $noComments = [regex]::Replace($t, '(?s)/\*.*?\*/', '')
        $darkHits = [regex]::Matches($noComments, 'prefers-color-scheme|\[data-theme|color-scheme:\s*dark')
        $results += Test-Check 'no dark-theme block' ($darkHits.Count -eq 0) $(if ($darkHits.Count) { "$($darkHits.Count) hit(s)" })

        # --- 9. Technique ID formatting -------------------------------------
        # A sub-technique is exactly three digits: T1059.003, never T1059.3 or T1059.03.
        $badIds = @([regex]::Matches($t, 'T\d{4}\.\d{1,2}(?!\d)') | ForEach-Object { $_.Value } | Sort-Object -Unique)
        $allIds = @([regex]::Matches($t, 'class="tid">\s*(T\d{4}(?:\.\d+)?)\s*<') | ForEach-Object { $_.Groups[1].Value })
        $results += Test-Check 'technique IDs well formed' ($badIds.Count -eq 0) $(if ($badIds.Count) { "malformed: " + ($badIds -join ', ') } else { "$($allIds.Count) ID chips" })

        # --- 10. Every tactic icon chip actually contains an icon -----------
        $ticons = ([regex]::Matches($t, 'class="ticon[^"]*"')).Count
        $ticonsWithSvg = ([regex]::Matches($t, '(?s)class="ticon[^"]*"[^>]*>\s*<svg')).Count
        $results += Test-Check 'every .ticon contains an <svg>' ($ticons -eq $ticonsWithSvg) "$ticonsWithSvg/$ticons"

        # --- 11. Icons inherit colour ---------------------------------------
        # A hard-coded stroke would break the heat/impact colour system.
        $hardCoded = [regex]::Matches($t, '<svg[^>]*stroke="(?!currentColor)[^"]+"')
        $results += Test-Check 'icons use stroke="currentColor"' ($hardCoded.Count -eq 0) $(if ($hardCoded.Count) { "$($hardCoded.Count) hard-coded stroke(s)" })

        # --- 12. Nothing about how the report was built -----------------------
        # A reader has no idea what this skill is called, which template produced the page,
        # or what a JSON handoff is. Every one of these strings describes the build rather
        # than the subject, so none of them may appear in text the reader sees. Checked
        # against VISIBLE text only: the same words are legitimate in HTML and CSS comments,
        # which is exactly where authoring guidance is supposed to live.
        $visible = [regex]::Replace($t, '(?s)<!--.*?-->', '')
        $visible = [regex]::Replace($visible, '(?s)<style.*?</style>', '')
        $visible = $visible -replace '<[^>]*>', ''
        # Deliberately does NOT name the other skills: this one must stand alone, and naming
        # them here would be a reference to them. '\bskills?\b' catches the shape instead -
        # a threat report has no reason to use the word at all, so "the <whatever> skill"
        # trips it whichever skill is named.
        $internals = @('mitre-visualizer', '\bskills?\b', 'TI-Reporting',
                       'analysis\.json', 'mapping\.json', 'subjects/', 'MODE CHAIN', 'MODE SET',
                       '[a-z0-9-]+-flow\.html', '[a-z0-9-]+-template\.html', 'analysis\.html')
        $leaked = @()
        foreach ($needle in $internals) {
            $m = [regex]::Match($visible, $needle)
            if ($m.Success) { $leaked += $m.Value }
        }
        $results += Test-Check 'no build or skill references in visible text' ($leaked.Count -eq 0) $(
            if ($leaked.Count) { "leaked: " + (($leaked | Sort-Object -Unique) -join ', ') })

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
        Write-Host "        Flow reports live in subjects/<slug>/reports/. A glob that misses"
        Write-Host "        them verifies nothing while looking like a pass."
        exit 1
    }
    if ($anyFailed) { Write-Host "RESULT: failures present."; exit 1 }
    Write-Host "RESULT: clean. $checked file(s) checked."
    exit 0
}
