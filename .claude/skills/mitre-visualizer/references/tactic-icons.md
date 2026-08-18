# Tactic Icon Library

One icon for every tactic in MITRE ATT&CK — Enterprise, Mobile and ICS. Each depicts the
*mechanism* of the tactic, not a generic symbol: a key for credential theft, a struck-through
eye for stealth, a gauge driven off-scale for impaired process control.

> **Framework currency (verified 2026-08-14).** Three matrices, and they do **not** share a
> tactic list:
>
> | Matrix | Tactics | Note |
> |---|---|---|
> | Enterprise | **15** | TA0005 renamed *Defense Evasion* → **Stealth**; **Defense Impairment (TA0112)** added |
> | Mobile | **12** | Still uses **Defense Evasion (TA0030)** — the Stealth rename is Enterprise-only |
> | ICS | **12** | Has three tactics with no Enterprise equivalent |
>
> Verify against attack.mitre.org when a mapping looks unfamiliar. Never "correct" a tactic
> or technique name from memory — ATT&CK changes faster than any model's training data.

## Usage

Wrap each in the `.ticon` span inside `.card-top`:

```html
<span class="ticon" aria-hidden="true">
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"
       stroke-linecap="round" stroke-linejoin="round">
    <!-- paths below -->
  </svg>
</span>
```

Rules that keep the set coherent:

- **Always `stroke="currentColor"`, `fill="none"`.** The icon inherits its phase's heat
  colour from `.ticon` / `.heat .ticon` / `.impact .ticon`. Never hard-code a hex value.
- **Keep `viewBox="0 0 24 24"` and `stroke-width="1.7"`** across every icon, so weights
  match when phases sit next to each other.
- `aria-hidden="true"` on the span — the tactic name sits in text right beside it, so the
  icon is decorative to a screen reader and must not be announced twice.

### The two encodings that make this a system

These repeat across the set and carry meaning, so keep them consistent:

- **A diagonal slash means the capability is negated.** Stealth (not seen), Defense
  Impairment (alarm broken), ICS Evasion, and Inhibit Response Function (stop function
  disabled) all share it. Do not use a slash decoratively on any other icon.
- **An X *inside* an object means that object is destroyed.** Enterprise Impact strikes
  through a database; ICS Impact strikes through a plant. The container tells you *what*
  was destroyed, which is the whole difference between the two.

---

# Enterprise — 15 tactics

### Reconnaissance (TA0043)
Magnifier with crosshairs — surveying a target before touching it.
```html
<circle cx="10.4" cy="10.4" r="6.6"/><path d="M15.2 15.2l5.6 5.6"/><path d="M10.4 7.1v6.6M7.1 10.4h6.6"/>
```

### Resource Development (TA0042)
Globe with meridians — acquiring infrastructure, VPNs, domains.
```html
<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.6 2.7 2.6 15.3 0 18M12 3c-2.6 2.7-2.6 15.3 0 18"/>
```

### Initial Access (TA0001)
Shield pierced by a bolt — the perimeter being broken.
```html
<path d="M12 2.5l7.5 3.2v6c0 4.4-3.1 8.1-7.5 9.6-4.4-1.5-7.5-5.2-7.5-9.6v-6L12 2.5z"/><path d="M13.2 7.8l-2.9 4.7h3.4l-2.9 4.2"/>
```

### Execution (TA0002)
Terminal prompt — code running on the host.
```html
<rect x="2.8" y="4.2" width="18.4" height="15.6" rx="2.2"/><path d="M7 9.5l3 2.9-3 2.9M13 15.3h4.2"/>
```

### Persistence (TA0003)
Anchor — the foothold that survives reboot.
```html
<circle cx="12" cy="4.6" r="2.3"/><path d="M12 6.9v14.2M5 12v1.2a7 7 0 0 0 14 0V12"/><path d="M3.2 12h4.2M16.6 12h4.2"/>
```

### Privilege Escalation (TA0004)
Ascending staircase — climbing privilege levels.

> Revised: this previously used a shield, which collided visually with Initial Access and
> read as "defence" rather than "climb". Stairs depict the mechanism and keep the shield
> unique to Initial Access.

