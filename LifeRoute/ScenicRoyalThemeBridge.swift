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

    /// Functional copy is environmental, not decorative. Palette accent remains
    /// available for branding, scenery, and intentional emphasis.
    var contentPrimaryForeground: Color {
        isBrightEnvironment
            ? ScenicRoyalDesignSystem.ColorToken.contentDayPrimary
            : ScenicRoyalDesignSystem.ColorToken.contentNightPrimary
    }

    var contentSecondaryForeground: Color {
        isBrightEnvironment
            ? ScenicRoyalDesignSystem.ColorToken.contentDaySecondary
            : ScenicRoyalDesignSystem.ColorToken.contentNightSecondary
    }

    /// Native glass and native labels must resolve in the same appearance as
    /// environmental copy. A bright scene cannot use dark regular controls.
    var nativeColorScheme: ColorScheme { isBrightEnvironment ? .light : .dark }

    /// A functional tint is not a selected surface fill. Dark scenes retain
    /// their theme accent; bright scenes need the dark selection indicator.
    var nativeControlTint: Color {
        isBrightEnvironment ? selectedControlIndicator : palette.accent
    }

    /// Accessibility replaces transparency with a surface paired to our copy.
    /// The underlying scene palette and ordinary Clear-glass recipe stay intact.
    var accessibleSurfaceFill: Color {
        isBrightEnvironment ? .white : readabilityBase
    }

    /// Keep legacy night bar/picker fills exact; only bright controls adapt.
    var nativeBarFill: Color { isBrightEnvironment ? .white : palette.backgroundTop }
    var nativeSegmentedFill: Color { isBrightEnvironment ? .white : palette.panel }

    /// Legacy filled panels have their own palette foreground, independent of
    /// text placed directly over an environmental surface.
    var filledPanelForeground: Color { palette.textPrimary }

    /// The environment's compatibility palette shares functional text tokens.
    /// Artwork, grade, panel and accent values remain the selected raw palette.
    var contentPalette: LifeRouteThemePalette {
        LifeRouteThemePalette(
            backgroundTop: palette.backgroundTop, backgroundBottom: palette.backgroundBottom,
            panel: palette.panel, panelElevated: palette.panelElevated,
            accent: palette.accent, accentSecondary: palette.accentSecondary,
            textPrimary: contentPrimaryForeground, textSecondary: contentSecondaryForeground
        )
    }

    /// Selected controls retain a stable, internally paired day/night base.
    var selectedControlFill: Color {
        isBrightEnvironment
            ? ScenicRoyalDesignSystem.ColorToken.selectedControlDayFill
            : ScenicRoyalDesignSystem.ColorToken.selectedControlNightFill
    }

    var selectedControlForeground: Color {
        isBrightEnvironment
            ? ScenicRoyalDesignSystem.ColorToken.selectedControlDayForeground
            : ScenicRoyalDesignSystem.ColorToken.selectedControlNightForeground
    }

    var selectedControlIndicator: Color {
        isBrightEnvironment
            ? ScenicRoyalDesignSystem.ColorToken.selectedControlDayIndicator
            : ScenicRoyalDesignSystem.ColorToken.selectedControlNightIndicator
    }

    var accent: Color { palette.accent }
    var accentReflection: Color { palette.accentSecondary }
    /// Compatibility aliases keep existing shared Scenic Royal components on
    /// the semantic foreground contract while callers migrate by intent.
    var primaryText: Color { contentPrimaryForeground }
    var secondaryText: Color { contentSecondaryForeground }

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

    // Core Arctic renders a dark blue/teal gradient with bounded reflections.
    // Its snow-colored accent does not make its environment a bright scene.
    private var scenicRoyalIsBrightEnvironment: Bool {
        switch self {
        case .light, .sceneryMountainsDay, .sceneryOceanDay,
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
