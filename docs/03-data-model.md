# A1C — data model

As simple as possible. Three tables.

Conventions: `id` bigint PK, `created_at`/`updated_at` datetime `null: false`.

## `doses`

One row per injection.

| Column | Type | Constraints |
|--------|------|-------------|
| `units` | integer | `null: false`; model: integer, `> 0` |
| `kind` | integer | `null: false`; `0 = fast`, `1 = slow`; model: inclusion |

- No `injected_at` column: `created_at` **is** the injection time (the app logs
  at injection time; no back-dating in v1).
- `kind` is an integer enum, not a string and not a table. Two kinds, frozen.
- No user/owner column: single-user app by contract.

```ruby
class Dose < ApplicationRecord
  enum :kind, %i[fast slow], validate: true
  validates :units, numericality: { only_integer: true, greater_than: 0 }
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

- One row, never many: `Settings.instance` (`first_or_create!`). No `user_id`.
- Both config screens write to this same row. No versioning/history.

## Daily totals (no table)

The graph aggregates on the fly:

```ruby
Dose.group("date(created_at)").order("date(created_at)").sum(:units)
```

Sunday's total is `SUM(units) WHERE created_at::date = today`. With a few
doses a day this is instant on Postgres; no counter cache, no rollup table.
Index on `created_at` only.

## What is deliberately absent

- No `users`, `sessions`, tokens. No auth by contract.
- No `injected_at`, no `notes`, no `device`/`client` metadata.
- No deletion/audit trail. Doses are append-only in v1.
