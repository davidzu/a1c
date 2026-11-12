# A1See — session state

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
