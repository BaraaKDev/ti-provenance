# Design alternatives — rationale

Two specimens, one system. Both files share the **same token set** and the **same markup
skeleton** (the only structural difference is that B wraps technique-usage text in a `<span>`
to feed its two-column grid). Only the `<style>` block changes between them, which is the
point: pick a direction, and the other's markup already works.

Both carry the full Andariel bulletin in one page — analysis half (assessment, chronology,
takeaways, sector risk) and flow half (tactic phases, arsenal) — as the merged product would.

## The inventory: 13 classes (vs 43 in the campaign template alone)

`wrap · eyebrow · lede · meta · prose · callout · seq · mark · tag · ref · cards · risk · level`

Plus two data-attributes carrying semantics, not style variants:
- `data-level="critical|high|moderate|low|minimal"` — the five sector-risk levels
- `data-apex` — the one emphasised item per sequence

Everything else is element selectors (`h1`–`h3`, `header/section/footer`, `dl/dt/dd`,
`table`, `footer ol`, `small`) and CSS counters.

## The consolidations

| One component | Replaces |
|---|---|
| `.seq` + `.mark` | `.chrono/.entry/.when` AND `.flow/.phase/.node` — chronology and tactic phases are the same rail: marker label (date or phase number), heading, body. The flow variant just adds a tactic `.eyebrow` and technique rows. |
| `.cards` | `.takeaway`, `.weapon` (arsenal), remediation cards. `ol.cards` = numbered takeaways, `ul.cards` = arsenal. One family, two list types. |
| `.meta` | `.facts` AND `.covermeta` — the hero key-value strip, now also absorbing the alias chip row as a plain row. |
| `.ref` | `.tid` (technique IDs), `.src` (source markers), `.sid` (software IDs) — all machine-readable reference metadata, one teal mono device. |
| `.tag` | `.chip` (aliases) and `.tool` (tooling) — named things, one neutral mono device. |
| `.eyebrow` | `.section-head` kicker, `.tactic` label, footer heading — one small-caps label reused at three scales. |

## What was dropped, and why

- **Tactic icons (`.ticon` + icon library)** — 34px colored chips per phase were the single
  loudest device. The tactic name in small caps says the same thing.
- **Heat escalation (`.heat`, gradient spine, color-mix ramps)** — three intermediate color
  states an executive cannot decode without the legend. Replaced by one `data-apex` marker:
  the single violet node where the objective is realised (1.2 TB in the chronology,
  Collection in the flow). One meaning, one mark.
- **Both legends (`.legend`, `.risklegend`)** — a design that needs a legend on every page is
  over-encoded. Risk levels are now worded; the apex mark is explained by its own heading.
- **Cover motif (`.covermotif/.arcs/.rail/.dots`)** — decoration carrying no meaning.
- **Transition connectors (`.transition`)** — the "why this leads on" sentence folds into the
  next phase's body when it earns its keep.
- **TLP color variants (`.tlp.clear/green/amber/red`)** — TLP:CLEAR is text in the masthead
  eyebrow. (If TLP:AMBER/RED products appear, the marking can be set in the risk family —
  a one-line addition, not a component.)
- **Segmented 5-bar meter + level pill (two devices per row)** — one `.level` device per row.
- **Shadows, alternating `section.alt` backgrounds, radial hero gradients** — chrome.
- **`.idtag`, `.standfirst`, `.note`, `.fact`, `.sector`, `.sources`** — absorbed into
  `.eyebrow b`, `.lede`, `small`, `.meta`, `.risk` rows, `footer ol`.

## Color discipline (identical in both)

- **Violet (accent)** = the analytic thread: the subject's objective. Title keyline /
  section numerals, key-judgment rule, takeaway numerals, and the one apex item per sequence.
- **Teal (meta)** = reference metadata: technique IDs, source markers, sequence marks.
- **Risk ramp** = sector risk only. Worded label, never a number — Direction A adds a dot,
  Direction B a fixed-length proportional bar. CVSS, wherever it appears, stays a bordered
  *numeric* badge, so the two claims cannot be read as interchangeable.
- Retuning per objective is two token pairs plus one neutral set (values are commented in
  each `:root`): espionage = violet/teal on cool neutrals; destruction = ember/steel on warm.

## Direction A — "Editorial"

Georgia serif, white paper, one 720px column. Chrome is nearly zero: a 3px accent keyline
over the title, hairline rules, a hanging-numeral takeaway list, a rule-topped arsenal grid
instead of boxes. The sequence is a 1px rail with dates hung in the left margin. Technique
rows drop to small sans — visibly the footnote layer, skimmable past. Reads as a printed
briefing paper; hierarchy is entirely type and space. Choose this if the product should feel
authored — an analyst's signed judgment.

## Direction B — "Structured"

System sans on a cool ground, 840px. Keeps light structure: numbered sections
(standards-document style, via CSS counters), eyebrow rules, bordered white panels for
cards/callout/risk, chip-style marks and technique IDs in a fixed ID column. No shadows, no
gradients, no icons — grouping is done by one hairline border device used consistently.
Choose this if the product should feel institutional — a document series with a spec.

## Constraints honoured

Fragment shape (`<title>` → `<style>` → content, no doctype/html/head/body); light-only with
`color-scheme: light` pinned; all colors from a single `:root` token block; nothing
load-bearing on `html/body` (every top-level block paints its own background); no external
assets, no JS, no images; print rules keep sequence items, cards, table rows and the callout
unbroken across US Letter pages and avoid heading orphans.
