# GymManager — Exercise intelligence, anatomy and recovery

## Production follow-up — 2026-10-08 08:33:35 UTC

User explicitly authorized the single difficulty migration. APPLIED AND VERIFIED on uslkraelkdjrwqjisczz, history 20261008083201 / exercise_difficulty_levels (local file 20261008074659_exercise_difficulty_levels.sql). 27/27 public persisted classifications: beginner 17, intermediate 9, advanced 1. All 337 private entries and old content/IDs/RLS/grants/owner/triggers remain unchanged; validated nullable text/check/default NULL confirmed. Only existing advisor warnings remain, no new finding. Other migrations/Edge Functions/Git publishing NONE.

Difficulty DATABASE LEVEL is now structurally verified, not pending authorization. Native build/136 XCTest/device and actual generator/save/reopen acceptance still NOT RUN. Do not reapply difficulty. Earlier standalone RLS restriction still not authorized. Audit in projects/GymManager/docs/EXERCISE_DIFFICULTY_PRODUCTION_20261008.md. The initial local report below is retained history; its unapplied/approval-pending difficulty statements are superseded by this update.

## Initial local implementation checkpoint (historical)

Date: 2026-10-08. Status: LOCAL IMPLEMENTATION / NATIVE AND DATABASE ACCEPTANCE PENDING.

Authoritative repository: `.orchestrator/tmp/ios-client-sync-20260913`, source `IOS_Client/`, main base `49e67c8`. Do not copy from stale `projects/GymManager/IOS_Client/`. Prior refresh and creation-wizard changes are preserved, not republished or discarded.

## Scope and sequential implementation

1. Actual exercise schema/catalog, existing generator, Desktop WorkoutAnalysis/Body Map and Git/handoff inspected first.
2. Technical difficulty model, local additive migration, generator compatibility/ranking and GymManager branding.
3. Shared catalog muscle DTO/mapping, anatomical front/rear detail and safe native motion reuse.
4. Recovery model and distinct nonblocking native controls.
5. Independent source review, corrections, source checks and safe handoff.

Desktop and Trainer iOS application code were not changed. The only new Desktop-path artifact is a local migration for the shared exercise catalog. No commits, pushes, deployments, database data changes, credentials or signing changes.

## Technical difficulty

- Optional persisted `difficulty_level`: beginner, intermediate, advanced; NULL means not reviewed.
- Definition: technique/coordination/stability, not kilograms, medical suitability or risk diagnosis.
- Stored difficulty overrides historical compatibility hints and survives the normal workout payload/snapshot conversions.
- Beginner prefers simple choices, can use intermediate where compatible, never automatically advanced. Intermediate uses beginner/intermediate. Advanced retains all levels rather than favoring complexity.
- Unknown level is excluded from automatic generation, not silently labelled beginner. Unclassified catalog primary roles are also excluded from automatic generation.
- Existing muscle/pattern/equipment/priority/weekly-use ranking is preserved; deterministic variation remains, not random selection. Compound movements precede accessories/isolation without disturbing equal-kind selection order.
- Historical name-rule hints remain explicitly legacy compatibility, not persisted server classification.

## Database inspection and local migration

Confirmed read-only production project: `uslkraelkdjrwqjisczz`.

Actual catalog: 27 public system exercises, 337 Trainer-owned exercises. No `difficulty_level` column existed at inspection. The new file is:

`projects/GymManager/Desktop/supabase/migrations/20261008074659_exercise_difficulty_levels.sql`

CREATED: YES. APPLIED LOCAL: NO. APPLIED PRODUCTION: NO. DATA MUTATIONS: NONE. EDGE FUNCTION DEPLOY: NONE.

Migration uses nullable text plus three-value check, no default, transactional additive schema change and exact-ID seed for 27 reviewed public entries. Trainer-owned variants stay NULL until owner/technical review; no bulk name-based classification. No RLS/grants/ownership changes. Read-only verification of seed identifiers: 27 entries / 27 matching system IDs / 27 distinct IDs. This does NOT prove DDL execution or RLS acceptance.

Only apply selectively after explicit authorization and a fresh project/schema/history preflight. Do not run indiscriminate `supabase db push`, overwrite private classifications or repeat unrelated migrations.

## Shared muscles and anatomical detail

