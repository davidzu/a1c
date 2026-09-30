# A1C — spec (numbered build list)

Implements `docs/ADR-001-architecture.md`. Slices in order; do not start N+1
until N is delivered (see `PIPELINE.md`).

## Slice 1 — foundation (API)

1. Rails 8 API-only app in `backend/`, PostgreSQL, Minitest enabled.
2. `doses` table per `docs/03-data-model.md` (`units` int > 0, `kind` enum
   fast/slow). Model validations + enum.
3. `settings` table (single row): `fast_name`, `slow_name` (defaults "Fast"/
   "Slow"), `weight_kg` decimal(5,2), `last_a1c` decimal(3,1). `Settings.instance`
   first-or-create. Seed creates it idempotently.
4. `GET /api/v1/doses` → `{ doses: [...recent], daily_totals: [...] }`.
   `daily_totals`: one row per day having doses, `date`, `total_units`,
   `fast_units`, `slow_units`, ascending by date.
5. `POST /api/v1/doses` with `units` (int) + `kind` (`fast`|`slow`) → 201 +
   dose payload; 422 with error shape on invalid input.
6. `GET /api/v1/settings` → `{ settings: {...} }` (creates the row if missing).
7. `PATCH /api/v1/settings` with any subset of the four fields → 200 + payload;
   422 on invalid.
8. Request tests for all of the above, including daily-totals math and the
   error contract.
9. `render.yaml` + `bin/render-build.sh` + `bin/render-start.sh` (copy the
   Mission Possible pattern; no disk, no seeds beyond settings).
10. Deploy to Render; verify `/up` and the endpoints on the live host.

## Slice 2 — Android shell + Log screen

1. Project `android/`, application id `com.a1c.app`, minSdk 24, target 36,
   JDK 21, Compose + Navigation + Retrofit + kotlinx.serialization, flavors
   `local` / `demo`.
2. Dark theme (black/grey + purple-pink accent) as the only theme.
3. Bottom bar: Log / Insulins / Generals.
4. Log screen: timestamp, Units integer field, Fast/Slow single choice, Save
   (disabled until valid), inline confirmation, dose list refreshes.
5. Daily totals bar graph below the form (Canvas-drawn bars; no chart library).
6. POST to the API on save; visible error if it fails; dose not marked saved.

## Slice 3 — config screens

1. Insulins screen: Fast + Slow name fields, Save → `PATCH /api/v1/settings`.
2. Generals screen: Weight + Last A1C decimal fields, Save → same endpoint.
3. Log screen labels use the configured insulin names.

## Slice 4 — polish

1. Timestamp updates on resume; sensible date formatting.
2. Empty states (no doses yet) and error states (API unreachable) designed,
   not raw text.
3. Demo flavor points at the Render host; APK installed on the phone.

## Slice 5 — glucose (v2, per docs/ADR-002-glucose.md)

1. `glucose_readings` table (`sgv` mg/dL int, `time` unique, `direction`,
   `device`) + model.
2. `POST /api/v1/entries` — Nightscout-format ingest (single or array),
   sgv/mbg only, idempotent upsert on `time`. Optional shared secret via
   `GLUCOSE_INGEST_SECRET` (`api-secret` header, raw or SHA-1 hex).
3. `GET /api/v1/glucose?hours=N` (default 24, max 336) → ascending readings.
4. Request tests: ingest shapes, dedupe, secret enforcement, glucose index.
5. Android: current glucose in the Log header (value + direction arrow +
   age), "Glucose · last 24 h" line chart card with 3.9–10 target band;
   glucose fetch failures never block dose logging.
6. xDrip+ on the phone: data source 640g/Eversense (receives SugarJoy+
   broadcasts), Nightscout REST upload pointed at the Render ingest URL.
   Delivered when glucose shows in the app from live sensor data.

## Slice 6 — daily context (v2.x, per docs/ADR-003-activity-nutrition.md)

1. Backend: `activity_sessions`, `nutrition_entries`, `a1c_entries` tables
   (unique `client_id` / `measured_on`), models with the ADR-003 validations.
2. `POST /api/v1/activities` + `POST /api/v1/nutrition` — single object or
   array, idempotent on `client_id` (retries free, first wins), same
   `{ingested, received}` response shape as `/entries`.
3. `GET /api/v1/activities?hours=N` + `GET /api/v1/nutrition?hours=N`
   (default 24, max 336) — ascending lists, same clamps as glucose.
4. `GET /api/v1/days?days=N` (default 30, max 180) — unified per-day totals
   in local time: insulin (fast/slow/total), carbs_g, calories_kcal,
   exercise_min.
5. `PATCH /api/v1/settings` with `last_a1c` also upserts `a1c_entries` for
   today (local day). Request tests for all endpoints + days math + A1C
   upsert.
6. Android: Health Connect reader (exercise sessions, active calories,
   nutrition records) — read-only, permission-gated; uploads new records
   with `client_id = hc:<metadata-id>`.
7. Log screen: three day-context mini-bars (insulin units / carbs g /
   exercise minutes, each scaled to its own 14-day max) + food dots and
   exercise bands on the glucose curve. Health Connect missing → waiting
   state on the bars only; logging stays untouched.
8. Delivered when a workout logged on the Balance and a meal logged in a
   food app show up on the phone's Log screen without manual entry.

## Slice 7 — doctor report (v2.x, per docs/ADR-003-activity-nutrition.md)

1. `GET /report?days=N` (default 14, max 90) — server-rendered ERB + inline
   CSS + server-side SVG; printable, no JS framework.
2. ADA Standard CGM metrics: days of data, % time active, mean glucose, GMI
   (`3.31 + 0.02392 × mean mg/dL`), variability (CV ≤36%), time-in-range
   stacked bar with the consensus targets (TIR >70%, TAR L1 <25% / L2 <5%,
   TBR L1 <4% / L2 <1%).
3. AGP-style 24-hour median profile with percentile band.
4. Per-day context table: insulin fast/slow/total · carbs g · kcal ·
   exercise minutes.
5. A1C history chart: `a1c_entries` + GMI trend line.
6. Day detail view: any day's glucose curve with food, exercise, and dose
   markers.
7. Delivered when the report renders from live Render data and prints
   cleanly.
