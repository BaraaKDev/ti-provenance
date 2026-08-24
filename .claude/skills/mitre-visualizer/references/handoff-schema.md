# Handoff schema

Two JSON files, one per producing step, both written into `subjects/<slug>/handoff/`:

| File | Written by | Carries |
|---|---|---|
| `analysis.json` | the **analysis step** | subject identity, framing, risk, sources |
| `mapping.json` | the **mapping step** | the ATT&CK tactics and techniques |

**Each file is owned by exactly one step.** Nothing is co-written, so two steps can never
collide in the same file. A consumer reads whichever files are present.

> This file is carried by every skill that touches the handoff, deliberately duplicated so
> each skill stays self-contained. The orchestration layer is where the copies are reconciled.

## When the files exist

Only when a pipeline run produces them. A skill invoked **on its own** will not find them and
must fall back to whatever the analyst supplied directly — pasted text, a CSV, a `.docx`.
Never fail because a handoff file is absent; fail only when a file is present and malformed.

Validate with `scripts/Verify-Mapping.ps1` before consuming.

---

# `analysis.json`

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

| Field | Required | Values | Why a consumer needs it |
|---|---|---|---|
| `schema` | yes | `analysis/1.0` | Version guard |
| `subject` | yes | string | Page `<h1>` |
| `slug` | yes | folder-safe string | Must match the folder name |
| `subject_type` | yes | `actor` · `vulnerability` · `campaign` | **Routes to one of three report templates** |
| `matrix` | yes | `enterprise` · `ics` · `mobile` | The three have different tactic orders |
| `attack_id` | no | e.g. `G1030` | Hero eyebrow |
| `aliases` | no | string[] | Alias chips |
| `objective` | yes | `destruction` · `extortion` · `espionage` · `collection` · `disruption` · `unknown` | Sets the accent **and** whether there is an impact phase |
| `severity` | yes | `critical` · `high` · `moderate` · `low` · `informational` | One level for the whole subject, shown on the cover. Shares four words with the sector rows; the floor is `informational` rather than `minimal` |
| `severity_note` | no | string | One line naming the axis that kept it off the level above |
| `objective_note` | no | string | One line, used in impact-phase copy |
| `cves` | if any | string[] of CVE IDs | Identifiers only — details are looked up live |
| `vuln_relationship` | if `cves` | `none` · `exploit-chain` · `remediation-cascade` | Picks chain vs set, and the hero row label |
| `confidence` | yes | `published` · `derived` | Drives the footer provenance caveat |
| `facts` | no | object of string:string | Hero facts strip, rendered in order |
| `background` | yes | string[] | One entry per paragraph. Who or what the subject is |
| `chronology` | yes | array | Dated activity, **oldest first**. See below |
| `risk` | no | array | Sector risk; `level` is `critical`·`high`·`moderate`·`low`·`minimal` |
| `sources` | yes | string[] of URLs | Footer citations. Other fields index into this array |
| `report` | no | filename | The human-readable analysis, for cross-linking |

### `chronology[]`

| Field | Required | Notes |
|---|---|---|
| `date` | yes | `YYYY`, `YYYY-MM` or `YYYY-MM-DD`. This format sorts chronologically as a plain string, which is why it is fixed |
| `event` | yes | Short headline for what happened |
| `detail` | yes | **What the subject actually did.** This is the field a mapping step reads to derive techniques, so name tooling, commands and behaviour — not just outcomes |
| `key` | no | `true` marks a turning point |
| `sources` | no | Integer indices into the top-level `sources` array |

**Entries must be ordered oldest first.** Chronology is not a formatting preference: it is
what lets a reader see escalation, dormancy and shifts in targeting. The validator enforces
the ordering.

**`detail` carries the evidence the rest of the pipeline works from.** "Deployed ASPXSpy web
shells, then used Mimikatz to dump LSASS" is mappable; "conducted a destructive attack" is
not. Write it so a mapping step can derive ATT&CK techniques from it without re-researching.

**Do not put technique IDs here.** The analysis records *what happened*; the mapping step
decides *which technique that is*. Pre-empting it turns mapping into rubber-stamping, and a
wrong guess gets laundered into an authoritative ID.

