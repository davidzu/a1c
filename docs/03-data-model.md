# A1See — data model

As simple as possible. Three tables.

Conventions: `id` bigint PK, `created_at`/`updated_at` datetime `null: false`.

## `doses`

One row per injection.

| Column | Type | Constraints |
|--------|------|-------------|
| `units` | integer | `null: false`; model: integer, `> 0` |
| `kind` | integer | `null: false`; `0 = fast`, `1 = slow`; model: inclusion |
| `taken_at` | datetime | optional; real injection time (offline sync) |
| `client_id` | string | optional; unique; idempotency key for offline sync |

- `created_at` is the server receive time. `taken_at` is the real injection
  moment, set by the client when a dose is logged offline and synced later.
  Day bucketing uses `coalesce(taken_at, created_at)`.
- `client_id` is a UUID generated on the phone. The API returns the existing
  dose (200) when a create comes in with an already-seen `client_id`, so
  retries never duplicate a dose.
- `kind` is an integer enum, not a string and not a table. Two kinds, frozen.
- No user/owner column: single-user app by contract.

```ruby
class Dose < ApplicationRecord
  enum :kind, %i[fast slow], validate: true
  validates :units, numericality: { only_integer: true, greater_than: 0 }
  validates :client_id, uniqueness: true, allow_nil: true
end
```

## `settings`

Exactly one row, created by seed on first boot. Holds both config screens.

| Column | Type | Constraints |
|--------|------|-------------|
| `fast_name` | string | default `"Fast"`; model: presence |
| `slow_name` | string | default `"Slow"`; model: presence |
| `weight_kg` | decimal(5,2) | optional |
| `last_a1c` | decimal(3,1) | optional; model: `> 0` if present |
| `timezone` | string | default `"America/Monterrey"`; must be a valid IANA zone |

- One row, never many: `Settings.instance` (`first_or_create!`). No `user_id`.
- Both config screens write to this same row. No versioning/history.
- `timezone` defines the day boundary for `daily_totals` (midnight in that
  zone, not UTC). Postgres handles DST via the zone name.

## Daily totals (no table)

The graph aggregates on the fly, bucketed by **local day** in the configured
timezone — never UTC:

```ruby
Dose.group(local_day_sql).order(local_day_sql).pluck(
  local_day_sql,
  "sum(units) filter (where kind = 0)",  # fast
  "sum(units) filter (where kind = 1)"   # slow
)
# local_day_sql = date((coalesce(taken_at, created_at) AT TIME ZONE 'UTC')
#                      AT TIME ZONE settings.timezone)
```

Sunday's total is every dose whose local date (in `settings.timezone`) is
Sunday — including a 21:00 injection, which in UTC would be Monday. With a few
doses a day this is instant on Postgres; no counter cache, no rollup table.

## Offline sync (Android side)

- The phone keeps an outbox (DataStore, JSON) of unsent doses:
  `{uuid, units, kind, taken_at}`.
- Save = enqueue locally first, then POST. Success removes from the outbox;
  failure leaves it queued and syncs on next app open/resume.
- `client_id` (the uuid) makes retries idempotent; `taken_at` preserves the
  real injection moment so totals land on the correct day.
- While offline, pending doses are merged into the list and daily totals on
  the client for display only; the server stays the source of truth.

## Glucose readings (v2, per docs/ADR-002-glucose.md)

`glucose_readings` — one row per CGM reading, written by xDrip+ through
`POST /api/v1/entries` (Nightscout format):

- `sgv` integer, mg/dL (Nightscout standard). The app displays mmol/L (÷18).
- `time` datetime, **unique index** — the dedupe key that makes ingest
  idempotent. Stored UTC.
- `direction` string, nullable — Nightscout trend name (Flat, FortyFiveUp…).
- `device` string, nullable — source identifier from the uploader.

Append-only like doses. No per-user scoping (single user).

## Activity sessions (v2.x, per docs/ADR-003-activity-nutrition.md)

`activity_sessions` — one row per workout, uploaded by the Android app after
reading Health Connect (source: Zepp / the Balance). Nightscout-style
exercise band on the glucose curve:

| Column | Type | Constraints |
|--------|------|-------------|
| `started_at` | datetime | `null: false`; session start (UTC) |
| `ended_at` | datetime | `null: false`; session end; model: `ended_at > started_at` |
| `minutes` | integer | computed at ingest (`ended_at - started_at`), `>= 1` |
| `calories_kcal` | decimal(9,2) | optional; active calories from Health Connect |
| `avg_hr` | integer | optional; bpm |
| `max_hr` | integer | optional; bpm |
| `source` | string | optional; e.g. `Zepp`, `HealthConnect:Amazfit Balance` |
| `client_id` | string | `null: false`; **unique**; `hc:<metadata-id>` for Health Connect records, UUID for manual adds |

## Nutrition entries (v2.x, per docs/ADR-003-activity-nutrition.md)

`nutrition_entries` — one row per logged meal/snack from Health Connect
(NutritionRecord) or a later quick-add:

| Column | Type | Constraints |
|--------|------|-------------|
| `taken_at` | datetime | `null: false`; meal time (UTC) |
| `carbs_g` | decimal(9,2) | optional; grams of carbohydrate — the primary number |
| `calories_kcal` | decimal(9,2) | optional; kcal |
| `meal_type` | string | optional; `unknown/breakfast/lunch/dinner/snack` |
| `source` | string | optional |
| `client_id` | string | `null: false`; **unique**; same scheme as activity |

- At least one of `carbs_g` / `calories_kcal` must be present.
- Display unit for food is **carbs (g)**; kcal is secondary context.

## A1C entries (v2.x, per docs/ADR-003-activity-nutrition.md)

`a1c_entries` — the lab A1C as a series, for the report's history chart:

| Column | Type | Constraints |
|--------|------|-------------|
| `measured_on` | date | `null: false`; **unique**; one value per day |
| `value` | decimal(3,1) | `null: false`; `> 0` |

- Every `PATCH /api/v1/settings` that sets `last_a1c` upserts
  `measured_on = today` (local day). `settings.last_a1c` remains the
  "current" value; the series is the history. Seed leaves it empty.

## What is deliberately absent

- No `users`, `sessions`, tokens. No auth by contract.
- No `notes`, no `device` metadata (client_id is an idempotency key, not
  telemetry).
- No deletion/audit trail. Doses are append-only in v1.
- Legacy tables inherited from the communities schema (users, sessions,
  missions, tries, groups, memberships, specialities, evidences,
  invite_codes, active_storage) were dropped by migration
  `20260926000001` — this app only ever owns `doses`, `settings`,
  `glucose_readings`, and (since v2.x) `activity_sessions`,
  `nutrition_entries`, `a1c_entries`.
