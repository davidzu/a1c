# A1See — QA plan

- Version: 1.0 · 2026-11-11
- Scope: Rails API (`backend/`), Android app (`android/`), `/report`, the Render
  demo, and the installed app on Sonic's phone.
- Authority: this plan tests the contract in `docs/01-product-brief.md`,
  `docs/02-information-architecture.md`, `docs/03-data-model.md`,
  `docs/ADR-001/002/003`, `docs/spec.md`, and `docs/design-system.md`.
  Where code and docs disagree, the disagreement is a finding, not a test pass.

---

## 1. What "quality" means here

The product is one sentence: **log an injection in seconds, several times a
day, and see the daily total at a glance.** Quality is therefore, in priority
order:

1. **No lost or wrong dose.** A logged dose is never dropped, duplicated, or
   filed under the wrong day.
2. **No wrong number on screen.** Daily totals, glucose, carbs, exercise,
   IOB, A1C, and the report either show the truth or show nothing.
3. **Logging never blocks.** Network, glucose, and Health Connect failures may
   degrade context; they may never stop a dose from being saved.
4. **Fast.** Cold start to a saved dose in under five seconds.
5. **Readable.** Dark theme, metric colors, and a11y gates hold at 200 % font
   scale and with TalkBack.
6. **Nothing leaks.** The API and the report are private-by-URL only; that
   assumption is tested, not assumed.

Anything that risks 1 or 2 is a release blocker.

---

## 2. System under test (snapshot 2026-11-11)

| Piece | Detail |
|---|---|
| API | `https://a1c-api.onrender.com` · `/up` 200 · Rails 8.1 API-only · Postgres |
| App | `com.a1c.app` v0.6.0 (versionCode 6), installed 2026-10-14, demo flavor → Render |
| Device | nubia NX789J (RedMagic), Android 15, 1216×2688 @ 520 dpi, tz `America/Monterrey` |
| Health Connect | provider `com.google.android.apps.healthdata` 2026.10.01.00; all four read permissions granted |
| Collectors | SugarJoy+ `com.sugarjoy.plus`, xDrip+ `com.eveningoutpost.dexdrip`, Zepp `com.huami.watch.hmwatchmanager` |
| Data today | 50 doses in the last window, 179 glucose readings/24 h, activities through 2026-10-31, 0 nutrition rows |
| Tests | 57 Minitest runs / 209 assertions, green (`bin/rails test`) |
| CI | **none** (`.github/workflows` absent) |
| Repo | no branch checked out (detached at `a2210a1`), worktree clean |

### 2.1 Environments

| Env | API | App | Use |
|---|---|---|---|
| Local | `http://localhost:3000` / emulator `10.0.2.2` | `localDebug` | destructive tests, fixtures, migrations |
| Demo | Render `a1c-api` | `demoDebug` | delivery smoke, real-device verification |
| Phone | Render | installed 0.6.0 | the only environment that counts as "delivered" |

**Test-data rule:** never write fake doses, glucose, or meals into the Render
production database. Destructive and edge-case writes go to the local stack or
to a throwaway Render service with its own Postgres. On the live host, only
GETs, 422-producing requests, and idempotent retries of already-stored
`client_id`s are allowed.

---

## 3. Baseline audit — what was executed

| Check | Result |
|---|---|
| `bin/rails test` | 57 runs, 0 failures (needs Ruby 4.0.6 per `.ruby-version`; the default mise Ruby has no bundled gems) |
| `GET /up` | 200 |
| `GET /api/v1/settings` | 200, but **no `a1c_total` key** |
| `GET /api/v1/doses` | 200, doses to 2026-11-11 18:47Z, totals correct for Nov 9–11 |
| `GET /api/v1/days?days=3` | **returns 2026-10-25 / 10-27 / 10-31**, not the last 3 days |
| `GET /api/v1/days?days=14` | 14 rows spanning 2026-10-24 → 2026-11-11 (19 calendar days) |
| `GET /api/v1/glucose?hours=24` | 179 readings, ascending, `mmol_l` present |
| `GET /api/v1/activities?hours=336` | sessions through 2026-10-31 |
| `GET /api/v1/nutrition?hours=336` | empty |
| `POST /api/v1/doses` `{units:0}` | 422 + `{"error":{...}}` envelope ✔ |
| `GET /api/v1/nope` | 404 with **0-byte body** ✘ |
| `GET /report?days=14` | 200, 17 KB, ADA metrics + AGP + day table + A1C history |
| `GET /report?day=<date>` | 200 day detail; out-of-window day → 404 plain text |
| Phone UI | Log / Insulins / Generals render; HC permissions granted; empty outbox |
| Phone logs | no crash/ANR for `com.a1c.app` |

---

## 4. Findings register

Severity: **S1** wrong/lost health data · **S2** visible breakage or contract
violation · **S3** polish / docs / process. `E` = confirmed by execution,
`C` = confirmed by code reading, `U` = unverified hypothesis.

