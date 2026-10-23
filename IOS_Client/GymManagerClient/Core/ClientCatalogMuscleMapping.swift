import Foundation

struct ClientCatalogMuscleContribution: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let sourceKey: String?
    let relevance: Double?
    let isPrimary: Bool
    // Nil preserves historical snapshots; false means the catalog did not classify the role.
    var roleIsKnown: Bool? = nil
    var hasKnownRole: Bool { roleIsKnown != false }
    var region: ClientMuscleRegion? { ClientCatalogMuscleMapping.region(for: name) }
}

enum ClientCatalogMuscleMapping {
    // Same database taxonomy and aliases as Desktop/services/bodyRegionMap.ts.
    static func region(for name: String) -> ClientMuscleRegion? {
        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "pettorali", "petto": .chest
        case "spalle": .shoulders
        case "centro schiena": .upperBack
        case "dorsali": .lats
        case "quadricipiti": .quadriceps
        case "femorali", "catena posteriore": .hamstrings
        case "glutei": .glutes
        case "bicipiti": .biceps
        case "tricipiti": .triceps
        case "addome", "core", "addome / core": .core
        case "polpacci": .calves
        default: nil
        }
    }
}

extension ClientMuscleRegion {
    var desktopRegionKey: String {
        switch self {
        case .upperBack: "upper_back"
        case .hamstrings: "posterior_chain"
        default: rawValue
        }
    }
}

struct ClientExerciseCatalogRecord: Decodable {
    let id: UUID
    let name: String
    let muscleGroup: String?
    let instructions: String?
    let videoURL: String?
    let sourceKey: String?
    let difficultyLevel: ClientTrainingExperience?
    let primaryMuscleGroupID: UUID?
    let muscleLinks: [MuscleLink]?

    struct MuscleLink: Decodable {
        let relevance: Double?
        let muscle: Muscle?
        struct Muscle: Decodable {
            let id: UUID
            let name: String
            let sourceKey: String?
            enum CodingKeys: String, CodingKey { case id, name; case sourceKey = "source_key" }
        }
        enum CodingKeys: String, CodingKey { case relevance; case muscle = "muscle_group" }
    }

    var catalogItem: ClientExerciseCatalogItem {
        var seenMuscles: Set<UUID> = []
        let contributions = muscleLinks?.compactMap { link -> ClientCatalogMuscleContribution? in
            guard let muscle = link.muscle, seenMuscles.insert(muscle.id).inserted else { return nil }
            // Keep the raw stored analytic coefficient. It is NOT activation percent.
            let weight = link.relevance.flatMap { $0.isFinite && $0 >= 0 && $0 <= 1 ? $0 : nil }
            return ClientCatalogMuscleContribution(id: muscle.id, name: muscle.name, sourceKey: muscle.sourceKey,
                                                  relevance: weight, isPrimary: muscle.id == primaryMuscleGroupID,
                                                  roleIsKnown: primaryMuscleGroupID != nil)
        }
        let primary = Array(Set((contributions ?? []).filter { $0.hasKnownRole && $0.isPrimary }.compactMap(\.region))).sorted { $0.rawValue < $1.rawValue }
        let secondary = Array(Set((contributions ?? []).filter { $0.hasKnownRole && !$0.isPrimary }.compactMap(\.region))).sorted { $0.rawValue < $1.rawValue }
        return ClientExerciseCatalogItem(id: id, name: name, muscleGroup: muscleGroup,
            videoURL: videoURL.flatMap { URL(string: $0)?.scheme == "https" ? URL(string: $0) : nil },
            instructions: instructions, sourceKey: sourceKey, primaryMuscles: primary, secondaryMuscles: secondary,
            difficultyLevel: difficultyLevel, catalogMuscles: contributions)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, instructions
        case muscleGroup = "muscle_group", videoURL = "video_url", sourceKey = "source_key"
        case difficultyLevel = "difficulty_level", primaryMuscleGroupID = "primary_muscle_group_id", muscleLinks = "muscle_links"
    }
}
