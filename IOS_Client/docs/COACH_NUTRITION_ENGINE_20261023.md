# Phase5C Nutrition Engine — pre-edit audit / approved scope

2026-10-23. ENGINE ONLY. No Phase5D UI, push/deploy/remote data or migration. Codex executes: scientific/numerical/security logic, not visual work. Supabase skill read and applied to local ownership audit. No delegated work needed/claimed.

## Audit BEFORE source edits
- Existing `ClientNutritionGenerator`: Mifflin/activity factors, cut−10%/bulk+5%, fixed25/50/25 macros, category-based food selection, bounded discrete portion optimizer, loose15%energy/35%macro tolerances. Existing `ClientNutritionCreationAnswers`, `ClientNutritionTarget`, `ClientNutritionDraft` and normal personal plan payload reused, not duplicated.
- Manual/guided existing wizard, picker, copy meal/day and local-first cache must stay byte-identical. Food calculator uses stored kcal, per100g × grams/100; pieces require trustworthy gram weight. Plan supports1/7days,3–6meals; no automatic ON/OFF/Reverse cycling.
- iOS reads global `food_references` only,500row cache/60search. It does NOT call CREA/USDA/OFF APIs. Current projection drops external IDs/state/provenance and decodes only grams_per_piece metadata. Source/provider name alone does NOT establish dietary/allergen safety. No automatic admission until explicit reviewed provenance/safety/portion metadata is available. Manual catalog/search preserved.
- Desktop read-only audit: official USDA import migrations retain real external IDs/sourceURLs/dataset, CREA/global provider/cache architecture and external USDA/OFF providers exist. OFF fetch lacks allergen review; categories alone are not evidence of vegan/allergen compatibility. No source values/IDs invented or copied into production. Real API/catalog integration NOT RUN.
- Existing profile has biologicalSex but no complete reliable age/height/weight/activity/health fields; only answers currently hold them. New pure typed contract accepts reliable inputs;5D must collect only missing fields. Never infer sex or diagnoses.
- Desktop energyEstimate.ts matches simplified Mifflin10/6.25/5/+5/−161 and factors1.2/1.375/1.55/1.725. Retain/version factors as inherited PRODUCT heuristics, not EFSA validated PAL. Activity evidence must include daily occupation, not only workout count.
- Ownership: UI/session standalone policy exists; nutrition repository currently lacks fresh profile/link preflight. Local20261004105732 standalone restriction migration exists, historical production NOT APPLIED/current NOT VERIFIED. RLS not remotely inspected (prior permission denial not bypassed). Gate OPEN; no production changes authorized.
- Existing read-back compares days/source/target/answers. Extend Nutrition ONLY with optional metadata preservation and strict generated-plan validation before local/server writes. Existing archive semantics/history/manual paths preserved. Fresh repository ownership preflight supplements, NEVER replaces, RLS.

## Ordered roadmap
1. Freeze current source/tests, eligibility/profile + versioned RMR/activity/goal/macros (pure).
2. Strict real-food admission/provenance/preferences + deterministic role templates/portion solver.
3. Existing generator integration + strict independent validator/signature + optional payload metadata; local service/save boundary only.
4. N01–N16 and arithmetic/safety/tamper tests; preservation/static checks; Mac backlog/handoff. STOP before5D.

## Scientific references (checked2026-10-23)
- Mifflin1990 simplified equations: https://pubmed.ncbi.nlm.nih.gov/2305711/ . Estimate, not measured RMR.
- EFSA0.83g/kg adult PRI: https://www.efsa.europa.eu/en/press/news/120209 . Population reference, not sports target.
- EFSA fat20–35%E/carbs45–60%E: https://www.efsa.europa.eu/sites/default/files/2017_09_DRVs_summary_report.pdf . General reference intervals.
- ISSN healthy exercising adults1.4–2g/kg: https://pmc.ncbi.nlm.nih.gov/articles/PMC5477153/ . Product targets within this range, not exact optimum.
- Conservative surplus rationale: https://pmc.ncbi.nlm.nih.gov/articles/PMC10620361/ . Product retains+5%, not universal recommendation.
- NICE low-energy800–1200 and<800 specialist-only: https://www.nice.org.uk/guidance/ng246/chapter/Physical-activity-and-diet . Existing1400lower/4500upper product envelope retained; NOT a guarantee of individual safety. No clinical treatment.
- Official Supabase SDK session: https://supabase.com/docs/reference/swift/auth-getsession . Changelog.md fetch unsupported-content-type; no SDK dependency/API upgrade.