```html
<path d="M2.8 20.6H7.9V15.5H13V10.4H18.1V5.3H21.2"/>
```

### Stealth (TA0005)
Struck-through eye — moving without being seen.

> Renamed by MITRE from **Defense Evasion**. Older Enterprise mappings will say "Defense
> Evasion"; relabel them to Stealth but keep the technique IDs as the source gives them.
> Note this rename is Enterprise-only — Mobile still has a Defense Evasion tactic.

```html
<path d="M2.2 12S5.8 5.8 12 5.8 21.8 12 21.8 12 18.2 18.2 12 18.2 2.2 12 2.2 12z"/><circle cx="12" cy="12" r="2.6"/><path d="M4.1 20.2L19.9 3.8"/>
```

### Defense Impairment (TA0112)
Silenced bell — the alarm itself is broken.

> A newer tactic, split out of the old Defense Evasion. The distinction that matters:
> **Stealth** is avoiding the sensor, **Defense Impairment** is disabling it. EDR kills,
> log clearing and BYOVD driver abuse (`T1685`) belong here, not under Stealth.

```html
<path d="M18 8.6a6 6 0 1 0-12 0c0 6.4-2.4 8.2-2.4 8.2h16.8S18 15 18 8.6z"/><path d="M13.7 20.4a2 2 0 0 1-3.4 0"/><path d="M3.6 3.6l16.8 16.8"/>
```

### Credential Access (TA0006)
Key — stolen secrets.
```html
<circle cx="7.8" cy="12" r="4.3"/><path d="M12.1 12h9.1M17.6 12v3.9M20.4 12v2.8"/>
```

### Discovery (TA0007)
Radar sweep — mapping the internal terrain.
```html
<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4.6"/><circle cx="12" cy="12" r="1.1"/><path d="M12 12l6.4-5.3"/>
```

### Lateral Movement (TA0008)
Host to host with a directed hop.
```html
<rect x="1.8" y="7.8" width="7.4" height="8.4" rx="1.6"/><rect x="14.8" y="7.8" width="7.4" height="8.4" rx="1.6"/><path d="M9.6 12h4.8M12.4 9.6l2.4 2.4-2.4 2.4"/>
```

### Collection (TA0009)
Stacked layers — data gathered and staged.
```html
<path d="M12 2.8l9.2 4.6-9.2 4.6-9.2-4.6L12 2.8z"/><path d="M2.8 12L12 16.6 21.2 12"/><path d="M2.8 16.6L12 21.2l9.2-4.6"/>
```

### Command and Control (TA0011)
Broadcast waves — the beacon channel home.
```html
<circle cx="12" cy="12" r="2.2"/><path d="M7.9 7.9a5.8 5.8 0 0 0 0 8.2M16.1 16.1a5.8 5.8 0 0 0 0-8.2"/><path d="M5 5a9.9 9.9 0 0 0 0 14M19 19a9.9 9.9 0 0 0 0-14"/>
```

### Exfiltration (TA0010)
Data leaving the container.
```html
<path d="M4.2 14.8v4a2.2 2.2 0 0 0 2.2 2.2h11.2a2.2 2.2 0 0 0 2.2-2.2v-4"/><path d="M12 2.9v12.2M7.9 7l4.1-4.1L16.1 7"/>
```

### Impact (TA0040)
Database struck through — destruction, encryption, denial of *data*.
```html
<ellipse cx="12" cy="5.6" rx="7.8" ry="2.9"/><path d="M19.8 5.6v12.8c0 1.6-3.5 2.9-7.8 2.9s-7.8-1.3-7.8-2.9V5.6"/><path d="M8.7 10.9l6.6 6.6M15.3 10.9l-6.6 6.6"/>
```

---

# Mobile — 12 tactics

Mobile needs **no new icons**. Every Mobile tactic name already exists in the Enterprise
set, so reuse those paths directly — a reader who has seen an Enterprise flow reads a
Mobile flow without relearning anything.

The one trap: **Mobile TA0030 is still called *Defense Evasion*.** The Stealth rename did
not carry across matrices. Label the phase "Defense Evasion" for a Mobile mapping and use
the Stealth eye icon.

