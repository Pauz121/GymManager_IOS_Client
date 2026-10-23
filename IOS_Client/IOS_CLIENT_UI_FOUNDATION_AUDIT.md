# IOS_Client — foundation audit, Phase 1/7

Date: 22 October 2026. Authoritative checkout: `.orchestrator/tmp/ios-client-sync-20260913/IOS_Client`. Target: GymManagerClient (native SwiftUI, Swift 6, iOS17+, iPhone only), not Trainer/Widget/Desktop.

## Evidence and boundary

Source audit, not rendered-device acceptance. No current Simulator screenshots/goldens were found (only app logo outside assets). Xcode/Swift unavailable on Windows. No fake HTML replica or generated app UI used. Baseline hashes in docs/ui-foundation-baseline-20261022.json distinguish Phase 1 from existing uncommitted creation/anatomy/registration/read fixes. Previous checkpoint: IOS_CLIENT_LAYOUT_LOAD_RECOVERY_20261022.md,202 static checks.

## Intent and native priority

Human: client checking today's work, training with one hand, recording food/activity or consulting a Trainer-assigned plan. Domain: training sets, recovery, daily meals, movement, progress, personal agenda. Existing color world: charcoal equipment, coral active effort, green completion, cyan running, warm neutral surfaces. Signature: today's actionable status and actual workout/recovery state, not decorative dashboard chrome. Reject web dashboard tile grids, neon/glass everywhere, and arbitrary font replacements. Keep SF/SF Symbols/native stacks/tabs/sheets; compact grouping and accessible metrics before decoration. Native correctness/accessibility/HIG outrank third-party style suggestions.

## Audit BEFORE foundation edits / approved plan

| Area | Current state | Issue | Severity | Foundation action now | Screen-specific action later |
|---|---|---|---|---|---|
| Appearance | Root forces Dark; ClientClay static palette | No System/Light preference or semantic mapping | P1 for requested theme capability | Local preference default System; adaptive semantic roles; retain explicit legacy-dark boundary | Phase6 full adoption after per-screen contrast migration |
| Surfaces | clayCard/premiumCard shared, many local variants | Heavy repeated shadows, white foreground assumptions | P2 | Extend existing system, shared spacing/radius/type/elevation tokens; no replacement framework | Phase2 reduce card/chrome density; Phase4/5 content hierarchy |
| Colors | 111 literal-color sites,86 outside design-system file | White/black/status/brand roles mixed | P1/P2 depending pair | Separate semantic and brand roles; explicit on-accent/inverse roles; backward compatible legacy aliases | Migrate86 remaining nonfoundation sites screen by screen |
| Layout | Prior local overlay fix already present; fixed frames common | Small-phone/DynamicType candidates require native evidence | P2, not all are defects | Preserve prior sizing fix; inventory safe/risky uses | Phase2 layout and Phase7 broad QA |
| Type | Mostly semantic SF;11 fixed-size font calls | Calendar/nutrition micro labels8/9pt; large metrics/avatars fixed | P1 for meaningful micro labels | Semantic type roles, preserve current geometry | Phase2/5/6 migrate affected labels; Phase7 AX |
| Navigation |5 tabs, NavigationStack per tab, custom safe-area tab bar | Tight caption scaling/legacy colors | P2 | Audit only; preserve navigation | Phase6/7 native touch/VO/theme pass |
| States | Existing empty/failure helpers plus prior local section gate | Large full-page failure used beside inline variants | P2 | Document page vs section state contract; reuse existing helpers | Phase4 behavior acceptance, not foundation business changes |
| Motion | Native Canvas/TimelineView descriptors |30Hz draw work; heuristic mapping is illustrative, not exercise footage | P2 source risk, not measured jank | Identify only; no animation edits | Phase3 decide remove/replace; Phase7 profile hardware |

Implementation plan: (1) capture inventory/baseline and skill decisions; (2) add local preference and semantic roles extending ClientClay, not a parallel UI framework; (3) name existing spacing/type/radius/elevation in shared styles without restyling screens; (4) native token/persistence/contrast tests and repeatable Windows source checks; (5) handoff. Do NOT begin Phases2–7.

## Initial reproducible inventory

