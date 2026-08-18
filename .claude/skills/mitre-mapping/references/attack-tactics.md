# ATT&CK tactics

Every tactic in the three matrices this project maps against. **39 tactics total.** The
`matrix` field in the analysis picks which table applies; they are not interchangeable and a
consumer validates the names against exactly these lists.

Verified against `https://attack.mitre.org/tactics/<matrix>/` on 2026-08-16. If a tactic you
expect is missing, or one here is unfamiliar, **the site is right and this file is stale** —
re-check it rather than assuming the framework has not moved.

---

## Enterprise — 15 tactics

| # | Tactic | ID | Map here when the adversary is... |
|---|---|---|---|
| 1 | Reconnaissance | TA0043 | gathering information to plan operations, **before** having access |
| 2 | Resource Development | TA0042 | building or acquiring what the operation runs on — infrastructure, accounts, capabilities |
| 3 | Initial Access | TA0001 | getting into the network for the first time |
| 4 | Execution | TA0002 | running code on a system they have reached |
| 5 | Persistence | TA0003 | arranging to still be there after a reboot, a credential change or a cleanup |
| 6 | Privilege Escalation | TA0004 | obtaining higher permissions than they entered with |
| 7 | **Stealth** | TA0005 | hiding or blending in so activity reads as normal |
| 8 | **Defense Impairment** | TA0112 | breaking security mechanisms, pipelines and tooling so defenders cannot see or trust what is happening |
| 9 | Credential Access | TA0006 | stealing account names, passwords, hashes or tokens |
| 10 | Discovery | TA0007 | learning the environment **from inside it** |
| 11 | Lateral Movement | TA0008 | moving to other systems in the environment |
| 12 | Collection | TA0009 | gathering the data they came for |
| 13 | Command and Control | TA0011 | communicating with compromised systems to control them |
| 14 | Exfiltration | TA0010 | moving data out |
| 15 | Impact | TA0040 | manipulating, interrupting or destroying systems and data |

**Stealth (TA0005) was named Defense Evasion.** Defense Impairment (TA0112) is a newer tactic
carved out of it. Most published reporting predates the split and will say "Defense Evasion"
for both — that is a fact about the source's age, not a reason to write the old name.
**Neither "Defense Evasion" nor "Defence Evasion" is a valid Enterprise tactic.**

## Mobile — 12 tactics

| # | Tactic | ID |
|---|---|---|
| 1 | Initial Access | TA0027 |
| 2 | Execution | TA0041 |
| 3 | Persistence | TA0028 |
| 4 | Privilege Escalation | TA0029 |
| 5 | **Defense Evasion** | TA0030 |
| 6 | Credential Access | TA0031 |
| 7 | Discovery | TA0032 |
| 8 | Lateral Movement | TA0033 |
| 9 | Collection | TA0035 |
| 10 | Command and Control | TA0037 |
| 11 | Exfiltration | TA0036 |
| 12 | Impact | TA0034 |

**Mobile still uses *Defense Evasion*, and has no Stealth and no Defense Impairment.** The
Enterprise rename did not propagate. Mobile also has no Reconnaissance and no Resource
Development. Carrying an Enterprise habit across is the usual way a Mobile mapping fails.

## ICS — 12 tactics

| # | Tactic | ID | Map here when the adversary is... |
|---|---|---|---|
| 1 | Initial Access | TA0108 | getting into the ICS environment |
| 2 | Execution | TA0104 | running code, or manipulating system functions, parameters and data without authorisation |
| 3 | Persistence | TA0110 | maintaining a foothold in the ICS environment |
| 4 | Privilege Escalation | TA0111 | gaining higher permissions |
| 5 | **Evasion** | TA0103 | avoiding security defences |
| 6 | Discovery | TA0102 | locating information to assess and identify targets |
| 7 | Lateral Movement | TA0109 | moving through the ICS environment |
| 8 | Collection | TA0100 | gathering data and domain knowledge about the environment |
| 9 | Command and Control | TA0101 | communicating with compromised controllers and platforms |
| 10 | Inhibit Response Function | TA0107 | stopping safety, protection, quality-assurance and operator-intervention functions from responding to a hazard |
| 11 | Impair Process Control | TA0106 | manipulating, disabling or damaging the physical control process |
| 12 | Impact | TA0105 | manipulating, interrupting or destroying ICS systems, data and the surrounding environment |

