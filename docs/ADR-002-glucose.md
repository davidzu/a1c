# ADR-002 — Glucose readings (v2)

Date: 2026-09-27. Status: accepted. Amends ADR-001 (which locked v1 to
doses + one settings row).

## Context

Sonic wears a SiBionics GS1 sensor, read by SugarJoy+ (`com.sugarjoy.plus`,
the modded companion app) on his phone. SugarJoy+ broadcasts readings for
other apps; xDrip+ consumes them ("640g/Eversense" data source) and can
upload to any Nightscout-compatible REST endpoint. A1See should show glucose
next to insulin doses.

## Decision

1. **xDrip+ is the ingest path.** SugarJoy+ keeps the sensor; xDrip+ listens
   and uploads. No custom bridge app.
2. **Backend accepts Nightscout-format ingest.** `POST /api/v1/entries`
   accepts a single entry or an array, reads `sgv` (mg/dL int), `date`
   (epoch ms) or `dateString`, and `direction`. Entries with `type` other
   than `sgv`/`mbg` are ignored. Idempotent: unique on `time`, upsert.
3. **Storage**: `glucose_readings` table — `sgv` int, `time` datetime
   (unique index), `direction` string, `device` string. Units stored as
   **mg/dL** (Nightscout standard); the app converts to mmol/L (÷18) for
   display, matching SugarJoy+'s units.
4. **Read**: `GET /api/v1/glucose?hours=N` (default 24, max 336) returns
   readings ascending: `{ glucose: [ { time, sgv, direction } ] }`.
5. **No auth** (single user, private URL), consistent with doses. An optional
   shared secret is supported: if `GLUCOSE_INGEST_SECRET` is set on the
   server, ingest requires an `api-secret` header (raw secret or its SHA-1
   hex, matching xDrip's behavior). Off by default.
6. **Android**: Log screen gains a current-glucose line in the header and a
   "Glucose · last 24 h" line chart card (Canvas, target band 3.9–10 mmol/L).
   Glucose fetch failures never block dose logging.

## Consequences

- Glucose history lives in Render Postgres, so the 24 h chart renders
  instantly on open without polling all day.
- If xDrip is off, the app shows a waiting state; doses keep working.
- v2 slice: `slice-5-glucose` (see spec.md). Daily context around the curve
  (exercise bands, food dots) is extended by ADR-003.
