# Smart Plan Editing — pre5D source plan

2026-10-23. Attachmentcef133ae fully read;79existing app sources/20native suites frozen before edits. Scope seven existing core modules plus new pure editing/proposal/test helpers. No UI,DB/remote query/migration/push/deploy. Codex owns numerical/business/security integration. Supabase skill read for preserving current save/ownership boundaries;no SDK/API/query change planned. No agent/delegated work claimed.

## Sequential roadmap
1. Workout:reuse reviewed admission,exact primary/pattern/kind and difficulty ceiling;deterministic lexicographic ranking,equipment setup/priority/actual-volume tie-breaks;full existing EditedWorkoutPlanValidator before accepting proposals. Preserve sets/reps/rest/RIR/notes;no invented kg. Generated plans get optional edit-origin marker;old payloads remain valid.
2. Nutrition:reuse existing PortionSolver with configurable objective DEFAULT unchanged. Same-role/source-reviewed hard compatibility first;optimize+quantize candidate quantity,rank four-nutrient distance. Default SWAP ONLY;optional explicit bounded-meal rebalance produces a full change list requiring consent. Independent edited layout validation permits names/order/meal composition/distribution,never weakens original targets/health/food safety.
3. Optional provenance in existing normal plans,strict regeneration-vs-edit distinction,shared validator/save integration,stale-preview protection. Original generator/profile/catalog/explanation data preserved. No separate plan/DB/LLM.
4. WREP01–06,NREP01–10 native definitions + preservation/source scripts and Mac backlog. Native Swift/XCTest remain NOT RUN on Windows. STOP before5D.

## Product policy choices (not medical similarity claims)
Workout:exact pattern/kind/primary only until reviewed similar-role metadata exists;no inferred pattern compatibility. Difficulty no higher than original and still inside profile admission. Ranking lexicographic:exact difficulty,required-equipment symmetric difference,priority coverage,actual-coefficient volume distance,stable canonical UUID. Full-plan invalid proposals rejected.
Nutrition replacement objective:kcal4,protein3,carb2,fat2;normalization floors25kcal/5gP/5gC/3gF prevent division by zero for negligible nutrients. Source preference is a small deterministic0.01×source-priority penalty. Role mismatch is HARD rejection,not a fake similarity percentage. Item fit must stay within25%energy and30%dominant-role nutrient with same normalization floors;these are transparent engineering bounds. Same gram amount is NEVER assumed.
Optional rebalance:at most one REAL quantity step up/down for other foods in the SAME meal;no other meal/day change. Explicit plan validator rechecks meal energy/protein,daily energy/macros/hard limits. Every nonselected changed food listed before confirmation;default and nonconsenting apply cannot rebalance. Solver limits/food bounds remain authoritative.

## Existing gates retained
Current real reviewed Nutrition catalogue/RLS/migration status and actual save/reopen are NOT VERIFIED;BACKEND RELEASE GATE OPEN. This source task cannot close them. New UI still requires approval;no publication authorized.

## Final implementation / Codex review
STATUS:PASS SOURCE/HASH;overall native/product acceptance PARTIAL. NO UI redesign or5D work. UI source files exact unchanged. No successful agent/Gemini/native review claimed;Codex implemented/reviewed sequential chunks.

### SMART WORKOUT REPLACEMENT
Existing ClientWorkoutCoachEditingContext delegates to ClientWorkoutReplacementRanking,not another exercise DB/admission algorithm. Canonical source reviews/actual muscle links/equipment/exclusions/effective profile gate remain authoritative. Same primary-set/pattern/kind required;unknown/unreviewed originals excluded;difficulty≤original PLUS profile admissibility. Same level ranked before lower compatible level;no automatic beginner→advanced escalation.

Ranking is lexicographic:difficulty distance→equipment setup symmetric difference→priority coverage shortfall→actual set/coefficient volume distance→canonical UUID. No random,locale sorting,similarity percentage or invented activation weights. Similar-but-not-exact patterns NOT inferred;limited verified catalog may offer no alternative.

