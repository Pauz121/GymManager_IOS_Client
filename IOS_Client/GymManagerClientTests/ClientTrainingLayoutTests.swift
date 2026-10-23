import SwiftUI
import UIKit
import XCTest
@testable import GymManagerClient

/// These are native measurements to run on Mac, not static Windows PASSes.
final class ClientTrainingLayoutTests: XCTestCase {
    @MainActor
    func testSelectorSupportsSmallStandardAndProMaxAtLargeDynamicType() {
        for width: CGFloat in [288, 343, 398] {
            for typeSize in [DynamicTypeSize.large, .accessibility3] {
                let selector = ClientCompactSelector(
                    values: ["Attività", "Palestra", "Corsa", "Riepilogo"],
                    selection: .constant("Attività"), title: { $0 },
                    accessibilityTitle: "Allenamento"
                ).dynamicTypeSize(typeSize)
                let size = measured(selector, width: width)
                XCTAssertLessThanOrEqual(size.width, width + 1)
                XCTAssertGreaterThanOrEqual(size.height, 44)
                XCTAssertLessThan(size.height, 160)
            }
        }
    }

    @MainActor
    func testRecapIsInlineInsteadOfDecorativeHeroAtDefaultSize() {
        let header = ClientActivityRecapHeader(activeDays: 1, duration: "1m")
        let size = measured(header, width: 343)
        XCTAssertLessThan(size.height, 70)
        XCTAssertLessThanOrEqual(size.width, 344)
    }

    @MainActor
    func testGymHeaderAndInlineRestDoNotOverlapAtAccessibilitySizes() {
        let plan = ClientWorkoutPlan(
            id: UUID(), title: String(repeating: "Scheda completa ", count: 5),
            startsOn: nil, endsOn: nil, currentWeek: 4, sessions: [],
            todaySessionID: nil, publishedAt: Date()
        )
        for width: CGFloat in [288, 343, 398] {
            for typeSize in [DynamicTypeSize.large, .accessibility3] {
                let header = ClientGymPlanHeader(plan: plan).dynamicTypeSize(typeSize)
                let rest = Label("Oggi riposo · consulta le sessioni del piano", systemImage: "moon.zzz")
                    .font(.subheadline).dynamicTypeSize(typeSize)
                    .fixedSize(horizontal: false, vertical: true)
                let stack = VStack(alignment: .leading, spacing: ClientSpacing.control) { header; rest }
                let size = measured(stack, width: width)
                XCTAssertLessThanOrEqual(size.width, width + 1)
                XCTAssertGreaterThanOrEqual(size.height, measured(header, width: width).height + measured(rest, width: width).height + 11)
            }
        }
    }

    @MainActor
    private func measured<Content: View>(_ view: Content, width: CGFloat) -> CGSize {
        UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: 10_000))
    }
}
