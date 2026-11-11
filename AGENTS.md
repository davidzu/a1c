# A1See — project rules

This file applies only to this repository.

Visible name: **A1See**. Application id and package stay `com.a1c.app`
(unchanged for compatibility — renaming them would orphan the installed app
and its offline outbox).

## Vision (do not dilute)

A1See is the permanent record of a diabetic's glucose life. Log insulin in
seconds, keep every CGM brand's history in one timeline, and hand your doctor
a report that makes sense in a five-minute consult.

Every feature is judged against that sentence. The log form and the report are
the product; config screens exist only to feed them. Nothing may add friction
to logging a dose or importing a month of history. The record must survive a
sensor change, a phone change, and a vendor change. Context (glucose, food,
exercise) arrives by ingest, never by a form.

## Current contract

`docs/ADR-004-hub-of-record.md` wins for direction (hub of record, multi-tenant,
official-app ingest). `docs/ADR-001-architecture.md` still governs the stack
where ADR-004 does not override it. The numbered build list is
`docs/spec-v2.md`; `docs/spec.md` (slices 1–7) is delivered history.

Superseded by ADR-004: **no auth / single user** — the app is multi-tenant with
device pairing. **Hosting** stays on Render (US); the cross-border transfer is
disclosed in the aviso, and the app stays container-portable in case a paying
clinic ever requires Mexican hosting.

Still locked:

- Rails API owns all rules and persistence. Android (Kotlin, Compose) and the
  web (server-rendered ERB) render state and own UI only.
- **Every row is owned by a `user_id`.** No unscoped table, no unscoped query.
  Uniqueness is per user: `(user_id, client_id)`, `(user_id, time)`.
- REST JSON under `/api/v1`. No WebSockets, no FCM.
- No Room on Android. Repository talks to the API; a small DataStore (JSON)
  outbox holds doses pending sync — that is the only local persistence.
- Data model: `doses`, `settings` (per user), `glucose_readings`,
  `activity_sessions`, `nutrition_entries`, `a1c_entries`, `import_batches`.
- Day bucketing for the graph is local time in the **user's** `settings.timezone`
  (default `America/Monterrey`), never UTC. Offline doses carry `taken_at`
  (real injection time) and `client_id` (idempotency UUID).
- Dark theme only: black/grey + purple-pink accent.
- Deploy the API to Render. Each finished slice is a delivery a human can use
  — the APK **or** a web page.
- **Never read a sensor radio** (BLE/NFC). Ingest vendor exports, official
  shares, and Health Connect. The regulatory boundary is at the sensor.
- **Never advise.** No dose suggestions, no bolus math, no diagnosis. A1See
  records and reports. See ADR-004 §3.7 for the intended-use sentence.

## Spec source

Implement against these, in this order:

1. `docs/ADR-004-hub-of-record.md` — product direction, auth, ingest rules
2. `docs/01-product-brief.md` (v1 voice; the record framing widens it)
3. `docs/03-data-model.md` (plus ADR-002/003 additions and `user_id` scoping)
4. `docs/ADR-001-architecture.md` (stack, except where ADR-004 overrides)
5. `docs/spec-v2.md` — slices 8+
6. `docs/ADR-002-glucose.md`, `docs/ADR-003-activity-nutrition.md`

Delivery process: `PIPELINE.md`. A slice is not done until the Render API
responds and the APK or the web can use it.

## UI/UX pipeline

Agent skills are installed globally (`~/.agents/skills/`) and load on demand:

- When building or refining Compose UI: rely on `ui-visual-composition` and
  `better-ui` (hierarchy, spacing, hit areas, visual states).
- Forms and data-entry flows (the log form is the product): consult
  `forms-inputs-checkout` before touching the dose form.
- Copy, labels, empty states, errors: `ux-writing-content-design`.
- Accessibility gate: `better-accessibility` + `accessibility-inclusive-design`
  (touch targets, contrast on the dark theme, focus order).
- Before calling a UI slice done: run `@interface-review` for a full audit
  (UI, typography, layout, color, writing, accessibility).
- Use `@break` to stress-test a component in every state, and `@variant` to
  iterate on alternatives when a screen feels off.
