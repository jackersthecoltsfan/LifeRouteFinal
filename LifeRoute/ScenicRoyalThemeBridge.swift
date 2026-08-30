import SwiftUI

enum ScenicRoyalEnvironmentFamily {
    case royalCurrent
    case canyon
    case alpine
    case rainforest
    case scenery
    case dynamic
    case core
}

struct ScenicRoyalThemeStyle {
    let family: ScenicRoyalEnvironmentFamily
    let palette: LifeRouteThemePalette
    let isBrightEnvironment: Bool

    var accent: Color { palette.accent }
    var accentReflection: Color { palette.accentSecondary }
    var primaryText: Color { palette.textPrimary }
    var secondaryText: Color { palette.textSecondary }

    var glassTint: Color {
        switch family {
        case .canyon:
            return Color(red: 0.30, green: 0.16, blue: 0.12)
        case .alpine:
            return Color(red: 0.08, green: 0.29, blue: 0.42)
        case .rainforest:
            return Color(red: 0.03, green: 0.23, blue: 0.16)
        case .royalCurrent:
            return ScenicRoyalDesignSystem.ColorToken.brandNavy
        case .scenery, .dynamic, .core:
            return palette.panelElevated
        }
    }

    var readabilityBase: Color {
        isBrightEnvironment ? ScenicRoyalDesignSystem.ColorToken.brandNavyDeep : palette.panel
    }

    var environmentScrimOpacity: Double {
        isBrightEnvironment ? 0.17 : 0.08
    }

    var glassTintOpacity: Double {
        isBrightEnvironment ? 0.22 : 0.16
    }
}

extension LifeRouteTheme {
    var scenicRoyalStyle: ScenicRoyalThemeStyle {
        ScenicRoyalThemeStyle(
            family: scenicRoyalEnvironmentFamily,
            palette: palette,
            isBrightEnvironment: scenicRoyalIsBrightEnvironment
        )
    }

    private var scenicRoyalEnvironmentFamily: ScenicRoyalEnvironmentFamily {
        switch self {
        case .royalCurrent:
            return .royalCurrent
        case .sceneryCanyonDay, .sceneryCanyonNight:
            return .canyon
        case .sceneryArcticDay, .sceneryArcticNight, .sceneryAlpineDay, .sceneryAlpineNight:
            return .alpine
        case .sceneryRainforestDay, .sceneryRainforestNight:
            return .rainforest
        default:
            if isPhaseThreeScenery { return .scenery }
            if isPhaseTwoDynamic { return .dynamic }
            return .core
        }
    }

    private var scenicRoyalIsBrightEnvironment: Bool {
        switch self {
        case .light, .arctic, .sceneryMountainsDay, .sceneryOceanDay,
             .sceneryDesertDay, .sceneryAlpineDay, .sceneryRainforestDay,
             .sceneryGrasslandDay, .sceneryCanyonDay, .sceneryArcticDay,
             .sceneryCoastalCliffsDay:
            return true
        default:
            return false
        }
    }
}

private struct ScenicRoyalThemeStyleKey: EnvironmentKey {
    static let defaultValue = LifeRouteTheme.royal.scenicRoyalStyle
}

extension EnvironmentValues {
    var scenicRoyalThemeStyle: ScenicRoyalThemeStyle {
        get { self[ScenicRoyalThemeStyleKey.self] }
        set { self[ScenicRoyalThemeStyleKey.self] = newValue }
    }
}
