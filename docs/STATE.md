# A1See — session state

## Current state — 2026-11-24 (session end)

- **Repo:** `~/Work/A1See` on `main`, clean, synced with origin. The
  `fix/qa-blockers` worktree was retired; all QA work is merged into `main`.
- **Deployed API:** Render live on `514b433` (`main`). `REPORT_TOKEN` enabled
  — value in `.env.local`, not git. `DOSES_HISTORY_DAYS=10`.
  `REPORT_ADMIN_SECRET` set on Render and in `.env.local` (switch for
  `/report`, see 2026-11-24 below).
- **Phone:** A1See **0.6.2** (versionCode 8). xDrip + Juggluco both allowed
  in RedMagic battery management (auto-start, secondary launch, background
  running). xDrip uploads; Juggluco is the sensor reader/broadcaster.
- **Verified today:** the `/report` kill switch end to end on the live URL
  (disarmed 404 → armed 200 → self-expiry 404), suite at 94 runs / 308
  assertions. Still standing from 2026-11-12: ±30 s dedupe, 5-min-bucket
  metric, and xDrip background delivery — 108/108 readings 22:00–06:40,
  24 h coverage 90.6%, 3 short daytime gaps.
- **Open:** Sonic's page review before any report polish (see 2026-11-24
  findings); the 0.6.2 Health Connect status line and missing-permission UI
  not yet seen on device; one test glucose row to delete; QA findings
  F-15…F-25.
- **Next:** (1) tomorrow morning, check last night's coverage; (2) if the
  gap returns, enable xDrip "Run Collector in foreground" or switch uploads
  to Juggluco; (3) QA F-15 (TIR flags), F-16 (HC kcal double count),
  F-18 (clock ticking), F-19 (form state on rejection); (4) slice 8
  (ADR-004 identity/scoping) is the next product gate.

## 2026-11-24 · Doctor report: kill switch, and a pre-consult audit

- **Why:** Sonic meets his endocrinologist in two days and wants `/report`
  live only when he is looking at it or showing it in the consult — not a
  permanent public URL. The old contract was the opposite: `REPORT_TOKEN`
  unset meant *open*, set meant token-gated but open forever.
- **Switch shipped (`514b433`, deploy `dep-dc30pami0phs73ek398g`):** two
  columns on `settings` (`report_access_until`, `report_token`). `/report`
  now fails closed: 404 unless a window is armed **and** the token matches;
  404 if no token is configured anywhere. Windows clamp to 7 days and lapse
  on their own. Arming only through `Api::V1::ReportAccessController`
  (`X-Report-Admin-Secret`), never through the report link.
- **Desktop control:** `scripts/a1see-report` (symlinked to
  `~/.local/bin/a1see-report`) — `on [3h] · off · status · open · url ·
  rotate`. Reads `RENDER_URL` + `REPORT_ADMIN_SECRET` from `.env.local`.
- **Backup first:** `~/Backups/a1see/a1c_production_20261124-1612.dump`
  (custom format, 257 KB, 8 tables) before the migration.
- **Verified live:** disarmed + correct token → 404; wrong/no token while
  armed → 404; armed → 200 with "link live until HH:MM" in the header;
  day detail 200; `off` → 404; arm 1 min → 200, then 404 after 70 s.
  Tests 94 runs / 308 assertions green; rubocop clean.
