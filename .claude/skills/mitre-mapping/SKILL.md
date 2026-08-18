---
name: mitre-mapping
description: Derives a MITRE ATT&CK mapping — which tactics and techniques a named threat actor, vulnerability or campaign actually used, and the attack path they form — from documented evidence, then writes subjects/<slug>/handoff/mapping.json. Reads the subject's analysis.json when one exists, otherwise works from a supplied report, advisory or narrative. Use when asked to map a subject to ATT&CK, identify its techniques or tactics, or work out the attack path an intrusion takes. Do NOT use it to research a subject from scratch, and do NOT use it to render a mapping as a diagram or report.
---

# MITRE ATT&CK Mapping

Turns an evidenced account of what a subject did into the tactics and techniques that account
represents, and writes it as `subjects/<slug>/handoff/mapping.json`.

The job is **judgment, not lookup.** The evidence says *"renamed Plink to systems.exe"*; you
decide that is `T1036` under Stealth, that it is Stealth rather than Defense Impairment, and
that it is `T1036` rather than a sub-technique. Each of those is a decision that can be wrong.

## Where this sits

**Step 2 of the pipeline.** One output: `subjects/<slug>/handoff/mapping.json`. **This skill
owns that file entirely** — nothing else writes to it, and this skill writes nothing else.

**Path convention.** `references/` and `scripts/` are relative to this skill folder.
`subjects/` is relative to the TI-Reporting project root.

## Input

**Preferred: `subjects/<slug>/handoff/analysis.json`.** A structured account of the subject written by
an earlier step. The fields that matter:

| Field | What you do with it |
|---|---|
| `chronology[].detail` | **the primary evidence** — the behaviour every technique is derived from |
| `background` | tradecraft documented across the subject's whole history rather than tied to one date |
| `matrix` | which of the three tactic vocabularies applies. Do not override it |
| `subject`, `slug` | copied into your output so it stands alone |
| `cves` | the only CVE IDs you may tag with `via_cve` |
| `objective` | a cross-check on the Impact tactic, **not** a licence to invent one |
| `sources` | what the evidence rests on, when you need to go back to it |

**If there is no `analysis.json`**, work from whatever the analyst supplied — a vendor report,
an advisory, pasted notes. Absence is never a failure; this skill runs standalone. What you
cannot do is proceed with *no* evidence at all. See *Refusing to map* below.

**Never override the analysis.** If `matrix` says `ics`, you map ICS tactics even where an
Enterprise technique feels closer. If the evidence genuinely contradicts the analysis, say so
in your reply — do not silently correct it in the JSON.

## Method

**1. Inventory the behaviour before naming anything.** Read every `chronology[].detail` and
every `background` paragraph, and list what the subject *did* — verbs and objects, in the
evidence's own words. `"loaded GMER64.sys to terminate EDR"`, not `"defence evasion"`. Naming
techniques while reading is how you end up mapping the words a report used rather than the
actions it described.

**2. For each behaviour, ask two questions in this order.** *What did this accomplish for the
adversary?* gives the **tactic**. *By what specific mechanism?* gives the **technique**.
Reversing the order is the single most common way mappings go wrong — you land on a familiar
technique and then reason backwards to a tactic that does not match what happened.

**3. Verify every technique ID live.** `https://attack.mitre.org/techniques/<ID>/`. Confirm
the ID exists, that its name matches what you are about to write, and that the tactic you have
chosen is one ATT&CK actually lists for it. Never skip this, and never "correct" an unfamiliar
ID from memory — see the warning at the end of this file.

**4. Choose depth honestly.** Go as deep as the evidence goes and no deeper. *"Dumped
credentials"* is `T1003`. *"Dumped credentials from LSASS"* is `T1003.001`. Adding the decimal
the evidence does not support is fabrication that looks like precision.

**5. Write `usage` as what *this* subject did.** One or two sentences, concrete, naming the
tooling, path or command where the evidence gives one. Never the ATT&CK description.

**6. Tag CVEs and build the arsenal.** `via_cve` only on techniques a declared CVE actually
enables. `arsenal[]` from tooling named in the evidence.

**7. Read the whole thing as an intrusion path.** See *The path check* below.

**8. Validate**, then report what you mapped and — just as important — what you could not.

`references/mapping-craft.md` carries all of this in detail: the evidence tiers, the
one-behaviour-many-techniques rules, sub-technique depth, `usage` craft, the arsenal, and the
mistakes that recur. Read it before your first mapping.

## The tactic vocabulary

`references/attack-tactics.md` lists every tactic in all three matrices, what each one means,
and where the boundaries between them actually fall. **The matrices are not interchangeable**
and the names are not cosmetic — a consumer validates them and will reject an invalid one.

Two boundaries cause nearly every misplacement, both covered in that file:

- **Stealth vs Defense Impairment** (Enterprise). *Did they hide from the defensive tooling,
  or attack it?* Renaming a binary to blend in is Stealth. Loading a vulnerable driver to kill
  the EDR is Defense Impairment. This split is recent; older reporting predates it and will
  have called both "Defense Evasion".
- **Discovery vs Reconnaissance.** Inside the victim environment is Discovery. Outside it,
  before access, is Reconnaissance.

## The path check

The mapping is not a checklist of techniques — it is the **attack path**, and it has to read
as one. Before validating, narrate the intrusion from your own tactics, in order, out loud:

