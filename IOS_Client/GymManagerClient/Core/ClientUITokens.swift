import SwiftUI

enum ClientSpacing {
    static let micro: CGFloat = 4
    static let related: CGFloat = 8
    static let control: CGFloat = 12
    static let page: CGFloat = 16
    static let group: CGFloat = 20
    static let section: CGFloat = 24
    static let major: CGFloat = 32
    static let spacious: CGFloat = 40
    // Compatibility exceptions, not new preferred spacing steps. Migrate only
    // when the owning screen is reviewed; no blanket numeric replacements.
    static let legacyCardInset: CGFloat = 18
}

enum ClientRadius {
    static let compact: CGFloat = 12
    static let control: CGFloat = 16
    static let card: CGFloat = 22
    static let hero: CGFloat = 26
}

enum ClientTypography {
    static let page = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let section = Font.title3.weight(.bold)
    static let body = Font.body
    static let supporting = Font.subheadline
    static let caption = Font.caption
    static let label = Font.caption.weight(.bold)
    static let metric = Font.system(.title2, design: .rounded, weight: .bold).monospacedDigit()
    static let button = Font.headline
}

enum ClientControlSize {
    static let minimumTarget: CGFloat = 44
    static let input: CGFloat = 48
    static let primaryButton: CGFloat = 50
}

enum ClientBorder {
    static let subtle: CGFloat = 1
    static let emphasized: CGFloat = 1.5
}

struct ClientElevation: Sendable {
    let opacity: Double
    let radius: CGFloat
    let y: CGFloat

    // Adopted adaptive surfaces use tonal separation in Dark, a subtle lift in
    // Light. Legacy profiles preserve existing screens until their own phase.
    static let lightSurface = ClientElevation(opacity: 0.08, radius: 8, y: 3)
    static let darkSurface = ClientElevation(opacity: 0, radius: 0, y: 0)
    static let legacyCard = ClientElevation(opacity: 0.34, radius: 16, y: 9)
    static let legacyHero = ClientElevation(opacity: 0.42, radius: 20, y: 12)
}
