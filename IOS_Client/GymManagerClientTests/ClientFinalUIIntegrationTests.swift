import SwiftUI
import UIKit
import XCTest
@testable import GymManagerClient

/// Source-defined deterministic contracts. NOT rendered acceptance or DB tests.
final class ClientFinalUIIntegrationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_750_000_000)
    private func entry(_ weight: Double?, days: Double, id: String = "00000000-0000-0000-0000-000000000001") -> ClientProgressEntry {
        ClientProgressEntry(id: UUID(uuidString: id)!, recordedAt: now.addingTimeInterval(days * 86_400), weightKg: weight, waistCm: nil, hipsCm: nil)
    }
    func testF01PeriodRejectsFutureEvenForAll() {
        for period in ClientProgressPeriod.allCases { XCTAssertFalse(period.contains(now.addingTimeInterval(1), now: now)) }
    }
    func testF02ThirtyDayWindowIsCalendarBounded() {
        XCTAssertTrue(ClientProgressPeriod.month.contains(now.addingTimeInterval(-28 * 86_400), now: now))
        XCTAssertFalse(ClientProgressPeriod.month.contains(now.addingTimeInterval(-31 * 86_400), now: now))
    }
    func testF03QuarterAndAllAreDistinct() {
        let old = now.addingTimeInterval(-100 * 86_400)
        XCTAssertFalse(ClientProgressPeriod.quarter.contains(old, now: now))
        XCTAssertTrue(ClientProgressPeriod.all.contains(old, now: now))
    }
    func testF04RejectsMissingNonFiniteAndInvalidWeights() {
        let values = [entry(nil, days: 0), entry(.nan, days: 0), entry(.infinity, days: 0), entry(-1, days: 0), entry(70, days: -1)]
        XCTAssertEqual(ClientProgressPresentation.weights(values, period: .month, now: now).compactMap(\.weightKg), [70])
    }
    func testF05SinglePointHasNoInventedDelta() {
        XCTAssertNil(ClientProgressPresentation.delta([]))
        XCTAssertNil(ClientProgressPresentation.delta([entry(70, days: 0)]))
    }
    func testF06DeltaUsesPreviousNotOldest() {
        XCTAssertEqual(ClientProgressPresentation.delta([entry(80, days: -3), entry(75, days: -2), entry(74, days: -1)]), -1)
    }
    func testF07NearestReturnsRealRecord() {
        let values = [entry(70, days: -10), entry(72, days: 0)]
        XCTAssertEqual(ClientProgressPresentation.nearest(to: now.addingTimeInterval(-86_400), in: values)?.weightKg, 72)
        XCTAssertNil(ClientProgressPresentation.nearest(to: now, in: []))
    }
    func testF08StableDateAndIDOrder() {
        let a = entry(70, days: 0), b = entry(71, days: 0, id: "00000000-0000-0000-0000-000000000002")
        XCTAssertEqual(ClientProgressPresentation.weights([b, a], period: .all, now: now).map(\.id), [a.id, b.id])
    }
    func testF09TextOnAccentCoversGradientAndPressedEndpoints() {
        for scheme in [ColorScheme.light, .dark] {
            for background in [ClientColorRole.brandAccent, .brandAccentPressed] {
                XCTAssertGreaterThanOrEqual(ClientColorRole.textOnAccent.rgb(for: scheme).contrastRatio(with: background.rgb(for: scheme)), 4.5)
            }
        }
    }
    @MainActor func testF10AppearanceRelaunchAndSystemReset() throws {
        let name = "final-ui-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        for preference in ClientAppearance.allCases {
            ClientAppearanceStore(defaults: defaults).select(preference)
            XCTAssertEqual(ClientAppearanceStore(defaults: defaults).preference, preference)
        }
        ClientAppearanceStore(defaults: defaults).select(.system)
        XCTAssertNil(ClientAppearanceStore(defaults: defaults).preference.preferredColorScheme)
    }
    @MainActor func testF11LegacyAliasesResolveInBothTraits() {
        for (style, scheme) in [(UIUserInterfaceStyle.light, ColorScheme.light), (.dark, .dark)] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            XCTAssertEqual(UIColor(ClientClay.ink).resolvedColor(with: traits), UIColor(ClientClay.color(.textPrimary)).resolvedColor(with: traits))
            XCTAssertEqual(UIColor(ClientClay.canvas).resolvedColor(with: traits), UIColor(ClientColorRole.backgroundPrimary.color(for: scheme)))
        }
    }
    func testF12InformationTopicsAreDistinct() {
        XCTAssertEqual(ClientAccountInformationTopic.privacy.title, "Privacy")
        XCTAssertEqual(ClientAccountInformationTopic.support.title, "Supporto")
        XCTAssertEqual(ClientAccountInformationTopic.deletion.title, "Elimina account")
    }
}
