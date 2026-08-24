---
name: threat-report
description: Produces a complete threat bulletin end to end for a threat actor, a vulnerability or CVE chain, or a campaign - given a name or a link to reporting about one. Drives the whole pipeline: research and written analysis, the ATT&CK mapping, the attack-flow report, the merge, verification, and the finished PDF. Use when someone asks for a threat report, a threat bulletin, a full write-up, or "everything on <subject>". Do NOT use it when only one half is wanted - a written analysis alone, a mapping alone, or a flow diagram from a mapping that already exists.
---

# Threat bulletin, end to end

One subject in, one PDF out. This skill runs the pipeline; it does not do the research, the
mapping or the rendering itself. Those belong to three skills it calls in order.

## What you are given

```
/threat-report Akira
/threat-report CVE-2021-44228
/threat-report https://www.cisa.gov/news-events/cybersecurity-advisories/aa24-109a
```

**A name** — an actor, a CVE, a named flaw, a patch batch, a campaign. Use it as the subject.

**A link** — read it first and work out which actor or vulnerability it is about. The subject is
what the page is *about*, not the page itself: an advisory about Akira produces a bulletin on
Akira, not a bulletin on the advisory.

### A link is a pointer, never a source

This is the rule that keeps the whole project honest, so do not bend it.

The link tells you **what to analyse**. It does not become a citation. Step 1 researches from its
own allowlist and may only cite what is on that list, so:

- If the link is on the allowlist, step 1 may find and cite it in the normal way — because it is
  an approved source, not because you were handed it.
- If it is not on the allowlist, **use it to identify the subject and then set it aside.** Do not
  quote it, do not cite it, and do not pass its claims to step 1 as facts.
- If the subject turns out to have no coverage in the allowlist, that is a refusal (see below).
  A single link is not a substitute for sourcing, however good the page looks.

Say which subject you extracted from the link before going further, so a wrong reading is caught
in one sentence rather than after five steps.

### When to refuse the input

Stop and say so plainly if:

- **The link is not about a threat actor or a vulnerability.** A vendor product page, a conference
  agenda, a general security-awareness article. There is no subject to analyse.
- **The link covers many subjects with no principal one.** A quarterly threat landscape naming
  thirty actors is not a bulletin subject. Ask which one they want.
- **The page cannot be retrieved.** Do not guess the subject from the URL slug.
- **The subject is a person, an organisation being accused, or an unnamed "someone who attacked
  us".** This pipeline reports on tracked actors and published vulnerabilities.

## Step 0 — classify and name

Three kinds of input, one pipeline. The difference only changes what step 1 researches and which
template step 3 picks.

| The subject is | `subject_type` | Examples |
|---|---|---|
| A tracked actor or group, no specific CVE | `actor` | *Andariel* · *Volt Typhoon* |
| One or more CVEs, or a named flaw | `vulnerability` | *CVE-2021-44228* · *the ProxyShell chain* · *August 2026 Patch Tuesday* |
| An actor named together with what they exploited | `campaign` | *Agrius exploiting FortiOS* · *Akira* |

**The boundary that matters is actor versus campaign.** If the subject names both an actor *and*
the CVEs they use, it is a campaign. An actor report cannot wire the two together, so writing one
drops the only thing a defender can act on today.

**Your reading only routes the request.** `subject_type` in `analysis.json` is what everything
downstream uses. If they disagree, the file wins.

Then pick the slug — lowercase, hyphenated, folder-safe, and **settled now**, because every
artefact is written into `subjects/<slug>/` and renaming later orphans all of them.

| Subject | Slug |
|---|---|
| Actor | the primary tracked name — `agrius`, `andariel` |
| Vulnerability with a common name | that name — `log4j`, `proxyshell` |
| Vulnerability without one | the CVE, lowercased — `cve-2026-68820` |
| A patch set or advisory batch | vendor plus period — `windows-2026-08` |
| Campaign | the actor's slug |

**Real work goes in `subjects/<slug>/`.** `samples/` is the shipped reference set — the schema docs
and report guides point at it and the test harness reads it. Never write there.

## Steps 1 to 5

Invoke each skill **by name** and let it work. They are self-contained: none references another,
and none needs telling how the next one behaves.

