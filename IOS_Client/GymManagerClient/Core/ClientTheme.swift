import Foundation
import SwiftUI
import UIKit

/// One palette for the existing ClientClay system. Old names are pinned-dark
/// adapters; new/adopted components use ClientClay.color(.semanticRole).
enum ClientColorRole: String, CaseIterable, Sendable {
    case backgroundPrimary, backgroundSecondary
    case surfacePrimary, surfaceSecondary, surfaceElevated, surfaceInteractive
    case textPrimary, textEmphasis, textSecondary, textTertiary, textDisabled, textInverse, textOnAccent
    case borderSubtle, borderStrong, divider, shadow
    case brandAccent, brandAccentPressed, brandAccentSoft, brandAccentMuted
    case success, successMuted, warning, error, info
    case workoutAccent, runningAccent, nutritionAccent, progressAccent

    var palette: ClientColorPair {
        switch self {
        case .backgroundPrimary: return ClientColorPair(light: 0xF6F5F2, dark: 0x0B0B0D)
        case .backgroundSecondary: return ClientColorPair(light: 0xEEECE7, dark: 0x131214)
        case .surfacePrimary: return ClientColorPair(light: 0xFFFEFB, dark: 0x151517)
        case .surfaceSecondary: return ClientColorPair(light: 0xF0EEEA, dark: 0x1D1D20)
        case .surfaceElevated: return ClientColorPair(light: 0xFFFFFF, dark: 0x252427)
        case .surfaceInteractive: return ClientColorPair(light: 0xE8E5DF, dark: 0x0F0F11)
        case .textPrimary: return ClientColorPair(light: 0x1A191C, dark: 0xF4F4F6)
        case .textEmphasis: return ClientColorPair(light: 0x403D44, dark: 0xD4D4D8)
        case .textSecondary: return ClientColorPair(light: 0x58565B, dark: 0xA1A1AA)
        case .textTertiary: return ClientColorPair(light: 0x66636B, dark: 0x9999A3)
        case .textDisabled: return ClientColorPair(light: 0x969299, dark: 0x71717A)
        case .textInverse: return ClientColorPair(light: 0xFFFFFF, dark: 0xFFFFFF)
        case .textOnAccent: return ClientColorPair(light: 0xFFFFFF, dark: 0x0B0B0D)
        case .borderSubtle: return ClientColorPair(light: 0xD5D1CA, dark: 0x353438)
        case .borderStrong: return ClientColorPair(light: 0x716C77, dark: 0x99949F)
        case .divider: return ClientColorPair(light: 0xDEDAD4, dark: 0x353438)
        case .shadow: return ClientColorPair(light: 0x000000, dark: 0x000000)
        case .brandAccent: return ClientColorPair(light: 0xBE2E16, dark: 0xFF4F32)
        case .brandAccentPressed: return ClientColorPair(light: 0xA92616, dark: 0xFF3529)
        case .brandAccentSoft: return ClientColorPair(light: 0x9E301E, dark: 0xFFB09A)
        case .brandAccentMuted: return ClientColorPair(light: 0xFBE5DE, dark: 0x38201B)
        case .success: return ClientColorPair(light: 0x196C3E, dark: 0x30D158)
        case .successMuted: return ClientColorPair(light: 0xE0F1E4, dark: 0x153820)
        case .warning: return ClientColorPair(light: 0x805000, dark: 0xFF9F0A)
        case .error: return ClientColorPair(light: 0xB82030, dark: 0xFF737D)
        case .info: return ClientColorPair(light: 0x2858AB, dark: 0x68ADFF)
        case .workoutAccent: return ClientColorRole.brandAccent.palette
        case .runningAccent: return ClientColorPair(light: 0x075E77, dark: 0x1CC3EC)
        case .nutritionAccent: return ClientColorRole.success.palette
        case .progressAccent: return ClientColorPair(light: 0x6650AE, dark: 0xB29DFF)
        }
    }

    func rgb(for scheme: ColorScheme, increasedContrast: Bool = false) -> ClientRGB {
        if increasedContrast {
            switch self {
            case .textSecondary, .textTertiary: return ClientColorRole.textPrimary.rgb(for: scheme)
            case .borderSubtle, .divider: return ClientColorRole.borderStrong.rgb(for: scheme)
            default: break
            }
        }
        return ClientRGB(hex: scheme == .dark ? palette.dark : palette.light)
    }

    var adaptiveColor: Color {
        Color(uiColor: UIColor { traits in
            let rgb = self.rgb(for: traits.userInterfaceStyle == .dark ? .dark : .light,
                               increasedContrast: traits.accessibilityContrast == .high)
            return UIColor(red: CGFloat(rgb.red), green: CGFloat(rgb.green), blue: CGFloat(rgb.blue), alpha: 1)
        })
    }

    func color(for scheme: ColorScheme) -> Color {
        let rgb = rgb(for: scheme)
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

struct ClientColorPair: Equatable, Sendable {
    let light: UInt32
    let dark: UInt32
}

struct ClientRGB: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(hex: UInt32) {
        red = Double((hex >> 16) & 255) / 255
        green = Double((hex >> 8) & 255) / 255
        blue = Double(hex & 255) / 255
    }

    var luminance: Double {
        func linear(_ value: Double) -> Double { value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    func contrastRatio(with other: ClientRGB) -> Double {
        (max(luminance, other.luminance) + 0.05) / (min(luminance, other.luminance) + 0.05)
    }
}

extension ClientClay {
    static func color(_ role: ClientColorRole) -> Color { role.adaptiveColor }
    static let onDark = ClientColorRole.textInverse.color(for: .dark)
    static let shadow = ClientColorRole.shadow.color(for: .dark)
}
