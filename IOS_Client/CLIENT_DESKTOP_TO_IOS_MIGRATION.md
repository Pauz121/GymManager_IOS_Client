# ClientDesktop to Client iOS migration

This inventory is the deletion gate for the temporary `ClientDesktop/` prototype. A row may be marked `DONE` only after the native implementation exists and its behavior has been reviewed. `ClientDesktop/` must remain present until the native app has also been built successfully with Xcode on macOS.

| ClientDesktop capability | Native iOS implementation | Status |
| --- | --- | --- |
| Separate Client application and session | `IOS_Client/GymManagerClient.xcodeproj`, independent app entry point and Client-specific Supabase auth storage | DONE |
| Onboarding choice | Native welcome screen with “Ho un codice dal mio Trainer” and “Non ho un Trainer” paths | DONE |
| Trainer code activation | Native onboarding/Account UI invokes authenticated `redeem-client-link-code`, validates the code and reloads the linked identity; server migration/function deploy is still pending | IMPLEMENTED LOCALLY / REMOTE DEPLOY PENDING |
| Standalone registration | Explicit Phase 2 unavailable state; no fake account creation | SCAFFOLDED / BACKEND PHASE 2 |
| Existing Client sign-in | Native Supabase Auth sign-in and verified `profiles`/`clients.auth_user_id` identity resolution | DONE |
| Five-destination navigation | SwiftUI `TabView`: Oggi, Scheda, Nutrizione, Progressi, Spazio | DONE |
| Home / today summary | Native `NavigationStack` home with workout, nutrition, appointment, agenda and update summaries | DONE |
| Published workout viewer | Native read-only plan/week/session/exercise views | DONE |
| Published nutrition viewer | Native read-only current-day meals and foods | DONE |
| Progress summary | Native weight/measurement history; photos and HealthKit remain labelled placeholders | DONE |
| Personal Agenda | Native local, per-user namespaced tasks, visibly separate from Trainer appointments | DONE |
| Trainer appointments | Native read-only upcoming appointments, filtered to visible/scheduled rows | DONE |
| Updates | Native read-only timeline; explicitly not a chat | DONE |
| Account and Trainer state | Native profile, connection state, password/logout actions and legal placeholders | DONE |
| Professional-plan permissions | No mutation affordances or write methods for workout/nutrition plans | DONE |
| Demo data | `#if DEBUG` fake snapshot with a persistent Demo label and no live-error fallback | DONE |
| Empty/loading/error states | Native accessible states per primary screen | DONE |
| Claymorphism minimal visual language | Client-only warm clay tokens/components, distinct from the Trainer design system | DONE |
| Automated checks | 24 native unit tests defined; 25 read-only static checks executed successfully | STATIC PASS / XCODE EXECUTION PENDING |
| Xcode build and navigation smoke test | macOS/Xcode build and simulator/device navigation verification | BLOCKED ON WINDOWS HOST |

## Deletion gate

`ClientDesktop/` may be deleted only when every useful row above is `DONE`, the Client iOS app builds with Xcode, core navigation/demo behavior has been exercised, the phase report is complete, and Codex has checked Git status/diff plus unique content one final time. On a non-macOS host the Xcode-build condition is unmet, therefore deletion is forbidden.
