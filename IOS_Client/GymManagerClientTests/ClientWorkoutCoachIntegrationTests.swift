import Foundation
import XCTest
@testable import GymManagerClient

final class ClientWorkoutCoachIntegrationTests: XCTestCase {
    func testUnansweredDraftCannotUseQuestionnaireDefaultsAsEvidence() {
        let draft = ClientWorkoutCoachDraft()
        XCTAssertNil(draft.evidence); XCTAssertNil(draft.perceivedLevel)
        XCTAssertNil(draft.compoundFamiliarity); XCTAssertNil(draft.canUseRIR)
        XCTAssertNil(draft.hasUsedProgression); XCTAssertNil(draft.acknowledgement)
        XCTAssertThrowsError(try draft.completeAnswers(catalog: catalog)) {
            XCTAssertEqual(($0 as? ClientWorkoutCoachFeedback)?.step, .experience)
        }
    }
    func testCompleteDraftCarriesEveryExplicitRequiredAnswerToEngine() throws {
        let draft = validDraft()
        let answers = try draft.completeAnswers(catalog: catalog)
        XCTAssertEqual(answers.experienceEvidence?.totalMonths, 60)
        XCTAssertEqual(answers.experienceEvidence?.recentConsistentMonths, 18)
        XCTAssertEqual(answers.experienceEvidence?.recentSessionsPerWeek, 4)
        XCTAssertEqual(answers.experienceEvidence?.canUseRIR, true)
        XCTAssertEqual(answers.healthyAdultAcknowledged, true)
        let plan = try ClientWorkoutGenerator().generate(answers: answers, catalog: catalog).plan
        XCTAssertEqual(plan.generationAnswers, answers)
        XCTAssertNotNil(plan.generationMetadata)
    }
    func testExplicitNoStaysNoAndDowngradesPerceivedLevel() throws {
        var draft = validDraft(); draft.perceivedLevel = .advanced
        draft.canUseRIR = false; draft.hasUsedProgression = false
        let answers = try draft.completeAnswers(catalog: catalog)
        XCTAssertEqual(answers.experienceEvidence?.canUseRIR, false)
        XCTAssertEqual(draft.effectiveLevel, .intermediate)
    }
    func testContradictoryMonthsAndMissingSkillAreCorrectableWithoutErasingDraft() {
        var draft = validDraft(); draft.recentMonths = "99"
        XCTAssertEqual(draft.issue(at: .experience, catalog: catalog)?.step, .experience)
        XCTAssertEqual(draft.totalMonths, "60")
        draft.recentMonths = "18"; draft.compoundFamiliarity = nil
        XCTAssertNotNil(draft.issue(at: .skills, catalog: catalog))
    }
    func testInvalidAvailabilityAndNoAcknowledgementRejectBeforeGeneration() {
        var draft = validDraft(); draft.frequency = -1
        XCTAssertThrowsError(try draft.completeAnswers(catalog: catalog))
        draft.frequency = 3; draft.minutes = 31
        XCTAssertEqual(draft.issue(at: .availability, catalog: catalog)?.step, .availability)
        draft.minutes = 60; draft.acknowledgement = false
        XCTAssertThrowsError(try draft.completeAnswers(catalog: catalog))
    }
    func testEquipmentOptionsComeFromVerifiedCoverageNotCategoryNames() {
        let draft = validDraft()
        XCTAssertTrue(draft.availableEquipment(in: []).isEmpty)
        XCTAssertTrue(draft.availableEquipment(in: catalog).contains(.fullGym))
        XCTAssertFalse(draft.availableEquipment(in: catalog).contains(.bodyweight))
    }
    func testHomeRequiresActualCompatibleInventory() throws {
        var draft = validDraft(); draft.equipment = .homeGym; draft.inventory = []
        XCTAssertNotNil(draft.issue(at: .equipment, catalog: catalog))
        draft.inventory = [.floor,.dumbbells,.bench]
        let answers = try draft.completeAnswers(catalog: catalog)
        XCTAssertEqual(answers.equipmentInventory, draft.inventory)
    }
    func testExclusionsPersistRealCatalogIDsNotFreeText() throws {
        var draft = validDraft()
        let id = try XCTUnwrap(catalog.first?.id); draft.excludedIDs = [id]
        let answers = try draft.completeAnswers(catalog: catalog)
        XCTAssertEqual(answers.avoidedExerciseIDs, [id])
        XCTAssertTrue(answers.avoidedExerciseNames.isEmpty)
    }
    func testIncompatibleSplitOffersCorrectionInsteadOfSilentlyChangingIt() {
        var draft = validDraft(); draft.frequency = 2; draft.split = .pushPullLegs
        XCTAssertEqual(draft.issue(at: .split, catalog: catalog)?.step, .split)
        XCTAssertEqual(draft.split, .pushPullLegs)
        XCTAssertFalse(draft.isSplitAvailable(.pushPullLegs))
        XCTAssertTrue(draft.isSplitAvailable(.automatic))
        XCTAssertEqual(ClientWorkoutCoachFeedback.generation(ClientWorkoutGenerationEligibility.incompatiblePreferredSplit).step, .split)
    }
    func testTypedFailuresMapToUsefulStepsAndOwnerDenialHasNoOverride() {
        XCTAssertEqual(ClientWorkoutCoachFeedback.generation(ClientWorkoutGenerationEligibility.invalidDuration).step, .availability)
        XCTAssertEqual(ClientWorkoutCoachFeedback.generation(ClientWorkoutGenerationEligibility.noCompatibleExercises).step, .equipment)
        XCTAssertNil(ClientWorkoutCoachFeedback.generation(ClientWorkoutGenerationEligibility.deniedTrainerManaged).step)
        XCTAssertEqual(ClientWorkoutCoachFeedback.generation(ClientWorkoutGeneratorError.emptyCatalog).step, .equipment)
        XCTAssertEqual(ClientWorkoutCoachFeedback.generation(ClientWorkoutGeneratorError.inconsistentPlan(["volume"])).step, .availability)
    }
    func testBackAndTemporaryFrequencyChangesPreserveAnswersAndCustomGroups() {
        var draft = validDraft(); draft.frequency = 4; draft.resizeCustomSplit()
        draft.customGroups[3] = [.chest]
        draft.frequency = 2; draft.resizeCustomSplit()
        draft.frequency = 4; draft.resizeCustomSplit()
        XCTAssertEqual(draft.customGroups[3], [.chest])
        XCTAssertEqual(draft.totalMonths, "60")
        XCTAssertEqual(draft.canUseRIR, true)
    }
    func testPreviewExplanationUsesHumanPlanDataNotInternalMetadata() throws {
        let plan = try generated()
        let copy = ClientWorkoutCoachExplanation.lines(for: plan).joined(separator: " ")
        XCTAssertTrue(copy.contains("allenamenti"))
        XCTAssertFalse(copy.contains(ClientWorkoutCoachRules.version))
        XCTAssertFalse(copy.contains(plan.generationMetadata!.catalogFingerprint))
    }
    func testEditedNamesAndSessionOrderAreAllowedButStrictGenerationCheckStaysStrict() throws {
        var plan = try generated()
        plan.sessions[0].name = "La mia sessione"
        plan.sessions.swapAt(0, 2)
        let edited = ClientEditedWorkoutPlanValidator().inspect(plan, catalog: catalog)
        XCTAssertTrue(edited.canSave, edited.messages.joined(separator: " "))
        XCTAssertEqual(edited.plan.sessions[2].name, "La mia sessione")
        let strict = ClientWorkoutPlanValidator().inspect(plan: plan, answers: plan.generationAnswers!, catalog: catalog)
        XCTAssertTrue(strict.issues.contains(.days))
    }
    func testEditedValidationRejectsDurationDuplicateAndExcludedExercise() throws {
        let original = try generated()
        var plan = original; plan.sessions[0].exercises += plan.sessions[0].exercises
        XCTAssertTrue(ClientEditedWorkoutPlanValidator().inspect(plan, catalog: catalog).issues.contains(.duplicates))
        plan = original
        for index in plan.sessions[0].exercises.indices {
            plan.sessions[0].exercises[index].sets = 5
            plan.sessions[0].exercises[index].restSeconds = 300
        }
        XCTAssertTrue(ClientEditedWorkoutPlanValidator().inspect(plan, catalog: catalog).issues.contains(.duration))
        plan = original
        plan.generationAnswers?.avoidedExerciseIDs = [plan.sessions[0].exercises[0].catalogExerciseID!]
        let excluded = ClientEditedWorkoutPlanValidator().inspect(plan, catalog: catalog)
        XCTAssertFalse(excluded.canSave)
        XCTAssertTrue(excluded.issues.contains(.exclusions))
    }
    func testReplacementKeepsActualRolesEquipmentAndDifficultyEnvelope() throws {
        let answers = ClientWorkoutCoachFixtures.answers()
        let context = ClientWorkoutCoachEditingContext(answers: answers, catalog: catalog)
        let benchID = UUID(uuidString: "3e0f0e97-7d85-458a-b2b1-96b28c94d85b")!
        let bench = ClientWorkoutCoachEditingContext.exercise(try XCTUnwrap(context.candidates.first { $0.item.id == benchID }))
        let alternatives = context.alternatives(to: bench, usedIDs: [benchID])
        XCTAssertFalse(alternatives.isEmpty)
        XCTAssertTrue(alternatives.allSatisfy { $0.review.pattern == bench.movementPattern && $0.primary == Set(bench.primaryMuscles ?? []) })
        XCTAssertFalse(alternatives.contains { $0.item.id == benchID })
        let replacement = ClientWorkoutCoachEditingContext.exercise(try XCTUnwrap(alternatives.first), replacing: bench)
        XCTAssertEqual(replacement.sets, bench.sets)
        XCTAssertNil(replacement.loadKg)
        XCTAssertNotEqual(replacement.id, bench.id)
    }
    func testMetadataSurvivesEditedValidationAndPayloadRoundTrip() throws {
        let original = try generated()
        let result = ClientEditedWorkoutPlanValidator().inspect(original, catalog: catalog)
        XCTAssertTrue(result.canSave)
        XCTAssertEqual(result.plan.generationMetadata?.generatorVersion, original.generationMetadata?.generatorVersion)
        XCTAssertEqual(result.plan.generationMetadata?.catalogFingerprint, original.generationMetadata?.catalogFingerprint)
        let readback = try JSONDecoder().decode(ClientPersonalWorkoutPlan.self, from: JSONEncoder().encode(result.plan))
        XCTAssertEqual(readback, result.plan) // JSON only, NOT server persistence.
    }
    func testOldPlanWithoutCoachMetadataStillDecodes() throws {
        let plan = ClientPersonalWorkoutPlan(id: UUID(), title: "Storico", status: .archived,
            sessions: [], createdAt: ClientWorkoutCoachFixtures.now, updatedAt: ClientWorkoutCoachFixtures.now)
        let restored = try JSONDecoder().decode(ClientPersonalWorkoutPlan.self, from: JSONEncoder().encode(plan))
        XCTAssertEqual(restored, plan)
        XCTAssertNil(restored.generationMetadata)
    }
    func testSaveStatesDoNotCallLocalRetentionServerConfirmed() {
        XCTAssertNotEqual(ClientWorkoutCoachSaveState.localDraft, .confirmed(demo: false))
        XCTAssertTrue(ClientWorkoutCoachSaveState.confirmed(demo: true).message.contains("solo"))
        XCTAssertTrue(ClientWorkoutCoachSaveState.failure("Non confermato").message.contains("Non confermato"))
        XCTAssertNotEqual(ClientWorkoutCoachSaveState.saving, .confirmed(demo: false))
    }
    func testCatalogRowsCannotIntroduceConflictingSwiftUIIdentities() throws {
        let first = try XCTUnwrap(catalog.first)
        let duplicate = ClientExerciseCatalogItem(id: first.id, name: "Conflicting variant", muscleGroup: nil, videoURL: nil)
        XCTAssertFalse(ClientWorkoutCoachDraft.visibleCatalogRows(catalog + [duplicate]).contains { $0.id == first.id })
        XCTAssertEqual(ClientWorkoutCoachDraft.visibleCatalogRows(catalog + [first]).count, catalog.count)
    }
    private var catalog: [ClientExerciseCatalogItem] { ClientWorkoutCoachFixtures.catalog() }
    private func validDraft() -> ClientWorkoutCoachDraft {
        var draft = ClientWorkoutCoachDraft()
        draft.totalMonths = "60"; draft.recentMonths = "18"; draft.recentFrequency = 4
        draft.perceivedLevel = .intermediate; draft.compoundFamiliarity = true
        draft.canUseRIR = true; draft.hasUsedProgression = true
        draft.frequency = 3; draft.minutes = 60; draft.equipment = .fullGym
        draft.goal = .hypertrophy; draft.phase = .maintenance; draft.weeks = 8
        draft.split = .automatic; draft.acknowledgement = true
        return draft
    }
    private func generated() throws -> ClientPersonalWorkoutPlan {
        try ClientWorkoutCoachFixtures.generate(ClientWorkoutCoachFixtures.answers()).plan
    }
}
