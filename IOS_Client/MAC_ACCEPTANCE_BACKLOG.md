# IOS_Client — consolidated Mac acceptance backlog, Phases1–7

## LATEST — reported Xcode overlapping metadata access, 2026-10-23

ClientNutritionGenerator.swift:109 read the whole plan inside the expression mutating its generationMetadata. The scoped compiler fix evaluates the structural signature in a local constant before a separate write. No generation rules, signature algorithm, catalog, validator or editing contract changes. Historical source baselines remain immutable; exact patch reversal verifies the entire pre-fix generator SHA256. Two native regression definitions NG01/NG02 check generated signature/validation and Codable metadata preservation (NOT database save/reopen). Now 325 native definitions / 26 test Swift files including fixtures; build and XCTest NOT RUN on Windows.

Canonical source QA: `pwsh -NoProfile -File IOS_Client/scripts/validate-nutrition-generator-exclusivity.ps1 -AllStatic` (includes the prior fingerprint validator and all nine program suites). Native P0: pull the new compiler-fix commit after 701bec8, build app + Widget in Xcode and run NG01/NG02 plus all prior 323 definitions. User explicitly authorized a normal push for this fix only. No production migration/deploy or native PASS is implied.

## PREVIOUS — reported Xcode type-check failure / local repair,2026-10-23
User-reported ClientNutritionFoodPolicy.swift:125 failed to type-check the30-field fingerprint expression. Localfix splits it into small explicitlytyped steps;all30expressions/order/UTF8framing/nilmarkers/sort/newlineseparator/SHA256 retained. 50focusedSOURCEchecks+all9prior suitesPASS;this is NOT a Swiftcompile. SixClientNutritionFingerprintTests PF01–PF06definitions added:reviewedlegacygolden,Unicode+nilgolden,empty,unreviewed,order,fieldchange. NOW323native definitions/25testSwiftfilesinclfixtures. Nativebuild/XCTestNOTRUN. User authorized publication aftersourceQA. Pull the compiler-fix commit newer than d417a7d before native acceptance. NEXT:afterauthorizedtransferofexactfixedfiles,Macbuildapp+Widgetandrun6newtestsplusprior317. Do not assumeoldGitHubd417a7dcontainsfix. Historical317countsbelowpre-dateaddition.

## CURRENT — Phase6+7 final source integration,2026-10-23
This section supersedes earlier STOP/theme/publication status notes,NOT historical evidence. Source program may be committed/pushed only after fullsourceQA;no production/AppStore/native acceptance inferred. Older detailed scenarios below remain mandatory.
Windows canonical:pwsh -NoProfile -File IOS_Client/scripts/validate-ui-final.ps1 -AllStatic.
Mac starts with:xcodebuild -list -project IOS_Client/GymManagerClient.xcodeproj. Select actualscheme andavailabledevice;build app+Widget andrun317XCTestdefinitions(24Swift test/fixturefiles),including12F01–F12,UI01–20,N01–N16,CASE01–CASE12,Smart/manual/timer/load regressions. Do not sum source-validator counts as executed native tests.

### P0 — release/functional correctness
|Area / Phases|Acceptance required|Status|
|---|---|---|
|Build / ALL1–7|Actual Xcode/Swift6 compile,app+Widget packages/schemes/resources;317tests;fix only demonstrated failures|NOT RUN|
|Coach authorization /5A/B,5C,5D|CurrentRLS/restrictionmigrationstate/directREST denial;standalone→Trainerlink-vs-save race;fresh actualsession owner before/after awaits|NOT RUN;backendgateOPEN,separateauthorization|
|Coach realdata /5A/B,5C,5D|Real reviewed exercise/foodcatalog provenance;emptycatalog failclosed;manual remainsavailable;neverforge reviews|NOT RUN|
|Persistence /5A/B,5C,5D|Authenticated save→readback→close/reopen/differentdevice;activation/archive atomicity;no falseconfirmation/offline/staleowner success|NOT RUN|
|Bootstrap /3+4|Freshinstall/login/return/background/cancellation/retry;capture correlatedsafe stage-only diagnostics;Progress read must never mutate Trainer relation|NOT RUN;original firstload incident not runtime-proven|
|Account /7|OfficialHTTPSprivacy/supportdomain;true reviewed server deletion endpoint/clientreauth/revocation/confirmation/dataretentionflow|BLOCKED;domainandClientdeletionpathMISSING|

