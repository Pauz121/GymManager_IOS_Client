# IOS_Client — Phase2/7 training refinement

Date:23October2026. Authoritative checkout .orchestrator/tmp/ios-client-sync-20260913/IOS_Client,main49e67c8. Phase1 foundations reused,not repeated. No push/deploy/DB/backend/dependency changes. No Phase3 exercise detail/anatomy/motion or other-page redesign.

## Audit BEFORE edits

| Area | Observed source | Decision |
|---|---|---|
| Training navigation | Two56pt minimum rows +10pt spacing;AX becomes four rows;large icon surfaces,headline single-line labels | One horizontal text selector,44pt minimum,untruncated label width/horizontal scrolling,semantic tokens and native Buttons. Native fixed segmented Picker rejected because4 long labels compress at large type;2x2 remains too tall. Reuse selector for Recap periods. |
| Gym | Natural VStack already present from prior fix;premium header+today/rest large card still dominates | Preserve prior structural background fix;compact adaptive plan surface,inline rest/upcoming state,scannable session rows;no offset/frame hacks. Preserve actual plan/session navigation,history,completion and permissions. |
| Recap | Two-metric premium header before period selector;repeated metric boxes and large no-distance empty state | Plain natural inline summary;shared compact periods;inline missing-distance/no-activity explanation. Preserve interval/math/chart scales. |
| Calendar |7-column grid,8pt markers,AX ceiling;small widths cannot fit7x44pt | Keep monthly grid at sufficient width,semantic icons and selected/today cues;native DatePicker fallback forAX/insufficient width. Do not merely uncap text. Preserve displayed month/selection/data. |
| Running | Four PB placeholders when no records;no-GPS completion map and multiple unavailable metric boxes | Show only actual PBs/available metrics;single contextual missing-GPS message;preserve duration,history,record/replay algorithms/actions. |
| Bottom tabs |5 real Buttons,52pt minimum,safeAreaInset;custom bar | Tap remains primary. Optional native longpress→drag sequence only within bar;40pt fresh movement per adjacent step,no wrap/burst,GestureState cancel cleanup,no motion when ReduceMotion,disable scrub withVO/SwitchControl. HIG/runtime acceptance pending;do not claim native success from source checks. |

## Skills actually reread/applied

UI/UX Pro Max:44pt,semantic tokens,visible states and single-pointer alternative;ACCEPTED native tap alternative,MODIFIED web/px suggestions. Query dragging movements alternative returned relevant guidance;SwiftUI gesture priority returned0 and narrowed ontapgesture returned unrelated deletion guidance,REJECTED as no verified match. Use official Apple gesture composition instead.

interface-design:content before chrome,one focal action,semantic type/rhythm,existing components before abstraction;MODIFIED to SF/native controls,no CSS/font replacement. design-ios-interfaces:native tabs/stacks/sheets,safe areas/non-color cues;ACCEPTED. implement-swiftui-ios:local selection ownership,semantic APIs,accessibility/ReduceMotion/previews;ACCEPTED. review-hig-compliance:source vs runtime evidence andgesture risk;ACCEPTED. ux-heuristics:recognition,progressive disclosure,optional shortcut,real empty/error distinction;ACCEPTED native subset. Impeccable native/adapt:preserve visual identity,use native-rendered evidence only;MODIFIED:root dark and prior features preserved,no speculative numeric runtime score.

Intent:client finds today's session or activity with one hand;calendar/rest/session/pace/weekly progress are domain anchors. Existing charcoal/coral/green/cyan palette remains via semantic roles. Navigation is quiet control chrome,not competing hero cards. SF text/control typography,4/8 spacing,tonal surfaces/subtle borders. No new brand world.

