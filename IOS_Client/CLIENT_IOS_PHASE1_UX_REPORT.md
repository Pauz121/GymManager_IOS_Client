# GymManager Client iOS — Phase 1 UX report

Date: 2026-09-13

## Client registration and optional Trainer linking — 2026-09-15

- The launch screen now contains only `FIT MANAGER`, `Accedi` and `Registrati`.
- Registration is split into two native steps: personal data (`Nome`, `Cognome`, biological sex and email), then credentials (`Username`, password and confirmation). Client validation mirrors the backend contract; passwords are never stored or logged by the app.
- Signup uses Supabase Auth with constrained metadata. The companion non-destructive migration creates the `client` profile inside the Auth-user transaction and never trusts a client-supplied role, Trainer ID or privileged flag.
- A standalone signup creates only the Auth/profile identity, not a duplicate professional `clients` row. A later valid Trainer code atomically connects the authenticated user to the Client row that the Trainer already created.
- After the first authenticated load, standalone Clients see the optional `Hai un codice di accesso?` flow. `Non ora` is persisted server-side so the prompt does not reappear; the same `TrainerCodeEntryForm` remains available in Account.
- Existing Trainer-connected Clients keep their current login and plan-loading behavior. Connected accounts cannot request a second primary link or disconnect from the Client app.
- Email-confirmation-required projects show a dedicated confirmation screen and return the user to login after verification.
- Antigravity review `GYM-IOS-REGISTRATION-UX-20260915-001` failed before analysis because file-reading permission was denied; it produced no result and changed no files. The sanitized retry `GYM-IOS-REGISTRATION-UX-20260915-002` completed successfully (conversation `e0a13aba-3ca7-4183-8b44-7bbc544d6776`). Codex accepted the two-step hierarchy and shared code component with modifications: `Accedi` remains first, password minimum remains 12, codes use the real `GM-XXXX-XXXX-XXXX-XXXX-XXXX` format, and onboarding completion is server-persisted.
- Static validation: PASS, 110 checks. Xcode build/XCTest and live Auth/email/linking smoke tests remain pending on macOS and on the correctly migrated backend.
- Backend artifacts prepared locally: `20260915145227_client_self_registration.sql`, `client_self_registration.sql`, and the existing `redeem-client-link-code` safe error update. Production migration/function deploy: NOT APPLIED in this session.

## Focused UX refinement and Trainer linking — 2026-09-15

- Running Live Activity now uses a charcoal/black surface, white metric values and a brighter red accent for active and paused states.
- Running opens with the primary `Inizia corsa`/`Riprendi corsa` action; assigned-session title, description and target blocks no longer delay entry.
- The Running recap includes a horizontal distance scale with an exact marker for the kilometers recorded in the selected period.
- Palestra and Riepilogo navigation/content cards use reduced padding and visual weight while retaining 44-point-or-larger controls.
- Nutrition keeps horizontal navigation but uses larger 72-point day controls, a green outline for today and an outline/elevation selection state without red fill.
- Home profile/greeting, daily headline, steps, meals, workout and Agenda status now share one premium hero instead of two detached blocks.
- Progress always renders the current calendar week from Monday through Sunday and includes both completed gym and running activity per day.
- Trainer-code linking is implemented locally through the authenticated Supabase Edge Function from onboarding and Account, with format validation, sanitized errors and identity refresh. No service-role key is present in the app. Production remains unavailable until the already prepared migration and Edge Function receive a separately authorized Supabase deploy.
- Static validation: PASS, 105 checks. Native Xcode build/XCTest and visual device validation remain pending on macOS.
- Antigravity/Gemini: NOT RUN. The external code-transmission request was blocked before execution; no code or files were sent or modified. Codex completed the scoped implementation locally.

## Global dark premium visual redesign — 2026-09-15

The native Client app now uses one centralized dark fitness/performance visual system while preserving the existing functional architecture, navigation, local activity state, HealthKit, Core Location, ActivityKit and Supabase read boundaries.