### P1 — native experience/accessibility
|Area / Phases|Acceptance required|Status|
|---|---|---|
|Theme /1,6,7|System(default) followsOS;Light/Darkpersistacrosslaunch;allmainviews/forms/sheets/alerts/keyboards/tabbar/chart/detail/execution;day/night/IncreaseContrast;actualcompositedcontrast|NOT RUN|
|Layout /ALL|320/375/430pt portrait/landscape,AX3/largestDynamicType;nosmallclipping/keyboardoverlap;native screenshots,notHTMLsubstitutes|NOT RUN|
|Assistive input /ALL|VoiceOverorder/announcements/selectedtraits/adjustablecontrols;SwitchControl44pt;ReduceMotion;hapticsrealdevice|NOT RUN|
|Tab/navigation /2,7|PremiumTabBartap/hold-scrub/release/cancel/systembackgesture;nointerference withscroll orassistivetech;safearea duringkeyboard|NOT RUN|
|Exercise /3|Actualprescription/mediafallback/anatomy/catalogmusclerelevance;noinventedaccessoryweights/unauthorizedmedia|NOT RUN|
|Execution/timer /3+4|Complete-setundo/history/loadinput+keyboard;singlefloatingtimerowner,dragclamp/safearea/rotation/largetext/skip/pause/resume/backgroundtimestamps|NOT RUN|
|Live Activity /3+4|Realdevice background/staleDate/permission/end/update/notification;run+restcoexistence;notclaimedfromsimulator|NOT RUN|
|Workout /5A/B|Eligibility/effectivelevel/catalogadmission/split/equipment/exclusions/volumes/duration/order/doubleprogression;wizardpreview/manualedit/regeneration/save|NOT RUN|
|Nutrition /5C,5D|Health/allergy/unknownmetadatafailclosed;targetWHY;piece/10gquantity;strict edits/fullplanvalidation/smartproposals/staleconsent/mealrepairdisclosure|NOT RUN|
|Progress /6|30/90/allboundaries/timezone/future/0or1weight;selectedactualpoint,neutraldelta;measurements/gym/runlocalcounts;fixedMonSun/16week;no inventedphotos/bodycomposition/steptrend|NOT RUN|
|Nutrition polish /6|Day→meals→foods;currentdayonlycheck;unknownkcal/macros notzero;realpersonalP/C/Gtotals;copy/edit/corebehaviorsretained|NOT RUN|
|Spazio /7|Avatarlocal-only/email/code/password;profiledatareadonlyhonest;Trainerstatusnoopenmutation;AppearanceandPrivacy/Support/deletionblockerexplained|NOT RUN|

### P2 — craft/performance/regression
|Area / Phases|Acceptance required|Status|
|---|---|---|
|Polish /ALL|Measure scroll/chartselection/picker/generation latency onsmall/olderiPhone;off-mainwork andcancel/staleresponses;noheatmap/renderstalls|NOT RUN|
|Visual /1–7|ActualLightwarmneutral/Darkcharcoal/coral/domaincolors;carddepthconsistent,contenthierarchy,chartaxes/labels,animation/hapticcomfort|NOT RUN|
|Legacy/manual /2–5D|Oldpayloaddecode,priorpersonalhistoryafterlinking,manualcreation/editor/meal-daycopy,Trainerreadonlyplans,Agendaunchangedexcepttargets|NOT RUN|

Acceptance evidence:record device/OS/Xcode/scheme/buildhash,steps,actualresult,screenshots/traceonlywithoutpersonaldata. Never markPASSfromsourcegrep/JSONroundtrip/fixture. No deployment/migration is authorized by this backlog.

---

# PREVIOUS — Mac acceptance backlog, Phases1–5D


## LATEST — Phase5D Nutrition UI,2026-10-23

Local5D SOURCE/HASH PASS,overall native/product PARTIAL. This new approval supersedes older STOP-BEFORE5D notes ONLY for current source work. Backend gate remains OPEN;no next phase/publishing authorization. Report docs/NUTRITION_COACH_UI_20261023.md;canonical Windows source command:pwsh -NoProfile -File IOS_Client/scripts/validate-nutrition-ui.ps1 -NutritionUI -AllStatic.167UI/145Smart/169Nutrition/110Foundation/75Phase2/86Phase34/212Workout/202app overlapping source checks PASS,NOT native evidence.

