# `mapping.json` schema

The structured output of this skill, written to `subjects/<slug>/handoff/mapping.json`.

**This skill owns this file entirely.** Nothing else writes to it, and this skill writes
nothing else.

An `analysis.json` sits beside it in the same folder, written by an earlier step and carrying
the subject's identity, framing and evidence. **This skill never writes that file.** The
fields it *reads* are documented at the end.

Validate with `scripts/Verify-Mapping.ps1` before finishing.

---

## Shape

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
          "usage": "Path traversal against the FortiOS SSL VPN portal retrieves system files without authenticating; the credentials inside are then used to connect as a real user.",
          "tooling": [],
          "via_cve": "CVE-2018-13379"
        }
      ]
    },
    {
      "tactic": "Defense Impairment",
      "techniques": [
        {
          "id": "T1685",
          "name": "Disable or Modify Tools",
          "usage": "Loads the vulnerable GMER64.sys driver to terminate EDR and antivirus services from kernel mode.",
          "tooling": ["GMER64.sys"]
        }
      ]
    }
  ],
  "arsenal": [
    { "name": "ASPXSpy", "sid": "S0073", "role": "ASP.NET web shell used for execution and persistence", "kind": "Web shell" }
  ]
}
```

## Fields

| Field | Required | Values | Notes |
|---|---|---|---|
| `schema` | yes | `mapping/1.0` | Version guard |
| `subject` | yes | string | Repeated from the analysis so this file stands alone |
| `slug` | yes | folder-safe string | Must match the subject folder name |
| `matrix` | yes | `enterprise` · `ics` · `mobile` | Copied from the analysis, never chosen independently |
| `tactics` | yes | array | One entry per tactic. Non-empty |
| `arsenal` | no | array | **Omit the key entirely** when no tooling is named |

**`subject`, `slug` and `matrix` are duplicated deliberately**, so this file is meaningful on
its own. A consumer holding both files checks that they agree, and the validator does too — a
mismatch means one of the two steps was run against a different subject.

### `tactics[]`

| Field | Required | Notes |
|---|---|---|
| `tactic` | yes | **Must be a valid tactic name for the declared matrix.** See `attack-tactics.md` |
| `techniques` | yes | Non-empty array. A tactic with no techniques is not a tactic you observed |

**Tactic order in the file does not matter.** Emit them in matrix order for readability, but a
consumer applies its own ordering rules and will not rely on yours.

**Tactic names are validated, so the matrix matters.** Enterprise uses **Stealth** and
**Defense Impairment**; Mobile still uses *Defense Evasion*; ICS uses *Evasion*. Writing an
Enterprise name into an ICS mapping fails.

### `techniques[]`

| Field | Required | Notes |
|---|---|---|
| `id` | yes | `T####` or `T####.###` — sub-technique suffix is exactly three digits |
| `name` | yes | The ATT&CK technique name, matching the ID |
| `usage` | yes | **How *this* subject used it** — never the ATT&CK description |
| `tooling` | no | string[] of tool names. May be empty |
| `via_cve` | no | A single CVE ID. **Only on techniques a declared CVE actually enables** |

**`usage` is the field that makes the mapping worth reading.** "Renames Plink to
`systems.exe`" earns a row; "adversaries may disguise artifacts" does not. Both `name` and
`usage` are validated as present and non-blank — a blank one silently produces an empty row
downstream, which is why the check exists.

**`via_cve` must name a CVE the analysis declared.** The validator cross-checks it against
`cves` in `analysis.json` and rejects anything undeclared. Identifiers only — CVSS, CWE, KEV
status and fixed versions are looked up live by whoever needs them, never stored here.

### `arsenal[]`

| Field | Required | Notes |
|---|---|---|
| `name` | yes | As the evidence names the tool |
| `sid` | no | ATT&CK software ID, `S####`. Omit for tooling ATT&CK does not track |
| `role` | yes | What it does **for this subject**, one line |
| `kind` | no | `Wiper` · `Ransomware` · `Backdoor` · `Web shell` · `Cred access` · `Discovery` · `Tunnelling` |

Build it from tools already named in a `usage` field. `kind` carries real weight for
destructive tooling: `Wiper` and `Ransomware` are different claims about what a victim can
recover.

---

## What this skill reads but does not write

`analysis.json`, written by an earlier step. Only these fields concern this skill:

| Field | Used for |
|---|---|
| `chronology[].detail` | **the primary evidence** — the behaviour every technique is derived from |
| `background` | tradecraft documented across the whole history rather than tied to one date |
| `subject`, `slug`, `matrix` | copied into the output; `matrix` also picks the tactic vocabulary |
| `cves` | the only CVE IDs that may appear in `via_cve` |
| `objective` | a cross-check on the Impact tactic, never a source for one |
| `sources` | the evidence behind a claim, when you need to go back to it |

Everything else in that file — `subject_type`, `aliases`, `facts`, `risk`, `confidence`,
`report` — belongs to other steps. Read it for context if you like; do not copy it into the
mapping.

**The file may be absent.** This skill runs standalone, in which case the evidence comes from
whatever the analyst supplied and `subject`, `slug` and `matrix` are established with them
directly. A missing file is never an error; a present but malformed one is.

---

## Worked example

`samples/agrius/handoff/mapping.json` is a complete, validated instance — 12 tactics, 22 techniques,
one `via_cve`, nine arsenal entries. Read it before writing a new one.