## Product rules / boundary
Moderate−10%cut/+5%bulk/0maintenance retained. Healthy18–78adult estimator envelope; bodyweight35–120kg/height130–220cm is a deliberately narrow unsupported-extremes guard, NOT diagnosis or adjusted-weight medicine. Protein1.0g/kg nonexercising (above EFSA PRI, product choice);1.6maintenance/1.8gain/2.0loss exercising;fat30%E;carbs remaining4/4/9. Protein fraction≤35%E product guard. No macros claimed micronutrient complete.3–6meals/1or7days; equal protein share and inherited energy distribution, no physiologic superiority claim. Quantized per-food reviewed bounds required, no universal category portion guesses. Daily kcal±10%,P/C/F±20%;meal kcal±25%,protein±35%;fat actual20–35%E;all explicit engineering tolerances. Fit failure never accepted. Safetyfloor enforced on actual food totals too.

## BACKEND RELEASE GATE
OPEN — current RLS/migration/catalog review metadata and real save/reopen NOT VERIFIED; no remote writes. Do not release or integrate5D until actual authorized catalog metadata source, current authorization, real API/catalog and native tests are verified. Source-only generator can fail closed with current unreviewed catalog.

## Final source implementation —2026-10-23
PHASE:5C Nutrition Engine. STATUS:PARTIAL overall; source/hash checks PASS. Engine code present,NOT Swift-compiled/behaviorally accepted on this Windows host. Phase5D NOT STARTED.

### Eligibility / energy / macros
Typed owner gate runs before profile calculations:unauthenticated/Trainer-connected denied;history preserved. Explicit adult acknowledgement and No declarations for pregnancy/breastfeeding,eating-disorder risk and clinical nutrition required;unknowns reject.18–78,35–120kg,130–220cm product applicability. Normalized mass/height ratio outside15–40 unsupported for automatic generation;pre-existing Cut guard below18.5 retained. These are conservative PRODUCT applicability checks,not a diagnosis or adjusted-weight treatment. Professional assessment rather than fabricated prescriptions.

Existing profile offers biologicalSex but not complete anthropometrics/activity/health evidence. New optional coachProfile is authoritative;5D must bridge/reuse only reliable data. Legacy estimate-only API remains for compatibility:existing explicit activity selection,shared RMR/allocation,conservative1g/kg general-product estimate,NO inferred occupation/workout-frequency/health evidence. Old owner-less generate API explicitly rejects until5D uses the actual-session adapter. No fabricated auth/health answers allow generation. This is intentionally NOT a shippable UI flow yet.

Mifflin simplified coefficients unchanged;unrounded RMR and maintenance in metadata,legacy display estimates round once,calorie target quantized once to10kcal. Daily occupation+exercise category determines inherited factor,not workouts alone. Reliable optional steps retained as evidence,not added again or treated as measured expenditure.−10%/+5%/0goal rules retained.1400–4500target and ACTUAL-food energy envelope,no silent clamp.

Protein uses actual weight within the narrow applicability envelope:1.0g/kg nonexercising PRODUCT target (distinct from EFSA0.83PRI);sport1.6maintenance/1.8gain/2.0cut. Fat30%E;carbs residual4/4/9. Target fat20–35%E/protein≤35%E/all positive/Atwater error≤0.000001. Actual day protein must also stay1.4–2.0g/kg sport or0.83–1.2general;20%fit tolerance cannot expand this range. Carbs need not blindly satisfy the general45–60%E population interval. No promise of physiologic optimum.

### Food admission and real-source boundary
CREA/USDA/OFF actual integrations EXIST in Desktop/backend source;no actual API call or live cache query performed this phase. iOS retains the same global-only food_references search/cache/limits;projection now also reads existing external_food_id/source_url/updated_at columns. Optional metadata.nutrition_coach_review is decoded lossily:missing/malformed evidence does not break manual search and is NEVER upgraded to trusted evidence.

Review must match actual canonical UUID,provider,externalID,sourceURL,cache revision,original serving amount/unit;it retains dataset/cache/review reference,food state,role,allowed meal occasions,patterns,complete14-allergen/two-intolerance review,contains/traces and per-food portion bounds. Source names/categories/names alone insufficient. Complete finite nonnegative P/C/F/kcal required;large stored-kcal vs4/4/9 contradictions excluded(25%or20kcal data-quality allowance,not replacement kcal). Conflicting canonical/provider IDs quarantined;no blind cross-source merge. Stored provider kcal is authoritative for food/meal/day totals.

Review producer must bind cacheRevision to the exact stored revision/serialized updated_at atomically;this is NOT a client-generated guessed timestamp. Any trigger/review serialization mismatch invalidates review and remains a real-catalog integration gate. No freshness exception introduced to make incomplete records pass.

Automatic admission FAILS CLOSED with legacy rows lacking this review. No review records,foodIDs,nutrient values or dietary/allergen absence claims were fabricated/seeded remotely. Test fixtures are SYNTHETIC,test-target-only with example.test URLs and synthetic IDs—not real USDA/CREA evidence. Actual reviewed catalog availability remains NOT VERIFIED. The upstream review-population workflow/provenance approval needs a separately authorized data task;5C does NOT create production metadata.

