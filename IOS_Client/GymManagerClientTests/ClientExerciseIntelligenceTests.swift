import Foundation
import XCTest
@testable import GymManagerClient

final class ClientExerciseIntelligenceTests: XCTestCase {
    func testServerDifficultyOverridesLegacyBeginnerHint() {
        let exercise = item(level: .advanced, legacy: .beginner)
        XCTAssertFalse(ClientExerciseDifficultyPolicy.allows(exercise, for: .beginner))
        XCTAssertFalse(ClientExerciseDifficultyPolicy.allows(exercise, for: .intermediate))
        XCTAssertTrue(ClientExerciseDifficultyPolicy.allows(exercise, for: .advanced))
    }

    func testBeginnerRankingPrefersSimpleButAllowsIntermediate() {
        let simple = item(level: .beginner)
        let moderate = item(level: .intermediate)
        XCTAssertTrue(ClientExerciseDifficultyPolicy.allows(moderate, for: .beginner))
        XCTAssertGreaterThan(ClientExerciseDifficultyPolicy.preferenceScore(simple, for: .beginner),
                             ClientExerciseDifficultyPolicy.preferenceScore(moderate, for: .beginner))
    }

    func testAdvancedProfileKeepsSimpleMovementsAvailable() {
        for level in ClientTrainingExperience.allCases {
            XCTAssertTrue(ClientExerciseDifficultyPolicy.allows(item(level: level), for: .advanced))
        }
    }

    func testUnknownDifficultyDoesNotSilentlyBecomeBeginner() {
        let unknown = ClientExerciseMetadataNormalizer.enrich(item(level: nil))
        XCTAssertNil(unknown.effectiveDifficulty)
        XCTAssertFalse(ClientExerciseDifficultyPolicy.allows(unknown, for: .beginner))
    }

    func testDifficultyIsPreservedThroughEnrichmentAndPersonalPayload() throws {
        let normalized = ClientExerciseMetadataNormalizer.enrich(item(level: .intermediate))
        let personal = ClientManualWorkoutDraft.exercise(from: normalized)
        let reopened = try JSONDecoder().decode(ClientPersonalExercise.self, from: JSONEncoder().encode(personal))
        XCTAssertEqual(reopened.difficultyLevel, .intermediate)
        XCTAssertEqual(reopened.asClientExercise().difficultyLevel, .intermediate)
    }

    private func item(level: ClientTrainingExperience?, legacy: ClientTrainingExperience? = nil) -> ClientExerciseCatalogItem {
        ClientExerciseCatalogItem(id: UUID(), name: "Variante test senza inferenze", muscleGroup: nil, videoURL: nil,
                                  minimumExperience: legacy, difficultyLevel: level)
    }

    func testCatalogMappingMatchesDesktopAxesWithoutUnknownGuess() {
        XCTAssertEqual(ClientCatalogMuscleMapping.region(for: "Centro Schiena")?.desktopRegionKey, "upper_back")
        XCTAssertEqual(ClientCatalogMuscleMapping.region(for: "Femorali")?.desktopRegionKey, "posterior_chain")
        XCTAssertEqual(ClientCatalogMuscleMapping.region(for: "Addome")?.desktopRegionKey, "core")
        XCTAssertNil(ClientCatalogMuscleMapping.region(for: "Muscolo non mappato"))
    }

    func testStoredAssociationsOverrideNameBasedAnatomyGuesses() {
        let contribution = ClientCatalogMuscleContribution(id: UUID(), name: "Tricipiti", sourceKey: "tricipiti", relevance: 0.5, isPrimary: true)
        let catalog = ClientExerciseCatalogItem(id: UUID(), name: "Panca piana", muscleGroup: nil, videoURL: nil,
            primaryMuscles: [.triceps], catalogMuscles: [contribution])
        let enriched = ClientExerciseMetadataNormalizer.enrich(catalog)
        XCTAssertEqual(enriched.primaryMuscles, [.triceps])
        XCTAssertTrue(enriched.secondaryMuscles.isEmpty)
        XCTAssertEqual(enriched.catalogMuscles?.first?.relevance, 0.5) // Raw coefficient, not 50% activation.
    }

