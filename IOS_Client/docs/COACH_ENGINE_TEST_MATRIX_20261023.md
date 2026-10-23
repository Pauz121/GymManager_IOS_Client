# Phase5B coach engine — test matrix and release gate

2026-10-23. ENGINE SOURCE checkpoint, BEFORE UI. Native Swift/Xcode/Simulator unavailable on this Windows host. All behavioral cases below are DEFINED / NOT RUN, not PASS.

## CASE01–CASE12

| Case | Input / assertion | Native result |
|---|---|---|
| CASE01 | Beginner,2 days,45min,full gym,hypertrophy; valid Full Body | NOT RUN |
| CASE02 | Beginner,3 days,60min,explicit floor/dumbbells/bench; compatible actual catalog variants | NOT RUN |
| CASE03 | Intermediate,4 days,60min,chest priority; coverage/volume/order/budget | NOT RUN |
| CASE04 | Intermediate,5 days,75min,back priority; hybrid PPL/Upper/Lower | NOT RUN |
| CASE05 | Advanced,5 days,90min,shoulder priority; bounded volume | NOT RUN |
| CASE06 | Advanced,6 days,60min,explicit PPL; movement/recovery | NOT RUN |
| CASE07 | Beginner,3 days,30min,floor+dumbbells; compact sessions | NOT RUN |
| CASE08 | Actual bench ID and exact incline name excluded; never selected | NOT RUN |
| CASE09 | All exercises excluded; explicit noCompatibleExercises, no fake fallback | NOT RUN |
| CASE10 | Trainer-connected context; denied before generation | NOT RUN |
| CASE11 | Generate standalone then deny connected creation; original JSON plan unchanged | NOT RUN — pure preservation unit only, NOT real linking/RLS |
| CASE12 | Seven days invalid; reject without clamping | NOT RUN |

Positive cases use the real Swift generator, repeat generation, compare structural signatures and invoke strict catalog-aware validation. Additional tests cover evidence downgrades, context-aware four-day strategy, custom split, bulk/cut, reordered catalog, same variation, wrong metadata/IDs/equipment, malformed reps, invalid days/volume/duration/order, missing coefficients and double progression. 25 new engine tests plus7 existing5A tests;215 total native definitions across app. None executed here.

Fixture content is SYNTHETIC, not a production seed or an assertion about live rows. Imported-variant test UUIDs and stored test coefficients exist only in the test target. Runtime generation retains actual catalog IDs. Thirty reviewed legacy ID/import source-key references were checked read-only against original local migrations; current production presence/roles/difficulty remains UNKNOWN.

## Implemented source contract

- Existing ClientWorkoutGenerator upgraded, not a second generator. Existing plan/source/payload/progression reused.
- Effective experience from total/recent months, recent frequency, compound/RIR/progression familiarity, capped by perceived level. Thresholds are conservative product rules, not diagnosis.
- Beginner selection prefers stable beginner variants. Reviewed intermediate fundamentals require declared compound familiarity for self-capped beginners; advanced variants denied unless effective advanced. Not equivalent to in-person technique clearance.
- Exact ID OR exact import source key PLUS exact normalized name establishes local pattern/kind/equipment review. Actual muscle roles/coefficients come only from catalog associations. Unknown/conflicting rows fail closed. Home variants require explicit source-key review, not generic legacy equipment assumptions.
- Leg curl is NOT relabelled as a hip hinge in the new admission list: current taxonomy has no knee-flexion case. Excluded rather than misclassified; old shared display normalizer remains unchanged.
- Explicit preferences Full Body/Upper-Lower/PPL/custom; automatic strategy additionally uses duration/level/goal/priorities. Three-day hybrid UL+FB, four-day Torso/Arti for appropriate advanced context, five-day PPL+UL, six-day PPL. Incompatible/missing custom split denied.
- Deterministic bounded scoring, sorted group/catalog IDs and stable tie-breaks. Three attempts max; bounded set calibration. New plan/session/exercise instance UUIDs and timestamps remain fresh intentionally, to avoid historical overwrite.
- Structural signature compares ordered catalog IDs, day, sets/reps/rest/RIR. It is not cryptographic auth, full JSON equality or reuse of persistence identity.
- Volume: actual stored coefficient × programmed sets; when a primary coefficient is missing, count primary sets. Missing secondary coefficients produce separate qualitative exposures ONLY, no invented half-sets/accessory percentages.
- Time/experience-aware central primary targets:4 at30min,6 beginner,10 otherwise; priority+2; cut−1, bulk+1 only nonbeginner>=60min. Targets yield to real time/weekly ceiling, not guaranteed optimal volumes. Main weekly floors2/3/5 for30min/beginner/other; ceilings22,priority24. Coverage alone is not numeric volume sufficiency.
- Duration estimate includes5min preparation,45sec/set, actual between-set rest,75sec exercise transitions. Reject over budget, not a measured duration/fitness prediction. Default4/5/6 exercises by duration, beginner capped at5; never add9–12.
- Compound before accessory/isolation, primary priority within class, required compound push/pull/knee/hinge, bounded repeated patterns, adjacent-heavy-primary check including week wrap. Limited catalog may make a requested combination infeasible; return explicit failure, never invent coverage.
- Reps4–6 strength compound or6–10 compound,8–12 accessories,10–15 isolation. Rest180/150 compound,105 accessory,75 isolation. Initial RIR3 beginner/2 other, no generated kilograms.
- Strict validator: answer/ownership service contract, actual IDs/names/roles/coefficients/pattern/level/equipment/exclusions, blueprint/day, duration, duplicates, prescription, ordering, coverage/volume, movement/recovery, metadata/source/length. Validation cannot replace Auth/RLS.
- Version coach-workout-2.0.0; metadata includes effective level/strategy/rationale/estimated durations/catalog fingerprint and persisted answers/program duration.
- Double progression is a pure qualitative decision requiring every set's actual reps/load/RIR at the same load. Complete top range at prescribed RIR suggests increase; incomplete evidence collects more; no kilogram increment invented, no automatic write. Existing execution logs have NO real per-set RIR, so runtime adapter must NOT fabricate it.

## Actual checks / limits

Source/hash110/110, app static202/202, Git whitespace PASS. These detect source contracts/regressions, not Swift compilation or generated-plan behavioral success. Original display normalizer,60 protected source files,3 original timer/query/Nutrition fragments and the5A service/repository/domain/contract/wizard checkpoint remain unchanged by5B. Existing guided tests updated to explicit reviewed fixtures/evidence; floor-only bodyweight now expects safe rejection when pulling/hinge coverage is unavailable, not fictitious compatibility.

Native compile/test/performance, actual catalog generation, save/reopen and real standalone→Trainer transition: NOT RUN. CASE02 fixture is a self-capped beginner WITH compound familiarity; true novices with no compatible reviewed hinge may be rejected. No UI changes: old wizard does not collect all5A required evidence and is NOT release-ready with the stricter engine. UI/edited-plan validator/progression adapter integration is a separate approved phase.

BACKEND RELEASE GATE: OPEN. Current Supabase catalog/RLS not verified (previous MCP read-only permission denied). Existing restrictive migration20261004105732 historically unapplied; no inference of current production state. Repository preflight is not atomic RLS/direct-REST protection. No DB/migration/remote data writes, push or deploy in5B.

NEXT EXACT STEP: on Mac run real Swift tests/build for this exact working tree, resolve actual failures, record case results; UI integration only after NEW user approval. Do not redo5A/audit, replay remote repairs or modify Nutrition/Desktop/body map.
