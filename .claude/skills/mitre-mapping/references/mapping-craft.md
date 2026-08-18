# Mapping craft

How to get from an account of what happened to a defensible set of techniques. The tactic
vocabulary and the boundaries between tactics are in `attack-tactics.md`; this file is about
the decisions either side of that.

---

## Evidence tiers

Every technique you write rests on one of three kinds of claim. **Two are mappable and one is
not**, and knowing which you are on is the whole discipline.

| Tier | What it is | Mappable | How it reads in `usage` |
|---|---|---|---|
| **Documented** | A source says the subject did this | yes | Plainly: *"Renames Plink to systems.exe."* |
| **Inferred** | The evidence describes something that could only have worked this way | yes, marked | Hedged and attributed: *"Reaching cmd.exe through the web shell implies..."* |
| **Assumed** | Subjects of this type usually do this | **no** | Does not appear |

**Inference is legitimate and has a narrow definition.** It is mechanical, not statistical: a
report saying operators ran commands through an ASPX web shell supports Windows Command Shell
execution because that is how the mechanism works, not because web-shell operators tend to.
The test is whether you could defend it to someone who has read the same source — if your
answer starts "actors like this normally", you are on the third tier.

**The third tier is where fabricated mappings come from.** "Ransomware crews disable shadow
copies", "APTs always establish C2", "they must have escalated privileges somehow" — each is a
reasonable prior and none is an observation. A prior in a mapping is indistinguishable from a
finding once it is rendered, cited and acted on.

**Absence of evidence maps to absence of a technique.** A subject with no documented C2 gets
no Command and Control tactic. That gap is information: it says the reporting does not cover
it. Filling it produces a mapping that looks complete and is partly invented, which is worse
than one that is visibly thin.

---

## Sub-technique depth

**Go as deep as the evidence goes and no further.** The parent technique is always a valid
answer; a sub-technique is a second claim on top of it, and it needs its own support.

| Evidence says | Map | Not |
|---|---|---|
| "dumped credentials" | `T1003` | `T1003.001` |
| "dumped credentials from LSASS" | `T1003.001` | |
| "used a web shell" | `T1505.003` | — the mechanism is already specific |
| "achieved execution" | nothing | any Execution technique |
| "ran commands via cmd.exe" | `T1059.003` | `T1059` |

A wrong sub-technique is worse than a right parent, because the decimal reads as precision
that came from somewhere. A defender who filters on `T1003.001` and builds LSASS-specific
detections has been misdirected by a guess.

**When several sub-techniques are plausible and the evidence does not choose**, map the parent
once rather than the sub-techniques speculatively. **When the evidence supports several
distinctly**, map each — Agrius dumping both LSASS memory and the SAM hive is `T1003.001` and
`T1003.002`, two evidenced mechanisms, not one hedged parent.

**Check the sub-technique still exists and still sits where you think.** ATT&CK reorganises;
sub-techniques get promoted, merged and renumbered between versions. This is the specific
failure that has already bitten this project.

---

## Verifying IDs

**Every ID gets checked at `https://attack.mitre.org/techniques/<ID>/` before it is written.**
Three things to confirm, not one:

1. **The ID exists.** A 404 means you invented it.
2. **The name matches** what you are about to put in `name`. A drifted name is how a stale
   mapping announces itself.
3. **ATT&CK lists your tactic for it.** The technique page names its tactics. If yours is not
   among them, either the tactic is wrong or the technique is — resolve it before writing.

**Never "correct" an unfamiliar ID from memory.** An ID you do not recognise is far more likely
to be newer than your training data than to be wrong. This project has one real instance: a
correct `T1685` was changed to a fabricated `T1562.001` and the change was reported as a fix.
The same caution applies to tactic names — Enterprise **Stealth** and **Defense Impairment**
are current, however unfamiliar they look against older reporting.

---

## Writing `usage`

`usage` is the field that decides whether the mapping is worth reading. It answers **what did
*this* subject do**, and it is the one thing a consumer cannot look up for itself.

| Good | Why |
|---|---|
| "Renames the Plink tunnelling tool to systems.exe to blend with system binaries." | Names the tool, the disguise and the purpose |
| "Parks 7zip archives in `C:\windows\temp\s\` ahead of exfiltration." | A defender can hunt this |
| "Loads the vulnerable GMER64.sys driver to terminate EDR from kernel mode." | Mechanism, not category |