### Visual system

- `ClientClay` remains the project convention but now supplies layered charcoal canvas/surfaces, high-contrast typography, a controlled red-orange brand gradient, semantic green completion, muted secondary text, shared borders, page spacing and inset surfaces.
- Standard cards use dark layered surfaces, restrained internal highlights and black depth shadows. Premium cards reserve accent glow for hero/active states. Buttons, numeric fields, progress rings, segmented progress, metric tiles and neutral directional delta badges are reusable primitives rather than page-local constants.
- The app is intentionally dark-first via `.preferredColorScheme(.dark)`. No backend or functional behavior depends on this choice.

### Navigation and screens

- The five existing `TabView` destinations remain unchanged. A safe-area-aware elevated bottom bar now provides a stronger selected state and preserves the locally stored profile avatar in `Spazio`.
- Home keeps steps immediately below the greeting, now inside the dominant daily hero with real HealthKit/demo state and workout/meal/Agenda status. Workout remains the principal CTA. The full quick meal list remains available, with per-meal calories and segmented completion.
- Workout uses a stronger plan/today hierarchy, a custom Palestra/Corsa selector, visible current/completed states, dark keyboard-safe set inputs and a non-blocking recovery dock. Completed sets remain readable and every plan session/exercise remains consultable.
- Nutrition highlights the real current day, provides a horizontal selector containing exactly the plan's days, preserves today-only completion and adapts honestly when calories are missing. Meal foods emphasize name, amount and optional calories without placeholder nutrition values.
- Progress separates today's HealthKit steps from cumulative activity, uses the latest real weight as the hero when available, compares only against the previous measurement, treats weight direction neutrally and integrates workout/weight/measurement charts into dark surfaces. No body-fat, lean-mass or step-history metric was added.
- Onboarding, Agenda, Updates, Account and Running use the same surfaces, spacing, fields, buttons and contrast. Running map, route replay, GPS metrics, background behavior and finish logic are unchanged.

### Gemini UI collaboration

- Home attempt `GYM-IOS-DARK-HOME-20260915-001`: real call, FAILED_PERMISSION because headless `read_file/ListDir` was auto-denied; response absent, files changed none, Codex rejected it.
- Home retry `GYM-IOS-DARK-HOME-20260915-002`: SUCCESS, usable. Codex accepted dark hierarchy/tokens/accessibility but kept steps at the top and all quick meals, and rejected unavailable distance/duration data.
- Workout `GYM-IOS-DARK-WORKOUT-20260915-001`: SUCCESS, usable. Codex accepted the hub/execution hierarchy, legible state system, input ergonomics and timer dock; no persisted timer percentage or hidden/collapsed exercise behavior was introduced.
- Nutrition `GYM-IOS-DARK-NUTRITION-20260915-001`: SUCCESS, usable. Codex accepted the current-day hero, real-day strip, optional-calorie fallback and meal hierarchy; invented meal times/macros were rejected.
- Progress `GYM-IOS-DARK-PROGRESS-20260915-001`: SUCCESS, usable. Codex accepted temporal separation, neutral deltas and chart treatment; global filters and unavailable metrics were rejected.
- All successful calls returned provider SUCCESS, exit code 0, a distinct conversation ID, no denied action and no file modification. Codex implemented and reviewed the accepted parts.

### Validation status

- Windows static source/project validator: PASS, 73/73 checks, including dark tokens, premium navigation, adaptive Home, Workout active/input state, Nutrition day selector and neutral Progress charts.
- Semantic comparison with the last dedicated iOS Client publication snapshot: exactly 18 modified files, all limited to Client UI, this report and the Client validation script; no unexpected file, deletion or dependency change.
- Xcode build/XCTest, simulator screenshots, VoiceOver, Dynamic Type and physical-device validation remain unavailable on this Windows host and must be run on macOS.
- Database, migration, RLS, Supabase data, permissions, Desktop and Trainer iOS changes: NONE.

## Premium UX and HealthKit alignment — 2026-09-14

