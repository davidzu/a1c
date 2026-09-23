# A1C

Personal insulin tracker. Log every injection in seconds and see the daily
total at a glance.

Monorepo, same shape as Mission Possible:

```
backend/   Rails 8 API-only + PostgreSQL (no auth — single user)
android/   Kotlin + Jetpack Compose (dark theme, purple-pink accent)
docs/      product brief, IA, data model, ADR-001, spec
```

## API (v1)

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/doses` | Recent doses + `daily_totals` (sum of units per day) |
| POST | `/api/v1/doses` | Log a dose — `{ "units": 6, "kind": "fast" }` |
| GET | `/api/v1/settings` | Insulin names, weight, last A1C |
| PATCH | `/api/v1/settings` | Update any subset of those four fields |

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
