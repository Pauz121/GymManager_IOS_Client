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

    func testTrainerCodeIsNormalized() {
        XCTAssertEqual(TrainerCodeService.normalized("  gm-1234-abcd-5678-90ef-1122  "), "GM-1234-ABCD-5678-90EF-1122")
    }

    func testTrainerCodeValidationMatchesServerContract() {
        XCTAssertTrue(TrainerCodeService.isValid("GM-1234-ABCD-5678-90EF-1122"))
        XCTAssertFalse(TrainerCodeService.isValid("ABC"))
        XCTAssertFalse(TrainerCodeService.isValid("GM-1234-ABCD-5678-90EF"))
    }

    func testInvalidTrainerCodeFailsBeforeNetworkCall() async {
        do {
            try await TrainerCodeService().activate(code: "ABC")
            XCTFail("An invalid code must be rejected locally")
        } catch {
            XCTAssertEqual(error as? ClientAppError, .message("Inserisci un codice GymManager valido."))
        }
    }

    func testTrainerCodeActivationResponseDecodesServerPayload() throws {
        let payload = #"{"clientId":"10000000-0000-4000-8000-000000000001","trainerId":"20000000-0000-4000-8000-000000000002","alreadyLinked":false}"#.data(using: .utf8)!
        let result = try JSONDecoder().decode(TrainerCodeActivationResult.self, from: payload)
        XCTAssertEqual(result.clientID.uuidString.lowercased(), "10000000-0000-4000-8000-000000000001")
        XCTAssertEqual(result.trainerID.uuidString.lowercased(), "20000000-0000-4000-8000-000000000002")
        XCTAssertFalse(result.alreadyLinked)
    }

    func testProgressWeekAlwaysRunsMondayThroughSunday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let wednesday = Date(timeIntervalSince1970: 1_757_462_400) // 2025-09-10 00:00 UTC
        let days = ClientProgressWeek.mondayToSunday(containing: wednesday, calendar: calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(calendar.component(.weekday, from: days.first!), 2)
        XCTAssertEqual(calendar.component(.weekday, from: days.last!), 1)
    }

    func testRegistrationStepOneRequiresBiologicalSex() {
        var input = validRegistrationInput()
        input.biologicalSex = nil
        XCTAssertEqual(ClientRegistrationValidation.stepOneIssue(for: input)?.field, .biologicalSex)
    }

    func testRegistrationStepOneNormalizesAndAcceptsValidData() {
        let input = validRegistrationInput()
        XCTAssertNil(ClientRegistrationValidation.stepOneIssue(for: input))
        XCTAssertEqual(ClientRegistrationValidation.normalizedEmail("  MARIO@EXAMPLE.COM "), "mario@example.com")
        XCTAssertEqual(ClientRegistrationValidation.normalizedName("  Mario  "), "Mario")
        XCTAssertEqual(ClientRegistrationValidation.normalizedUsername("  Mario.Rossi "), "mario.rossi")
    }

    func testRegistrationRejectsInvalidUsernameBeforeAuth() {
        var input = validRegistrationInput()
        input.username = "nome con spazi"
        XCTAssertEqual(ClientRegistrationValidation.stepTwoIssue(for: input)?.field, .username)
    }

    func testRegistrationRequiresTwelveCharacterMatchingPasswords() {
        var input = validRegistrationInput()
        input.password = "breve"
        input.passwordConfirmation = "breve"
        XCTAssertEqual(ClientRegistrationValidation.stepTwoIssue(for: input)?.field, .password)

        input.password = "password-sicura"
        input.passwordConfirmation = "password-diversa"
        XCTAssertEqual(ClientRegistrationValidation.stepTwoIssue(for: input)?.field, .passwordConfirmation)
    }

    func testRegistrationErrorClassifierUsesServerWeakPasswordCode() {
        let issue = ClientRegistrationErrorClassifier.issue(
            message: "Server validation failed",
            code: "weak_password",
            status: 422
        )
        XCTAssertEqual(issue.field, .password)
        XCTAssertTrue(issue.message.contains("12 caratteri"))
    }

    func testRegistrationErrorClassifierDistinguishesDuplicateEmail() {
        let issue = ClientRegistrationErrorClassifier.issue(
            message: "User already registered",
            code: "user_already_exists",
            status: 422
        )
        XCTAssertEqual(issue.field, .form)
        XCTAssertTrue(issue.message.contains("email"))
    }

    func testRegistrationErrorClassifierDistinguishesDuplicateUsername() {
        let issue = ClientRegistrationErrorClassifier.issue(
            message: "Database error saving new user: client_username_unavailable",
            code: "unexpected_failure",
            status: 500
        )
        XCTAssertEqual(issue.field, .username)
        XCTAssertTrue(issue.message.contains("username"))
    }

    func testRegistrationErrorClassifierExplainsEmailConfirmation() {
        let issue = ClientRegistrationErrorClassifier.issue(
            message: "Email not confirmed",
            code: "email_not_confirmed",
            status: 400
        )
        XCTAssertEqual(issue.field, .form)
        XCTAssertTrue(issue.message.contains("confermata"))
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
        XCTAssertTrue(identity.hasCompletedInitialOnboarding)
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

    func testHealthDayWindowUsesTheRequestedCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = Date(timeIntervalSince1970: 1_757_750_400) // 2025-09-13 08:00 UTC
        let interval = ClientHealthDayWindow.interval(containing: date, calendar: calendar)

        XCTAssertEqual(interval.start, calendar.startOfDay(for: date))
        XCTAssertEqual(interval.end, calendar.date(byAdding: .day, value: 1, to: interval.start))
        XCTAssertTrue(interval.contains(date))
    }

    func testHealthDayWindowRespectsCalendarTimeZone() {
        let date = Date(timeIntervalSince1970: 1_757_750_400)
        var rome = Calendar(identifier: .gregorian)
        rome.timeZone = TimeZone(identifier: "Europe/Rome")!
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!

        XCTAssertNotEqual(
            ClientHealthDayWindow.interval(containing: date, calendar: rome).start,
            ClientHealthDayWindow.interval(containing: date, calendar: utc).start
        )
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

    func testAutomaticKilometerSplitsRequireCompletedDistance() {
        XCTAssertTrue(ClientRunningAchievements.splits(for: route(distanceMeters: 900, duration: 300)).isEmpty)
        let splits = ClientRunningAchievements.splits(for: route(distanceMeters: 2_050, duration: 600))
        XCTAssertEqual(splits.count, 2)
        XCTAssertEqual(splits.map(\.index), [1, 2])
        XCTAssertGreaterThan(splits[0].durationSeconds, 0)
        XCTAssertGreaterThan(splits[1].durationSeconds, 0)
    }

    func testStabilizedRunningSpeedUsesThirtySecondWindow() {
        let points = route(distanceMeters: 300, duration: 30)
        XCTAssertEqual(ClientRunningMetrics.stabilizedSpeedMetersPerSecond(for: points) ?? 0, 10, accuracy: 0.1)
        XCTAssertNil(ClientRunningMetrics.stabilizedSpeedMetersPerSecond(for: route(distanceMeters: 40, duration: 5)))
    }

    func testBestEffortFindsInternalThreeKilometerWindow() {
        let start = Date(timeIntervalSince1970: 1_757_721_600)
        let distances = stride(from: 0.0, through: 8_000.0, by: 1_000).map { $0 }
        let elapsed: [TimeInterval] = [0, 360, 720, 1_080, 1_320, 1_560, 1_800, 2_160, 2_520]
        let points = zip(distances, elapsed).map { distance, time in
            routePoint(distanceMeters: distance, elapsed: time, start: start)
        }
        let best = ClientRunningAchievements.bestEffort(for: points, target: .threeKilometers)
        XCTAssertNotNil(best)
        XCTAssertEqual(best?.durationSeconds ?? 0, 720, accuracy: 1)
        XCTAssertEqual(best?.startOffsetMeters ?? 0, 3_000, accuracy: 2)
    }

    func testBestEffortDoesNotExtrapolateMissingTenKilometers() {
        XCTAssertNil(ClientRunningAchievements.bestEffort(for: route(distanceMeters: 9_900, duration: 3_000), target: .tenKilometers))
        XCTAssertNotNil(ClientRunningAchievements.bestEffort(for: route(distanceMeters: 10_100, duration: 3_000), target: .tenKilometers))
    }

    func testOneThreeFiveAndTenKilometerBestEffortsUseCoveredDistance() {
        let longRoute = route(distanceMeters: 10_100, duration: 3_600)
        for target in ClientRunningTarget.allCases {
            let effort = ClientRunningAchievements.bestEffort(for: longRoute, target: target)
            XCTAssertNotNil(effort, "Missing \(target.title)")
            XCTAssertEqual((effort?.endOffsetMeters ?? 0) - (effort?.startOffsetMeters ?? 0), Double(target.rawValue), accuracy: 2)
        }
    }

    func testRunningTopThreeSortsAndKeepsOneEntryPerSession() {
        let results = [3_000.0, 2_700.0, 2_850.0, 2_600.0].enumerated().map { index, duration in
            runningResult(distanceMeters: 5_100, duration: duration, completedAt: Date(timeIntervalSince1970: 1_757_721_600 + Double(index) * 86_400))
        }
        let top = ClientRunningAchievements.leaderboard(results: results, target: .fiveKilometers)
        XCTAssertEqual(top.count, 3)
        XCTAssertEqual(top.map(\.sessionID).count, Set(top.map(\.sessionID)).count)
        XCTAssertEqual(top.map(\.effort.durationSeconds), top.map(\.effort.durationSeconds).sorted())
    }

    func testNewPersonalBestCanContainMultipleDistances() {
        let old = runningResult(distanceMeters: 5_100, duration: 1_800, completedAt: Date(timeIntervalSince1970: 1_757_721_600))
        let current = runningResult(distanceMeters: 5_100, duration: 1_500, completedAt: Date(timeIntervalSince1970: 1_757_808_000))
        let targets = ClientRunningAchievements.newPersonalBests(for: current, comparedWith: [old]).map(\.target)
        XCTAssertTrue(targets.contains(.oneKilometer))
        XCTAssertTrue(targets.contains(.threeKilometers))
        XCTAssertTrue(targets.contains(.fiveKilometers))
        XCTAssertFalse(targets.contains(.tenKilometers))
    }

    func testActivityAggregationCombinesGymAndRunningWithoutDuplicates() {
        let snapshot = ClientDemoData.snapshot(for: .trainerConnected)
        let workout = snapshot.workout!.sessions[0]
        let plan = snapshot.workout!
        let start = Date(timeIntervalSince1970: 1_757_721_600)
        let execution = ClientWorkoutExecution(
            id: UUID(), planID: plan.id, sessionID: workout.id,
            dayKey: ClientDayKey.string(for: start), startedAt: start,
            completedAt: start.addingTimeInterval(3_600), exercises: [], feedback: nil
        )
        let run = runningResult(distanceMeters: 5_100, duration: 1_800, completedAt: start.addingTimeInterval(7_200))
        let state = ClientActivityState(workouts: [execution], meals: [], restTimer: nil, activeRun: nil, runningResults: [run])
        let interval = DateInterval(start: start.addingTimeInterval(-1), end: start.addingTimeInterval(86_400))
        let summary = ClientActivityInsights.summary(state: state, snapshot: snapshot, interval: interval)
        XCTAssertEqual(summary.gymSessions, 1)
        XCTAssertEqual(summary.runs, 1)
        XCTAssertEqual(summary.activeDays, 1)
        XCTAssertEqual(ClientActivityInsights.items(state: state, snapshot: snapshot).count, 2)
        XCTAssertEqual(ClientActivityInsights.items(on: start, state: state, snapshot: snapshot).count, 2)
        XCTAssertTrue(ClientActivityInsights.items(on: start.addingTimeInterval(86_400), state: state, snapshot: snapshot).isEmpty)
    }

    func testActivityPeriodCoversRequestedCalendarMonths() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = Date(timeIntervalSince1970: 1_757_750_400)
        let interval = ClientActivityInsights.interval(for: .threeMonths, endingAt: date, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.month], from: interval.start, to: interval.end).month, 3)
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

    func testExerciseLoadHistoryUsesBestPositiveCompletedLoadPerSession() {
        let exerciseID = UUID()
        let firstDate = Date(timeIntervalSince1970: 1_757_721_600)
        func execution(date: Date, loads: [(Double?, Bool)]) -> ClientWorkoutExecution {
            let sets = loads.enumerated().map { index, item in
                ClientSetLog(
                    id: UUID(), number: index + 1, prescribedRepetitions: "8", prescribedLoadKg: 70,
                    actualRepetitions: 8, actualLoadKg: item.0,
                    completedAt: item.1 ? date.addingTimeInterval(Double(index + 1) * 60) : nil
                )
            }
            return ClientWorkoutExecution(
                id: UUID(), planID: UUID(), sessionID: UUID(), dayKey: ClientDayKey.string(for: date),
                startedAt: date, completedAt: date.addingTimeInterval(600),
                exercises: [ClientExerciseLog(id: UUID(), exerciseID: exerciseID, note: "", sets: sets)], feedback: nil
            )
        }
        let state = ClientActivityState(
            workouts: [
                execution(date: firstDate, loads: [(70, true), (75, true), (90, false)]),
                execution(date: firstDate.addingTimeInterval(86_400), loads: [(0, true), (80, true)])
            ],
            meals: [], restTimer: nil, activeRun: nil, runningResults: []
        )
        let points = ClientActivityInsights.exerciseLoadHistory(exerciseID: exerciseID, state: state)
        XCTAssertEqual(points.map(\.loadKg), [75, 80])
        XCTAssertLessThan(points[0].date, points[1].date)
    }

    func testTrainerDemoPopulatesHistoricalPlansAndPerformanceData() {
        let snapshot = ClientDemoData.snapshot(for: .trainerConnected)
        let activity = ClientDemoData.activity(for: .trainerConnected)
        XCTAssertEqual(snapshot.workoutHistory?.count, 2)
        XCTAssertEqual(activity.workouts.count, 4)
        XCTAssertEqual(activity.runningResults.count, 6)
        XCTAssertEqual(activity.meals.count, 2)
        XCTAssertEqual(ClientRunningAchievements.leaderboard(results: activity.runningResults, target: .tenKilometers).count, 3)

        let grouped = Dictionary(grouping: ClientActivityInsights.items(state: activity, snapshot: snapshot)) {
            ClientDayKey.string(for: $0.completedAt)
        }
        XCTAssertTrue(grouped.values.contains { items in
            items.contains(where: { $0.kind == .gym }) && items.contains(where: { $0.kind == .running })
        })
    }

    func testPersonalWorkoutConvertsToExecutableClientPlan() {
        let exercise = ClientPersonalExercise(
            id: UUID(), catalogExerciseID: UUID(), name: "Squat", muscleGroup: "Gambe",
            sets: 4, repetitions: "8", restSeconds: 120, loadKg: 80,
            effortTarget: "RIR 2", notes: "Controlla la discesa", videoURL: nil
        )
        let session = ClientPersonalWorkoutSession(id: UUID(), name: "Lower", weekday: 2, exercises: [exercise])
        let plan = ClientPersonalWorkoutPlan(id: UUID(), title: "Forza", status: .active, sessions: [session], createdAt: Date(), updatedAt: Date())
        let converted = plan.asClientPlan()
        XCTAssertEqual(converted.sessions.first?.exercises.first?.setCount, 4)
        XCTAssertEqual(converted.sessions.first?.exercises.first?.restSeconds, 120)
        XCTAssertTrue(converted.sessions.first?.exercises.first?.notes?.contains("RIR 2") == true)
    }

    func testPersonalNutritionUsesRealQuantityCalories() {
        let food = ClientPersonalFood(
            id: UUID(), catalogFoodID: UUID(), name: "Riso", quantityGrams: 150,
            caloriesPer100g: 350, proteinPer100g: 7, carbsPer100g: 78, fatPer100g: 1
        )
        XCTAssertEqual(food.calories, 525, accuracy: 0.001)
        let meal = ClientPersonalMeal(id: UUID(), name: "Pranzo", foods: [food])
        XCTAssertEqual(meal.calories, 525, accuracy: 0.001)
        XCTAssertEqual(meal.protein, 10.5, accuracy: 0.001)
        XCTAssertEqual(meal.carbs, 117, accuracy: 0.001)
        XCTAssertEqual(meal.fat, 1.5, accuracy: 0.001)
    }

    func testPersonalContentMergeKeepsNewestAndNeverDropsLocalOnlyPlans() {
        let sharedID = UUID()
        let localOnly = ClientPersonalWorkoutLibraryView.newPlan()
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        let localShared = ClientPersonalWorkoutPlan(
            id: sharedID, title: "Versione locale", status: .active, sessions: [],
            createdAt: older, updatedAt: newer
        )
        let remoteShared = ClientPersonalWorkoutPlan(
            id: sharedID, title: "Versione remota", status: .draft, sessions: [],
            createdAt: older, updatedAt: older
        )
        let local = ClientPersonalContentState(workoutPlans: [localOnly, localShared], nutritionPlans: [], mealTemplates: [])
        let remote = ClientPersonalContentState(workoutPlans: [remoteShared], nutritionPlans: [], mealTemplates: [])

        let merged = local.merging(remote)

        XCTAssertEqual(merged.workoutPlans.count, 2)
        XCTAssertEqual(merged.workoutPlans.first(where: { $0.id == sharedID })?.title, "Versione locale")
        XCTAssertTrue(merged.workoutPlans.contains(where: { $0.id == localOnly.id }))
    }

    func testPersonalContentStorageIsNamespacedAndSurvivesConnectionModeChanges() throws {
        let suite = "ClientPersonalContentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ClientPersonalContentStore(defaults: defaults)
        let user = UUID()
        let plan = ClientPersonalWorkoutLibraryView.newPlan()
        let state = ClientPersonalContentState(workoutPlans: [plan], nutritionPlans: [], mealTemplates: [])
        try store.save(state, userID: user)
        XCTAssertEqual(store.load(userID: user).activeWorkout?.id, plan.id)
        XCTAssertTrue(store.load(userID: UUID()).workoutPlans.isEmpty)
    }

    private func route(distanceMeters: Double, duration: TimeInterval) -> [ClientRoutePoint] {
        let start = Date(timeIntervalSince1970: 1_757_721_600)
        return [
            routePoint(distanceMeters: 0, elapsed: 0, start: start),
            routePoint(distanceMeters: distanceMeters, elapsed: duration, start: start)
        ]
    }

    private func validRegistrationInput() -> ClientRegistrationInput {
        ClientRegistrationInput(
            firstName: "Mario",
            lastName: "Rossi",
            biologicalSex: .male,
            email: "mario@example.com",
            username: "mario.rossi",
            password: "password-sicura",
            passwordConfirmation: "password-sicura"
        )
    }

    private func routePoint(distanceMeters: Double, elapsed: TimeInterval, start: Date) -> ClientRoutePoint {
        ClientRoutePoint(
            latitude: distanceMeters / 111_195,
            longitude: 9,
            timestamp: start.addingTimeInterval(elapsed),
            horizontalAccuracy: 5,
            speedMetersPerSecond: nil,
            elapsedSeconds: elapsed
        )
    }

    private func runningResult(distanceMeters: Double, duration: TimeInterval, completedAt: Date) -> ClientRunningResult {
        ClientRunningResult(
            id: UUID(), planID: UUID(), completedAt: completedAt,
            durationSeconds: duration, distanceKm: distanceMeters / 1_000,
            route: route(distanceMeters: distanceMeters, duration: duration),
            maximumSpeedKmh: nil, effort: nil, note: ""
        )
    }
}
