import SwiftUI
import UIKit
import XCTest
@testable import GymManagerClient

final class ClientThemeFoundationTests: XCTestCase {
    func testSystemDelegatesAppearanceToOS() {
        XCTAssertNil(ClientAppearance.system.preferredColorScheme)
        XCTAssertEqual(ClientAppearance.light.preferredColorScheme, .light)
        XCTAssertEqual(ClientAppearance.dark.preferredColorScheme, .dark)
    }

    @MainActor
    func testPreferenceDefaultsToSystemAndPersistsLocally() throws {
        let suite = "client-appearance-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ClientAppearanceStore(defaults: defaults)
        XCTAssertEqual(store.preference, .system)
        store.select(.light)
        XCTAssertEqual(ClientAppearanceStore(defaults: defaults).preference, .light)
        store.select(.dark)
        XCTAssertEqual(ClientAppearanceStore(defaults: defaults).preference, .dark)
        store.select(.system)
        XCTAssertEqual(defaults.string(forKey: ClientAppearanceStore.storageKey), "system")
    }

    @MainActor
    func testInvalidStoredValueFallsBackToSystem() throws {
        let suite = "client-appearance-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("invalid-fixture", forKey: ClientAppearanceStore.storageKey)
        XCTAssertEqual(ClientAppearanceStore(defaults: defaults).preference, .system)
    }

    func testAllReadableTextRolesHaveContrastOnBaseSurfaces() {
        let text: [ClientColorRole] = [.textPrimary, .textEmphasis, .textSecondary, .textTertiary]
        let surfaces: [ClientColorRole] = [.backgroundPrimary, .backgroundSecondary, .surfacePrimary, .surfaceSecondary, .surfaceElevated, .surfaceInteractive]
        for scheme in [ColorScheme.light, .dark] {
            for foreground in text {
                for background in surfaces {
                    XCTAssertGreaterThanOrEqual(foreground.rgb(for: scheme).contrastRatio(with: background.rgb(for: scheme)), 4.5,
                                                "\(scheme) \(foreground) on \(background)")
                }
            }
        }
    }

    func testOnAccentAndErrorSemanticsAreNotBrandAliases() {
        XCTAssertNotEqual(ClientColorRole.error.palette, ClientColorRole.brandAccent.palette)
        for scheme in [ColorScheme.light, .dark] {
            XCTAssertGreaterThanOrEqual(ClientColorRole.textOnAccent.rgb(for: scheme)
                .contrastRatio(with: ClientColorRole.brandAccent.rgb(for: scheme)), 4.5)
        }
    }

    func testIncreasedContrastPromotesSecondaryTextAndBoundaries() {
        for scheme in [ColorScheme.light, .dark] {
            XCTAssertEqual(ClientColorRole.textSecondary.rgb(for: scheme, increasedContrast: true), ClientColorRole.textPrimary.rgb(for: scheme))
            XCTAssertEqual(ClientColorRole.divider.rgb(for: scheme, increasedContrast: true), ClientColorRole.borderStrong.rgb(for: scheme))
        }
    }

    @MainActor
    func testDynamicColorUsesSuppliedTraitsRatherThanCurrentScreen() {
        let uiColor = UIColor(ClientClay.color(.backgroundPrimary))
        for (style, scheme) in [(UIUserInterfaceStyle.light, ColorScheme.light), (.dark, .dark)] {
            let resolved = uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            let expected = ClientColorRole.backgroundPrimary.rgb(for: scheme)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            XCTAssertTrue(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            XCTAssertEqual(Double(red), expected.red, accuracy: 0.001)
            XCTAssertEqual(Double(green), expected.green, accuracy: 0.001)
            XCTAssertEqual(Double(blue), expected.blue, accuracy: 0.001)
        }
    }

    func testLegacySpacingAndRadiusArePreservedAndPreferredScaleIsRegular() {
        XCTAssertEqual(ClientSpacing.legacyCardInset, 18)
        XCTAssertEqual(ClientRadius.card, 22)
        XCTAssertEqual(ClientRadius.hero, 26)
        XCTAssertGreaterThanOrEqual(ClientControlSize.minimumTarget, 44)
        for spacing in [ClientSpacing.micro, ClientSpacing.related, ClientSpacing.control, ClientSpacing.page,
                        ClientSpacing.group, ClientSpacing.section, ClientSpacing.major, ClientSpacing.spacious] {
            XCTAssertEqual(spacing.truncatingRemainder(dividingBy: 4), 0)
        }
    }
}