Hard allergies include known traces;intolerance/pattern/excluded UUID checks repeated in strict validation. Known milk/egg/fish ingredients cannot be marked vegan;fish/shellfish cannot be vegetarian. Unknown safety coverage rejects even if some other fields are known. Not a certification of allergen absence;reviewed source truth must be maintained.

### Meals / portions / variety
Existing3–6meal taxonomy and1/7day plan used. Stable explicit referenceWeekday for single-day plans;no timestamp-dependent structure. Same daily targets,NO ON/OFF/Reverse cycling. Inherited energy shares;equal protein share (product convenience,not medical optimum).

Main/breakfast4ingredients:protein+carb+vegetable/fruit+fat. Snacks3:protein+fruit+fat. Each food must have verified allowedMeal occasion and role;no arbitrary substring food inference. Least-used candidates within preferred source rotate deterministically;6bounded attempts prefer CREA then allow USDA/OFF fallback. Variation retains all inputs/constraints;fresh persistence UUID/time only.

Per-food reviewed min/max/step REQUIRED;no universal arbitrary100g. Finite positive bounds≤1000g and≤1000lattice points;gram foods5/10g steps or real whole-piece mass.40continuous coordinate sweeps→quantize→≤160discrete repair→≤160whole-day repair;no heavy optimizer dependency. Stored-food nutrient×grams/100. Quantization recalculated,never hidden in UI rounding. Global optimum not guaranteed;infeasible/local-fit failure explicitly rejects.

Daily kcal±10%,P/C/F±20%;meal kcal±25%,protein±35%;actual daily fat20–35%E and energy/protein hard limits also required. These are ENGINEERING tolerances,not scientific intake recommendations. Source/version/inputs/raw estimates/adjustment/targets/tolerances/food fingerprint/rationale/signature stored. SHA256 canonical sorted-set + ordered-plan signature excludes generated instance UUIDs/timestamps. Tolerances are versioned and independently revalidated.

### Strict validator / normal plan / save boundary
Existing ClientPersonalNutritionPlan,ClientPersonalMeal/Day/Food and source.guided reused. Only optional generationMetadata/nutritionEvidence/coachProfile appended;old manual/history payloads remain decodable. No parallel database/table/storage source value. JSON round-trip test is NOT real persistence proof.

Independent validation recomputes eligibility,energy,targets,source admission,fingerprint,food nutrient/evidence snapshots,all hard preferences,roles/occasions,quantities/lattice/pieces,day/meal counts,duplicate IDs,meal/day totals and metadata/signature. Invalid generated result never returned;strict-invalid new coach payload blocked BEFORE local stage and again in repository before upsert. Both existing session save entry points retain manual/history semantics;full read-back additionally compares generationMetadata.

Repository fresh Auth user/profile activeClient/no linkedClient preflight added in Nutrition scope,not a new auth persistence layer. Existing atomic archive+new-plan upsert retained. RLS remains essential against direct REST and link-vs-save races;preflight is NOT server enforcement proof. Historical snapshots remain readable;new coach edits/archives can reject if reviewed catalog fingerprint has changed—5D must handle explicit revalidation/regeneration,not silently rewrite history.

## Files / exact preservation
Modified existing:Core/ClientNutritionGenerator.swift(upgrade);ClientNutritionCreation.swift(optional profile/evidence normalization);ClientPersonalContent.swift(three optional Nutrition fields);ClientPersonalRepository.swift(Nutrition-only preflight/strict save/review projection);ClientSessionStore.swift(Nutrition-only two guards/helper/readback).

Created Core:ClientNutritionCoachContract.swift,ClientNutritionCoachEnergy.swift,ClientNutritionFoodPolicy.swift,ClientNutritionPortionSolver.swift,ClientNutritionPlanValidator.swift,ClientNutritionCoachService.swift. New tests:ClientNutritionCoachFixtures.swift,ClientNutritionCoachEngineTests.swift.

Scripts:validate-nutrition-coach.ps1,nutrition-checkpoint-source.ps1 NEW;previous four UI/Workout validators gain explicit-NutritionEngine stage;validate-client-ios.ps1 replaces two obsolete old-generator assertions with actual new contract/energy/strict-validator checks. All old baseline JSON files unchanged.

73-source pre5C baseline:68otherexisting app files byte-identical;four shared/creation files reproduce pre5C entire-file hashes after reversing ONLY listed Nutrition additions;only existing NutritionGenerator wholly upgraded. Workout engine/CASE01–CASE12/fixtures/remaining17native suites exact unchanged. One old Nutrition generation test changed to require authenticated typed context;all other old Nutrition arithmetic/copy/decode tests exact unchanged after masking that method. New XCTest test definitions:30,total264,ALL NOT RUN.

