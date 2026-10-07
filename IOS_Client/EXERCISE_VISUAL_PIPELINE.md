# Exercise Visual Pipeline

## Sources of truth

- `exercises` remains the exercise source of truth. Saved plans keep the real exercise UUID and `source_key` when available.
- `ClientMuscleRegion` is the normalized muscle taxonomy shared by generation, validation and visual presentation.
- `ClientExerciseMetadataNormalizer` is the single compatibility layer for the current database, whose exercise rows do not yet expose structured equipment, movement and complexity columns.
- `ClientExerciseVisualResolver` is the versioned animation map. SwiftUI views consume descriptors and do not contain exercise-name rules.

## Technology selected for the pilot

The first release uses dependency-free native SwiftUI vector motion (`TimelineView` + `Canvas`) at a target of 30 fps. It is bundled, works offline, does not stream media and renders only the current exercise. Reduce Motion and the rest phase pause the loop automatically.

This pilot deliberately avoids adding unreviewed GIFs, external videos, large 3D assets or a runtime animation dependency. The descriptor/resolver boundary allows a future reviewed Rive or Lottie renderer without changing workout persistence.

## Pilot catalog

The following versioned keys are active:

- `bench_press_v1`
- `squat_v1`
- `romanian_deadlift_v1`
- `lat_pulldown_v1`
- `seated_row_v1`
- `shoulder_press_v1`
- `biceps_curl_v1`
- `triceps_pushdown_v1`
- `leg_press_v1`
- `leg_curl_v1`

Compatible variants may share an asset only when the represented movement is sufficiently equivalent. For example, flat and incline bench press currently share `bench_press_v1`. Custom or unmapped exercises receive `static_body_v1`, muscle highlights and verified technique text when available.

## Adding or replacing an asset

1. Confirm the real exercise UUID, canonical name and `source_key`.
2. Validate primary and secondary muscles against the shared taxonomy.
3. Validate movement pattern, equipment, complexity and preferred view angle.
4. Create and review the motion asset outside runtime. Do not generate assets dynamically in the app.
5. Assign a new immutable key such as `exercise_name_v2`; never silently change the meaning of an existing version.
6. Add the mapping in `ClientExerciseMetadataNormalizer` and the renderer descriptor in `ClientExerciseVisualResolver`.
7. Add resolver tests for muscles, view, asset key, version and fallback.
8. Test on a small and large iPhone: loop, scrolling, rest timer, Reduce Motion, VoiceOver, memory and offline behavior.
9. Only after device review, activate the new version and retain a safe fallback.

## Future remote assets

If remote assets are introduced, binary files belong in reviewed object storage, not database rows. The database should store only asset key/path, type, version, view angle and active state. Download one current/next asset lazily, use a bounded local cache and release unused assets. Failure must always fall back to the bundled static muscle view.

## Performance budget

- One animated exercise view at a time.
- No preloading of the entire exercise library.
- 30 fps initial target; validate before considering 60 fps.
- Pause during rest and when Reduce Motion is enabled.
- No network dependency for the pilot.
- No animation is the sole source of technique or muscle information.
