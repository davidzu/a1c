# ADR-004 — Hub of record (product direction)

- Status: **ACCEPTED — 2026-11-07**
- Date: 2026-11-06 (proposed) · 2026-11-07 (accepted)
- Decision record: §7 (all five open questions resolved)
- Amends: `AGENTS.md` (vision), ADR-001 §2.3 (no auth), ADR-001 §2.7
  (Render-only hosting assumptions), ADR-003 (food/context sources are no
  longer HC-only)
- Implemented by: `docs/spec-v2.md` (slices 8–15)
- Origin: 2026-11-06 product-direction discussion (public health-data hub
  for Mexican diabetics on insulin with a CGM).

---

## 1. Context

A1See works as a personal tracker for one user. It now needs a public
audience. The problem worth solving is not "another glucose app" — the
vendor apps are free, good, and live. It is this:

> People with diabetes change sensors. Every change resets the story.
> The history is exportable in principle and unusable in practice, and
> nobody merges one brand's year into the next brand's year.

No vendor will build that merge: it is structurally against their
interest. That gap is the product.

## 2. Who this is for

A person in Mexico with diabetes who uses insulin (T1, or insulin-treated
T2) and wears a CGM; who has changed — or will change — sensor brand
because of price, availability, or insurance; and who sees an
endocrinologist a few times a year.

Not: clinicians as primary users (later, as a buyer), people without a
CGM, people who want dosing advice.

## 3. Decision

### 3.1 We are a hub of record, not a hub of pipes

The value is the normalized, permanent, portable timeline and the
doctor-ready report — not live integration with every vendor. Live
integration is a bonus. The record is the moat.

**North star (the definition of done for this pivot):**

> A Mexican diabetic wearing a Libre, a Sibionics, or a QiTrax can create
> an account, import their history from two *different* brands into one
> timeline, and hand their doctor a link that expires — and can export or
> delete their data on request.

### 3.2 Ingest: three layers, official apps first

1. **Health Connect** (live, when available) — already built.
2. **File import** — vendor exports: LibreView, Sibionics AGP export,
   QiTrax export, Nightscout JSON, plus a generic column-mapping CSV
   fallback. Universal, retroactive, partnership-free, durable.
3. **Official share surfaces** — LibreLinkUp, Sibionics share. Optional,
   opt-in, behind a flag, with a ToS caveat.

**We never read the sensor radio.** No BLE, no NFC, no reverse-engineered
protocols. Two reasons:

- **Regulatory.** Reading the radio makes A1See part of the measurement
  chain — an unregistered software-as-a-medical-device. The vendor's
  COFEPRIS registration covers their app, not ours. The regulatory
  boundary is drawn at the sensor, not at the data.
- **Engineering.** Encrypted protocols, firmware drift, Android
  background limits, and a permanent arms race, against three vendors,
  maintained by one person.

### 3.3 Vendor-agnostic from day one

No table, job, or endpoint may assume a vendor. Provenance lives in
`source` and `import_batches`. Adding a fourth brand must be a parser,
not a migration.

### 3.4 Multi-tenant, authenticated

ADR-001's "no auth" contract ends. It anticipated this: *"If that ever
changes, a new ADR adds Mission Possible-style bearer auth."* This is
that ADR.

- A `users` row owns every record. Every table gains `user_id`.
- Unique constraints become per-user: `(user_id, client_id)` and
  `(user_id, time)` — a global `time` uniqueness would collide two users'
  readings at the same minute.
- `settings` stops being a singleton row; it becomes `user.settings`.
- Ingest credentials become per-user tokens (xDrip, HC uploads).
- **Identity is the paired phone.** No email is collected and no email is
  sent (decision 2026-11-07). The model:
  - An admin-issued **pairing code** binds one phone to one user and
    returns a device token. The phone is the identity anchor.
  - The **web** gets in by a short-lived, one-time code displayed in the
    phone app and typed in the browser. No password, no email link.
  - **Account recovery is a printed recovery code** generated at pairing
    and shown once. Losing the phone without it means losing the account —
    stated plainly in onboarding, because it is true.
  - Consequence: no email means **no email as a contact channel**. The
    breach-notification and ARCO channels must be defined explicitly
    (in-app notice + a published web form), not assumed. See §3.8.

### 3.5 Append-only, but import batches are undoable

Doses and readings are never rewritten. Imports are the exception: a
mis-mapped CSV must not poison history forever. Every imported row
carries an `import_batch_id`, and a batch can be reverted. That is the one
sanctioned exception to append-only, and it is scoped to imports.

### 3.6 Hosting: Render stays (US)

Staying on Render in Oregon. There is no Mexican data-localization
requirement, so this is legal with disclosure. Revisit only if a paying
clinic requires Mexican hosting — the app stays container-portable so the
move is a redeploy, not a rewrite.

### 3.7 Regulatory posture: personal health record, not a medical device

Intended use, in one sentence, to be repeated in the aviso, the site, and
the code review checklist:

