import SwiftUI

enum ClientClay {
    static let canvas = Color(red: 0.973, green: 0.965, blue: 0.941)
    static let surface = Color(red: 0.995, green: 0.988, blue: 0.969)
    static let surfaceDeep = Color(red: 0.941, green: 0.925, blue: 0.882)
    static let ink = Color(red: 0.141, green: 0.133, blue: 0.125)
    static let secondaryInk = Color(red: 0.38, green: 0.36, blue: 0.34)
    static let accent = Color(red: 0.757, green: 0.231, blue: 0.161)
    static let accentSoft = Color(red: 0.98, green: 0.89, blue: 0.85)
    static let sage = Color(red: 0.220, green: 0.420, blue: 0.357)
    static let warning = Color(red: 0.72, green: 0.47, blue: 0.15)
    static let radius: CGFloat = 22
}

struct ClayCardModifier: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: ClientClay.radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ClientClay.surface, ClientClay.surfaceDeep.opacity(0.58)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: ClientClay.ink.opacity(0.07), radius: 14, x: 7, y: 9)
                    .shadow(color: .white.opacity(0.82), radius: 9, x: -5, y: -6)
                    .overlay {
                        RoundedRectangle(cornerRadius: ClientClay.radius, style: .continuous)
                            .stroke(.white.opacity(0.62), lineWidth: 1)
                    }
            }
    }
}

extension View {
    func clayCard(padding: CGFloat = 18) -> some View { modifier(ClayCardModifier(padding: padding)) }
    func clientPage() -> some View { background(ClientClay.canvas.ignoresSafeArea()) }
}

struct ClayPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(configuration.isPressed ? ClientClay.accent.opacity(0.78) : ClientClay.accent)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: ClientClay.accent.opacity(0.22), radius: 9, y: 6)
    }
}

struct ClaySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(ClientClay.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(ClientClay.surfaceDeep.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.72)) }
    }
}

struct ClientPageTitle: View {
    let eyebrow: String
    let title: String
    let subtitle: String?

    init(_ title: String, eyebrow: String, subtitle: String? = nil) {
        self.title = title
        self.eyebrow = eyebrow
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow.uppercased()).font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(ClientClay.accent)
            Text(title).font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(ClientClay.ink)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(ClientClay.secondaryInk) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct ClientBadge: View {
    let text: String
    var tint = ClientClay.sage
    var symbol: String?

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(tint.opacity(0.11), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct ReadOnlyPlanBadge: View {
    var body: some View { ClientBadge(text: "Piano del Trainer · sola lettura", tint: ClientClay.sage, symbol: "lock.fill") }
}

struct ClientEmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(.title, design: .rounded, weight: .medium)).foregroundStyle(ClientClay.accent)
            Text(title).font(.title3.weight(.semibold)).multilineTextAlignment(.center)
            Text(message).font(.subheadline).foregroundStyle(ClientClay.secondaryInk).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).clayCard()
    }
}

struct ClientFailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Connessione non disponibile", systemImage: "wifi.exclamationmark")
        } description: { Text(message) } actions: {
            Button("Riprova", action: retry).buttonStyle(.borderedProminent).tint(ClientClay.accent)
        }
    }
}