**`objective: "unknown"` is a legitimate value.** A CVE grants a capability, not an intent. It
produces a flow with no impact phase, which is honest rather than incomplete.

**`vuln_relationship` is the highest-risk field.** `exploit-chain` = exploiting one gives you
what you need for the next. `remediation-cascade` = fixing one exposed the next. `none` =
independent. Wrong here means the report asserts a dependency that does not exist, or hides
one that does. A single CVE is always `none` — one CVE composes with nothing.

---

# `mapping.json`

```json
{
  "schema": "mapping/1.0",
  "subject": "Agrius",
  "slug": "agrius",
  "matrix": "enterprise",
  "tactics": [
    {
      "tactic": "Initial Access",
      "techniques": [
        {
          "id": "T1190",
          "name": "Exploit Public-Facing Application",
          "usage": "Path traversal against the FortiOS SSL VPN portal retrieves system files.",
          "tooling": [],
          "via_cve": "CVE-2018-13379"
        }
      ]
    }
  ],
  "arsenal": [
    { "name": "ASPXSpy", "sid": "S0073", "role": "ASP.NET web shell", "kind": "Web shell" }
  ]
}
```

| Field | Required | Notes |
|---|---|---|
| `schema` | yes | `mapping/1.0` |
| `subject` · `slug` · `matrix` | yes | Repeated so this file stands alone; a consumer holding both files should check they agree |
| `tactics` | yes | Array, one entry per tactic |
| `tactics[].tactic` | yes | **Must be a valid tactic name for the declared matrix** |
| `tactics[].techniques` | yes | Non-empty array |
| `techniques[].id` | yes | `T####` or `T####.###` — three-digit sub-technique |
| `techniques[].name` | yes | The ATT&CK technique name |
| `techniques[].usage` | yes | **How *this* subject used it** — not the generic definition |
| `techniques[].tooling` | no | string[] |
| `techniques[].via_cve` | no | Only on techniques a CVE actually enables |
| `arsenal` | no | Omit entirely if no tooling is mapped |
| `arsenal[].kind` | no | `Wiper`, `Ransomware` etc. mark destructive tooling |

**Tactic names must match the matrix.** Enterprise uses **Stealth**, not "Defense Evasion";
Mobile still uses *Defense Evasion*; ICS uses *Evasion*.

**`usage` is the field that makes a report worth reading.** "Renames Plink to `systems.exe`"
earns a row; "adversaries may disguise artifacts" does not.

**Tactic order in the file does not matter.** A consumer re-orders using its own rules.

---

# Which fields each consumer reads

**A mapping step** turns evidence into ATT&CK techniques. It reads `analysis.json`:

| Field | Used for |
|---|---|
| `chronology[].detail` | **the primary input** — the behaviour techniques are derived from |
| `background` | orientation: who the subject is, what they are for |
| `subject`, `matrix` | naming, and which tactic vocabulary applies |
| `cves` | which techniques should carry a `via_cve` tag |
| `sources` | citing the same evidence the analysis did |

**A visualization step** renders the flow. It reads both files:

| From `analysis.json` | Used for |
|---|---|
| `subject_type` | picking the report template |
| `matrix` | tactic ordering |
| `objective` | accent palette, impact phase |
| `cves` + `vuln_relationship` | chain vs set, hero row label |
| `subject`, `attack_id`, `aliases`, `facts` | hero block |
| `confidence`, `sources` | footer provenance |

| From `mapping.json` | Used for |
|---|---|
| `tactics[]` | the flow phases |
| `techniques[]` | the rows inside each phase |
| `via_cve` | wiring techniques to the CVE that enables them |
| `arsenal[]` | the Arsenal section |

**A bulletin step** composes the final document from `chronology` and `risk` — which is why
those live here as data rather than only inside rendered HTML. Nothing downstream should ever
have to parse a rendered page to recover something the pipeline already knew.

**Never taken from either file:** tactic ordering, icons, colour, phase headings, transitions,
and every CVE fact (CVSS, CWE, KEV, fixed versions). Those come from the consumer's own
references and live lookups. The handoff supplies content and judgment; the consumer supplies
craft.

---

# Worked example

`samples/agrius/handoff/analysis.json` and `samples/agrius/handoff/mapping.json` are complete, validated
instances. Read them before writing new ones.
