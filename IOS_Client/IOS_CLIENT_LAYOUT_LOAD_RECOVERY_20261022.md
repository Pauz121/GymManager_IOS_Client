# Layout/read lifecycle — local safe checkpoint (22 October 2026)

Paused on the user's new Phase 1/7 foundation request. No push/deploy/backend change.

## Source diagnosis and local changes

1. Recap/Gym: fixed-size decorative circle participated in the shared background ZStack's sizing, independently of the smaller card content. Local fix keeps the base shape as layout owner, clips the circle as a noninteractive overlay, gives Gym a natural VStack and multiline title, and provides a wrapping Recap metric layout. UIKit measurements/tests added, NOT RUN on Windows.
2. Progress: TabView.task(id:selectedTab) called refresh on entry; refresh read errors fed the global notice alert. HEAD contains the exact reported Trainer reassurance. Progress's own task reads HealthKit only. Read chain: tab→refresh→Auth.session→identity SELECT→snapshot SELECT→notice→Root.alert. NO Trainer mutation in that read path (source inspection, not device instrumentation). Local fix removes tab-driven reload, separates refreshError/section errors from action notice, adds retryable Progress error.
3. Home: section catch blocks treated CancellationError/URL cancellation as real fetch warnings and continued through four sections; a second tab-driven automatic reload could overwrite warnings. Local fix propagates cancellation, uses session-owned bootstrap/single-flight refresh, session/account/generation guards, explicit idle/authBootstrap/loading/loaded/empty/error and typed section states. Real failures retain cached data only for unchanged ownership, stay visible until explicit retry, and are not silently retried on foreground.
4. DEBUG logs use random request IDs, fixed stage/error codes and prerequisite booleans. Legacy registration logging no longer dumps user IDs or server prose.

## Evidence limits

First failed HTTP request/status on the user's device: UNKNOWN. Why that particular second request succeeded: NOT OBSERVED. Auth/client-readiness race on that device: NOT PROVEN. Source resolves identity before content; no fabricated early-identity diagnosis. New logs must be checked on Mac/iPhone.

## Verification checkpoint

- 202/202 source/static checks PASS; git diff whitespace check PASS.
- New native lifecycle and card-layout tests defined, not compiled/executed.
- Xcode/Swift/Simulator unavailable on Windows. All small/ProMax/DynamicType, launch/restore/offline/foreground/device acceptance: NOT RUN.
- Backend/migrations/data mutations/deployment: NONE. Commit/push: NONE.

## Next exact step (parked)

After Phase 1 and specific user approval, Mac: xcodebuild -list -project IOS_Client/GymManagerClient.xcodeproj; run GymManagerClient tests on an available iPhone simulator. Then validate two-card bounds/long titles/Dynamic Type, training/rest/no-plan, cold/slow restore/profile/client resolution/offline, rapid tabs, foreground and logout during read. Capture actual failed request codes if errors recur. Do not claim device PASS from regex checks.