| ID | Sev | Area | Finding | Evidence |
|---|---|---|---|---|
| F-01 | S1 | `/api/v1/days` | `days=N` returns the N **most recently inserted** day keys, not the last N calendar days. Exercises are inserted into the hash last, so small N returns old workout-only days and can drop today. Powers the day bars and Today-vs-standard. | E: `?days=3` → Oct 25/27/31 while Nov 11 has doses. `DaysController#day_rows` → `by_date.values.last(limit)` |
| F-02 | S1 | Delivery | Deployed API is behind: Render is live on `ebfe87d` (2026-10-03). Commits `6647e35` (design system + A1C:Total) and `a2210a1` (docs) were **never pushed** to `origin/main`, so auto-deploy never ran. The installed 0.6.0 app therefore renders no `A1C:Total`. | E: `origin/main` = ebfe87d; Render deploy list |
| F-03 | S1 | Glucose ingest | `EntriesController` calls `insert_all!` **without `valid?`**, so `sgv ≥ 2000` (model says `< 2000`) and other invalid rows are stored and poison the curve/report. Activities and nutrition do validate. | C |
| F-04 | S1 | Offline outbox | `syncOutbox()` breaks on **any** exception, including a 4xx rejection. One permanently rejected dose stays queued forever and blocks every later dose from syncing. | C: `A1CRepository.syncOutbox` catch → `break` |
| F-05 | S2 | API contract | Unknown routes return 404 with an empty body, not the documented `{"error":{code,message,field}}` envelope. | E: `/api/v1/nope` → 404, 0 bytes |
| F-06 | S2 | Dose display | Recent-doses rows format `created_at`, not `taken_at`; an offline-synced dose shows the sync time, contradicting "real injection time". | C: `LogScreen` recent-doses row |
| F-07 | S2 | Log form | Type chips are hard-coded `N` / `R`; IA and slice 3.3 say the configured insulin names label the Log screen. Docs and UI disagree. | E: screenshot shows N/R while settings are Novorapid/Ryzodeg |
| F-08 | S2 | Day context | "Today vs standard" uses device-local `LocalDate.now()` and averages the last 14 **rows** divided by rows-present, not 14 calendar days. Wrong "today" when the phone zone ≠ `settings.timezone`; inflated averages on sparse data. | C |
| F-09 | S2 | Chart legend | Legend row overflows: "slow ▼" wraps into three clipped lines at the right edge. | E: screenshot |
| F-10 | S2 | Chart axes | 24 h chart prints only `HH:mm` at both ends ("16.34 → 16.18"), so time appears to run backwards across midnight; no y-axis labels or unit. | E: screenshot |
| F-11 | S2 | UI hygiene | A dev diagnostic ("18 sessions · 0 meals", 9 sp) is shipped in the Log card, self-labelled temporary. | E + C |
| F-12 | S2 | Health Connect | Ready requires **all four** permissions; a partial grant silently disables all context with no partial state or explanation. | C: `status()` equality check |
| F-13 | S2 | Privacy | `/report` is unauthenticated (by contract) with no `noindex`/robots directive; activities and nutrition ingest are open even when `GLUCOSE_INGEST_SECRET` is set. | E: headers, no meta |
| F-14 | S3 | API | `/api/v1/doses` returns the **entire** `daily_totals` history with no window param; payload grows forever. | C |
| F-15 | S3 | Report | TIR breaches are not visually flagged (only CV has pass/fail styling). | C: `flag-bad` only on CV |
| F-16 | S3 | HC accuracy | Session kcal sums every `TotalCaloriesBurnedRecord` overlapping the session (double counting when records overlap); HR aggregates only if samples fall inside. | C |
| F-17 | S3 | Schema | `routes` and `votes` legacy tables still exist; `docs/03` says only the six app tables do. Drop migration omitted them. | C: `db/schema.rb` |
| F-18 | S3 | Lifecycle | The clock and "3h ago" ages do not tick while the app stays open; `now` is captured on resume only. | C |
| F-19 | S3 | Log form | The form is cleared before the save callback; on a 4xx rejection the typed units/kind are lost. | C |
| F-20 | S3 | Docs drift | IA still lists weight on the Log header (UI removed it); `a1c_total` is undocumented in `03-data-model`/`spec.md`; day detail uses `?day=`. | C |
| F-21 | S3 | Process | No CI; tags are `slice-6-backend` (pipeline says `slice-6-context`); two commits (`6647e35`, `a2210a1`) sit after the `slice-7-report` tag. | E: `git tag`, no workflows |
| F-22 | S3 | Security | Ingest secret compared with `==` (not constant-time); no rate limiting on any ingest endpoint. | C |
| F-23 | S3 | A11y | Canvas charts expose no semantics; 9 sp diagnostic text; fixed 56/110 dp rows clip at 200 % font. | C |
| F-24 | S3 | Report math | `% time active` divides by `days_of_data × 288`, where a day with one reading counts as a full day. | C |
| F-25 | S3 | Android | Zero unit/instrumentation tests; no harness for the outbox or the repository. | E |
| F-26 | S1 | API serialization | Decimal columns were emitted as JSON **strings** (`"calories_kcal":"97.0"`, `"carbs_g":"53.4"`, `a1c_total`). The Android DTOs are `Double?`, so kotlinx.serialization rejects the whole response; the repository swallows it and falls back to empty/defaults. Result: exercise bands and food dots never render, and deploying F-02 would have silently reset insulin names to "Fast"/"Slow". | E: live activities payload types; caught by the new `a1c_total` test |

