# Nutrition Coach Phase5D — pre-edit audit and plan

2026-10-23. Authoritative iOS Client checkout only. Attachment9a2edacd read completely (1315 lines). 85 app sources and22 native suites frozen in nutrition-ui-baseline-20261023.json before edits. No engine/N01–N16 rewrite, Desktop/Trainer/Running/Progress/theme work, DB/migration/remote data/push/deploy.

## Audit / skills / Codex direction
Existing guided wizard uses the obsolete owner-less generator and legacy combined safety toggle; it cannot satisfy5C evidence (severity3, blocked core task). Existing editor only does shallow draft validation and generic food selection, no smart-proposal/consent path (severity3). Existing confirmed save correctly reads back metadata/provenance but UI closes immediately without an explicit confirmed state and does not pin owner (severity3). Manual wizard and copy/picker work and must be preserved. Source-only heuristic score4/10; not a rendered/native usability score.

SKILL USED: UI/UX Pro Max (actual SwiftUI query: form validation navigation), interface-design, design-ios-interfaces, implement-swiftui-ios, review-hig-compliance, ux-heuristics, Impeccable Operate/iOS/craft floor; Supabase security boundary. Real instructions and applicable references read. RELEVANT PRINCIPLES: progressive disclosure; native Form/List/NavigationStack/sheets; task-first hierarchy; meaningful error recovery; explicit status/units;44pt/DynamicType/VoiceOver; same controls/tokens. FINDINGS PRODUCED: obsolete questionnaire, no source-aware editing, owner/save state ambiguity. CODEX DECISION: ACCEPTED native principles; MODIFIED web typography/primitive/render guidance to SF Symbols/system text/native containers. Rejected CSS/web mockups/dependency/theme replacement. WHY: native iOS correctness/accessibility outrank generic skill expression.

Intent: standalone adult making a practical food plan, with transparent estimates and reversible local edits. Domain: meals, portions, daily routine, training, food safety, substitutions. Color world: incumbent charcoal/canvas/ink/sage/accent/status roles, not new palette. Signature: real food/quantity before→after plus disclosed sibling adjustments. Avoid nested card dashboards, technical metadata and fictional AI. Hierarchy: one question/primary CTA, then target→meals→editing. Depth/surfaces: incumbent system/grouped Form, not more clay containers. Typography: SF semantic text, weight and secondary foreground; spacing4/8pt rhythm/44pt controls. This brief applies to questionnaire, plan editor and replacement sheet.

## Sequential roadmap
1. Explicit input/reuse/error/target flow + owner-pinned session/save adapters; native questionnaire integrated with existing wizard. Close source chunk.
2. Existing editor enhanced only for real5C coach plans: ID-layout changes, totals/revalidation, original metadata retained; shared food picker with safe optional filtering. Smart replacement same engine, calculated quantities, optional bounded rebalance/disclosure/explicit consent. No second nutrition engine/editor.
3. UI01–UI20 native definitions, explicit -NutritionUI source stage preserving all earlier baselines, regression checks; Mac backlog/handoff. Stop before next phase.

## Acceptance boundary
Swift/XCTest/Simulator/VoiceOver/real catalog/save/reopen/RLS NOT RUN on Windows. Backend gate OPEN; unknown reviews fail closed. No fake food IDs/nutrients/health evidence/precision/provenance. No production authorization in this task.

## Final source integration / Codex review
PHASE:5D Nutrition UI. STATUS:PASS SOURCE/HASH;overall product/native acceptance PARTIAL. Local integration only,not a published app or proven real-catalog/persistence result. The new user approval supersedes the historical stop-before5D solely for this source phase. No next phase started.

### Wizard / profile / eligibility
Eight native Form steps:personal data→daily activity→actual exercise frequency→goal→pattern→safety/exclusions→meals/horizon→review. Required choices start nil;explicit zero exercise/No health declarations retained. Four separate safety answers plus explicit allergy/intolerance review;clinical/minor/unsafe/missing/insufficient-food failures remain typed and corrective. No combined allergy=medical exclusion hack and no fake consent to calculate the preview.

Reuse actual identity biological sex without guessing;reuse a positive finite progress weight only if explicitly recorded TODAY in the device calendar and not future-dated,clearly labelled/correctable. Earlier measurements are not silently current. Profile currently lacks reliable age/height/occupational activity;those are requested. A planned workout frequency is not evidence of actual attendance and is therefore confirmed by the person. No estimated per-workout calories or inferred Health steps.

Patterns actually supported by5C:omnivore/vegetarian/vegan,subject to verified-catalog availability. Structured14allergens and2intolerances plus real UUID exclusions. Positive favourite-food ranking is NOT in the existing5C contract;no unimplemented favourite selector/score was fabricated. Preferences in this phase mean real pattern/safety/exclusions. No diet/medical promises.

### Target / meals / rationale
Same5C Mifflin/activity/goal/macro calculations,NOT duplicated or changed. Human-rounded daily kcal/P/C/G,WHY RMR/maintenance/goal adjustment,and WHY macro explanations in native disclosure groups. Generated day/meal/food quantities and nutrient totals versus target;horizontal days and normal plan model. No internal versions/signatures/fingerprints/tolerance IDs in UI.

