import Foundation
import Supabase
import XCTest
@testable import GymManagerClient

/// Native tests: run in the iOS Simulator. They never authenticate to production.
final class ClientContentLifecycleTests: XCTestCase {
    func testEmptyMeansSuccessfulAbsenceNotPendingOrFailure() {
        let snapshot = ClientSnapshot.empty
        XCTAssertEqual(snapshot.loadPhase, .empty)
        for section in ClientContentSection.allCases {
            XCTAssertEqual(snapshot.contentState(for: section), .empty)
        }
    }

    func testPendingSectionsAreNotConvertedToEmpty() {
        for pending in [ClientContentLoadState.idle, .loading] {
            var snapshot = ClientSnapshot.empty
            snapshot.setContentState(pending, for: .workout)
            XCTAssertEqual(snapshot.loadPhase, .loading)
            XCTAssertTrue(snapshot.contentState(for: .workout).isPending)
            XCTAssertNil(snapshot.contentState(for: .workout).failure)
        }
    }

    func testRealFailureRemainsErrorEvenWithNoRows() {
        var snapshot = ClientSnapshot.empty
        snapshot.setContentState(.failed("Progressi: lettura non riuscita."), for: .progress)
        XCTAssertEqual(snapshot.loadPhase, .error)
        XCTAssertNotEqual(snapshot.contentState(for: .progress), .empty)
        XCTAssertEqual(snapshot.contentState(for: .workout), .empty)
    }

    func testLegacyWarningDoesNotBecomeFakeEmpty() {
        var snapshot = ClientSnapshot.empty
        snapshot.warnings = ["Allenamento: caricamento non riuscito."]
        XCTAssertNotNil(snapshot.contentState(for: .workout).failure)
        XCTAssertEqual(snapshot.loadPhase, .error)
    }

    func testLegacySnapshotDecodesWithoutLifecycleProperty() throws {
        let encoded = try JSONEncoder().encode(ClientSnapshot.empty)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(object["contentStates"])
        let decoded = try JSONDecoder().decode(ClientSnapshot.self, from: encoded)
        XCTAssertEqual(decoded, .empty)
        XCTAssertEqual(decoded.loadPhase, .empty)
    }

    func testExplicitSectionStatesRoundTripWithoutChangingPlanData() throws {
        var snapshot = ClientDemoData.snapshot(for: .trainerConnected)
        snapshot.setContentState(.failed("Nutrizione: lettura non riuscita."), for: .nutrition)
        snapshot.setContentState(.loaded, for: .workout)
        let decoded = try JSONDecoder().decode(ClientSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(decoded, snapshot)
    }

    func testRealFailureRetainsAllPreviousSectionsAndTheirError() {
        let previous = ClientDemoData.snapshot(for: .trainerConnected)
        var fresh = ClientSnapshot.empty
        for section in ClientContentSection.allCases {
            fresh.setContentState(.failed("Lettura non riuscita."), for: section)
        }
        fresh.retainFailedSections(from: previous)
        XCTAssertEqual(fresh.workout, previous.workout)
        XCTAssertEqual(fresh.nutrition, previous.nutrition)
        XCTAssertEqual(fresh.appointments, previous.appointments)
        XCTAssertEqual(fresh.progress, previous.progress)
        XCTAssertEqual(fresh.loadPhase, .error)
        XCTAssertTrue(ClientContentSection.allCases.allSatisfy { fresh.contentState(for: $0).failure != nil })
    }

    func testSuccessfulEmptyReadDoesNotResurrectPreviouslyAssignedPlans() {
        var fresh = ClientSnapshot.empty
        fresh.setContentState(.empty, for: .workout)
        fresh.setContentState(.empty, for: .nutrition)
        fresh.retainFailedSections(from: ClientDemoData.snapshot(for: .trainerConnected))
        XCTAssertNil(fresh.workout)
        XCTAssertNil(fresh.nutrition)
        XCTAssertEqual(fresh.loadPhase, .empty)
    }

    func testSuccessfulRetryReplacesErrorInsteadOfKeepingOldWarning() {
        var failed = ClientSnapshot.empty
        failed.setContentState(.failed("Progressi: errore."), for: .progress)
        var success = ClientSnapshot.empty
        success.setContentState(.empty, for: .progress)
        success.retainFailedSections(from: failed)
        XCTAssertNil(success.contentState(for: .progress).failure)
        XCTAssertTrue(success.warnings.isEmpty)
    }

    @MainActor
    func testCancelledSnapshotStopsBeforeAuthAndSectionQueries() async {
        let repository = fixtureRepository()
        let identity = ClientDemoData.identity(for: .trainerConnected)
        let task = Task { try await repository.snapshot(for: identity) }
        // The task inherits MainActor; cancelling before yielding is deterministic.
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Cancellation must not become four section warnings")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    @MainActor
    func testMissingConnectedIdentityIsNotReportedAsEmpty() async {
        var identity = ClientDemoData.identity(for: .trainerConnected)
        identity = ClientIdentity(authUserID: identity.authUserID, clientID: nil, trainerID: nil,
                                  mode: .trainerConnected, firstName: "Test", lastName: "Demo", displayName: "Test Demo",
                                  username: "fixture", email: nil, trainerName: nil,
                                  biologicalSex: nil, hasCompletedInitialOnboarding: true)
        do {
            _ = try await fixtureRepository().snapshot(for: identity)
            XCTFail("A connected identity without IDs is invalid, not an empty plan")
        } catch {
            XCTAssertEqual(error as? ClientAppError, .invalidClientLink)
        }
    }

    @MainActor
    func testStandaloneSnapshotNeedsNoTrainerQuery() async throws {
        let snapshot = try await fixtureRepository().snapshot(for: ClientDemoData.identity(for: .standalone))
        XCTAssertEqual(snapshot, .empty)
    }

    @MainActor
    private func fixtureRepository() -> ClientRepository {
        ClientRepository(client: SupabaseClient(supabaseURL: URL(string: "https://content-tests.invalid")!,
                                               supabaseKey: "sb_publishable_test_fixture_not_a_credential"))
    }
}
