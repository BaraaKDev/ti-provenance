# Flow craft — shared by every report type

Everything in this file applies to all three report types. The guide for your subject
covers what is specific to it; this covers what is not.

---

# 1. Tactic ordering

Sort tactics into **operational order** — the sequence the intrusion actually ran in — not
the order the source listed them, and not MITRE's column order.

**MITRE's matrix order is a taxonomy, not a timeline.** Tactics answer "why did the
adversary do this", and the columns group them by purpose. Reading them left to right as a
kill chain is a convenience the framework never claims, and in two places it is actively
misleading. Pick the band table for **the matrix the mapping came from** — the three
matrices do not share a tactic list.

## Enterprise — 15 tactics

| Band | Order |
|---|---|
| **Pre-intrusion** — nothing on the victim network is touched yet | 1 Reconnaissance · 2 Resource Development |
| **Entry** — get in, get a channel | 3 Initial Access · 4 Execution · 5 Command and Control · 6 Persistence |
| **Entrenchment** — make the foothold safe to work from | 7 Stealth · 8 Defense Impairment |
| **Escalation loop** — repeats per host; internal order is conditional, see below | Discovery · Privilege Escalation · Credential Access · Lateral Movement |
| **Actions on objectives** | 13 Collection · 14 Exfiltration · 15 Impact |

Three deliberate departures from MITRE's column order, with the reasoning so you can defend
them to a reviewer:

- **Command and Control moves from 13 to 5.** MITRE places it between Collection and
  Exfiltration, implying the actor worked an entire intrusion with no channel and then built
  one to ship data out. C2 is established immediately after Execution and nearly everything
  downstream depends on it. It sits late in the matrix because "how you talk to the implant"
  pairs *conceptually* with "how data leaves" — a taxonomic pairing, not a temporal one.
- **Discovery and Credential Access swap depending on the mapping.** The one genuinely
  conditional position, so read the techniques rather than the tactic name. **Discovery
  first** when the mapped techniques are local host enumeration (`tasklist`, `netstat`,
  process listing) — that runs on landing, before any credential theft. **Credential Access
  first** when the mapped discovery is domain-wide (`nltest`, AdFind, AD trust enumeration),
  because those queries need credentials to return anything. Privilege Escalation still
  precedes Credential Access either way, because dumping LSASS generally needs SYSTEM first.
- **Persistence moves after Command and Control.** The usual chain is exploit → stager →
  channel → full implant → persistence; the channel normally delivers the thing that
  survives reboot.

## ICS — 12 tactics

No Credential Access and no Exfiltration; ends with two tactics Enterprise has no
equivalent for.

| Band | Order |
|---|---|
| **Entry** | 1 Initial Access · 2 Execution · 3 Command and Control · 4 Persistence |
| **Entrenchment** | 5 Evasion |
| **Escalation loop** | 6 Discovery · 7 Privilege Escalation · 8 Lateral Movement |
| **Actions on objectives** | 9 Collection · 10 Inhibit Response Function · 11 Impair Process Control · 12 Impact |

Keep the ICS objective band in MITRE's own order — it is already causal: suppress the safety
systems, *then* manipulate the process, *then* the physical consequence lands. Reversing
them reads as damage that nothing tried to stop.

## Mobile — 12 tactics

Same names as Enterprise, but TA0030 is still called *Defense Evasion*, and there is no
Reconnaissance, Resource Development or Defense Impairment.

| Band | Order |
|---|---|
| **Entry** | 1 Initial Access · 2 Execution · 3 Command and Control · 4 Persistence |
| **Entrenchment** | 5 Defense Evasion |
| **Escalation loop** | 6 Discovery · 7 Privilege Escalation · 8 Credential Access · 9 Lateral Movement |
| **Actions on objectives** | 10 Collection · 11 Exfiltration · 12 Impact |

## Two honest caveats about this shape

**The escalation loop is a cycle, and a vertical flow flattens it.** The real pattern is
discover → escalate → steal credentials → move → land somewhere new → discover again,
repeating until the actor reaches what they came for. Four sequential cards quietly assert
it happened once. Say "repeated per host" in the phase copy or the transition leaving
Lateral Movement, wherever the reporting supports it.