- Daily steps now use one `HKStatisticsQuery` with `.cumulativeSum` over the current local calendar day. HealthKit performs its normal multi-source merge, so the app does not manually add overlapping iPhone, Apple Watch or third-party samples. The value refreshes on Home appearance, foreground activation, pull-to-refresh and every 60 seconds while Home remains visible. The last refresh time is shown.
- The old Home “Il tuo percorso” summary is replaced by “Il tuo oggi”: a brand-forward status card that reports only real workout, meal and personal Agenda state.
- The Home Nutrition card has stronger hierarchy, calorie visualization, meal progress, animated one-tap completion, per-meal calories and clear completed/pending states.
- The shared visual system now has warmer layered backgrounds, deeper clay surfaces, high-contrast brand hero cards, richer metric tiles and restrained pressed-state micro-interactions.
- Every exercise listed inside a workout session is tappable. Its detail sheet shows the supported prescription fields, operational notes, Trainer video when a URL exists, and recent local execution history with completed sets, actual load and personal notes. RIR/RPE and photos are intentionally not displayed because the current Client model does not expose those fields.
- Progressi is rebuilt around real data: overview, four KPI tiles, seven-day completed-workout chart, weight area/line trend, waist/hip trends, current-day HealthKit steps and saved running summaries.
- Static validation: PASS, 66/66 checks. Two additional XCTest definitions verify the local-day HealthKit window and timezone behavior. Xcode compilation and device validation remain pending on macOS.
- Antigravity delegation `GYM-CLIENT-IOS-PREMIUM-UX-20260913-001` was attempted but did not run: authentication timed out before any model turn (0 tokens, no conversation ID, no file change). Codex completed and reviewed the work; no Gemini result is claimed.
- Database, migration, Supabase, Desktop and Trainer iOS changes: NONE.

## Phase 2 UX update — Home, plans and background Running

The requested Client-only UX update is implemented in the local `IOS_Client/` source:

- Home places daily steps directly below the greeting with an accessible circular progress graph.
- The compact Nutrition card keeps every meal visible, shows each meal's calories and advances a calorie pie only when that meal is checked. Calories come from `nutrition_meal_items.calories_kcal`; an incomplete source is shown as unavailable rather than estimated.
- Home shows today's and undated personal Agenda activities with a direct completion check.
- The Palestra section shows the full plan name and every workout as a tappable row. Each detail remains inspectable after completion and shows its exercises and saved set progress.
- Nutrition shows the full plan name and every available day. Every day can be inspected, but meal completion controls exist only for the current weekday.
- Account accepts a profile image through the native Photos picker. The image is normalized, protected and namespaced per Auth/demo UUID in Application Support, then used in the Spazio tab. It is deliberately local-only because no verified avatar Storage bucket/policies exist yet.
- Running now enables continuous Core Location updates after the user explicitly starts a run, shows the iOS background-location indicator, and publishes distance, elapsed time, average pace or average speed to a dedicated ActivityKit/WidgetKit Live Activity on the Lock Screen and Dynamic Island. Updates are throttled; the system timer continues visually without a one-second app write loop.

No database table, migration, RLS policy, Supabase data, Trainer iOS source or Desktop source was changed. The existing local execution/nutrition/running persistence contract remains unchanged.

Validation for this update: Windows static validator PASS, 58 checks; 39 XCTest definitions are present. Xcode compilation, Widget-extension signing, simulator accessibility and physical-iPhone background/Lock-Screen testing remain required on macOS.

Antigravity delegation `GYM-CLIENT-IOS-PHASE2-UX-REVIEW-20260913-001` completed successfully (conversation `fbbdd643-5ba0-43ef-a0ff-2c05fe1dbea6`). Codex accepted the information hierarchy with modifications: no inferred calories, local-only avatar until Storage RLS is proven, and throttled Live Activity state updates.

