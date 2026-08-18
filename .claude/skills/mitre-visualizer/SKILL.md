---
name: mitre-visualizer
description: Renders a COMPLETED MITRE ATT&CK mapping as a vertical attack-flow report for a threat actor, a vulnerability/CVE set or chain, or an actor exploiting specific CVEs. Its preferred input is the JSON handoff in subjects/<slug>/ (analysis.json and mapping.json, both optional), but it also accepts a mapping pasted inline or held in a CSV, .xlsx, .docx, .md or .txt file. Use when techniques are already assigned to tactics and the intrusion needs rendering as a flow through initial access, execution, persistence, stealth, lateral movement and impact. Do NOT use this to perform the mapping itself; it only visualizes a mapping that already exists.
---

# MITRE ATT&CK Attack-Flow Visualizer

Renders a finished ATT&CK mapping as a single-page vertical kill-chain: one node per tactic,
techniques and observed tooling inside each node, and a labeled transition explaining why
each phase enables the next.

## When this runs — and when it does not

**Run it** when a mapping already exists and the analyst wants it visualized.

**Do not run it** to build the mapping. If the input is a raw report, a blog post, or a
narrative with no techniques assigned to tactics, stop and say so: the mapping is the
analyst's judgment call, and inventing technique IDs to fill a diagram produces intelligence
that is wrong but looks authoritative. Ask for the mapping, then visualize it.

If the mapping is *partial* — techniques with no tooling, or tactics with gaps — visualize
what is there and mark the gaps honestly rather than filling them in.

## Input and output

```
subjects/<slug>/handoff/analysis.json  ─┐
                                ├─→  this skill  ─→  subjects/<slug>/reports/<name>-flow.html
subjects/<slug>/handoff/mapping.json   ─┘
```

Two JSON handoff files, each owned by one producing step. **Both are optional.** They exist
only when a pipeline run produced them; invoked on its own this skill works from whatever
the analyst supplies directly. Nothing here depends on another skill existing.

**Path convention.** Paths starting `references/`, `guides/` or `scripts/` are relative to
this skill folder. Paths starting `subjects/` are relative to the **project root**. Run the
scripts from the project root.

## Step 1 — Read the mapping

**Preferred input: the JSON handoff** in `subjects/<slug>/`. Validate first, then read:

```powershell
.\.claude\skills\mitre-visualizer\scripts\Verify-Mapping.ps1 -Path .\subjects\<slug>
```

It validates whichever files are present and cross-checks them when both are. A **missing**
file is reported and skipped, not failed — that is the standalone case. A file that is
present and malformed **is** a failure.

| File | Fields this skill reads |
|---|---|
| `analysis.json` | `subject_type` (picks the template), `matrix` (tactic order), `objective` (accent + impact phase), `cves` + `vuln_relationship` (chain vs set), `subject` · `attack_id` · `aliases` · `facts` (hero), `confidence` · `sources` (footer) |
| `mapping.json` | `tactics[]` → phases, `techniques[]` → rows, `via_cve` → CVE wiring, `arsenal[]` → the Arsenal section |

The full contract is `references/handoff-schema.md`. `subjects/agrius/handoff/` holds a
validated worked pair.

**If only `mapping.json` is present**, you have techniques but no framing — establish subject
type, objective and CVE relationship yourself, and ask rather than guess.

**Anything else** — pasted inline, or a loose `.csv` / `.docx` / `.xlsx` / `.md` / `.txt`:

```powershell
.\.claude\skills\mitre-visualizer\scripts\Extract-Mapping.ps1 -Path <file>
.\.claude\skills\mitre-visualizer\scripts\Extract-Mapping.ps1 -Path <file> -Sheet 2
```

One line per paragraph or table row, cells joined by ` | `. No Python and no third-party
modules — this machine has no Python interpreter, so never reach for one.

Normalize into the same shape the handoff carries:

```
tactic → [ { technique_id, technique_name, how_the_subject_uses_it, tooling[], via_cve? } ]
```

With a loose input you must also establish what the frontmatter would have told you —
subject type, matrix, objective, CVE relationship, confidence. **Ask rather than guess**:
picking the wrong subject type or CVE relationship produces a report that asserts something
false.

## Step 2 — Route to the right guide

**Read the guide for your subject, then follow it.** Each names its template and the sections
that report type must have. Do not mix them, and do not write two half-reports when one
combined report is called for.

| The subject is… | Read this guide | Sections |
|---|---|---|
| A threat actor, no specific CVE | `guides/threat-actor-report.md` | The Intrusion · The Arsenal |
| Vulnerabilities, no specific actor — one CVE, several, or a chain | `guides/vulnerability-report.md` | Vulnerabilities · The Intrusion · Remediation |
| **A named actor exploiting named CVEs** | `guides/campaign-report.md` | Vulnerabilities · The Intrusion · The Arsenal · Remediation |

