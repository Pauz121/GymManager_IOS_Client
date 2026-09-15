# GymManager Client iOS — Phase 1 report

> Historical architecture baseline. The current executable-workout, HealthKit and GPS Running status is documented in `CLIENT_IOS_PHASE1_UX_REPORT.md`.

## Outcome

A separate native iPhone Client application now exists at `IOS_Client/`. It is written in Swift 6 and SwiftUI, uses `NavigationStack`, `TabView`, async/await and the same exact Supabase Swift dependency (2.55.1) as the Trainer app. The existing Trainer project and sources were not modified.

The Client opening entry point is `IOS_Client/GymManagerClient.xcworkspace`, which contains:

- the independent `GymManagerClient.xcodeproj` for Client only;
- a separate Client test target and shared Client scheme.

The Trainer/Super Admin app remains independently at `IOS/GymManager.xcodeproj`; it is not a member of the Client workspace.

## Client identity and visual language

The Client app intentionally does not copy the Trainer design. Its design system is restrained claymorphism plus minimalism: warm limestone canvas, softly raised surfaces, controlled double shadows, continuous corners, warm terracotta accent, desaturated sage status color, high-contrast warm ink and system typography. The family relationship is carried by product language and a limited brand accent, not by reusing the Trainer component system.

Gemini's contrast finding was verified numerically. The final small-text accent and sage colors exceed the 4.5:1 target against the light canvas/tinted surface. The root currently forces Light Mode until a complete dynamic palette is designed.

## Navigation and pages

The five primary tabs are:

1. `Oggi` — daily workout/nutrition summary, next Trainer appointment, personal Agenda item and warnings.
2. `Scheda` — active published Trainer plan, current week, sessions and exercise prescriptions, read-only.
3. `Nutrizione` — active published plan, current day, meals and foods, read-only.
4. `Progressi` — professional weight/measurement history, with explicit Phase 2 placeholders for photos and HealthKit.
5. `Spazio` — Agenda, Aggiornamenti and Account.

Every primary tab owns an independent `NavigationStack`. Empty, loading and error states are native and accessible. The Debug demo badge uses a safe-area inset and does not intercept touches.

## Connection modes

### Trainer-connected

The repository resolves the authenticated Supabase user, requires an active `client` profile, then reads `clients` by `auth_user_id`. It rejects duplicate, inactive or mismatched links. `client_id` and `trainer_id` never come from a route, editable field or client metadata. Workout/nutrition queries require matching Client and Trainer, `active`, `client_plan`, non-null publication and valid dates. Appointments also require `client_visible = true` and `scheduled`.

### Standalone

An active Client profile without a linked `clients` row is treated as standalone and receives no professional data. Personal Agenda remains available. Personal workout/nutrition builders and self-registration remain Phase 2; the current UI reports this honestly and never fakes success.

### Trainer code

The native UI now validates the `GM-XXXX-XXXX-XXXX-XXXX-XXXX` format and invokes the authenticated `redeem-client-link-code` Edge Function from onboarding or Account. After a successful atomic redemption it reloads identity and professional data, while server errors remain sanitized. The existing migration keeps codes in a private schema and prevents reuse or cross-account linking. The migration and Edge Function still require an explicitly authorized Supabase deployment before this flow can work in production.

## Data and security

- The Client uses a separate Keychain auth storage service.
- Live backend settings are supplied through the ignored `Config/Local.xcconfig`; the repository contains only a placeholder example and no service-role credential.
- The repository exposes reads only for professional data. Password update is scoped to the authenticated Supabase Auth user.
- RLS remains authoritative; frontend filters are defense in depth.
- Personal Agenda uses local encoded storage namespaced by live/demo source and authenticated user UUID.
- Trainer appointments are visually and technically separate from personal Agenda tasks.
- Demo data is wrapped entirely in `#if DEBUG`, uses fake UUIDs and the `.invalid` email domain, has a persistent label and is never a fallback for live failures.
- HealthKit is a labelled placeholder; no entitlement, framework access or permission prompt was added.

