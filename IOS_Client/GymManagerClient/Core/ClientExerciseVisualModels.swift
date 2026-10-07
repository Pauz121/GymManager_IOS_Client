import Foundation

enum ClientExerciseViewAngle: String, Codable, Equatable, Sendable {
    case front
    case side
    case rear
    case threeQuarter

    var displayName: String {
        switch self {
        case .front: "Vista frontale"
        case .side: "Vista laterale"
        case .rear: "Vista posteriore"
        case .threeQuarter: "Vista 3/4"
        }
    }
}

enum ClientNativeExerciseMotion: String, Codable, CaseIterable, Equatable, Sendable {
    case benchPress
    case squat
    case romanianDeadlift
    case latPulldown
    case seatedRow
    case shoulderPress
    case bicepsCurl
    case tricepsPushdown
    case legPress
    case legCurl
    case staticPose
}

struct ClientExerciseVisualDescriptor: Equatable, Sendable {
    let assetKey: String
    let version: Int
    let motion: ClientNativeExerciseMotion
    let viewAngle: ClientExerciseViewAngle
    let primaryMuscles: [ClientMuscleRegion]
    let secondaryMuscles: [ClientMuscleRegion]
    let technique: String?

    var isAnimated: Bool { motion != .staticPose }
}

struct ClientExerciseVisualResolver {
    private struct Asset: Sendable {
        let key: String
        let version: Int
        let motion: ClientNativeExerciseMotion
        let angle: ClientExerciseViewAngle
    }

    func resolve(_ exercise: ClientExercise) -> ClientExerciseVisualDescriptor {
        let metadata = ClientExerciseMetadataNormalizer.enrich(ClientExerciseCatalogItem(
            id: exercise.catalogExerciseID ?? exercise.id,
            name: exercise.name,
            muscleGroup: nil,
            videoURL: exercise.videoURL,
            instructions: exercise.technique,
            sourceKey: exercise.catalogSourceKey,
            primaryMuscles: exercise.primaryMuscles ?? [],
            secondaryMuscles: exercise.secondaryMuscles ?? [],
            movementPattern: exercise.movementPattern,
            animationKey: exercise.animationKey
        ))
        let asset = Self.assets[metadata.animationKey ?? ""]
        return ClientExerciseVisualDescriptor(
            assetKey: asset?.key ?? "static_body_v1",
            version: asset?.version ?? 1,
            motion: asset?.motion ?? .staticPose,
            viewAngle: asset?.angle ?? preferredFallbackAngle(metadata.movementPattern),
            primaryMuscles: metadata.primaryMuscles,
            secondaryMuscles: metadata.secondaryMuscles,
            technique: metadata.instructions
        )
    }

    private func preferredFallbackAngle(_ pattern: ClientMovementPattern?) -> ClientExerciseViewAngle {
        switch pattern {
        case .horizontalPush, .kneeDominant, .hipHinge, .unilateralLower:
            return .side
        case .horizontalPull, .verticalPull:
            return .rear
        default:
            return .front
        }
    }

    private static let assets: [String: Asset] = [
        "bench_press_v1": Asset(key: "bench_press_v1", version: 1, motion: .benchPress, angle: .side),
        "squat_v1": Asset(key: "squat_v1", version: 1, motion: .squat, angle: .side),
        "romanian_deadlift_v1": Asset(key: "romanian_deadlift_v1", version: 1, motion: .romanianDeadlift, angle: .side),
        "lat_pulldown_v1": Asset(key: "lat_pulldown_v1", version: 1, motion: .latPulldown, angle: .rear),
        "seated_row_v1": Asset(key: "seated_row_v1", version: 1, motion: .seatedRow, angle: .side),
        "shoulder_press_v1": Asset(key: "shoulder_press_v1", version: 1, motion: .shoulderPress, angle: .front),
        "biceps_curl_v1": Asset(key: "biceps_curl_v1", version: 1, motion: .bicepsCurl, angle: .threeQuarter),
        "triceps_pushdown_v1": Asset(key: "triceps_pushdown_v1", version: 1, motion: .tricepsPushdown, angle: .side),
        "leg_press_v1": Asset(key: "leg_press_v1", version: 1, motion: .legPress, angle: .side),
        "leg_curl_v1": Asset(key: "leg_curl_v1", version: 1, motion: .legCurl, angle: .side)
    ]
}
