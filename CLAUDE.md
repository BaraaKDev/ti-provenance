# TI-Provenance

Threat intelligence reporting pipeline. Four skills produce a bulletin about one subject —
a threat actor, a vulnerability, or a campaign.

**This file is for changing the machine. The `threat-report` skill is for using it.**

If the task is *produce a bulletin*, none of this is needed — invoke the orchestrator and it
handles classification, slugs, the three worker skills, the merge and the export. This file is
what you need when the task is *change how bulletins get made*: the artefact layout, the handoff
contract, the design decisions behind the machinery, the conventions that keep the skills
independent, and the environment traps that have already cost this project real bugs.

The split matters because a procedure written twice drifts. Anything describing how to run the
pipeline belongs in the skill and nowhere else; anything describing why it is shaped this way
belongs here.

## The pipeline

Read it as artefacts rather than arrows — every step writes into the subject folder:

```
subjects/<slug>/                       one folder per subject, slug-named
  handoff/                              machine handoff - JSON, one writer each
    analysis.json    <-- ti-analysis      framing, risk, sources
    mapping.json     <-- mitre-mapping    tactics and techniques
  reports/                              the halves a human reviews
    analysis.html    <-- ti-analysis      the prose report
    <name>-flow.html <-- mitre-visualizer built from the two JSON files
  bulletin/                             the merged HTML, still a working file
    <slug>-threat-bulletin.html
                     <-- threat-report    the two reports, merged

output/                                 project root, not per-subject
  <slug>-threat-bulletin.pdf            <-- threat-report - THE DELIVERABLE
```

**`output/` is what the reader gets.** Everything under a subject folder is working material —
intermediate data, halves, a merged HTML that still needs a browser. The PDF in `output/` is
the finished artefact, and it sits at the project root rather than per-subject so that
"what have we published" is one directory listing rather than a walk through six folders.

**The bulletin is named, not generic.** It leaves the project and lands in somebody's inbox,
so the filename has to identify the subject on its own — `akira-threat-bulletin.html`, not a
`bulletin.html` that is indistinguishable from every other one.

**Three folders, three kinds of thing.** `handoff/` is read by machines, `reports/` is read by
people, `bulletin/` is what gets sent. The split is what keeps a subject legible once it holds
five artefacts, and it means "everything a step produced" is one directory rather than a
filename convention.

| Step | Skill | Writes | Status |
|---|---|---|---|
| 1 | `ti-analysis` | `reports/analysis.html` + `handoff/analysis.json` | built |
| 2 | `mitre-mapping` | `handoff/mapping.json` | built |
| 3 | `mitre-visualizer` | `reports/<name>-flow.html` | built |
| 4 | `threat-report` | `bulletin/<slug>-threat-bulletin.html` | built |
| 5 | `threat-report` | `output/<slug>-threat-bulletin.pdf` | built |

**Every file has exactly one writer.** No artefact is co-written, so two steps can never
collide or contradict each other inside one file. A consumer reads whichever files exist.

**The JSON is machine handoff; the HTML is what a human reviews.** That split is why the
handoff is JSON at all — an analyst checks the rendered report, not the data file, so the
handoff can optimise for unambiguous parsing.

---

# Running the pipeline

**The `threat-report` skill drives it.** Give it an actor, a vulnerability, or a link to
reporting about one, and it classifies the subject, picks the slug, runs the three worker
skills in order, merges, verifies and exports.

That procedure used to live here. It moved because a skill is discoverable — it shows up under
`/skills`, carries its own description, and can be invoked directly — whereas a section of this
file is only found by something already reading this file.

What stays here is what the skill assumes rather than what it does: the artefact layout, the
handoff contract, the conventions, and the traps this environment keeps setting.

**Real runs write to `subjects/<slug>/`. `samples/<slug>/` is the shipped reference set** that
the schema docs, the report guides and the harness all read, so nothing should write there.

---
# Why it is built this way

Not how to run it — that is the orchestrator's job, and repeating it here would create a second
copy to drift. These are the decisions behind the machinery, kept because each one cost something
to learn and none is obvious from the code.