    func testMissingCatalogPrimaryRoleIsNotInvented() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","name":"Variante senza regola","muscle_group":"Petto",
         "muscle_links":[{"relevance":0.5,"muscle_group":{"id":"00000000-0000-0000-0000-000000000002","name":"Tricipiti"}}]}
        """
        let record = try JSONDecoder().decode(ClientExerciseCatalogRecord.self, from: Data(json.utf8))
        let enriched = ClientExerciseMetadataNormalizer.enrich(record.catalogItem)
        XCTAssertTrue(enriched.primaryMuscles.isEmpty)
        XCTAssertTrue(enriched.secondaryMuscles.isEmpty)
        XCTAssertEqual(enriched.catalogMuscles?.first?.roleIsKnown, false)
        let reopened = try JSONDecoder().decode(ClientCatalogMuscleContribution.self,
            from: JSONEncoder().encode(try XCTUnwrap(enriched.catalogMuscles?.first)))
        XCTAssertFalse(reopened.hasKnownRole)
    }

    func testInvalidCatalogCoefficientIsNotAnActivationEstimate() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","name":"Variante test",
         "primary_muscle_group_id":"00000000-0000-0000-0000-000000000002",
         "muscle_links":[{"relevance":4,"muscle_group":{"id":"00000000-0000-0000-0000-000000000002","name":"Tricipiti"}}]}
        """
        let record = try JSONDecoder().decode(ClientExerciseCatalogRecord.self, from: Data(json.utf8))
        XCTAssertNil(record.catalogItem.catalogMuscles?.first?.relevance)
        XCTAssertEqual(record.catalogItem.primaryMuscles, [.triceps])
    }

    func testWeeklyVolumeUsesStoredCoefficientRatherThanLegacyHalfSets() {
        let chest = ClientCatalogMuscleContribution(id: UUID(), name: "Pettorali", sourceKey: nil, relevance: 1, isPrimary: true)
        let triceps = ClientCatalogMuscleContribution(id: UUID(), name: "Tricipiti", sourceKey: nil, relevance: 0.25, isPrimary: false)
        let item = ClientExerciseCatalogItem(id: UUID(), name: "Panca piana", muscleGroup: nil, videoURL: nil,
            primaryMuscles: [.chest], secondaryMuscles: [.triceps], difficultyLevel: .intermediate, catalogMuscles: [chest, triceps])
        var exercise = ClientManualWorkoutDraft.exercise(from: item)
        exercise.sets = 4
        let now = Date()
        let plan = ClientPersonalWorkoutPlan(id: UUID(), title: "Test coefficienti", status: .draft,
            sessions: [ClientPersonalWorkoutSession(id: UUID(), name: "Giorno 1", weekday: 2, exercises: [exercise])],
            createdAt: now, updatedAt: now)
        let validation = ClientWorkoutGenerator().validate(plan: plan, profile: ClientTrainingProfile(answers: ClientWorkoutQuestionnaireAnswers()))
        XCTAssertEqual(validation.weeklySets[.chest], 4)
        XCTAssertEqual(validation.weeklySets[.triceps], 1)
    }

    func testSixSupportedDemonstrationsAndUnsupportedVariantFallback() {
        for name in ["Panca piana", "Squat", "Lat machine", "Shoulder press", "Curl manubri", "Push down al cavo"] {
            let catalog = ClientExerciseCatalogItem(id: UUID(), name: name, muscleGroup: nil, videoURL: nil)
            let exercise = ClientManualWorkoutDraft.exercise(from: catalog).asClientExercise()
            XCTAssertTrue(ClientExerciseVisualResolver().resolve(exercise).isAnimated, name)
        }
        let pushUp = ClientManualWorkoutDraft.exercise(from: ClientExerciseCatalogItem(id: UUID(), name: "Push-up", muscleGroup: nil, videoURL: nil)).asClientExercise()
        XCTAssertFalse(ClientExerciseVisualResolver().resolve(pushUp).isAnimated)
    }
}
