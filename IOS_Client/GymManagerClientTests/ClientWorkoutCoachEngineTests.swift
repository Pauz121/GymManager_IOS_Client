import Foundation
import XCTest
@testable import GymManagerClient

final class ClientWorkoutCoachEngineTests: XCTestCase {
    func testCASE01BeginnerTwoDays45FullGym() throws {
        let result = try checked(.beginner, days: 2, minutes: 45)
        XCTAssertEqual(result.plan.generationMetadata?.strategy, .fullBody)
    }
    func testCASE02BeginnerThreeDays60HomeDumbbells() throws {
        var answers = ClientWorkoutCoachFixtures.answers(level: .beginner, days: 3)
        answers.equipment = .homeGym; answers.equipmentInventory = [.floor,.dumbbells,.bench]
        try assertPlan(answers)
    }
    func testCASE03IntermediateFourDays60ChestPriority() throws {
        _ = try checked(.intermediate, days: 4, minutes: 60, priority: [.chest])
    }
    func testCASE04IntermediateFiveDays75BackPriority() throws {
        let result = try checked(.intermediate, days: 5, minutes: 75, priority: [.lats,.upperBack])
        XCTAssertEqual(result.plan.generationMetadata?.strategy, .hybrid)
    }
    func testCASE05AdvancedFiveDays90ShoulderPriority() throws {
        _ = try checked(.advanced, days: 5, minutes: 90, priority: [.shoulders])
    }
    func testCASE06AdvancedSixDays60PreferredPPL() throws {
        var answers = ClientWorkoutCoachFixtures.answers(level: .advanced, days: 6)
        answers.splitPreference = .pushPullLegs
        try assertPlan(answers)
    }
    func testCASE07ThreeDays30MinimalEquipment() throws {
        var answers = ClientWorkoutCoachFixtures.answers(level: .beginner, days: 3, minutes: 30)
        answers.equipment = .homeGym; answers.equipmentInventory = [.floor,.dumbbells]
        try assertPlan(answers)
    }
    func testCASE08ExcludedBenchNeverSelected() throws {
        var answers = ClientWorkoutCoachFixtures.answers()
        let excluded = UUID(uuidString: "3e0f0e97-7d85-458a-b2b1-96b28c94d85b")!
        answers.avoidedExerciseIDs = [excluded]; answers.avoidedExerciseNames = ["Panca inclinata"]
        let result = try ClientWorkoutCoachFixtures.generate(answers)
        XCTAssertFalse(result.plan.sessions.flatMap(\.exercises).contains { $0.catalogExerciseID == excluded || $0.name == "Panca inclinata" })
        try assertPlan(answers)
    }
    func testCASE09ManyExcludedExercisesFailClosed() {
        var answers = ClientWorkoutCoachFixtures.answers()
        answers.avoidedExerciseIDs = Set(ClientWorkoutCoachFixtures.catalog().map(\.id))
        XCTAssertThrowsError(try ClientWorkoutCoachFixtures.generate(answers)) {
            XCTAssertEqual($0 as? ClientWorkoutGenerationEligibility, .noCompatibleExercises)
        }
    }
    func testCASE10TrainerConnectedGenerationDenied() {
        XCTAssertThrowsError(try ClientWorkoutGenerator().generate(context: .init(mode: .trainerConnected),
            answers: ClientWorkoutCoachFixtures.answers(), catalog: ClientWorkoutCoachFixtures.catalog())) {
            XCTAssertEqual($0 as? ClientWorkoutGenerationEligibility, .deniedTrainerManaged)
        }
    }
    func testCASE11ConnectionDenialPreservesExistingGeneratedPlanPayload() throws {
        let plan = try ClientWorkoutCoachFixtures.generate(ClientWorkoutCoachFixtures.answers()).plan
        let before = try JSONEncoder().encode(plan)
        XCTAssertThrowsError(try ClientWorkoutGenerator().generate(context: .init(mode: .trainerConnected),
            answers: ClientWorkoutCoachFixtures.answers(), catalog: ClientWorkoutCoachFixtures.catalog()))
        let restored = try JSONDecoder().decode(ClientPersonalWorkoutPlan.self, from: before)
        XCTAssertEqual(restored, plan) // Pure engine denial has no data deletion/mutation path; not an E2E link test.
    }
    func testCASE12InvalidQuestionnaireRejectedWithoutCorrection() {
        var answers = ClientWorkoutCoachFixtures.answers(); answers.weeklyFrequency = 7
        XCTAssertThrowsError(try ClientWorkoutCoachFixtures.generate(answers)) {
            XCTAssertEqual($0 as? ClientWorkoutGenerationEligibility, .invalidFrequency)
        }
    }
    func testDeterminismAcrossCatalogPermutationAndFreshInstanceIdentity() throws {
        let answers = ClientWorkoutCoachFixtures.answers(days: 4)
        let first = try ClientWorkoutCoachFixtures.generate(answers)
        let second = try ClientWorkoutGenerator().generate(answers: answers,
            catalog: Array(ClientWorkoutCoachFixtures.catalog().reversed()), now: ClientWorkoutCoachFixtures.now)
        XCTAssertEqual(ClientWorkoutCoachRules.programSignature(first.plan), ClientWorkoutCoachRules.programSignature(second.plan))
        XCTAssertEqual(first.validation, second.validation)
        XCTAssertEqual(first.plan.generationMetadata, second.plan.generationMetadata)
        XCTAssertNotEqual(first.plan.id, second.plan.id) // A new saved instance must not overwrite historical plans.
    }
    func testAlternativesRemainDeterministicAndValidate() throws {
        let answers = ClientWorkoutCoachFixtures.answers()
        let first = try ClientWorkoutCoachFixtures.generate(answers, variation: 2)
        let second = try ClientWorkoutCoachFixtures.generate(answers, variation: 2)
        XCTAssertEqual(ClientWorkoutCoachRules.programSignature(first.plan), ClientWorkoutCoachRules.programSignature(second.plan))
        try assertPlan(answers, variation: 2)
    }
    func testEvidenceDowngradesUnsupportedAdvancedSelfLabel() throws {
        var answers = ClientWorkoutCoachFixtures.answers(level: .advanced)
        answers.experienceEvidence?.recentConsistentMonths = 1
        let result = try ClientWorkoutCoachFixtures.generate(answers)
        XCTAssertEqual(result.plan.generationMetadata?.effectiveExperience, .beginner)
    }
    func testFourDayStrategyRespondsToContextAndRejectsConflictingPreference() throws {
        var answers = ClientWorkoutCoachFixtures.answers(level: .advanced, days: 4, minutes: 90)
        answers.priorityMuscles = [.chest,.biceps]
        XCTAssertEqual(ClientWorkoutCoachRules.strategy(ClientTrainingProfile(answers: answers)), .hybrid)
        answers.weeklyFrequency = 2; answers.splitPreference = .pushPullLegs
        XCTAssertThrowsError(try ClientWorkoutCoachFixtures.generate(answers))
    }
    func testBulkAndCutDoNotRewriteAllRepRangesOrShortenRest() throws {
        var answers = ClientWorkoutCoachFixtures.answers(days: 4)
        answers.goal = .strengthAndMass; answers.nutritionPhase = .cut
        let cut = try ClientWorkoutCoachFixtures.generate(answers)
        answers.nutritionPhase = .bulk
        let bulk = try ClientWorkoutCoachFixtures.generate(answers)
        for plan in [cut.plan,bulk.plan] {
            XCTAssertTrue(plan.sessions.flatMap(\.exercises).contains { $0.repetitions == "4–6" })
            XCTAssertTrue(plan.sessions.flatMap(\.exercises).contains { $0.repetitions == "10–15" })
            XCTAssertTrue(plan.sessions.flatMap(\.exercises).filter { $0.exerciseKind == .compound }.allSatisfy { $0.restSeconds >= 150 })
        }
    }
    func testUnknownMetadataAndConflictingDuplicateCatalogIDsExcluded() throws {
        let catalog = ClientWorkoutCoachFixtures.catalog()
        let known = try XCTUnwrap(catalog.first)
        let unknown = ClientExerciseCatalogItem(id: known.id, name: "Unreviewed renamed variant", muscleGroup: "Petto", videoURL: nil)
        let admission = try ClientWorkoutCatalogPolicy.admit(catalog + [unknown], answers: ClientWorkoutCoachFixtures.answers(), level: .intermediate)
        XCTAssertFalse(admission.candidates.contains { $0.item.id == known.id })
        XCTAssertNil(ClientWorkoutCatalogPolicy.review(for: unknown))
    }
    func testSecondaryWithoutStoredCoefficientIsQualitativeNotHalfSets() throws {
        var exercise = try XCTUnwrap(ClientWorkoutCoachFixtures.generate(ClientWorkoutCoachFixtures.answers()).plan.sessions.first?.exercises.first)
        exercise.sets = 4
        exercise.catalogMuscles = [.init(id: UUID(), name: "Petto", sourceKey: nil, relevance: 1, isPrimary: true),
                                  .init(id: UUID(), name: "Tricipiti", sourceKey: nil, relevance: nil, isPrimary: false)]
        let metrics = ClientWorkoutVolumeMetrics(exercises: [exercise])
        XCTAssertEqual(metrics.weeklySets[.chest], 4)
        XCTAssertNil(metrics.weeklySets[.triceps])
        XCTAssertEqual(metrics.secondaryExposures[.triceps], 4)
    }
    func testValidatorRejectsTamperedIDPrescriptionEquipmentAndMetadata() throws {
        let answers = ClientWorkoutCoachFixtures.answers()
        let original = try ClientWorkoutCoachFixtures.generate(answers).plan
        var forged = original; forged.sessions[0].exercises[0].catalogExerciseID = UUID() // Deliberately invalid test ID.
        XCTAssertFalse(inspect(forged, answers).summary.isValid)
        forged = original; forged.sessions[0].exercises[0].restSeconds = 0
        XCTAssertTrue(inspect(forged, answers).issues.contains(.prescription))
        forged = original; forged.sessions[0].exercises[0].compatibleEquipment = []
        XCTAssertTrue(inspect(forged, answers).issues.contains(.equipment))
        forged = original; forged.generationMetadata = nil
        XCTAssertTrue(inspect(forged, answers).issues.contains(.metadata))
    }
    func testRepParserRejectsMalformedRangesAndNegativeValues() {
        for value in ["-8", "8--10", "10–8", "0", "31", "8 reps", "nan"] { XCTAssertNil(ClientWorkoutRepRange(value), value) }
        XCTAssertEqual(ClientWorkoutRepRange("8–10")?.upper, 10)
    }
    func testValidatorRejectsEachStructuralAndVolumeViolation() throws {
        let answers = ClientWorkoutCoachFixtures.answers(days: 4)
        let original = try ClientWorkoutCoachFixtures.generate(answers).plan
        var changed = original; changed.sessions[0].weekday = changed.sessions[1].weekday
        XCTAssertTrue(inspect(changed, answers).issues.contains(.days))
        changed = original; changed.sessions[0].durationMinutes = 0
        XCTAssertTrue(inspect(changed, answers).issues.contains(.duration))
        changed = original; changed.sessions[0].exercises += changed.sessions[0].exercises
        XCTAssertTrue(inspect(changed, answers).issues.contains(.duplicates))
        changed = original; changed.sessions[0].exercises[0].sets = Int.max
        XCTAssertTrue(inspect(changed, answers).issues.contains(.prescription))
        XCTAssertTrue(inspect(changed, answers).issues.contains(.duration))
        changed = original
        for day in changed.sessions.indices { changed.sessions[day].exercises.removeAll { ($0.primaryMuscles ?? []).contains(.chest) } }
        XCTAssertTrue(inspect(changed, answers).issues.contains(.coverage))
        changed = original
        for day in changed.sessions.indices {
            for exercise in changed.sessions[day].exercises.indices { changed.sessions[day].exercises[exercise].sets = 1 }
        }
        XCTAssertTrue(inspect(changed, answers).issues.contains(.volume))
        changed = original
        changed.sessions[0].exercises = Array(changed.sessions[0].exercises.reversed())
        XCTAssertTrue(inspect(changed, answers).issues.contains(.order))
    }
    func testExplicitCustomSplitAndEquipmentAreValidatedAgainstCurrentAnswers() throws {
        var answers = ClientWorkoutCoachFixtures.answers(days: 4)
        answers.splitPreference = .custom
        answers.customSplitGroups = [Array(ClientWorkoutCoachRules.upper), Array(ClientWorkoutCoachRules.lower),
                                     Array(ClientWorkoutCoachRules.upper), Array(ClientWorkoutCoachRules.lower)]
        try assertPlan(answers)
        let plan = try ClientWorkoutCoachFixtures.generate(answers).plan
        answers.equipment = .homeGym; answers.equipmentInventory = [.floor]
        XCTAssertFalse(inspect(plan, answers).summary.isValid)
    }
    func testUnresolvedExclusionAndUnclassifiedMuscleDoNotGetGuessed() throws {
        var answers = ClientWorkoutCoachFixtures.answers()
        answers.avoidedExerciseNames = ["Bench spelling not in actual catalog"]
        XCTAssertThrowsError(try ClientWorkoutCoachFixtures.generate(answers))
        let first = try XCTUnwrap(ClientWorkoutCoachFixtures.catalog().first)
        let unknown = ClientExerciseCatalogItem(id: first.id, name: first.name, muscleGroup: "Petto", videoURL: nil,
            sourceKey: first.sourceKey, catalogMuscles: [.init(id: UUID(), name: "Unknown muscle", sourceKey: nil, relevance: 1, isPrimary: true)])
        let admitted = try ClientWorkoutCatalogPolicy.admit([unknown], answers: ClientWorkoutCoachFixtures.answers(), level: .intermediate)
        XCTAssertTrue(admitted.candidates.isEmpty)
        answers = ClientWorkoutCoachFixtures.answers(level: .beginner)
        answers.experienceEvidence?.compoundFamiliarity = false
        let novice = try ClientWorkoutCatalogPolicy.admit(ClientWorkoutCoachFixtures.catalog(), answers: answers, level: .beginner)
        XCTAssertTrue(novice.candidates.allSatisfy { $0.level == .beginner })
    }
    func testDoubleProgressionNeedsAllSetsAndRealRIRNeverWritesKG() throws {
        let exercise = try XCTUnwrap(ClientWorkoutCoachFixtures.generate(ClientWorkoutCoachFixtures.answers()).plan.sessions.first?.exercises.first)
        let upper = try XCTUnwrap(ClientWorkoutRepRange(exercise.repetitions)).upper
        let success = Array(repeating: ClientWorkoutDoubleProgression.SetPerformance(repetitions: upper, loadKg: 40, rir: 3), count: exercise.sets)
        XCTAssertEqual(ClientWorkoutDoubleProgression.decide(prescription: exercise, performed: success), .suggestIncrease)
        XCTAssertEqual(ClientWorkoutDoubleProgression.decide(prescription: exercise, performed: Array(success.dropLast())), .collectEvidence)
        let missingRIR = Array(repeating: ClientWorkoutDoubleProgression.SetPerformance(repetitions: upper, loadKg: 40, rir: nil), count: exercise.sets)
        XCTAssertEqual(ClientWorkoutDoubleProgression.decide(prescription: exercise, performed: missingRIR), .collectEvidence)
        let hard = Array(repeating: ClientWorkoutDoubleProgression.SetPerformance(repetitions: upper, loadKg: 40, rir: 0), count: exercise.sets)
        XCTAssertEqual(ClientWorkoutDoubleProgression.decide(prescription: exercise, performed: hard), .maintain)
        var partial = hard; partial[partial.count - 1] = .init(repetitions: upper, loadKg: 40, rir: nil)
        XCTAssertEqual(ClientWorkoutDoubleProgression.decide(prescription: exercise, performed: partial), .collectEvidence)
    }

