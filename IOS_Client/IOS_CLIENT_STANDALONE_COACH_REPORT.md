# IOS_Client — Standalone Workout Coach, Phase5A+5B

2026-10-23. Scope: existing Client SwiftUI app only. Native build/tests NOT RUN on Windows. No Nutrition engine, previous-screen redesign, push, deploy or production migration.

## Audit BEFORE implementation

EXISTING WORKOUT CREATION FLOW: Palestra → personal library → creation choice → manual wizard or ten-step guided questionnaire → preview → same plan editor → save confirmed by server read-back.

EXISTING MANUAL CREATION: ClientManualWorkoutWizard/ClientManualWorkoutDraft,2–6 days, real catalog, groups/exercises/order/prescription; no mandatory creation load. Preserve it.

EXISTING AUTO GENERATION: ClientWorkoutGenerator is already rule-based, with normalized catalog, split blueprints, scored selection, prescriptions, validation and double-progression text. Evolve this implementation; no parallel Workout domain or LLM service.

EXISTING TRAINER RESTRICTION: ClientAccessPolicy and SessionStore save methods deny connected users; previous plans remain in personal library read-only. Repository currently relies on RLS, without its own session/standalone preflight. Existing local migration20261004105732 adds owner SELECT and standalone-only writes; earlier handoff says APPLIED PRODUCTION:NO. Do not assume deployed.

EXERCISE CATALOGUE: public system-only exercises query, actual UUIDs/source_key, associations and stored relevance, real video/instructions and optional difficulty_level; cached up to500 rows. Remote catalog size and current production RLS cannot be verified: Supabase MCP read-only inspection returned permission denied. No alternate credentials/path used to bypass that denial.

AVAILABLE METADATA: UUID/name/source key, catalog muscle IDs/known primary-secondary roles/relevance, optional server difficulty, existing local normalizer pattern/kind/coarse equipment fallback.

MISSING METADATA: structured server equipment/pattern/kind/learning-demand fields are not decoded; some difficulty/primary/coefficient records may be absent. Existing substring aliases can mark unknown equipment as all equipment, or confuse variants. Generator must not treat inferred unknowns as reliable. Local exact-key/variant review may supplement metadata with explicit provenance; otherwise exclude and explain, never invent IDs or clinical adaptations.

EXISTING VOLUME ANALYSIS: stored coefficients used when available; legacy fallback invents half secondary sets. Replace only standalone generation analytics with primary-set count plus explicitly separate secondary exposures when coefficients are absent. Do not change WorkoutAnalysis/Desktop/body map.

EXISTING PROGRESSION: double progression text and duration already persist; no measured-RIR-based decision service. Do not increase actual loads automatically.

FINDINGS: input silently clamped; level only self-reported; auto split only frequency; identity UUIDs/timestamps random while prescription sorting is partially locale-dependent; duration allows18min overrun; validation lacks actual catalog-ID/exclusion/rep/RIR checks; no generator version/explanation; save stages local activation before server confirmation (existing offline retention), so never claim backend confirmation from UI alone.

DATA MODEL REUSE PLAN: keep ClientPersonalWorkoutPlan/Sessions/Exercise and existing source.manual/guided, payload JSON and confirmed read-back. Add optional versioned generation metadata/experience evidence for backward decode compatibility, preserve historical plans and versions. Table source self_created remains existing storage category; payload source.guided distinguishes guided origin without schema change.

## Unified sequential roadmap

1.5A: typed eligibility/answers/experience evidence/input validation/result metadata; session generation gate + repository standalone/session check; ownership/history and compatibility tests.
2.5B engine: auditable catalog admissibility; effective level; limited context-aware split strategies; deterministic selection/order/volume/duration/prescription/progression; strict plan validator and representative XCTest matrix BEFORE UI.
3. UI integration: evolve existing progressive wizard/preview/editor/save; truthful explanation, validation/recovery, dynamic ownership recheck. No empty parallel editor.
4. Validation: source regressions + exact65-file baseline/5allowed scope, native backlog and final report/handoffs. Actual Mac and production save/RLS tests remain NOT RUN if unavailable.

## Skills actually read/applied

