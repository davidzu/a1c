# A1See — spec v2 (numbered build list, slices 8+)

- Status: **ACCEPTED 2026-11-07.** Slice 8 not started.
- Implements: `docs/ADR-004-hub-of-record.md` (accepted 2026-11-07).
- Continuation of `docs/spec.md` (slices 1–7, delivered). Slice numbering
  continues at 8; those slices are not re-opened.
- Delivery ritual: unchanged from `PIPELINE.md` — API on Render, seed,
  a path a human can use, git tag `slice-N-<name>`. The "path" is now
  either the APK **or** a web page.

---

## North star

> A Mexican diabetic wearing a Libre, a Sibionics, or a QiTrax can create
> an account, import their history from two different brands into one
> timeline, and hand their doctor a link that expires — and can export or
> delete their data on request.

Nothing in slices 8–14 is done until it serves that sentence.

---

## Beta operating model (in force until slice 15)

Decided 2026-11-07. This narrows the work below; take it as scope, not caveat.

- **Five users, onboarded by hand.** Sonic creates each account and issues a
  pairing code. No self-serve signup, no waitlist, no marketing page.
- **No email is collected or sent.** The phone is the identity anchor; web
  access is a one-time code shown in the app. Every user gets a printed
  recovery code at pairing.
- **Persona física** is the responsable. The aviso carries a professional
  domicile. Entity review is required before open signup, not before user 1.
- **Imports may be done by Sonic.** If a user cannot produce a file, Sonic
  imports it for them. That is acceptable for five people and it avoids
  building a public upload funnel before the record is proven.
- **The web is read-only for beta users**: report links, timeline view,
  export. Upload UI arrives in slice 15.

**Beta exit criteria.** Ten consecutive days where the merged record is
correct for two users on two different brands, the report has been shown to
at least one doctor, and export/delete have both been exercised on a real
account. Only then does slice 15 open signup.

---

## Phase 0 — decisions and paperwork (not a slice, runs in parallel)

No code. These gate slice 11 and the first real user, not slice 8.

1. Accept/amend `docs/ADR-004-hub-of-record.md`; rewrite the vision block
   in `AGENTS.md` from §6.
2. Write the intended-use statement (one sentence, ADR-004 §3.7) into the
   aviso, the site footer, and a code-review checklist.
3. Draft the **aviso de privacidad** (integral + simplified) with a
   Mexican lawyer. Must name the responsable and a domicile.
4. Decide the legal entity (SAS / S. de R.L.). Needed for the aviso, for
   liability, and for CFDI when a clinic pays.
5. Define the consent mechanism: what is shown, what is stored, how a
   version is proven. Input to slice 8.
6. Write the breach-notification runbook (who, how, in what order).

**Calendar note:** buying and wearing test sensors (see `docs/spec-v2.md`
§Sensor access) has a 14-day lead time per brand. Start it in Phase 0,
not in slice 9.

---

## Slice 8 — identity and scoping (`slice-8-identity`)

The gate. Everything after this assumes a `current_user`.

1. `users` table: `email`, `created_at`, `updated_at`, plus whatever the
   chosen auth mechanism needs. No roles yet.
2. `user_id` (`null: false`, FK, indexed) on `doses`, `settings`,
   `glucose_readings`, `activity_sessions`, `nutrition_entries`,
   `a1c_entries`.
3. Replace global unique indexes with per-user ones:
   `(user_id, client_id)` on doses/activity/nutrition,
   `(user_id, time)` on glucose readings, `(user_id, measured_on)` on
   A1C. **A global `time` index would collide two users reading at the
   same minute** — this is the migration's main landmine.
4. `settings` stops being a singleton: `Settings.instance` becomes
   `user.settings`, created on demand. Day bucketing keeps using the
   *user's* timezone.
5. Per-user ingest credentials: replace the global
   `GLUCOSE_INGEST_SECRET` with a token per user (xDrip endpoint and the
   Android upload path both use it).
6. Auth — **device pairing, no email** (ADR-004 §3.4):
   - `POST /api/v1/devices/pair` with an admin-issued pairing code →
     creates/binds `users` + `devices`, returns a device token.
   - Web session: `POST /api/v1/web_sessions` with a one-time code shown
     in the app → cookie session. Codes expire in 5 minutes, single use.
   - Recovery: a printed code generated at pairing, stored hashed, usable
     once to move the account to a new phone.
   - Android shows the pairing/recovery/web-code UI; the token lives in
     DataStore next to the outbox.
7. ARCO minimum, shipped as features: `GET /api/v1/export` (JSON, with
   CSV alongside) and `DELETE /api/v1/account` (hard delete, cascading).