50 app Swift files;111 `.clayCard`/`.premiumCard` call sites (not111 simultaneous visible cards);111 literal-color occurrences (25 in ClientDesignSystem,86 outside);11 `.system(size:)`;72 fixed-height and53 fixed-width call sites;3 GeometryReader;10 ZStack;48 overlay;2 offset;1 position. Zero negative padding/zIndex/alignmentGuide matches. Regex candidates are NOT a defect count. Chart `.position(by:)` is grouping, NOT absolute positioning.

Color hotspots: WorkoutView15,Home13,Progress10,Running9,GuidedWorkout8 literal occurrences. Card candidates: WorkoutView16,GuidedWorkout13,Nutrition wizard12,ManualWorkout8,ActivityDashboard7,Progress7. Counts span multiple states/screens; they do not prove runtime overlap or overload.

## Skill application (read actual instructions and relevant references)

| Skill used | Relevant principles / findings produced | Codex decision | Why |
|---|---|---|---|
| UI/UX Pro Max | Semantic tokens, contrast,44pt,4/8 rhythm, native stack; identifies fixed8/9pt and varied radius sites | MODIFIED | Keep SF Symbols/SF and SwiftUI. Search `semantic colors appearance` swiftui was off-topic; narrowed `colorScheme darkMode` returned0. No verified native theming database match; use Apple APIs. OLED style result is web-specific/neon and rejected, not persisted. |
| interface-design | One focal job, page/section/group vs card; reuse shared styles; four text levels; no mechanical migration | MODIFIED | Keep existing fitness identity. Do not apply px/CSS/fonts/Radix/GSAP; SF semantic styles win over arbitrary type ratios. |
| design-ios-interfaces | Native peer tabs/stacks/sheets, safe areas, local settings, SF, DynamicType | ACCEPTED | Existing architecture already native; no navigation rewrite. |
| implement-swiftui-ios | Follow local state ownership, semantic color/font APIs, native previews, no dependencies | ACCEPTED | New theme is purely local, Preview source is not runtime evidence. |
| review-hig-compliance | Separate accessibility defects from taste; P0–P3; identify exact location/risk | ACCEPTED | Low label sizes/theme incompatibility are evidence, no invented device findings. |
| ux-heuristics | Visible status, recognition, consistency, progressive disclosure, recovery | MODIFIED | Apply to client workout tasks, not web conversion/global search. No numerical user-testing score claimed. |
| Impeccable native audit/extract | Source audit only, native priority, consolidate repeated foundation not everything | MODIFIED | Existing ClientClay preserved; no browser screenshots, generated fake UI, external framework, automatic whole-app redesign. |

## Implementation completed locally — 23 October 2026

- `Core/ClientAppearance.swift`: System/Light/Dark enum, System=nil, one MainActor observable local UserDefaults preference store. Default System, invalid values fall back System; no session, account or Supabase dependency. Presentation modifier prepared. App injects one store; no settings redesign.
- `Core/ClientTheme.swift`:30 semantic roles, one Light/Dark palette, native UIColor dynamic provider using supplied style/contrast traits (never global current traits). Includes textOnAccent, textInverse and non-brand error/warning/status roles. Increase Contrast promotes secondary text and boundaries. Brand/domain aliases are explicit.
- `Core/ClientUITokens.swift`: regular4/8/12/16/20/24/32/40 spacing; explicit18pt compatibility exception; radius12/16/22/26; semantic SF typography;44pt minimum target; border/elevation roles. Existing22/26radius and18padding preserved, not mechanically replaced throughout screens.
- Shared `ClientDesignSystem.swift` now sources its existing dark aliases from that palette, not parallel definitions. Values are equivalent8-bit roundings of prior sRGB constants. Shared fonts/padding/elevation reference tokens. Existing clayCard has an opt-in `.adaptive` variant used by three preview groups; default remains `.legacyDark`. No second card library, navigation or state framework.
- `Preview/ClientFoundationPreview.swift`: Debug-only native Light/Dark/System and accessibility3 specimens. Developer typography/status examples are labelled illustrative, not product data. No new app destination. Preview source is NOT a screenshot/test result.
- Root Dark pin is intentionally retained with a migration comment. Preference DEFAULT=System does NOT mean existing screens already follow System. Full adoption and user-facing selector remain Phase6; do not remove pin before all surfaces/text/controls are migrated and tested together. Premium cards/button legacy styles are not advertised as Light-ready.

