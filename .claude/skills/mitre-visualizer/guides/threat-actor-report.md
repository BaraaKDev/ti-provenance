# Threat actor report

**Subject:** a tracked actor or intrusion set, with no specific CVE as the focus.
If the report also names the vulnerabilities the actor exploits, stop and use
`guides/campaign-report.md` instead — do not write two half-reports.

**Template:** `references/templates/threat-flow-template.html`
**Also read:** `references/flow-craft.md` for tactic ordering, phase craft, heat, accent and
the hand checks. This file only covers what is specific to an actor report.

## Sections

Two, in this order:

**The Intrusion** → **The Arsenal** → **Sources**

## The Intrusion

One `.flow`, entry to objective. Tactic order comes from `references/flow-craft.md`; icons
from `references/tactic-icons.md`.

The flow is the whole report, so it carries the argument on its own. Two things do most of
that work:

- **The written transitions.** They are what turn a stack of technique cards into a causal
  narrative. "With defenses down, they harvest credentials" is a transition; "next phase" is
  not.
- **The objective phase.** Mark the last phase `class="phase impact"` and make it clear what
  the whole intrusion was *for*. Retune the accent to that objective before writing anything
  else — see the accent table in `flow-craft.md`.

## The Arsenal

The actor's named software, as `.weapon` cards carrying the name, S-ID, one-line role and a
`.kind` label. Mark destructive tools `class="weapon destruct"`.

**Include this section only when the mapping names tooling.** An arsenal of two commodity
RATs is a finding in itself — say so rather than padding the grid.

The split between commodity and bespoke tooling is usually worth a sentence in the
standfirst. A crew that buys its access tools and writes its own wipers is telling you where
its development budget goes.

## Hero

- `.aliases` chips for the actor's other tracked names.
- `.facts` strip: attribution, active since, objective, primary targets.
- The lede should state what makes this actor *different*, not what makes it a threat actor.

## Worked example

`samples/andariel/reports/andariel-G0138-attack-flow.html` — state espionage, and the
reference for this report type. Four things it shows that a destruction crew cannot:

- **A retuned accent.** Violet rather than signal blue, because the objective is quiet
  collection. The colour is an assertion about intent.
- **An objective phase that is Collection, not Impact**, carrying the **Exfiltration icon** —
  data leaving the container — because the goal is theft rather than destruction. The struck-
  through database would have stated something false.
- **A deliberate ordering departure.** The ransomware phase sits *before* the objective,
  because its proceeds fund the collection that follows, and the transition says so. This is
  `flow-craft.md`'s "causality outranks the tables" rule used in anger.
- **Six empty tactics** named in a footer caveat rather than padded, plus a provenance note
  explaining that the mapping is *derived* and differs from MITRE's published G0138 entry.

## A routing lesson worth internalising

There is deliberately **no destruction or extortion example in this guide**, and that is not
an oversight. Both obvious candidates turned out to be campaigns:

| Candidate | Why it is not an actor report |
|---|---|
| Agrius | MITRE documents CVE-2018-13379 for its initial access → `samples/agrius/reports/agrius-fortios-campaign-flow.html` |
| Akira | Three CVEs across Cisco and SonicWall, carrying five `via_cve` tags → `samples/akira/reports/akira-G1024-attack-flow.html` |

Before starting an actor report, check whether the mapping names a CVE in Initial Access. If
it does, this is the wrong guide: writing an actor report anyway produces a page that
silently omits the one thing a defender can act on today. **Both examples above were nearly
written as actor reports** — Akira in particular reads as a pure ransomware crew until you
notice that every documented way in is a named, patchable flaw.
