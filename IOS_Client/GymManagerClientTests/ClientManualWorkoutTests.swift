import Foundation
import XCTest
@testable import GymManagerClient

final class ClientManualWorkoutTests: XCTestCase {
    func testResizeKeepsExistingSessionAndExerciseIDs() {
        var plan = ClientManualWorkoutDraft.newPlan()
        plan.sessions[0].exercises = [ClientManualWorkoutDraft.exercise(from: item())]
        let original = plan.sessions[0]
        ClientManualWorkoutDraft.resize(&plan, count: 6)
        XCTAssertEqual(plan.sessions[0], original)
        XCTAssertEqual(plan.sessions.count, 6)
        ClientManualWorkoutDraft.resize(&plan, count: 2)
        XCTAssertEqual(plan.sessions[0], original)
    }

    func testDayCountIsBoundedAndManualSourcePreserved() {
        var plan = ClientManualWorkoutDraft.newPlan()
        ClientManualWorkoutDraft.resize(&plan, count: 99)
        XCTAssertEqual(plan.sessions.count, 6)
        ClientManualWorkoutDraft.resize(&plan, count: 0)
        XCTAssertEqual(plan.sessions.count, 2)
        XCTAssertEqual(plan.source, .manual)
    }

    func testSuggestedSplitDoesNotRemoveChosenExercises() {
        var plan = ClientManualWorkoutDraft.newPlan()
        plan.sessions[0].exercises = [ClientManualWorkoutDraft.exercise(from: item())]
        let exercise = plan.sessions[0].exercises[0]
        ClientManualWorkoutDraft.apply(.upperLower, to: &plan)
        XCTAssertEqual(plan.sessions[0].exercises, [exercise])
        XCTAssertTrue(plan.sessions[0].targetMuscles?.contains(.chest) == true)
        XCTAssertTrue(plan.sessions[1].targetMuscles?.contains(.quadriceps) == true)
    }

    func testPickerUsesSharedPrimaryAndSecondaryMetadata() {
        let exercise = item()
        XCTAssertTrue(ClientManualWorkoutDraft.catalogMatches(exercise, groups: [.chest]))
        XCTAssertTrue(ClientManualWorkoutDraft.catalogMatches(exercise, groups: [.triceps]))
        XCTAssertFalse(ClientManualWorkoutDraft.catalogMatches(exercise, groups: [.calves]))
        XCTAssertTrue(ClientManualWorkoutDraft.catalogMatches(exercise, groups: []))
    }

    func testCreationDoesNotInventLoadAndKeepsRealCatalogReference() {
        let catalog = item()
        let exercise = ClientManualWorkoutDraft.exercise(from: catalog)
        XCTAssertNil(exercise.loadKg)
        XCTAssertEqual(exercise.catalogExerciseID, catalog.id)
        XCTAssertEqual(exercise.primaryMuscles, [.chest])
        XCTAssertFalse(exercise.effortTarget.isEmpty)
        XCTAssertNotEqual(exercise.id, catalog.id)
    }

    func testValidationRequiresExercisesButNotWeight() {
        var plan = ClientManualWorkoutDraft.newPlan()
        XCTAssertNotNil(ClientManualWorkoutDraft.validationMessage(plan))
        for index in plan.sessions.indices {
            plan.sessions[index].exercises = [ClientManualWorkoutDraft.exercise(from: item())]
        }
        XCTAssertNil(ClientManualWorkoutDraft.validationMessage(plan))
        plan.sessions[0].exercises[0].repetitions = " "
        XCTAssertNotNil(ClientManualWorkoutDraft.validationMessage(plan))
    }

    func testPayloadRoundTripPreservesGroupsExerciseOrderAndIDs() throws {
        var plan = ClientManualWorkoutDraft.newPlan()
        plan.sessions[0].targetMuscles = [.chest, .triceps]
        plan.sessions[0].exercises = [ClientManualWorkoutDraft.exercise(from: item()), ClientManualWorkoutDraft.exercise(from: item())]
        plan.sessions[0].exercises.swapAt(0, 1)
        let decoded = try JSONDecoder().decode(ClientPersonalWorkoutPlan.self, from: JSONEncoder().encode(plan))
        XCTAssertEqual(decoded, plan)
    }

    func testOldSessionPayloadWithoutGroupsStillDecodes() throws {
        let session = ClientPersonalWorkoutSession(id: UUID(), name: "Giorno A", weekday: nil, exercises: [])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any])
        object.removeValue(forKey: "targetMuscles")
        let decoded = try JSONDecoder().decode(ClientPersonalWorkoutSession.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded, session)
        XCTAssertNil(decoded.targetMuscles)
    }

    private func item() -> ClientExerciseCatalogItem {
        ClientExerciseCatalogItem(
            id: UUID(), name: "Panca piana", muscleGroup: "Petto", videoURL: nil,
            primaryMuscles: [.chest], secondaryMuscles: [.triceps], movementPattern: .horizontalPush,
            compatibleEquipment: [.fullGym], kind: .compound
        )
    }

    func testPreviousLoadExcludesCurrentSessionAndUncompletedSets() {
        let exerciseID = UUID()
        let now = Date()
        var state = ClientActivityState.empty
        state.workouts = [
            execution(exerciseID: exerciseID, start: now.addingTimeInterval(-86400), actual: 70, completed: true),
            execution(exerciseID: exerciseID, start: now.addingTimeInterval(-3600), actual: 95, completed: false),
            execution(exerciseID: exerciseID, start: now, actual: 100, completed: true)
        ]
        XCTAssertEqual(ClientActivityInsights.previousExerciseLoad(exerciseID: exerciseID, state: state, before: now), 70)
    }

    func testPreviousLoadNeverUsesAnUnexecutedPrescribedWeight() {
        let exerciseID = UUID(); let now = Date()
        var state = ClientActivityState.empty
        state.workouts = [execution(exerciseID: exerciseID, start: now.addingTimeInterval(-86400), actual: nil, completed: true)]
        XCTAssertNil(ClientActivityInsights.previousExerciseLoad(exerciseID: exerciseID, state: state, before: now))
    }

    private func execution(exerciseID: UUID, start: Date, actual: Double?, completed: Bool) -> ClientWorkoutExecution {
        ClientWorkoutExecution(id: UUID(), planID: UUID(), sessionID: UUID(), dayKey: "test", startedAt: start, completedAt: nil,
            exercises: [ClientExerciseLog(id: UUID(), exerciseID: exerciseID, note: "", sets: [
                ClientSetLog(id: UUID(), number: 1, prescribedRepetitions: "10", prescribedLoadKg: 80,
                    actualRepetitions: nil, actualLoadKg: actual, completedAt: completed ? start.addingTimeInterval(60) : nil)
            ])], feedback: nil)
    }
}
