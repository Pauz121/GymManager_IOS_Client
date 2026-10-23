import SwiftUI
import UIKit
import XCTest
@testable import GymManagerClient

/// UIKit/SwiftUI measurements, not HTML approximations. Device visual QA is also
/// required for shadow/rasterization and NavigationStack/safe-area behavior.
final class ClientCardLayoutTests: XCTestCase {
    @MainActor
    func testDecorativeSurfaceHonorsShortCardProposal() {
        for width: CGFloat in [288, 398] {
            let host = UIHostingController(rootView: ClientPremiumCardSurface(tint: ClientClay.accent))
            let size = host.sizeThatFits(in: CGSize(width: width, height: 60))
            XCTAssertEqual(size.width, width, accuracy: 1)
            XCTAssertEqual(size.height, 60, accuracy: 1, "150pt decoration must not set a minimum background height")
        }
    }

    @MainActor
    func testPremiumModifierKeepsNaturalContentHeight() {
        for width: CGFloat in [288, 398] {
            let content = Text("Piano attivo").frame(height: 40).premiumCard(padding: 14)
            let size = measured(content, width: width)
            XCTAssertEqual(size.height, 68, accuracy: 1)
            XCTAssertLessThanOrEqual(size.width, width + 1)
        }
    }

    @MainActor
    func testGymHeaderAndRestCardReserveSeparateVerticalSpace() {
        let plan = fixturePlan(title: "Scheda completa — forza e controllo del movimento per tutto il corpo")
        for width: CGFloat in [288, 398] {
            for typeSize in [DynamicTypeSize.large, .accessibility3] {
                let header = ClientGymPlanHeader(plan: plan).dynamicTypeSize(typeSize)
                let rest = ClientEmptyState(symbol: "moon.zzz", title: "Oggi riposo", message: "Consulta le sessioni del piano.")
                    .dynamicTypeSize(typeSize)
                let stack = VStack(alignment: .leading, spacing: 18) { header; rest }
                let combined = measured(stack, width: width)
                let individualHeight = measured(header, width: width).height + measured(rest, width: width).height
                XCTAssertGreaterThanOrEqual(combined.height, individualHeight + 17)
                XCTAssertLessThanOrEqual(combined.width, width + 1)
            }
        }
    }

    @MainActor
    func testLongGymTitleGrowsVerticallyAtAccessibilitySize() {
        let header = ClientGymPlanHeader(plan: fixturePlan(title: String(repeating: "Titolo scheda molto lungo ", count: 4)))
        let standard = measured(header.dynamicTypeSize(.large), width: 288)
        let accessible = measured(header.dynamicTypeSize(.accessibility3), width: 288)
        XCTAssertGreaterThan(accessible.height, standard.height)
        XCTAssertLessThanOrEqual(accessible.width, 289)
    }

    @MainActor
    func testRecapHeaderAdaptsToSmallAndLargePhoneAndDynamicType() {
        for width: CGFloat in [288, 398] {
            for typeSize in [DynamicTypeSize.large, .accessibility3] {
                let header = ClientActivityRecapHeader(activeDays: 31, duration: "124h 59m").dynamicTypeSize(typeSize)
                let size = measured(header, width: width)
                XCTAssertLessThanOrEqual(size.width, width + 1)
                XCTAssertGreaterThan(size.height, 24)
                XCTAssertLessThan(size.height, 1_500)
            }
        }
    }

    @MainActor
    private func measured<Content: View>(_ content: Content, width: CGFloat) -> CGSize {
        UIHostingController(rootView: content).sizeThatFits(in: CGSize(width: width, height: 10_000))
    }

    private func fixturePlan(title: String) -> ClientWorkoutPlan {
        ClientWorkoutPlan(id: UUID(), title: title, startsOn: nil, endsOn: nil, currentWeek: 4,
                          sessions: [], todaySessionID: nil, publishedAt: Date())
    }
}