1. Exact dirty worktree,xcodebuild -list -project IOS_Client/GymManagerClient.xcodeproj;actualscheme/device→build app+Widget/test305definitions. Run20new ClientNutritionCoachUITests UI01–20 plus ALL frozen N01–N16/CASE01–12/Smart/oldmanual suites. Swift6 actor/Sendable/Task.detached,Form/Section/ViewBuilder,optional pickers/keypaths/inout operations need actual compile. XCTest definitions are not XCUITest or server persistence evidence.
2. Render actual8-step Nutrition flow and SAME existing editor at320/375/430pt,portrait/landscape,Dark/Light specimens,AX3,VoiceOver/SwitchControl,ReduceMotion/IncreaseContrast. Three target specimens have no session/network. Capture Simulator/device screenshots,never browser approximations. No whole-app Light/contrast completion claimed.
3. Requirednil inputs/explicitzero/No;profile sex and ONLYtodaydatednonfuture progress weight labelled/correctable;older measurements not auto-current. No guessed age/height/occupation/activity/health consent. Back/corrective errors preserve answers;typed clinical/minor/unsafe/catalogfailures never bypassed. Structured14allergens/twointolerances/exclusions with review confirmation. Actual catalog may admitzerofoods—correct failclosed state,not a reason to forge review metadata.
4. Shared-engine kcal/P/C/G target andWHY RMR/maintenance/goal/macros;no technical metadata/rawprecision. Current plan→selectedday→compact meal/food quantities/totals/target. Regenerate0 vs bounded variation;no arbitraryshuffle/early persistence. Verify UI remains responsive during off-main generation/replacement,requestcancelled/stale previews do not overwrite currentstate;measure latency/energy rather than infer it.
5. SAMEeditor rename/order/quantity/add/remove/move/mealoccasion/3–6meal distribution/copyday-meal. Invalid intermediates visible and saveblocked;no hidden normalization/target change. Recalculate actual meal/day totals;piece lattices and full-day hard constraints. Copy new IDs,original generation metadata/source/answers retained. Newmanualdraft does not inherit oldcoachcontract;oldoptional-less/manual/history untouched.
6. Smart alternatives ordered actualscore,real calculatedgrams/wholepieces,kcal/P/C/G before/after/human deltas. Sharedpicker filters source/role/occasion/preferences/safety;manual search calculates thenpreviews,no samegramassumption. Strict-valid CURRENTcanonical draft feeds replacement;accepted revision persists. Unknown/allergen/traces/intolerance/exclusions/wrongrole/changedcatalog reject. Testzeroalternatives andexplicitcatalogretry.
7. Defaultswap-only keeps all other foodsexact. Explicitboundedmealrepair shows everychangedsibling andwholemealbefore/after;unchecked separateconsent required. No silentdayrebalance. Verify cancellation leavesdraftunchanged;apply rechecks owner/stalepreview/catalog/fullvalidation.
8. OwnerA→logout/loginB andlateTrainerlink atquestionnaire/await/editor/save:denywithoutadoptingB;historypreserved. RealRLS/directREST/link-vs-save race STILL NOT VERIFIED. No security acceptance from app helper tests. Existing current-session/repository/fullreadback must run under actualbackendauthorization.
9. localDraft→saving→confirmed vsfailure;offlinefailedsync preserveslocaldraft butNOTserverconfirmation;demoexplicitlocalonly. No dismissalbeforeverification,explicitFineafterconfirmation. ACTUALsave/logout/reopen must retain days/foods/source/answers/targets/generationMetadata/editProvenance andactive/archive semantics. Newmanualcreation/copy/picker/history regression. JSON testUI17 isNOTthis test.
10. BACKENDGATEOPEN:verifycurrent reviewed catalog andprovenance/RLS/migrationstate usingseparatelyauthorizedread-onlychecks andcontrolledpersistenceacceptance. No migration/deploy/push authorized. Positivefavourite-foodranking unsupported byexisting5Ccontract;do not add nonfunctionalcontrols. ExistingPhases1–4/Workout/native debts below retained.

