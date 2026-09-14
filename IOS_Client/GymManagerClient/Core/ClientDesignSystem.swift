import SwiftUI

enum ClientClay {
    static let canvas = Color(red: 0.973, green: 0.965, blue: 0.941)
    static let canvasWarm = Color(red: 0.949, green: 0.922, blue: 0.874)
    static let surface = Color(red: 0.995, green: 0.988, blue: 0.969)
    static let surfaceDeep = Color(red: 0.941, green: 0.925, blue: 0.882)
    static let ink = Color(red: 0.141, green: 0.133, blue: 0.125)
    static let inkSoft = Color(red: 0.215, green: 0.196, blue: 0.181)
    static let secondaryInk = Color(red: 0.38, green: 0.36, blue: 0.34)
    static let accent = Color(red: 0.757, green: 0.231, blue: 0.161)
    static let accentSoft = Color(red: 0.98, green: 0.89, blue: 0.85)
    static let sage = Color(red: 0.220, green: 0.420, blue: 0.357)
    static let sageSoft = Color(red: 0.867, green: 0.922, blue: 0.878)
    static let gold = Color(red: 0.773, green: 0.553, blue: 0.216)
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
                            .stroke(
                                LinearGradient(colors: [.white.opacity(0.9), ClientClay.ink.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    }
            }
    }
}

struct ClientPremiumCardModifier: ViewModifier {
    var tint: Color = ClientClay.accent
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)
            .background {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [ClientClay.ink, ClientClay.inkSoft, tint.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Circle()
                        .fill(tint.opacity(0.42))
                        .frame(width: 150, height: 150)
                        .blur(radius: 8)
                        .offset(x: 52, y: -65)
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: ClientClay.ink.opacity(0.22), radius: 18, y: 12)
            }
    }
}

extension View {
    func clayCard(padding: CGFloat = 18) -> some View { modifier(ClayCardModifier(padding: padding)) }
    func premiumCard(tint: Color = ClientClay.accent, padding: CGFloat = 20) -> some View {
        modifier(ClientPremiumCardModifier(tint: tint, padding: padding))
    }
    func clientPage() -> some View {
        background {
            LinearGradient(
                colors: [ClientClay.canvas, ClientClay.canvasWarm.opacity(0.64), ClientClay.canvas],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
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
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
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
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct ClientSectionHeader: View {
    let title: String
    var detail: String?
    var symbol: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol).foregroundStyle(ClientClay.accent)
                }
                Text(title).font(.title3.weight(.bold)).foregroundStyle(ClientClay.ink)
            }
            Spacer()
            if let detail {
                Text(detail).font(.caption.weight(.semibold)).foregroundStyle(ClientClay.secondaryInk)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ClientMetricTile: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    var tint = ClientClay.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(ClientClay.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title).font(.caption.weight(.bold)).foregroundStyle(ClientClay.ink)
            Text(detail).font(.caption2).foregroundStyle(ClientClay.secondaryInk).lineLimit(2)
        }
        .clayCard(padding: 14)
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
