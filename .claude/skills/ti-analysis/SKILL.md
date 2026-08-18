---
name: ti-analysis
description: Produces a detailed written threat-intelligence analysis of a NAMED threat actor, a vulnerability or vulnerability chain, or a campaign — covering overview, history, conclusion, and a risk-and-impact assessment with per-sector risk levels. Writes subjects/<slug>/reports/analysis.html plus subjects/<slug>/handoff/analysis.json, leaving the ATT&CK technique mapping to a separate step. Use when asked to research, analyse, profile or write up a threat actor, CVE or campaign. Do NOT use it to build an ATT&CK mapping.
---

# TI Analysis

Researches a named subject from open sources and writes the prose half of a threat
intelligence bulletin: who they are, what they have done in chronological order, what it
means, and who is at risk.

## Where this sits in the pipeline

**Step 1 of the pipeline.** Two outputs, into two different subfolders of `subjects/<slug>/`:

| Output | Consumed by |
|---|---|
| `reports/analysis.html` | `CLAUDE.md`, merged with the flow report into the bulletin |
| `handoff/analysis.json` | the structured handoff; a separate step writes `handoff/mapping.json` |

The subject folder separates artefacts by kind: `handoff/` is machine-read JSON, `reports/` is
what a human reviews, and `bulletin/` holds the merged deliverable a later step writes. Create
the subfolders if they do not exist.

**Path convention.** `references/` and `scripts/` are relative to this skill folder.
`subjects/` is relative to the TI-Reporting project root.

## When this runs — and when it does not

**Run it** for a *named* subject: a tracked actor, a specific CVE or chain, or a campaign.

**Do not run it** to invent a profile. If open sources carry nothing on the subject, say so
and stop. A thin subject produces a short report, not a padded one — and a report that reads
as authoritative while resting on nothing is worse than no report.

**Do not build the ATT&CK mapping here.** It belongs in a separate file this skill never writes.
Techniques named in passing in your prose are fine; a mapping is not.

## The five sections

Copy `references/analysis-template.html` and fill it. Order is fixed.

**1. Cover** — title, subject, TLP marking, cover motif, and a meta strip. The standfirst is
one sentence and should say what makes this subject *different*, not what makes it a threat.

**2. Overview** — the heart of the report.
- Open with **one or two paragraphs of background**: who they are, where they are assessed to
  operate from, what they are for. A reader who has never heard the name must finish these
  paragraphs oriented.
- Then activity in the `.chrono` rail, **oldest first, always**. Chronology is not a
  formatting preference — it is what lets a reader see escalation, dormancy and shifts in
  targeting. Reverse or scattered order hides exactly that.
- For a **vulnerability** subject the structure is identical: background on the flaw, then a
  chronological account of threat actors abusing it in real campaigns. The chronology is of
  *exploitation*, not of the CVE lifecycle — patch dates belong in the flow report.
- Mark turning points with `class="entry key"`.

**3. History** — *optional*. Origin story: first discovery, earliest campaigns, and for a
vulnerability whether it was exploited as a zero-day before disclosure. **Delete the whole
section** when the subject is recent or nothing is documented. An empty History section says
"we did not look"; no History section says "there is nothing to say".

**4. Conclusion** — a tl;dr of what the report established, then three to five `.takeaway`
items. A takeaway is a *finding*, not a summary of a paragraph.

**5. Risk & Impact** — see below.

## The risk assessment

**Sector rows, ordered highest first.** Five levels — `critical`, `high`, `moderate`, `low`,
`minimal` — set as a class on `.sector`, which drives both the meter and the label.

| Level | Means |
|---|---|
| Critical | Actively and repeatedly targeted by this subject |
| High | Fits the observed victim profile closely |
| Moderate | Plausible, not observed |
| Low | Outside the observed pattern |
| Minimal | No indication of interest |

Three rules that keep the assessment honest:

- **Every row needs a reason in `.why`.** A level with no justification is a guess with a
  colour on it.
- **Include sectors you assess as low or minimal.** Saying who is *not* likely to be hit is
  as useful as saying who is, and it demonstrates the assessment discriminates rather than
  painting everything red. A risk table where every row is critical carries no information.