NEXT EXACT STEP:Mac actualbuild/tests/realUI+backendacceptance;waitfornewapprovalbeforeNEXTproductphase. None of the native rows above has been executed on Windows.

---

LATEST:pre5D Smart Plan Editing source/hash PASS;overall native acceptance PARTIAL.21newnative definitions(WREP01–06/NREP01–10+5extras),285total NOT RUN. Report docs/SMART_PLAN_EDITING_20261023.md. This supersedes only older source-count checkpoints;Phase5D still NOT authorized.

1. Exact current worktree:xcodebuild -list -project IOS_Client/GymManagerClient.xcodeproj;actualscheme/device→build app+Widget/testall285. Swift6/CryptoKit/JSONSerialization canonical fingerprints/Sendable/optionalCodable require actual compilation,no static proxy.
2. Run ClientWorkoutSmartReplacementTests7definitions and ClientNutritionSmartReplacementTests14definitions plus all original CASE01–12/N01–16. Check fixture assumptions,not only method presence. No real food/production claim from synthetic fixtures.
3. Verify deterministic ordering across catalog permutations/repeated calls;same muscle/pattern/kind/difficulty/inventory/exclusions/duplicate rules. Full-plan movement/volume/recovery/duration/order revalidation;no prescription rewrites;real source coefficients,not assumed weights.
4. Real Nutrition same-role verified compatibility,quantities via existing solver/lattices,real before/after macro deltas;wrong-role/unknownreview/allergen/intolerance/pattern/exclusion must fail. UI5D later must round display,never fake similarity percentage.
5. Default swap-only keeps every other food byte-identical. Explicit bounded same-meal repair:replacement quantity locked,otherfoods≤1realstep;all changes listed;apply denies without explicit consent;no unrelatedmeal/day change. Exercise/fullplan invalid alternatives rejected.
6. Rename/reorder/meal composition/3–6meals/normalizedenergy5–50%+protein10–50%permeal distribution via prepare API;original target/answers/generation metadata preserved. Unsafe edited plan remains a local failed draft. Revision/signature0 forgery/stalecontext/catalog/user/profile/Trainer-link cases fail safely.
7. Optional editProvenance+Nutritionlayout JSON/backward decode then ACTUAL server save/readback/logout/reopen. JSON tests are not persistence. Five session adapters must pin expectedOwnerID and recheckmode;existing fresh repo/RLS and source read-back equality mandatory. Backend release gate OPEN,real catalog/RLS/current migration NOT VERIFIED. No production apply authorized.
8. Canonical Windows source regression:pwsh -NoProfile -File IOS_Client/scripts/validate-smart-plan-editing.ps1 -AllStatic.145smart/169Nutrition/110foundation/75Phase2/86Phase34/212Workout/202app current source checks PASS only. New baselines do not replace historical ones;explicit approved reverse patches verify old bytes.

NEXT:Mac native/real-data acceptance;NEW authorization before5D UI. No push/deploy/migration. All older backlog below retained.

LATEST: Phase5C Nutrition ENGINE source/hash checks PASS;overall PARTIAL.264 native test definitions (30 new Nutrition,N01–N16 included) NOT RUN. See the latest Phase5C section below and docs/COACH_NUTRITION_ENGINE_20261023.md. Earlier stop/approval notes are historical:5C engine is now authorized and implemented;5D UI still requires NEW approval. No backend/publishing authorization.

Checkpoint: 2026-10-23. Authoritative checkout: `.orchestrator/tmp/ios-client-sync-20260913`.

All native rows below are **NOT RUN / NATIVE ACCEPTANCE PENDING**. Windows source checks, color math and byte comparisons are not Swift compilation, rendered UI, accessibility or functional acceptance. There are 183 XCTest test definitions, including ten new Phase3/4 tests, and nine native preview specimens across Phases1–4. None has been executed here.

## Run on Mac first

Use this exact working tree including all existing uncommitted files, not a stale project mirror. Do not push automatically or apply migrations.

```sh
xcodebuild -list -project IOS_Client/GymManagerClient.xcodeproj
xcrun simctl list devices available
xcodebuild test -project IOS_Client/GymManagerClient.xcodeproj -scheme GymManagerClient -destination 'platform=iOS Simulator,id=<actual installed simulator UUID>'
```