**Stealth is ambient, not a stage.** Masquerading and obfuscation wrap around every other
action rather than occupying a slot between Persistence and Discovery. Give it a card when
the mapping has discrete stealth techniques worth showing, but do not imply the actor
stopped everything else to be sneaky for a while. Defense Impairment survives as a card far
better, because loading a vulnerable driver to kill EDR usually *is* a discrete, datable
event. Persistence is similar — established at the first foothold, then re-established on
each new host inside the loop.

**Causality still outranks the tables.** They are the default, not a rule to follow off a
cliff. If two phases read backwards for a specific intrusion, reorder them and say why in
the transition. If you cannot write an honest transition explaining why one phase enables
the next, the ordering is wrong — fix the ordering rather than writing a vague transition.

Omit any tactic the mapping does not cover. Never pad the chain to look complete.

## Two recent framework changes to watch for

TA0005 was renamed from *Defense Evasion* to **Stealth**, and **Defense Impairment
(TA0112)** was split out of it. Stealth is avoiding the sensor (masquerading, obfuscation,
valid accounts); Defense Impairment is disabling it (EDR kills, log clearing, BYOVD —
`T1685`). Older mappings still say "Defense Evasion" and lump both together; relabel the
tactic, and split the phase when the mapping contains both kinds.

---

# 2. Building the page

**These flows are light-theme only, by deliberate choice.** No
`@media (prefers-color-scheme: dark)` block and no `[data-theme]` stamps, so the page
renders light on any host theme. Do not add a dark palette back in. This holds only because
every colour is painted explicitly from a token and `color-scheme` is pinned to light — keep
both true of anything you add.

The template's CSS is the contract. Keep the class names and token structure exactly as they
are; if a class or token is not in the template, it does not exist.

## Hero row labels

The small uppercase label beside the chips in the hero is a fixed vocabulary, not free text.
It tells the reader what kind of relationship the chips have to each other, so two reports
that use different words are making different claims. Use exactly these:

| Report | Row | Label |
|---|---|---|
| Threat actor | actor aliases | **Also tracked as** |
| Campaign | actor aliases | **Also tracked as** |
| Campaign | CVE row | **Exploits** |
| Vulnerability — MODE CHAIN, exploit chain | CVE row | **Chain** |
| Vulnerability — MODE CHAIN, remediation cascade | CVE row | **Cascade** |
| Vulnerability — MODE SET | CVE row | **In scope** |

**Chain** and **Cascade** are deliberately different words for MODE CHAIN's two shapes.
*Chain* says the CVEs compose into one attack; *Cascade* says each fix exposed the next, and
that an attacker exploits only one of them. Labelling a cascade "Chain" asserts a
composition that does not exist — which is the same error the mode choice itself guards
against, so keep the label honest for the same reason.

**In scope** is deliberately neutral. MODE SET vulnerabilities have no relationship beyond
appearing in the same report, and the label should not imply one.

## Per phase

- **The heading says what the actor achieves**, not the tactic name repeated. "Break the
  internet-facing edge" beats "Initial Access" — the tactic name is already in the eyebrow.
- **One `.ttp` row per technique**, with the real ID in `.tid`, the ATT&CK technique name,
  and then how *this specific subject* used it. Generic ATT&CK definitions are worthless
  here; the analyst can read those on the website.
