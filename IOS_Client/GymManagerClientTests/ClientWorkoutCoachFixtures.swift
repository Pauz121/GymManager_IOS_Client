import Foundation
@testable import GymManagerClient

/// Synthetic test content, NEVER a production seed or a claim about current database rows.
/// Legacy identities are existing public IDs; imported-variant fixture UUIDs are deliberately synthetic.
/// Stored coefficients are test inputs, not activation percentages or default production weights.
enum ClientWorkoutCoachFixtures {
    static let now = Date(timeIntervalSince1970: 1_700_000_000)
    static func answers(level: ClientTrainingExperience = .intermediate, days: Int = 3, minutes: Int = 60) -> ClientWorkoutQuestionnaireAnswers {
        var result = ClientWorkoutQuestionnaireAnswers()
        result.experience = level; result.weeklyFrequency = days; result.sessionDurationMinutes = minutes
        result.experienceEvidence = .init(totalMonths: 60, recentConsistentMonths: 18, recentSessionsPerWeek: 4,
            compoundFamiliarity: true, canUseRIR: true, hasUsedLoadProgression: true)
        result.healthyAdultAcknowledged = true
        return result
    }
    static func catalog() -> [ClientExerciseCatalogItem] {
        ClientWorkoutCatalogPolicy.reviews.enumerated().map { index, rule in
            let id = rule.id.flatMap(UUID.init(uuidString:))
                ?? UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index + 1))!
            let primary: ClientMuscleRegion
            let secondary: [ClientMuscleRegion]
            switch rule.pattern {
            case .horizontalPush: primary = .chest; secondary = rule.kind == .compound ? [.shoulders,.triceps] : [.shoulders]
            case .horizontalPull: primary = .upperBack; secondary = [.lats,.biceps]
            case .verticalPull: primary = .lats; secondary = [.upperBack,.biceps]
            case .verticalPush: primary = .shoulders; secondary = rule.kind == .compound ? [.triceps] : []
            case .kneeDominant, .unilateralLower: primary = .quadriceps; secondary = [.glutes,.hamstrings]
            case .hipHinge: primary = .hamstrings; secondary = [.glutes,.upperBack]
            case .elbowFlexion: primary = .biceps; secondary = []
            case .elbowExtension: primary = .triceps; secondary = []
            case .calves: primary = .calves; secondary = []
            default: primary = .core; secondary = []
            }
            let roles = [primary] + secondary
            let links = roles.enumerated().map { offset, muscle in
                ClientCatalogMuscleContribution(id: UUID(uuidString: String(format: "10000000-0000-4000-8000-%012d", ClientMuscleRegion.allCases.firstIndex(of: muscle)! + 1))!,
                    name: muscle.displayName, sourceKey: nil, relevance: offset == 0 ? 1 : 0.5, isPrimary: offset == 0)
            }
            return ClientExerciseCatalogItem(id: id, name: rule.name, muscleGroup: nil, videoURL: nil,
                sourceKey: rule.sourceKey, primaryMuscles: [primary], secondaryMuscles: secondary,
                movementPattern: rule.pattern, compatibleEquipment: ClientWorkoutCatalogPolicy.coarseEquipment(for: rule.required),
                kind: rule.kind, difficultyLevel: rule.level, catalogMuscles: links)
        }
    }
    static func generate(_ answers: ClientWorkoutQuestionnaireAnswers, variation: Int = 0) throws -> ClientGeneratedWorkoutResult {
        try ClientWorkoutGenerator().generate(answers: answers, catalog: catalog(), variation: variation, now: now)
    }
}