Existing picker gets ranked compatible candidates via unchanged API;no new recommendation UI. New full-plan proposal API additionally replaces a COPY,uses existing canonical exercise builder,retains sets/reps/rest/RIR/notes,clears nonexistent prescribed kg,then reruns ClientEditedWorkoutPlanValidator. Coverage/weekly volume/order/duration/duplicates/recovery/exclusions refreshed by the SAME validator/metrics. Invalid full-plan proposals omitted;no-result typed failure. New exercise instance UUID avoids treating old exercise logs as the new movement's load history;catalog IDs never invented.

Apply rechecks parent plan UUID/structural content/catalog/target,and reconstructs from current reviewed catalog rather than trusting proposal.plan. Trainer-connected/unauthenticated denied. Both full-plan before/after actual volume metrics exposed. No plan mutation/persistence during preview.

### SMART NUTRITION REPLACEMENT
Existing ClientNutritionFoodPolicy admission remains source of truth for real source review,pattern,allergies INCLUDING traces,intolerance/exclusions,serving/portion metadata. Same original role and allowed meal occasion first;no current-food self-swap or duplicate within same meal. Manual search can request a particular REAL catalog UUID but follows identical fit/hard-safety rules;wrong-role candidates are rejected,not sold as calorie-equivalent protein substitutes.

Quantity is solved by SAME ClientNutritionPortionSolver.fit with a new objective parameter. Generation DEFAULT remains EXACT4/1/1/1 and1-unit normalization. Replacement uses4/3/2/2 and25kcal/5gP/5gC/3gF floors;continuous optimization→real step/whole-piece quantization→discrete repair unchanged. Objective weights0.1–100/scales0.1–1000 finite bounds prevent pathological numeric configuration. Stored food kcal/macros×actual grams,never same-grams assumption or LLM values.

ReplacementScore =four-nutrient normalized squared error +0.01×CREA/USDA/OFF priority. Default source penalty bounded0–0.05;role/safety mismatch HARD rejection,not a score penalty. Energy distance≤25% and dominant-role nutrient distance≤30%,using explicit normalization floors;these are engineering fit guards,NOT clinical equivalence claims. Full plan validator can reject an otherwise similar food.

Returned alternatives sorted score→canonical UUID,deterministic for fixed plan/catalog/target/policy;no meaningless percent-similar badge. Preview DTO contains original and replacement real quantities,exact kcal/P/C/F before/after/deltas.5D must display kcal rounded whole and macros reasonably rounded(typically0–1decimal),not raw float precision.

### REBALANCE POLICY / CONSENT
DEFAULT:swap ONLY the selected food. No sibling quantity changes.

Optional allowMealRebalance must be explicitly requested. If direct swap fails full-plan validation,offered replacement quantity remains FIXED;each other food in SAME meal may move at most1actual quantity step within original real bounds. No other meal/day change. Same solver fits the original explicit meal target;strict validator reruns ALL meal/day/source/safety checks and candidate similarity rechecked.

Every changed sibling creates foodID/name/beforeGrams/afterGrams/explanation. Apply defaults acceptRebalance=false and rejects any proposal with sibling changes unless consent is explicit. Apply recomputes proposal from current data and compares original/replacement/full change list,then validates again;stale/forged preview cannot silently apply different changes. Local draft result is NOT a server-save confirmation.

### WHOLE PLAN EDITABILITY / VALIDATORS
Workout source/answers/progression/engine metadata preserved. Existing edited validator allows existing valid names/session/order/prescription changes within the current5B program envelope;hard structure/coverage/recovery budgets remain,no silent sets/reps normalization. New generation change ONLY adds edit-origin anchor after existing successful validation;programming algorithm/metrics/CASE matrix unchanged.

