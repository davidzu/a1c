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