| Mobile tactic | TA ID | Icon to reuse |
|---|---|---|
| Initial Access | TA0027 | Initial Access |
| Execution | TA0041 | Execution |
| Persistence | TA0028 | Persistence |
| Privilege Escalation | TA0029 | Privilege Escalation |
| **Defense Evasion** | TA0030 | **Stealth** (eye) — keep the *Defense Evasion* label |
| Credential Access | TA0031 | Credential Access |
| Discovery | TA0032 | Discovery |
| Lateral Movement | TA0033 | Lateral Movement |
| Collection | TA0035 | Collection |
| Command and Control | TA0037 | Command and Control |
| Exfiltration | TA0036 | Exfiltration |
| Impact | TA0034 | Impact (database) |

---

# ICS — 12 tactics

ICS shares nine tactic names with Enterprise but adds three that have no Enterprise
equivalent, plus an Impact that means something physically different.

| ICS tactic | TA ID | Icon |
|---|---|---|
| Initial Access | TA0108 | reuse Initial Access |
| Execution | TA0104 | reuse Execution |
| Persistence | TA0110 | reuse Persistence |
| Privilege Escalation | TA0111 | reuse Privilege Escalation |
| **Evasion** | TA0103 | reuse **Stealth** (eye) — label it *Evasion* |
| Discovery | TA0102 | reuse Discovery |
| Lateral Movement | TA0109 | reuse Lateral Movement |
| Collection | TA0100 | reuse Collection |
| Command and Control | TA0101 | reuse Command and Control |
| **Inhibit Response Function** | TA0107 | **new** — below |
| **Impair Process Control** | TA0106 | **new** — below |
| **Impact** | TA0105 | **new variant** — below |

### Inhibit Response Function (TA0107)
Emergency-stop octagon, slashed — safety and protection systems prevented from reacting.

> This is the tactic that turns a cyber incident into a physical one: alarms suppressed,
> safety instrumented systems blocked, shutdown logic disabled. Distinct from Defense
> Impairment, which breaks the *security* stack; this breaks the *safety* stack.

```html
<path d="M8.3 3h7.4L21 8.3v7.4L15.7 21H8.3L3 15.7V8.3L8.3 3z"/><path d="M4.8 4.8l14.4 14.4"/>
```

### Impair Process Control (TA0106)
Gauge driven off-scale — setpoints, actuators and process values manipulated.

```html
<path d="M3.4 18a8.6 8.6 0 0 1 17.2 0"/><path d="M12 18l5.2-6.2"/><circle cx="12" cy="18" r="1.4"/>
```

### Impact — ICS variant (TA0105)
Plant struck through — loss of control, loss of safety, physical damage.

> Use this instead of the database icon for ICS flows. Enterprise Impact destroys *data*;
> ICS Impact destroys *process and equipment*, and the icon should say which. The shared
> X-inside-the-object encoding keeps the two legible as a pair.

```html
<path d="M2.8 21.2V11.6L8 14.8V11.6L13.2 14.8V5.2H20.8V21.2Z"/><path d="M15.4 9.8l3.8 3.8M19.2 9.8l-3.8 3.8"/>
```

---

## Fallback

If a mapping uses a phase that is not an ATT&CK tactic (for example a report-specific step
like "Victim Selection"), use the neutral node marker rather than inventing an icon that
competes with the set:

```html
<circle cx="12" cy="12" r="8.6"/><path d="M12 7.8v4.6M12 15.8v.1"/>
```

## Icons for CVE / exploit-chain flows

A vulnerability flow usually spans fewer tactics. Reuse the same icons — an exploit chain
still passes through Initial Access, Execution, Privilege Escalation and Impact. Do not
create a parallel icon set for CVEs; the whole point of the library is that a reader who
has seen one of these flows can read the next one without relearning the vocabulary.

## Seeing them rendered

`icon-sheet.html` in this folder renders every icon at working size with its tactic name,
matrix and encoding notes. Open that when choosing an icon — reading raw SVG path data is
not a reasonable way to pick one.