| SKILL USED | RELEVANT PRINCIPLES | FINDINGS PRODUCED | CODEX DECISION | WHY |
|---|---|---|---|---|
| UI/UX Pro Max |44pt targets,readable labels,alternative to dragging | Grid navigation too tall;bar-only gesture cannot replace taps | MODIFIED | NativeButton/SF/pt take precedence over web sizing/patterns |
| interface-design | Hierarchy,content before chrome,reuse | Plan/rest and two-metric hero compete with actual sessions | MODIFIED | Quiet native controls/inline states,not a web dashboard or new font system |
| design-ios-interfaces | Safe areas,clear states,native date/accessibility controls |7-column layout cannot guarantee44pt at every width/type size | ACCEPTED | Keep monthly grid when it fits,use native date selection alternative otherwise |
| implement-swiftui-ios | Local state,semantic APIs,ReduceMotion,testable components | Selection/scrub belong to UI,not services;new logic should be separately testable | ACCEPTED | Pure scrub state/shared selector,existing TabView/NavigationStack/engine remain |
| review-hig-compliance | Accessible actions,source vs native evidence | Custom press-drag is not a standard tab convention;button/system conflict unverified | ACCEPTED | Mark CONCERN/PARTIAL,require device gate and remove shortcut if conflicting |
| ux-heuristics | Recognition,progressive disclosure,real empty states | Repeated PB/GPS placeholders obscure real data | ACCEPTED | Show available metrics and one contextual explanation,no fabricated values |
| Impeccable native/adapt | Preserve incumbent identity,reduce chrome,real native evidence | Card overload,small markers,label shrink;no fresh native renders available | MODIFIED | Preserve GymManager/SwiftUI anddark staging;no web imitation or fabricated screenshots |

## Delegation

client_phase2_review attempt1 FAILED — usage quota before usable output. Files affectedNONE,result usableNO. No Gemini/Antigravity run or completed review claimed. Codex source review fallback,delegation optional;no repeated quota calls/no waiting. Native HIG/gesture acceptance NOT RUN on Windows.

## Implementation/tests

Source implementation complete locally;STATUS PARTIAL pending native acceptance. Baseline54 existing files/4 authorized UI edits;50 protected source files match exact SHA256.13 normalized-line-ending frozen fragments match pre-edit hashes,including workout/exercise detail tail,tab read lifecycle,Running history/metrics/actions/replay/format. No Phase3 work.

### Navigation and layout

Training defaults to Attività as before;four destinations and ContentGate/retry stay unchanged. New ClientCompactSelector uses real nativeButtons,44pt minimum,text semantic size and intrinsic horizontal label width,scroll-to-selection,selected trait,border+tonal selected surface,ReduceMotion. Reused for four Recap periods. No font-shrink/one-line truncation. Larger text scrolls instead of becoming four navigation cards.

VERTICAL SPACE REDUCTION:source lower-bound estimate at ordinary type:old2×56+10=122pt,new44+2×1.5=47pt;75pt/about61% less navigation chrome. NOT a Simulator measurement;intrinsic text/system fonts may increase height. No invented rendered percentages at accessibility sizes.

Gym structural cause:earlier premium-card decorative150pt circle could influence background sizing;prior task already fixed shared primitive with constrained overlay,retained exact bytes in this phase. Local Gym now uses one naturalVStack,adaptive12pt-padded plan surface,wrapped title/week/session count,inline rest/upcoming status,compact today/session rows with44pt minimum and actual completion state. No offset/fixed-height masking. Current/completed/historical destinations and read-only permissions preserved.

Recap structural cause:large decorated two-metric hero before other content,plus earlier shared decorative sizing risk. New inline baseline-aligned active-day/time summary with vertical fallback,no premium wrapper. Period,metrics,distance scale and chart follow. Missing data is secondary text,not another empty hero. Existing aggregate/filter/formula logic unchanged. Distance bar/chart now use semantic colors and adaptive surface;no new chart engine.

Calendar:normal monthly42-day grid retained where7×44pt fits. Accessibility text sizes OR insufficient width select a native compact DatePicker limited to the displayed month;detail below lists real activities. No DynamicType ceiling. Today underline,selected outline,gym/run/both SF symbols and full spoken date/activity state distinguish states without color alone.8pt markers removed. Native fallback rendering/DatePicker accessibility remains to test.

### Running partial data

Start/resume action remains first. Only distances with actual PB entries create PB cards;no four empty records. Live time stays visible;GPS-based metric group is gated on accepted route points. One contextual location banner handles unavailable/waiting states. Completion without a route omits blank map and shows one GPS explanation;duration and available optional metrics remain. Existing GPS filtering,elapsed time,speed/pace math,pause/finish,LiveActivity updates,replay,splits/records and persistence unmodified. Existing local-device save copy is retained;no new cloud persistence claim.

### Bottom tab press-drag / HIG review

BOTTOM TAB PRESS-DRAG:PARTIAL (native implementation present;unverified interaction).
NORMAL TAP PRESERVED:YES in source;runtime NOT RUN. Five actual nativeButtons remain,selection/avatar/routes unchanged.