- **Permanent address (follow-up, Sonic's call):**
  `https://a1c-api.onrender.com/doctor-dashboard` — clean path, no token to
  paste, `/report` kept as an alias for links that already carry one. Access
  is the armed window alone; a supplied token must still match. Tradeoff
  accepted explicitly: the path is guessable, so the page is only as private
  as the window is short.
- **Country filter (also Sonic's call):** while armed, anonymous visits must
  come from `REPORT_ALLOWED_COUNTRIES=MX` (Cloudflare's `CF-IPCountry`, set at
  Render's edge). Verified: allowlist `US` → MX traffic 404; a forged
  `CF-IPCountry: US` from MX **still** 404s, so the edge overwrites the header
  and it cannot be spoofed; a valid token bypasses the filter (escape hatch for
  a mislabelled carrier network). Diagnostics live in `GET /api/v1/report_access`
  (`allowed_countries`, `your_country`).
- **Operational gotcha:** env var changes on Render only apply after a
  **deploy** — `/restart` came back with the old values. Also, for ~20 s after
  a deploy reports `live`, requests can still be served by the old container,
  so verify a blocking change with a cache-busting query param and a second
  request. Cost 20 minutes today.
- **API gate (same day, Sonic asked for it):** every `/api/v1` data route now
  inherits `Api::V1::BaseController` and applies `API_ALLOWED_COUNTRIES=MX`
  against the same edge header. Blocked requests get the 404 envelope; the
  admin switch stays ungated so it is reachable from anywhere. Verified live
  with the allowlist flipped to `US`: all read and write routes 404 while
  `/api/v1/report_access` and `/doctor-dashboard` stayed 200; after restoring
  `MX`, a fresh CGM reading arrived within one upload cycle (23:06:33Z), so
  the phone pipeline is unaffected.
- **Cache note:** Cloudflare does not cache either surface — the API answers
  `cache-control: no-cache`, the report `max-age=0, private, must-revalidate`,
  both `cf-cache-status: DYNAMIC`. No PHI sits in a shared edge cache.
- **Still open (pre-slice-8):** there is no per-user auth. The country gate is
  a net, not a lock: anyone in Mexico still reads `/api/v1/*`.
- **Page review round 1 (same evening, four notes):** days-of-data moved from
  a card to a legend line; TBR (<70) and TAR (>180) cards added in percent
  with ADA goals; daily context moved to the bottom; A1C history rebuilt
  (anchored to the last lab, lab value as a labelled line, y axis explained).
  Then round 2: half-point y gridlines, x labels every 2 days / 2 weeks in
  compact form, a dot per daily GMI point, chart height 220 -> 300.
- **A1C backfill:** `a1c_entries` row 1 = 2026-09-14, 6.8 % (Sonic's lab
  result), inserted directly with psql after the dump. `settings.last_a1c`
  was already 6.8 but the upsert only fires on change, so the series was
  empty; the chart now starts at the draw.
- **Docs:** QA-plan H-01 reworded, H-10 and H-12 tightened, H-15 (kill
  switch), H-16 (arming), H-17 (permanent path) and H-18 (country filter)
  added; README gained the switch section, the country filter and the access
  endpoints.
- **Audit findings, not yet fixed** (Sonic is reviewing the page before
  deciding): the A1C chart has **zero lab points** — `settings.last_a1c` is
  6.8 but `a1c_entries` is empty, because the upsert only fires when
  `last_a1c` *changes* after the deploy; nutrition is 4 entries in 30 days
  (all Zepp, all 2026-11-16) so carbs/kcal read `0` on 13 of 14 days; day
  detail is not chronological (doses, then meals, then workouts); charts are
  illegible at 390 px because the 720-wide SVG scales down; the 14-day table
  splits across the print page break; `favicon.ico` 404s. Nov 12 and Nov 20
  show no doses at all — a logging gap, not a report bug.

## 2026-11-12 · CGM pipeline: xDrip freeze diagnosed

- **Symptom:** 147.7 h missing over 14 days, every night ~22:00 → ~06:00
  (A1See 54–55% time active).
- **Evidence:** Juggluco's own `files/sensors/<serial>/polls.dat` (20-byte
  records: epoch, seq, sgv) holds **4,413 readings, 1/min, zero gaps** for
  Nov 8–11. The loss is after Juggluco.
- **Screen-off test (16 min, charging at 100%):** xDrip `curProcState=10`
  and **0 readings** reached A1See; Juggluco stayed `curProcState=4`
  (foreground service). xDrip's ongoing notification has **no
  FOREGROUND_SERVICE flag** — it is not a foreground service, so the OS
  freezes it when the screen is off. The Juggluco→xDrip EverSense broadcast
  is live-only, so frozen minutes are lost permanently.
- **Impact:** same 3-day window, complete vs A1See — mean 167.5 vs 153.1
  mg/dL, GMI **7.3 vs 7.0**, TIR **61.7 vs 68.8%**. The missing hours are
  the high ones (Nov 10 night 242, Nov 11 night 233; Nov 9 night 148), so
  the report was flattering the numbers.
- **Shipped (fc6f0e1):** glucose ingest dedupes within ±30 s (xDrip
  fractional seconds vs Juggluco whole seconds); `/report` % time active
  counts distinct 5-minute buckets so 1-minute uploads can't read 500%.
- **Next:** switch ingest to Juggluco's own Nightscout Uploader
  (`https://a1c-api.onrender.com`, Active, test V3 off, Give Amounts off),
  turn off xDrip's Nightscout upload (keep xDrip for alarms), press
  "Resend data" to backfill, then repeat the 16-min screen-off test.
- **Resolved 2026-11-12 18:43 local:** the cause was RedMagic's battery
  management, not xDrip alone. Three toggles were off — **auto-start**,
  **secondary launch**, **background running** (Apps → battery management).
  Allowed, then the same screen-off test: 8 min → 1 reading, 20 min → 4/4
  readings (00:48/00:52/00:57/01:02), xDrip still `curProcState=10` with no
  foreground service. No persistent notification needed.
- **Overnight confirmed 2026-11-12:** 108/108 readings 22:00–06:40 (mean
  115 mg/dL, TIR 100%, GMI 6.1); last 24 h = 270 readings, 90.6% bucket
  coverage, gaps only 13:47→14:40, 07:41→08:23, 18:01→18:18 (1.9 h total,
  all daytime). 14-day report still reads 54.9% time active / GMI 7.1 /
  TIR 62.3% because 13 gap-riddled days remain in the window; it will climb
  as new nights accumulate. No action needed unless a system update resets
  the three OEM toggles.
- **Cleanup:** my compatibility replay stored one extra row —
  `GlucoseReading.where(device: "Juggluco").delete_all` in the Render shell
  (all real rows are `xDrip-NSEmulator`).

## 2026-11-11 · QA audit + blocker fixes (branch `fix/qa-blockers`)

- Wrote `docs/QA-plan.md`: baseline audit, 16 suites (~120 cases), findings
  register F-01…F-26, release gates, 5-min smoke, automation roadmap.
  Targets the shipped v2.x app, not the ADR-004 slices 8–15.
- Fixed on `fix/qa-blockers` (`4942777`), tests **65 runs / 226 assertions
  green**, Android `:app:compileDemoDebugKotlin` green:
  - **F-01** `/api/v1/days?days=N` is now a calendar window ending today.
    It was "last N inserted day keys"; `days=3` returned Oct 25/27/31.
  - **F-03** glucose ingest validates before `insert_all!` (sgv ≥ 2000 was
    being stored).
  - **F-04** outbox drops 4xx-rejected doses; one poison record no longer
    blocks every later dose.
  - **F-26** decimal payloads (`a1c_total`, `calories_kcal`, `carbs_g`) now
    serialize as numbers. They were JSON strings, which broke the Android
    `Double` decoding — exercise bands / food dots / A1C:Total were silently
    lost.
- **F-02 root cause:** `6647e35` (design system + A1C:Total) and `a2210a1`
  (docs) were **never pushed**. `origin/main` = `ebfe87d`; Render live =
  `ebfe87d` since 2026-10-03.
- **Deployed:** pushed `ebfe87d..4942777`; Render deploy
  `dep-dbqetjs9v7es73di78jg` live at 16:41 CST. Verified live: `/up` 200,
  `settings.a1c_total = 6.9` (Float), `activities.calories_kcal` Float,
  `/days?days=3` = Nov 9–11, `/report` 200. Phone header now shows
  `A1C:Total 6.9`. Exercise bands not visually confirmed (last HC session
  Oct 31, outside the 24 h window) — check on the next sync.
- Next after deploy: on-phone check (exercise bands + A1C:Total), then
  **F-05** (404 envelope), F-06 (recent doses use `taken_at`), F-07 (N/R vs
  insulin names), F-08 (`TodayVsStandard` zone/avg), F-09/F-10 (chart
  legend/axis).
- **Batch 2 done** (`ac4fbb0`, deploy `dep-dbqf3459el5s73eqllsg` live 16:53):
  F-05 404 envelope (`ErrorsController` + catch-all), F-06 effective-time
  ordering/display, F-07 chips now show configured names (decision: docs win
  over the N/R pen letters — revert if Sonic prefers N/R), F-08 "today" in
  `settings.timezone`, F-09 two-row legend, F-10 mmol/L y axis + dated x axis.
  APK **0.6.1** (versionCode 7) built and installed; tests 69 runs / 237
  assertions. Live verified: 404 JSON envelope, `/up`, settings, report.
- **Batch 3 done** (`e833d04`, deploy `dep-dbqfff142hec73cvkf30` live 17:19):
  F-11 HC status is an 11 sp sentence; F-12 missing scopes are named + "Open
  settings"; F-13 noindex + `REPORT_TOKEN` (enabled on Render, value in
  `.env.local`); F-14 `/doses?days=N` default `DOSES_HISTORY_DAYS=10`.
  Tests 76/257. APK **0.6.2** built but **not installed** — the phone dropped
  off USB. Reinstall + check the HC line and the missing-permission state when
  it's back.
- **State file lives only in this checkout** (untracked); the agent worktree
  cannot see it. Consider committing `docs/STATE.md`, ADR-004 and spec-v2 so
  every worktree/session shares them.
- Next: F-16 (HC kcal double count), F-15 (TIR flags), F-18 (clock), F-19
  (form state on rejection), then F-17/F-20/F-23…F-25.

## 2026-11-07 · Pivot accepted: hub of record

- `docs/ADR-004-hub-of-record.md` **accepted**. AGENTS.md vision rewritten:
  A1See is now "the permanent record of a diabetic's glucose life", not a
  personal insulin tracker. Multi-tenant replaces the no-auth contract;
  "never read a sensor radio" and "never advise" are now contract rules.
- `docs/spec-v2.md` accepted (slices 8–15). Slice 8 (identity/scoping) is
  the gate and is not started.
- Owner decisions: **device pairing, no email** · **persona física** for the
  beta · **five hand-held users** · **polish after live-share** · **narrow
  web** (record + report only).
- Consequence: the beta is a *concierge* operation — manual onboarding,
  imports may be run by Sonic, public funnel deferred to slice 15.
- Three risks recorded with mitigations (ADR-004 §7): no email → breach
  notification needs an explicit channel; persona física → personal
  liability + published domicile, entity before open signup; device pairing
  → lost phone needs the printed recovery code.
- Parked: photo nutrition (`docs/backlog/photo-nutrition.md`). Cheapest
  precursor still open — read `protein`/`fat` from HC `NutritionRecord`.
- Next: slice 8 migration plan + backup of the live Render database before
  any schema change.

## 2026-10-21 · Presentación PPTX v4 — enlace real del repo en slide 9

- Slide 9: placeholder reemplazado por https://github.com/davidzu/a1c;
  añadidos Twitter/X (x.com/davidzu) y LinkedIn
  (linkedin.com/in/david-zuniga-carmona) arriba de la lista técnica.
  Deck final listo en `docs/presentation/A1See-charla.pptx`.

## 2026-10-21 · Presentación PPTX v3 — slide 7 con captura web real del /report

- La captura móvil del /report era ilegible en slide. Tomé screenshot
  real de la página web: backend en :3000 con BD `a1see_present_development`,
  Playwright viewport 1400×900, fullpage → crop superior (0–950 px:
  AGP metrics cards + TIR bar + curva AGP 24 h).
- Guardada como `docs/talk-screenshots/slice-7-report/04-report-web-top.png`;
  slide 7 la usa grande (6.7×4.9 in) con bullets reducidos a la izquierda.
- Limpieza: rails detenido, `report-full.png` temporal eliminado.

## 2026-10-21 · Presentación PPTX v2 (correcciones de Sonic)

- Correcciones aplicadas y verificadas en render: slide 1 ahora es sobre
  David (CV 2026: `/home/sonic/Documents/Work/David_Zuniga_CV_2026.docx`,
  convertido a texto con libreoffice) — sin captura de pantalla; slides
  2–7 con UNA sola captura grande (5.6×5.5 in, marco magenta); slide 3
  ahora es tabla de agentes (Orquestador=GLM/opencode, Constructor=Grok,
  Analista/revisor=DeepSeek, Subagentes) — roles editables, confirmar
  con Sonic que el rol de DeepSeek refleja su uso real; slide 4 objetivo
  corregido (métricas que sobrevivan distintos medidores y sus apps);
  slide 5 sin la línea de "contexto llega o no llega", desarrollo
  incremental expandido; slide 6 con más detalle de design-system +
  skills de diseño; slide 7 A1C constante entre laboratorio y CGM;
  slide 8 con la idea open source (plugins de medidores/ejercicio/
  comidas). Slide 9 sin cambios.
- Archivo: `docs/presentation/A1See-charla.pptx` (script regenerador en
  /tmp/opencode/build_deck.py — copiarlo a docs/presentation/ si se
  quiere persistente).

## 2026-10-21 · Presentación PPTX de la charla (vía LibreOffice, no Miro)

- Sonic dejó el tablero de Miro; pidió una presentación normal. Elegimos
  PPTX editable en LibreOffice Impress (generado con python-pptx en venv
  temporal /tmp/opencode/pptx-venv, script /tmp/opencode/build_deck.py).
- Archivo: `docs/presentation/A1See-charla.pptx` — 9 slides, 16:9,
  tema oscuro A1See (negro #0D0D0F + acento magenta), todo en español:
  1 Intro (quién soy + app) · 2 Motivación · 3 Orquestación de agentes
  (captura slice-2/3) · 4 Datos en línea (curva glucosa slice-5) ·
  5 Todos los datos (slice-8 curva+barras) · 6 UI/UX rework + skills
  (2 capturas slice-8) · 7 Dashboard doctor + A1C permanente
  (slice-7 report) · 8 Producción/seguridad/futuro · 9 Q&A + enlaces.
- Pendiente para Sonic: reemplazar el placeholder "github.com/…/A1See"
  del slide 9 por la URL real del repo, y revisar redacción a su gusto.
- Render verificado: PDF de prueba en /tmp/opencode (todas las slides OK).

## 2026-10-21 · Capturas del rework del LogScreen (slice-8) para la charla

- Faltaban capturas entre slice-7 (2026-10-12) y HEAD: el rework de
  LogScreen (`6647e35`, design-system metric colors + A1C:Total) nunca
  se había fotografiado.
- Método: backend actual en :3000 con BD dedicada
  `a1see_present_development` (DATABASE_URL override, migrada + sembrada
  vía rails runner: settings NovoRapid/Ryzodeg, 6 dosis en 3 días,
  curva CGM 24 h a 5 min, 2 sesiones HC, 3 meals HC, 3 A1C labs),
  parche `usesCleartextTraffic` en el manifest (revertido después),
  APK `localDebug`, emulador pixel_9_api36, `adb exec-out screencap`.
- Resultado en `docs/talk-screenshots/slice-8-rework/` (5 PNG):
  01 log completo (metric cards glucosa/última insulina/on board +
  fila de entrada de una línea + A1C:Total 6.7), 02 curva 24 h con
  leyenda de métricas + barras del día (Kcal/Exercise/Fast/Slow/Carbs)
  + dosis recientes, 03 formulario en acción (8 u, chip N activo,
  teclado), 04 Generals (timezone + last A1C), 05 Insulins
  (NovoRapid/Ryzodeg).
- Nota: 04 y 05 son pantallas de config simples — candidatas a
  descarte al elegir las finales.
- Limpieza: backend y emulador detenidos; manifest revertido; BD
  `a1see_present_development` se conserva (patrón sliceN).
- Tablero Miro "A1See — El recorrido del héroe" creado con el arco de
  9 etapas; las capturas se subieron a mano al board.

## 2026-10-12 · Screenshots históricos para la charla del congreso

- Generadas capturas de las versiones anteriores de la app para la charla
  "Construyendo Apps con IA: lo que aprendí (y lo que me equivoqué)".
- Método: git worktrees temporales por tag (`slice-2-log` … `slice-7-report`),
  APK `localDebug` por slice (con parche `usesCleartextTraffic` en el manifest
  del worktree — los slices antiguos no lo tenían), backend de la era corriendo
  en :3000 con BD dedicada (`a1see_sliceN_development`), datos sembrados vía
  curl (dosis, settings NovoRapid/Tresiba, curva CGM 8 h, Health Connect),
  emulador pixel_9_api36 y `adb exec-out screencap`.
- Resultado en `docs/talk-screenshots/`:
  - `slice-2-3-log-config/` — estado vacío, formulario en acción, log con
    datos y grafo, tabs Insulins/Generals sin y con configuración (7 PNG).
    Nota: en esta era la app se llamaba "A1C" (rebrand a A1See fue slice-4).
  - `slice-4-polish/` — subtítulo A1C/kg, nombres en dosis, leyenda (1 PNG).
  - `slice-5-glucose/` — glucosa en vivo "6.4 mmol/L · now" + curva 24 h
    con banda target (2 PNG).
  - `slice-7-report/` — dashboard `/report` del doctor (AGP, TIR 87.6%,
    GMI 6.6%, tabla diaria, A1C history) + app actual con barras de 3 días
    y marcadores food/exercise (3 PNG).
- slice-6 fue backend-only (sin cambios en android/), no tiene UI propia.
- Hallazgo útil para la charla: el error "CLEARTEXT communication to
  10.0.2.2 not permitted" del slice-2 se capturó — buena imagen de
  "lección aprendida".
- Limpieza: worktrees y servidores eliminados; emulador apagado.
- Pendiente: elegir las capturas finales por slide del recorrido del héroe.

## Backlog (fix later)

- **Juggluco migration — DONE 2026-10-16.** Installed Juggluco 11.5.0 arm64
  (11.4.1 was superseded on juggluco.nl), scanned the new GS1's data matrix
  (LT2603YGGF, ends Sun 2026-11-08 12:27), force-stopped SugarJoy+
  (kept installed as fallback), granted all permissions + battery-optimization
  exemption via `adb install -g` + `deviceidle whitelist`. One hiccup: xDrip
  showed "Signal Missed" for ~16 h until the **Eversense broadcast** was
  enabled in Juggluco (Settings → Exchange data) — that toggle was the
  missing link. Chain verified live: Juggluco → xDrip (640G/EverSense) →
  POST /entries → API (fresh readings within minutes). Note: ingest cadence
  is 5 min (xDrip side) even though Juggluco captures at 1 min. Judge the
  switch by A1See's glucose card staleness over a few days of wear.
  Rollback: clear left menu → Sensor → Use Bluetooth in Juggluco,
  reopen SugarJoy+.
- **Log screen: pull-to-refresh.** The app only fetches on ON_RESUME; add a
  pull-to-refresh on the Log screen so a manual sync is possible from the
  UI. (From the sync-levers discussion, 2026-10-14 — auto-refresh and a
  sync-state chip were considered and deferred.)
- **Daily totals graph: slow-insulin bar readability.** The orange fast bar
  in front of the blue slow bar loses contrast — the blue needs to be
  darker (or the composition rethought: side-by-side instead of
  overlaid/foregrounded). Report from the phone after the design-system
  rework install, 2026-10-14.
- **Photo nutrition estimation — PARKED 2026-11-06.** Full design kept in
  `docs/backlog/photo-nutrition.md`: two-pass vision+grams flow, jsonb
  `items` + per-100 g arithmetic on the server, backend-proxied model call
  behind a secret, no photo storage. Deferred because it has a per-use cost
  and a third-party data transfer, and does not address the retention
  problem behind the public "health hub" pivot. Cheap precursor still
  stands: read `protein`/`fat` from Health Connect `NutritionRecord` — A1See
  currently discards them and Zepp already writes them.