The separate final-review attempt `GYM-CLIENT-IOS-PHASE2-FINAL-REVIEW-20260913-001` did not execute: Antigravity authentication timed out before a model turn (zero tokens, no conversation ID, no files changed). It is logged as FAILED and is not claimed as Gemini work. Codex performed the final source/static review.

This report belongs in `IOS_Client/`, not `IOS/`: `IOS/` is reserved for the separate Trainer/Super Admin application.

## 1. Home

The native SwiftUI Home is organized around “What do I need to do today?”. It uses the authenticated Client first name and the current localized date. The main cards show today's assigned workout, daily nutrition completion, Apple Health steps, the next Trainer appointment and today's personal Agenda item. Standalone mode replaces unavailable professional data with honest personal-path actions.

## 2. Today's workout

An assigned session displays the plan, current week, session name and exercise count. The primary action starts or resumes the local execution. When completed, the card remains visible with completion status and measured duration.

## 3. Nutrition

Today's meals can be marked complete from Home or Nutrition. Completion is reversible, scoped to meal and calendar day, persisted per user/source and summarized with a small progress indicator. Foods and quantities remain read-only professional data.

## 4. Steps

HealthKit step reading is implemented. GymManager requests read access only after an explicit “Connect Apple Health” action, never at launch. The UI distinguishes unavailable, loading, no-data and failure states without fabricating values. Debug personas use clearly labelled synthetic step values.

## 5. Workout execution

Each exercise stays visible throughout execution. Prescribed repetitions/load remain separate from the actual values. A Client can complete or undo each set, see remaining work, add an optional quick exercise note, and complete the workout only after every exercise is done.

## 6. Set logging

Set logs persist prescribed and actual repetitions/load plus the completion timestamp. The professional plan is never structurally edited.

## 7. Rest timer

Completing a set starts the prescribed rest timer automatically. The compact timer supports pause, resume, +30 seconds and skip without blocking exercise content. Its authority is an end timestamp, so navigation does not corrupt elapsed time.

## 8. Notes

Exercise notes use a compact optional sheet. Saving a note adds a visible indicator but does not interrupt the workout or modify Trainer programming.

## 9. Post workout

The final sheet contains only perceived effort, workout quality, pain yes/no and one optional note. Saving marks the workout complete, records duration and updates Home/Progress locally.

## 10. Running

Running is hidden unless both the Client capability and an assigned running plan exist. The active run uses CoreLocation and MapKit to show:

- a live Apple map and real traversed polyline;
- elapsed time and measured distance;
- a selectable live metric in `km/h` or `min/km`;
- a pause/resume action;
- a 1.25-second hold-to-finish control.

The location prompt is deferred until Start is tapped. Samples with poor horizontal accuracy, implausible jumps or implausible running speed are rejected. Maximum speed requires compatible consecutive fixes to reduce isolated GPS spikes. Pace becomes unavailable below the walking/running threshold instead of showing an extreme value.

After finish, the real route is replayed in at most approximately 2.5 seconds and can be skipped. Reduce Motion bypasses the replay. The final summary shows route, distance, duration, average pace, average speed and filtered maximum speed. Results and route points are saved locally per authenticated/demo user and remain in the Running history.

Background update: the earlier foreground-only limit has been superseded. After an explicit Start, the app enables the `location` background mode, keeps continuous Core Location updates active, shows the standard iOS background-location indicator and exposes a Live Activity on the Lock Screen/Dynamic Island. Forced termination and reboot recovery are not implemented.

## 11. Progress

Progress now combines locally completed workouts, available daily steps, existing professional weight entries and saved running summaries. No unsupported health metric is inferred.

## 12. Agenda

The existing Client Agenda behavior and visual direction are preserved. Personal activity, date/time, priority, notes and completion remain isolated from Trainer appointments. Today's personal item can surface on Home.

## 13. Demo accounts

Two isolated `#if DEBUG` personas are available without credentials in source:

- Trainer-connected: synthetic Client, Trainer, workout, nutrition, Agenda/progress-ready state, appointment and enabled running.
- Standalone: no Client row, Trainer, professional workout or nutrition data.

