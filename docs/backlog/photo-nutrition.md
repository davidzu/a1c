# Backlog — Photo nutrition estimation (parked)

- Status: **Parked**, not planned. No work started.
- Parked on: 2026-11-06
- Origin: product-direction discussion (A1See as a public health-data hub
  for Mexican diabetics). Photo→macros was evaluated as a candidate feature
  and deferred: it costs money per use, sends user images to a third party
  (a data transfer under the LFPDPPP), and does not serve the retention
  problem that the pivot is about.
- This document is the full design so the decision does not have to be
  re-derived later. If it is reopened, start with "Preconditions" below.

---

## 1. What it is

Point the camera at a plate, get carbs + kcal + protein + fat, adjust the
grams per ingredient, save it as a `nutrition_entry` that lands on the
glucose curve and the doctor report.

The reference behaviour (Zepp's food log, Cronometer, Calorie Mama) is:
photo → estimate → **one editable confirmation screen** → saved. The
editable confirmation screen is the product; a raw AI guess is not.

## 2. Why it was parked

1. **Cost per use.** ~US$0.001–0.002 per photo on a cheap vision model —
   small per user, unbounded in aggregate, and it is the only feature in
   A1See with a marginal cost per interaction. The current product is free
   to run.
2. **It is a data transfer.** Uploading a photo to Google/OpenAI is a
   remisión/transferencia to a third party under the LFPDPPP (2025). Food
   photos are sensitive-ish (home, people, routines) and health data is
   sensitive personal data. It requires disclosure in the aviso de
   privacidad and, arguably, specific consent.
3. **It does not fix retention.** The pivot's core pain is *losing history
   when you change sensors*. Photo nutrition is a new data source, not a
   continuity mechanism. It would be the 4th thing to build, not the 1st.
4. **Health Connect already delivers macros.** Zepp logs photo meals with
   carbs, protein, fat and kcal into Health Connect. A1See currently throws
   away protein and fat. That is ~15 lines of work and gets 80% of the
   value for 0% of the cost. See "Cheap precursor" below.

## 3. Cheap precursor (do this regardless)

- `HealthConnectReader` maps only `totalCarbohydrate` + `energy`. Add
  `protein`, `totalFat` (and optionally `dietaryFiber`) from
  `NutritionRecord`.
- Requires `protein_g`, `fat_g` columns on `nutrition_entries` — the same
  migration the AI feature would need.
- Delivers macros for every Zepp/Cronometer/Lose It! meal, today, for free.

## 4. Decisions already reached (if reopened, honour these)

| Question | Decision | Why |
|---|---|---|
| Where does the model call run? | **Rails**, not the APK | Key stays in env; prompt/model swap without an APK; cache + spend cap; matches "Rails owns all rules" |
| Is the endpoint authenticated? | **Yes** — `AI_ESTIMATE_SECRET` header + Rails 8 `rate_limit` + daily counter | The API is public; an open image endpoint is a credit-drain |
| Are photos stored? | **No** | No Active Storage / no disk by ADR-001; food photos are the most revealing images a user owns; the item list is the useful audit trail, not the pixels |
| Food data model? | `items` **jsonb** on `nutrition_entries` + denormalized totals | One read-back per meal, totals stay in columns for `/days` and `/report`. No `foods` table |
| Who does the arithmetic? | **Server**, client mirrors it for instant feedback | Editing grams must be free and instant; the server recomputes totals from `items` on save so they can never disagree |
| Does it write to Health Connect? | **No** | ADR-003 keeps HC read-only; a write would be re-ingested under a different `client_id` and double-count the meal |
| Second AI pass? | Only on **low confidence** or **user-corrected item** | Never to re-do arithmetic from grams |

**Model choice guidance:** a Flash-Lite class model for pass 1, escalate to a
Flash/Pro class model when any item has `confidence < 0.6` or the plate is a
composite dish. Pin model IDs explicitly — provider aliases drift and one
provider's cheap tier was scheduled to reroute in Dec 2026.

## 5. Accuracy strategy (the part that makes it trustworthy)

**Never ask the model to do arithmetic on user-supplied grams.** Ask for
two things per item: an estimated weight *and* a per-100 g nutrition
profile. Totals = `Σ (grams/100) × per_100g`, computed in Ruby. Then:

- Editing 180 g → 140 g is instant, free, and offline.
- The server is authoritative and consistent.
- A correction (rice → quinoa) is the only thing that costs another call.

Portion presets beat free-text grams for low-friction corrections
("tortilla: 25 / 30 / 40 g").

### Evidence the user's instinct was right

- GPT-4o study (2026): image-only → image + ingredient list with amounts
  moved energy R² from **0.591 → 0.941**. Ingredient quantities are the
  dominant lever, not prompt wording.
- 40-model VLM benchmark (*Scientific Reports*, 2026): **model architecture
  explains 99.6%** of variance; multi-angle photos gave **no** benefit
  (p = 0.182); prompt engineering was not significant; good phone photos
  beat lab photos (RMSLE 0.548 vs 0.616).
- ChatGPT-5 cross-source study (2025): MAE drops as non-visual context is
  added; removing the image still hurts, so vision matters but is not
  sufficient.
- Realistic floors, image-only: **kcal MAPE ~30–40%**, carbs **MAE ~9 g**
  (GPT-5-class) vs ~6 g for a purpose-built system. Best published VLM
  calorie MAE on Nutrition5k: **~81 kcal** (CCC 0.767).
- Cost benchmark: **~US$0.59 per 1,000 images** for the best
  cost/accuracy Flash-Lite point.

**Safety line:** show carbs, never suggest a dose. A1See "shows what
happened, it does not advise" (ADR-003). A wrong carb estimate is context;
a wrong suggestion is a medical device.

## 6. Schema (when it happens)

```ruby
# add_photo_estimate_fields_to_nutrition_entries
t.decimal :protein_g, precision: 9, scale: 2
t.decimal :fat_g,     precision: 9, scale: 2
t.decimal :weight_g,  precision: 9, scale: 2   # total edible weight
t.jsonb   :items,     default: [], null: false # the accepted/edited item list
t.jsonb   :ai_meta,   default: {}              # model, prompt_version, latency
```

```json
[{"name":"arroz blanco cocido","grams":180,
  "per_100g":{"kcal":130,"carbs_g":28.2,"protein_g":2.7,"fat_g":0.3},
  "confidence":0.82,"assumption":null}]
```

Totals stay authoritative in `carbs_g`, `calories_kcal`, `protein_g`,
`fat_g`, `weight_g`. `items` is the snapshot, not the source of truth for
charts.

## 7. API (when it happens)

```
POST /api/v1/nutrition/estimate      # does not persist
  multipart: image, hint?, items?    # items => refinement pass, image optional
  header:    X-A1See-Secret
→ { "estimate": { "model": "...", "items": [...], "totals": {...},
                  "assumptions": ["tortillas counted as 2"],
                  "warnings": ["low confidence: salsa"] } }

POST /api/v1/nutrition               # existing endpoint, extended
  { items: [...], taken_at, meal_type, client_id }  # server recomputes totals
```

- Service object `NutritionEstimator` with a `client:` seam so tests inject
  a fake — no WebMock, keeps the ADR gem allowlist intact.
- `Net::HTTP` is enough; one outbound call does not justify a new gem.
- Cache the estimate by SHA-256 of the image for 24 h (double taps free).
- Timeouts: 15 s server, 20 s client, graceful 504.

## 8. Android flow (when it happens)

- `ActivityResultContracts.TakePicture` + `FileProvider` — no camera
  library, no `CAMERA` permission (the system camera app owns it).
- Downscale to ~1024 px long edge, JPEG q80, **rotate by EXIF** first.
  Target 150–250 KB. Image quality matters more than model size per the
  benchmark above — do not over-compress.
- Review sheet: item rows with grams + presets, per-item macros, confidence
  chip, editable meal type (inferred from local time).
- Save through the existing `client_id` idempotent path.
- Offline: do not queue photos. Keep the photo in app-private cache, resume
  the estimate when online, and only enter the outbox after confirmation.

## 9. Failure modes to plan for

- EXIF rotation → sideways plate → worse estimate.
- HEIC from some camera apps; camera unavailable on emulator (fixture).
- Render cold start: first estimate can take 20 s. Show progress.
- Duplicate meal: an HC meal already exists within ±30 min. Warn, do not
  silently double-count.
- `taken_at` = capture time, not save time (offline day bucketing).
- Cost abuse if the secret leaks → rate limit + daily cap + alert.
- Provider model deprecation/rerouting → pinned IDs, one fallback.

## 10. Slice plan (if reopened)

| Slice | Delivers | Est. |
|---|---|---|
| A — macros from HC | protein/fat columns; reader uploads them | ½ day |
| B — estimate endpoint | `curl -F image=@lunch.jpg` returns items + macros on Render | 1–1½ days |
| C — camera + review sheet | photo → edited grams → saved meal → dot on the curve | 3–4 days |
| D — accuracy loop | escalation pass, duplicate detection, 25-photo eval script | 2 days |

Total ~1 focused week. Slice D includes a small weighed-meal eval set that
prints carb/kcal MAE per prompt version — that is what turns "cool demo"
into "a number I trust".

## 11. Preconditions before reopening

1. Auth + per-user scoping shipped (a public, unauthenticated image endpoint
   is unthinkable multi-tenant).
2. Aviso de privacidad discloses the third-party AI transfer, or the call
   moves to a provider with an adequate data-processing agreement.
3. A per-user spend cap exists, or the feature is limited/free-tiered.
4. The health-data hub work is stable enough that a failed estimate does
   not become a support incident.

## 12. Open questions

- Do users weigh their food? If not, portion presets dominate and free-text
  grams is a power-user path.
- Is the goal to *add* meals A1See lacks, or to *correct* meals Zepp already
  logged? That decides whether the duplicate rule is a warning or a merge.
- If the product becomes multi-user, does photo nutrition stay free
  (acquisition) or gate the paid tier (cost recovery)?