- **Ground levels in observed targeting**, not in how important a sector sounds. Energy is
  not automatically critical; it is critical when *this* subject has hit energy.

**This section answers WHO, not HOW.** Do not list attack vectors, techniques or tooling
here. The companion ATT&CK flow report answers *how* a compromise unfolds, technique by
technique and in order — and that is a far better answer than a prose list. Putting it in both places creates two versions of the same
claim that drift apart the moment one is updated.

Close instead with the bottom-line `.callout`, which points the reader across to the flow
report. Division of labour for the bulletin: **this report says who is at risk and why; the
flow report says how they get hit.**

## Sourcing

**`references/sources.yaml` is the allowlist.** Research only from the sources it names. A
claim that cannot be traced to one of them does not go in the report. The file groups them
into `primary_research`, `government`, `reference`, `news` and `vendor_advisories`, and each
entry carries a `use_for` line saying what it is actually good for — read it rather than
defaulting to whichever source is most familiar.

Every entry is tagged `tier`:

| Tier | What it means | Weight |
|---|---|---|
| `primary` | Publishes its own research and telemetry | Can carry an attribution claim |
| `corroborating` | Reports on somebody else's research | Timeline and reach only |
| `reference` | Structured lookup, not narrative | Identifiers, never a story |

Four rules follow from that:

- **Attribution needs a primary source.** "Actor X did Y" must rest on a `primary` or
  `government` entry. A news outlet reporting a vendor's finding is a pointer to the
  primary, not a substitute for it — cite the vendor.
- **Corroborate across vendors.** They use different names for the same actor and sometimes
  disagree on attribution; two independent primaries agreeing is materially stronger than
  one. `reference` → ETDA and MITRE resolve aliases when one actor carries five names.
- **Say when reporting is thin.** "Only one vendor has reported this" is a finding and
  belongs in the report.
- **Separate fact from assessment in the wording.** "Reported to have" and "assessed to" are
  different claims and must not share a sentence.

Every factual claim that is not common knowledge carries a `.src` marker resolving to the
Sources list. Unsourced assertion is the failure mode this report type exists to avoid.

**Never cite** vendor marketing pages, unattributed blogs, social media, LLM-generated
aggregators, or anything not in the allowlist. If the subject genuinely has no coverage in
these sources, say so and stop — that is a finding, not a reason to reach further afield.

## Design

**Retune the accent to the subject's objective.** The accent pair in `:root` is the one
thing that changes per subject. An espionage subject whose purpose is quiet collection should
not be presented in the same alarm red as a wiper crew — the colour is an assertion about
intent, so make it a true one. Neutrals carry a faint bias toward the accent, so shift them
with it.

| Objective | `--ember` (accent) | `--steel` (metadata) | Neutrals |
|---|---|---|---|
| Destruction / extortion | ember red `#cf4a1f` | steel blue `#346b8f` | warm grey (`--ground: #f6f4f2`) |
| Espionage / collection | covert violet `#6d3fa3` | slate teal `#2f6b78` | faint cool (`--ground: #f5f4f7`) |

These values are shared across the TI-Reporting project so that separate reports on one
subject read as one body of work. `CLAUDE.md` records the convention.

**Risk colours are a separate token family** (`--risk-*`). Sector risk is an analyst
judgment, not a measured score, so it renders as a **segmented meter** rather than a numeric
badge. Do not swap the form.

## Also write `analysis.json`

Alongside the report, write `subjects/<slug>/handoff/analysis.json`. **This skill owns that file
entirely** — nothing else writes to it, and the ATT&CK mapping lives in a separate file
written by a separate step. Every field is a judgment this analysis has already made.

The full contract is `references/analysis-schema.md`.