They have different fake Auth UUIDs and therefore separate Agenda/activity namespaces. Real Supabase Auth demo accounts were not created because no non-production test/dev project was proven. No password was written to source, reports, logs or Git.

## 14. Gemini delegations

- `GYM-CLIENT-IOS-PHASE1-UX-20260913-003`: successful seven-part Home/Workout/Timer/Nutrition/Running/mobile-hierarchy review. Codex accepted it with modifications.
- `GYM-CLIENT-IOS-RUNNING-GPS-REVIEW-20260913-001`: successful historical Phase 1 GPS Running review, conversation `1c72b404-d343-4dc9-bc78-18d411bd5c03`. Its foreground-only boundary was later superseded by the explicit Phase 2 request.
- `GYM-CLIENT-IOS-PHASE1-FINAL-REVIEW-20260913-001`: successful historical Phase 1 final review, conversation `40d87d19-9363-4d43-9a95-6deabdc66207`. Its foreground-only notice was correct for that checkpoint and is superseded by the Phase 2 implementation above.

Two earlier Phase 1 attempts did not produce usable Gemini work and remain recorded as failures in the orchestration audit.

## 15. Database

- Migration created: NO.
- Applied locally: NO.
- Applied to production: NO.
- Supabase data changed: NO.

Workout execution, meals, HealthKit state and running history are currently local device state. This avoids inventing a backend contract or touching the shared Desktop/Supabase scope during an iOS Client-only phase.

## 16. RLS

Existing professional-data RLS and read filters are unchanged. No new remote table or grant was introduced. Local state is namespaced by authenticated/demo user UUID plus live/demo source. Remote Client/Trainer sharing for execution logs remains a future separately reviewed backend phase.

## 17. Tests

- Static Client validator: PASS, 58 checks after the Phase 2 background/Live Activity update.
- Native XCTest definitions: 39.
- Coverage includes identity/mode rules, Agenda and activity namespace isolation, persistence round-trip, day-scoped meal completion, timestamp rest timer, set parsing/log retention, route-only distance calculation, running pace/speed and capability gating.
- Secret/service-role scan: no credential is present in Debug demo data; no service-role marker or professional-data writer exists in Client source.
- Trainer scope: `IOS/` has no Client membership/reference and was not modified.

## 18. Xcode/build status

`NOT AVAILABLE ON THIS WINDOWS HOST`.

The Client workspace/project XML, file references, configuration, plist, entitlements, asset catalog, privacy manifest and static source contracts pass validation. Compilation, XCTest execution, simulator/device UX, HealthKit and real GPS testing remain required on macOS/Xcode and a physical iPhone.

## Branding

The supplied `img/logo.png` is installed as the Client AppIcon through a 1024×1024, opaque, mechanically resized asset. Its design was not regenerated or reinterpreted.

## Current status summary

- HOME: PASS (static/source validation)
- TODAY WORKOUT: PASS (static/source validation)
- WORKOUT EXECUTION: PASS (static/source validation)
- REST TIMER: PASS (static/source validation)
- POST WORKOUT: PASS (static/source validation)
- NUTRITION TODAY: PASS (static/source validation)
- MEAL COMPLETION: PASS (static/source validation)
- DAILY STEPS: REAL integration, device test pending
- RUNNING: IMPLEMENTED, physical-device GPS test pending
- AGENDA: PASS (preserved)
- DEMO TRAINER CLIENT: Debug persona created; real Auth account not created
- DEMO STANDALONE CLIENT: Debug persona created; real Auth account not created
- ACCOUNT ISOLATION: PASS for local namespaces; remote login isolation not run
- DATABASE MIGRATIONS: NONE
- XCODE BUILD: NOT AVAILABLE

## Next phase

On macOS: resolve packages, build, run all XCTest cases, test both Debug personas in simulator, then test HealthKit and Running on a physical iPhone. Separately design and approve a non-destructive backend/RLS contract if Trainer-visible workout, meal or running logs are required.