- Both personal/system and professional exercise reads use the same catalog decoder and embedded `exercise_muscle_groups` / `muscle_groups` associations.
- Canonical mapping matches Desktop's 11 group axes and aliases; old Codable region raw values remain compatible. `upperBack` maps to `upper_back`, `hamstrings` to `posterior_chain`.
- Actual relevance coefficients in 0...1 are retained and multiplied by sets for weekly equivalent volume, matching the catalog branch of WorkoutAnalysis. Invalid coefficients are not normalized or converted to guessed percentages; duplicate associations are ignored.
- Missing primary IDs remain explicitly unclassified. Catalog associations override name-based anatomy guesses in both normalization branches.
- Legacy snapshots with no relational metadata retain their prior fallback; these are not claimed to be authoritative measured data.
- Distinct anterior/posterior vector anatomy includes pectoral contours, deltoid contours, central back/trapezius, lats, arms, neutral forearms, abdomen/obliques, glutes, thighs and calves. Text keys explain the illustrative regions.
- Actual highlighting resolves whole catalog groups only: principal red, secondary amber, unknown/neutral gray. Granular subdivisions are illustrations, not claims that individual fascicles were measured or assigned.
- Real per-fascicle mapping: NOT IMPLEMENTED because the catalog has no granular identifiers. Activation percentages: NOT IMPLEMENTED. No 70/20/10 or invented values.
- Current RLS permits system associations but does not expose private Trainer muscle associations to assigned clients. This policy is preserved. Private assigned details can therefore use legacy fallback; exact association parity cannot be claimed until separately authorized, narrowly scoped RLS work and real-client testing.

## Exercise UI and animation

- Tap an exercise name during execution to open native detail: prescription, operational notes, motion, front/rear anatomy and available personal note.
- Compact execution preview links to full anatomy rather than stacking a tall duplicate map above series controls.
- Existing ten lightweight native Canvas motions are retained. Six requested examples resolve existing supported motions: Panca piana, Squat, Lat machine, Shoulder press, Curl manubri, Push down al cavo.
- Unsupported variants (including push-up, trazioni, French press, chest press and incline bench) do not reuse misleading bench/cable motions; they show static guidance and technique instead.
- No generated exercise imagery or invented media. Controls support Reduce Motion and accessible pause. Animations pause during recovery.
- Native animation smoothness and actual anatomical visual acceptance still need iPhone QA; source matching is not a substitute.

## Rest timer

- Dedicated elevated card, cyan accent from the existing palette, circular countdown and compact exercise/next-set/repetition target.
- Minus/plus 15 seconds, pause/resume and skip; no blocking overlay. Notes, scrolling and navigation remain available.
- Timestamp deadline remains the authority. Optional start/duration fields persist the ring denominator and preserve old payload decoding; old timers without duration show the correct countdown without an invented progress fraction.
- Pause retains remaining time; resume establishes a new deadline. Adjustments cannot produce negative remaining time. Completing another set replaces the old recovery; all-completed workouts do not retain a previous timer.
- Foreground and execution re-entry reconcile elapsed deadlines. Completion clears state before emitting haptic, preventing repeated finish events. Ready feedback is separate and dismissible.
- Timer state persists through existing per-user activity storage. No new backend table or second workout logging system.
- OS suspension does not invalidate the timestamp countdown; a background haptic at the precise deadline is NOT promised. No new background notification/Live Activity for recovery was implemented.
- Background/resume, app relaunch, Dynamic Type and compact-device usability: NOT RUN on this Windows host.

## Files

New current-task iOS files:

- `GymManagerClient/Core/ClientExerciseDifficultyPolicy.swift`
- `GymManagerClient/Core/ClientCatalogMuscleMapping.swift`
- `GymManagerClient/Features/Workout/ClientAnatomyMap.swift`
- `GymManagerClientTests/ClientExerciseIntelligenceTests.swift`
- `GymManagerClientTests/ClientRecoveryTimerTests.swift`
- `IOS_EXERCISE_INTELLIGENCE_REPORT.md`

Modified for this task:

