# Coach UI integration — approved Codex plan,2026-10-23

Scope: four existing app files (GuidedWorkoutView, existing PersonalWorkoutView/editor, PlanValidator for generated-vs-edited naming/calendar compatibility, SessionStore ONLY for preserving typed save denial instead of misreporting offline retention) plus scoped flow/editing support, tests/scripts/docs. Generator/Rules/CatalogPolicy/Contract/CASE01–CASE12 frozen; Nutrition/Desktop/body map/backend unchanged.

1. Explicit questionnaire draft and typed corrective feedback; no silent evidence defaults. Ten steps: experience, technique, availability, equipment, goal/phase/length, split, priorities, actual-ID exclusions, acknowledgement, review. Only verified equipment categories exposed; choices persist on Back/errors.
2. Existing session.generatePersonalWorkout entry; honest local generation state and native preview with effective level/strategy/budget/reasons, never version/fingerprint.
3. Reuse same existing plan/session/exercise editor; admissible role-matched replacements, shared edited-plan validator, no override policy in Views. Core strict generation validation retained by default; edited validation accepts legitimate names/calendar/order but still enforces coverage, time, prescription, equipment/exclusions/volume/recovery.
4. Reuse confirmed save/read-back pipeline. Recheck current identity and repository fresh no-link preflight; local retention explicitly distinguished from server success, demo explicitly local. No RLS enforcement claims.
5. Freeze70-source-file checkpoint/CASE tests, add focused tests/assertions and Mac backlog. Native/real save/VoiceOver remain NOT RUN.

## Per-component craft decisions BEFORE UI edits
Intent: standalone adult fitness user creating a realistic next training week, not a trainer/admin. Domain: sessions,sets,reps,RIR,recovery,weekly consistency. Color world: charcoal equipment,white chalk,red accents,green completion,neutral mats. Existing GymManager identity is authoritative.
Wizard: focal current question→one Continue CTA; SF semantic body/headline/caption, existing charcoal ClientClay canvas/ink/accent, native grouped controls, one surface level not cards nested in cards,4/8pt spacing/16page/24section. Explicit unselected required inputs, step feedback, minimum44pt.
Preview: focal session/program and human reasons; existing Clay surface/semantic states/green only verified local consistency, not clinical approval. No internal hashes/IDs/engine version. Semantic SF,8related/24section, horizontal native-labelled session selection.
Editor: existing NavigationStack/Form/Sections, not a second editor. Focal valid prescription then Save; native edit/reorder controls, labels/errors above action, same tokens/type/depth/spacing; replacements filtered by pure policy. No layout/dynamic-type hacks; no custom gesture/nav/font/dependency.
Save: explicit localDraft/saving/confirmed/failure; clear activation semantics; no success before read-back, no stale account closure. No automatic retry. ReduceMotion respected; no decorative choreography.

## Skills applied
UI/UX Pro Max targeted swiftui search: live validation/local draft state/EnvironmentObject shared state ACCEPTED. interface-design native adaptation: hierarchy,token reuse,clear states ACCEPTED; web CSS/headless controls REJECTED for SwiftUI. design-ios-interfaces/implement-swiftui-ios/HIG reference/checklist: native Form/navigation,safe areas,44pt,Dynamic Type ACCEPTED. ux-heuristics/Nielsen1/3/5/9: status,Back preservation,error recovery ACCEPTED; no invented rendered score. Impeccable Operate+iOS+craft-floor: precise familiar native controls/incumbent brand,not a redesign ACCEPTED; browser-only patterns REJECTED. Context launcher already run once this session, not rerun. Supabase skill security: preserve actual session/RLS/read-back; no SDK/schema/API change, remote gate remains OPEN.

## Delegation
GYM-COACH-UI-20261023-001: Antigravity analysis via actual agy1.3.1 plan mode,FAILED exit1/provider ERROR/no response (not authenticated),filesNONE. Codex verification FAILED/unusable, no delegated implementation/lock. Codex plan APPROVED with above scope; no claim of successful Gemini work.

## Final source integration / acceptance —2026-10-23

PHASE:5A+5B UI Integration.
STATUS:PASS SOURCE; native/end-to-end acceptance still PARTIAL, not a production release.

