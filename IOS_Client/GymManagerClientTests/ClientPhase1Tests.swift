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
        XCTAssertEqual(ClientDemoData.snapshot.warnings, [])
        XCTAssertTrue(ClientDemoData.identity.email?.hasSuffix(".invalid") == true)
    }

    func testDemoIsTrainerConnectedWithoutUsingProductionIDs() {
        XCTAssertEqual(ClientDemoData.identity.mode, .trainerConnected)
        XCTAssertTrue(ClientDemoData.identity.authUserID.uuidString.hasPrefix("DE000000"))
    }

    func testDemoHasCurrentWorkoutAndNutrition() {
        XCTAssertNotNil(ClientDemoData.snapshot.workout)
        XCTAssertNotNil(ClientDemoData.snapshot.nutrition)
    }

    func testUpdatesAreOneWayDomainEvents() {
        let update = ClientDemoData.snapshot.updates.first
        XCTAssertEqual(update?.kind, .workout)
        XCTAssertFalse(update?.title.lowercased().contains("chat") == true)
    }

    func testHealthKitIsNotLinkedByTheDomainLayer() {
        let modelNames = String(describing: ClientSnapshot.self)
        XCTAssertFalse(modelNames.contains("HKHealthStore"))
    }
}