**The merge is scripted because the two halves collide.** Both are HTML fragments, so
concatenating them looks like it works. But they share class names, and `high` and `low` mean
*risk level* in part 1 and *severity* in part 2. A naive merge silently restyles the risk meters
and nothing about the output says so. The script rewrites part 2's CSS under a `.flowpart`
wrapper, including its `:root` custom properties, which land on the wrapper and cascade down.

**Two regions are hand-written because only the combined view can say certain things.** *This
actor is in your sector, and the way in is a flaw you have* is not available to either half
alone, which is why the executive summary exists rather than being cut from part 1. Re-merging
with `-Force` preserves both regions; everything outside them is derived and overwritten.

**An actor bulletin has a structural remediation gap.** An actor flow has no CVEs to remediate,
so it has no Remediation part, and the bulletin arrives with no defensive guidance unless the
orchestrator writes it. That gap is a property of the design, not an oversight — worth knowing
before someone "fixes" it by having the flow report invent mitigations.

**The exporter gates on the verifier.** A PDF is a faithful render of whatever it is handed,
including a bulletin with a surviving placeholder or no remediation at all — and the PDF is the
artefact that leaves the project. `-SkipVerify` exists for when you know why you are overriding.

**PDF conversion is Chromium-only on purpose.** There is no Python here and no `wkhtmltopdf`; the
browser engine is already present and renders the same CSS the bulletin was designed against, so
it is the only route that guarantees the PDF matches the page that was reviewed. Page numbering
rides on `@page` margin boxes for the same reason — `string-set` is unimplemented in every
browser, Chromium honours margin boxes, and the harness reads the numbers back out of the
finished PDF rather than trusting the CSS took.

**Mechanical checks cannot see the page.** They confirm the HTML is sound and the PDF is
well-formed. They cannot see a clipped column or a colour that did not survive printing. This
project has shipped one layout defect that passed every check, so the finished PDF gets looked at
once by a human.
## The reader never sees the pipeline

Everything in this file — the skills, the handoff JSON, the `samples/` layout, the templates —
is build machinery. **None of it may appear in text a reader sees**, in either half or in the
merged bulletin. That means no skill names, no `analysis.json` or `mapping.json`, no
`subjects/...` or `samples/...` paths, no companion-report filenames, 

or MODE SET. Refer to the other half as "the companion attack-flow report", without a filename.

This leaked for a while and was only caught by reading a finished PDF. Three things now hold it:

| Where | What it does |
|---|---|
| `Verify-Flow.ps1` | fails a flow report that names any of it — runs inside the skill, so a standalone run is covered too |
| `Verify-Bulletin.ps1` | fails the merged bulletin, which gates export, so no PDF can carry it |
| `Test-Pipeline.ps1` | sweeps every report, bulletin and template in one pass |

All three scan **visible text only**, stripping HTML comments, CSS comments and `<style>` blocks
first. That is deliberate: authoring guidance is supposed to live in comments, and a comment can
never render. The failure mode that caused this was guidance sitting in a `<p class="note">`
instead — visible by default, and it shipped whenever an author did not overwrite it.

# Subject folders

One folder per subject, slug-named, holding every artefact for it — the layout is the pipeline
diagram above. Two directories use it, and the difference is what they mean rather than what
they contain:

| | |
|---|---|
| `samples/` | The shipped reference set. The schema docs and report guides point at it, and the harness reads it for its positive cases, so changing one of these changes the documentation. |
| `subjects/` | Real output. Nothing references it, so it can be added to, rewritten and deleted freely. This is where the orchestrator writes. |

Six samples exist, at three levels of completeness:

| Subject | What it carries | Why it is worth reading |
|---|---|---|
| `akira` | all five artefacts | `campaign`. The reference for a full pipeline run, and for three CVEs wired to techniques with `via_cve` |
| `agrius` | all five artefacts | `campaign`. The validated `analysis.json` + `mapping.json` worked example both schema docs point at |
| `andariel` | all five artefacts | `actor`. The only subject whose flow carries no Remediation, so its bulletin is the one that writes `BULLETIN:DEFENCE` by hand |
| `proxyshell` · `log4j` · `windows-2026-08` | flow report only | Predate steps 1 and 2. Still the canonical examples for the vulnerability report modes |