| Bad | Why |
|---|---|
| "Adversaries may disguise artifacts to evade defenses." | The ATT&CK description. Says nothing about this subject |
| "Used masquerading." | Restates the technique name |
| "Employs sophisticated evasion techniques." | Assertion with no content |

Three rules:

- **One or two sentences.** A paragraph means the technique is doing too much and should
  probably be two rows.
- **Name the concrete thing** — tool, filename, path, service name, protocol — wherever the
  evidence gives you one. That detail is the difference between a report and a catalogue.
- **Keep inference visible in the wording.** *"Reaching cmd.exe through the web shell implies
  command-shell execution"* is honest; stating it flatly is not.

---

## `via_cve`

Tag a technique with `via_cve` **only when a declared CVE is what enables it**. Three
constraints:

- **Only CVEs the analysis declared.** A `via_cve` naming a CVE that is not in the analysis's
  `cves` array fails validation, and rightly — it means the two files disagree about what the
  subject exploited.
- **The technique the CVE *grants*, not everything downstream.** A pre-auth RCE grants
  `T1190` under Initial Access, and possibly an Execution technique. It does not grant the
  credential dumping that happened three steps later just because that intrusion started here.
- **Never put CVE details in the mapping.** Identifiers only. CVSS, CWE, KEV status and fixed
  versions are looked up live by whoever needs them; baking them in guarantees they go stale.

**For a chain**, tag each CVE on the technique it enables, in the order they are exploited —
that is what makes the chain legible. **For unrelated CVEs**, each is tagged independently and
nothing implies a sequence.

---

## The arsenal

`arsenal[]` is the tooling inventory. Build it **from tools already named in your `usage`
fields** — a tool in the arsenal that appears in no technique is not part of the attack path.

| Field | Notes |
|---|---|
| `name` | As the evidence names it |
| `sid` | The ATT&CK software ID, `S####`. **Verify at `https://attack.mitre.org/software/<SID>/`.** Omit for tooling ATT&CK does not track |
| `role` | What it does **for this subject**, one line |
| `kind` | Short category: `Wiper`, `Ransomware`, `Backdoor`, `Web shell`, `Cred access`, `Discovery`, `Tunnelling` |

**`kind` matters most for destructive tooling.** A `Wiper` and a `Ransomware` entry are
different claims about what a victim can expect to recover, and a subject carrying both is
making a specific point — that the ransomware is cover.

**Omit `arsenal` entirely when no tooling is named.** An empty array asserts that you looked
and found none; a missing key says the question does not arise. For a vulnerability with no
attributed exploitation, the key should be missing.

---

## Mapping by subject type

The evidence shape differs, so the mapping does.

**Actor.** The fullest case: an intrusion path across most of the matrix, built from a
chronology of campaigns. Watch for tradecraft that appears across the whole history rather
than at one date — it will be in `background`, not `chronology`, and it is easy to miss.

**Vulnerability.** Usually thin, and should be. **A CVE maps to what exploitation achieves**,
not to a full intrusion. A pre-auth RCE is Initial Access and Execution; what an attacker does
afterwards is a different subject unless someone documented it. For an exploit chain, each CVE
gets its own technique in exploitation order. If nobody has been observed using it, the
mapping stops at the capability and `objective: unknown` follows naturally.

**Campaign.** An actor plus the CVEs they exploited. The whole path is in scope, and the CVEs
appear as `via_cve` on the specific techniques they enable — usually only the first one or two.
The commonest error is tagging half the mapping with the CVE because the intrusion started
there.

---

## Recurring mistakes

- **Mapping the report's vocabulary instead of the subject's behaviour.** A source using the
  word "phishing" is not evidence of `T1566`; a described email with an attachment is. Vendor
  prose reaches for ATT&CK words loosely.
- **Padding for coverage.** Fifteen tactics is not better than six. The matrix is a vocabulary,
  not a checklist, and a full-looking mapping built on inference is the failure this whole
  file exists to prevent.
- **Reasoning from technique to tactic.** Landing on a familiar technique and then picking a
  tactic to justify it. Always ask what the behaviour accomplished first.
- **Duplicating one behaviour across tactics** because the technique is listed under several.
  See *One behaviour, several tactics* in `attack-tactics.md`.
- **Inheriting a source's stale tactic names.** Reporting that predates the Enterprise split
  says "Defense Evasion" for what is now Stealth or Defense Impairment. Translate it; do not
  copy it.
- **Letting `objective` generate an Impact phase.** The analysis's objective is a cross-check
  on your Impact techniques, not a source for them.
- **Correcting an unfamiliar ID from memory.** Covered above, and it has already happened once.
