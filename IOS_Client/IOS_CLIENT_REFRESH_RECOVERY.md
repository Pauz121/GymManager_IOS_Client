# iOS Client refresh recovery — 2026-10-08

## Findings

The reported generic alert is emitted by `ClientSessionStore.refresh()` while reloading identity, before the content snapshot. Previously, the caller was SwiftUI `.task(id: selectedTab)`, canceled whenever the tab changes, and the catch treated cancellation as an update failure. This is a confirmed code defect, not a conclusively reproduced diagnosis of the user's particular device.

Read-only production inspection on `uslkraelkdjrwqjisczz` confirmed that selected identity columns exist. In the inspected last-24-hour iOS edge-log aggregate, profiles (29 requests) and clients (21) returned HTTP 200, with no identity-endpoint HTTP failure. One exercise-catalog request returned HTTP 401; this is a different operation. Successful HTTP requests do not rule out local decoding/cancellation errors.

## Fix

- One session-owned, shared refresh task survives cancellation of individual screen callers; concurrent refresh callers join the same task.
- Retrieve the actual Supabase session and verify the account ID before identity queries.
- Cancel and invalidate pending refreshes on logout, onboarding, demo switch and session reload. Check generation/account before committing results or reporting errors.
- Ignore Swift cancellation and URLSession canceled requests. Actual network, session, database permission and decoding errors remain distinguishable, without exposing server payloads.
- Preserve the active state on failure. Clear only a previous refresh notice on successful retry, not an unrelated action's notice.
- Debug diagnostics contain operation/stage/safe error code only, never tokens, passwords or personal payloads.

No database writes, Trainer-code redemption, unlinking, RLS changes, migrations, automatic logout or dependency changes were introduced. The Supabase skill informed session validation, privacy and strict read-only investigation.

## Verification

- Static iOS validator: 153/153 PASS.
- Diff whitespace check: PASS.
- Added nine native XCTest error-policy cases: cancellation (Swift/URL), actual network failure, missing session, expired JWT versus permission, private messages/code redaction, decoding and domain errors.
- SDK error signatures verified against pinned `supabase-swift` 2.55.1.
- Xcode compilation, XCTest execution and physical-device reproduction: NOT AVAILABLE / NOT RUN on Windows. Static checks do not substitute for these.
- Commit/push/deploy: NONE; not authorized for this new task.

## Mac/device acceptance

1. Build the authoritative Client workspace and run `ClientRefreshTests` plus existing tests.
2. On a connected test account, rapidly switch Home/Workout/Nutrition while a refresh is pending. No canceled-request alert; one shared refresh completes.
3. Pull to refresh, switch tabs, then verify identity/Trainer link and content remain correct.
4. Disable network, refresh and verify the visible account/data remain intact with a connection notice. Restore network and refresh: only that notice clears.
5. Start a slow refresh and log out; late completion must not restore the previous account. Sign in as another account and verify isolation.
6. If an actual error persists, capture only `operation=content_refresh stage=... code=...` from Debug console, not credentials/payloads. This identifies session, identity or content stage without assuming a backend linking failure.