### Page/group/surface contract

PAGE owns scrolling, safe areas, and peer navigation. SECTION groups one task with a heading and larger leading gap. GROUP uses spacing/dividers, normally no extra background. SURFACE is a real elevation/interaction layer. CARD summarizes an independent object/task; INTERACTIVE CARD uses Button/NavigationLink,44pt target, state/AX semantics. METRIC is a value/label, not automatically a box. STATUS uses text/icon plus semantic color, not color alone. EMPTY follows a successful read with no data. ERROR is retryable and not EMPTY. Loading may use native progress; no need for a skeleton framework. None of these categories authorizes a screen rewrite in this phase.

## Component inventory

YES/NO consistency below is source-level; native VoiceOver/layout remain pending.

| Pattern / existing owner | Used in | Duplicated | Consistent | Should centralize | Action |
|---|---|---|---|---|---|
| ClayCardModifier | All content/features | NO shared owner;local variants YES | NO radius/shadow variants | YES tokens now | KEEP shared;consolidate later |
| PremiumCardSurface | Home,Gym,Recap,Progress | NO shared owner | YES intrinsic background after prior fix | YES existing | KEEP |
| ClientMetricTile / local metrics | Home,Progress,Activity,Running | YES similar,not equivalent | NO density variants | YES common tokens;variants later | REFACTOR LATER |
| ClientEmptyState | Gym,Home,Nutrition,history | NO shared helper | YES;context size differs | YES existing | KEEP;smaller inline variant later |
| ClientFailureView / ContentFailureCard | Root,section failures | NO different scope intentional | YES page vs inline | YES existing | KEEP |
| ClientSectionHeader / PageTitle | Feature headings | NO shared helpers | YES semantic fonts;row wrapping to test | YES token reuse now | KEEP |
| Custom segment/period/week controls | Workout,Recap,Nutrition | YES contextual | NO sizing/selected variants | YES tokens,later controls | REFACTOR LATER |
| NavigationStack/Link/toolbars |5 tabs/drill-in/edit flows | NO standard primitives | YES native routing | NO new router | KEEP |
| PremiumTabBar | App only | NO | YES selected/AX labels;theme/scale debt | NO new bar inPhase1 | KEEP |
| ClayPrimary/SecondaryButtonStyle | Auth,wizards,save actions | NO shared;Running hold distinct | NO legacy contrast | YES style roles;no behavior edits | KEEP now,migrate later |
| Choice chips | Manual/GuidedWorkout,NutritionWizard | YES3 visual families | NO | YES after intent variants agreed | REFACTOR LATER |
| ClientBadge / directional / read-only | Plans,progress,account | NO intentional variants | YES icon/text | YES existing | KEEP |
| Native Form/TextField/Picker/Stepper | Account,wizards | YES label wrappers | PARTIAL | YES input tokens;not data logic | KEEP |
| GymPlanHeader / workout session rows | Gym and plan detail | NO scoped components | YES natural title height | NO universal row abstraction | KEEP |
| Nutrition meal/day tiles | Home,plan,personal nutrition | YES different completion/edit modes | NO selection styles | YES later shared stateful presentation | REFACTOR LATER |
| Charts / CircularProgress / CaloriePie | Progress,Recap,Home,Nutrition | Rings/pie shared;chart chrome repeated | PARTIAL | YES chart styling later | KEEP math/data |
| ProgressView/ContentGate | Bootstrap/section reads | NO shared gate | YES after prior local fix | NO skeleton library | KEEP lifecycle untouched |
| Alert / inline banner | Root actions/read errors | NO scope separation intentional | YES source contract | NO universal alert abstraction | KEEP |
| ProfileAvatar / avatar store | Home,Account,tab | NO shared | YES per account;fixed-font scope debt | YES existing | KEEP |

## Layout safety inventory

Six inspection targets (L06–L11), not six proven overlaps. Five explicitly safe source constructs remain preserved. Exact line positions may move as foundation aliases are introduced; symbols are stable anchors.

