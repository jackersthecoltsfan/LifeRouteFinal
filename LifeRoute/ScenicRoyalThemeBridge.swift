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
        switch family {
        case .canyon, .alpine, .rainforest, .royalCurrent:
            return glassTint
        case .scenery, .dynamic, .core:
            return palette.panel
        }
    }

    var environmentScrimOpacity: Double {
        isBrightEnvironment ? 0.10 : 0.045
    }

    var glassTintOpacity: Double {
        isBrightEnvironment ? 0.20 : 0.16
    }
}

extension LifeRouteTheme {
    /// Dynamic themes keep a scenic base in the shared root environment. The
    /// Dynamic renderer supplies mood and motion above this companion scene;
    /// it never replaces the scene or creates a per-screen background.
    var scenicRoyalDynamicSceneryTheme: LifeRouteTheme {
        switch self {
        case .royalCurrent, .midnightPrism, .obsidianSpectra:
            return .sceneryMountainsNight
        case .auroraBloom:
            return .sceneryArcticNight
        case .solarPulse:
            return .sceneryDesertNight
        case .emeraldFlow:
            return .sceneryRainforestNight
        case .oceanGlass:
            return .sceneryOceanNight
        case .plasmaOrchid:
            return .sceneryCanyonNight
        default:
            return .sceneryMountainsNight
        }
    }

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
