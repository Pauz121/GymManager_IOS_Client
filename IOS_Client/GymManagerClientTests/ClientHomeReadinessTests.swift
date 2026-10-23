import XCTest
@testable import GymManagerClient

final class ClientHomeReadinessTests: XCTestCase {
    func testSlowSessionOrProfileNeverPresentsOldSectionFailureAsReady() {
        for phase in [ClientLoadPhase.idle, .authBootstrap] {
            for oldState in [ClientContentLoadState.empty, .loaded, .failed("Vecchia richiesta")] {
                XCTAssertEqual(ClientContentReadiness.resolve(oldState, phase: phase, hasActiveIdentity: false), .loading)
                XCTAssertEqual(ClientContentReadiness.resolve(oldState, phase: phase, hasActiveIdentity: true), .loading)
            }
        }
    }
    func testActiveLoadingDoesNotHideRealPreviousErrorDuringExplicitRetry() {
        XCTAssertEqual(ClientContentReadiness.resolve(.failed("Errore reale"), phase: .loading, hasActiveIdentity: true),
                       .failed("Errore reale"))
    }
    func testSuccessfulEmptyAndFailureRemainDistinctAfterReadiness() {
        XCTAssertEqual(ClientContentReadiness.resolve(.empty, phase: .empty, hasActiveIdentity: true), .empty)
        XCTAssertEqual(ClientContentReadiness.resolve(.loaded, phase: .loaded, hasActiveIdentity: true), .loaded)
        XCTAssertEqual(ClientContentReadiness.resolve(.failed("Errore reale"), phase: .error, hasActiveIdentity: true),
                       .failed("Errore reale"))
    }
    func testNoActiveIdentityCannotPresentReadyContent() {
        XCTAssertEqual(ClientContentReadiness.resolve(.loaded, phase: .loaded, hasActiveIdentity: false), .loading)
    }
}
