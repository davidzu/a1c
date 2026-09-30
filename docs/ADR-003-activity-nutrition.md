# ADR-003 — Daily context: activity & nutrition (v2.x)

- Status: Accepted
- Date: 2026-09-29
- Amends: ADR-001 (which excluded food/carbs/exercise) and extends the
  pattern set by ADR-002 (context arrives by automated ingest, not forms).
- Sources: research pass 2026-09-29 — Nightscout/xDrip treatment-display
  conventions, ADA Standard CGM Report (10 core metrics + AGP), Health
  Connect ecosystem (Zepp, Cronometer, My Macros+, Lose It!).

---

## Context

Glucose alone is a symptom without a cause. A day only becomes readable when
the curve is seen next to insulin (already in A1See), food, and exercise.
Sonic's phone already holds both missing inputs:

- **Exercise**: the Amazfit Balance records workouts; the Zepp app syncs
  exercise sessions, active calories, and heart rate to **Health Connect**
  (Android's on-device health store, ~26 data types since 2025).
- **Food**: Zepp's Food Log (photo → kcal + macros) and any dedicated food
  app (Cronometer, My Macros+, Lose It!) write nutrition records to Health
  Connect.

Building a food diary or workout forms inside A1See would duplicate apps he
already uses and add friction — the one thing the vision forbids.

## Decision

1. **Health Connect is the ingest path.** A1See reads exercise sessions,
   active calories, heart rate, and nutrition records from Health Connect on
   the phone, then POSTs new records to the Rails API. No Zepp Open API (it
   is a partner OAuth product — overkill), no manual diary forms. A tiny
   manual fallback (quick-add carbs/kcal or minutes) may exist later, but the
   default path is automatic.
2. **Rails owns storage and rules; the phone is a pipe.** The Android app
   reads Health Connect and uploads; the server dedupes and is the single
   source of truth. A1See never writes to Health Connect (read-only client).
3. **Append-only + idempotent, same as glucose.** New records carry
   `client_id` — for Health Connect records it is `hc:<metadata-id>` (the
   record's own ID), for manual entries a UUID. Unique index on `client_id`;
   a repeated POST returns the existing row effect (ingest is count-only,
   like `/entries`). Deleting a workout in Zepp does not delete it from
   A1See — history is never rewritten.
4. **Metrics of record.** Exercise = **session minutes** (duration of the
   Health Connect `ExerciseSessionRecord`), with kcal, avg HR, and max HR as
   secondary context. No heart-rate-zone filtering — duration + intensity
   badge is enough at personal scale. Food = **carbs (g)** as the primary
   number (carbs are what move the curve), kcal secondary. No step counts,
   no sleep, no calories-in-vs-out ledger.
5. **New tables** (full columns in `docs/03-data-model.md`):
   - `activity_sessions` — `started_at`, `ended_at`, `minutes`,
     `calories_kcal`, `avg_hr`, `max_hr`, `source`, `client_id`.
   - `nutrition_entries` — `taken_at`, `carbs_g`, `calories_kcal`,
     `meal_type`, `source`, `client_id`.
   - `a1c_entries` — `measured_on` (date, unique), `value`. A1C becomes a
     series: every `PATCH /api/v1/settings` that sets `last_a1c` also
     upserts today's row. `settings.last_a1c` stays the "current" value.
   - Amended 2026-09-30 after the first real Health Connect sync:
     `carbs_g` and `calories_kcal` are **decimal(9,2)**, not integers —
     Zepp writes fractional values (53.4 g carbs, 150.5 kcal) and integer
     columns rejected them with 422. `minutes`, `avg_hr`, `max_hr` stay
     integers.
6. **Endpoints** (all under `/api/v1`, no auth, same error contract):
   - `POST /api/v1/activities` — single object or array → `{ingested, received}`.
   - `POST /api/v1/nutrition` — same shape.
   - `GET /api/v1/activities?hours=N` and `GET /api/v1/nutrition?hours=N`
     (default 24, max 336 — same clamps as glucose), ascending lists.
   - `GET /api/v1/days?days=N` (default 30, max 180) — the **unified day
     table**: one row per local day (bucketed in `settings.timezone`, never
     UTC) with `insulin_units` (fast/slow split), `carbs_g`, `calories_kcal`,
     `exercise_min`. Powers both the app's daily bars and the report.
7. **Log screen display** (the Nightscout pattern, kept minimal):
   - **Left gutter: three mini-bars for the current local day** — insulin
     units, carbs g, exercise minutes. Each bar is scaled to the max daily
     value of the last 14 days (min 1), so a full bar means "your biggest
     recent day". Each has its own scale; they never share an axis.
   - **Markers on the glucose curve**: doses as thin vertical ticks (fast/
     slow colors) at dose time; food as a dot at `taken_at`; exercise as a
     translucent band spanning `started_at → ended_at` (exercise has
     duration and its glucose effect lingers — it is a band, not a point).
   - Health Connect missing or permission denied → waiting state on the
     context bars only; glucose and dose logging are never blocked.
8. **Doctor report — `GET /report?days=N`** (default 14, max 90).
   Server-rendered HTML (ERB) with inline CSS and server-computed SVG
   charts. No JavaScript framework, no Hotwire — printable, opens on any
   device in the doctor's office. Contents, in ADA Standard CGM Report
   order:
   - **10 core metrics**: days of data, % time active, mean glucose,
     **GMI** (`GMI% = 3.31 + 0.02392 × mean glucose mg/dL`), glucose
     variability (CV, goal ≤36%), and the **time-in-range stacked bar**
     (TIR 70–180 mg/dL goal >70%; TAR L1 >180 <25%, L2 >250 <5%; TBR L1
     <70 <4%, L2 <54 <1%).
   - **AGP-style curve**: all days collapsed into one 24-hour median
     profile with percentile band.
   - **Per-day context table**: date, insulin fast/slow/total, carbs g,
     kcal, exercise minutes.
   - **A1C history**: `a1c_entries` plotted with the **GMI trend** running
     between lab points.
   - **Day detail**: any day's glucose curve with food/exercise/insulin
     markers (query param).
   - Display units: **mg/dL** (the unit Mexican clinicians use); the app
     keeps displaying mmol/L.
9. **No new auth.** Private URL, single user — same contract as everything
   else. `GLUCOSE_INGEST_SECRET` stays glucose-only (xDrip uploads directly);
   Health Connect data flows through the phone, which is the trusted client.
10. **Sync cadence**: Health Connect is read on app open/resume, same
    rhythm as the glucose fetch. No background workers (WorkManager) in
    this slice.

## Consequences

- ADR-001's "API-only, no views" is amended: one read-only HTML report page
  is now part of the contract. The API itself gains no views.
- Deletions in source apps (Zepp, food apps) do not propagate — A1See
  history is append-only, like glucose. Wrong entries stay; acceptable at
  personal scale.
- Health Connect availability: built into Android 14+; Android 13 needs the
  Health Connect app installed. If absent, the app degrades to
  glucose + doses only.
- The report computes aggregates per request in SQL. At personal scale
  (≈300 glucose readings/day, a handful of doses/meals/workouts) this is
  instant; no rollup tables.
- The "no food, carbs" exclusion in the v1 brief is lifted **as context
  only**: there is still no food database, no barcode scanning, no bolus
  calculator, no meal-planning. A1See shows what happened; it does not
  advise.