Use the actual scheme returned by `-list` if it differs. Record Xcode/Swift/iOS SDK versions, device/OS, scheme, test count, failures and real screenshots. Compile the Widget extension as well. Simulator tests do not replace physical iPhone checks for ActivityKit, Health permissions, haptics and system gestures.

## Phase 1 — foundations

- Small 320pt, standard 375pt, Pro Max 430pt; default text and Accessibility3; portrait/landscape where supported.
- Three Foundation previews: semantic roles, surface hierarchy, local System/Light/Dark preference, Increase Contrast. These are specimens: app root deliberately remains Dark until Phase6 migration.
- Foreground/background appearance changes, text clipping/wrapping, VoiceOver focus/order and selected traits.
- Verify actual composited contrast. Legacy white-on-coral mathematical ratio3.27:1 remains an open debt; no whole-app contrast PASS.

## Phase 2 — training navigation and preserved behavior

- Three Training previews and real Activity/Palestra/Corsa/Riepilogo screens at all sizes, large text and long plan/session names. No overlap, clipped labels or compressed targets.
- Horizontal selector intrinsic text, scroll-to-selected and native button selected traits; calendar native DatePicker fallback when seven44pt cells do not fit and at accessibility sizes.
- Gym plan/session opening, including completed workouts; Recap periods/distance marker and Running GPS/no-GPS/partial records remain usable.
- Tab primary taps must have no delay. Optional hold0.45s then drag40pt: one step per fresh movement, no wrap, no activation on hold alone, cancellation keeps selection, one feedback per change.
- Test tab shortcut against back swipe, scroll, home indicator, keyboard, sheet dismissal and Dynamic Island/system gestures. VoiceOver/Switch Control keep individual labelled tab buttons. If it conflicts, remove the optional shortcut, not native tap/system behavior.

## Phase 3 — exercise detail and media

- Three Exercise previews plus actual planning/execution detail sheets: title → one Movimento/Muscoli module → prescription → real history → secondary notes. Small/large text, long technique/notes, missing metadata and empty history.
- Front/rear anatomy matches actual broad primary/secondary catalog roles; secondary pattern distinguishable without color. Unknown roles never become primary/secondary or activation percentages. Accessory classification is not available.
- No procedural robot movement; no unapproved clip plays. Real HTTPS video opens only on user action. Future local clip must pass `docs/EXERCISE_MEDIA_PIPELINE.md` quality/rights/native review before approval.
- Verify AVKit creation/cancellation, pause on rest/disappearance/Reduce Motion, no autoplay, no duplicate player, memory release. Playback/frame rate/thermal/energy/size comparisons are NOT MEASURED.
- History max-per-session labels, actual loads/notes, zero/one/multiple points; no fabricated PB, RIR or absolute load.

## Phase 3 priority addition — workout operation

- Start/resume existing session, one current set input, reps/load contextual keyboard, Done action, previous recorded load and prescription readable one-handed.
- Complete4→3→2→1→0; completed rows stay compact below current set and Undo works. Current input does not move down with each new history row.
- Note sheet save/cancel, technique detail and back, next exercise, all-exercise list including completed exercises. At session completion list items must still open their detail.
- Automatic rest start only when prescribed; no extra taps or second engine. Real completion counts/duration, quick feedback/save then summary/return to day.
- Verify existing local activity persistence after close/reopen; do not claim a new server logging contract. Existing data/permissions unchanged.
- Actual haptics for set/rest/workout, Reduce Motion, VoiceOver editing/feedback, Switch Control and44pt targets.

## Floating rest timer — blocking acceptance cases

