# `analysis.json` schema

The structured output of this skill, written to `subjects/<slug>/handoff/analysis.json` alongside the
human-readable `analysis.html`.

**This skill owns this file entirely.** Nothing else writes to it.

A separate `mapping.json` sits beside it in the same folder, holding the ATT&CK tactics and
techniques. **This skill never writes that file** and its schema is not documented here — see
*What this skill does not write* at the end.

Validate with `scripts/Verify-Mapping.ps1` before finishing.

---

## Write the JSON first, then render the report from it

`background`, `chronology` and `risk` are the same content as the report's Overview and
Risk & Impact sections. Produce them once as data and build the HTML from that — it is what
stops the two halves of one subject disagreeing.

---

## Shape

```json
{
  "schema": "analysis/1.0",
  "subject": "Agrius",
  "slug": "agrius",
  "subject_type": "campaign",
  "matrix": "enterprise",
  "attack_id": "G1030",
  "aliases": ["Pink Sandstorm", "AMERICIUM"],
  "objective": "destruction",
  "objective_note": "Wipers disguised as ransomware",
  "cves": ["CVE-2018-13379"],
  "vuln_relationship": "none",
  "confidence": "published",
  "facts": {
    "attribution": "Iran, MOIS-linked",
    "active_since": "2020",
    "targets": "Israel and the wider Middle East"
  },
  "background": [
    "Agrius is an Iranian threat actor active since 2020, running wiper and ransomware operations against Israeli targets."
  ],
  "chronology": [
    {
      "date": "2020-11",
      "event": "Apostle wiper developed",
      "detail": "Early builds often failed to destroy files, so the group fell back to DEADWOOD to finish intrusions.",
      "key": true,
      "sources": [2]
    }
  ],
  "risk": [
    { "sector": "Energy", "level": "critical", "why": "Repeatedly targeted." }
  ],
  "sources": ["https://attack.mitre.org/groups/G1030/"],
  "report": "analysis.html"
}
```

## Fields

| Field | Required | Values | Notes |
|---|---|---|---|
| `schema` | yes | `analysis/1.0` | Version guard |
| `subject` | yes | string | Becomes the report `<h1>` |
| `slug` | yes | folder-safe string | Must match the subject folder name |
| `subject_type` | yes | `actor` · `vulnerability` · `campaign` | Decides which report shape a consumer builds |
| `matrix` | yes | `enterprise` · `ics` · `mobile` | Which ATT&CK tactic vocabulary applies |
| `attack_id` | no | e.g. `G1030` | Omit if the subject has no ATT&CK group ID |
| `aliases` | no | string[] | Other tracked names for the same subject |
| `objective` | yes | `destruction` · `extortion` · `espionage` · `collection` · `disruption` · `unknown` | Drives the accent palette |
| `severity` | yes | `critical` · `high` · `moderate` · `low` · `informational` | One level for the whole subject, shown on the cover. Shares four words with the sector rows; the floor is `informational` rather than `minimal` |
| `severity_note` | no | string | One line naming the axis that kept it off the level above |
| `objective_note` | no | string | One line expanding on the objective |
| `cves` | if any | string[] of CVE IDs | Identifiers only — never CVE details, which go stale |
| `vuln_relationship` | if `cves` | `none` · `exploit-chain` · `remediation-cascade` | See below |
| `confidence` | yes | `published` · `derived` | Whether the framing rests on published reporting or your own analysis |
| `facts` | no | object of string:string | The hero facts strip, rendered in order |
| `background` | yes | string[] | One entry per paragraph. Who or what the subject is |
| `chronology` | yes | array | Dated activity, **oldest first**. See below |
| `risk` | no | array | `sector`, `level`, `why`. `level` is `critical`·`high`·`moderate`·`low`·`minimal` |
| `sources` | yes | string[] of URLs | Every URL cited. Other fields index into this array |
| `report` | no | filename | Usually `analysis.html`, for cross-linking |

**`objective: "unknown"` is a legitimate answer.** A CVE grants a capability, not an intent.
Guessing here produces a confident-looking claim about motive that nothing supports.

**`vuln_relationship` is the highest-risk field.** `exploit-chain` = exploiting one gives you
what you need for the next. `remediation-cascade` = fixing one exposed the next. `none` =
independent. A single CVE is always `none` — one CVE composes with nothing. Getting this
wrong makes a downstream report assert a dependency that does not exist, or hide one that does.

## `chronology[]`

| Field | Required | Notes |
|---|---|---|
| `date` | yes | `YYYY`, `YYYY-MM` or `YYYY-MM-DD`. Fixed format because it sorts chronologically as a plain string |
| `event` | yes | Short headline for what happened |
| `detail` | yes | **What the subject actually did.** See below |
| `key` | no | `true` marks a turning point |
| `sources` | no | Integer indices into the top-level `sources` array |

**Oldest first.** Chronology is not a formatting preference — it is what lets a reader see
escalation, dormancy and shifts in targeting. The validator enforces the ordering.

**`detail` is the evidence the rest of the pipeline works from.** A later step derives ATT&CK
techniques from it, so write it so that is possible without re-researching: *"deployed
ASPXSpy web shells, then used Mimikatz against LSASS"* is usable, *"conducted a destructive
attack"* is not. Where tradecraft is documented across a subject's whole history rather than
tied to one date, put it in `background` instead.

**Source indices keep provenance across the handoff**, so a later step can cite the same
evidence this analysis did. The validator rejects indices that do not resolve.

---

## What this skill does not write

**No ATT&CK technique IDs anywhere in this file.** You record *what happened*; a separate
mapping step decides *which technique that is*. Pre-empting it turns that step into
rubber-stamping, and a wrong guess gets laundered into an authoritative-looking ID.

The tactics and techniques live in `mapping.json`, written by a different step and validated
by the same script. If you find yourself wanting to add a `techniques` array here, the answer
is a better `chronology[].detail` instead.

---

## Worked example

`subjects/agrius/handoff/analysis.json` is a complete, validated instance. Read it before writing a
new one.