8. Migrate the existing instance: backfill Sonic's rows to his account;
   keep the historical data intact and verify totals before/after.
9. Tests: two users cannot see or write each other's rows; per-user
   uniqueness; export/delete round-trip; ingest rejects foreign tokens;
   a used/expired pairing code or web code is rejected; recovery moves
   the account and invalidates the old device token.

**Delivered when:** the phone logs a dose into Sonic's account, a second
test account sees an empty app, and export/delete work end to end.

**Est:** 3–5 days. Mechanical, touches everything, no new features.

---

## Slice 9 — the importer (`slice-9-import`)

The wedge. This is the feature that makes the pivot real.

1. `import_batches` table: `user_id`, `source`, `filename`, `checksum`,
   `row_count`, `imported_count`, `skipped_count`, `status`
   (`processing/complete/reverted`), `created_at`.
2. `glucose_readings.import_batch_id` (nullable; live ingest leaves it
   null).
3. Parsers, each a small object behind one interface
   `(file, user) -> rows`:
   - `LibreViewCsv` — the canonical one; column names vary by locale
     (es-MX uses `Hora`, `Glucosa`), so match on normalized headers.
   - `SibionicsExport` — official AGP export.
   - `QiTraxExport` — verify against a real file before promising it.
   - `NightscoutJson` — already a known shape; reuse `/entries` rules.
   - `GenericCsv` — user maps timestamp + value columns in the UI; the
     fallback that makes the importer work on any future brand.
4. Dedupe per user on `(user_id, time)`: first wins, but **report the
   overlap** (`skipped_count`) instead of silently dropping. A user
   importing an overlapping range must see what happened.
5. Timezone handling: vendor exports are usually local wall-clock. Parse
   in the user's `settings.timezone`, store UTC. Wrong by default if
   shrugged at.
6. Undo: a batch can be reverted (delete its rows, mark the batch
   reverted). This is the only sanctioned exception to append-only.
7. Upload surface: API first (multipart), web UI in slice 11.
8. Tests: one fixture file per vendor; overlapping import; bad mapping;
   revert; a file with DST-ambiguous timestamps.

**Delivered when:** a year of history from two different brands lands in
one continuous timeline, and one bad batch can be removed cleanly.

**Est:** 4–6 days, plus whatever the real files surprise us with.

---

## Slice 10 — per-user report with expiring links (`slice-10-report`)

The product a doctor actually wants.

1. `GET /report` scoped to `current_user`, `.es` Spanish labels, mg/dL.
2. Share links: signed, expiring (default 7 days), read-only, no login.
   Revocable. Multiple concurrent links per user.