- Drag within actual safe bounds on all devices/rotation, keyboard present/absent, tab bar/navigation bar, Dynamic Island/home indicator. Test detached/narrow viewport and nonzero geometry origin.
- Edge docking, remembered position across exercise navigation/detail/return, no jump while dragging. No overlap with active form, notes/detail/Undo, next/list/finish controls.
- When no safe circle position exists, a reserved native top accessory must remain reachable without covering content; it is not a duplicate timer. Tap controls must work in both forms.
- Root → full-screen workout → exercise detail → back: only top host draws circle/accessory/popup. Popovers close when host loses ownership; no stale accessory left underneath.
- Distinguish tap from drag; normal scroll/back/sheet/system gestures must win appropriately. VoiceOver value follows same clock, includes paused state; left/right controls offer non-drag movement.
- Pause/resume/+15/−15/skip, very short/zero rest, replacement by another set, Undo, finish, logout. Exactly one current timer and at most one ready popup. No endless00:00.
- Expiry haptic once, four-second nonblocking popup then collapse. Foreground sleep/reconcile/background/screen-lock timestamps must agree with wall clock; no local decrement drift.
- Background suspension may delay app callbacks. At return reconcile from endDate; do not assume code runs continuously while locked or killed.

## Rest Live Activity / notifications

- Build with current ActivityKit SDK and Swift concurrency checks, especially `update/end` SDK boundary and UserNotifications callbacks. Existing Run activity must remain unchanged.
- Start/update/pause/resume/adjust/skip/end; never duplicate rest activities. Compare actual lock-screen and supported Dynamic Island counters to app endDate.
- Activities disabled, already active at app launch, stale state, app backgrounded/killed, device lock/unlock, OS dismissal, low-power mode. Date-based label/staleDate is not proof of guaranteed wakeup or immediate automatic Activity end while app is killed.
- Running and Rest activities concurrently: no cross-type end/update. No fake action buttons or unsupported lock-screen control.
- Notification permission denied/not requested/provisional/authorized and sound disabled/enabled: no new permission prompt. One fixed request ID; pause/skip/logout/new rest cancels or replaces prior pending notification. Check cancellation/expiry race and no duplicate foreground sound/haptic.

## Phase 4 — Home and load lifecycle

- Header/profile/date/day status reads as one compact entry; workout/nutrition/appointments/agenda before secondary steps. Nutrition one-tap completion and all existing data/mode behaviors preserved.
- Cold launch/new login/restored session, slow session refresh, slow profile lookup, slow client link lookup and section network failures. Capture correlated DEBUG logs: `request_id`, stage, code and readiness booleans only. Never copy tokens/names/health payloads.
- Identify actual first failed prerequisite and why a second attempt succeeds: currently UNKNOWN, not proved fixed by source. Reproduce on device before closure.
- Assert no content requests before SDK session + verified identity, no view-owned bootstrap, no duplicate refresh on tab/nav return, correct single-flight and cancellation/stale-generation handling across logout/user change/trainer linking.
- idle/authBootstrap → loading, genuine loaded-empty, successful content, section error, partial success, explicit retry, subsequent recovery. No premature empty state, hidden real failure or silent automatic retry.
- Ready-state previous real error stays visible while explicit refresh runs; prior content retained only under same actual owner. Trainer link not altered by failed refresh.
- Health unavailable/denied/not-requested/authorized and demo labels; no fabricated step count or automatic new permission request. Existing Health refresh loop remains separate from Supabase content reads.

## Acceptance recording and stop rule

For each row record PASS/FAIL, real environment and evidence after execution. Resolve compile/runtime/accessibility regressions before accepting Phases1–4. Keep original source/static results separately. No Phase5 implementation, push, deploy, schema/RLS change or App Store submission is authorized by this backlog.

## New authorization65afee75 — Phase5A+5B coach, 2026-10-23

The new prompt authorizes LOCAL Phase5A+5B source work, superseding only the historical Phase5 stop above. It does not authorize publishing, production migration or Nutrition. Current checkpoint:5A contract/service/repository source implemented,5B engine/UI upgrade NOT STARTED. Seven new XCTest definitions (190 total) NOT RUN; previous183 remain pending, not reclassified PASS.

