import SwiftUI

enum ClientClay {
    // Phase7: legacy API names now use the same adaptive semantic palette.
    // Asset and domain colors remain separate from UI surfaces.
    static let canvas = ClientColorRole.backgroundPrimary.adaptiveColor
    static let canvasWarm = ClientColorRole.backgroundSecondary.adaptiveColor
    static let surface = ClientColorRole.surfacePrimary.adaptiveColor
    static let surfaceDeep = ClientColorRole.surfaceSecondary.adaptiveColor
    static let surfaceElevated = ClientColorRole.surfaceElevated.adaptiveColor
    static let inset = ClientColorRole.surfaceInteractive.adaptiveColor
    static let ink = ClientColorRole.textPrimary.adaptiveColor
    static let inkSoft = ClientColorRole.textEmphasis.adaptiveColor
    static let secondaryInk = ClientColorRole.textSecondary.adaptiveColor
    static let tertiaryInk = ClientColorRole.textTertiary.adaptiveColor
    static let accent = ClientColorRole.brandAccent.adaptiveColor
    static let accentHot = ClientColorRole.brandAccentPressed.adaptiveColor
    static let accentSoft = ClientColorRole.brandAccentSoft.adaptiveColor
    static let sage = ClientColorRole.success.adaptiveColor
    static let sageSoft = ClientColorRole.successMuted.adaptiveColor
    static let runAccent = ClientColorRole.runningAccent.adaptiveColor
    static let gold = ClientColorRole.warning.adaptiveColor
    static let warning = ClientColorRole.warning.adaptiveColor
    static let border = ClientColorRole.borderSubtle.adaptiveColor
    static let radius = ClientRadius.card
    static let pagePadding = ClientSpacing.page

    static let brandGradient = LinearGradient(
        colors: [accent, accentHot],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum ClientSurfaceAppearance: Equatable { case legacyDark, adaptive }

struct ClayCardModifier: ViewModifier {
    var padding: CGFloat = ClientSpacing.legacyCardInset
    var appearance: ClientSurfaceAppearance = .adaptive
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme

    private func color(_ role: ClientColorRole) -> Color {
        appearance == .adaptive ? ClientClay.color(role) : role.color(for: .dark)
    }

    func body(content: Content) -> some View {
        let elevation = appearance == .legacyDark ? ClientElevation.legacyCard
            : colorScheme == .dark ? ClientElevation.darkSurface : ClientElevation.lightSurface
        return content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: ClientClay.radius, style: .continuous)
                    .fill(LinearGradient(colors: [color(.surfaceSecondary), color(.surfacePrimary)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: ClientClay.shadow.opacity(elevation.opacity), radius: elevation.radius, y: elevation.y)
                    .overlay {
                        RoundedRectangle(cornerRadius: ClientClay.radius, style: .continuous)
                            .stroke(appearance == .adaptive ? ClientClay.color(contrast == .increased ? .borderStrong : .borderSubtle)
                                    : ClientClay.onDark.opacity(contrast == .increased ? 0.22 : 0.08),
                                    lineWidth: contrast == .increased ? ClientBorder.emphasized : ClientBorder.subtle)
                    }
            }
    }
}

struct ClientPremiumCardModifier: ViewModifier {
    var tint: Color = ClientClay.accent
    var padding: CGFloat = ClientSpacing.group

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(ClientClay.ink)
            .background {
                ClientPremiumCardSurface(tint: tint)
            }
    }
}

/// Only the base shape participates in background layout. The decorative circle
/// is an overlay: its fixed size cannot enlarge the background beyond the card.
struct ClientPremiumCardSurface: View {
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: ClientRadius.hero, style: .continuous)
            .fill(LinearGradient(colors: [ClientClay.surfaceElevated, ClientClay.surface, tint.opacity(colorScheme == .dark ? 0.22 : 0.07)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(alignment: .topTrailing) {
                Circle().fill(tint.opacity(colorScheme == .dark ? 0.20 : 0.06))
                    .frame(width: 150, height: 150)
                    .blur(radius: 18).offset(x: 52, y: -65)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: ClientRadius.hero, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: ClientRadius.hero, style: .continuous).stroke(ClientClay.border, lineWidth: ClientBorder.subtle) }
            .shadow(color: ClientClay.shadow.opacity(colorScheme == .dark ? ClientElevation.darkSurface.opacity : ClientElevation.lightSurface.opacity), radius: ClientElevation.lightSurface.radius, y: ClientElevation.lightSurface.y)
            .accessibilityHidden(true)
    }
}

extension View {
    func clayCard(padding: CGFloat = ClientSpacing.legacyCardInset, appearance: ClientSurfaceAppearance = .adaptive) -> some View {
        modifier(ClayCardModifier(padding: padding, appearance: appearance))
    }
    func premiumCard(tint: Color = ClientClay.accent, padding: CGFloat = ClientSpacing.group) -> some View {
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
        padding(.horizontal, ClientSpacing.control)
            .frame(minHeight: ClientControlSize.input)
            .background(ClientClay.inset, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(ClientClay.border) }
            .foregroundStyle(ClientClay.ink)
    }
}

struct ClayPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ClientTypography.button)
            .foregroundStyle(ClientClay.color(.textOnAccent))
            .frame(maxWidth: .infinity, minHeight: ClientControlSize.primaryButton)
            .background(configuration.isPressed ? AnyShapeStyle(ClientClay.accentHot) : AnyShapeStyle(ClientClay.brandGradient))
            .clipShape(RoundedRectangle(cornerRadius: ClientRadius.control, style: .continuous))
            .shadow(color: ClientClay.accent.opacity(0.25), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct ClaySecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ClientTypography.button)
            .foregroundStyle(ClientClay.ink)
            .frame(maxWidth: .infinity, minHeight: ClientControlSize.input)
            .background(configuration.isPressed ? ClientClay.surface : ClientClay.surfaceDeep)
            .clipShape(RoundedRectangle(cornerRadius: ClientRadius.control, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: ClientRadius.control).stroke(ClientClay.border) }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
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
                Text(title).font(ClientTypography.section).foregroundStyle(ClientClay.ink)
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
            Text(title).font(ClientTypography.page).foregroundStyle(ClientClay.ink)
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
                .foregroundStyle(ClientClay.color(.textOnAccent))
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