## Gemini / Antigravity audit

### Architecture and UX analysis

- ID: `GYM-CLIENT-IOS-UX-20260911-002`
- Status: SUCCESS, provider `SUCCESS`, exit 0
- Conversation: `078e5d98-a55e-4b8e-957a-63a77afe0f02`
- Files changed by Gemini: none
- Codex result: accepted workspace/tabs/clay-minimal direction; rejected Trainer self-disconnect, local progress writes and health-data offline cache.

The preceding ID `GYM-CLIENT-IOS-UX-20260911-001` failed authentication before any model execution and is not counted as Gemini use.

### Implementation review

- ID: `GYM-CLIENT-IOS-REVIEW-20260911-001`
- Status: SUCCESS, provider `SUCCESS`, exit 0
- Conversation: `95664513-d0c3-4104-aca9-47e9e557dc50`
- Files changed by Gemini: none
- Codex result: fixed safe-area/hit-testing, small-text contrast and scalable empty-state icon; rejected a false Dark Mode finding because the root already forces Light Mode; retained query concurrency and shadow profiling as measured-device optimizations rather than unverified blockers.

## Validation

The read-only validator `IOS_Client/scripts/validate-client-ios.ps1` completed 27/27 checks after the relocation:

1. workspace XML;
2. shared scheme XML;
3. Info.plist XML;
4. privacy manifest XML;
5. Client workspace contains only the Client project;
6. Client project root is `IOS_Client`;
7. app and unit-test targets exist;
8. exact Supabase Swift version 2.55.1;
9. balanced Xcode object braces;
10. all Xcode object IDs resolve;
11. self-contained Client configuration with an optional ignored local override;
12. independent Client bundle identifier;
13. client-safe Supabase build-setting references;
14. Debug-only demo source;
15. no service-role marker;
16. no professional-data writer in the repository;
17. identity derived from `auth_user_id`;
18. active/published plan filters;
19. visible/scheduled appointment filters;
20. exactly five tabs;
21. safe/non-interactive Demo badge;
22. all seven functional pages;
23. visible read-only and Trainer labels;
24. Agenda namespace by source/user;
25. at least 18 native unit tests;
26. no Client reference in the Trainer project;
27. no Client application artifact remains inside `IOS/`.

The Client test target includes coverage for identity normalization, professional read-only policy, Trainer connection protection, local Agenda isolation and validation, Trainer-code normalization/validation/response decoding, fixed Monday–Sunday week logic, empty/standalone state, Debug demo data, one-way updates and the HealthKit boundary.

`git diff --check` passed for tracked changes and the tracked Trainer tree compares unchanged with `HEAD`.

## Build status and deletion gate

`XCODE BUILD: NOT AVAILABLE ON THIS HOST`

This Windows host has neither Xcode nor the Apple SDK, so neither compilation nor simulator/device navigation can be claimed. The new project, workspace, schemes, XML, file membership and object references passed static validation, but the 24 XCTest cases remain pending execution on macOS.

`ClientDesktop/` has therefore **not** been deleted. Its useful behavior is mapped and ported, but the explicit deletion prerequisite “the native Client app compiles” is not provable here. After a macOS build/test and navigation smoke test pass, Codex must perform one final unique-content and Git status/diff review before removing the temporary folder.

## Phase 2

- Deploy and smoke-test the already prepared private Trainer-code migration and Edge Functions in the authorized Supabase environment.
- Standalone registration plus personal workout/nutrition builders.
- App icon/branding production assets and complete Dark Mode palette.
- Push notifications and publication event feed if the backend exposes a safe contract.
- Protected progress-photo flow.
- HealthKit design, privacy review and explicit permission flow.
- Device performance measurement for clay shadows and optional concurrent bootstrap fetching.
- macOS CI or local Xcode build/test, signing and accessibility/device QA.

## Database / migration

- Migration created: NONE.
- Migration applied: NONE.
- Supabase configuration changed: NONE.
- RLS/grants changed: NONE.
- Deployment: NONE.
