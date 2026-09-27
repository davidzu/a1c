# ADR-001 — Architecture

- Status: Accepted
- Date: 2026-09-23
- Deciders: founder
- Sources: `docs/01-product-brief.md`, `docs/02-information-architecture.md`, `docs/03-data-model.md`
- Reference app: Mission Possible (`~/Work/communities`) — same shape, smaller.

This ADR is the non-negotiable technical contract for v1. The data model, gem
list, library list, and hosting may not change without a new ADR.

---

## 1. Context

A1See is a personal insulin tracker: log a dose in seconds, see daily totals.
One user, no auth, three screens. The app must open fast and make logging
fast. The architecture mirrors Mission Possible because that stack is already
proven on this machine and on Render.

---

## 2. Decision

### 2.1 Shape of the repo

**Monorepo**

```text
A1C/
  backend/     Rails 8 API-only
  android/     Kotlin, Jetpack Compose, single activity
  docs/
  PIPELINE.md
  AGENTS.md
  render.yaml
```

One git history. Do not split into two remotes in v1.

### 2.2 Rails: API-only, PostgreSQL, `/api/v1`

```bash
rails new backend --api --database=postgresql --skip-test --skip-system-test
```

Minitest enabled (`rails/test_unit`). Request tests live in `backend/test/`.
No Hotwire, no views, no auth, no Active Storage, no Solid gems needed for
v1 behavior but default Rails 8 gems stay as generated (solid_* included,
harmless).

### 2.3 No auth (locked)

The API is open. Single user. No `users`/`sessions` tables, no tokens, no
bcrypt. This is acceptable because the app is personal and the Render URL is
not shared. If that ever changes, a new ADR adds Mission Possible-style
bearer auth.

### 2.4 JSON contract

Same shapes as Mission Possible:

```json
{ "dose": { "id": 1, "kind": "fast", "units": 6, "created_at": "2026-09-23T13:45:00Z" } }
```

```json
{ "daily_totals": [ { "date": "2026-09-22", "total_units": 31, "fast_units": 12, "slow_units": 5 } ] }
```

```json
{ "error": { "code": "validation_failed", "message": "Units must be greater than 0", "field": "units" } }
```

- `kind` is serialized as the string `"fast"` | `"slow"` (never 0/1 over the wire).
- Timestamps ISO-8601 UTC. Dates as `YYYY-MM-DD`. Snake_case keys.
- HTTP: `200` ok, `201` create, `204` no content, `404` missing, `422` validation.

### 2.5 Endpoints (all, v1)

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/doses` | Recent doses + `daily_totals` for the graph |
| POST | `/api/v1/doses` | Log a dose (`units`, `kind`) |
| GET | `/api/v1/settings` | The settings row (insulin names, weight, a1c) |
| PATCH | `/api/v1/settings` | Update any subset of the four fields |

`GET /up` health check stays. That is the whole API.

### 2.6 Android

- Application id: `com.a1c.app`, minSdk 24, compile/target 36, JDK 21 —
  aligned with Mission Possible.
- Single `MainActivity`, Jetpack Compose, Material 3, Navigation Compose with a
  bottom bar (Log / Insulins / Generals).
- One ViewModel per screen, `StateFlow<UiState>`.
- Repository over Retrofit + OkHttp + kotlinx.serialization. No Room, no Hilt.
  Manual composition in an `AppContainer`.
- **Fast open:** no splash screen library, no auth gate, cold start goes
  straight to Log; log form renders from local state and does not wait on the
  network. Settings load async and fill labels when they arrive.
- Product flavors:

  | Flavor | `BASE_URL` |
  |---|---|
  | `local` | emulator `http://10.0.2.2:3000/api/v1/` |
  | `demo` | Render HTTPS origin |

- Dark theme only: black/grey surfaces, purple-pink accent. Hard-coded dark
  `darkColorScheme` (this app has no light mode by design).

### 2.7 Hosting and delivery

- Render Blueprint `render.yaml` at repo root: one web service + one
  Postgres (smallest plans). No persistent disk (no uploads in this app).
- `main` auto-deploys. `bin/rails db:prepare` on boot; seed creates the
  settings row (idempotent).
- Android `demo` flavor built locally and installed by hand. Not Play Store.

### 2.8 Tests

Minitest request tests per endpoint (validation, persistence, payload shape,
daily totals math). Android: none in v1 beyond build success; ViewModel tests
are a later nicety, not a gate.

### 2.9 Gem / library allowlist (v1)

**Rails (no others):** `rails`, `pg`, `puma`, `json` (`~> 2.10`), `bootsnap`,
`thruster`, `tzinfo-data`, `solid_*` (Rails 8 defaults), `debug` (dev/test).
**Android:** Compose BOM, Navigation, ViewModel, Retrofit, OkHttp,
kotlinx.serialization, DataStore (theme/base-url only). No Coil (no images),
no Room, no Hilt, no camera.

---

## 3. Consequences

- No auth means the API is world-writable if the URL leaks. Accepted: it is a
  personal tracker; worst case is junk data rows.
- No offline mode in v1: no dose is logged unless the POST succeeds. The app
  fails visibly if the API is unreachable. (Offline queue is a v2 idea.)
- The daily graph aggregates on the fly; at personal scale this is instant.
- One settings row keeps both config screens trivial.

---

## 4. Out of scope (do not "just add")

Auth, multi-user, editing/deleting doses, offline queue, glucose/carb
tracking, charts beyond the daily bar graph, iOS, widgets, notifications,
S3/Active Storage, JWT, Devise, Room, Hilt, Ktor, GraphQL.
