# A1See — slice delivery pipeline

Demo-based process. A slice is done when it can be used on the phone against
the live Render API, not only locally.

## Environments

| Name | What it is | When it updates |
|---|---|---|
| Local | Rails API + Android emulator/device against `10.0.2.2` / LAN IP | Continuous while building a slice |
| Demo | Render web service + PostgreSQL + Android **demo** flavor | When a slice is accepted as showable |

Render:

- Blueprint: `render.yaml` (one web service + one Postgres, smallest plans).
- Deploy: push to `main` auto-deploys the demo API.
- Config: `RAILS_MASTER_KEY`, `DATABASE_URL` live in the Render dashboard. Not in git.
- Android `BASE_URL` for the demo flavor is the Render hostname.

## What "delivered" means for a slice

1. **API on Render** — the slice's endpoints respond on the demo host.
2. **Seed** — the settings row exists with sane defaults.
3. **Android path** — a demo APK whose screens for this slice talk to Render.
4. **Git tag** — `slice-N-<name>` on the shown commit.

## Slice sequence

Do not skip. Do not start N+1 until N is delivered.

| Tag | Slice | What you can do afterwards |
|---|---|---|
| `slice-1-foundation` | Rails API: doses + settings, tests green, deployed to Render | `POST /api/v1/doses` from curl on the live host |
| `slice-2-log` | Android shell + Log screen (units, fast/slow, save) + graph | Log doses from the phone |
| `slice-3-config` | Insulins + Generals screens wired to settings | Set names, weight, A1C from the phone |
| `slice-4-polish` | Timestamp behavior, empty/error states, demo flavor BASE_URL | Daily-driver quality |
| `slice-5-glucose` | CGM glucose via xDrip+ → `/api/v1/entries` → Log screen | See glucose next to doses |