- Build/execute ClientWorkoutCoachEligibilityTests: owner denial before answer validation, missing/invalid input, continuity/RIR/progression-based level cap, explicit equipment, incompatible split and historical JSON decode.
- After real connection refresh, prior standalone plans remain read-only in history; new generation and both direct save entry points deny. Local merge test is NOT an end-to-end linking test.
- Save/reopen actual new JSON metadata without losing old optional fields. Wrong Auth user, inactive profile, missing profile and newly connected Client must fail safely. Preserve offline draft; never display server-confirmed from a local-only change.
- Production release gate: verify exact current RLS/select/insert/update/delete policies and existing20261004105732 migration state on uslkraelkdjrwqjisczz. MCP inspection denied; historically migration not applied. No apply authorization in this task. Repository preflight is not atomic protection against direct REST or link-vs-save races.
-5B BEFORE UI: define/run12 requested profiles and exclusions/metadata/IDs/determinism/volume/duration/ordering/progression validation matrix. At this checkpoint those generated-plan tests are NOT IMPLEMENTED/NOT RUN; no case01–12 PASS claimed.
- After engine source/testing AND NEW UI approval, integrate and verify wizard→preview→edit→save/activate→reopen, late Trainer connection, regeneration preserving answers, real catalog cache/empty/failure and no invented loads. Native real-device,VoiceOver,small/large text and Reduce Motion remain NOT RUN.

## Latest authorization —5B ENGINE ONLY, STOP BEFORE UI

Source upgrade and CASE01–CASE12 definitions now integrated;25 new engine XCTest definitions (215 total native definitions), all NOT RUN. Source/hash110/110 and app202/202 checks PASS, not Swift behavior. See docs/COACH_ENGINE_TEST_MATRIX_20261023.md for exact profiles/assumptions/expected assertions.

- On Mac compile app/test target and run ClientWorkoutCoachEligibilityTests, ClientWorkoutCoachEngineTests, adapted guided ClientPhase1Tests and all regressions. Record actual case results, not presence of a test method. Check current Xcode concurrency settings too.
- Validate actual catalog association roles, stored coefficients, difficulty/source keys and admissible equipment. Local fixture30 reviewed references are NOT evidence of live catalog completeness. Sparse/missing metadata must reject safely.
- Verify fixed-input programming signatures across repeated runs/process launches/catalog order, same variation, no random kilograms, new persistence UUID per created instance.
- Verify all12 cases, strict tamper rejection, custom split, budget/weekly volume/order/recovery and qualitative missing-secondary handling. Test true novice without compound familiarity (may safely reject unavailable reviewed hinge), floor-only unsupported catalog and empty/malformed cases.
- Double progression: real completed reps/load/RIR required. Current execution logs have no real RIR; do not synthesize it from target or notes. No runtime adapter/UI authorized in5B.
- Keep backend gate OPEN until actual Auth/RLS, standalone/connected race and real save/reopen/history verified. Existing migration state NOT VERIFIED, no production apply authorized.
- STOP before UI. Existing wizard was intentionally not edited and does not gather all required5A evidence. Integrating questionnaire/preview/edit/save/progression needs NEW user approval; engine/native failures may be resolved first without UI.

## Latest approval2cce4455 —5A+5B UI integration SOURCE COMPLETE

This approval supersedes ONLY the historical UI stop above. No Nutrition/production/publication authorization.214coach UI source/hash+202fullapp static PASS, NOT native evidence.19new integration tests/234total native definitions,3Coach previews:NOT RUN.

