# A1See — information architecture

Three screens. The app opens on the main screen, always.

```
A1See
├── Log (main, app opens here)
│     timestamp · Units field · Fast/Slow choice · Save
│     + current glucose (header) · 24 h glucose curve
│     + day-context bars (insulin · carbs · exercise)   <- v2.x, ADR-003
│     + food/exercise markers on the glucose curve      <- v2.x, ADR-003
│     + daily totals bar graph below the log form
├── Insulins (config)
│     Fast name field · Slow name field · Save
└── Generals (config)
      Weight field · Last A1C field · Save
```

Outside the app: `GET /report` on the API host renders the printable doctor
dashboard (v2.x, ADR-003) — no app screen, opens in any browser.

## Navigation

- Bottom bar with three destinations: **Log**, **Insulins**, **Generals**.
- No back stack subtleties: three top-level destinations, `saveState`/`restoreState`.
- After saving a dose, stay on Log with the field cleared and a brief
  confirmation so several doses can be logged in a row fast.

## Screen details

### Log (main)

- Large timestamp of "now" (updates when the screen resumes).
- `Units:` integer-only numeric field.
- One choice, exactly one of: **Fast** / **Slow** (radio-style, default none).
- Save button — disabled until units ≥ 1 and a type is chosen.
- Below: bar graph, one bar per day, height = sum of units that day
  (fast + slow combined; a future version may split by type).
- Last A1C and weight from Generals shown small at the top for context.
- (v2) Current glucose line above the form; 24 h glucose curve card with
  the 3.9–10 mmol/L target band.
- (v2.x, ADR-003) Left of the glucose curve: three mini day-bars —
  **insulin units · carbs g · exercise minutes** for the current local
  day, each scaled to its own 14-day max. On the curve: dose ticks, food
  dots (at meal time), translucent exercise bands (start → end).

### Insulins (config)

- Two text fields: **Fast** and **Slow**. Save button.
- Labels on the Log screen use these names once saved.

### Generals (config)

- Two decimal fields: **Weight (kg)** and **Last A1C**. Save button.
