# A1See — project rules

This file applies only to this repository.

Visible name: **A1See**. Application id and package stay `com.a1c.app`
(unchanged for compatibility — renaming them would orphan the installed app
and its offline outbox).

## Vision (do not dilute)

A1See is a personal insulin tracker. Log every injection in seconds, several
times a day, and see the daily total at a glance.

Every feature is judged against that sentence. The log form is the product;
config screens exist only to feed it. Nothing may add friction between
opening the app and having a dose saved.

## Current contract

v1 is the contract. `docs/ADR-001-architecture.md` wins. The numbered build
list is `docs/spec.md`.

**v2 started**: glucose readings follow `docs/ADR-002-glucose.md`
(`glucose_readings` table + Nightscout-format ingest via xDrip+). All other
v1 rules below still hold.

Locked for v1:

- Rails API owns all rules and persistence. Native Android (Kotlin, Compose)
  renders state and owns UI only.
- **No auth.** Single user. No users/sessions tables, no tokens.
- REST JSON under `/api/v1`. No WebSockets, no FCM.
- No Room on Android. Repository talks to the API; a small DataStore (JSON)
  outbox holds doses pending sync — that is the only local persistence.
- Data model is `doses` + one `settings` row. Nothing else.
- Day bucketing for the graph is local time in `settings.timezone`
  (default `America/Monterrey`), never UTC. Offline doses carry `taken_at`
  (real injection time) and `client_id` (idempotency UUID).
- Dark theme only: black/grey + purple-pink accent.
- Deploy the API to Render. Each finished slice is a phone-visible delivery.

## Spec source

`docs/01-product-brief.md` is the product contract. Implement against these,
in this order:

1. `docs/01-product-brief.md`
2. `docs/02-information-architecture.md`
3. `docs/03-data-model.md`
4. `docs/ADR-001-architecture.md`
5. `docs/spec.md`

Delivery process: `PIPELINE.md`. A slice is not done until the Render API
responds and the demo APK can use it.