A subject with only a flow report is not broken — the validators skip what is absent, which is
the standalone case working as designed.

# The handoff contract

Two JSON files, `analysis.json` and `mapping.json`, each written by exactly one step. The
schema is duplicated into every skill that touches it — see *Skill independence* below — and
it is the single point where the pipeline can go wrong quietly, so:

- **Validate before rendering.** `Verify-Mapping.ps1 -Path .\subjects\<slug>` checks both
  files and cross-checks them against each other: malformed technique IDs, tactic names
  invalid for the declared matrix, missing `usage` text, risk levels with no justification,
  a `via_cve` naming a CVE nobody declared, and cross-field errors like a single CVE marked
  as a chain. A **missing** file is skipped, not failed — that is the standalone case.
- **Judgment in, facts out.** Steps 1 and 2 supply analytical judgment — which techniques,
  which tactics, how the subject used them, the objective, the CVE relationship, confidence.
  Step 3 looks up CVSS, CWE, KEV status, fixed versions and technique verification itself.
  Pass CVE *identifiers*, never CVE *details*, or the pipeline bakes in data that goes stale.

# Conventions

**Two kinds of skill.** `ti-analysis`, `mitre-mapping` and `mitre-visualizer` are **workers**:
each does one job, references nothing inside another skill, and names no project-level script.
Invoke any one on its own and it works, which is the property that makes them reusable.

`threat-report` is the **orchestrator**. Naming the other three is its entire function, so it
is exempt from that rule — it inherits the exemption this file used to hold. The exemption runs
one way only: a worker still may not name the orchestrator, and the harness checks both
directions, plus that the orchestrator actually drives all three workers rather than quietly
dropping a step.

The cost is duplication: each skill carries its own schema reference and its own copy of
`Verify-Mapping.ps1`. The script is meant to stay byte-identical across skills; the schema
docs are deliberately **scoped**, so each skill documents only the files it actually touches:

| Skill | Schema doc | Covers |
|---|---|---|
| `ti-analysis` | `references/analysis-schema.md` | `analysis.json` only — the file it writes |
| `mitre-mapping` | `references/mapping-schema.md` | `mapping.json` in full, plus the `analysis.json` fields it reads |
| `mitre-visualizer` | `references/handoff-schema.md` | both files — it reads both |

Each skill documents exactly its own relationship to the handoff, which is why the three docs
have different names. The `analysis.json` section appears in all three at different depths, so
that is the part to reconcile when the contract moves.

**When the contract changes, update every copy.** For the script a hash comparison detects
drift; for the schema docs the shared `analysis.json` section has to be reconciled by hand:

```powershell
Get-FileHash .\.claude\skills\*\scripts\Verify-Mapping.ps1 | Select-Object Hash, Path
```

**Paths.** Inside a skill, paths are skill-relative (`references/`, `guides/`, `scripts/`).
Everywhere else they are project-relative and start with `subjects/`, `samples/` or `scripts/`. Run
scripts from this directory.

**Project scripts vs skill scripts.** `scripts/` at the project root holds steps 4 and 5 —
`Merge-Bulletin.ps1`, `Verify-Bulletin.ps1` and `Export-Bulletin.ps1` — plus the test harness.
They are not part of any skill, because these are the steps that must see both halves at once.
No **worker** skill may reference them; the orchestrator invokes them by design.

**Run the harness before committing a script change.**

```powershell
.\scripts\Test-Pipeline.ps1                  # 52 checks, a few seconds
.\scripts\Test-Pipeline.ps1 -IncludeExport   # adds the PDF round trip, ~15s more
```