If the subject names **both** an actor and the vulnerabilities they exploit, it is a campaign
report — not an actor report with a CVE mentioned in passing.

## Step 3 — Build the page

Every report is built from three things, in this order:

1. **The template named by your guide**, in `references/templates/`. Copy it and fill in the
   `{{PLACEHOLDER}}` slots. Never hand-roll a flow page from scratch, and never restyle one
   from memory — the CSS is the contract.
2. **`references/tactic-icons.md`** — one icon per tactic, covering all three ATT&CK matrices.
   `references/icon-sheet.html` renders them all at working size with copyable source if you
   would rather see them than read path data.
3. **The worked examples named by your guide**, in `subjects/<slug>/reports/` — the standard
   for phase copy, technique density and transition wording.

**`references/flow-craft.md` carries everything shared across all three report types**:
tactic ordering for Enterprise, ICS and Mobile; per-phase writing rules; how to order
techniques inside a phase; the objective phase and its icon; heat; accent retuning; coverage
gaps; and the checks a script cannot make. Read it alongside your guide.

## Step 4 — Verify before publishing

```powershell
$v = ".\.claude\skills\mitre-visualizer\scripts\Verify-Flow.ps1"
& $v -Path .\subjects\<slug>\reports\<name>-flow.html
Get-ChildItem .\subjects\*\reports\*-flow.html | & $v   # every report in the project
```

**The `reports\` segment is load-bearing.** A glob that misses it matches zero files. The
script now refuses that case with `NOTHING CHECKED` and exit 1 rather than reporting a pass,
but a green line that says `0 file(s) checked` is still not a verification.

Eleven mechanical checks: title present, no leftover placeholders, transitions = phases − 1
per flow, sequential node numbering per flow, impact-phase placement, tag balance, every
`var()` token defined in `:root`, no dark-theme block, technique-ID formatting, every
`.ticon` containing an `<svg>`, and every icon using `stroke="currentColor"`. Exit 0 clean,
1 on any failure. Fix failures before publishing — do not hand-wave a red check.

An impact phase is **optional**: the checker validates only that if one exists there is
exactly one and it comes last. A flow whose objective is unknown correctly has none.

Then work the hand checks in `references/flow-craft.md` §3, which cover what the script
cannot judge — above all, **never "correct" an unfamiliar technique ID from memory.**

Save the HTML in `subjects/<slug>/reports/`, beside the analysis report and one level up from
the `handoff/` it was built from.

## Files

```
.claude/skills/mitre-visualizer/
  SKILL.md                            this router
  guides/
    threat-actor-report.md            actor only
    vulnerability-report.md           CVEs only — carries the two-mode decision
    campaign-report.md                actor + CVEs
  references/
    handoff-schema.md                 contract for both JSON handoff files
    flow-craft.md                     shared: tactic order, phase craft, hand checks
    tactic-icons.md                   an icon for every tactic in all three matrices
    icon-sheet.html                   those icons rendered, with copyable source
    templates/                        threat- · vulnerability- · threat-vuln-flow-template.html
  scripts/
    Extract-Mapping.ps1               .docx/.xlsx/.csv → text
    Verify-Mapping.ps1                validates the JSON handoff (Step 1)
    Verify-Flow.ps1                   validates a rendered report (Step 4)

subjects/<slug>/                      one folder per threat actor or vulnerability
  handoff/
    analysis.json                     handoff: framing (optional)
    mapping.json                      handoff: tactics and techniques (optional)
  reports/
    <name>-flow.html                  from this skill — the output
```

> `Verify-Mapping.ps1` is a **deliberate duplicate**, carried identically by every skill that
> touches the handoff. `handoff-schema.md` is **scoped, not duplicated** — this skill *reads*
> both JSON files, so it documents both. A skill that only writes one of them documents less.
>
> Each skill in this project is self-contained and references nothing inside another skill, so
> a shared contract is copied rather than linked. `CLAUDE.md` is the only place that knows the
> other skills exist, and is where the copies get reconciled if the contract changes.

> **Two PowerShell 5.1 encoding traps, both already fixed — do not undo them.**
> The `.ps1` files are deliberately **pure ASCII**, because PS 5.1 reads scripts as ANSI
> unless they carry a BOM and a stray em-dash becomes a parser error; match non-ASCII
> characters with `\uXXXX` escapes instead. And every `Get-Content` that reads a report or
> mapping passes **`-Encoding UTF8`**, because the same ANSI default silently shreds
> non-ASCII content before the regexes see it.