Historical Phase1/2/3+4 frozen files predate approved Workout5A/5B/UI edits. New stage explicitly checks those five already-approved paths against pre5C checkpoint,not stale hashes;SessionStorePhase34 fragment similarly replaced by stronger whole-file pre5C preservation. Literal inventory after approved WorkoutUI is48,not historic55;5C UI is proven byte-identical. No silent baseline reset or source behavior PASS.

## Test matrix — definitions only, NO XCTest execution
| Case | Defined scenario/assertions | Native result |
|---|---|---|
|N01|Adult male,maintenance,4meals,knownRMR,strict valid|NOT RUN|
|N02|Adult female,maintenance,3meals,strict valid|NOT RUN|
|N03|Resistance/muscle gain,+5%/1.8gkg|NOT RUN|
|N04|Female resistance/cut,2gkg,strict valid|NOT RUN|
|N05|Vegetarian compatible-source meals|NOT RUN|
|N06|Vegan gain with compatible synthetic catalogue|NOT RUN|
|N07|Lactose intolerance excludes incompatible milk row|NOT RUN|
|N08|Peanut allergy includes trace exclusion|NOT RUN|
|N09|Multiple excluded IDs never selected|NOT RUN|
|N10|Unsafe low target explicit error,no clamp|NOT RUN|
|N11|Trainer-managed denial before profile/calculation|NOT RUN|
|N12|Missing anthropometrics denied|NOT RUN|
|N13|Repeated/reversed catalogue identical signature,newinstanceIDs|NOT RUN|
|N14|Missingmacro not admitted aszero|NOT RUN|
|N15|Empty/insufficient compatible catalogue explicit failure|NOT RUN|
|N16|All7days recomputed within strict tolerances|NOT RUN|

Additional14native definitions:male/female RMR and rounding;invalid RMR inputs;clinical/missing/minor gates;occupational activity evidence;macro4/4/9 arithmetic;exact portions;unknown/conflicting review;tamper quantities/metadata/nutrients/target;JSON roundtrip/legacy field;5/6meals;owner-less API denial;prior low-relative-weightCut guard;whole-piece solver;contradictory vegan/milk review.

A separate ephemeral JS arithmetic prototype exercised the coordinate-fit approach for six synthetic energy/meal-count profiles to catch arithmetic design errors. This was NOT Swift execution,NOT N01–N16 PASS and NOT evidence of real foods/persistence;not included in native/static test counts.

## Native / backend / release status

Final fresh SOURCE/HASH results (overlapping checks,NOT native totals):
- Nutrition169/169;foundation110/110;Phase2 75/75;Phase3+4 86/86;WorkoutCoachUI212/212;fullapp202/202.
- Git diff--check/scopednewsource+tests+scripts+report whitespace PASS;stagedNONE.
- Canonical Windows regression command: pwsh -NoProfile -File IOS_Client/scripts/validate-nutrition-coach.ps1 -AllStatic.
- The-NutritionEngine stage is explicit;old baselines unchanged. No scope waiver for new Workout/UI edits.
Swift compile:XCODE NOT AVAILABLE on Windows;XCTest264definitions:NOT RUN;Simulator/real generated meal visuals/VoiceOver/performance:NOT RUN. Real CREA/USDA/OFF APIs:NOT RUN. Actual catalog review rows,ownership/RLS,server save/reopen:NOT RUN. Production current migration state NOT VERIFIED. BACKEND RELEASE GATE:OPEN.

DATABASE:NONE. MIGRATIONS CREATED/APPLIED LOCAL/APPLIED PRODUCTION:NONE. Remote queries/writes/functions/deploy:NONE. Git commit/push/tag/release:NONE. No Desktop/Trainer/bodymap/UI sources changed. main49e67c8,31pre-existing tracked dirty files retained,stagedNONE. Current task changes mostly pre-existing untracked files/new files;do not infer scope from Git stat alone.

Known limitations:healthy-adult/macronutrient planner only,not micronutrient adequacy,medical nutrition or allergen certification. Limited role templates/curated food data may fail;not a universal meal generator. Existing old wizard cannot safely call5C until authorized5D;manual creation/history stay unchanged. Catalog revision changes require explicit new validation,not history rewrite. No native acceptance or RLS release claim.

NEXT EXACT STEP:On Mac inspect actual scheme via xcodebuild-list for this exact worktree;build/test264definitions and real cache/payload acceptance per MAC_ACCEPTANCE_BACKLOG. With separate authorization,verify current real reviewed catalog and RLS/migration state WITHOUT applying anything blindly. Phase5D Nutrition UI ONLY after NEW user approval;no push/deploy/migration.
