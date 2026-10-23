import CoreGraphics
import XCTest
@testable import GymManagerClient

final class ClientFloatingTimerTests: XCTestCase {
    func testDockStaysInsideBoundsForPhoneAndRotation() throws {
        for size in [CGSize(width: 320, height: 460), CGSize(width: 430, height: 720), CGSize(width: 700, height: 270)] {
            let bounds = CGRect(origin: .zero, size: size)
            let center = try XCTUnwrap(ClientFloatingTimerPlacement.center(preferred: CGPoint(x: 1000, y: -80), bounds: bounds, diameter: 84, avoiding: []))
            XCTAssertTrue(bounds.insetBy(dx: 42, dy: 42).contains(center))
        }
    }
    func testCriticalFormIsNotCovered() throws {
        let bounds = CGRect(x: 0, y: 0, width: 375, height: 650)
        let form = CGRect(x: 0, y: 180, width: 375, height: 250)
        let center = try XCTUnwrap(ClientFloatingTimerPlacement.center(preferred: CGPoint(x: 350, y: 260), bounds: bounds, diameter: 84, avoiding: [form]))
        XCTAssertFalse(form.insetBy(dx: -42, dy: -42).contains(center))
    }
    func testNoSafeSpaceRequestsNativeAccessoryInsteadOfCoveringForm() {
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 480)
        XCTAssertNil(ClientFloatingTimerPlacement.center(preferred: CGPoint(x: 200, y: 200), bounds: bounds, diameter: 84, avoiding: [bounds]))
        XCTAssertNil(ClientFloatingTimerPlacement.center(preferred: CGPoint(x: 10, y: 10), bounds: .zero, diameter: 84, avoiding: []))
        XCTAssertNil(ClientFloatingTimerPlacement.center(preferred: CGPoint(x: 10, y: 10), bounds: CGRect(x: 0, y: 0, width: 90, height: 600), diameter: 84, avoiding: []))
        XCTAssertNil(ClientFloatingTimerPlacement.center(preferred: CGPoint(x: CGFloat.nan, y: 10), bounds: bounds, diameter: 84, avoiding: []))
    }
}
