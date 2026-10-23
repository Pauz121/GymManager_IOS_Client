# Standalone workout + nutrition creation flows

Checkpoint: 2026-10-08. Local implementation, not released and not yet accepted end-to-end.

## Scope and repository

Authoritative working checkout: `AGENT-IA/.orchestrator/tmp/ios-client-sync-20260913`, branch `main`, base `49e67c8`. Sources live in `IOS_Client/`. The stale copy under `projects/GymManager/IOS_Client/` was not edited. Desktop and Trainer iOS application sources were not changed. The earlier uncommitted refresh recovery fix was preserved.

## Workout

- Entry offers **Crea per me** and **Crea da solo** only in standalone mode.
- Guided creation reuses the existing deterministic generator, questionnaire, preview, regenerate and editable generated payload. It is not marketed as AI.
- Manual creation has five stages: days (2–6), muscle groups, real catalog exercises, prescription, preview/save. The save action is the final confirmation, not a separate empty screen.
- Existing muscle taxonomy is reused; optional Full Body, Upper/Lower and Push/Pull/Legs suggestions remain editable. The picker filters primary and secondary muscles, searches locally and offers an explicit all-groups fallback.
- Exercise order supports drag/drop and up/down alternatives; duplicate and delete remain available. No absolute weight is required or invented during creation.
- Exercise execution retains actual load recording and now displays the latest earlier completed-set load as **Ultima volta**. These existing execution logs are local, per account/source; cross-device load history is NOT implemented or claimed.
- Reducing days requires confirmation; sheets cannot silently swipe-dismiss a draft. Existing generated-plan editor uses confirmed async saving and explicit discard confirmation.

## Nutrition

- Entry offers **Crea per me** and **Crea da solo** only in standalone mode.
- Guided flow: profile → activity/goal → preferences → proposal. Known biological sex and most recent recorded weight are prefilled; age/height and remaining inputs are requested when unavailable. Existing answers can be reused, but health confirmation is not inherited.
- Manual flow: meal/day count → meal names → foods → quantities → totals/preview/save. Supports 3–6 initial meals and one day or Monday–Sunday; meals can subsequently be added, removed or renamed.
- Meal copies use new nested IDs. Day copies preserve the destination day/weekday, clone meal/food IDs, and require confirmation before replacement. Existing habitual meal templates remain available.
- Generated plans can be modified using the same manual builder; both sources use the existing personal Nutrition JSON payload and table.
- Current global catalog inspection: 170 real rows (163 USDA, 7 Open Food Facts), not a fabricated local food database. No CREA row was present. The client only loads global rows, never private Trainer libraries.
- Gram nutrients are normalized using the real reference serving. Piece foods require trusted `grams_per_piece`; piece quantities remain whole numbers. Unknown unit/density is not silently treated as grams. Automatic gram portions use multiples of 10 g. Missing macro values are disclosed as partial totals, not invented nutrients.
- Estimates reuse Desktop Mifflin–St Jeor coefficients and activity factors (1.2, 1.375, 1.55, 1.725). The general-purpose proposal uses modest Cut/Bulk modifiers and an explicitly generic 25/50/25 energy split, not the Trainer's advanced nutrition protocol or an invented lean-body-mass estimate.
- Generation is limited to self-confirmed healthy adults; allergy/clinical needs block it because the catalog has no reliable allergen metadata. No rehabilitation, clinical diet or allergen-safety claim is made. Exclusions use real catalog IDs. The plant/dairy preference does not claim certified vegetarian suitability for every packaged food.
- Deterministic generation uses real categories, bounded portions, four attempts and a consistency check. Unsupported catalog/preference combinations fail with a clear manual alternative rather than invented foods.