Gesture design:native LongPressGesture0.45s,max12pt before activation,sequences DragGesture. Hold alone cannot change selection;fresh40pt horizontal travel per adjacent transition,one step per sample,no timers/auto-repeat/wrap. Boundary travel updates anchor;reverse travel can leave the boundary. Invalid/nonfinite/vertical samples do nothing. Selection only changes after model returns a distinct valid index;one selection haptic. Reduced motion disables selection animation. GestureState release/cancel clears interaction only,not the selectedTab. Bar highlight shows armed mode.

Gesture attaches only to inner tabButtons in existing safeAreaInset,not root/content/home-indicator padding. High-priority recognition is intended to consume the recognized hold while ordinary taps continue to Buttons. This interaction MUST be verified on-device;source alone does not prove it. No delayed button suppression,UIKit private APIs,overlay over the home area or global drag handler.

VoiceOver/SwitchControl disable scrub and leave all five individual labelled Buttons with selected traits. SwitchControl status changes reset transient scrub state. Tap remains primary;no gesture-only navigation. Text can wrap rather than shrink. No broad navigation redesign.

HIG REVIEW:CONCERN — optional nonstandard shortcut,not a native TabView convention. Native semantics/alternative/scope/ReduceMotion are retained;normal tap,longhold-without-drag,cancel,system back/home/scroll and assistive-tech behavior are NOT RUN. Do not ship/accept gesture before these pass. If a conflict appears,remove the optional highPriorityGesture and retain the five Buttons;do not add tap-delay hacks.