> A1See stores and displays the glucose and insulin history a person
> already generated with their own devices, and produces a summary for
> their doctor. It does not diagnose, treat, or recommend therapy.

Consequences, all binding:

- No dose suggestions, no bolus calculator, no "you should" copy.
- No auto-generated clinical conclusions in the report; metrics and
  reference ranges only.
- Every AI feature (see backlog) is opt-in, disclosed, and descriptive.

### 3.8 Privacy and legal obligations are part of the contract

- New LFPDPPP (DOF 20-03-2025, in force 21-03-2025; authority: SABG).
  Health data is **sensitive personal data**: express consent, provable
  and versioned.
- Aviso de privacidad (integral + simplified) published **before**
  collection; consent recorded with version + timestamp.
- ARCO channels, export, and hard delete shipped as features, not emails.
- Breach-notification procedure written down before the first real user.
- Processors (Render, and any AI provider) under equivalent terms; any
  cross-border transfer disclosed.
- The responsable for the beta is **Sonic as a persona física** (decision
  2026-11-07). The aviso must therefore name a person and a domicile —
  use a fiscal/professional address, not a home address. A persona física
  can still invoice (CFDI) for a clinic later; what is deferred is the
  liability shield, so revisit the entity **before open signup**, not
  before the first five users.
- **Channels are defined, not assumed.** With no email collected, the
  breach-notification path is: (a) an in-app / web notice at next visit,
  (b) a published contact form, (c) the aviso's stated procedure. Write
  this down in Phase 0 — an obligation you cannot execute is a violation
  waiting to happen.

### 3.9 Data portability is a feature

If we ask people to trust us with the record they can't get anywhere
else, export must be one click and lossless (JSON + CSV). This is both
an ARCO obligation and the trust argument that differentiates us from
the vendor apps.

## 4. Consequences

- Every controller, model and test is touched by the scoping change. It
  is cheapest now, at seven endpoints, and becomes a rewrite later.
- The reference setup (Juggluco → xDrip) is no longer required: Sibionics
  is officially distributed in Mexico (COFEPRIS 0097W2026) with an AGP
  export. The DIY chain becomes a fallback for imported sensors.
- Web becomes a first-class surface, not just `/report`. This further
  amends ADR-001's "API-only".
- Support becomes a real obligation: an insulin user with a blank graph
  at 2 a.m. is a different category of bug report.
- The Android app is no longer the only client, so UI work has to be
  duplicated or deprioritized consciously.

## 5. Out of scope (do not "just add")

- Direct sensor reading (BLE/NFC), of any brand.
- Dexcom support (no Mexican registration; not a market).
- Native iOS app. Web covers iPhone.
- Mexican hosting (revisit only for a paying clinic).
- Photo nutrition, any AI estimating (see `docs/backlog/photo-nutrition.md`).
- Bolus calculation, dosing advice, diagnosis, alerts that tell a user
  what to do.
- App-store distribution on either platform.
- Deleting or editing doses. Imports are the only undoable batch.

## 6. Proposed replacement for the `AGENTS.md` vision

On acceptance, the "Vision (do not dilute)" section becomes:

> A1See is the permanent record of a diabetic's glucose life. Log insulin
> in seconds, keep every CGM brand's history in one timeline, and hand
> your doctor a report that makes sense in a five-minute consult.
>
> Every feature is judged against that sentence. The log form and the
> report are the product; config screens exist only to feed them. The
> record must survive a sensor change, a phone change, and a vendor
> change. Nothing may add friction to logging a dose or importing a
> month of history.

The rest of `AGENTS.md` (data model constraints, local-day bucketing,
dark theme, delivery process) stays.

---

## 7. Decision record (2026-11-07)

| # | Question | Decision | Structural consequence |
|---|---|---|---|
| 1 | Auth mechanism | **Device pairing, no email** | The phone is the identity anchor; web access via a one-time code shown in the app; recovery via a printed code. No email anywhere (§3.4) |
| 2 | Legal entity | **Beta as a persona física** | Aviso names Sonic + a professional domicile; liability is personal; entity revisited before open signup (§3.8) |
| 3 | Beta shape | **Five hand-held users** | No self-serve signup; onboarding is manual; the public funnel is deferred to slice 15 |
| 4 | Polish timing | **After** the live-share slice | Slice 13 stays at position 13; no reordering |
| 5 | Web scope | **Narrow** — record + report only | The web does not mirror the app's daily UI; upload in beta may be admin-assisted (slice 11, slice 15) |

**What these decisions add up to:** a *concierge beta*. Five people, onboarded
by hand, whose exports Sonic may import for them. That is deliberate — it
validates the record and the report before any public funnel exists, and it
keeps the no-email constraint from becoming an unusable web app.

The three decisions that carry risk are recorded with their mitigations:

- No email → no obvious breach-notification channel. Mitigation: §3.8.
- Persona física → personal liability and a published domicile. Mitigation:
  professional address; entity before open signup.
- Device pairing → lost phone means lost account. Mitigation: recovery code,
  stated plainly at pairing.