1. Run xcodebuild list/test with actual scheme/simulator for exact dirty working tree; build Widget and all234definitions. Preserve original CASE01–CASE12. Check Swift6 actor/Sendable/type inference and Form/Picker APIs against installed SDK; no source check substitutes compilation.
2. Render actual Coach wizard 320/375/430pt,portrait/landscape,Dark/Light specimens,AX3,ReduceMotion,VoiceOver/SwitchControl. Capture Simulator screenshots,never browser mockups. Verify native keyboard Done/safe-area CTA/error focus,all labels/44pt,no truncated selected options. Full app Light migration still parked.
3. Empty required choices must block generation; explicit zero/No retained. Experience cap cannot be raised arbitrarily. Back and frequency4→2→4 preserve answers/custom groups. Invalid split disabled/explained; Decidi tu only on explicit choice.
4. Verified catalog only; unsupported equipment hidden,home inventory explicit,empty/sparse/conflicting metadata safe rejection,forceReload retry once on user action. Exclusions real UUIDs searchable,duplicate/conflicting identities never crash List. No private Trainer catalog exposure.
5. Local generation message,one in-flight request,typed corrective errors preserving all answers;actual preview level/split/durations/reasons/prescriptions. No version/fingerprint/raw technical issue IDs or invented load/percentages.
6. Same existing editor:rename/reorder/calendar/set/reps/rest/RIR/notes;eligible replacement only. Hard-invalid equipment/exclusions/duplicate/coverage/volume/duration/order/recovery prevents save;no View overrides. Change presentation names without false strict-generation rejection. Invalid edits stay visible/recoverable,never auto-normalize existing prescriptions.
7. Save states:localDraft/saving/confirmed/failure. Explicit active/draft consequence,archives+newplan atomic write/read-back. Offline failure retains existing local copy but NEVER says server-confirmed. Demo says local demo. Fine only after confirmation. Payload generator metadata survives actual reopen; JSON-only test is not backend persistence.
8. Wizard/editor opened as A→loginB,logout/inactive profile,late Trainer connection before Save and during await:deny safely,preserve original history,do not write under B. Verify actual backend RLS/directREST/link-vs-save races separately with approval. UI/session/repository checks alone do not close backend gate.
9. Historical optional-less plans decode/read,connected history read-only,manual creation unchanged. No Nutrition/Desktop/timer/query regressions;prior Phases1–4 native backlog still applies.
10. Backend gate OPEN:production catalog/RLS/current migration state not verified;no deployment/apply authorized. Antigravity analysis FAILED authentication,not a successful visual review. Native first-load/appearance/contrast debts remain open.

NEXT EXACT STEP:execute this native matrix;wait for user approval before Nutrition5C+5D. No push/deploy/production migration.
# Latest approvalc426d4fd —Phase5C Nutrition ENGINE SOURCE, STOP BEFORE5D

Overall PARTIAL;source/hash checks PASS only.30new Nutrition native test definitions,N01–N16 included,total264,ALL NOT RUN on Windows. Report:docs/COACH_NUTRITION_ENGINE_20261023.md. Prior Workout/Phases1–4 backlog below remains.

1. Exact current worktree on Mac:xcodebuild -list -project IOS_Client/GymManagerClient.xcodeproj;resolve actual scheme/device,build app+widget,run all264definitions. Check Swift6 type inference/Sendable/Foundation/CryptoKit/optional-Codable compatibility. No test-presence assertion substitutes XCTest.
2. Run ClientNutritionCoachEngineTests N01–N16 plus14arithmetic/safety/portion/tamper/legacy tests and existing ClientNutritionCreationTests. Fixtures are synthetic/test-target-only,not USDA/CREA integration.
3. Validate repeated/permuted catalog structural SHA256 signatures including dietary/allergy/ID constraints;1/7days,3–6meals,variation,rawRMR/final10kcal precision,real piece lattices. Inputs/unsupportedextremes/lowrelativeweightCut/clinicaldecls/missing/NaN fail safely. Benchmark bounded solver on device;generation must later be off-main actor in5D if necessary.
4. Real global food_references schema/projection matches existing external_food_id/source_url/updated_at. Manual search still works with missing/malformed nutrition_coach_review;NO automatic food admitted without complete source-grounded review matching source/cache revision/serving basis. Review allowed meals/roles/portions/patterns/14allergens+traces/two-intolerances upstream;no fabricated safe tags or test fixture promotion. Real CREA/USDA/OFF APIs/cache integration NOT RUN.
5. Validate current Auth/profile/Trainer-link ownership,RLS/select/insert/update/delete/directREST/link race with separate read/test authorization. Existing20261004105732 historical migration not applied,current NOT VERIFIED;no productionapply authorized. BACKEND RELEASE GATE OPEN,not closed by app preflight.
6. Real standalone generated save→server metadata/food snapshot readback→logout/reopen exact payload. JSON roundtrip alone not PASS. Inactive/wrongAuth/Trainer-connected deny before persistence;midawaitlink race must be denied by backend. Preserve manual/history/offline drafts. Confirm archive+newplan transaction and catalogrevision-mismatch failure remain honest;never auto-rewrite historical food snapshots.
7. Do not start UI5D/new preview/wizard yet. Legacy owner-less generation deliberately fails required-profile gate;old estimate-only API/manual/history kept.5D needs NEW user approval and actual-session generation adapter;must reconcile typed profile with legacy fields and revalidate edits. No release/push/deploy/productionwrites.
