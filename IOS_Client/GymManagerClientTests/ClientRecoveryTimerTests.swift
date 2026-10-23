import Foundation
import XCTest
@testable import GymManagerClient

final class ClientRecoveryTimerTests: XCTestCase {
    private let origin = Date(timeIntervalSince1970: 1_000)
    private func timer() -> ClientRestTimerState {
        ClientRestTimerState(exerciseID: UUID(), nextSetNumber: 2, phase: .running,
            endsAt: origin.addingTimeInterval(120), pausedSeconds: nil, startedAt: origin, durationSeconds: 120)
    }

    func testTimestampAndRingSurviveForegroundGap() throws {
        let restored = try JSONDecoder().decode(ClientRestTimerState.self, from: JSONEncoder().encode(timer()))
        XCTAssertEqual(restored.remainingSeconds(at: origin.addingTimeInterval(90)), 30)
        XCTAssertEqual(try XCTUnwrap(restored.remainingFraction(at: origin.addingTimeInterval(90))), 0.25, accuracy: 0.001)
        XCTAssertEqual(restored.remainingSeconds(at: origin.addingTimeInterval(500)), 0)
    }

    func testPauseDoesNotConsumeTimeAndResumeUsesNewDeadline() {
        var timer = timer(); timer.pause(at: origin.addingTimeInterval(30))
        XCTAssertEqual(timer.remainingSeconds(at: origin.addingTimeInterval(500)), 90)
        timer.resume(at: origin.addingTimeInterval(500))
        XCTAssertEqual(timer.remainingSeconds(at: origin.addingTimeInterval(530)), 60)
    }

    func testPlusAndMinusFifteenClampWithoutNegativeTime() {
        var timer = timer()
        timer.adjust(by: 15, at: origin.addingTimeInterval(30))
        XCTAssertEqual(timer.remainingSeconds(at: origin.addingTimeInterval(30)), 105)
        XCTAssertEqual(timer.durationSeconds, 135)
        timer.adjust(by: -15, at: origin.addingTimeInterval(30))
        XCTAssertEqual(timer.remainingSeconds(at: origin.addingTimeInterval(30)), 90)
        timer.adjust(by: -300, at: origin.addingTimeInterval(30))
        XCTAssertEqual(timer.remainingSeconds(at: origin.addingTimeInterval(30)), 0)
    }

    func testPausedAdjustmentPreservesPause() {
        var timer = timer(); timer.pause(at: origin.addingTimeInterval(110))
        timer.adjust(by: 15, at: origin.addingTimeInterval(500))
        XCTAssertEqual(timer.phase, .paused)
        XCTAssertEqual(timer.remainingSeconds(at: origin.addingTimeInterval(600)), 25)
    }

    func testLegacyTimerDecodesWithoutInventedProgressDuration() throws {
        let legacy = ClientRestTimerState(exerciseID: UUID(), nextSetNumber: nil, phase: .paused, endsAt: nil, pausedSeconds: 30)
        let restored = try JSONDecoder().decode(ClientRestTimerState.self, from: JSONEncoder().encode(legacy))
        XCTAssertEqual(restored.remainingSeconds(at: origin), 30)
        XCTAssertNil(restored.remainingFraction(at: origin))
    }
}
