# A1See

Personal insulin tracker. Log every injection in seconds and see the daily
total at a glance. Named after the A1C metric it helps you watch.

Monorepo, same shape as Mission Possible:

```
backend/   Rails 8 API-only + PostgreSQL (no auth — single user)
android/   Kotlin + Jetpack Compose (dark theme, purple-pink accent)
docs/      product brief, IA, data model, ADR-001/002/003, spec
```

## API (v1)

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/doses` | Recent doses + `daily_totals` (per local day in `settings.timezone`) |
| POST | `/api/v1/doses` | Log a dose — `{ "units": 6, "kind": "fast", "taken_at": "...", "client_id": "uuid" }` (last two optional, for offline sync) |
| GET | `/api/v1/settings` | Insulin names, weight, last A1C, timezone |
| PATCH | `/api/v1/settings` | Update any subset of those five fields (setting `last_a1c` also appends to `a1c_entries`) |
| POST | `/api/v1/entries` | Nightscout-format glucose ingest from xDrip+ (single or array) |
| GET | `/api/v1/glucose?hours=N` | Glucose readings ascending (default 24 h, max 336) |
| POST | `/api/v1/activities` | Exercise-session ingest from Health Connect (single or array, idempotent `client_id`) |
| GET | `/api/v1/activities?hours=N` | Exercise sessions ascending (default 24 h, max 336) |
| POST | `/api/v1/nutrition` | Food-entry ingest from Health Connect (single or array, idempotent `client_id`) |
| GET | `/api/v1/nutrition?hours=N` | Food entries ascending (default 24 h, max 336) |
| GET | `/api/v1/days?days=N` | Unified per-day totals: insulin fast/slow/total · carbs g · kcal · exercise min (default 30, max 180) |
| GET | `/report?days=N` | Printable doctor dashboard — ADA CGM metrics, AGP profile, day table, A1C history (default 14, max 90) |

## Run locally

Backend (PostgreSQL must be running):

```bash
cd backend
bin/rails db:prepare
bin/rails test        # 12 request tests
bin/rails server      # http://localhost:3000/up
```

Android (emulator, local flavor → `10.0.2.2:3000`):

```bash
cd android
./gradlew :app:assembleLocalDebug
# APK: app/build/outputs/apk/local/debug/app-local-debug.apk
```

## Deploy

`render.yaml` at the repo root defines the web service + Postgres. Push to
`main` auto-deploys. Set `RAILS_MASTER_KEY` and `DATABASE_URL` in the Render
dashboard, then point the Android `demo` flavor's `BASE_URL` at the Render
host (`android/app/build.gradle.kts`).

## Rules

`AGENTS.md` is the project contract. Process: `PIPELINE.md` (slices, tags,
definition of delivered).