It exists because **every bug that has actually shipped here was invisible to the checks in
place at the time**. So it deliberately runs what nobody runs by hand: each script in the exact
invocation form its own `.EXAMPLE` documents (including true pipeline binding, where state
leaks between items), an empty pipeline against every verifier, and a fixture per known failure
mode — malformed JSON, a pre-rename tactic name, an undeclared `via_cve`, a lone CVE marked as
a chain, a blank `usage`, reversed chronology, two flow reports, two bulletins.

It also asserts the things this file *claims*: the three `Verify-Mapping.ps1` copies are
byte-identical, no worker references another skill or a project script, the orchestrator drives
all three workers and targets `subjects/`, every script is pure ASCII and parses, nothing
carries a BOM, no local shadows a `begin{}` constant by casing, and the schema docs still
document every field the validator enforces.

Fixtures are built under `%TEMP%` and removed afterwards. Nothing is written to `samples/` or
`output/`. The harness has been mutation-tested: reintroducing the `$TACTICS` collision trips
three separate checks, and removing a zero-input guard trips exactly one.

**PowerShell 5.1, no Python.** This machine has no Python interpreter despite `.pyc` files
elsewhere in the workspace. PS 5.1 has bitten this project **four separate times**; all four
are handled and must stay handled:

| Trap | Symptom | Fix |
|---|---|---|
| `.ps1` read as **ANSI** without a BOM | a literal em-dash in a string is a parser error | keep scripts **pure ASCII**; match non-ASCII with `\uXXXX` escapes |
| `Get-Content -Raw` defaults to **ANSI** | non-ASCII in a report or mapping is shredded before regexes see it — a validator once found *0 of 22* techniques | always pass **`-Encoding UTF8`** when reading |
| `Set-Content -Encoding utf8` **writes a BOM** | the BOM precedes `---`, so YAML frontmatter stops parsing and a skill's `description` disappears | write with `[System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($false)))` |
| **Variable names are case-insensitive** | a local `$tactics` in `process{}` silently replaced the `$TACTICS` lookup table built in `begin{}`, so the *second* piped subject died on `.ContainsKey()` | never name a local after a `begin{}` constant, whatever the casing. `ForEach-Object` hides this — it re-runs the script per item, so `begin{}` reinitialises |

The fourth is the sneakiest, because the bug only appears under **true pipeline binding**
(`Get-ChildItem … | script.ps1`) and vanishes under `ForEach-Object { script.ps1 -Path … }`.
Test scripts the way their own `.EXAMPLE` block says to run them, or state that survives
between items never gets exercised.

The third is the nastiest, because the file looks correct in every editor and only the
frontmatter parser notices. If a skill stops being discovered, check for a BOM first:

```powershell
$b=[System.IO.File]::ReadAllBytes($path); $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF
```

**Never invent ATT&CK IDs.** An unfamiliar technique ID is far more likely to be newer than
the model's training data than wrong. Verify against `https://attack.mitre.org/techniques/<ID>/`
before changing anything. This has already caused one real error in this project — a correct
`T1685` was "corrected" to a fabricated `T1562.001`. The same applies to tactic names:
Enterprise uses **Stealth** and **Defense Impairment**, not *Defense Evasion*.

# Still to decide

- **What happens when the two JSON files disagree in substance.** The validator already
  catches structural mismatch (subject, slug, matrix) and undeclared `via_cve` values. It
  cannot catch a *semantic* clash — `analysis.json` saying `objective: espionage` while every
  technique in `mapping.json` is destructive. Worth deciding whether that becomes a check or
  stays a human read at step 4.
- **Re-running a subject months later.** Nothing currently records when an artefact was
  produced, so a stale `analysis.json` and a fresh `mapping.json` are indistinguishable from a
  matched pair.

# Decided

- **The bulletin keeps two Sources lists, labelled per part.** Both halves must stand alone as
  documents, so both carry citations. Merging them would mean renumbering part 1's `.src`
  markers by hand. Instead the merge labels them *Part 1 sources* / *Part 2 sources* in the
  derived file only, and `Verify-Bulletin.ps1` **fails** on an unattributed `Sources` block.