```json
{
  "schema": "analysis/1.0",
  "subject": "{{SUBJECT}}",
  "slug": "{{folder-safe-slug}}",
  "subject_type": "actor | vulnerability | campaign",
  "matrix": "enterprise | ics | mobile",
  "attack_id": "{{G-ID, omit if none}}",
  "aliases": ["{{other tracked names}}"],
  "objective": "destruction | extortion | espionage | collection | disruption | unknown",
  "objective_note": "{{one line}}",
  "cves": ["{{CVE IDs, omit if none}}"],
  "vuln_relationship": "none | exploit-chain | remediation-cascade",
  "confidence": "published | derived",
  "facts": { "attribution": "{{...}}", "active_since": "{{...}}", "targets": "{{...}}" },
  "background": ["{{paragraph}}", "{{paragraph}}"],
  "chronology": [
    {
      "date": "YYYY | YYYY-MM | YYYY-MM-DD",
      "event": "{{short headline}}",
      "detail": "{{what the subject actually did - name tooling and behaviour}}",
      "key": true,
      "sources": [0, 2]
    }
  ],
  "risk": [
    { "sector": "{{SECTOR}}", "level": "critical | high | moderate | low | minimal", "why": "{{reason}}" }
  ],
  "sources": ["{{URL}}"],
  "report": "analysis.html"
}
```

**Write the JSON first, then render the report from it.** `background`, `chronology` and
`risk` are the same content as the Overview and Risk & Impact sections. Producing them once
as data and building the HTML from that is what stops the two halves disagreeing.

- **`chronology` must be oldest first**, with `date` in `YYYY`, `YYYY-MM` or `YYYY-MM-DD` so
  it sorts as a plain string. The validator enforces both.
- **`detail` is the field the mapping step reads to derive ATT&CK techniques.** Write it so
  that is possible: *"deployed ASPXSpy web shells, then used Mimikatz against LSASS"* is
  mappable, *"conducted a destructive attack"* is not. Where tradecraft is documented across
  a subject's whole history rather than tied to one date, put it in `background` instead.
- **Do not put technique IDs anywhere in this file.** You record what happened; the mapping
  step decides which technique that is. Pre-empting it turns mapping into rubber-stamping.
- **`sources` on a chronology entry are integer indices** into the top-level `sources` array,
  so provenance survives the handoff. The validator rejects indices that do not resolve.
- Every `risk` row needs a `why`; the validator rejects a level with no justification.

**Write it without a BOM.** `Set-Content -Encoding utf8` on PowerShell 5.1 emits one, and a
BOM breaks downstream parsing.

Two fields decide how the whole flow report is built, so get them right:

- **`subject_type`** routes to one of three report templates. If the subject names both an
  actor *and* the CVEs it exploits, it is `campaign` — not an actor with a CVE mentioned.
- **`vuln_relationship`** picks chain versus set. `exploit-chain` = exploiting one gives you
  what you need for the next. `remediation-cascade` = fixing one exposed the next. `none` =
  independent. A single CVE is always `none`; one CVE composes with nothing.

Use `objective: unknown` rather than guessing. It is a legitimate answer that produces a flow
with no impact phase, which is honest.

Validate before finishing:

```powershell
.\.claude\skills\ti-analysis\scripts\Verify-Mapping.ps1 -Path .\subjects\<slug>
```

It reports `mapping.json` as absent, which is expected at this stage — the `analysis.json`
checks are the ones that must pass.

## Files

```
.claude/skills/ti-analysis/
  SKILL.md                        this file
  references/
    sources.yaml                  THE ALLOWLIST - 51 approved sources, tiered
    analysis-template.html        the report template
    analysis-schema.md            the analysis.json contract this skill writes
  scripts/
    Verify-Mapping.ps1            validates the JSON handoff this skill writes
```

> `Verify-Mapping.ps1` is a **deliberate duplicate**, carried identically by every skill that
> touches the handoff. `analysis-schema.md` is **scoped, not duplicated** — it documents only
> `analysis.json`, the file this skill writes, because that is the whole of this skill's
> contract. A skill that also *reads* the handoff documents more than this.
>
> Each skill in this project is self-contained and references nothing inside another skill, so
> a shared contract is copied rather than linked. `CLAUDE.md` is the only place that knows the
> other skills exist, and is where the copies get reconciled if the contract changes.

> The script is deliberately **pure ASCII**, and every `Get-Content` that reads a report or
> mapping passes **`-Encoding UTF8`**. Windows PowerShell 5.1 reads `.ps1` as ANSI without a
> BOM, so a literal em-dash is a parser error — use `\uXXXX` escapes; and the same ANSI
> default silently shreds non-ASCII content in data files before the regexes see it.