### Same editor / complete draft editing
Existing ClientNutritionCreationWizard handles generated and manual plans;new helper views are sections/questionnaire/focused replacement sheets,NOT a second plan/editor/DB. Coach only:rename plan/day/meal,change quantities,add/remove foods,change food/meal order with accessible buttons,move foods,change meal occasion,explicit energy/protein distribution,copy meal/day and add/remove meals within existing validator envelope. Manual five-step wizard/copy/search/partial-macro behavior retained. New manual drafts explicitly clear any previous coach contract;old existing payloads are not rewritten.

Local domain operations preserve slot/layout identity,copy creates independent instance IDs,and full shared edited validator checks after every edit. Invalid intermediate drafts remain visible/correctable;no silent portion/target/distribution normalization. All invalid engine issues block save (no invented soft-error bypass). Names/order/distribution do not alter original answers/targets/generation metadata. Whole-day horizon remains the original1/7days;3–6meals and current5C hard bounds still apply. Empty/malformed coach days display a recovery message instead of indexing an empty array.

### Smart replacement / add / manual search
Same ClientNutritionSmartReplacement and ClientNutritionPortionSolver,not another ranker/food database. Current canonical revalidated draft feeds suggestions;accepted replacement becomes the last-valid edit base so provenance revisions are not reset. Hard role/occasion/pattern/allergy INCLUDING traces/intolerance/exclusion/source/nutrient/portion rules precede deterministic score/UUID ordering. Unknown metadata is excluded,not inferred from names.

Real solved quantity plus kcal/P/C/G before/after/rounded deltas. Same shared food picker gains optional allowed IDs/real portion lattice and candidate-only search;manual defaults unchanged. Manual replacement selection ignores arbitrary entered grams because the SAME solver calculates quantity before confirmation. Add filters compatible reviewed foods before listing them,rehydrates the real evidence snapshot and checks actual bounds.

Default swap-only. Optional bounded SAME-MEAL repair remains the pre5D policy:max1real step in siblings,selected replacement amount fixed. Exact sibling changes and whole-meal before/after displayed;separate unchecked consent required. Apply rechecks actual owner,stale preview/catalog and strict validation. No hidden full-day repair or blanket target rewrite. Generating/alternative calculations off main actor using immutable Sendable data;owner and cancellation checked on return;request IDs stop cancelled/older suggestions overwriting current previews. Actual latency/energy use remains unmeasured.

### Save / ownership / compatibility
Actual session owner pinned at modal entry;generation/edit proposal/apply/save and async returns recheck owner+standalone mode. No adoption of accountB when modal began underA;late Trainer connection denies. App guards do NOT replace repository/RLS or prove direct REST/link-vs-save safety.

Explicit localDraft→saving→confirmed/demo or failure. Existing confirmed save still stages local/offline draft,atomically writes archive+new payload,performs full read-back incl original generationMetadata/editProvenance. No onSaved/dismiss before confirmation;explicit Fine after success,local demo clearly not server success. Failed sync retains recoverable draft and never says database-confirmed. Native actual save/reopen NOT RUN. Historical standalone plans/old optional-less/manual payloads retained;no migration/new schema/source value.

Regenerate same inputs uses variation0;Generate Alternative uses existing bounded deterministic variation≤1000. Neither is random or silently persists. These actions are available while original questionnaire inputs remain in the current creation flow. Reopened historical plans can be edited;new generation must collect/confirm current evidence again rather than silently inherit old safety declarations.

### Actual delegation
[DELEGATION → GEMINI] GYM-NUTRITION-UI-20261023-001,native UX plan,read-only existing wizard,attempt1. [AGENT RESULT] FAILED:Antigravity not logged in/authentication timeout,exit1/providerERROR,num_turns0,empty response,filesNONE. [CODEX REVIEW] REJECTED as unusable;optional Codex fallback per project policy. Human record/invocation/stdout/stderr and machine CALL_STARTED/CALL_FINISHED/CODEX_VERIFICATION exist. NO successful Gemini/visual review claimed. No implementation lock or agent-modified files.

## Files and preservation
Exactly TWO pre-existing app files changed since the85-source checkpoint:
- Features/Nutrition/ClientNutritionCreationWizard.swift:guided routing,shared coach sections,current-owner/validation/save states;manual path preserved.
- Features/Nutrition/ClientPersonalNutritionView.swift:shared picker optional coach filtering/portion/candidate selection;library/manual defaults retained.

New app files7:Core/ClientNutritionCoachFlow.swift;ClientNutritionCoachUISession.swift;ClientNutritionCoachEditing.swift;Features/Nutrition/ClientNutritionCoachWizard.swift;ClientNutritionCoachEditor.swift;ClientNutritionReplacementSheet.swift;Preview/ClientNutritionCoachPreview.swift.
New test file:GymManagerClientTests/ClientNutritionCoachUITests.swift,20definitions.
New scripts:validate-nutrition-ui.ps1;nutrition-ui-checkpoint-source.ps1. Eight existing script helpers/validators get explicit-NutritionUI chaining. Immutable pre-edit baseline plus explicit reviewed before/after UI patch audit;NO historical baseline reset. Original22native suites/fixtures and83otherexisting app sources exact unchanged,including5C engine,N01–N16,Workout/BodyMap,Auth/query/repository/save/read-back cores.

