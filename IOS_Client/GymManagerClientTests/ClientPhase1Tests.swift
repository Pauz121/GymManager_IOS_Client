import Foundation
import XCTest
@testable import GymManagerClient

final class ClientPhase1Tests: XCTestCase {
    func testTechnicalEmailNormalizesUsername() {
        XCTAssertEqual(ClientIdentityLogic.technicalEmail(for: "  Mario.Rossi "), "mario.rossi@accounts.gestionale.invalid")
    }

    func testTechnicalEmailPreservesRealEmail() {
        XCTAssertEqual(ClientIdentityLogic.technicalEmail(for: " MARIO@EXAMPLE.COM "), "mario@example.com")
    }

    func testProfessionalWorkoutIsReadOnly() {
        XCTAssertFalse(ClientAccessPolicy.canEditProfessionalWorkout)
    }

    func testProfessionalNutritionIsReadOnly() {
        XCTAssertFalse(ClientAccessPolicy.canEditProfessionalNutrition)
    }

    func testTrainerCannotBeDisconnectedFromClientUI() {
        XCTAssertFalse(ClientAccessPolicy.canDisconnectTrainer)
    }

    func testPersonalAgendaIsAvailable() {
        XCTAssertTrue(ClientAccessPolicy.canUsePersonalAgenda)
    }

    func testAgendaKeyIsNamespacedByLiveUser() {
        let user = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        XCTAssertEqual(PersonalAgendaStore.storageKey(userID: user, source: .live), "gymmanager.client.agenda.live.10000000-0000-0000-0000-000000000001")
    }

    func testDemoAndLiveAgendaKeysAreDifferent() {
        let user = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        XCTAssertNotEqual(PersonalAgendaStore.storageKey(userID: user, source: .live), PersonalAgendaStore.storageKey(userID: user, source: .demo))
    }

    func testAgendaTitleIsTrimmed() throws {
        XCTAssertEqual(try PersonalAgendaStore.validatedTitle("  Fare una passeggiata  "), "Fare una passeggiata")
    }

    func testAgendaRejectsEmptyTitle() {
        XCTAssertThrowsError(try PersonalAgendaStore.validatedTitle("   "))
    }

    func testAgendaRejectsOverlongTitle() {
        XCTAssertThrowsError(try PersonalAgendaStore.validatedTitle(String(repeating: "a", count: 161)))
    }

    func testTrainerCodeIsNormalizedWithoutClaimingActivation() {
        XCTAssertEqual(TrainerCodeService.normalized("  ab-cd  "), "AB-CD")
    }

    func testTrainerCodeContractFailsClosed() async {
        do {
            try await TrainerCodeService().activate(code: "ABC")
            XCTFail("The Phase 1 scaffold must never report success")
        } catch {
            XCTAssertEqual(error as? ClientAppError, .trainerCodeUnavailable)
        }
    }

    func testRegistrationUnavailableMessageDoesNotClaimCreation() {
        XCTAssertTrue(ClientAppError.registrationUnavailable.localizedDescription.contains("Nessun account"))
    }

