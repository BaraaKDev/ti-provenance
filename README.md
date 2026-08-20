# TI-Provenance

A threat-intelligence reporting pipeline that produces a finished, sourced **threat bulletin** as
a PDF — and refuses to produce one when the evidence does not hold up.

The name is the point. Anything can generate a threat report. The problem with a generated threat
report is that you cannot tell which sentences are load-bearing, which are inference, and which are
invention. This pipeline is built so that every factual claim traces to an approved source, the
provenance survives every step, and the checks fail the run rather than printing a warning.

## What it produces

A bulletin is one document in two halves:

| Part | What it answers |
|---|---|
| **1 — Analysis** | Who or what this is, what it has done in order, what it means, and **who is at risk and why** |
| **2 — Attack flow** | **How** a compromise actually unfolds, tactic by tactic, mapped to MITRE ATT&CK |

The split is deliberate. Part 1 never lists attack techniques and Part 2 never re-argues risk, so
the same claim never exists in two places that can drift apart.

Six worked examples ship in [`output/`](output/), covering all three subject types and all three
CVE relationships:

| Bulletin | Subject type | Notes |
|---|---|---|
| Akira | campaign | Ransomware crew whose every documented way in is a patchable edge-appliance flaw |
| Agrius | campaign | Iranian destruction crew running wipers dressed as ransomware |
| Andariel | actor | North Korean espionage that funds itself with ransomware |
| Log4j | vulnerability · remediation cascade | Four CVEs where three were revealed by the fix for the one before |
| ProxyShell | vulnerability · exploit chain | Three Exchange flaws that only matter in sequence |
| Windows August 2026 | vulnerability · independent set | Three unrelated flaws; the lowest-scoring one is the only one being exploited |

## How it is built

Three skills, each self-contained and unaware of the others, plus a small set of project scripts
that join them up:

```
analysis  ──→  analysis.json  ─┐
                               ├──→  merge  ──→  verify  ──→  PDF
mapping   ──→  mapping.json   ─┘
                    └──→  attack-flow report
```

- **Analysis** researches the subject and writes the prose half plus a structured handoff.
- **Mapping** derives which ATT&CK tactics and techniques the subject actually used.
- **Visualizer** renders a finished mapping as a vertical attack flow. It will not do the mapping
  itself — inventing technique IDs to fill a diagram produces intelligence that is wrong but looks
  authoritative.

The skills share a JSON contract rather than calling each other, so any one of them can be run on
its own against a hand-written input.

## What keeps it honest

The interesting engineering is in the refusals.

- **A source allowlist.** Research comes only from ~50 tiered sources. Attribution needs a primary,
  not a news outlet reporting a primary. A claim that cannot be traced does not go in.
- **Provenance survives the handoff.** Chronology entries carry integer indices into the source
  list, and the validator rejects an index that does not resolve.
- **Checks fail the run.** Verifiers exit non-zero; the PDF exporter gates on the verifier, so a
  bulletin with a surviving placeholder or no remediation guidance cannot become a PDF.
- **Zero input is a failure, not a pass.** Every verifier refuses an empty file set rather than
  reporting "clean, 0 files checked".
- **The reader never sees the pipeline.** No skill name, internal path or template jargon may
  appear in text a reader sees, and three separate gates enforce it against the rendered output.
- **Levels need reasons.** A sector risk row without a justification is rejected — "a level with no
  justification is a guess with a colour on it".

`scripts/Test-Pipeline.ps1` runs the whole regression, including the documented invocation forms,
the refusal paths, contract drift between the skill copies, and a PDF round trip.

## Running it

```powershell
.\scripts\Merge-Bulletin.ps1  -Path .\samples\<slug>      # join the two halves
.\scripts\Verify-Bulletin.ps1 -Path .\samples\<slug>      # 17 checks; exit 1 on any failure
.\scripts\Export-Bulletin.ps1 -Path .\samples\<slug>      # gated PDF into output/
.\scripts\Test-Pipeline.ps1 -IncludeExport                 # the full regression
```

Environment notes, because they shaped the tooling:

- **Windows PowerShell 5.1**, and there is no Python on the target machine, so everything is
  PowerShell with no third-party modules.
- Scripts are deliberately **pure ASCII** — PS 5.1 reads `.ps1` as ANSI without a BOM, so a stray
  em-dash is a parser error — and every data read passes `-Encoding UTF8`.
- PDF export drives **headless Edge or Chrome**. Page numbering uses `@page` margin boxes, which
  Chromium honours and `string-set` does not.

## Repository layout

```
.claude/skills/     the three skills: analysis, mapping, visualizer
scripts/            merge, verify, export, and the regression harness
samples/<slug>/     handoff/ (JSON)  reports/ (each half)  bulletin/ (merged)
output/             the finished PDFs - the artefact that leaves the project
CLAUDE.md           how the pieces fit together, and the traps worth remembering
```

`output/*.pdf` is tracked on purpose. It is derived and regenerable, but for an intelligence
product the question "what exactly did we publish, and when" has to be answerable.