Nutrition:original strict generation default retained. Shared inspectCore preserves health/profile/RMR/TDEE/target/macro/food/portion/day/tolerance/metadata rules. Specific edited validator permits different names/order/food composition/3–6meals per day/explicit energy and protein distributions via ID-based layout,not inferred from renamed meal labels. Day horizon stays original1/7days. Per-day distributions normalized to1;energy shares5–50%,protein10–50% each are product guards against nearly-all-in-one-meal edits,not medical claims. Ingredient budget1–5main/1–3snack retained. Original targets/answers/generation metadata immutable;each food role/occasion independently revalidated. No View validation policy.

ClientEditedNutritionPlanValidator.prepare(original,edited,layout) is the intended future edit transaction:validate original,check immutable origin fields,update only explicit editing layout/provenance,independent full revalidation. Invalid generated edits cannot bypass by dropping/forging revision0 provenance;default wrapper returns actual underlying failures plus metadata error. Shared core edited-layout entry also verifies provenance,not a public bypass flag.

### GENERATED VS EDITED / SAVE BOUNDARY
Both existing normal plan structs gain ONE OPTIONAL editProvenance,old payloads nil. No second plan type/table/source enum or migration. Original generator version/answers/rationale/catalog snapshot remain;editor version smart-plan-edit-1.0.0,original/current structural signatures,origin-metadata fingerprint,revision persisted. hasUserEdits derived from revision>0,not a fabricated encoded boolean. Nutrition explicit layout inside that same marker. New generated plan starts revision0;successful structural changes increment. Older metadata-less plans remain historical/manual paths;no regeneration or retroactive provenance invention.

Fingerprints canonicalize only known unordered sets,preserve ordered plan arrays,and exclude instance IDs/timestamps/status/derived validation. SHA256 is a local audit/stale-preview aid,NOT authorization/signing/tamper-proof attestation. Newly introduced source markers do not make client-supplied claims trusted server authority. Fresh UUIDs allowed for persistence instances,not exercise/food catalog IDs.

Five current-session proposal/apply adapters pin expectedOwnerID and recheck actual active identity/mode before each call,including manual Nutrition candidate preview. They return only LOCAL drafts. Existing save entry points/strict Nutrition dispatch,Workout edited-save validator,fresh repository preflight and backend RLS remain required;server read-back additionally compares editProvenance for BOTH plan types. No Auth/SDK/query/RLS implementation change. Actual linking-vs-save race/real persistence still unverified.

## Files / preservation
Modified seven existing core files:ClientEditedWorkoutPlanValidator.swift;ClientNutritionPlanValidator.swift;ClientNutritionPortionSolver.swift;ClientPersonalContent.swift;ClientWorkoutGenerator.swift;ClientNutritionGenerator.swift;ClientSessionStore.swift.

Created six core files:ClientPlanEditProvenance.swift;ClientWorkoutSmartReplacement.swift;ClientNutritionEditingLayout.swift;ClientEditedNutritionPlanValidator.swift;ClientNutritionSmartReplacement.swift;ClientSmartPlanEditingSession.swift. Created two test suites:ClientWorkoutSmartReplacementTests.swift;ClientNutritionSmartReplacementTests.swift.

New scripts:validate-smart-plan-editing.ps1;smart-editing-checkpoint-source.ps1. Existing nutrition checkpoint helper and five historical validators gain explicit-SmartEditing stage. Prior baseline JSON files NEVER rewritten. New smart baseline79files/20tests and approved reverse-patch audit support exact original whole-file hash verification outside seven approved edits.

72otherexisting Swift files exact unchanged,including ALL UI,other Nutrition core/food/health rules,Workout rule/catalog/validator/progression logic. All20existing native suites/fixtures exact bytes unchanged—including original CASE01–CASE12 and N01–N16. Minimal generator additions only initialize provenance after existing successful validation. No Desktop/Trainer/BodyMap/Widget/Xcode/signing/dependency changes this task. Existing31tracked dirty files/pre-existing untracked retained,stagedNONE,main49e67c8.

