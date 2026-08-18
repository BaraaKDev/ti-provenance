# TI-Reporting

Threat intelligence reporting pipeline. Three skills produce a bulletin about one subject —
a threat actor, a vulnerability, or a campaign.

## The pipeline

Read it as artefacts rather than arrows — every step writes into the subject folder:

```
subjects/<slug>/                        one folder per subject, slug-named
  handoff/                              machine handoff - JSON, one writer each
    analysis.json    <-- ti-analysis      framing, risk, sources
    mapping.json     <-- mitre-mapping    tactics and techniques
  reports/                              the halves a human reviews
    analysis.html    <-- ti-analysis      the prose report
    <name>-flow.html <-- mitre-visualizer built from the two JSON files
  bulletin/                             the merged HTML, still a working file
    <slug>-threat-bulletin.html
                     <-- this file        the two reports, merged

output/                                 project root, not per-subject
  <slug>-threat-bulletin.pdf            <-- this file - THE DELIVERABLE
```

**`output/` is what the reader gets.** Everything under `subjects/` is working material —
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
| 4 | this file | `bulletin/<slug>-threat-bulletin.html` | built |
| 5 | this file | `output/<slug>-threat-bulletin.pdf` | built |

**Every file has exactly one writer.** No artefact is co-written, so two steps can never
collide or contradict each other inside one file. A consumer reads whichever files exist.

**The JSON is machine handoff; the HTML is what a human reviews.** That split is why the
handoff is JSON at all — an analyst checks the rendered report, not the data file, so the
handoff can optimise for unambiguous parsing.

---

# Running the pipeline

## 1. Classify the request

Three kinds of input, one pipeline. The difference only changes what step 1 researches and
which template step 3 picks — the sequence is identical.

| The user gives you | `subject_type` | Examples |
|---|---|---|
| A tracked actor or group name | `actor` | *Andariel* · *Volt Typhoon* |
| One or more CVEs, or a named flaw | `vulnerability` | *CVE-2021-44228* · *the ProxyShell chain* · *August 2026 Patch Tuesday* |
| An actor named together with what they exploited, or a named operation | `campaign` | *Agrius exploiting FortiOS* · *Akira* · *Operation X* |

**Akira is in the campaign row on purpose.** It reads as a pure ransomware crew, and was
nearly written up as an actor — but every documented way in is a named, patchable CVE, and a
report that omitted them would have dropped the only thing a defender can act on today.

**The boundary that matters is actor vs campaign.** If the request names both an actor *and*
the CVEs they used, it is a campaign — not an actor with a CVE mentioned in passing. A
campaign report wires the two together; an actor report cannot.

**Step 1 decides authoritatively.** Your reading routes the request; `subject_type` in
`analysis.json` is the answer everything downstream uses. If they disagree, the file wins and
your reading was wrong.

## 2. Pick the slug

Everything writes into `subjects/<slug>/`, so the slug is settled **before** step 1 runs.
Lowercase, hyphenated, folder-safe, and stable — renaming later orphans every artefact.

| Subject | Slug | Examples |
|---|---|---|
| Actor | the primary tracked name | `agrius` · `akira` · `andariel` |
| Vulnerability with a common name | that name | `log4j` · `proxyshell` |
| Vulnerability without one | the CVE, lowercased | `cve-2026-68820` |
| A patch set or advisory batch | vendor plus period | `windows-2026-08` |
| Campaign | the actor's slug | `agrius` |

Create the folder, then run the steps in order.

## 3. Run the five steps

**Invoke each skill by name and let it work.** They are self-contained: none references
another, and none needs to be told how the next one behaves.

| Step | Invoke | Give it | Then |
|---|---|---|---|
| 1 | `ti-analysis` | the subject, and the slug you chose | wait for `analysis.html` + `analysis.json` |
| 2 | `mitre-mapping` | `subjects/<slug>/` | wait for `mapping.json` |
| 3 | `mitre-visualizer` | `subjects/<slug>/` | wait for `<name>-flow.html` |
| 4 | this file | `subjects/<slug>/` | merge into `bulletin/<slug>-threat-bulletin.html` |
| 5 | this file | `subjects/<slug>/` | export `output/<slug>-threat-bulletin.pdf` |

**Never paste one step's output into the next step's prompt.** Point at the folder. The whole
purpose of the handoff files is that the evidence is already written down in a form the next
step can read — re-narrating it in a prompt creates a second version that will drift from the
file, and step 2 in particular is designed to read `chronology[].detail` rather than your
summary of it.

**Validate between steps, not at the end.**

```powershell
.\.claude\skills\mitre-mapping\scripts\Verify-Mapping.ps1 -Path .\subjects\<slug>
```