S1 items (F-01…F-04, F-26) block the next release; F-02 is a deploy plus the
F-26 fix.

### 4.1 Remediation status (2026-11-11)

Branch `fix/qa-blockers`, tests **65 runs / 226 assertions / 0 failures**.

| ID | Status | Change |
|---|---|---|
| F-01 | **Fixed** | `/days` now filters each source with `in_local_days(zone, N)` — a calendar window ending today; `last(limit)` removed. Regression tests for a stale workout-only day and an out-of-window dose. Verified live: `?days=3` → Nov 9/10/11. |
| F-02 | **Deployed & verified** | Root cause was two unpushed commits. Pushed `ebfe87d..4942777`; Render deploy `dep-dbqetjs9v7es73di78jg` went **live**. Live `/settings` now returns `a1c_total: 6.9` (Float) and the phone header shows `A1C:Total 6.9`. |
| F-03 | **Fixed** | Glucose ingest drops invalid rows (`.select(&:valid?)`) instead of `insert_all!`-ing them. Tests: single `sgv: 3000`, mixed batch. |
| F-04 | **Fixed (Android)** | `syncOutbox()` drops a 4xx-rejected dose and continues; only network/5xx breaks the loop. Compiles via `:app:compileDemoDebugKotlin`. No unit test yet (no Android harness — F-25). |
| F-26 | **Fixed & verified live** | `a1c_total`, `calories_kcal`, `carbs_g`/`calories_kcal` serialize with `.to_f`; tests assert JSON numbers. Live activities now return `calories_kcal` as Float. |
| F-05 | Open | Unknown routes still return a 0-byte 404 (needs a catch-all route + envelope). |
| F-06…F-25 | Open | See the tracker in §11. |

Three `days_controller` tests were rewritten to be relative to today: they had
hard-coded September dates and only passed because `/days` ignored the
calendar.

### 4.2 Post-deploy verification (2026-11-11)

Render deploy `dep-dbqetjs9v7es73di78jg` from `4942777`, status **live**
(16:41 CST). Against the live host afterwards:

| Check | Result |
|---|---|
| `GET /up` | 200 |
| `GET /api/v1/settings` | `a1c_total: 6.9` (Float); names/weight/A1C intact |
| `GET /api/v1/activities?hours=336` | 28 sessions, `calories_kcal` is a **float** |
| `GET /api/v1/days?days=3` | `2026-11-09, 2026-11-10, 2026-11-11` |
| `GET /api/v1/days?days=14` | 11 rows, `2026-10-31 → 2026-11-11` (window starts Oct 29; empty days absent) |
| `GET /report?days=14` | 200, 17 KB |
| Phone after force-stop + relaunch | `A1C:Total 6.9` in the header; insulin names still Novorapid/Ryzodeg |

Residual check: exercise bands/food dots could not be confirmed visually —
the last Health Connect session is 2026-10-31, outside the app's 24 h band
window. Confirm on the next workout sync; the numeric payload that used to
break decoding is proven by `/activities`.

### 4.3 Second batch (2026-11-11, APK 0.6.1)

Tests **69 runs / 237 assertions / 0 failures**; APK `0.6.1` (versionCode 7)
built and installed on the phone.

| ID | Status | Change |
|---|---|---|
| F-05 | **Fixed** | `ErrorsController` + catch-all routes (`/` and `*path`) render the documented `{error:{code,message,field}}` envelope with 404. Test asserts known routes are not shadowed. |
| F-06 | **Fixed** | `Dose.recent` orders by `coalesce(taken_at, created_at)`; the Recent-doses row formats `taken_at` when present. Test proves an offline dose does not jump the list. |
| F-07 | **Fixed — docs followed** | Type chips show the configured insulin names (`Novorapid` / `Ryzodeg`), ellipsized at 13 sp. The N/R pen letters were brand-specific. Verified on the phone. **Open question 1 is closed by this choice; say the word and it reverts to N/R + a docs edit.** |
| F-08 | **Fixed (zone); avg semantics kept** | "Today" is computed in `settings.timezone` (falls back to the device zone). The 14-day average still divides by days *with data* inside the now-correct 14-day window. |
| F-09 | **Fixed** | Legend is two deliberate rows (glucose/food/exercise, then fast ▲/slow ▼); nothing clips or wraps mid-word. Verified on the phone. |
| F-10 | **Fixed** | Y axis labelled in mmol/L (max/mid/min); x axis shows `d MMM HH:mm` at both ends, so a 24 h window no longer looks like it runs backwards. Verified on the phone. |

