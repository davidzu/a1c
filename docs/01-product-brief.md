# A1See — product brief

A1See is a personal insulin tracker. It exists so Sonic can log every insulin
injection in seconds, several times a day, and see how much insulin he uses
per day over time.

Every feature is judged against that sentence. Logging a dose must take less
than five seconds from opening the app. Config screens exist only to hold
names and two health numbers; they are not a settings system.

## Who it is for

One person. No auth, no accounts, no multi-user. The API is open by design
because it is only reachable by Sonic's phone (keep the Render URL private).

## What it does (v1)

1. **Log a dose** — open app → timestamp shown → type units (integer) → pick
   Fast or Slow → save. Done.
2. **See the day** — a bar graph of total insulin units per day, so daily
   totals are visible at a glance.
3. **Insulin names** — one-time setup of the name of the fast insulin and the
   slow insulin (e.g. "Lispro", "Glargine"). These names label the app.
4. **Generals** — current weight and last A1C, decimals, updated now and then.

## What it also does (v2 — glucose, per docs/ADR-002-glucose.md)

5. **Glucose context** — the Log screen shows the current glucose reading
   (mmol/L, with trend arrow) and a 24-hour glucose curve with the 3.9–10
   target band, so every dose can be seen against the glucose that prompted
   it. Readings come from the CGM via xDrip+ (see ADR-002); A1See never talks
   to the sensor.

## What it also does (v2.x — daily context, per docs/ADR-003-activity-nutrition.md)

6. **Day context, automatically** — exercise and food arrive from the phone
   itself: Health Connect feeds A1See the day's workouts (minutes, kcal,
   heart rate) and meals (carbs g, kcal) logged by Zepp or any food app. No
   new forms in the daily flow. The Log screen shows three small daily bars
   (insulin units · carbs g · exercise minutes) and marks food and exercise
   directly on the glucose curve.
7. **Doctor report** — a printable web page on the API host (`/report`)
   with the standard CGM metrics doctors read (time in range, GMI,
   variability), a 24-hour glucose profile, the per-day context table
   (insulin · carbs · kcal · exercise), and the A1C history over time.
   No login: the URL is private.

## What it does not do (v1; amended where noted)

- No login, no accounts, no password.
- ~~No food, carbs, glucose readings, or bolus calculators.~~ Glucose came in
  with v2 (ADR-002); food/carbs arrive as automatic context in v2.x
  (ADR-003). Still true: no food database, no barcode scanning, no bolus
  calculator, no meal planning — A1See shows context, it does not advise.
- No editing/deleting doses (v2 if ever needed).
- No charts other than the daily totals bar graph — amended by the glucose
  curve, the day-context bars, and the web report (they serve the same
  "see the day" purpose).
- No multi-day pickers: the log is "now", the graph is history.
