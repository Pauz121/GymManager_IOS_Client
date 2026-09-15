# GymManager Client iOS — Activity + Advanced Running report

Date: 2026-09-15

## 1. Activity architecture

The existing local, per-user `ClientActivityState` remains the only Client execution store. `ClientActivityInsights` is a pure aggregation layer over completed gym executions and saved running results; it introduces no second activity/calendar persistence source.

Training now exposes `Attività`, `Palestra`, `Corsa` and `Riepilogo`. `Attività` is the default. Running remains capability- and assigned-plan-gated, while historical activity aggregation does not duplicate sessions.

## 2. Calendar

The Activity screen renders a compact fixed six-week monthly grid, with previous/next navigation and an `Oggi` return action. Each day is derived from real completion timestamps and distinguishes gym, running and combined days through both color and symbols. A tap displays the selected day's actual sessions; empty days show a compact neutral state.

## 3. Monthly summary

The selected month reports supported values only: completed gym sessions, runs, measured running kilometers, active time, unique active days and running PB achievements recorded in that month.

## 4. Gym integration

No workout execution behavior was rewritten. Once `finishWorkout` assigns `completedAt`, the existing execution automatically appears in Activity and Recap. Plan, sessions, exercises, sets, rest timer, notes and post-workout feedback remain unchanged.

## 5. Running metrics

The live map and existing CoreLocation pipeline remain in place. The live dock now presents simultaneously:

- elapsed active time;
- measured distance;
- stabilized current pace;
- stabilized current speed;
- average pace;
- average speed.

The pace/speed selector is retained specifically for the Lock-Screen/Dynamic-Island Live Activity, so the foreground screen always shows both values while the compact background presentation remains user-selectable.

## 6. Pace

Pace is calculated from actual distance and active elapsed time. It remains unavailable below the valid movement threshold instead of emitting extreme or fabricated values.

## 7. Speed

Speed in km/h is the same stabilized meters-per-second source multiplied by 3.6. Average speed is measured route distance divided by active elapsed hours; pace and speed therefore remain mathematically coherent.

## 8. Smoothing

CoreLocation continues accepting only accurate, chronological and plausible points. A pure 30-second trailing-window calculation publishes a new stabilized current speed no more frequently than every 25 active seconds. It requires at least ten seconds of valid samples and rejects values outside the existing plausible running range.

## 9. Splits

`ClientRunningAchievements.splits` interpolates the exact crossing time for every 1,000-meter threshold from cumulative route distance and active sample time. The live screen gives a short haptic and a four-second split toast; the final report lists every completed kilometer. A partial final kilometer is not mislabeled as a full split.

## 10. Personal Best

Supported target distances are exactly 1K, 3K, 5K and 10K. A distance is eligible only when the recorded route actually covers it; no 10K is extrapolated from a shorter run.

## 11. Best Effort

For each target, the engine evaluates consecutive route windows starting at recorded samples and interpolates the target-distance endpoint between adjacent GPS samples. This detects an internal best effort inside a longer run rather than relying only on integer splits or on the session's final distance.

## 12. Top 3

The leaderboard keeps the best effort from each persisted session, sorts by duration and retains three distinct session IDs. The Running home shows four PB cards, and tapping an available distance opens time, date, average pace/speed, delta from first place and whether the effort came from a longer run.

## 13. End summary

The existing fast route replay and Reduce Motion bypass remain. The final screen then shows distance, duration, average pace, average speed and maximum speed, followed by all full-kilometer splits. If the session established one or more chronological records, every new PB is shown with the prior comparison when available. Unsupported calories, heart rate and elevation remain absent.

## 14. Data model

No backend schema was added. New route samples persist an optional active `elapsedSeconds`; old saved samples remain decodable and fall back to chronological GPS timestamps. PB, Top 3 and calendar values are deterministically reconstructed from the persisted sessions, avoiding duplicated record state.

## 15. Location / HealthKit

CoreLocation route is the source of truth for running distance, splits and best efforts. `ClientRunningExecution` is the source of truth for active duration. HealthKit remains the daily-step source and does not overwrite a run's CoreLocation distance or pace. Existing When-In-Use authorization, background location behavior, accuracy filtering and Live Activity integration are preserved.

Historical routes saved before active sample time was introduced use raw GPS timestamps; a manual pause in those older runs can make their split/PB duration slower. New sessions persist active elapsed time and exclude pause duration from those calculations.

## 16. Gemini contribution

- Activities calendar: first attempt `GYM-IOS-ACTIVITY-CALENDAR-20260915-001` failed before execution because sandboxed Antigravity could not access its authenticated profile/network. No response, conversation or file change occurred. Retry `GYM-IOS-ACTIVITY-CALENDAR-20260915-002` succeeded, conversation `8dd2df37-0ea3-4c38-b582-2d9619b94a8f`.
- Running live: `GYM-IOS-RUNNING-LIVE-20260915-001`, SUCCESS, conversation `4578b501-f2af-41af-aca1-ee57e58adbbc`.
- Running end summary: `GYM-IOS-RUNNING-SUMMARY-20260915-001`, SUCCESS, conversation `0eb0492c-ec64-4796-8cf1-2c1845e53bec`.
- Personal Best / Top 3: `GYM-IOS-RUNNING-PB-20260915-001`, SUCCESS, conversation `2d449c23-741b-4e40-aebe-706285dbbb6b`.
- Monthly recap: `GYM-IOS-ACTIVITY-RECAP-20260915-001`, SUCCESS, conversation `8264ebdd-ed1e-4f73-8548-d4b38e9848a7`.

Codex accepted every usable result with modifications: centralized tokens replace suggested ad-hoc colors; unsupported gym records, calories/HR/elevation and synthetic calls to action were rejected; real durations are not silently clamped. Gemini modified no files. Codex implemented and reviewed the accepted design.

## 17. Tests

The native XCTest source now covers:

- no split below 1 km and automatic successive splits;
- 30-second stabilized speed and insufficient-window fallback;
- internal 3K best effort inside an 8K run;
- no 10K extrapolation;
- best efforts for 1K, 3K, 5K and 10K when covered;
- Top 3 ordering and session deduplication;
- multiple PBs from one run;
- gym/run day aggregation, empty day and period interval.

Windows static validation: PASS, 86 checks at the implementation checkpoint. Xcode compilation and execution of the native test target are not available on this Windows host.

## 18. Known issues

- Xcode build, XCTest runtime, simulator layout, VoiceOver and physical-device GPS/background validation remain required on macOS/iPhone.
- Historical route samples without `elapsedSeconds` use timestamp fallback as described above.
- Calorie, heart-rate and elevation metrics are intentionally not displayed because there is no verified source in the current Client model.

## Database / migrations

- CREATED: NO
- APPLIED LOCAL: NO
- APPLIED PRODUCTION: NO
- Supabase data, Auth, RLS, Storage and remote permissions changed: NO

## Build status

- XCODE BUILD: NOT AVAILABLE
