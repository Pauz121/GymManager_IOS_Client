import SwiftUI

enum ClientClay {
    static let canvas = Color(red: 0.043, green: 0.043, blue: 0.051)
    static let canvasWarm = Color(red: 0.075, green: 0.071, blue: 0.078)
    static let surface = Color(red: 0.082, green: 0.082, blue: 0.090)
    static let surfaceDeep = Color(red: 0.114, green: 0.114, blue: 0.125)
    static let surfaceElevated = Color(red: 0.145, green: 0.141, blue: 0.153)
    static let inset = Color(red: 0.059, green: 0.059, blue: 0.067)
    static let ink = Color(red: 0.957, green: 0.957, blue: 0.965)
    static let inkSoft = Color(red: 0.831, green: 0.831, blue: 0.847)
    static let secondaryInk = Color(red: 0.631, green: 0.631, blue: 0.667)
    static let tertiaryInk = Color(red: 0.443, green: 0.443, blue: 0.478)
    static let accent = Color(red: 1.000, green: 0.310, blue: 0.196)
    static let accentHot = Color(red: 1.000, green: 0.208, blue: 0.161)
    static let accentSoft = Color(red: 1.000, green: 0.690, blue: 0.604)
    static let sage = Color(red: 0.188, green: 0.820, blue: 0.345)
    static let sageSoft = Color(red: 0.082, green: 0.220, blue: 0.125)
    static let runAccent = Color(red: 0.110, green: 0.765, blue: 0.925)
    static let gold = Color(red: 1.000, green: 0.624, blue: 0.039)
    static let warning = Color(red: 1.000, green: 0.624, blue: 0.039)
    static let border = Color.white.opacity(0.08)
    static let radius: CGFloat = 22
    static let pagePadding: CGFloat = 16

    static let brandGradient = LinearGradient(
        colors: [accent, accentHot],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct ClayCardModifier: ViewModifier {
    var padding: CGFloat = 18
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: ClientClay.radius, style: .continuous)
                    .fill(LinearGradient(colors: [ClientClay.surfaceDeep, ClientClay.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .black.opacity(0.34), radius: 16, y: 9)
                    .overlay {
                        RoundedRectangle(cornerRadius: ClientClay.radius, style: .continuous)
                            .stroke(.white.opacity(contrast == .increased ? 0.22 : 0.08), lineWidth: contrast == .increased ? 1.5 : 1)
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
                                colors: [ClientClay.surfaceElevated, ClientClay.surface, tint.opacity(0.22)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Circle()
                        .fill(tint.opacity(0.20))
                        .frame(width: 150, height: 150)
                        .blur(radius: 18)
                        .offset(x: 52, y: -65)
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(0.42), radius: 20, y: 12)
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
            ZStack {
                LinearGradient(colors: [ClientClay.canvas, ClientClay.canvasWarm, ClientClay.canvas], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [ClientClay.accent.opacity(0.09), .clear], center: .topTrailing, startRadius: 10, endRadius: 360)
            }.ignoresSafeArea()
        }
    }

    func clientInputField() -> some View {
        padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(ClientClay.inset, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(ClientClay.border) }
            .foregroundStyle(ClientClay.ink)
    }
}

struct ClayPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(configuration.isPressed ? AnyShapeStyle(ClientClay.accent.opacity(0.76)) : AnyShapeStyle(ClientClay.brandGradient))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: ClientClay.accent.opacity(0.25), radius: 10, y: 5)
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
            .background(configuration.isPressed ? ClientClay.surface : ClientClay.surfaceDeep)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(ClientClay.border) }
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

struct ClientProgressSegmentBar: View {
    let completed: Int
    let total: Int
    var tint = ClientClay.sage

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<max(1, total), id: \.self) { index in
                Capsule()
                    .fill(index < completed && total > 0 ? tint : ClientClay.surfaceElevated)
                    .frame(maxWidth: .infinity, minHeight: 5, maxHeight: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progresso")
        .accessibilityValue(total > 0 ? "\(completed) di \(total)" : "Non disponibile")
    }
}

struct ClientDirectionalBadge: View {
    let text: String
    let direction: FloatingPointSign?

    var body: some View {
        Label(text, systemImage: direction == .plus ? "arrow.up.right" : direction == .minus ? "arrow.down.right" : "equal")
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(ClientClay.inkSoft)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(ClientClay.inset, in: Capsule())
            .overlay { Capsule().stroke(ClientClay.border) }
    }
}