Also bumped `versionCode 6 → 7`, `versionName 0.6.0 → 0.6.1` so the installed
APK maps to a commit.

Still open from this batch: **F-11** (the "18 sessions · 0 meals" diagnostic
at 9 sp) was intentionally left for the next pass, since it needs a product
decision on what that status line should become.

### 4.4 Third batch (2026-11-11, APK 0.6.2)

Owner decisions applied: F-11 option 2, F-12 option 2, F-13 both, F-14 = 10
days as config. Tests **76 runs / 257 assertions / 0 failures**.

| ID | Status | Change |
|---|---|---|
| F-11 | **Fixed** | The 9 sp debug line is now an 11 sp sentence: `Health Connect: 18 sessions · 0 meals in the last 7 days`, or `sync failed — will retry`, or `nothing in the last 7 days`. Failure text no longer prints exception class names. |
| F-12 | **Fixed** | `NeedsPermissions` carries the missing scopes; the card says `needs access to heart rate` and offers **Connect Health** plus **Open settings**. All-or-nothing readiness is unchanged, so the read still needs all four. |
| F-13 | **Fixed & active** | `X-Robots-Tag` + `<meta robots>` `noindex, nofollow`. Optional `REPORT_TOKEN`: missing/wrong token → 404, all report links carry it. Token **enabled on Render**; value in `~/Work/A1See/.env.local`. |
| F-14 | **Fixed** | `/api/v1/doses?days=N`; default `DOSES_HISTORY_DAYS=10` (render.yaml), max 366. Android requests `HISTORY_DAYS` and the graph renders that window. Live: default 8 rows (Nov 2–3 had no doses), `?days=3` → 3, `?days=30` → 21. |

Deploy `dep-dbqfff142hec73cvkf30` live 17:19. Verified live: no token → 404,
wrong → 404, right → 200 with 15 token-carrying links; `X-Robots-Tag` present.

**Pending on device:** the 0.6.2 APK is built but the phone dropped off USB
before install, so the F-11/F-12 UI has not been seen on hardware yet.


---

## 5. Test strategy

### 5.1 Levels

| Level | What | Tooling | Gate |
|---|---|---|---|
| L1 unit/model | validations, GMI/CV/TIR math, percentile, local-day SQL | Minitest | every push |
| L2 request/API | status, payload shape, error envelope, idempotency, clamps | Minitest `test/controllers` | every push |
| L3 integration | app ↔ API: dose round-trip, outbox sync, HC upload, report render | emulator + local API, then phone + Render | per slice |
| L4 device/UX | form speed, states, navigation, TalkBack, font scale, rotation | physical phone | per slice |
| L5 non-functional | cold start, 24 h soak, DST, privacy, load | scripts + phone | before tagging |

The pyramid is deliberately thin at L1/L2 (personal-scale app, no auth) but
**L4 is mandatory**: the contract says "delivered" only when it works on the
phone against Render.

### 5.2 New tests (added 2026-11-11 unless marked open)

1. `days window ends today, not at the newest inserted day key` (F-01) ✔
2. `days window excludes events older than N calendar days` (F-01) ✔
3. `skips an out-of-range sgv instead of storing it` + `mixed batch keeps valid readings` (F-03) ✔
4. `unknown API path returns the documented error envelope` + root/top-level + `known routes are not shadowed` (F-05) ✔
5. `payload includes a1c_total as the average of lab A1C and 90-day GMI` + fallback (F-02/F-26) ✔
6. `index emits numeric calories/carbs, not JSON strings` (F-26) ✔
7. `recent doses are ordered by effective time, not receive time` (F-06) ✔
8. Android: `outbox drops a poison message on 4xx and continues` (F-04) — **open** (needs a harness)
9. Android: `pending dose merges into totals under settings.timezone` (F-08) — **open**
10. Report: `TIR goal breach is flagged` (F-15) — if accepted.
11. Report: `pct_time_active uses days in window, not days with one reading` (F-24) — if accepted.
12. `marks the page noindex in headers and markup` + `requires REPORT_TOKEN` + `report links carry the token` (F-13) ✔
13. `daily totals default to 10 days`, `accept days override and clamp`, `window is a deploy config parameter` (F-14) ✔

### 5.3 Traceability

| Doc contract | Suites |
|---|---|
| `01-product-brief` — log in < 5 s, daily totals | A, C, M |
| `02-information-architecture` — 3 screens, nav, labels | I, D, F-07 |
| `03-data-model` — tables, bucketing, offline keys | B, C, O |
| `ADR-001` — no auth, `/api/v1`, JSON shapes, flavors | E, N, P |
| `ADR-002` — Nightscout ingest, secret, 24 h card | E |
| `ADR-003` — HC ingest, `/days`, day bars, `/report` | F, G, H |
| `design-system` — one color per metric, contrast | L |
| `PIPELINE` — slice tags, Render delivery | P |

---

## 6. Functional suites