## Native test matrix — DEFINED, NOT RUN
|Case|Definition/assertions|Native result|
|---|---|---|
|WREP01|Same primary/pattern/difficulty envelope;catalog permutation stable ranking|NOT RUN|
|WREP02|Beginner original excludes advanced/higher technical level|NOT RUN|
|WREP03|Home inventory rejects incompatible equipment|NOT RUN|
|WREP04|Explicit excluded exercise absent|NOT RUN|
|WREP05|Same-session duplicate absent|NOT RUN|
|WREP06|Actual coefficient-volume revalidation,prescription preservation,provenance,stale apply|NOT RUN|
|NREP01|Similar protein with calculated2×diluted-fixture quantity,not copied grams|NOT RUN|
|NREP02|Same kcal/different macros worse score;accepted compatible alternatives rank accordingly|NOT RUN|
|NREP03|Known allergen trace candidate denied|NOT RUN|
|NREP04|Vegan-incompatible candidate denied|NOT RUN|
|NREP05|Real piece lattice quantity|NOT RUN|
|NREP06|Outside real portion capacity rejected|NOT RUN|
|NREP07|Meal validates,no sibling/unrelated meal change|NOT RUN|
|NREP08|Daily totals valid and invalid edited quantity rejected|NOT RUN|
|NREP09|Boundary meal needs explicit rebalance,all changes disclosed,consent-only apply|NOT RUN|
|NREP10|No compatible alternative typed failure|NOT RUN|

Five extra definitions:Trainer-connected Workout denial;Nutrition rename/reorder/distribution-preserving edit;catalog-permutation/stale preview;provenance/layout JSON roundtrip;extreme distribution/forged origin denied.21newnative definitions,285total,ALL NOT RUN. Fixtures reuse existing explicitly synthetic test inputs,not real chicken/turkey/USDA API evidence;NO food/exercise data seeded.

## Final validation / gates
Fresh source/hash:145/145smart editing;169Nutrition;110foundation;75Phase2;86Phase3+4;212WorkoutUI;202fullapp. Counts overlap,NOT behavioral totals. Git diff--check/newcore whitespace PASS. Canonical source command:

    pwsh -NoProfile -File IOS_Client/scripts/validate-smart-plan-editing.ps1 -AllStatic

Swift/Xcode/Simulator/285XCTest/visual/performance:NOT RUN,tools unavailable on Windows. Actual real reviewed catalog availability/save/reopen/RLS:NOT RUN. BACKEND RELEASE GATE OPEN. No DB changes/migrations/remote query or writes/functions/push/deploy/commit/release.

SMART WORKOUT REPLACEMENT:IMPLEMENTED SOURCE;native unverified.
SMART NUTRITION REPLACEMENT:IMPLEMENTED SOURCE;real catalog/native unverified.
WORKOUT RANKING:deterministic lexicographic.
NUTRITION RANKING:deterministic four-nutrient distance+source tie preference.
QUANTITY SOLVER REUSE:YES.
REBALANCE POLICY:swap-only default;explicit bounded same-meal proposal+full disclosure+consent.
VALIDATORS:existing EditedWorkout/shared Nutrition hard core+dedicated edited Nutrition.
TESTS ADDED:21definitions,WREP01–06/NREP01–10 included;NOT RUN.
UI CHANGES:NONE.
PHASE5D READY:NO—native/catalog/backend gates open,UI integration approval required.

Known limitations:exact Workout movement roles only;small reviewed catalog can offer zero replacements. Existing Workout program bounds still apply;no automatic splitting/session-count or target redefinition. Nutrition approximate bounded solver,not a proof of global optimality or medical equivalence;source safety only as reliable as real upstream reviews. Layout distribution is editable within stated guards,not unrestricted clinical diet editing. Existing catalog revision mismatch handling remains fail-closed;no silent rewriting of history. Pure policy context not server authorization;actual session adapters/RLS mandatory.

NEXT EXACT STEP:On Mac use actual scheme/device to compile current worktree and run285definitions,especially21new cases and all original coach matrices. Verify real catalog/source review and save/read-back with separate authorization. THEN Phase5D only after NEW user approval. No push/deploy/production migration.
