import Combine
import SwiftUI

enum ClientAppearance: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "Sistema"
        case .light: "Chiaro"
        case .dark: "Scuro"
        }
    }

    /// nil delegates to the presentation's system appearance, never a cached
    /// reading of UITraitCollection.current or a second platform override.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Device preference, deliberately independent of account/session/backend.
@MainActor
final class ClientAppearanceStore: ObservableObject {
    static let storageKey = "gymmanager.client.appearance"
    @Published private(set) var preference: ClientAppearance
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preference = defaults.string(forKey: Self.storageKey).flatMap(ClientAppearance.init(rawValue:)) ?? .system
    }

    func select(_ preference: ClientAppearance) {
        guard self.preference != preference else { return }
        self.preference = preference
        defaults.set(preference.rawValue, forKey: Self.storageKey)
    }
}

extension View {
    /// Apply once at an adopted presentation boundary. Legacy app screens remain
    /// dark until Phase6; do not attach this to individual rows or cards.
    func clientAppearance(_ preference: ClientAppearance) -> some View {
        preferredColorScheme(preference.preferredColorScheme)
    }
}