Each case: **ID · steps · expected**. "Phone" = installed demo flavor on the
RedMagic unless stated.

### A. Dose logging (the product)

| ID | Case | Expected |
|---|---|---|
| A-01 | Cold start → Log | Log renders before any network response; header clock and last A1C appear |
| A-02 | Type `6`, tap N, tap save | Haptic + "✓ Saved 6 u fast"; field clears; dose appears in Recent doses; golden path under 5 s |
| A-03 | Type `0` / blank | Save disabled |
| A-04 | Type `123` | Field caps at 2 digits (`12`); no crash |
| A-05 | Choose kind, no units | Save disabled |
| A-06 | Units only, no kind | Save disabled |
| A-07 | Tap save twice rapidly | Exactly one dose; idempotent (`client_id`) |
| A-08 | Units = 99 | Accepted; totals add 99 |
| A-09 | Today's bar | Increases by the saved units immediately, without waiting for a refresh |
| A-10 | Server 422 (curl-only, local) | Error text shown in error color, form state preserved (currently lost — F-19), nothing stored |
| A-11 | IOB card | Only fast doses, linear 4 h decay, 0.0 u after 4 h |
| A-12 | Last-insulin card | Newest dose by effective time, name from settings, color by kind |
| A-13 | Recent doses | Newest first, 10 rows, name/units/date; offline rows marked "pending" (and must show `taken_at` — F-06) |

### B. Offline outbox

| ID | Case | Expected |
|---|---|---|
| B-01 | Airplane mode → save a dose | "✓ Saved offline — will sync when online"; "1 pending sync" chip; dose at top of list marked pending |
| B-02 | Restore network → background/foreground | Dose POSTs once, chip disappears, totals include it once |
| B-03 | Kill app in airplane mode → reopen online | Queued dose still present and syncs (DataStore survives process death) |
| B-04 | Queue 3 doses offline, restore | All 3 sync in order; no duplicates |
| B-05 | Replay the same `client_id` via curl | 200 with the existing dose; no second row |
| B-06 | Poison record (force a 422 on sync) | Record is dropped/logged, later records still sync (currently blocks — F-04) |
| B-07 | Pending dose day attribution | Counted on the injection's **local** day in `settings.timezone` (F-08) |
| B-08 | Outbox inspection | `adb shell run-as com.a1c.app cat files/datastore/a1c_outbox.preferences_pb \| strings` shows exactly the pending set |

### C. Daily totals & day bucketing

| ID | Case | Expected |
|---|---|---|
| C-01 | 20:00 local dose | Counted on that local date, not UTC tomorrow |
| C-02 | 23:30 local dose | Same local day; graph unaffected until midnight |
| C-03 | 00:05 local dose | New day |
| C-04 | `taken_at` ≠ `created_at` (offline) | Bucketed by `taken_at` |
| C-05 | Change `settings.timezone` (PATCH) | History re-buckets on next load; no dose moves days unexpectedly |
| C-06 | DST zone (e.g. `America/New_York`, spring forward) | 23:30 and 02:30 doses land on their local dates; no duplicate/missing day |
| C-07 | Graph window | Last 14 days with data, ascending, labels parsed as `LocalDate` (no zone shift) |
| C-08 | Bar heights | Fast and slow share one scale (max of either), fast drawn narrow on top of slow |
| C-09 | Empty history | "Log your first dose to see the graph." |

### D. Settings, insulin names, A1C

| ID | Case | Expected |
|---|---|---|
| D-01 | Insulins: change both names, save | "Saved"; Log legend and recent doses use the new names |
| D-02 | Blank name | Save disabled (UI) and 422 (API) |
| D-03 | Generals: set weight 78.5, A1C 6.9, save | Persisted; A1C:Total recomputed |
| D-04 | Set A1C again same day | `a1c_entries` keeps one row for today, value updated |
| D-05 | Set A1C next day | New row appended; history has two points |
| D-06 | Save weight only | No new A1C point (guard on `saved_change_to_last_a1c?`) |
| D-07 | A1C = 0 or negative | 422, message readable in the app |
| D-08 | Weight with 3 decimals | Server rounds to `decimal(5,2)`; UI re-reads |
| D-09 | Offline save | "No connection — try again when online"; nothing persisted |
| D-10 | `A1C:Total` | Shown when the API returns it: average of last lab and 90-day GMI; hidden only when both are absent (currently hidden always — F-02) |
| D-11 | Timezone | PATCH `timezone` via curl; invalid zone → 422; valid zone changes bucketing |

### E. Glucose (v2 / ADR-002)