**ICS uses *Evasion*** — one word, not "Defense Evasion" and not "Stealth". It has no
Reconnaissance, no Resource Development, no Credential Access and no Exfiltration tactic.

**The three ICS endgame tactics are distinct and routinely confused.** Inhibit Response
Function attacks the *safety and alerting* layer — the systems meant to react when something
goes wrong. Impair Process Control attacks the *process itself* — setpoints, actuators,
control logic. Impact is the *consequence* to systems and data. Blinding an operator HMI while
you drive a pump out of range is all three, in that order, and mapping it as one loses the
part that actually endangers people.

---

# Boundaries

Six places where two tactics both look right. In each, the question is **what the behaviour
accomplished**, never what the behaviour resembles.

## Stealth vs Defense Impairment (Enterprise)

*Did they hide from the defensive tooling, or attack it?*

| Behaviour | Tactic | Why |
|---|---|---|
| Renaming Plink to `systems.exe` | Stealth | The tooling still works; the adversary is trying not to look interesting to it |
| Base64-encoding a web shell to defeat signatures | Stealth | Evading a detection, not disabling one |
| Reusing valid domain credentials so activity reads as legitimate | Stealth | Blending in |
| Loading a vulnerable driver to kill EDR from kernel mode | Defense Impairment | The sensor is the target |
| Stopping the event log service, clearing logs | Defense Impairment | Destroying the defender's visibility |
| Adding an exclusion path to the AV configuration | Defense Impairment | Reconfiguring the control so it stops working |

The line is the **defensive control's capability**. If it still functions and the adversary is
sneaking past it, that is Stealth. If it has been degraded, blinded, disabled or lied to, that
is Defense Impairment.

## Discovery vs Reconnaissance

Inside the environment, after access, is **Discovery**. Outside it, before access, is
**Reconnaissance**. Scanning a target's public IP range from the internet is Reconnaissance;
running NBTscan from a compromised host is Discovery. The tool can be identical — the position
of the adversary is what decides it.

## Collection vs Exfiltration

**Collection** is gathering and staging data inside the environment; **Exfiltration** is moving
it out. Archiving a haul with 7zip and parking it in `C:\windows\temp\` is Collection, even
though the obvious purpose is exfiltration later. Map the step that happened, not the intent
behind it. If both are evidenced, both are mapped — that is a genuine two-technique sequence,
not a duplicate.

## Persistence vs Privilege Escalation

Many mechanisms deliver both, and ATT&CK lists several techniques under both tactics. Decide
by what the evidence says the subject **got** from it. A service created to survive reboot is
Persistence. A service created to run as SYSTEM when the adversary was a normal user is
Privilege Escalation. If the evidence supports both outcomes separately, map it under both;
if it supports one, mapping both inflates the path.

## Execution vs everything that runs code

Almost every technique involves code running somewhere. **Execution is for the mechanism that
got code to run**, not for the consequence. `cmd.exe` invoked through a web shell is Execution.
The web shell itself sitting on disk as a re-entry point is Persistence. The wiper that the
command launched is Impact. One incident, three tactics, and squashing them into Execution
loses the path.

## Impact vs objective

Impact is a tactic with evidence behind it, not a restatement of the analysis's `objective`
field. An `objective: destruction` subject with no evidenced destructive action gets **no
Impact phase**, and that is the honest output. `objective: unknown` is common for a
vulnerability that grants a capability without implying an intent — it produces no Impact
phase and should not be argued into one.

---

# One behaviour, several tactics

A technique can legitimately appear under more than one tactic. `T1078` Valid Accounts is
listed by ATT&CK under Initial Access, Persistence, Privilege Escalation and Stealth — all
four are real.

**Place it where *this* subject used it.** Two rules keep that from becoming duplication:

- **Repeat a technique only when the evidence separately supports each placement.** Credentials
  used to log in at the start *and* still being used weeks later to re-enter is two evidenced
  placements. Credentials used once is one, however many tactics the technique is listed under.
- **Write a different `usage` for each placement.** If you cannot say something different
  about what it accomplished the second time, you do not have a second placement — you have
  the same one written twice.
