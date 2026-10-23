import Foundation
import Supabase
import XCTest
@testable import GymManagerClient

final class ClientRefreshTests: XCTestCase {
    func testSwiftCancellationIsNotPresentedAsFailure() {
        XCTAssertTrue(ClientRefreshErrorPolicy.isCancellation(CancellationError()))
        XCTAssertNil(ClientRefreshErrorPolicy.message(for: CancellationError()))
    }

    func testURLSessionCancellationIsNotPresentedAsFailure() {
        let error = URLError(.cancelled)
        XCTAssertTrue(ClientRefreshErrorPolicy.isCancellation(error))
        XCTAssertNil(ClientRefreshErrorPolicy.message(for: error))
        XCTAssertEqual(ClientRefreshErrorPolicy.diagnosticCode(for: error), "cancelled")
    }

    func testRealNetworkFailureStillHasAnActionableMessage() {
        for error in [URLError(.notConnectedToInternet), URLError(.timedOut)] {
            XCTAssertFalse(ClientRefreshErrorPolicy.isCancellation(error))
            XCTAssertTrue(ClientRefreshErrorPolicy.message(for: error)?.contains("Riprova") == true)
            XCTAssertTrue(ClientRefreshErrorPolicy.message(for: error)?.contains("conservati") == true)
        }
    }

    func testMissingSessionRequestsLoginWithoutClaimingTrainerMutation() {
        let message = ClientRefreshErrorPolicy.message(for: AuthError.sessionMissing)
        XCTAssertTrue(message?.contains("accedi di nuovo") == true)
        XCTAssertFalse(message?.contains("Trainer") == true)
    }

    func testGenericReadFailureDoesNotUseTrainerActionCopy() {
        let message = ClientRefreshErrorPolicy.message(for: NSError(domain: "Fixture", code: 1))
        XCTAssertTrue(message?.contains("Riprova") == true)
        XCTAssertFalse(message?.contains("Trainer") == true)
        XCTAssertFalse(message?.contains("collegamento") == true)
    }

    func testExpiredJWTAndPermissionErrorsAreDifferent() {
        let expired = PostgrestError(code: "PGRST301", message: "sensitive server detail")
        let forbidden = PostgrestError(code: "42501", message: "sensitive server detail")
        XCTAssertTrue(ClientRefreshErrorPolicy.message(for: expired)?.contains("Accedi di nuovo") == true)
        XCTAssertTrue(ClientRefreshErrorPolicy.message(for: forbidden)?.contains("accesso non autorizzato") == true)
        XCTAssertNotEqual(ClientRefreshErrorPolicy.message(for: expired), ClientRefreshErrorPolicy.message(for: forbidden))
    }

    func testDatabaseDetailsNeverLeakIntoNoticesOrDiagnostics() {
        let error = PostgrestError(details: "private payload", code: "42P01", message: "sensitive server detail")
        XCTAssertFalse(ClientRefreshErrorPolicy.message(for: error)?.contains("sensitive") == true)
        XCTAssertFalse(ClientRefreshErrorPolicy.message(for: error)?.contains("private") == true)
        XCTAssertEqual(ClientRefreshErrorPolicy.diagnosticCode(for: error), "42P01")
    }

    func testUntrustedErrorCodeIsNotLogged() {
        let error = PostgrestError(code: "secret-or-personal-detail", message: "private payload")
        XCTAssertEqual(ClientRefreshErrorPolicy.diagnosticCode(for: error), "unknown")
    }

    func testDecodingFailureIsIdentifiedWithoutPayload() {
        let error = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "private payload"))
        XCTAssertEqual(ClientRefreshErrorPolicy.diagnosticCode(for: error), "decoding")
        XCTAssertFalse(ClientRefreshErrorPolicy.message(for: error)?.contains("private payload") == true)
    }

    func testDomainErrorsKeepTheirMeaning() {
        XCTAssertEqual(ClientRefreshErrorPolicy.message(for: ClientAppError.duplicateClientLinks),
                       ClientAppError.duplicateClientLinks.errorDescription)
    }
}
