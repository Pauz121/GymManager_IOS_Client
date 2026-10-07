# Standalone Guided Workout and Exercise Visuals

## Scope

This implementation extends the native iOS Client app. It reuses the existing personal workout model, editor, workout execution and `client_personal_workout_plans` persistence. It does not create a parallel workout format and does not alter Trainer-owned plans.

## Standalone creation

Standalone clients can choose `Crea da zero` or `Crea per me`. Manual creation keeps the existing editor and now also supports exercise duplication. Guided creation uses a ten-step native wizard for experience, frequency, session duration, equipment, split, priorities, goal, nutrition phase, limitations/avoids and plan duration.

The generator is deterministic and separated into questionnaire/profile, split selection, exercise ranking, prescription and consistency validation. It uses real exercise rows from Supabase, never invents exercise IDs or absolute loads, and stores a double-progression rule across 4, 6, 8 or 12 weeks.

## Generation behavior

- Frequencies 2–6 adapt between Full Body, Upper/Lower and Push/Pull/Legs; custom group splits remain available.
- Session size is bounded from 4 to 7 exercises and favors five exercises at 60 minutes.
- Primary and secondary muscles, movement pattern, equipment and exercise type are normalized centrally from the current catalog.
- Compound, accessory and isolation ranges are prescribed by exercise role and goal. Bulk/cut/maintenance are modifiers, not simplistic repetition rules.
- Priority groups receive moderate preference/set increases without dropping weekly coverage.
- Significant injury/rehabilitation language stops automatic generation and shows a professional-safety message.
- Preview supports accept, edit and deterministic regeneration from the same answers.

## Persistence and ownership

Accepted plans are staged locally, upserted through the existing repository and read back by exact plan/user ID before the UI reports server confirmation. Guided/manual origin and generator metadata live inside the backward-compatible JSON payload; the existing database row source remains `self_created`.

UI and store mutations are blocked for Trainer-connected clients. The repository also contains the additive migration `20261004105732_restrict_trainer_connected_personal_plans.sql`, which makes personal plans read-only after linking while preserving historical visibility. That migration is not applied to production by this implementation.

## Exercise visuals

The pilot uses native SwiftUI vector loops with a static fallback. A centralized resolver maps ten common movements to versioned assets and normalized muscle metadata. Primary muscles use the app accent red; secondary muscles use the warning/orange accent. The current exercise is shown in execution and the same component appears in exercise detail.

The loop is muted, pausable, automatically paused during rest, honors Reduce Motion and exposes a combined VoiceOver description. Unmapped/custom exercises show a neutral silhouette, known muscles and verified technique instead of an error.

## Database and migrations

- New database tables: none.
- New binary storage: none.
- Production mutations/deploys: none.
- Existing local RLS migration required for backend enforcement: `Desktop/supabase/migrations/20261004105732_restrict_trainer_connected_personal_plans.sql`.
- Current database limitation: structured equipment/movement/complexity/animation columns are not present, so the compatibility metadata is centralized in app code for this pilot.

## Validation

- Windows static iOS validation covers source integration and regression assertions.
- XCTest cases were added for 2/4/5-day generation, muscle coverage, priority volume, bulk/cut behavior, bodyweight filtering, compact/long sessions, persistence metadata, determinism, safety stop and all ten visual mappings/fallbacks.
- Xcode build, XCTest execution, authenticated production save/reopen and physical-device FPS/memory/VoiceOver checks require macOS/iPhone and are not reported as passed on this Windows host.

## Known issues / next step

1. Run Xcode build and XCTest on macOS against the authoritative repository.
2. Validate a real standalone save/reopen with a test account.
3. Apply and verify the RLS migration only through an explicitly authorized Supabase production change.
4. Review pilot movements on a physical iPhone before expanding the asset library.
5. Expand structured exercise metadata server-side before claiming full animated coverage of the database.