> They got in *how*, ran code *how*, kept access *how*, then reached the objective *how*.

Three things that narration surfaces:

- **A break in the path.** Credential Access and Lateral Movement with no Execution between
  them usually means you dropped a behaviour, not that the intrusion teleported. Go back to
  the evidence. If the evidence really is silent, the gap stays — but you should know it is
  there and say so.
- **A tactic doing no work.** If removing a phase changes nothing about the story, it was
  padding. Coverage is not the goal; a five-tactic mapping that is entirely evidenced beats a
  fifteen-tactic one where ten are inferred from actor type.
- **An ending that does not match.** If the analysis says `objective: destruction` and nothing
  in Impact destroys anything, one of the two is wrong. Say which, in your reply.

## Refusing to map

**Do not map what the evidence does not show.** Three cases where the answer is to say so
rather than produce something:

- **Nothing to work from.** A subject name and no account of behaviour is not evidence. Ask
  for the report or the analysis rather than assembling a plausible-looking intrusion.
- **Behaviour described only as an outcome.** *"Conducted a destructive attack"* supports
  `T1485` and nothing else. Do not fill in the access, execution and persistence an attack
  like that "must have" involved.
- **Actor-type inference.** *"Ransomware crews usually disable shadow copies"* is a prior, not
  an observation. It never becomes a mapped technique.

A thin mapping is a finding. A padded one is a fabrication that will be read as fact, cited,
and eventually acted on.

## Output

Write `subjects/<slug>/handoff/mapping.json`. Full contract in `references/mapping-schema.md`.

```json
{
  "schema": "mapping/1.0",
  "subject": "{{SUBJECT}}",
  "slug": "{{folder-safe-slug}}",
  "matrix": "enterprise | ics | mobile",
  "tactics": [
    {
      "tactic": "{{tactic name valid for the declared matrix}}",
      "techniques": [
        {
          "id": "T#### | T####.###",
          "name": "{{the ATT&CK technique name}}",
          "usage": "{{how THIS subject used it - concrete, not the ATT&CK description}}",
          "tooling": ["{{named tools, omit or leave empty if none}}"],
          "via_cve": "{{CVE-YYYY-NNNNN, only when a declared CVE enables this technique}}"
        }
      ]
    }
  ],
  "arsenal": [
    { "name": "{{tool}}", "sid": "{{S####, omit if none}}", "role": "{{what it does here}}", "kind": "{{Wiper | Ransomware | Backdoor | Web shell | Cred access | Discovery | Tunnelling}}" }
  ]
}
```

Four things about the output specifically:

- **Every technique needs a `usage`.** A row with an ID and no account of how it was used is
  the ATT&CK catalogue restated, and a consumer will render it as though it were a finding.
- **Tactic order in the file does not matter.** Emit them in matrix order for readability; a
  consumer applies its own ordering rules and will not trust yours.
- **`arsenal` is optional — omit the key entirely** when no tooling is named. An empty array
  is not the same statement.
- **Write it without a BOM.** `Set-Content -Encoding utf8` on PowerShell 5.1 emits one and it
  breaks downstream parsing:
  ```powershell
  [System.IO.File]::WriteAllText($p, $json, (New-Object System.Text.UTF8Encoding($false)))
  ```

Validate before finishing:

```powershell
.\.claude\skills\mitre-mapping\scripts\Verify-Mapping.ps1 -Path .\subjects\<slug>
```

It checks tactic names against the declared matrix, technique ID format, that every technique
carries a `name` and a `usage`, that the two files agree on subject and matrix, and that every
`via_cve` names a CVE the analysis declared. It reports `analysis.json` as absent when you ran
standalone, which is expected. **It cannot tell you whether a technique sits under the right
tactic, or whether the mapping is any good** — that is what the path check is for.

## Files

```
.claude/skills/mitre-mapping/
  SKILL.md                        this file
  references/
    attack-tactics.md             every tactic in all three matrices, and the boundaries
    mapping-craft.md              evidence to technique: the judgment rules
    mapping-schema.md             the mapping.json contract this skill writes
  scripts/
    Verify-Mapping.ps1            validates the JSON handoff
```

> `Verify-Mapping.ps1` is a **deliberate duplicate**, carried identically by every skill that
> touches the handoff. `mapping-schema.md` is **scoped, not duplicated** — it documents
> `mapping.json` in full because this skill writes it, and only those `analysis.json` fields
> this skill reads. A skill with a different relationship to the handoff documents a different
> subset.
>
> Each skill in this project is self-contained and references nothing inside another skill, so
> a shared contract is copied rather than linked. `CLAUDE.md` is the only place that knows the
> other skills exist, and is where the copies get reconciled if the contract changes.

> **Never invent or "correct" an ATT&CK ID.** Method step 3 above is the instruction;
> `references/mapping-craft.md` §*Verifying IDs* carries the three-point check, the tactic-name
> corollary, and the real error this project has already made. Do not restate the rule here —
> it was written out three times in this one skill and the copies are what drift.

> The script is deliberately **pure ASCII**, and every `Get-Content` reading a data file passes
> **`-Encoding UTF8`**. Windows PowerShell 5.1 reads `.ps1` as ANSI without a BOM, so a literal
> em-dash is a parser error — use `\uXXXX` escapes; and the same ANSI default silently shreds
> non-ASCII content before any regex sees it.