Run it after step 1 and again after step 2. After step 1 it reports `mapping.json` as absent,
which is expected. A structural error caught here costs one step to fix; caught after step 4
it costs three. (Any skill's copy of the script will do — they are byte-identical.)

## 4. When a step refuses

**Steps 1 and 2 are allowed to stop, and a refusal is a result.** Step 1 stops when the
subject has no coverage in its allowlisted sources. Step 2 stops when the evidence describes
outcomes but no behaviour it can map.

When that happens: **keep whatever was produced, stop the pipeline, and tell the user which
step stopped and why.** Do not paper over it. Specifically, do not supply the missing research
yourself, do not relax a skill's sourcing rules, and do not hand step 3 a mapping you wrote to
keep things moving. A bulletin assembled around a gap reads exactly like one built on
evidence, which is the whole problem.

A thin subject legitimately produces a short bulletin. That is a different thing from a padded
one, and the difference is not visible in the output — only in whether it happened.

---

# Step 4: the bulletin

Part 1 says **who is at risk and why**. Part 2 says **how they get hit**. The bulletin is
those two, plus the two things only the combined view can say.

## The merge is scripted

```powershell
.\scripts\Merge-Bulletin.ps1 -Path .\subjects\<slug>
.\scripts\Verify-Bulletin.ps1 -Path .\subjects\<slug>
```

**Do not hand-merge the two files.** Both halves are HTML fragments, so concatenating them
looks like it works — but they share class names, and `high` and `low` mean *risk level* in
part 1 and *severity* in part 2. A naive merge silently restyles the risk meters, and nothing
about the output announces it. The script rewrites part 2's CSS to sit under a `.flowpart`
wrapper, including its `:root` custom properties, which land on the wrapper and cascade down.

Re-running with `-Force` **preserves the editorial regions**, so regenerating either half does
not cost you the written sections. Everything outside those two regions is derived and will be
overwritten — edit the source report, not the bulletin.

## Two regions you write by hand

The script leaves both marked and stubbed.

**`BULLETIN:SUMMARY`** — sits after the cover. One paragraph plus three to five bottom lines,
**written last**, for a reader who will not read further. It is the only section allowed to
draw on both halves at once: *this actor is in your sector, and the way in is a flaw you have.*
Neither half can say that alone, which is why the section exists rather than being cut from
part 1.

**`BULLETIN:DEFENCE`** — sits at the end, and **whether you write it depends on the subject
type**:

| Subject | Where remediation comes from |
|---|---|
| `vulnerability` | the flow report's own **Remediation** part. **Empty this region** |
| `campaign` | usually the flow report. Check, then empty the region |
| `actor` | **nothing produces it.** Write it here |

That gap is real and worth knowing about: an actor flow has no CVEs to remediate, so it has no
Remediation part, and an actor bulletin arrives with no defensive guidance unless step 4
supplies it. Derive it from `mapping.json` — ordered by the tactics actually mapped, each item
naming the technique it denies, verified against the ATT&CK mitigations for that technique. Do
not fall back to generic hardening advice; a list that would be identical for any actor tells
the reader nothing about this one.

The verifier fails on a surviving placeholder in either region, and fails when a bulletin
carries an unattributed second Sources block.

---

# Step 5: the PDF

```powershell
.\scripts\Export-Bulletin.ps1 -Path .\subjects\<slug>
Get-ChildItem .\subjects -Directory | .\scripts\Export-Bulletin.ps1 -Force
```

Writes `output/<slug>-threat-bulletin.pdf`. **This is the deliverable** — everything under
`subjects/` is working material, and this is the file that gets sent.

**Conversion runs through headless Edge or Chrome**, whichever is installed. There is no
Python on this machine and no `wkhtmltopdf`; the browser engine is already present and renders
the same CSS the bulletin was designed against, so it is the only route that guarantees the
PDF matches the page you reviewed. The script finds the engine itself and refuses if neither
is there.

Two things the exporter fixes before printing, both of which would otherwise ruin the page:

- **The bulletin is an HTML fragment** — no doctype, `html`, `head` or `body`. Printed as-is a
  browser renders it in quirks mode, so it is wrapped in a real document first.
- **Print defaults would strip the colour.** Backgrounds are off by default in print, and this
  design encodes meaning in colour: sector risk meters, CVSS severity chips, phase heat, the
  accent that asserts the actor's objective. Losing it does not merely look worse, it removes
  information. The wrapper forces `print-color-adjust: exact`, widens the 940px reading column
  to the printable width so nothing is clipped, and stops cards breaking across pages.

Run it **after** `Verify-Bulletin.ps1` passes, not before. The PDF is a faithful render of
whatever it is given, including a bulletin with a placeholder still in it.

**Check the PDF by eye once.** The verifier can confirm the HTML is structurally sound and the
exporter can confirm the PDF is well-formed, but neither can see a clipped column or a colour
that did not survive. Layout defects only surface by looking — this project has already shipped
one that passed every mechanical check.

---

# Subject folders

One folder per subject, slug-named, holding every artefact for it — the layout is the pipeline
diagram above.

Six subjects exist, at three levels of completeness:

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

**Skill independence.** Every skill is self-contained and **references nothing inside another
skill**. Invoke any one of them on its own and it works. The only thing that knows all three
exist is this file.

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
Everywhere else they are project-relative and start with `subjects/` or `scripts/`. Run
scripts from this directory.

**Project scripts vs skill scripts.** `scripts/` at the project root holds steps 4 and 5 —
`Merge-Bulletin.ps1`, `Verify-Bulletin.ps1` and `Export-Bulletin.ps1` — plus the test harness.
They are not part of any skill, because these are the steps that must see both halves at once.
Nothing in a skill may reference them.

**Run the harness before committing a script change.**

```powershell
.\scripts\Test-Pipeline.ps1                  # ~40 checks, a few seconds
.\scripts\Test-Pipeline.ps1 -IncludeExport   # adds the PDF round trip, ~15s more
```

It exists because **every bug that has actually shipped here was invisible to the checks in
place at the time**. So it deliberately runs what nobody runs by hand: each script in the exact
invocation form its own `.EXAMPLE` documents (including true pipeline binding, where state
leaks between items), an empty pipeline against every verifier, and a fixture per known failure
mode — malformed JSON, a pre-rename tactic name, an undeclared `via_cve`, a lone CVE marked as
a chain, a blank `usage`, reversed chronology, two flow reports, two bulletins.

It also asserts the things this file *claims*: the three `Verify-Mapping.ps1` copies are
byte-identical, no skill references another, every script is pure ASCII and parses, nothing
carries a BOM, no local shadows a `begin{}` constant by casing, and the schema docs still
document every field the validator enforces.

Fixtures are built under `%TEMP%` and removed afterwards. Nothing is written to `subjects/` or
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
