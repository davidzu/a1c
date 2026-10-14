# A1See

Personal insulin tracker. Log every injection in seconds, several times a day,
and see the daily total at a glance — with the day's glucose, carbs, and
exercise around every dose. Named after the A1C metric it helps you watch.

**Current state:** all seven planned slices are built and in daily use
(see `docs/spec.md`): dose logging with offline sync, live glucose from a CGM,
exercise/food context from Health Connect, and a printable doctor dashboard.

```
backend/   Rails 8 API-only + PostgreSQL. Owns all rules and persistence.
android/   Kotlin + Jetpack Compose. Renders state and owns UI only.
docs/      product brief, IA, data model, ADR-001/002/003, spec, design system
```

## How it works

- **Thin client, fat API.** The Rails API owns every rule (day bucketing,
  totals, ADA metrics); the Android app is stateless UI over REST JSON.
- **No auth — single user.** No users/sessions tables, no tokens. Deployed
  privately; the ingest endpoints optionally take a shared secret
  (`GLUCOSE_INGEST_SECRET`, Nightscout `api-secret` header style).
- **Offline-first logging.** Doses persist to a local outbox
  (DataStore JSON) and sync when online; `client_id` UUIDs make retries
  idempotent — the API keeps the first write and ignores duplicates.
- **Local-day bucketing.** Day totals are computed in `settings.timezone`
  (default `America/Monterrey`), never UTC — a dose at 23:30 belongs to
  that day for the person who took it.
- **Bring-your-own-collector.** Glucose arrives in Nightscout format from
  any uploader (xDrip+ in the reference setup); activity and nutrition
  arrive from Health Connect with `client_id = hc:<metadata-id>`.
- **Dark theme only**, with a metric-color design system (`docs/design-system.md`):
  one color = one metric everywhere, hue never the only carrier.

## Data model

`doses` (units int, kind fast/slow, `taken_at`, `client_id`) · `settings`
(single row: insulin names, weight, last A1C, timezone) — plus, from the
v2 ADRs: `glucose_readings` (Nightscout ingest), `activity_sessions`,
`nutrition_entries`, `a1c_entries`.

## API

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/doses` | Recent doses + `daily_totals` (per local day in `settings.timezone`) |
| POST | `/api/v1/doses` | Log a dose — `{ "units": 6, "kind": "fast", "taken_at": "...", "client_id": "uuid" }` (last two optional, for offline sync) |
| GET | `/api/v1/settings` | Insulin names, weight, last A1C, computed `a1c_total` (avg of last lab A1C and 90-day GMI), timezone |
| PATCH | `/api/v1/settings` | Update any subset of those fields (setting `last_a1c` also appends to `a1c_entries`) |
| POST | `/api/v1/entries` | Nightscout-format glucose ingest (single or array), idempotent on `time` |
| GET | `/api/v1/glucose?hours=N` | Glucose readings ascending (default 24 h, max 336) |
| POST | `/api/v1/activities` | Exercise-session ingest (single or array, idempotent `client_id`) |
| GET | `/api/v1/activities?hours=N` | Exercise sessions ascending (default 24 h, max 336) |
| POST | `/api/v1/nutrition` | Food-entry ingest (single or array, idempotent `client_id`) |
| GET | `/api/v1/nutrition?hours=N` | Food entries ascending (default 24 h, max 336) |
| GET | `/api/v1/days?days=N` | Unified per-day totals: insulin fast/slow/total · carbs g · kcal · exercise min (default 30, max 180) |
| GET | `/report?days=N` | Printable doctor dashboard — ADA CGM metrics, AGP profile, day table, A1C history (default 14, max 90) |

## Run locally

Backend (PostgreSQL must be running):

```bash
cd backend
bin/rails db:prepare
bin/rails test        # request tests for every endpoint + error contract
bin/rails server      # http://localhost:3000/up
```

Android (emulator, local flavor → `10.0.2.2:3000`):

```bash
cd android
./gradlew :app:assembleLocalDebug
# APK: app/build/outputs/apk/local/debug/app-local-debug.apk
```

The Android `demo` flavor points at a deployed API — set its `BASE_URL` in
`android/app/build.gradle.kts` to wherever you host yours.

## Deploying

Host-agnostic Rails 8 + PostgreSQL app. Any host works; a `render.yaml`
blueprint is included as one example. Secrets are environment variables,
never in git: `DATABASE_URL`, `RAILS_MASTER_KEY` (Rails credentials are
committed encrypted), and optionally `GLUCOSE_INGEST_SECRET` to require the
`api-secret` header on glucose ingest.

## Docs map

1. `docs/01-product-brief.md` — the product contract
2. `docs/02-information-architecture.md`
3. `docs/03-data-model.md`
4. `docs/ADR-001-architecture.md` — the locked v1 decisions
5. `docs/ADR-002-glucose.md`, `docs/ADR-003-activity-nutrition.md` — v2/v2.x
6. `docs/spec.md` — the numbered build list (all slices delivered)
7. `docs/design-system.md` — metric colors, contrast-measured

`AGENTS.md` is the project contract; `PIPELINE.md` is the delivery process.