Primary references used:[Apple gesture composition](https://developer.apple.com/documentation/SwiftUI/Composing-SwiftUI-Gestures),[SwiftUI gestures and native actions](https://developer.apple.com/documentation/SwiftUI/Gestures),[Switch Control status changes](https://developer.apple.com/documentation/uikit/uiaccessibility/switchcontrolstatusdidchangenotification). These support APIs and review approach,not a claim that Apple approves this custom interaction.

### Foundation adoption / skill decisions

New selector/tab controls/plan/session surfaces and edited activity/recap presentation use existing semantic foreground/surface/border/accent roles;spacing,radius,typography and min-target constants reused. Root remains deliberatelyDark;global System/Light adoption not activated. Only18 literal-color occurrences migrated in authorized UI files (86→68 outsidefoundation;total87→69 includingcentralRGBconstructor). Remaining legacy/detail/history/other-screen colors are parked,not globally replaced. Existing white-on-coral3.27:1 button debt remains and is not claimed fixed.

Skills influenced reduced chrome/native alternatives/semantic states/intrinsic wrapping/accessibility fallback and narrow token adoption. Rejected web typography/CSS/hover patterns,new dependencies,brand replacement and global appearance activation. Per-skill findings/decision/reason are recorded in initial audit above;all six mandatory skills plus Impeccable actually read. No skill overrode native behavior/business boundaries.

### Files

MODIFIED inPhase2:
- GymManagerClient/App/ClientTabView.swift — optional bar gesture/presentation only;root read/Health flow frozen.
- GymManagerClient/Features/Workout/ClientWorkoutView.swift — selection and Gym listing/header only;detail tail frozen.
- GymManagerClient/Features/Workout/ClientActivityDashboardView.swift — calendar/Recap UI;existing insights/calculation unchanged.
- GymManagerClient/Features/Running/ClientRunningView.swift — missing-data presentation;business fragments frozen.
- scripts/validate-client-ios.ps1 — replace obsolete hero/grid style assertions with approved compact-control contracts;202 checks retained.
- scripts/validate-ui-foundation.ps1 — explicit -TrainingPhase2 mode uses54-file baseline/4 authorized edits;original Phase1 baseline/default remains preserved.
- CODEX_HANDOFF.md plus workspace/project operational pointers.

CREATED:
- GymManagerClient/Core/ClientCompactSelector.swift
- GymManagerClient/Core/ClientTabScrubState.swift (UI state only)
- GymManagerClient/Preview/ClientTrainingPreview.swift (3 Debug native specimens)
- GymManagerClientTests/ClientTabScrubTests.swift (8 definitions)
- GymManagerClientTests/ClientTrainingLayoutTests.swift (3 definitions)
- scripts/validate-ui-training.ps1
- docs/ui-training-baseline-20261023.json
- docs/ui-training-protected-fragments-20261023.json
- IOS_CLIENT_UI_PHASE2_REPORT.md
- internal .orchestrator/delegations/GYM-IOS-PHASE2-20261023-001.md

No Xcode project/signing/dependency edits inPhase2:filesystem-synchronized source/test groups include new files automatically. Existing dirty Xcode/other-feature changes predate this phase and remain untouched.

### Actual validation

From authoritative checkout:

```powershell
pwsh -NoProfile -File IOS_Client/scripts/validate-client-ios.ps1
pwsh -NoProfile -File IOS_Client/scripts/validate-ui-foundation.ps1 -TrainingPhase2
pwsh -NoProfile -File IOS_Client/scripts/validate-ui-training.ps1
git -c core.safecrlf=false diff --check
```

202/202 app static PASS;114/114 foundation source/math PASS;87/87 Phase2 source/hash assertions PASS;Git whitespace PASS. These overlap and MUST NOT be summed into a functional/native test count. The original foundation validator without the explicitPhase2 switch still audits the historicalPhase1 boundary,not the newly approved four UI edits.

11 new native XCTest definitions (8 state-machine,3 layout);173 total definitions across app test suite. NOT RUN:Swift compiler,Xcode,Simulator absent onWindows. Swift syntax/typechecking/rendering/native control behavior are not proven by text predicates. No fabricated screenshots/browser mockups/FPS results.

## Required test matrix — runtime

All rows below are NOT RUN,not PASS and not observed FAIL. Static source coverage is above.

| Area | Native cases pending |
|---|---|
| Training nav | Small320pt,standard375pt,ProMax430pt,DynamicType default/AX3,VoiceOver;4 labels/selected state/horizontal scroll |
| Activity | Previous/next month/today,selected day,gym/run/both/rest,AX/narrow DatePicker fallback and full day details |
| Gym | Active plan,rest,today,completed session,no plan,future plan,long title,natural vertical spacing/no overlap |
| Recap | Inline header,all periods,no activity,no GPS distance,real chart/bar,no overlap,large type |
| Running | No records,somePB,partial route,noGPS,time-only completion,normal GPS route/replay;finish/pause/history smoke |
| Bottom bar | Every normal tap,hold alone(no change),left/right,multi-step,jitter,first/last no-wrap,cancel(no rollback),onehaptic/change |
| Accessibility/system | VoiceOver,SwitchControl,ReduceMotion,scroll/back/home indicator gestures,foreground/background,small/ProMax safe areas |

## Final output / acceptance

PHASE:2/7
STATUS:PARTIAL — source chunks complete,native acceptance required.
SKILLS USED:UI/UX Pro Max;interface-design;design-ios-interfaces;implement-swiftui-ios;review-hig-compliance;ux-heuristics;Impeccable(native adapt).
GYM OVERLAP:source structural treatment complete;runtime NOT RUN,not yet PASS.
RECAP OVERLAP:source structural treatment complete;runtime NOT RUN,not yet PASS.
ACTIVITY CALENDAR:source implemented with native fallback;runtime NOT RUN.
RUNNING EMPTY STATES:source implemented;runtime NOT RUN.
BOTTOM TAB PRESS-DRAG:PARTIAL.
HIG REVIEW:CONCERN pending native conflicts/assistive-tech testing.
NORMAL TAP PRESERVED:YES(source),runtime NOT RUN.
HAPTIC:YES(source),one per actual selection;physical feedback NOT RUN.
ACCESSIBILITY:native alternatives/selected traits/large text fallback implemented;VO/SwitchControl NOT RUN.
LEGACY COLORS MIGRATED THIS PHASE:18 literal occurrences;semantic alias substitutions are additional,not counted as literal removal.
BUSINESS LOGIC MODIFIED:NO.
BACKEND MODIFIED:NO.
DATABASE/MIGRATIONS/PRODUCTION:NONE.
PUSH/COMMIT/DEPLOY/APPSTORE:NONE.
PHASE3 READY:NO — native Phase2 gate pending;new approval required regardless.

KNOWN ISSUES:native build/render/gesture unverified;optional read-only agent quota failure;Root still dark by design;legacy button contrast debt remains;prior unrelated standalone/backend/AppStore/site/Desktop tasks parked. No fresh backend issue introduced or investigated here.

NEXT EXACT STEP:on Mac in the same checkout,run xcodebuild -list -project IOS_Client/GymManagerClient.xcodeproj and xcrun simctl list devices available;then xcodebuild test -project IOS_Client/GymManagerClient.xcodeproj -scheme GymManagerClient -destination 'platform=iOS Simulator,id=<actual available device UUID>'. Build/run3 ClientTrainingPreview specimens and execute matrix above on simulator plus physical iPhone gestures/haptics/VO/SwitchControl. Fix native failures inPhase2 scope only;if gestures conflict,remove shortcut rather than alter primarytap/system behavior. Capture real screenshots. Wait for user approval before Phase3. NO push/deploy.
