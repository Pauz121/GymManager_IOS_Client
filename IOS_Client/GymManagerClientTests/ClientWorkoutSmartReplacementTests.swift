import Foundation
import XCTest
@testable import GymManagerClient

final class ClientWorkoutSmartReplacementTests: XCTestCase {
    typealias F = ClientWorkoutCoachFixtures
    private let benchID = UUID(uuidString: "3e0f0e97-7d85-458a-b2b1-96b28c94d85b")!
    private let chestPressID = UUID(uuidString: "b881964d-c8cb-4ffb-8166-ca4fcd4da8ab")!
    private func context(_ answers: ClientWorkoutQuestionnaireAnswers = F.answers(),
                         catalog: [ClientExerciseCatalogItem] = F.catalog()) -> ClientWorkoutCoachEditingContext {
        .init(answers: answers, catalog: catalog)
    }
    private func bench(_ context: ClientWorkoutCoachEditingContext) throws -> ClientPersonalExercise {
        ClientWorkoutCoachEditingContext.exercise(try XCTUnwrap(context.candidates.first { $0.item.id == benchID }))
    }
    func testWREP01SameMusclePatternDifficultyDeterministicRanking() throws {
        let ctx = context(), original = try bench(ctx)
        let a = ctx.alternatives(to: original, usedIDs: [])
        let b = context(catalog: Array(F.catalog().reversed())).alternatives(to: original, usedIDs: [])
        XCTAssertFalse(a.isEmpty)
        XCTAssertEqual(a.map { $0.item.id }, b.map { $0.item.id })
        XCTAssertTrue(a.allSatisfy { $0.primary == Set(original.primaryMuscles ?? []) && $0.review.pattern == original.movementPattern })
        let ranks = ClientWorkoutReplacementRanking.ranked(candidates: ctx.candidates, original: original, usedIDs: [], priorities: [])
        if ranks.contains(where: { $0.score.difficultyDistance == 0 }) { XCTAssertEqual(ranks.first?.score.difficultyDistance, 0) }
    }
    func testWREP02BeginnerDoesNotReceiveAdvancedOrMoreTechnicalAlternative() throws {
        var catalog = F.catalog()
        let index = try XCTUnwrap(catalog.firstIndex { $0.id == benchID })
        let item = catalog[index]
        catalog[index] = .init(id: item.id, name: item.name, muscleGroup: item.muscleGroup, videoURL: nil,
            sourceKey: item.sourceKey, primaryMuscles: item.primaryMuscles, secondaryMuscles: item.secondaryMuscles,
            movementPattern: item.movementPattern, compatibleEquipment: item.compatibleEquipment, kind: item.kind,
            difficultyLevel: .advanced, catalogMuscles: item.catalogMuscles)
        let ctx = context(F.answers(level: .beginner), catalog: catalog)
        let original = ClientWorkoutCoachEditingContext.exercise(try XCTUnwrap(ctx.candidates.first { $0.item.id == chestPressID }))
        let alternatives = ctx.alternatives(to: original, usedIDs: [])
        XCTAssertFalse(alternatives.contains { $0.level == .advanced || $0.level == .intermediate })
    }
    func testWREP03EquipmentIncompatibleIsNotRecommended() throws {
        var answers = F.answers(); answers.equipment = .homeGym; answers.equipmentInventory = [.floor,.dumbbells,.bench]
        let ctx = context(answers)
        let original = ClientWorkoutCoachEditingContext.exercise(try XCTUnwrap(ctx.candidates.first { $0.review.pattern == .horizontalPush }))
        XCTAssertTrue(ctx.alternatives(to: original, usedIDs: []).allSatisfy {
            $0.review.required.isSubset(of: answers.equipmentInventory!)
        })
        XCTAssertFalse(ctx.alternatives(to: original, usedIDs: []).contains { $0.item.id == chestPressID })
    }
    func testWREP04ExcludedExerciseRejected() throws {
        var answers = F.answers(); answers.avoidedExerciseIDs = [chestPressID]
        let ctx = context(answers), original = try bench(ctx)
        XCTAssertFalse(ctx.alternatives(to: original, usedIDs: []).contains { $0.item.id == chestPressID })
    }
    func testWREP05DuplicateInSameSessionRejected() throws {
        let ctx = context(), original = try bench(ctx)
        XCTAssertFalse(ctx.alternatives(to: original, usedIDs: [chestPressID]).contains { $0.item.id == chestPressID })
    }
    func testWREP06ReplacementRevalidationUsesActualVolumeAndPreservesPrescription() throws {
        var catalog = F.catalog()
        let position = try XCTUnwrap(catalog.firstIndex { $0.id == chestPressID })
        let row = catalog[position]
        let links = row.catalogMuscles!.map { link in
            ClientCatalogMuscleContribution(id: link.id, name: link.name, sourceKey: link.sourceKey,
                relevance: link.isPrimary ? 1 : 0.25, isPrimary: link.isPrimary)
        }
        catalog[position] = .init(id: row.id, name: row.name, muscleGroup: row.muscleGroup, videoURL: nil,
            sourceKey: row.sourceKey, primaryMuscles: row.primaryMuscles, secondaryMuscles: row.secondaryMuscles,
            movementPattern: row.movementPattern, compatibleEquipment: row.compatibleEquipment, kind: row.kind,
            difficultyLevel: row.difficultyLevel, catalogMuscles: links)
        let answers = F.answers(minutes: 75)
        var plan = try ClientWorkoutGenerator().generate(answers: answers, catalog: catalog, now: F.now).plan
        let day = try XCTUnwrap(plan.sessions.indices.first { plan.sessions[$0].exercises.contains { $0.movementPattern == .horizontalPush && $0.exerciseKind == .compound } })
        let slot = try XCTUnwrap(plan.sessions[day].exercises.firstIndex { $0.movementPattern == .horizontalPush && $0.exerciseKind == .compound })
        let original = plan.sessions[day].exercises[slot]
        let ctx = context(answers, catalog: catalog)
        plan.sessions[day].exercises[slot] = ClientWorkoutCoachEditingContext.exercise(try XCTUnwrap(ctx.candidates.first { $0.item.id == benchID }), replacing: original)
        let checked = ClientEditedWorkoutPlanValidator().inspect(plan, catalog: catalog)
        XCTAssertTrue(checked.canSave, checked.messages.joined(separator: " "))
        let proposals = try ClientWorkoutSmartReplacement.alternatives(plan: checked.plan, sessionID: plan.sessions[day].id,
            exerciseID: plan.sessions[day].exercises[slot].id, catalog: catalog, context: .init(mode: .standalone))
        let swap = try XCTUnwrap(proposals.first { $0.replacementCatalogID == chestPressID })
        XCTAssertNotEqual(swap.beforeVolume.weeklySets, swap.afterVolume.weeklySets)
        let after = swap.plan.sessions[day].exercises[slot]
        XCTAssertEqual(after.sets, original.sets)
        XCTAssertEqual(after.repetitions, original.repetitions)
        XCTAssertEqual(after.restSeconds, original.restSeconds)
        XCTAssertEqual(after.effortTarget, original.effortTarget)
        XCTAssertTrue(swap.plan.editProvenance?.hasUserEdits == true)
        XCTAssertEqual(swap.plan.generationMetadata?.catalogFingerprint, plan.generationMetadata?.catalogFingerprint)
        var stale = checked.plan; stale.title = "Scheda modificata dopo anteprima"
        XCTAssertThrowsError(try ClientWorkoutSmartReplacement.apply(swap, to: stale, catalog: catalog, context: .init(mode: .standalone))) {
            XCTAssertEqual($0 as? ClientSmartPlanEditError, .stalePreview)
        }
    }
    func testTrainerConnectedProposalDenied() throws {
        let plan = try F.generate(F.answers()).plan
        let day = try XCTUnwrap(plan.sessions.first), exercise = try XCTUnwrap(day.exercises.first)
        XCTAssertThrowsError(try ClientWorkoutSmartReplacement.alternatives(plan: plan, sessionID: day.id,
            exerciseID: exercise.id, catalog: F.catalog(), context: .init(mode: .trainerConnected))) {
            XCTAssertEqual($0 as? ClientWorkoutGenerationEligibility, .deniedTrainerManaged)
        }
    }
}