UI/UX Pro Max: clear validation/recovery/44pt/native semantic controls; focused search returned useful recovery and web error-summary guidance. ACCEPT recovery; MODIFY ARIA to native accessibility, no CSS. interface-design: one focal job, compact sections, shared tokens; MODIFY to existing SF/ClientClay, no new aesthetic. design-ios-interfaces: sheets/stack/safe areas/progressive states; ACCEPT. implement-swiftui-ios: local draft state, semantic controls/previews/ReduceMotion; ACCEPT. review-hig-compliance: separate source from native evidence; ACCEPT. ux-heuristics: recognition/control/preserve answers; MODIFY score requirement because no rendered/native user evidence. Impeccable native/adapt: preserve identity and native behavior; ACCEPT native subset, no fake browser iOS rendering. Supabase: actual session/ownership and RLS defense in depth; ACCEPT, remote permission denial explicitly recorded.

Installed skill search found no verified fitness/workout-programming/recommendation/rule-engine/testing specialist SKILL.md in project/global user skill inventories. None invented or installed. Official ACSM2026 guidance checked as general healthy-adult context; product rules and conservative bounds are configurable engineering decisions, not medical clearance or claims of an optimal clinical prescription. [ACSM2026 overview](https://acsm.org/resistance-training-guidelines-update-2026/).

## State

Audit/checkpoint complete; implementation IN PROGRESS. Baseline65 current source files captured before first app edit, five explicitly authorized existing modules. All prior dirty work preserved; main49e67c8, stagedNONE. Runtime/build/real save/reopen/RLS acceptance NOT RUN. Database/migrations created/applied:NONE; no production query succeeded.

## 5A checkpoint — contract and ownership

Typed ClientWorkoutGenerationEligibility distinguishes unauthenticated/Trainer-managed/missing answers/invalid frequency-duration-length/experience/split/professional-assessment/catalog failures. Required evidence includes total months, recent continuity/frequency, compound familiarity, RIR and progression familiarity. Classification is a documented conservative product rule capped by the perceived level, not medical clearance. Historical optional fields decode nil, but new generation must answer them explicitly. Healthy-adult acknowledgement and limitation guard remain separate from exercise exclusions.

Session generation entry resolves the current verified identity, not a UI mode flag. Existing save guards preserved; repository now independently checks actual SDK session, matching user, active Client profile and absence of Trainer link before workout upsert. This is defense in depth, NOT a replacement for RLS or an atomic link-vs-save authorization guarantee. Existing selective restriction migration is still DOCUMENT ONLY / NOT APPLIED by this task; production confirmation/authorization is an OPEN release gate. Prior personal history merges/read path retained; generated metadata is optional in existing JSON payload and included in server read-back comparison.

Validation initially70/70 source/hash checks; three additional exact original fragments now protect all session workout/timer/read code from beginWorkout onward, repository content/Nutrition queries from activeWorkoutPlans onward and the whole food/Nutrition domain tail.202/202 full app static and Git whitespace PASS. Seven new XCTest definitions (190 total) NOT RUN. Source UI is intentionally not switched yet; engine/tests must precede UI. Next macro-phase: catalog/level strategy/generator/validator tests. New source changes remain limited to five allowlisted modules plus new contract/tests/docs.

## Historical5A output / safe checkpoint (superseded by5B below)

PHASE:5A+5B. STATUS:PARTIAL.5A typed contract/service preflight implemented locally, not end-to-end accepted.5B engine/classification integration/strategy/strict catalog-aware validator/versioned explanations/progression decision and UI integration NOT COMPLETED. Existing generator/manual flow preserved, not replaced or falsely presented as the new engine.

CASE01–CASE12 generated-plan acceptance:NOT RUN, new representative matrix still to be implemented. Existing historical tests are not fresh evidence of new constraints. Native compile/Xcode/Simulator/VoiceOver/actual save/reopen:NOT RUN. Catalogue production size:UNKNOWN. Remote RLS/security acceptance:NOT VERIFIED, permission denied. Backend change requirement: existing restrictive migration must be verified/applied only with separate authorization; no new migration created/applied here. Database data mutation/deploy/push:NONE.

MAC ACCEPTANCE BACKLOG:UPDATED with5A tests and pending5B/release gate. NEXT EXACT STEP: implement/test existing generator upgrade before changing the wizard. Read latest app handoff and preserved preimages; do not repeat full skill/audit discovery or touch prior phases. Nutrition5C+5D remains parked pending separate future approval.

## Historical5B ENGINE + TEST MATRIX checkpoint — UI subsequently authorized below

PHASE5B ENGINE STATUS:PARTIAL — source integrated, native execution/compile and live catalog/save/RLS not verified. Existing ClientWorkoutGenerator upgraded; four scoped pure support files separate exact catalog admission, shared generation rules, strict validator/volume and progression decision. No second Workout domain, dependency, LLM or UI implementation.

CASE01–CASE12 defined in ClientWorkoutCoachEngineTests;25 new native engine tests,215 total app definitions, ALL NOT RUN. Existing guided regression tests now provide required evidence and reviewed catalog fixture; floor-only unsupported bodyweight explicitly rejects. Full case/rule/provenance/limitations report: docs/COACH_ENGINE_TEST_MATRIX_20261023.md.

LEVEL CLASSIFICATION:evidence-capped product rule integrated. SUPPORTED SPLITS:FB,UL,PPL,hybrids,validated custom. VOLUME MODEL:time/level targets and weekly floors/ceilings, priority+2, moderate cut/bulk modifier. INDIRECT VOLUME:stored coefficients only; missing secondary coefficient qualitative, not0.5. ADMISSIBILITY:30 exact locally reviewed IDs/source variants plus actual roles; unknowns excluded. Leg curl excluded from new admission rather than incorrectly called a hinge. DETERMINISM:stable structural specification, fresh persistence instance IDs intentional. VALIDATOR:strict actual-catalog/source/day/prescription/budget/volume/metadata gate before return. PROGRESSION:pure complete actual-set/RIR decision, no fabricated load; execution logs do not yet supply RIR. GENERATOR VERSION:coach-workout-2.0.0.

Fresh110/110 coach source/hash checks,202/202 app static, local provenance30/30 and Git whitespace PASS. This is NOT native/test-case PASS. Original60 protected files+3 timer/query/Nutrition fragments unchanged;5A contract/session/repository/domain/wizard bytes unchanged during5B; shared display normalizer independently unchanged. Prior unrelated dirty work preserved.

BACKEND RELEASE GATE:OPEN — production catalog/RLS still NOT VERIFIED, existing restrictive migration historically unapplied. No successful remote query repeated, no DB/migration/push/deploy. Save/reopen and true linked-account history acceptance NOT RUN. Old wizard intentionally untouched and missing required evidence: not release-ready; edited-preview validation and real-RIR adapter remain future integration work. UI only after new approval, never an automatic next phase.

NEXT EXACT STEP: execute native tests/build on Mac for this exact tree, repair demonstrated engine/test failures without UI, record CASE01–12 results. STOP BEFORE UI integration; new user approval required. Do not repeat audit/skills/5A.

## Current UI integration checkpoint — new approval2cce4455,2026-10-23

PHASE5A+5B UI INTEGRATION:PASS SOURCE, native/end-to-end PARTIAL. Full implementation/skills/delegation/scope/results: docs/COACH_UI_INTEGRATION_20261023.md. Ten-step explicit evidence questionnaire→current-session generation→human explanation/session preview→existing editor with shared hard validation/role-compatible replacements→same owner recheck and server-confirmed save. No second editor/generator, no hidden evidence defaults, no early saved claim, demo/local retention explicit. Historical/manual flow retained.

Core generator/Rules/CatalogPolicy/Contract and CASE01–CASE12 frozen by exact70-source checkpoint/hash; PlanValidator narrow edited-presentation extension defaults to strict, SessionStore only typed save-denial catch.214/214 coach UI source/hash and202/202 full app static plus whitespace PASS.19 new integration XCTest definitions (234total native) and3native previews NOT RUN. Mac/Simulator/VO/real generation/save/RLS remain NOT RUN; backend gate OPEN. No Nutrition/Desktop/body map/DB/migration/push/deploy. NEXT: Mac native matrix; wait for new approval before Nutrition5C+5D. Earlier UI-stop applies to historical checkpoint only.
