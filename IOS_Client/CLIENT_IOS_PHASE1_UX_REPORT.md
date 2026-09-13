# GymManager Client iOS — Phase 1 UX report

Date: 2026-09-13

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

Running is hidden unless both the Client capability and an assigned running plan exist. The active foreground run uses CoreLocation and MapKit to show:

- a live Apple map and real traversed polyline;
- elapsed time and measured distance;
- a selectable live metric in `km/h` or `min/km`;
- a pause/resume action;
- a 1.25-second hold-to-finish control.

The location prompt is deferred until Start is tapped. Samples with poor horizontal accuracy, implausible jumps or implausible running speed are rejected. Maximum speed requires compatible consecutive fixes to reduce isolated GPS spikes. Pace becomes unavailable below the walking/running threshold instead of showing an extreme value.

After finish, the real route is replayed in at most approximately 2.5 seconds and can be skipped. Reduce Motion bypasses the replay. The final summary shows route, distance, duration, average pace, average speed and filtered maximum speed. Results and route points are saved locally per authenticated/demo user and remain in the Running history.

Foreground-only limitation: background location mode is intentionally not enabled. The screen stays awake during an active run, but location updates may pause if iOS suspends the app or the screen is locked. No background-tracking claim is made.

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
- `GYM-CLIENT-IOS-RUNNING-GPS-REVIEW-20260913-001`: successful GPS Running review, conversation `1c72b404-d343-4dc9-bc78-18d411bd5c03`. Codex accepted map-first hierarchy, explicit metric toggle, protected finish, short replay, GPS filtering and Reduce Motion handling; background tracking was deliberately excluded.
- `GYM-CLIENT-IOS-PHASE1-FINAL-REVIEW-20260913-001`: successful final acceptance review, conversation `40d87d19-9363-4d43-9a95-6deabdc66207`. Result: ACCEPT WITH MINOR FOLLOW-UP and no release-blocking UX defect. Codex added the explicit foreground-only Running notice; exercise skip/substitute remains a future product contract decision.

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

- Static Client validator: PASS, 49 checks after the Swift 6 Core Location conformance correction.
- Native XCTest definitions: 36.
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