    func testMondayUsesBackendWeekdayOne() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = Date(timeIntervalSince1970: 1_757_289_600) // 2025-09-08 00:00 UTC, Monday
        XCTAssertEqual(ClientDateLogic.weekday(for: date, calendar: calendar), 1)
    }

    func testSundayUsesBackendWeekdaySeven() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = Date(timeIntervalSince1970: 1_757_808_000) // 2025-09-14 00:00 UTC, Sunday
        XCTAssertEqual(ClientDateLogic.weekday(for: date, calendar: calendar), 7)
    }

    func testPlanWeekNeverFallsBelowOne() {
        let today = Date(timeIntervalSince1970: 1_757_289_600)
        XCTAssertEqual(ClientDateLogic.planWeek(startsOn: today.addingTimeInterval(86_400), durationWeeks: 4, fallback: 0, today: today), 1)
    }

    func testPlanWeekHonorsDurationLimit() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(ClientDateLogic.planWeek(startsOn: start, durationWeeks: 3, fallback: 1, today: start.addingTimeInterval(50 * 86_400)), 3)
    }

    func testEmptySnapshotContainsNoProfessionalData() {
        XCTAssertNil(ClientSnapshot.empty.workout)
        XCTAssertNil(ClientSnapshot.empty.nutrition)
        XCTAssertTrue(ClientSnapshot.empty.appointments.isEmpty)
        XCTAssertTrue(ClientSnapshot.empty.progress.isEmpty)
    }

    func testDemoUsesFakeInvalidEmailDomain() {
        let identity = ClientDemoData.identity(for: .trainerConnected)
        let snapshot = ClientDemoData.snapshot(for: .trainerConnected)
        XCTAssertEqual(snapshot.warnings, [])
        XCTAssertTrue(identity.email?.hasSuffix(".invalid") == true)
    }

    func testDemoIsTrainerConnectedWithoutUsingProductionIDs() {
        let identity = ClientDemoData.identity(for: .trainerConnected)
        XCTAssertEqual(identity.mode, .trainerConnected)
        XCTAssertTrue(identity.authUserID.uuidString.hasPrefix("DE000000"))
    }

    func testDemoHasCurrentWorkoutAndNutrition() {
        let snapshot = ClientDemoData.snapshot(for: .trainerConnected)
        XCTAssertNotNil(snapshot.workout)
        XCTAssertNotNil(snapshot.nutrition)
    }

    func testUpdatesAreOneWayDomainEvents() {
        let update = ClientDemoData.snapshot(for: .trainerConnected).updates.first
        XCTAssertEqual(update?.kind, .workout)
        XCTAssertFalse(update?.title.lowercased().contains("chat") == true)
    }

    func testHealthKitRemainsOutsideSnapshotDomainLayer() {
        let modelNames = String(describing: ClientSnapshot.self)
        XCTAssertFalse(modelNames.contains("HKHealthStore"))
    }

    func testStandaloneDemoHasNoTrainerOrProfessionalPlans() {
        let identity = ClientDemoData.identity(for: .standalone)
        let snapshot = ClientDemoData.snapshot(for: .standalone)
        XCTAssertEqual(identity.mode, .standalone)
        XCTAssertNil(identity.clientID)
        XCTAssertNil(identity.trainerID)
        XCTAssertNil(identity.trainerName)
        XCTAssertNil(snapshot.workout)
        XCTAssertNil(snapshot.nutrition)
    }

    func testDemoPersonasUseDifferentStorageNamespaces() {
        let connected = ClientDemoData.identity(for: .trainerConnected)
        let standalone = ClientDemoData.identity(for: .standalone)
        XCTAssertNotEqual(connected.authUserID, standalone.authUserID)
        XCTAssertNotEqual(
            ClientActivityStore.storageKey(userID: connected.authUserID, source: .demo),
            ClientActivityStore.storageKey(userID: standalone.authUserID, source: .demo)
        )
    }

    func testActivityStoreRoundTripAndSourceIsolation() throws {
        let suiteName = "ClientPhase1Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ClientActivityStore(defaults: defaults)
        let user = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        let meal = ClientMealCompletion(id: UUID(), mealID: UUID(), dayKey: "2026-09-13", completedAt: Date(timeIntervalSince1970: 1_757_721_600))
        var state = ClientActivityState.empty
        state.meals = [meal]

        try store.save(state, userID: user, source: .demo)

        XCTAssertEqual(store.load(userID: user, source: .demo), state)
        XCTAssertEqual(store.load(userID: user, source: .live), .empty)
    }

    func testMealCompletionIsScopedToMealAndDay() {
        let mealID = UUID()
        let date = Date(timeIntervalSince1970: 1_757_721_600)
        let completion = ClientMealCompletion(id: UUID(), mealID: mealID, dayKey: ClientDayKey.string(for: date), completedAt: date)
        var state = ClientActivityState.empty
        state.meals = [completion]

        XCTAssertTrue(state.isMealCompleted(mealID, on: date))
        XCTAssertFalse(state.isMealCompleted(mealID, on: date.addingTimeInterval(86_400)))
        XCTAssertFalse(state.isMealCompleted(UUID(), on: date))
    }

    func testRestTimerUsesEndTimestamp() {
        let now = Date(timeIntervalSince1970: 1_757_721_600)
        let timer = ClientRestTimerState(exerciseID: UUID(), nextSetNumber: 2, phase: .running, endsAt: now.addingTimeInterval(120), pausedSeconds: nil)
        XCTAssertEqual(timer.remainingSeconds(at: now), 120)
        XCTAssertEqual(timer.remainingSeconds(at: now.addingTimeInterval(31)), 89)
        XCTAssertEqual(timer.remainingSeconds(at: now.addingTimeInterval(121)), 0)
    }

    func testPausedRestTimerDoesNotDecrease() {
        let timer = ClientRestTimerState(exerciseID: UUID(), nextSetNumber: 2, phase: .paused, endsAt: nil, pausedSeconds: 45)
        XCTAssertEqual(timer.remainingSeconds(at: Date(timeIntervalSince1970: 0)), 45)
        XCTAssertEqual(timer.remainingSeconds(at: Date(timeIntervalSince1970: 500)), 45)
    }

    func testExerciseParsesSetCountAndFirstRepTarget() {
        let exercise = ClientExercise(id: UUID(), name: "Test", sets: "4", repetitions: "8-10", restSeconds: 90, loadKg: 50, notes: nil, videoURL: nil)
        XCTAssertEqual(exercise.setCount, 4)
        XCTAssertEqual(exercise.suggestedActualRepetitions, 8)
    }

    func testInvalidSetCountFallsBackToOne() {
        let exercise = ClientExercise(id: UUID(), name: "Test", sets: "non definito", repetitions: nil, restSeconds: nil, loadKg: nil, notes: nil, videoURL: nil)
        XCTAssertEqual(exercise.setCount, 1)
    }

    func testWorkoutCompletionKeepsCompletedExerciseVisibleInModel() {
        let completedSet = ClientSetLog(id: UUID(), number: 1, prescribedRepetitions: "8", prescribedLoadKg: 40, actualRepetitions: 8, actualLoadKg: 42.5, completedAt: Date())
        let exercise = ClientExerciseLog(id: UUID(), exerciseID: UUID(), note: "Buona esecuzione", sets: [completedSet])
        XCTAssertTrue(exercise.isCompleted)
        XCTAssertEqual(exercise.sets.count, 1)
        XCTAssertEqual(exercise.sets.first?.actualLoadKg, 42.5)
    }

    func testRunningPaceRequiresRealDistance() {
        let withoutDistance = ClientRunningResult(id: UUID(), planID: UUID(), completedAt: Date(), durationSeconds: 1_800, distanceKm: nil, route: [], maximumSpeedKmh: nil, effort: 3, note: "")
        let withDistance = ClientRunningResult(id: UUID(), planID: UUID(), completedAt: Date(), durationSeconds: 1_800, distanceKm: 5, route: [], maximumSpeedKmh: 12, effort: 3, note: "")
        XCTAssertNil(withoutDistance.averagePaceMinutesPerKm)
        XCTAssertEqual(withDistance.averagePaceMinutesPerKm, 6)
        XCTAssertEqual(withDistance.averageSpeedKmh, 10)
        XCTAssertEqual(withDistance.maximumSpeedKmh, 12)
    }

    func testRunningDistanceUsesRecordedRouteOnly() {
        let start = Date(timeIntervalSince1970: 1_757_721_600)
        let route = [
            ClientRoutePoint(latitude: 45, longitude: 9, timestamp: start, horizontalAccuracy: 5, speedMetersPerSecond: 3),
            ClientRoutePoint(latitude: 45.001, longitude: 9, timestamp: start.addingTimeInterval(30), horizontalAccuracy: 5, speedMetersPerSecond: 3)
        ]
        XCTAssertEqual(ClientRunningMetrics.distanceMeters(for: route), 111.2, accuracy: 1)
        XCTAssertEqual(ClientRunningMetrics.distanceMeters(for: []), 0)
    }

    func testRunningIsCapabilityGatedInDemoData() {
        let connected = ClientDemoData.snapshot(for: .trainerConnected)
        let standalone = ClientDemoData.snapshot(for: .standalone)
        XCTAssertTrue(connected.capabilities.runningEnabled)
        XCTAssertNotNil(connected.runningPlan)
        XCTAssertFalse(standalone.capabilities.runningEnabled)
        XCTAssertNil(standalone.runningPlan)
    }

    func testMealCaloriesSumOnlyCompleteSourceData() {
        let meal = ClientMeal(id: UUID(), name: "Pranzo", foods: [
            ClientFood(id: UUID(), name: "Riso", quantity: 100, unit: "g", caloriesKcal: 360),
            ClientFood(id: UUID(), name: "Pollo", quantity: 150, unit: "g", caloriesKcal: 240)
        ])
        XCTAssertEqual(meal.caloriesKcal, 600)
    }

    func testMealCaloriesDoNotInventMissingValues() {
        let meal = ClientMeal(id: UUID(), name: "Cena", foods: [
            ClientFood(id: UUID(), name: "Alimento", quantity: nil, unit: "g", caloriesKcal: nil)
        ])
        XCTAssertNil(meal.caloriesKcal)
    }

    func testDemoNutritionExposesWholeWeekWithCalories() {
        let days = ClientDemoData.snapshot(for: .trainerConnected).nutrition?.days ?? []
        XCTAssertEqual(days.count, 7)
        XCTAssertTrue(days.allSatisfy { $0.caloriesKcal != nil })
    }
}