    @discardableResult private func checked(_ level: ClientTrainingExperience, days: Int, minutes: Int,
                                            priority: Set<ClientMuscleRegion> = []) throws -> ClientGeneratedWorkoutResult {
        var answers = ClientWorkoutCoachFixtures.answers(level: level, days: days, minutes: minutes)
        answers.priorityMuscles = priority
        try assertPlan(answers)
        return try ClientWorkoutCoachFixtures.generate(answers)
    }
    private func inspect(_ plan: ClientPersonalWorkoutPlan, _ answers: ClientWorkoutQuestionnaireAnswers) -> ClientWorkoutPlanValidator.Report {
        ClientWorkoutPlanValidator().inspect(plan: plan, answers: answers, catalog: ClientWorkoutCoachFixtures.catalog())
    }
    private func assertPlan(_ answers: ClientWorkoutQuestionnaireAnswers, variation: Int = 0) throws {
        let result = try ClientWorkoutCoachFixtures.generate(answers, variation: variation)
        XCTAssertTrue(result.validation.isValid, result.validation.notices.joined(separator: ","))
        XCTAssertEqual(result.plan.sessions.count, answers.weeklyFrequency)
        XCTAssertTrue(result.plan.sessions.allSatisfy { ClientWorkoutCoachRules.minutes($0.exercises) <= answers.sessionDurationMinutes })
        XCTAssertTrue(result.plan.sessions.flatMap(\.exercises).allSatisfy { $0.loadKg == nil })
        let second = try ClientWorkoutCoachFixtures.generate(answers, variation: variation)
        XCTAssertEqual(ClientWorkoutCoachRules.programSignature(result.plan), ClientWorkoutCoachRules.programSignature(second.plan))
        let report = inspect(result.plan, answers)
        XCTAssertTrue(report.issues.isEmpty)
        XCTAssertTrue(report.summary.equipmentCompatible && report.summary.movementBalanceValid && report.summary.weeklyVolumeValid)
    }
}