| ID / source anchor | Classification | Evidence and risk | Later phase |
|---|---|---|---|
| L01 Core/ClientDesignSystem,ClientPremiumCardSurface | SAFE |150pt circle only overlay,clipped/non-hit-testable;does not size card. Prior local fix retained |2 native bounds proof |
| L02 Workout/ClientActivityDashboardView,distanceScaleIndicator | SAFE |GeometryReader height16;marker clamped to axis,decorative offset only |2 screenshot |
| L03 Workout/ClientGuidedWorkoutView,wizardHeader | SAFE |GeometryReader explicitly7pt tall for progress,not outer page |2/7 |
| L04 Running/ClientRunningView,HoldToFinishButton overlay | SAFE layout |Reader constrained4pt overlay;separate semantic activation concern below |7 |
| L05 Progress/ClientProgressView,weeklyWorkoutChart | SAFE |`.position(by:)` is Swift Charts grouping,not absolute view placement |5 |
| L06 Workout/ClientActivityDashboardView:79/113 | KNOWN LAYOUT RISK |Calendar seven columns;explicit DynamicType ceiling accessibility1 and8pt icons;do not just uncap without alternate layout |2/7 |
| L07 App/ClientTabView,HealthConnectionPrompt | SUSPICIOUS |Medium-only sheet + non-scrolling VStack may compress long text/actions |6/7 |
| L08 App/ClientTabView,PremiumTabBar | SUSPICIOUS |5 caption2 labels,lineLimit1/minimumScale0.72;52pt height and labels/selected traits are positive |6/7 |
| L09 Workout/ClientExerciseVisualCard / ClientAnatomyMap | SUSPICIOUS |180pt motion +248pt anatomy +chips/disclaimer before prescription can dominate detail. Execution already hides full anatomy,keep that |3 |
| L10 Nutrition/ClientNutritionView,dayPill:110 | KNOWN LAYOUT RISK |Fixed72x72 plus9pt meaningful OGGI/PASTI label,large text adaptation pending |5/7 |
| L11 Progress/ClientProgressView:175/182/397 | KNOWN LAYOUT RISK |46/38pt numerical fonts bypass semantic scaling,containment unverified |5/7 |

Other source AX risk: Running HoldToFinishButton is a Label with long-press gesture and label/hint but no explicit Button/accessibilityAction. Plan VoiceOver/SwitchControl equivalent protected finish inPhase7; not a proven runtime unusability claim. No current feature behavior changed.

## Card overload hotspots

- HIGH (source candidate): Exercise detail composition, motion+anatomy+supporting blocks before prescription. Preserve operational data and plan Phase3 progressive disclosure.
- MEDIUM: Home premium daily hero plus nested small metric surfaces and separate priority cards (Phase4); Progress hero/ring/KPI/chart boxes (Phase5); training category navigation styled like content cards above actual plan (Phase2).
- MEDIUM: Guided/manual/nutrition wizard choice/summary card patterns; screen content is step-based,call-site count alone does not prove simultaneous clutter. Review actual step before extracting.
- LOW: Account/agenda simple grouped rows and existing inline error states. No mass de-carding now.

## Animation implementation identified — no edits

SwiftUI TimelineView(.animation,min interval1/30s) + local Canvas/Path drawings;10 explicit native motion descriptors in ClientExerciseVisualModels resolve catalogue/source/name to motion,otherwise staticPose. No Lottie/SceneKit/video or remote asset in this renderer. assetKey/version are metadata,renderer chooses `motion`; viewAngle is displayed but not a3D camera. Existing explicit pause/rest/ReduceMotion/static handling preserved.30Hz is requested update cadence,NOT measured FPS; hardware profile remains needed. Decision REMOVE/REPLACE deferred Phase3.

## Independent review and Codex acceptance

Agent client_foundation_review,read-only,attempt1: genuine component/risk/motion inspection;files changedNONE. Codex ACCEPTED source findings,MODIFIED any visual severity to pending native verification. Attempt2 bounded review of new foundation files/tests: no material source/Swift6 issue found; accepted with build/runtime limitations. No Gemini/Antigravity call or success claimed. Record: .orchestrator/delegations/GYM-IOS-FOUNDATION-20261023-001.md.

## Colors, contrast and test evidence

Initial111 literal-color occurrences →87 now:86 existing nonfoundation sites unchanged,1 central RGB constructor. Counting regex excludes component property access such as `rgb.red`; hex palette definitions are intentional centralized primitives,not per-screen magic values.24 literal call sites consolidated,not24 UI bugs fixed. Role count30. No whole-screen replacements.

