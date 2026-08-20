# Campaign report — an actor exploiting vulnerabilities

**Subject:** both halves are named — a tracked actor *and* the CVEs they use to get in.
If only one half is the subject, use `guides/threat-actor-report.md` or
`guides/vulnerability-report.md` instead.

**Template:** `references/templates/threat-vuln-flow-template.html`
**Also read:** `references/flow-craft.md` for tactic ordering, phase craft, heat, accent and
the hand checks. This file only covers what is specific to a campaign report.

## Sections

Four, in this order:

**Vulnerabilities** → **The Intrusion** → **The Arsenal** → **Remediation** → **Sources**

Use the **singular** heading *Vulnerability* when there is only one CVE.

---

# The point is the boundary, not the sum

A campaign report is not a CVE summary stapled to an actor profile. What a defender needs is
the line where the vulnerability's contribution ends and the actor's own tradecraft begins,
because that line answers **what does patching actually buy me**.

Two components carry it:

- **`.viacve`** goes on every technique the CVE enables — and on **none** after that. Where
  the chips stop is the boundary.
- **`.transition.handoff`** sits exactly where they stop and says so in words. **Exactly one
  per report.** It names what the vulnerability delivered and states that everything below
  would follow from any other foothold.

The handoff **replaces** the ordinary transition at that point — it does not sit alongside
one. Every gap between two phases holds exactly one transition, so an extra one breaks the
phases-minus-one parity `Verify-Flow.ps1` checks.

Reinforce the same point in the section 1 `.callout`, split into **what patching buys you**
and **what it does not**: a patched estate is protected against *this doorway*, not against
*this actor*.

## Watch for multiple entry routes

If the actor has more than one documented way in, say so plainly. A report that shows one
CVE and stops implies patching it closes the actor out, which is usually false. Agrius is the
worked case — MITRE names CVE-2018-13379 *and* SQL injection, and presents both as examples
rather than an exhaustive list.

---

# The Intrusion

**One flow.** A campaign is one attack path. If the actor uses several CVEs as alternative
entry points, those are alternatives inside the entry phase, not separate flows. Genuinely
different campaigns are separate reports.

The ratio is often the argument: one phase of vulnerability against ten of tradecraft tells
the reader how much of the campaign patching actually addresses. Let that ratio show rather
than describing it.

# Vulnerabilities (section 1)

Deliberately **lighter** than a standalone vulnerability report — the actor is the subject
and the CVEs are the doorway. Carry the table, plus the optional `.chain` block only if the
CVEs genuinely compose, then move on. The full chain-versus-set treatment lives in
`guides/vulnerability-report.md` and does not need repeating.

# The Arsenal (section 3)

The actor's named software, same as a threat-actor report: `.weapon` cards with name, S-ID,
role and `.kind`. Mark destructive tools `class="weapon destruct"`.

# Remediation (section 4)

Concrete versions, and one campaign-specific addition: **a hunt card**. Patching closes the
door but does not remove anyone already through it, so give the reader artefacts to search
for. Where the CVE discloses credentials rather than granting execution, add a **rotate
credentials** card too — patching stops future theft but does nothing about what already
leaked.

---

# Two things to keep honest

**Retune the accent to the actor's objective, not the CVE severity.** A critical CVE used by
a quiet espionage actor should not terminate in the same urgent blue. See the accent table in
`references/flow-craft.md`.

**State attribution confidence in the footer.** Whether the actor is confirmed to have
exploited these CVEs, or whether the link is inferred from tooling and timing. A campaign
report should never imply firmer attribution than the reporting supports. Note also whether
other actors exploit the same CVEs — patching is driven by the vulnerability, not by who is
on the page.

## Worked example

`samples/agrius/reports/agrius-fortios-campaign-flow.html` — Agrius (G1030) entering through
CVE-2018-13379 in FortiOS. Shows the `.viacve` chip appearing once and stopping, the
`.transition.handoff` marking that boundary, a section 1 callout split into what patching
buys and what it does not, and a Remediation section carrying patch, credential-rotation and
hunt cards because the flaw leaks credentials rather than granting execution.