No Desktop/Trainer/Running/Progress/theme/Widget/Xcode/signing/dependency source changes. Normal existing dirty main worktree retained;Git HEAD49e67c8,31tracked dirty,stagedNONE. Git stat alone includes prior work and is not this phase's scope evidence.

## UI01–UI20 — definitions, NOT RUN
|Case|Presentation/domain assertion|Native result|
|---|---|---|
|UI01|required inputs explicit/collectable,no inherited health defaults|NOT RUN|
|UI02|actual sex/today-dated weight reuse,no stale measures|NOT RUN|
|UI03|missing data corrective step,other answers retained|NOT RUN|
|UI04|Trainer-managed denied before generation|NOT RUN|
|UI05|typed human eligibility/recovery mapping|NOT RUN|
|UI06|target preview equals SAME energy calculation/human units|NOT RUN|
|UI07|real generated meals/amounts/targets,same-input structural signature|NOT RUN|
|UI08|add-food role/occasion/duplicate filter|NOT RUN|
|UI09|actual deterministic replacement-score ordering|NOT RUN|
|UI10|solved replacement quantity,not copied grams|NOT RUN|
|UI11|known allergen traces excluded|NOT RUN|
|UI12|vegan incompatibility excluded|NOT RUN|
|UI13|manual quantity recalculates totals,hard bounds revalidated|NOT RUN|
|UI14|bounded sibling rebalance disclosure and explicit consent|NOT RUN|
|UI15|strict edits,origin preserved,catalog failures stay specific|NOT RUN|
|UI16|owner pin/late Trainer denial and nonconfirmed states|NOT RUN|
|UI17|metadata JSON roundtrip,NOT a database persistence test|NOT RUN|
|UI18|backward optional-less payload decode|NOT RUN|
|UI19|old manual model/copy/no invented coach target|NOT RUN|
|UI20|same plan/catalog alternatives identical under catalog permutation|NOT RUN|

These are XCTest presentation/domain contracts,NOT XCUITest rendered interactions. Native305total test definitions and3new target specimens NOT RUN. OriginalN01–N16/CASE01–12/previous fixtures exact unchanged.

## Real validation results
Canonical Windows command:

    pwsh -NoProfile -File IOS_Client/scripts/validate-nutrition-ui.ps1 -NutritionUI -AllStatic

Fresh167NutritionUI source/hash checks;145SmartEditing;169NutritionEngine;110Foundation;75Phase2;86Phase3+4;212WorkoutCoachUI;202fullappstatic:PASS. Counts overlap and are NOT behavioral/native totals. Ten PowerShell files parse;Git diff--check/newSwift whitespace PASS. Approved patches reverse ONLY the two scoped UI diffs and reproduce exact original whole-file hashes;all other pre5D app/test sources unchanged. New source checks inspect actual CURRENT5D implementation;old suites inspect historical preserved contracts explicitly rather than falsely accepting unreviewed drift.

Swift build:NOT RUN;XCTest:NOT RUN;Simulator:NOT RUN;VoiceOver:NOT RUN;rendered contrast/DynamicType/one-hand/ReduceMotion/performance:NOT RUN;real reviewed food catalog:NOT RUN;actual save/reopen:NOT RUN;real RLS:NOT RUN. Windows has no swift/xcodebuild. No browser mockup presented as native acceptance.

## BACKEND RELEASE GATE / known limits
OPEN until actual current RLS/standalone restrictions/reviewed metadata/provenance/real save+reopen verified with appropriate authorization. Current catalog could admitZEROautomatic foods;UI then reports insufficient verified data,never fabricates reviews/food IDs/nutrients. Source preflight is not atomic server protection. Prior local restriction migration state remains historicalNOTAPPLIED/currentNOTVERIFIED;NONE applied here.

Existing5C applicability/portions/fit envelope retained,not universal/clinical nutrition or allergen certification. Positive favourite-food ranking not supported by existing core. Strict-invalid edits require correction,not a newly invented soft override. Catalog revision mismatch fails closed;no rewriting historical snapshots. Reopened plan regeneration requires current evidence questionnaire. Native compilation and complete UI/persistence matrix remain necessary. Existing legacy app/theme contrast debt remains parked;not whole-app accessibility PASS.

DATABASE/MIGRATIONS/REMOTE QUERIES/WRITES/FUNCTION DEPLOY:NONE. COMMIT/PUSH/TAG/RELEASE/DEPLOY:NONE. MAC_ACCEPTANCE_BACKLOG:UPDATED. NEXT EXACT STEP:Mac exact worktree→xcodebuild-list actual scheme/device→build app+Widget/test305definitions,then approved real catalog/RLS/save acceptance. Wait for user approval before NEXT product phase;no publishing authorized.
