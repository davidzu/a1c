# A1See Design System — Metric Colors (v2)

Status: adopted Oct 2026. Applies to the Android app and the `/report`
dashboard. Supersedes the "dark + purple-pink accent" era where `Accent`
meant glucose in one place, fast insulin in another, and selection in a
third.

## Principle: one color = one metric, everywhere

Every metric owns a permanent hue. The same color identifies the same
metric on the log screen, the glucose card, the day bars, and the doctor
report. Color is backed by units (`u`, `g`, `kcal`, `min`) and/or shapes
(▲ fast, ▼ slow, ● meal) — hue is never the only carrier.

## Metric tokens

| Token | Hex | Contrast (worst surface, SurfaceHigh) | Meaning |
|---|---|---|---|
| `Glucose` | `#22D3EE` | 9.2:1 | CGM glucose — the hero metric |
| `InsulinFast` | `#FB923C` | 7.3:1 | Fast/rapid insulin — **NovoRapid pen is orange** |
| `InsulinSlow` | `#60A5FA` | 6.5:1 | Slow/basal insulin — **Ryzodeg cap is blue** |
| `InsulinOnBoard` | `#F87171` | 6.0:1 | Rapid insulin currently acting (4 h linear decay). Red is reserved for this card; never error |
| `Food` | `#FACC15` | 10.8:1 | Food: carbs, kcal, meal markers |
| `Exercise` | `#4ADE80` | 9.5:1 | Exercise sessions, minutes |
| `Error` | `#E5646E` | 5.0:1 | Failures only — never a metric |
| `OnSurface`/`OnSurfaceDim` | `#E8E6EC`/`#9A97A3` | 13.4 / 5.8:1 | All non-metric text |

All values measured with WCAG luminance ratio against `Background
#0A0A0C`, `Surface #141418`, `SurfaceHigh #1E1E24` (values above are the
minimum across the three). All pass 4.5:1.

The purple-pink accent (`#C465D8`) survives for **interactive chrome
only**: Save button, selected chip, links. Brand, not data.

## Chart language (glucose card)

- Curve: `Glucose` cyan, 2.5dp, round caps.
- Target band 3.9–10 mmol/L: dim band behind the curve.
- Event markers, colored by metric:
  - Food: amber dots on the curve at intake time.
  - Exercise: green translucent full-height bands (duration matters).
  - Fast dose: pink ▲ marker; slow dose: violet ▼ marker.
- The chart shows glucose + events in time. Nothing else.

## Today vs standard (below the chart)

Each metric is a row: label · bar in the metric's color · value vs
standard. Standards live in settings (defaults hard-coded until the
settings screen grows):

- Calories: goal **2 000 kcal/day**.
- Exercise: goal **20 min/day**.
- Carbs: **225 g/day** — 45% of the 2 000 kcal goal (ADA macro pattern
  for an adult male at this calorie target).
- Fast/Slow insulin: no universal target — measured against the 14-day
  average.

Over/under target is carried by the marker position and the printed
number, never by recoloring the bar red. Red stays error-only (exception:
the On board card, whose red means *acting insulin* — see tokens).

## Governance

- New metric → new token in `Theme.kt` + a row here, with measured
  contrast, before it ships.
- The doctor report (`report.html.erb`) mirrors these as CSS vars
  (`--glucose`, `--insulin-fast`, `--insulin-slow`, `--food`,
  `--exercise`).
- `interface-review` runs before any UI slice is called done.