New semantic opaque-sRGB textPrimary/textEmphasis/textSecondary/textTertiary on6 base surfaces in2 schemes:48 combinations >=4.5. textOnAccent in2 schemes:2 combinations >=4.5. These50 mathematical checks do NOT establish contrast over composited gradients,transparency,photos,disabled states,or unchanged legacy screens.

Important existing debt: legacy white on coral #FF4F32 is3.27:1; not sufficient for ordinary-sized text. New textOnAccent fixes the semantic contract (dark ink on bright dark-theme accent;white on deeper Light accent),but existing legacy button usages deliberately not silently restyled. Resolve with per-screen adoption and native acceptance before declaring accessibility complete.

-112/112 foundation source/mathematical checks PASS (includes47 exact baseline SHA256 checks proving Feature/business/animation/Tab sources unchanged duringPhase1).
-202/202 full Client source/static checks PASS;git whitespace PASS.
-8 native theme tests added;162 total XCTest methods currently defined,ALL native execution NOT RUN here.
-No application data,Auth,read lifecycle,ownership,workout/nutrition engine/sync/backend/schema/RLS/EdgeFunction change inPhase1. Previous recovery changes are a separate recorded checkpoint,not new work.
-Source buildability/Xcode/Simulator/native preview/System behavior/VoiceOver/DynamicType/real device FPS/screenshots:NOT RUN / NOT AVAILABLE on Windows. No fabricated UX/20-point score; unobserved runtime criteria are not scored. User's evidence boundary overrides a skill's generic scoring prescription.

## Status and next exact step

PHASE1 STATUS: PARTIAL — source foundation/audit complete locally;native build/appearance/layout acceptance not available. UI FOUNDATION AUDIT:PASS source. THEME ARCHITECTURE:PASS source. SYSTEM/LIGHT/DARK FOUNDATION:PASS source;SYSTEM MODE runtime:NOT RUN;full adoptionPhase6 pending. SEMANTIC COLORS/SPACING/TYPE/RADIUS/SURFACE:PASS source. COMPONENT DUPLICATION REDUCED:PARTIAL (shared tokens/adaptive variant,not mass extraction). LAYOUT INVENTORY:READY. ANIMATION IDENTIFIED:YES. EXISTING SCREENS PRESERVED:PASS source/hash;visualNOT RUN.

PHASE2 READY: YES for scoped planning AFTER user approval;no permission inferred. First validate current branch in Mac Xcode:

`xcodebuild -list -project IOS_Client/GymManagerClient.xcodeproj`

Choose an actually installed iPhone simulator,run scheme GymManagerClient tests and open the3 native foundation previews. Verify Light/Dark/System and Increase Contrast at small/ProMax/accessibility3,then capture Simulator screenshots. Keep Root dark until approved Phase6 adoption. Begin Phase2 only after user approval;do not resume recovery feature work automatically.

Official API references checked: [preferredColorScheme](https://developer.apple.com/documentation/swiftui/view/preferredcolorscheme(_:)) (nil=system/no preference) and [UIColor dynamicProvider](https://developer.apple.com/documentation/uikit/uicolor/init(dynamicprovider:)) (use supplied traits). No dependency upgrade or new SDK/backend API.

## Phase1 file manifest (not the entire pre-existing dirty worktree)

MODIFIED: GymManagerClient/Core/ClientDesignSystem.swift;App/GymManagerClientApp.swift (local preference injection only);App/ClientRootView.swift (compatibility comment only).

CREATED: GymManagerClient/Core/ClientAppearance.swift;ClientTheme.swift;ClientUITokens.swift;GymManagerClient/Preview/ClientFoundationPreview.swift;GymManagerClientTests/ClientThemeFoundationTests.swift;scripts/validate-ui-foundation.ps1;this audit;docs/ui-foundation-baseline-20261022.json. Operational handoffs updated at workspace/project/authoritative Client. Previous recovery report/tests/code predatePhase1 and are explicitly separate.

COMMIT/PUSH/DEPLOY/APP STORE/DB/MIGRATIONS:NONE. NEXT EXACT STEP: native validation checkpoint,then Phase2 only after new user approval.
