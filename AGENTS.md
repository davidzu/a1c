# A1C — project rules

This file applies only to this repository.

Visible name: **A1C**. Application id: `com.a1c.app`.

## Vision (do not dilute)

A1C is a personal insulin tracker. Log every injection in seconds, several
times a day, and see the daily total at a glance.

Every feature is judged against that sentence. The log form is the product;
config screens exist only to feed it. Nothing may add friction between
opening the app and having a dose saved.

## Current contract

v1 is the contract. `docs/ADR-001-architecture.md` wins. The numbered build
list is `docs/spec.md`.

Locked for v1:

- Rails API owns all rules and persistence. Native Android (Kotlin, Compose)
  renders state and owns UI only.
- **No auth.** Single user. No users/sessions tables, no tokens.
- REST JSON under `/api/v1`. No WebSockets, no FCM.
- No Room on Android. Repository talks to the API.
- Data model is `doses` + one `settings` row. Nothing else.
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