Method/reference context: [Mifflin original paper](https://pubmed.ncbi.nlm.nih.gov/2305711/?dopt=Abstract), [NIDDK adult planning limitations](https://www.niddk.nih.gov/health-information/weight-management/body-weight-planner). Product modifiers and macro baseline are explicitly product choices, not claims prescribed by these sources.

## Persistence and permissions

Existing tables: `client_personal_workout_plans`, `client_personal_nutrition_plans`. No separate generated/manual database. Existing supported database source remains `self_created`; JSON payload source distinguishes `manual` and `guided` without a schema change. New payload fields are optional for old plans.

Both creation save paths await an owner-filtered server readback and compare the full plan content before dismissing. Activating a new plan and archiving the fetched old active plans use one bulk upsert request; retry reads current remote active rows instead of trusting already changed local statuses. See [official Swift upsert reference](https://supabase.com/docs/reference/swift/upsert).

Drafts/local pending content are retained on failure. Local UI/cache changes are NOT proof of server persistence. There is no database uniqueness constraint preventing two devices from concurrently activating different plans; no concurrent-activation guarantee is claimed.

Local UI and service entry points reject Trainer-connected personal creation/editing and preserve earlier personal plans as read-only history. However, production inspection found the existing owner-only RLS policies still permit direct writes from connected clients. Therefore backend restriction acceptance is **NOT COMPLETE**.

Existing targeted migration: `Desktop/supabase/migrations/20261004105732_restrict_trainer_connected_personal_plans.sql` in the main GymManager project. It preserves owner SELECT and gates writes on standalone eligibility. Application to confirmed project `uslkraelkdjrwqjisczz` requires explicit user authorization; approval has been requested and not received at this checkpoint.

MIGRATIONS CREATED: NONE. APPLIED LOCAL: NONE. APPLIED PRODUCTION: NONE. DATABASE DATA MUTATIONS: NONE. EDGE DEPLOYS: NONE. No Git commit or push.

## Performance and lifecycle

Global food/exercise catalogs are cached in the session; wizard search filters cached results locally rather than querying on each step. Current catalog sizes fit the existing 500-row cap. Growth beyond that cap requires pagination work. Retry controls remain visible on catalog failure.

Sheet transitions use pending destinations and dismissal callbacks, not a fixed delay. Pending navigation is cleared on owner disappearance. The retained old exercise search rechecks cancellation after awaiting the response. Saving locks duplicate submission; reduced-motion preferences are respected by wizard transitions.

## Delegations and Codex review

1. Antigravity `GYM-IOS-CREATION-UX-20261008-001`: attempt 1, COMPLETED, provider SUCCESS, exit 0, conversation `f0277e8b-816d-4dd0-995a-60fd29c33aa9`. Text-only UX plan, no files edited. Codex APPROVE_WITH_CHANGES/PASSED: compact steps, preservation and retry accepted; existing taxonomy retained; empty workout sessions are not mislabeled as rest days.
2. Antigravity `GYM-IOS-CREATION-REVIEW-20261008-002`: NOT RUN. Tool approval rejected before launch because export of specific internal source to the external service lacked explicit authorization. No process, session, exit code or agent edits. No bypass attempted.
3. Internal Codex sub-agent `/root/review_creation_wizards`: read-only review of the two wizards and Workout library, attempt 1 COMPLETED, usable YES, files affected NONE. Codex ACCEPTED its discard, modal-lifecycle and stale-search findings and implemented fixes. Review was source-only, not compilation/runtime proof.

## Tests and acceptance

Windows static validation: **175/175 PASS** after final code edits. Scoped Git whitespace check: PASS. Project uses synchronized source/test groups, so new Swift files are included without manually duplicating project references.

Native XCTest definitions: 120 total (88 existing, 9 previous refresh, 10 manual Workout/history, 13 Nutrition). All **NOT RUN** on this Windows host. Synthetic food fixtures exist only in tests, not the app. Earlier independent JS arithmetic inspection using real public food rows was not execution of Swift or persistence and is not counted as native PASS.

| Acceptance area | Local source implementation | Real runtime acceptance |
| --- | --- | --- |
| Workout guided/manual, days/groups, real picker, order, sets/reps, no required kg | Implemented/reviewed | NOT RUN |
| Workout save/reopen/execute, actual kg and previous load | Confirmed-save path implemented; local history preserved | NOT RUN |
| Nutrition guided questions/generation/catalog/portions | Implemented/reviewed | NOT RUN |
| Nutrition manual meals/foods/quantities/macros/copy | Implemented/reviewed | NOT RUN |
| Nutrition save/reopen/generated edit | Confirmed-save path implemented | NOT RUN |
| Trainer-connected CTA/service restriction | Source checks PASS | Device NOT RUN |
| Trainer-connected direct DB write denial | Existing migration identified | NOT APPLIED / NOT RUN |
| Xcode build / Swift typecheck / XCTest / visual accessibility | Not available on Windows | NOT RUN |

No SAVE or REOPEN PASS is declared until a real authenticated plan is stored and reloaded.

## Exact next steps

1. Obtain explicit authorization for the single existing RLS migration. Re-read real policy/history, apply only that migration if still absent, inspect grants/policies, then controlled standalone/connected ownership tests. Do not run blind `supabase db push`.
2. On Mac, use this authoritative working source, not the stale project copy. Run:

   ```sh
   xcodebuild -showdestinations -project IOS_Client/GymManagerClient.xcodeproj -scheme GymManagerClient
   xcodebuild test -project IOS_Client/GymManagerClient.xcodeproj -scheme GymManagerClient -destination 'platform=iOS Simulator,id=<AVAILABLE_SIMULATOR_ID>'
   ```

   Choose an actually available simulator ID; build/test results are pending.
3. Authenticated standalone acceptance for each of the four flows: create → save → owner-filtered DB row read → refresh → close/reopen → compare IDs/order/content → edit/save. Workout: execute and record actual kg, start a later session and verify previous real kg. Nutrition: piece-unit foods, partial macros, one/seven days, copy independent IDs. Offline/rejected save must retain draft and show failure, not success.
4. Connected account: hidden creation CTA, service rejection, direct INSERT/UPDATE/DELETE denied after authorized RLS application, old personal plans SELECT still permitted. Never unlink or delete previous plans to make these tests pass.
5. Update handoff with actual acceptance evidence; commit/push only if newly explicitly authorized.

## Files

New: `Core/ClientManualWorkoutDraft.swift`, `Core/ClientNutritionCreation.swift`, `Core/ClientNutritionGenerator.swift`, `Features/Workout/ClientManualWorkoutWizard.swift`, `Features/Nutrition/ClientNutritionCreationWizard.swift`, `GymManagerClientTests/ClientManualWorkoutTests.swift`, `GymManagerClientTests/ClientNutritionCreationTests.swift`, this report.

Modified: `Core/ClientPersonalContent.swift`, `Core/ClientPersonalRepository.swift`, `Core/ClientSessionStore.swift`, `Core/ClientActivityInsights.swift`, `Features/Workout/ClientPersonalWorkoutView.swift`, `Features/Workout/ClientGuidedWorkoutView.swift`, `Features/Workout/ClientWorkoutExecutionView.swift`, `Features/Nutrition/ClientPersonalNutritionView.swift`, `scripts/validate-client-ios.ps1`. Earlier refresh files/project changes remain separate and preserved.

## Known issues / completion status

Not complete end-to-end: native/device and DB persistence acceptance pending; production connected-write restriction awaits authorization. No deployment/publication done. Local load history is not cross-device. Catalog has no verified allergen metadata and has a 500-row cap. Simultaneous multi-device activation is not serialized. Existing legacy duplicate/archive/delete menu paths remain optimistic and are not covered by the new creation confirmation contract.