| ID | Case | Expected |
|---|---|---|
| E-01 | xDrip+ live upload | Reading appears within one upload interval; value in mmol/L, direction arrow, age |
| E-02 | `GET /api/v1/glucose?hours=24` | Ascending, `mmol_l` = sgv/18 rounded to 1 dp |
| E-03 | Ingest single + array | 201 `{ingested, received}`; counts correct |
| E-04 | Repeat same `time` | No duplicate (unique index) |
| E-05 | `type` = `cal` / missing | Ignored, counted in `received` only |
| E-06 | `date` vs `dateString` | Both parse; invalid → skipped, not 500 |
| E-07 | `sgv` = 0 / 3000 | Rejected (currently 3000 is stored — F-03) |
| E-08 | `GLUCOSE_INGEST_SECRET` set | Missing/incorrect `api-secret` → 401; raw and SHA-1 hex both accepted |
| E-09 | CGM stale > 30 min | Value dims; no crash; chart shows the gap |
| E-10 | No glucose at all | "Waiting for glucose data…"; dose logging unaffected |
| E-11 | Glucose API down | Charts keep last data; doses still save (isolation gate) |
| E-12 | Chart | Cyan 2.5 dp line, 3.9–10 band, latest point, no y-axis labels (fix with F-10) |

### F. Health Connect context (v2.x / ADR-003)

| ID | Case | Expected |
|---|---|---|
| F-01 | First run, no permissions | "Connect Health" appears; nothing else changes |
| F-02 | Grant all four | Context bars fill; diagnostic count updates |
| F-03 | Grant 3 of 4 | App explains what's missing (currently silent — F-12) |
| F-04 | Workout on the Balance → Zepp → HC | Session appears as a green band; minutes/kcal correct |
| F-05 | Meal logged in a food app | Amber dot at intake time; carbs increase in the bars |
| F-06 | Re-open the app 5× | No duplicate activities/nutrition (`hc:<metadata-id>`) |
| F-07 | Delete a workout in Zepp | A1See keeps history (append-only, by contract) |
| F-08 | HC unavailable (Android 13 without the APK, or permission revoked) | Bars show a waiting state; glucose and logging untouched |
| F-09 | 7-day re-read volume | Re-POSTing 7 days is idempotent and does not slow the open noticeably |
| F-10 | Fractional carbs (53.4 g) / kcal-only (black coffee) | Accepted; zero coerced to null, batch not rejected |
| F-11 | Day bars | Three own-scale bars (insulin/carbs/minutes) vs 14-day max, never a shared axis |
| F-12 | `GET /api/v1/days?days=3` | Returns **today and the two prior calendar days** (currently October — F-01) |

### G. Unified day table

| ID | Case | Expected |
|---|---|---|
| G-01 | `days` default / clamp | 30 rows max; `1 ≤ days ≤ 180` |
| G-02 | Days without events | Absent, not zero rows (for `/days`; the report fills zeros) |
| G-03 | Insulin split | `total = fast + slow` on every row |
| G-04 | Carbs/kcal sums | Match the underlying entries to 2 dp internally, integers on the wire |
| G-05 | Exercise minutes | Sum of session minutes per local day |
| G-06 | Ordering | Ascending by local date |
| G-07 | Window correctness | Only dates inside the last N local days (F-01) |

### H. Doctor report

| ID | Case | Expected |
|---|---|---|
| H-01 | `GET /report` | 200, one page, light theme, inline CSS/SVG, no JS |
| H-02 | Defaults and clamps | 14 days default, `1 ≤ days ≤ 90` |
| H-03 | Core metrics | Days of data, % active, mean, GMI (`3.31 + 0.02392 × mean`), CV, TIR stack |
| H-04 | GMI math | Hand-computed mean → GMI matches to 0.1 |
| H-05 | CV math | sd/mean×100 matches; > 36 % flagged |
| H-06 | TIR buckets | `<54`, `54–69`, `70–180`, `181–250`, `>250` sum to 100 ± rounding |
| H-07 | AGP | 96 buckets, percentile band, median line, 70–180 band |
| H-08 | Day table | Insulin fast/slow/total, carbs, kcal, exercise per local day |
| H-09 | Day detail | Clicking a date opens that day's curve with dose/meal/workout markers; out-of-window date → 404 |
| H-10 | A1C history | Lab points plus GMI trend; one lab point still renders |
| H-11 | No data | Empty states, no divide-by-zero, no `NaN` |
| H-12 | Print | US Letter/A4, readable at 100 %, page breaks do not split a chart, `< 3` pages for 14 days |
| H-13 | Units | mg/dL everywhere (the app stays mmol/L) |
| H-14 | Privacy | Not indexed, not cached publicly, no PHI in the URL |

### I. Navigation & lifecycle