| Step | Invoke | Give it | Wait for |
|---|---|---|---|
| 1 | `ti-analysis` | the subject, and the slug you chose | `reports/analysis.html` + `handoff/analysis.json` |
| 2 | `mitre-mapping` | `subjects/<slug>/` | `handoff/mapping.json` |
| 3 | `mitre-visualizer` | `subjects/<slug>/` | `reports/<name>-flow.html` |
| 4 | `Merge-Bulletin.ps1` | `subjects/<slug>/` | `bulletin/<slug>-threat-bulletin.html` |
| 5 | `Export-Bulletin.ps1` | `subjects/<slug>/` | `output/<slug>-threat-bulletin.pdf` |

**Never paste one step's output into the next step's prompt.** Point at the folder. The handoff
files exist precisely so the evidence is already written down in a form the next step can read.
Re-narrating it creates a second version that drifts, and step 2 is built to read
`chronology[].detail` rather than your summary of it.

**Validate between steps, not at the end:**

```powershell
.\.claude\skills\mitre-mapping\scripts\Verify-Mapping.ps1 -Path .\subjects\<slug>
```

Run it after step 1 and again after step 2. After step 1 it reports `mapping.json` as absent,
which is expected. A structural error caught here costs one step; caught after step 4 it costs
three. Any skill's copy will do — they are byte-identical.

### Steps 4 and 5

```powershell
.\scripts\Merge-Bulletin.ps1  -Path .\subjects\<slug>
.\scripts\Verify-Bulletin.ps1 -Path .\subjects\<slug>
.\scripts\Export-Bulletin.ps1 -Path .\subjects\<slug>
```

**Do not hand-merge the two halves.** They are HTML fragments that share class names, and `high`
and `low` mean *risk level* in part 1 and *severity* in part 2. Concatenating them silently
restyles the risk meters and nothing announces it. The script rewrites part 2's CSS under a
`.flowpart` wrapper.

The exporter runs the verifier itself and refuses on failure. That gate is the point: the PDF is a
faithful render of whatever it is handed, including a bulletin with a surviving placeholder.

## The two hand-written regions

The merge leaves both marked and stubbed. Neither is optional to consider.

**`BULLETIN:SUMMARY`** — after the cover. One paragraph plus three to five bottom lines, **written
last**, for a reader who will not read further. It is the only section allowed to draw on both
halves at once: *this actor is in your sector, and the way in is a flaw you have.* Neither half
can say that alone.

**`BULLETIN:DEFENCE`** — at the end, and whether you write it depends on the subject:

| Subject | Where remediation comes from |
|---|---|
| `vulnerability` | the flow report's own Remediation part — **empty this region** |
| `campaign` | usually the flow report — check, then empty it |
| `actor` | **nothing produces it — write it here** |

An actor flow has no CVEs to remediate, so an actor bulletin arrives with no defensive guidance
unless you supply it. Derive it from `mapping.json`, ordered by the tactics actually mapped, each
item naming the technique it denies. Generic hardening advice that would be identical for any
actor tells the reader nothing.

Leave the markers in place even when the region is empty — the verifier fails if they are lost.

## When a step refuses

**Steps 1 and 2 are allowed to stop, and a refusal is a result.** Step 1 stops when the subject
has no coverage in its allowlisted sources. Step 2 stops when the evidence describes outcomes but
no mappable behaviour.

When that happens: keep what was produced, stop, and tell the user which step stopped and why.

Do **not** paper over it. Do not supply the missing research yourself, do not relax a skill's
sourcing rules, and do not hand step 3 a mapping you wrote to keep things moving. A bulletin
assembled around a gap reads exactly like one built on evidence, which is the whole problem.

A thin subject legitimately produces a short bulletin. That is a different thing from a padded
one, and the difference is invisible in the output.

## Before you hand it over

- The exporter already gated on the verifier, so the structure is sound.
- **Open the PDF and look at it once.** No check can see a clipped column or a colour that did not
  survive printing. This project has shipped one layout defect that passed every mechanical check.
- Tell the user the subject type you settled on, where the PDF is, and anything a step refused.

## What this skill does not do

- **It does not research.** That is step 1, under its own sourcing rules.
- **It does not decide techniques.** That is step 2, from documented evidence.
- **It does not draw the flow.** That is step 3, from a mapping that already exists.
- **It does not write into `samples/`.**

If someone wants only one of those, invoke that skill directly instead of this one.
