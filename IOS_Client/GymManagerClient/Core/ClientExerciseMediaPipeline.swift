import Foundation

/// Presentation only: no fuzzy name matching, guessed roles or activation weights.
struct ClientExerciseMusclePresentation {
    let primary: [ClientMuscleRegion]
    let secondary: [ClientMuscleRegion]
    let unclassified: [String]

    init(exercise: ClientExercise) {
        if let links = exercise.catalogMuscles, !links.isEmpty {
            primary = Array(Set(links.filter { $0.hasKnownRole && $0.isPrimary }.compactMap(\.region))).sorted { $0.rawValue < $1.rawValue }
            secondary = Array(Set(links.filter { $0.hasKnownRole && !$0.isPrimary }.compactMap(\.region))).sorted { $0.rawValue < $1.rawValue }
            unclassified = links.filter { !$0.hasKnownRole || $0.region == nil }.map(\.name)
        } else {
            let primaries = exercise.primaryMuscles ?? []
            primary = primaries
            secondary = (exercise.secondaryMuscles ?? []).filter { !primaries.contains($0) }
            unclassified = []
        }
    }
}

enum ClientExerciseMediaPipeline {
    // Candidate keys, NOT approved or bundled clips. No executable robot fallback.
    static let prototypeKeys = [
        "bench_press_v1", "squat_v1", "lat_pulldown_v1", "shoulder_press_v1",
        "biceps_curl_v1", "seated_row_v1", "leg_press_v1", "romanian_deadlift_v1",
        "lateral_raise_v1", "triceps_pushdown_v1"
    ]
    static let approvedAssetKeys: Set<String> = [] // Populate only after technical/native/rights review.

    static func approvedURL(for key: String?, bundle: Bundle = .main) -> URL? {
        guard let key, prototypeKeys.contains(key), approvedAssetKeys.contains(key) else { return nil }
        return bundle.url(forResource: key, withExtension: "mp4", subdirectory: "ExerciseMedia")
    }
}