- Core: `ClientModels.swift`, `ClientPersonalContent.swift`, `ClientPersonalRepository.swift`, `ClientRepository.swift`, `ClientWorkoutGenerator.swift`, `ClientManualWorkoutDraft.swift` (previously untracked), `ClientActivityModels.swift`, recovery methods in `ClientSessionStore.swift`.
- Workout: `ClientExerciseVisualModels.swift`, `ClientExerciseVisualCard.swift`, `ClientWorkoutExecutionView.swift`, catalog payload in `ClientPersonalWorkoutView.swift`, labels in `ClientGuidedWorkoutView.swift`.
- Branding/foreground: `App/ClientTabView.swift`, `ClientOnboardingView.swift`, `ClientAccountView.swift`, `Resources/Info.plist`.
- Tests: `ClientPhase1Tests.swift` variant fallback expectation, `scripts/validate-client-ios.ps1`.
- Shared local migration above; root/project `CODEX_HANDOFF.md`; delegation record `GYM-IOS-EXERCISE-REVIEW-20261008-001.md`.

Other dirty/untracked files belong to preceding refresh/creation tasks and were preserved. No dependency, bundle identifier or signing modification introduced here.

## Delegation and Codex review

Internal Codex `/root/anatomy_timer_plan`: two genuine read-only passes, no files modified by agent. Initial UX/lifecycle findings integrated. Final review found missing-role secondary mislabelling and a catalog/legacy precedence defect; both corrected by Codex and covered with native regression definitions. ACCEPTED source advice, not runtime acceptance. External Gemini/Antigravity NOT RUN for this task; no fake delegation or external source export.

## Tests

| Check | Actual result |
|---|---|
| Windows source/XML/project assertions | 186/186 PASS after final source edits |
| Git diff whitespace | PASS |
| Public migration seed identifier match, read-only | 27/27 PASS |
| Native XCTest definitions | 136 defined, NOT RUN |
| New intelligence tests | 11 defined, NOT RUN |
| New recovery tests | 5 defined, NOT RUN |
| Swift typecheck / Xcode build | NOT AVAILABLE on Windows |
| Actual database classification and generated-plan save/reopen | NOT RUN |
| SQL migration execution / SQL tests | NOT RUN |
| Device anatomy/animation/accessibility/timer background | NOT RUN |

Source assertions validate presence/structure, not native compilation, algorithm execution, persistence or visual rendering. Do not present those checks as end-to-end PASS.

## Required final status

- APP NAME: GYMMANAGER.
- EXERCISE LEVELS / GENERATOR USES LEVEL: locally implemented; native acceptance pending.
- DATABASE LEVEL: PENDING — migration unapplied, private variants unclassified.
- RANDOM SELECTION REMOVED: source PASS — deterministic ranking preserved, no random selection added.
- ANATOMICAL DETAIL: local front/rear implementation; device acceptance pending.
- ANIMATION: existing supported motions preserved; unsupported variants static; native acceptance pending.
- MICRO MUSCLE MAPPING: NOT IMPLEMENTED in data; illustrative anatomy only.
- PERCENTAGES: NOT IMPLEMENTED, no invented values.
- REST TIMER REDESIGN / DISTINCT RECOVERY STATE: local implementation; device acceptance pending.
- BACKGROUND SAFE TIMER: timestamp implementation, actual background test NOT RUN.

## Next exact step

1. Request explicit authorization for selective `20261008074659_exercise_difficulty_levels.sql` on confirmed `uslkraelkdjrwqjisczz`; do not include prior standalone restrictions implicitly. Recheck schema/history before any DDL and verify post-migration null/private preservation and security after approved application.
2. On Mac use this authoritative source, open `IOS_Client/GymManagerClient.xcodeproj`, build `GymManagerClient`, run all 136 XCTest definitions, fix any real compiler/runtime failures. No push is currently authorized.
3. Device QA six exercise examples plus unsupported fallback and missing-role data; verify detail tap, notes, Reduce Motion/VoiceOver and 120-second timer background, pause, +/-15, skip, tab navigation, relaunch, single haptic/ready transition.
4. Test persisted catalog levels and real standalone generation/save/reopen/edit against approved backend, and confirm professional plan reads do not regress. Private association access requires a separate scoped authorization/proposal, not open RLS.

Previous creation-flow RLS approval and real save/reopen acceptance remain pending. Desktop 0.1.20 release is already complete and must not be repeated.