- **Wrap tooling and IOCs in `<span class="tool">`** — binaries, CVEs, file paths, domains.
- **Every transition earns its line.** Write the causal link ("with defenses down, they
  harvest credentials"), never filler like "next phase".

## Ordering techniques inside a phase

Rows are read top-down and the first sets what the phase is about, so priority is a real
editorial decision. Apply in order, stopping at the first that separates two rows:

1. **Causality.** If one technique enables another, it goes first — the profiling script
   before the exploit it gates, the escalation before the credential dump it unlocks.
2. **Primary before fallback.** Lead with the signature route, follow with the alternate.
3. **Specific before generic.** A row naming real tooling, a file path or a CVE outranks a
   broad one — that is the row a detection engineer can act on today.
4. **Parent before its own sub-technique.** Never list `T1027.003` above `T1027` when both
   are mapped. Sibling sub-techniques stay adjacent so the family reads as one idea.
5. **Tiebreak — ascending technique ID**, so the same mapping always renders the same page.

This is **not** severity ranking — ATT&CK carries no severity, and inventing one is the kind
of false precision this skill exists to avoid. It is also not a timing claim unless rule 1
applied; techniques inside one tactic are frequently concurrent.

## The objective phase

**The objective phase is optional.** Where the intrusion's purpose *is* known — destruction,
extortion, espionage, persistence-for-later — make it the last phase and mark it
`class="phase impact"`. It is what gives the flow an argument rather than a shape.

**Where the objective is not known, leave it off and say so.** These are reporting
artefacts, and a vulnerability often has no documented impact at all: a CVE grants a
capability, not an intent. A single-phase flow with no objective is a complete and honest
report of a primitive. `Verify-Flow.ps1` does **not** require an impact phase anywhere — it
only checks that if one exists there is exactly one and it comes last. Whether a flow
*should* carry an objective is editorial judgment, and forcing one would push you to invent
an objective, which is the exact failure this skill exists to prevent.

Two rules of thumb. A **threat actor** almost always has a documented objective — that is
what makes them a tracked actor rather than a technique list, so an actor flow ending
without one usually means the mapping is incomplete. A **vulnerability** often does not, and
that is normal; `windows-2026-08-vuln-flow.html` has three flows and no impact phase at all.

If the mapping has no Impact technique but the purpose is documented and unambiguous, you
may add the objective phase — but say plainly in the phase copy that it is the reported
objective rather than a mapped technique, and keep the ATT&CK IDs to the ones actually
mapped.

**Match the objective icon to the objective, not to the phase class.** `class="phase impact"`
is a *visual* treatment. The Impact icon is a struck-through database, which asserts
destruction; using it for an espionage actor states something false:

| Objective | Icon to use |
|---|---|
| Wiping, destruction, denial | Impact — database struck through |
| Ransomware, extortion | Impact — database struck through |
| Espionage, collection, theft of data | **Exfiltration** — data leaving the container |
| Physical damage, loss of control (ICS) | **Impact, ICS variant** — plant struck through |

## Heat

Add `class="phase heat"` starting at **the first phase after the actor has working, durable
access** — after Initial Access, Execution, Persistence and Command and Control have done
their job — and run it through the phase *before* the objective. In practice heat almost
always begins at Stealth or Defense Impairment. The count varies with flow length; do not
aim for a fixed proportion.

## Accent — retune before writing the phases

The accent pair in `:root` is the one thing that changes per subject. An espionage actor
whose objective is quiet collection should not terminate in the same urgent blue as a wiper
crew; the colour is an assertion about intent, so make it a true one. Neutrals carry a faint
bias toward the accent, so shift them with it.

| Objective | `--ember` (objective) | `--steel` (metadata) | Neutrals |
|---|---|---|---|
| Destruction / extortion / disruption | signal blue `#1d4ed8` | slate `#55607a` | white (`--ground: #ffffff`) |
| Espionage / collection | violet `#7c3aed` | slate `#55607a` | white (`--ground: #ffffff`) |

For a **campaign** report, retune to the **actor's** objective, not the CVE severity.
Everything else — class names, structure, token names — stays identical, so the set still
reads as one body of work.

## Coverage gaps

Sparse mappings are common. When tactics are missing, add a short caveat in the footer
`.note` block naming which tactics carry no techniques, and state explicitly that absence
reflects a gap in the published mapping rather than evidence the subject lacks that
capability. These pages get used for gap analysis, and an empty Exfiltration row silently
reads as "they don't exfiltrate".

---

# 3. What the checker cannot judge

`Verify-Flow.ps1` covers everything mechanical. Check these by hand:

- **Whether each technique is under the *right tactic*.** The checker validates ID
  formatting, not semantics, and MITRE's own group pages have twice given a wrong tactic
  (T1005 as Reconnaissance when it is Collection; steganography as Defense Evasion when
  TA0005 is now Stealth).
- **Never "correct" an unfamiliar technique ID from memory.** ATT&CK gains techniques and
  renames tactics regularly, so an ID you do not recognise is far more likely to be newer
  than your training data than wrong. Verify by fetching
  `https://attack.mitre.org/techniques/<ID>/` before changing anything. Only if the page
  genuinely does not exist should you correct it — and then say what you changed and why.
  Silently substituting an ID you merely *think* is right corrupts the mapping while making
  it look more authoritative, which is the worst possible failure for this skill.
- **Sub-technique IDs match their parent's name** — `T1027.003` must read "Obfuscated Files
  or Information: Steganography", not a name borrowed from a neighbour.
- **Phase count matches the mapping** — nothing invented, nothing dropped, and any missing
  tactics called out in the footer caveat.
- **The objective icon matches the objective type**, not the phase class.
- **Every transition states a real causal link.** "Next phase" is not a transition.
