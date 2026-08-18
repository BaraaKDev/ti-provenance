# Threat actor report

**Subject:** a tracked actor or intrusion set, with no specific CVE as the focus.
If the report also names the vulnerabilities the actor exploits, stop and use
`guides/campaign-report.md` instead — do not write two half-reports.

**Template:** `references/templates/threat-flow-template.html`
**Also read:** `references/flow-craft.md` for tactic ordering, phase craft, heat, accent and
the hand checks. This file only covers what is specific to an actor report.

## Sections

Two, in this order:

**The Intrusion** → **The Arsenal**

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

## Worked examples

- `subjects/akira/reports/akira-G1024-attack-flow.html` — financially motivated ransomware, and
  the canonical reference for tone, density and phase copy. Also shows how a flow with **no
  exploitation phase** is handled: Akira logs in with valid credentials rather than
  exploiting anything, so there is no CVE and this is correctly an actor report.
- `subjects/andariel/reports/andariel-G0138-attack-flow.html` — state espionage. Read alongside
  Akira to see the same grammar carry a different objective, and for two cases Akira does not
  show: a **retuned accent** for a non-destructive objective, and a **sparse mapping** handled
  honestly, with an objective phase carrying no technique ID at all and a footer caveat naming
  the empty tactics.

## A routing lesson worth internalising

There is deliberately **no destruction-crew example here**. Agrius would have been the
obvious one, but MITRE documents a specific CVE for its initial access, which makes it a
**campaign** subject — see `subjects/agrius/reports/agrius-fortios-campaign-flow.html`.

Before starting an actor report, check whether the mapping names a CVE in Initial Access. If
it does, this is the wrong guide: writing an actor report anyway produces a page that
silently omits the one thing a defender can act on today.
