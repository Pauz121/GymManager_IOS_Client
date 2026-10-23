import Foundation
import XCTest
@testable import GymManagerClient

final class ClientWorkoutCoachEligibilityTests: XCTestCase {
    func testTrainerManagedDenialPrecedesQuestionnaireErrors() {
        XCTAssertEqual(ClientWorkoutGenerationPolicy.evaluate(context: .init(mode: .trainerConnected), answers: .init()), .deniedTrainerManaged)
        XCTAssertEqual(ClientWorkoutGenerationPolicy.evaluate(context: .init(mode: nil), answers: .init()), .deniedUnauthenticated)
    }
    func testMissingAnswersAreTypedNotSilentlyDefaulted() {
        guard case .missingRequiredAnswers(let fields) = ClientWorkoutGenerationPolicy.validateAnswers(.init()) else { return XCTFail("Missing contract") }
        XCTAssertTrue(fields.contains(.experienceEvidence))
        XCTAssertTrue(fields.contains(.healthyAdultAcknowledgement))
    }
    func testInvalidValuesAreRejectedNotClamped() {
        var answers = validAnswers()
        answers.weeklyFrequency = 0
        XCTAssertEqual(ClientWorkoutGenerationPolicy.validateAnswers(answers), .invalidFrequency)
        answers.weeklyFrequency = 3; answers.sessionDurationMinutes = 31
        XCTAssertEqual(ClientWorkoutGenerationPolicy.validateAnswers(answers), .invalidDuration)
        answers.sessionDurationMinutes = 45; answers.durationWeeks = 3
        XCTAssertEqual(ClientWorkoutGenerationPolicy.validateAnswers(answers), .invalidProgramLength)
    }
    func testExperienceNeedsContinuityAndSkillsNotPerceivedLabelAlone() {
        var evidence = ClientWorkoutExperienceEvidence(totalMonths: 60, recentConsistentMonths: 1,
            recentSessionsPerWeek: 1, compoundFamiliarity: false, canUseRIR: false, hasUsedLoadProgression: false)
        XCTAssertEqual(evidence.classified(cappedAt: .advanced), .beginner)
        evidence.recentConsistentMonths = 18; evidence.recentSessionsPerWeek = 4
        evidence.compoundFamiliarity = true; evidence.canUseRIR = true; evidence.hasUsedLoadProgression = true
        XCTAssertEqual(evidence.classified(cappedAt: .advanced), .advanced)
        XCTAssertEqual(evidence.classified(cappedAt: .intermediate), .intermediate)
    }
    func testHomeNeedsActualInventoryAndConflictingSplitIsExplicit() {
        var answers = validAnswers(); answers.equipment = .homeGym
        guard case .missingRequiredAnswers = ClientWorkoutGenerationPolicy.validateAnswers(answers) else { return XCTFail("Inventory missing") }
        answers.equipmentInventory = [.floor, .dumbbells]
        XCTAssertEqual(ClientWorkoutGenerationPolicy.validateAnswers(answers), .allowed)
        answers.weeklyFrequency = 2; answers.splitPreference = .pushPullLegs
        XCTAssertEqual(ClientWorkoutGenerationPolicy.validateAnswers(answers), .incompatiblePreferredSplit)
    }
    func testHistoricalAnswersDecodeWithoutNewEvidenceOrConsent() throws {
        let data = try JSONEncoder().encode(ClientWorkoutQuestionnaireAnswers())
        let reopened = try JSONDecoder().decode(ClientWorkoutQuestionnaireAnswers.self, from: data)
        XCTAssertNil(reopened.experienceEvidence)
        XCTAssertNil(reopened.healthyAdultAcknowledged)
    }
    func testPersonalHistorySurvivesReloadMergeWhileConnectedWritesAreDenied() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let plan = ClientPersonalWorkoutPlan(id: UUID(), title: "Storico standalone", status: .archived,
            sessions: [], createdAt: now, updatedAt: now, source: .guided)
        let original = ClientPersonalContentState(workoutPlans: [plan], nutritionPlans: [], mealTemplates: [])
        // The same merge is used on identity reload; an empty remote read cannot erase a local historical plan.
        let reloaded = original.merging(.empty)
        XCTAssertEqual(reloaded.workoutPlans, [plan])
        XCTAssertEqual(reloaded.workoutPlans.first?.source, .guided)
        XCTAssertFalse(ClientAccessPolicy.canManagePersonalWorkoutPlans(in: .trainerConnected))
        XCTAssertTrue(ClientAccessPolicy.canManagePersonalWorkoutPlans(in: .standalone))
    }
    private func validAnswers() -> ClientWorkoutQuestionnaireAnswers {
        var answers = ClientWorkoutQuestionnaireAnswers()
        answers.experienceEvidence = .init(totalMonths: 0, recentConsistentMonths: 0, recentSessionsPerWeek: 0,
                                          compoundFamiliarity: false, canUseRIR: false, hasUsedLoadProgression: false)
        answers.healthyAdultAcknowledged = true
        return answers
    }
}