WIZARD STEPS:10 (experience,skills,availability,equipment,goal/phase/length,split,priorities,real-ID exclusions,healthy-adult acknowledgement,review).
REQUIRED ANSWERS:all collectable. Evidence/mandatory choices initially nil/empty; explicit No and zero accepted where meaningful. completeAnswers rejects omissions/invalid input before current-session generatePersonalWorkout. Back preserves input and temporarily hidden custom days.
LEVEL UX:evidence-based estimate, never above perceived/evidence cap; no editable effective-level bypass.
SPLIT UX:unsupported fixed options disabled, stale incompatible selection explained with user-selected Decidi tu alternative; no silent correction.
PRIORITIES:real11-region taxonomy, optional none, moderate-priority/feasibility explanation. No invented hard cap absent from core policy.
EXCLUSIONS:search actual cached global catalog; persist real UUID set, not free text. Conflicting catalog identities excluded from visible lists; raw catalog conflicts still fail engine admission.
EQUIPMENT:only categories with actual reviewed coverage; explicit home inventory from verified variants, no unsupported floor-only promise. Empty/insufficient catalog message and explicit forceReload retry.
GENERATION ERRORS:typed correction destinations for invalid/missing answers,split,duration,catalog,guardrail; owner denial has no override. Same draft retained, no generic unknown error hiding typed reason.
PREVIEW:actual plan/level/split/sessions/estimated durations and prescriptions; local-draft status, explicit regenerate/edit/review/save actions.
WHY THIS PLAN:human explanation from actual stored answers/metadata, priorities/exclusions when present; no version/fingerprint/internal strategy raw ID in View.
EDIT VALIDATION:ClientEditedWorkoutPlanValidator outside View, no overrides. Recomputes only derived estimates/summary; same core catalog/prescription/coverage/equipment/exclusion/volume/recovery checks. Narrow validator option permits edited names/calendar/session order while strict generation default remains false for allowEditedPresentation. Muscle-group blueprint multiset and actual weekdays/recovery remain checked. New-evidence guided plan cannot escape validation by dropping metadata; historical metadata-less payload still readable.
REPLACEMENT LOGIC:existing picker reused, same movement/kind/primary-muscle role,admitted equipment/exclusions,difficulty no higher than original,no same-day duplicate. New exercise instance UUID but actual catalog UUID preserved; no load invented. Current verified catalog may have no suitable replacement; explicit empty state, no random fallback/custom-entry escape.
OWNERSHIP RECHECK:entry owner pinned; current identity/mode before generation and save, actual existing repository SDK session/profile/no-link preflight before write, same owner/mode after await. This is NOT atomic RLS proof; backend gate stays OPEN.
SAVE CONFIRMATION:localDraft→saving→confirmed/demo or failure. No optimistic dismissal; explicit Fine after successful read-back; failures retain editor and clarify existing local-retention semantics. Preview button says Salva e attiva (existing active-plan semantics), editor shows selected status/activation consequence. Demo confirmation explicitly local. Existing archives+new plan atomic write/read-back retained.
BACKWARD COMPATIBILITY:domain/decoder/payload unchanged, existing manual wizard/choice/history preserved. Editor reused, not duplicated. Old guided metadata-less plans remain on legacy edit path; stricter new rules not silently applied to history.

## Exact source scope and preservation

Existing source edits:GuidedWorkoutView;PersonalWorkoutView/editor;PlanValidator (edited presentation option, default strict);SessionStore (typed save-failure catch ONLY). Reversing that one catch reproduces exact original SessionStore SHA256 CE38EB1B36D7E131BE429543A4C9EA8BF84F387912719046FE98FEF191B9D9B2. Library/history code unchanged except editor completion callback; creation-choice code identical. Generator,Rules,CatalogPolicy,Contract,CASE01–CASE12 and fixture unchanged by hashes.

New source:ClientWorkoutCoachFlow,ClientEditedWorkoutPlanValidator (including small session integration extension),19 IntegrationTests,3 native Coach previews (320Dark,375Light,430AX3). No dependencies/signing/project/Info/domain/backend changes. Previews skip catalog network loading; no browser imitation of SwiftUI.

Static validation explicitly gains -UIIntegration; previous5B baseline is NOT overwritten. Fresh70-file pre-UI baseline authorizes4 source files,protects66 existing sources and engine matrix/fixture hashes. Three original timer/query/Nutrition fragments still pass. Old full-app assertions updated from Bool+automatic-dismiss to explicit confirmed-state+Fine, not removed. Four source-only engine/default scopes are not claimed unchanged when UI flag is used.

STATIC TESTS:214/214 coach UI source/hash checks;202/202 full Client static;Git whitespace PASS. Counts overlap, not behavioral test totals.19new native definitions/234total and3new previews NOT RUN. No Swift compiler on Windows.

Native/Simulator/VoiceOver/DynamicType rendering/ReduceMotion/Swift concurrency/actual generation performance/real save-reopen/RLS:NOT RUN. Actual two-account change/late remote Trainer link scenarios pending. Backend catalog/RLS denied in prior phase; restrictive migration current state NOT VERIFIED. No backend query/mutation/migration/push/deploy this phase.

Legacy global Dark/theme/contrast debt outside this flow remains parked; new primary CTA label uses semantic textOnAccent and controls use native semantics. Light preview is a specimen, not evidence of completed app-wide Light adoption. Native visual acceptance absent, never inferred from source.

## Skill/delegation and documentation closure

Skill principles from approved plan applied:progressive native Form,semantic SF/tokens,44pt targets,error focus/correction,Back preservation,ReduceMotion,precise state/confirmation. No web controls/new theme/design-system files or invented UX score.
Antigravity attempt GYM-COACH-UI-20261023-001 FAILED (not authenticated,exit1/provider ERROR,no response,filesNONE);Codex fallback/review recorded. Gemini did NOT successfully review or implement this work.
Official [Supabase Swift session documentation](https://supabase.com/docs/reference/swift/auth-getsession) checked; existing SDK call reused, no API/config/RLS change. Changelog markdown unavailable through web tool (content type) and shell fetch (DNS); not claimed reviewed. No new Supabase feature introduced.

BACKEND RELEASE GATE:OPEN.
MAC ACCEPTANCE BACKLOG:UPDATED.
NEXT EXACT STEP:Mac native build/tests and actual UI/save/ownership matrix; wait for user approval before Nutrition5C+5D. NO PUSH/DEPLOY/PRODUCTION MIGRATION.