| ID | Case | Expected |
|---|---|---|
| I-01 | Bottom bar | Log / Insulins / Generals; state restored per tab |
| I-02 | Rapid tab switching | No duplicate ViewModels or stacked screens |
| I-03 | Background for 30 min → resume | Clock, glucose, HC resync; no crash |
| I-04 | Rotation while typing | Text and selection survive (`configChanges` declared) |
| I-05 | Back from a config screen | Returns to Log, app stays open |
| I-06 | Process death (Don't keep activities) | App returns to Log; outbox intact |
| I-07 | Weight field | Not in the UI; still in the API (docs say otherwise — F-20) |

### J. Error, empty, and degraded states

| ID | Case | Expected |
|---|---|---|
| J-01 | API unreachable, no cache | Designed error card + Retry |
| J-02 | API unreachable, cache present | Stale data shown; **some** offline indicator (currently none) |
| J-03 | 500 from the API | Human message, no stack trace |
| J-04 | First run, empty DB | Empty graph and dose list copy, no placeholder junk |
| J-05 | Slow network (3G profile) | App usable; save either confirms or queues; no ANR |
| J-06 | Airplane toggle mid-save | Either confirmed or queued exactly once |
| J-07 | Timeout | Treated as offline; dose queued (408 included) |

### K. Accessibility

| ID | Case | Expected |
|---|---|---|
| K-01 | TalkBack pass on Log | Timestamp, three metric cards, units field ("Insulin units"), type chips (announce configured names), save ("Save dose"), message, graph summary |
| K-02 | Canvas charts | Reachable/described or duplicated as text (currently silent — F-23) |
| K-03 | Touch targets | ≥ 48 dp for save, chips, nav items, retry |
| K-04 | Contrast | All metric tokens ≥ 4.5:1 on `#0A0A0C`/`#141418`/`#1E1E24`; verify with a meter, don't trust the table |
| K-05 | Font scale 200 % | No clipping of values, labels, or the N/R chips; rows reflow |
| K-06 | Color independence | Fast/slow/food/exercise still distinguishable by shape, position, and unit label |
| K-07 | Keyboard | Numeric keyboard for units; IME does not cover the save row |
| K-08 | Report | Semantic headings, table headers, SVG has text alternatives, prints in grayscale |

### L. Visual / design-system conformance

| ID | Case | Expected |
|---|---|---|
| L-01 | One color = one metric | Glucose cyan, fast orange, slow blue, food amber, exercise green, IOB red (documented exception), error red only for failures |
| L-02 | Purple-pink accent | Save/selected only; never on data |
| L-03 | Legend | Complete, non-wrapping, matches markers (F-09) |
| L-04 | Dark only | No light theme, no white flash on cold start |
| L-05 | Report palette | CSS vars mirror the tokens; still readable printed B/W |
| L-06 | `@interface-review` | Run before any UI slice is called done (per AGENTS.md) |

### M. Performance

| ID | Case | Target |
|---|---|---|
| M-01 | Cold start → Log interactive | < 1.5 s on the phone |
| M-02 | Cold start → dose saved (A-02) | < 5 s median of 10, p90 < 7 s |
| M-03 | Resume → fresh glucose | < 3 s with a warm API |
| M-04 | Log screen scroll | 60 fps, no jank in the 24 h chart card |
| M-05 | `/api/v1/doses` | < 300 ms with 2 years of data (generated locally) |
| M-06 | `/report?days=90` | < 2 s server time; < 5 MB HTML |
| M-07 | Render cold service start | Report the actual number; it is part of the UX |
| M-08 | 24 h soak | No leak, no crash, battery delta acceptable |

### N. Security & privacy

| ID | Case | Expected |
|---|---|---|
| N-01 | No auth | Confirmed by design; document who knows the URL |
| N-02 | Ingest secret | Set → glucose ingest 401 without header; unset → open (accepted) |
| N-03 | Secret handling | Never in git, never in logs, compared safely (F-22) |
| N-04 | Host header | Foreign `Host` rejected (`config.hosts`), `/up` still 200 |
| N-05 | TLS | HTTPS only; no mixed content; HSTS decision recorded |
| N-06 | Report privacy | `noindex`, private cache, no PHI in URL, no open redirect (F-13) |
| N-07 | Error text | No SQL, paths, or stack traces in 4xx/5xx bodies |
| N-08 | Log hygiene | Parameter filter covers secrets; glucose/dose values are not PII but review volume |
| N-09 | Abuse | No rate limit: document the blast radius of a leaked URL (junk data only) |

### O. Data integrity & migrations

| ID | Case | Expected |
|---|---|---|
| O-01 | `db:prepare` on an empty DB | Schema + settings row (idempotent seed) |
| O-02 | Migrate from the previous production schema | No data loss; legacy tables gone (F-17) |
| O-03 | Unique indexes | `doses.client_id`, `glucose_readings.time`, `activity_sessions.client_id`, `nutrition_entries.client_id`, `a1c_entries.measured_on` |
| O-04 | Concurrency | Two identical glucose POSTs at once → one row (currently a possible 500 on unique violation) |
| O-05 | Integer overflow / precision | `units` int, `carbs_g`/`kcal` decimal(9,2), `a1c` decimal(3,1) |
| O-06 | Backup/restore | Render snapshot restores; app reconnects unchanged |
| O-07 | Clock skew | A phone 10 min fast does not corrupt day totals |

### P. Delivery & process

| ID | Case | Expected |
|---|---|---|
| P-01 | Deploy `main` | Render build green, `/up` 200, seed row present |
| P-02 | Deployed code = tagged commit | `GET /settings` includes every field the installed APK reads (currently fails — F-02) |
| P-03 | APK ↔ API compatibility | Installed APK against Render after each deploy |
| P-04 | Slice tag | `slice-N-<name>` on the shown commit; matches PIPELINE (F-21) |
| P-05 | Docs sync | README/docs reflect the shipped UI before tagging (F-20) |
| P-06 | Rollback | Previous Render deploy restored within 10 min; data untouched |
| P-07 | CI | `bin/rails test` runs on push, Ruby 4.0.6 pinned (F-21) |

---

## 7. Release gates

### 7.1 Per-slice definition of done (PIPELINE, made testable)

- [ ] Endpoints respond on Render.
- [ ] Settings row present with sane defaults.
- [ ] Demo APK path for the slice works **on the phone against Render**.
- [ ] All S1/S2 findings for that slice closed.
- [ ] `bin/rails test` green; new tests added for new rules.
- [ ] Accessibility and design-system checks (K, L) passed.
- [ ] Tag matches PIPELINE and points at the deployed commit.

### 7.2 Five-minute smoke (every deploy, on the phone)

1. `GET /up` → 200; `GET /settings` has all fields the APK reads.
2. Cold start → Log renders.
3. Log `2 u` fast → confirmation, bar updates.
4. Open Insulins → names correct; Generals → weight/A1C correct.
5. `/report` opens and prints one page.
6. Airplane mode → save queues; restore → syncs once.

### 7.3 Blocking criteria

No release with an open S1. No release if the deployed API is older than the
tag. No release if the phone APK cannot log a dose in under five seconds.

---

## 8. Defect reporting

```
Title:      <area> — <what breaks>
Severity:   S1 / S2 / S3
Found in:   API commit / APK version / device / env
Steps:      1..n (with exact times, kinds, units)
Expected:   per doc section
Actual:     what happened (screenshot or curl output)
Data:       ids, client_ids, dates, timezone
Impact:     dose lost? number wrong? friction?
```

Severity guide: **S1** wrong or lost health data, crash in the log path, silent
data corruption. **S2** visible breakage, contract violation, wrong label,
unusable state. **S3** polish, docs, process.

---

## 9. Automation roadmap

| Order | Item | Why |
|---|---|---|
| 1 | CI job: Ruby 4.0.6, `bin/rails test` | no gate today (F-21) |
| 2 | Tests for F-01, F-03, F-04, F-05 | each is a correctness bug |
| 3 | Android unit tests for `Outbox`, `LogData.mergedWith`, `insulinOnBoard` | pure functions, no device needed |
| 4 | API contract test from a recorded fixture set | catches deploy drift like F-02 |
| 5 | Nightly curl smoke against Render (read-only + 422) | catches F-02/F-05 class failures |
| 6 | Screenshot diff of Log at 100 %/200 % font | catches F-09/F-10/F-23 |
| 7 | Compose UI test for the save flow (emulator) | protects the one critical path |
| 8 | Report golden-file test (metrics + SVG presence) | protects slice 7 |

---

## 10. Open questions for the product owner

1. ~~Chips: keep the pen letters N/R or use the configured names?~~ **Decided
   2026-11-11: configured names** (F-07), matching IA + slice 3.3. Revert if
   the pen letters were intentional — then the docs change instead.
2. ~~Should `/api/v1/days?days=N` mean calendar days or rows?~~ **Decided:
   calendar days** (F-01).
3. Weight was removed from the Log header — update `02-information-architecture`
   or restore the line (F-20).
4. ~~Is the "sessions · meals" line meant to ship?~~ **Decided 2026-11-11:
   keep it as a designed 11 sp status sentence** (F-11).
5. ~~Privacy posture for `/report`~~ **Decided: both.** noindex plus an
   optional `REPORT_TOKEN`, enabled on Render (F-13). Token lives in
   `~/Work/A1See/.env.local`, not in git.
6. Should a 4xx'd queued dose be dropped with a visible warning, or surfaced as
   a per-dose error list? (F-04)

---

## 11. Known-issue tracker summary

| Area | Open | Worst |
|---|---|---|
| Day table / bars | F-01 (fixed), F-08 (fixed), F-14 (fixed), G-07 | S1 |
| Glucose ingest | F-03 (fixed), E-07 | S1 |
| Offline sync | F-04 (fixed), B-06, F-19 | S1 |
| Delivery | F-02 (deployed), F-21, P-02 | S1 |
| API serialization | F-26 (fixed) | S1 |
| Log UI | F-06…F-11 (fixed), F-18 | S2 |
| Health Connect | F-12 (fixed), F-16 | S2 |
| Privacy / API | F-05 (fixed), F-13 (fixed), F-15, F-22 | S2 |
| Docs / schema / a11y | F-17, F-20, F-23, F-24, F-25 | S3 |

Fix order: the S1s and the S2s through F-13 are done and deployed. Next: F-16
(HC calorie double counting), F-15 (TIR flags), F-18 (clock ticking), F-19
(form state on rejection), then docs/schema/a11y (F-17, F-20, F-23…F-25).