3. The report gains an import-provenance footer ("Datos: LibreView
   2024-06 → 2025-03; Sibionics 2025-04 → …") so a doctor can see the
   record's seams.
4. Print stylesheet verified: one URL, opens on any device in the
   consult, prints on A4 without clipping.
5. Tests: expired link 404s; a link cannot read another user's data;
   report math unchanged from slice 7.

**Delivered when:** a doctor opens a link on their own phone, sees the
merged history, and prints it.

**Est:** 2–3 days.

---

## Slice 11 — the web (`slice-11-web`, narrow)

A read-only window on the record for beta users and their doctors. Not an
acquisition funnel — that is slice 15.

1. Minimal Rails views (ERB, no JS framework, inline CSS — same stance as
   the report): sign in by one-time code, timeline, day list, settings,
   export/delete.
2. Timeline view is deliberately **not** a copy of the app: the day table,
   the day bars, the imported ranges, and a link to the report. No live
   curve, no dose form.
3. Report links open without an account (slice 10).
4. Consent capture: the aviso shown before first data, versioned, with a
   timestamped record — in the app at pairing, mirrored on the web.
5. The Android app keeps working against the same API; nothing becomes
   web-only.

**Delivered when:** a beta user signs in from a borrowed iPhone, sees their
imported history, exports it as CSV, and opens the doctor link.

**Est:** 3–4 days. (The public upload UI moved to slice 15; that is what
took this from 5–7 days.)

---

## Slice 12 — live from official shares (`slice-12-live-share`)

Optional, opt-in, and explicitly reversible. Do not start before slice 11
is in real hands.

1. A per-user connection record (encrypted credentials) for one source:
   **LibreLinkUp first** — it is the volume market and the mechanism
   behind most third-party bridges.
2. Polling on a schedule (solid_queue is already in the stack). Cadence:
   the share's own refresh, not faster.
3. Provenance: rows carry `source`, so live rows and imported rows stay
   distinguishable in the record and the report footer.
4. Feature flag, per user, off by default; a clear explanation of what it
   connects to and what the vendor's terms say.
5. Graceful failure: if the share breaks (vendor change), the account
   keeps its history and says so. Never block the app.
6. Then, if the pattern holds, Sibionics share.

**Delivered when:** a Libre user's curve updates without opening the app.

**Est:** 3–5 days, and an unknown amount of maintenance forever. This is
the slice most likely to be broken by a vendor, which is why it is not
earlier.

---

## Slice 13 — client polish (`slice-13-polish`)

The work that was already on the list, now that real users exist.

1. Glucose curve rework: readable bands, better tick density, clearer
   target range, food/exercise markers that survive a small screen.
2. Daily-totals graph: fix the fast/slow bar contrast (backlog item).
3. Pull-to-refresh on the Log screen (backlog item).
4. Empty/error/waiting states reviewed against real support reports.
5. Metric cards re-checked against `docs/design-system.md` contrast.

May be pulled forward if the graph blocks daily use — see §Open questions.

**Delivered when:** Sonic prefers A1See to the vendor app for daily
viewing again.

**Est:** 3–4 days.

---

## Slice 14 — clinic view (`slice-14-clinic`)

Only after five real patients and at least one doctor asking.

1. Clinic accounts with read-only access to patients who explicitly
   invite them.
2. Multi-patient list: last reading, 14-day TIR, last report date.
3. Revocable per-patient access, expiring by default.
4. Export for the clinic.
5. Billing is out of scope until someone asks to pay.

**Delivered when:** one endocrinologist opens the list during a consult.

**Est:** 5–7 days.

---

## Slice 15 — public funnel (`slice-15-funnel`, post-beta)

Gated on the beta exit criteria above, and on two decisions that must be
revisited first: the legal entity (ADR-004 §3.8) and the no-email model
(an open signup with no contact channel is not defensible).

1. Legal entity formed; aviso updated to name it.
2. Self-serve onboarding that does not require Sonic: invite code →
   pairing, or a public signup with a recovery strategy that survives a
   lost phone.
3. Public upload page: drag a CSV/JSON, format detection, preview with row
   counts and overlap warning before commit.
4. Abuse controls: per-account quotas, rate limits, a growth ceiling.
5. A support channel that is not Sonic's personal phone.

**Delivered when:** a stranger finds the site, imports a year of history,
and shares a report without Sonic touching anything.

**Est:** 5–8 days, plus the entity paperwork.

---

## Cross-cutting (every slice)

- **Tests** stay request-level and cheap; no new gems outside the ADR
  allowlist without an ADR amendment.
- **Backups**: the moment a second user exists, a restore must have been
  rehearsed. Not a slice — a precondition.
- **Support**: a public contact channel and an answer for "my graph is
  empty" before the first non-Sonic account.
- **No new AI, no photo features, no sensor reading** until slice 13 is
  delivered.

---

## Sensor access (calendar critical path)

To build the importer we need **real export files**, and to get real
files we need to wear the sensors. This is 14 days per brand and cannot
be compressed — so it runs in parallel with Phase 0 and slice 8.

Priority:

1. **Sibionics GS1 bought in Mexico** (~$1,199–1,299 MXN, Kabla /
   `sibionics.com.mx`, COFEPRIS 0097W2026). **Yes, buy it.** Not because
   the sensor is new to you, but because the *Mexican official app's
   export flow and account system* are the thing being tested, and the
   AliExpress unit may not produce the same file. This also retires the
   Juggluco → xDrip chain as the only option.
2. **FreeStyle Libre 2 Plus** (~$1,489–1,663 MXN, Reg. San. 0995E2025).
   Worth buying even though it is the most expensive: Libre is the volume
   market, LibreView is the canonical export, and LibreLinkUp is the share
   surface slice 12 depends on.
3. **QiTrax** (~$1,329–1,370 MXN, COFEPRIS 263300201B0771). Smallest and
   newest. Try to get a sample or a single sensor from the distributor
   before buying a pack; if the export is thin, deprioritize the parser.

For each: capture the raw export file, the app version, the phone OS, and
a screenshot of the export screen. Those files become the test fixtures.

---

## Decisions (resolved 2026-11-07)

1. **Auth** — device pairing, no email. Slice 8.
2. **Entity** — persona física for the beta; reviewed before slice 15.
3. **Beta shape** — five hand-held users, manual onboarding.
4. **Polish timing** — slice 13 stays after slice 12.
5. **Web scope** — narrow: record + report only.

Carried into the specs: the beta is a *concierge* operation. Imports can be
run by Sonic; the public upload funnel is slice 15.

---

## Explicitly out of scope

Direct sensor reading, Dexcom, native iOS, Mexican hosting, photo
nutrition, bolus math, dosing advice, app-store distribution, editing or
deleting doses.
