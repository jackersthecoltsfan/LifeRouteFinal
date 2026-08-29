import SwiftUI
import UIKit

private extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: opacity
        )
    }
}

enum LifeRouteThemeCategory: String, CaseIterable, Identifiable {
    case core = "Core"
    case metallic = "Metallic"
    case scenery = "Scenery"
    case dynamic = "Dynamic"
    case fluid = "Fluid"
    var id: String { rawValue }
}

struct LifeRouteThemePalette {
    let backgroundTop: Color
    let backgroundBottom: Color
    let panel: Color
    let panelElevated: Color
    let accent: Color
    let accentSecondary: Color
    let textPrimary: Color
    let textSecondary: Color

    var backgroundGradient: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var panelGradient: LinearGradient {
        LinearGradient(colors: [panelElevated.opacity(0.88), panel.opacity(0.76)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var accentGradient: LinearGradient {
        LinearGradient(colors: [accentSecondary, accent], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private func makeThemePalette(
    _ bgA: UInt,
    _ bgB: UInt,
    _ panel: UInt,
    _ elevated: UInt,
    _ accent: UInt,
    _ accent2: UInt,
    textPrimary: Color = .white,
    textSecondary: Color = .white.opacity(0.70)
) -> LifeRouteThemePalette {
    .init(
        backgroundTop: Color(hex: bgA),
        backgroundBottom: Color(hex: bgB),
        panel: Color(hex: panel),
        panelElevated: Color(hex: elevated),
        accent: Color(hex: accent),
        accentSecondary: Color(hex: accent2),
        textPrimary: textPrimary,
        textSecondary: textSecondary
    )
}

enum LifeRouteTheme: String, CaseIterable, Identifiable {
    case royal, obsidian, carbon, midnight, navyNoir
    case titanium, slate, moltenGold, phantomSilver
    case ocean, aurora, forest, plum, ember
    case solarFlare, electricStorm, ultraviolet, arcticPulse
    case sapphireTide
    case mountain, space, desert, sunshine
    case sunflare, noir, golden, cobaltShine, light, dark, kaleidoscope, classic, accessible
    // v0.7.0 Theme Phase 1 Core Glass catalog uses stable identifiers that cannot collide
    // with the retained legacy Dynamic/Scenery identifiers.
    case coreOcean = "core.ocean"
    case coreAurora = "core.aurora"
    case coreSolarFlare = "core.solarFlare"
    case coreUltraviolet = "core.ultraviolet"
    case emerald = "core.emerald"
    case roseQuartz = "core.roseQuartz"
    case arctic = "core.arctic"
    case coreEmber = "core.ember"

    // v0.7.0 Theme Phase 2 Dynamic Liquid Glass catalog uses stable identifiers.
    case royalCurrent = "dynamic.royalCurrent"
    case midnightPrism = "dynamic.midnightPrism"
    case auroraBloom = "dynamic.auroraBloom"
    case solarPulse = "dynamic.solarPulse"
    case emeraldFlow = "dynamic.emeraldFlow"
    case arcticHalo = "dynamic.arcticHalo"
    case oceanGlass = "dynamic.oceanGlass"
    case roseEmber = "dynamic.roseEmber"
    case obsidianSpectra = "dynamic.obsidianSpectra"
    case plasmaOrchid = "dynamic.plasmaOrchid"
    case verdantMist = "dynamic.verdantMist"
    case titaniumGlow = "dynamic.titaniumGlow"

    var id: String { rawValue }

    // v0.7.0 Theme Phase 1 Core Glass catalog: exactly the 12 approved still environments.
    static let phaseOneCoreGlassCatalog: [LifeRouteTheme] = [
        .royal, .obsidian, .midnight, .titanium,
        .coreOcean, .coreAurora, .coreSolarFlare, .coreUltraviolet,
        .emerald, .roseQuartz, .arctic, .coreEmber,
    ]

    var isPhaseOneCoreGlass: Bool {
        Self.phaseOneCoreGlassCatalog.contains(self)
    }

    // v0.7.0 Theme Phase 2 Dynamic Liquid Glass catalog: exactly 12 approved live environments.
    static let phaseTwoDynamicCatalog: [LifeRouteTheme] = [
        .royalCurrent, .midnightPrism, .auroraBloom, .solarPulse,
        .emeraldFlow, .arcticHalo, .oceanGlass, .roseEmber,
        .obsidianSpectra, .plasmaOrchid, .verdantMist, .titaniumGlow,
    ]

    var isPhaseTwoDynamic: Bool {
        Self.phaseTwoDynamicCatalog.contains(self)
    }

    var name: String {
        switch self {
        case .royal: return "Royal"
        case .obsidian: return "Obsidian"
        case .carbon: return "Carbon"
        case .midnight: return "Midnight"
        case .navyNoir: return "Navy Noir"
        case .titanium: return "Titanium"
        case .slate: return "Slate"
        case .moltenGold: return "Molten Gold"
        case .phantomSilver: return "Phantom Silver"
        case .ocean: return "Ocean"
        case .aurora: return "Aurora"
        case .forest: return "Forest"
        case .plum: return "Plum"
        case .ember: return "Ember"
        case .solarFlare: return "Solar Flare"
        case .electricStorm: return "Electric Storm"
        case .ultraviolet: return "Ultraviolet"
        case .arcticPulse: return "Arctic Pulse"
        case .sapphireTide: return "Sapphire Tide"
        case .mountain: return "Mountain"
        case .space: return "Space"
        case .desert: return "Desert"
        case .sunshine: return "Sunshine"
        case .sunflare: return "Sunflare"
        case .noir: return "Noir"
        case .golden: return "Golden"
        case .cobaltShine: return "Cobalt Shine"
        case .light: return "Light"
        case .dark: return "Dark"
        case .kaleidoscope: return "Kaleidoscope"
        case .classic: return "Classic"
        case .accessible: return "Accessible"
        case .coreOcean: return "Ocean"
        case .coreAurora: return "Aurora"
        case .coreSolarFlare: return "Solar Flare"
        case .coreUltraviolet: return "Ultraviolet"
        case .emerald: return "Emerald"
        case .roseQuartz: return "Rose Quartz"
        case .arctic: return "Arctic"
        case .coreEmber: return "Ember"
        case .royalCurrent: return "Royal Current"
        case .midnightPrism: return "Midnight Prism"
        case .auroraBloom: return "Aurora Bloom"
        case .solarPulse: return "Solar Pulse"
        case .emeraldFlow: return "Emerald Flow"
        case .arcticHalo: return "Arctic Halo"
        case .oceanGlass: return "Ocean Glass"
        case .roseEmber: return "Rose Ember"
        case .obsidianSpectra: return "Obsidian Spectra"
        case .plasmaOrchid: return "Plasma Orchid"
        case .verdantMist: return "Verdant Mist"
        case .titaniumGlow: return "Titanium Glow"
        }
    }

    var category: LifeRouteThemeCategory {
        switch self {
        case .royal, .obsidian, .carbon, .midnight, .navyNoir, .sunflare, .noir, .golden, .cobaltShine, .light, .dark, .kaleidoscope, .classic, .accessible, .coreOcean, .coreAurora, .coreSolarFlare, .coreUltraviolet, .emerald, .roseQuartz, .arctic, .coreEmber: return .core
        case .titanium, .slate, .moltenGold, .phantomSilver: return .metallic
        case .ocean, .forest, .plum, .ember, .mountain, .space, .desert, .sunshine: return .scenery
        // v0.7.0 Theme Phase 2 category compatibility
        case .solarFlare, .electricStorm, .ultraviolet, .arcticPulse, .royalCurrent, .midnightPrism, .auroraBloom, .solarPulse, .emeraldFlow, .arcticHalo, .oceanGlass, .roseEmber, .obsidianSpectra, .plasmaOrchid, .verdantMist, .titaniumGlow: return .dynamic
        case .aurora, .sapphireTide: return .dynamic
        }
    }

    var symbol: String {
        switch category {
        case .core: return "sparkles"
        case .metallic: return "hexagon.fill"
        case .scenery: return "mountain.2.fill"
        case .dynamic: return "bolt.fill"
        case .fluid: return "drop.fill"
        }
    }

    var artworkSymbols: (primary: String, secondary: String) {
        switch self {
        case .royal: return ("crown.fill", "shield.fill")
        case .obsidian: return ("diamond.fill", "circle.hexagongrid.fill")
        case .carbon: return ("square.grid.3x3.fill", "square.stack.3d.up.fill")
        case .midnight: return ("moon.stars.fill", "sparkles")
        case .navyNoir: return ("moon.fill", "building.columns.fill")
        case .titanium: return ("gearshape.2.fill", "hexagon.fill")
        case .slate: return ("square.stack.3d.up.fill", "rectangle.3.group.fill")
        case .moltenGold: return ("flame.fill", "sun.max.fill")
        case .phantomSilver: return ("moon.circle.fill", "sparkles")
        case .ocean: return ("water.waves", "sailboat.fill")
        case .aurora: return ("wand.and.stars", "wave.3.right")
        case .forest: return ("tree.fill", "leaf.fill")
        case .plum: return ("camera.macro", "sparkles")
        case .ember: return ("flame.fill", "smoke.fill")
        case .solarFlare: return ("sun.max.fill", "sparkles")
        case .electricStorm: return ("cloud.bolt.rain.fill", "bolt.fill")
        case .ultraviolet: return ("atom", "sparkles")
        case .arcticPulse: return ("snowflake", "wave.3.right")
        case .sapphireTide: return ("drop.fill", "water.waves")
        case .mountain: return ("mountain.2.fill", "sun.horizon.fill")
        case .space: return ("sparkles", "moon.stars.fill")
        case .desert: return ("sun.max.fill", "wind")
        case .sunshine: return ("sun.max.fill", "sun.horizon.fill")
        case .sunflare: return ("sun.max.fill", "flame.fill")
        case .noir: return ("circle.hexagongrid.fill", "diamond.fill")
        case .golden: return ("seal.fill", "sun.max.fill")
        case .cobaltShine: return ("diamond.fill", "drop.fill")
        case .light: return ("cloud.sun.fill", "sparkles")
        case .dark: return ("moon.fill", "circle.grid.cross.fill")
        case .kaleidoscope: return ("camera.filters", "sparkles")
        case .classic: return ("circle.lefthalf.filled", "square.fill")
        case .accessible: return ("accessibility", "circle.fill")
        case .coreOcean: return ("water.waves", "drop.fill")
        case .coreAurora: return ("wand.and.stars", "sparkles")
        case .coreSolarFlare: return ("sun.max.fill", "flame.fill")
        case .coreUltraviolet: return ("circle.hexagongrid.fill", "sparkles")
        case .emerald: return ("leaf.fill", "diamond.fill")
        case .roseQuartz: return ("diamond.fill", "sparkles")
        case .arctic: return ("snowflake", "circle.fill")
        case .coreEmber: return ("flame.fill", "circle.fill")
        case .royalCurrent: return ("crown.fill", "water.waves")
        case .midnightPrism: return ("moon.stars.fill", "triangle.fill")
        case .auroraBloom: return ("wand.and.stars", "camera.macro")
        case .solarPulse: return ("sun.max.fill", "waveform.path.ecg")
        case .emeraldFlow: return ("leaf.fill", "water.waves")
        case .arcticHalo: return ("snowflake", "circle.dotted")
        case .oceanGlass: return ("drop.fill", "water.waves")
        case .roseEmber: return ("flame.fill", "sparkles")
        case .obsidianSpectra: return ("diamond.fill", "sparkles")
        case .plasmaOrchid: return ("atom", "camera.macro")
        case .verdantMist: return ("leaf.fill", "cloud.fog.fill")
        case .titaniumGlow: return ("hexagon.fill", "sparkles")
        }
    }

    var palette: LifeRouteThemePalette {
        switch self {
        case .royal: return makeThemePalette(0x071329, 0x05284f, 0x0d2038, 0x143f68, 0xedb847, 0xfbdc80)
        case .obsidian: return makeThemePalette(0x07080a, 0x17120b, 0x111116, 0x242019, 0xd69d38, 0xffdfa0)
        case .carbon: return makeThemePalette(0x0e1114, 0x1c2228, 0x1a2026, 0x343d46, 0xb8c6d4, 0xe9f0f7)
        case .midnight: return makeThemePalette(0x050817, 0x071f46, 0x0d1730, 0x153964, 0x4e9eff, 0x99c8ff)
        case .navyNoir: return makeThemePalette(0x04101d, 0x08293d, 0x091d2c, 0x103b54, 0xd4a547, 0x63b0ff)
        case .titanium: return makeThemePalette(0x171c21, 0x2d3842, 0x292f36, 0x4a555f, 0xb4d1ef, 0xebf3fb)
        case .slate: return makeThemePalette(0x10171f, 0x263440, 0x1b2530, 0x384859, 0x96b2cc, 0xd2e0ee)
        case .moltenGold: return makeThemePalette(0x1f1002, 0x4c2503, 0x2e1906, 0x573008, 0xffbd19, 0xffe86b)
        case .phantomSilver: return makeThemePalette(0x101419, 0x242e38, 0x1a2028, 0x3c4a57, 0xc1d5e7, 0xf2f9ff)
        case .ocean: return makeThemePalette(0x031a29, 0x00465c, 0x052d3d, 0x085162, 0x35d8ef, 0x72f5df)
        case .aurora: return makeThemePalette(0x051a21, 0x162d49, 0x0a252d, 0x164c4b, 0x54f2d1, 0x7e8cff)
        case .forest: return makeThemePalette(0x061a12, 0x123821, 0x0b2519, 0x16442d, 0x79d889, 0xbfe66b)
        case .plum: return makeThemePalette(0x18081f, 0x41114d, 0x27102f, 0x511c5f, 0xe060eb, 0xff9bc7)
        case .ember: return makeThemePalette(0x211006, 0x4c1908, 0x301209, 0x5b210f, 0xff7a40, 0xffc54d)
        case .solarFlare: return makeThemePalette(0x29060a, 0x5c1405, 0x35100c, 0x6b1f0b, 0xff4f2b, 0xffc23d)
        case .electricStorm: return makeThemePalette(0x05071f, 0x220a48, 0x111235, 0x2a195b, 0x00dcff, 0x7f46ff)
        case .ultraviolet: return makeThemePalette(0x15052b, 0x430d52, 0x241037, 0x531c65, 0xb73dff, 0xff66ba)
        case .arcticPulse: return makeThemePalette(0x06172a, 0x123050, 0x0c253c, 0x1f455f, 0x5ce7e5, 0x91adff)
        case .sapphireTide: return makeThemePalette(0x00142a, 0x00506b, 0x00283f, 0x055163, 0x0782ff, 0x59f0d2)
        case .mountain: return makeThemePalette(0x041326, 0x0a2340, 0x0a1b2d, 0x183b58, 0xe6a642, 0xffd77a)
        case .space: return makeThemePalette(0x03050f, 0x101438, 0x0b1025, 0x202b55, 0x8aa7ff, 0xe0d2ff)
        case .desert: return makeThemePalette(0x261207, 0x5a2d0e, 0x32190a, 0x68401b, 0xe9a94d, 0xffdc8f)
        case .sunshine: return makeThemePalette(0x10243b, 0x3b6a79, 0x173149, 0x426678, 0xffc44f, 0xffef9a)
        case .sunflare: return makeThemePalette(0x251008, 0x733017, 0x431a0d, 0x88401e, 0xc8602f, 0xf1a45d)
        case .noir: return makeThemePalette(0x040506, 0x181b1f, 0x0b0d0f, 0x2d3238, 0x929aa2, 0xedf1f4)
        case .golden: return makeThemePalette(0x1c1103, 0x4b3009, 0x2d1c05, 0x694613, 0xb87a25, 0xf4d36d)
        case .cobaltShine: return makeThemePalette(0x020d2b, 0x073d89, 0x061d4e, 0x0d5db7, 0x2d8cff, 0x83c8ff)
        case .light: return makeThemePalette(
            0xf7eaf2, 0xeaf4ff, 0xf5f0ff, 0xeef9f2, 0xb9a7e8, 0xf3c7d9,
            textPrimary: Color(hex: 0x18222c),
            textSecondary: Color(hex: 0x344451).opacity(0.82)
        )
        case .dark: return makeThemePalette(0x040609, 0x11161d, 0x0a0e13, 0x1b232c, 0x526778, 0x718596)
        case .kaleidoscope: return makeThemePalette(0x25104f, 0x082f6f, 0x321267, 0x0d5d88, 0xffd43b, 0xff4fab)
        case .classic: return makeThemePalette(0x000000, 0x1a1a1a, 0x101010, 0x343434, 0xbfbfbf, 0xffffff)
        case .accessible: return makeThemePalette(0x000000, 0x000000, 0x000000, 0x000000, 0xffffff, 0xffffff, textPrimary: .white, textSecondary: .white)
        case .coreOcean: return makeThemePalette(0x031923, 0x063e4e, 0x0a2b35, 0x115060, 0x34d1dc, 0x88f4e6)
        case .coreAurora: return makeThemePalette(0x120824, 0x35105b, 0x24103d, 0x4f1d75, 0xae5cff, 0xff78d1)
        case .coreSolarFlare: return makeThemePalette(0x2a0b05, 0x64170a, 0x3a120a, 0x78260d, 0xff7a2f, 0xffd060)
        case .coreUltraviolet: return makeThemePalette(0x0e0727, 0x271056, 0x1b103e, 0x3b1b70, 0x8d5bff, 0x4cc8ff)
        case .emerald: return makeThemePalette(0x041a15, 0x0c3b31, 0x082a22, 0x135246, 0x2ed3a6, 0x7cf4d2)
        case .roseQuartz: return makeThemePalette(0x251016, 0x4a1f31, 0x351824, 0x66314a, 0xe88aa6, 0xffc5d2)
        case .arctic: return makeThemePalette(0x071923, 0x173847, 0x102934, 0x245263, 0x8ee8ff, 0xe2f8ff)
        case .coreEmber: return makeThemePalette(0x240807, 0x57120d, 0x35100d, 0x6e1c13, 0xff4d32, 0xffa05d)
        case .royalCurrent: return makeThemePalette(0x03122b, 0x073f69, 0x0a2745, 0x13547a, 0xe7b64d, 0x61d9ff)
        case .midnightPrism: return makeThemePalette(0x040616, 0x1b1648, 0x101631, 0x302866, 0x657cff, 0x65efff)
        case .auroraBloom: return makeThemePalette(0x100620, 0x233d3a, 0x201334, 0x345c53, 0xc16cff, 0x66f0bd)
        case .solarPulse: return makeThemePalette(0x2b0804, 0x6c1d08, 0x3b1208, 0x793316, 0xff633d, 0xffd258)
        case .emeraldFlow: return makeThemePalette(0x031912, 0x075044, 0x0a2b23, 0x146255, 0x25d69f, 0x9af7cf)
        case .arcticHalo: return makeThemePalette(0x041826, 0x16425c, 0x0d2c3d, 0x285f75, 0x8eeaff, 0xe2faff)
        case .oceanGlass: return makeThemePalette(0x001827, 0x00566c, 0x062e42, 0x0d6274, 0x2bcde2, 0x72f5d9)
        case .roseEmber: return makeThemePalette(0x250810, 0x65192f, 0x3a1322, 0x793247, 0xff6688, 0xffbd77)
        case .obsidianSpectra: return makeThemePalette(0x030407, 0x17102b, 0x101018, 0x2a2140, 0x9a76ff, 0x65e7ff)
        case .plasmaOrchid: return makeThemePalette(0x130421, 0x50115f, 0x291037, 0x63216f, 0xcd55ff, 0xff70c4)
        case .verdantMist: return makeThemePalette(0x04150e, 0x183b2d, 0x0e281d, 0x315648, 0x62d69d, 0xc4f2b1)
        case .titaniumGlow: return makeThemePalette(0x111820, 0x2d3c4c, 0x222d37, 0x465b6c, 0x9ac9f4, 0xe9f5ff)
        }
    }
}

final class LifeRouteThemeStore: ObservableObject {
    // v0.7.0 Theme Phase 1 persistence: one owner, stable identifiers, deterministic legacy migration.
    private static let storageKey = "liferoute.selectedTheme"

    @Published var selectedTheme: LifeRouteTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.storageKey)
            LifeRouteAppearance.configure(theme: selectedTheme)
        }
    }

    init() {
        let savedIdentifier = UserDefaults.standard.string(forKey: Self.storageKey)
        let theme = Self.resolveStoredTheme(savedIdentifier)
        selectedTheme = theme
        if savedIdentifier != theme.rawValue {
            UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey)
        }
        LifeRouteAppearance.configure(theme: theme)
    }

    var palette: LifeRouteThemePalette { selectedTheme.palette }

    private static func resolveStoredTheme(_ identifier: String?) -> LifeRouteTheme {
        guard let identifier else { return .royal }

        // Retired Core/Metallic choices migrate to the closest approved Phase 1 still identity.
        // Existing Dynamic/Scenery identifiers remain valid and unchanged until their own phases.
        switch identifier {
        case "carbon", "noir", "dark", "accessible":
            return .obsidian
        case "navyNoir", "cobaltShine":
            return .midnight
        case "slate", "phantomSilver", "classic":
            return .titanium
        case "moltenGold", "golden", "sunflare":
            return .coreSolarFlare
        case "kaleidoscope":
            return .coreAurora
        case "light":
            return .arctic
        // Retired pre-Phase-2 Dynamic identifiers migrate deterministically to the nearest live identity.
        case "solarFlare":
            return .solarPulse
        case "electricStorm":
            return .midnightPrism
        case "ultraviolet":
            return .plasmaOrchid
        case "arcticPulse":
            return .arcticHalo
        case "aurora":
            return .auroraBloom
        case "sapphireTide":
            return .oceanGlass
        default:
            return LifeRouteTheme(rawValue: identifier) ?? .royal
        }
    }
}

private struct LifeRouteThemePaletteKey: EnvironmentKey {
    static let defaultValue = LifeRouteTheme.royal.palette
}

private struct LifeRouteThemeKey: EnvironmentKey {
    static let defaultValue = LifeRouteTheme.royal
}

extension EnvironmentValues {
    var lifeRoutePalette: LifeRouteThemePalette {
        get { self[LifeRouteThemePaletteKey.self] }
        set { self[LifeRouteThemePaletteKey.self] = newValue }
    }

    var lifeRouteTheme: LifeRouteTheme {
        get { self[LifeRouteThemeKey.self] }
        set { self[LifeRouteThemeKey.self] = newValue }
    }
}

enum LifeRouteDesign {
    // v0.7.0 Build A design system: compact premium geometry shared by every later screen family.
    enum Spacing {
        static let compact: CGFloat = 8
        static let standard: CGFloat = 12
        static let comfortable: CGFloat = 16
        static let spacious: CGFloat = 24
    }

    enum Radius {
        static let control: CGFloat = 14
        static let card: CGFloat = 18
        static let hero: CGFloat = 26
        static let iconContainer: CGFloat = 12
    }

    enum Layout {
        static let pageHorizontal: CGFloat = 16
        static let cardGap: CGFloat = 12
        static let minimumTouchTarget: CGFloat = 44
        static let primaryControlHeight: CGFloat = 50
        static let secondaryControlHeight: CGFloat = 46
    }

    enum Stroke {
        static let subtle: CGFloat = 1
    }

    enum Elevation {
        static let cardRadius: CGFloat = 12
        static let cardY: CGFloat = 6
    }
}

enum LifeRouteHaptics {
    static func primaryAction() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.78)
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}

struct LifeRouteCardModifier: ViewModifier {
    @Environment(\.lifeRoutePalette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(LifeRouteDesign.Spacing.comfortable)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    palette.panelElevated.opacity(0.44),
                                    palette.panel.opacity(0.26),
                                    palette.accent.opacity(0.035),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                palette.accentSecondary.opacity(0.14),
                                palette.accent.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: LifeRouteDesign.Stroke.subtle
                    )
            }
            .shadow(color: Color.black.opacity(0.20), radius: LifeRouteDesign.Elevation.cardRadius, y: LifeRouteDesign.Elevation.cardY)
    }
}

struct LifeRoutePrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.lifeRoutePalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .foregroundStyle(Color.black.opacity(0.78))
            .frame(maxWidth: .infinity, minHeight: LifeRouteDesign.Layout.primaryControlHeight)
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.control, style: .continuous).fill(palette.accentGradient))
            .overlay { RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.control, style: .continuous).stroke(Color.white.opacity(0.23), lineWidth: 0.8) }
            .shadow(color: palette.accent.opacity(configuration.isPressed ? 0.10 : 0.18), radius: configuration.isPressed ? 7 : 11, y: configuration.isPressed ? 2 : 4)
            .opacity(configuration.isPressed ? 0.86 : (isEnabled ? 1 : 0.48))
            .scaleEffect(configuration.isPressed ? 0.972 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

struct LifeRouteSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeRoutePalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.textPrimary)
            .frame(maxWidth: .infinity, minHeight: LifeRouteDesign.Layout.secondaryControlHeight)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.control, style: .continuous).fill(palette.panelElevated.opacity(configuration.isPressed ? 0.94 : 0.68)))
            .overlay { RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.control, style: .continuous).stroke(palette.accent.opacity(configuration.isPressed ? 0.46 : 0.28), lineWidth: 1) }
            .shadow(color: palette.accent.opacity(configuration.isPressed ? 0.03 : 0.07), radius: 7, y: 3)
            .scaleEffect(configuration.isPressed ? 0.978 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

// MARK: - v0.7.0 Build A reusable visual primitives

struct LifeRoutePageBackground: View {
    // v0.7.0 Theme Phase 1: page-level renderers are intentionally disabled.
    // The single persistent environment is owned above the five-tab shell.
    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// v0.7.0 official LifeRoute brand mark — refined 1E/1F hybrid identity.
enum LifeRouteBrandMarkVariant {
    case master
    case standard
    case small
    case micro
}

struct LifeRouteBrandMark: View {
    let variant: LifeRouteBrandMarkVariant

    private let navyDeep = Color(red: 0.008, green: 0.027, blue: 0.075)
    private let navyMid = Color(red: 0.025, green: 0.105, blue: 0.22)
    private let navyLift = Color(red: 0.06, green: 0.22, blue: 0.37)
    private let gold = Color(red: 0.88, green: 0.65, blue: 0.23)
    private let goldBright = Color(red: 1.00, green: 0.86, blue: 0.45)

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.19, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [navyDeep, navyMid, navyDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if variant != .micro {
                    brandTopo(size: proxy.size)
                        .stroke(navyLift.opacity(variant == .master ? 0.34 : 0.20), lineWidth: max(0.7, side * 0.012))
                    brandMountains(size: proxy.size)
                        .fill(navyLift.opacity(variant == .small ? 0.34 : 0.48))
                }

                brandRoute(size: proxy.size)
                    .stroke(gold.opacity(0.24), style: StrokeStyle(lineWidth: max(3, side * 0.12), lineCap: .round, lineJoin: .round))
                    .blur(radius: variant == .micro ? 0.5 : side * 0.035)

                brandRoute(size: proxy.size)
                    .stroke(
                        LinearGradient(colors: [goldBright, gold], startPoint: .bottom, endPoint: .top),
                        style: StrokeStyle(lineWidth: max(1.5, side * 0.047), lineCap: .round, lineJoin: .round)
                    )

                Text("LR")
                    .font(.system(size: side * (variant == .micro ? 0.48 : 0.52), weight: .black, design: .serif))
                    .tracking(-side * 0.045)
                    .foregroundStyle(
                        LinearGradient(colors: [goldBright, gold], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .black.opacity(0.56), radius: max(1, side * 0.025), y: side * 0.018)
                    .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.47)

                Image(systemName: "mappin")
                    .font(.system(size: side * (variant == .micro ? 0.18 : 0.20), weight: .black))
                    .foregroundStyle(goldBright)
                    .shadow(color: .black.opacity(0.46), radius: max(1, side * 0.018), y: 1)
                    .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.34)

                RoundedRectangle(cornerRadius: side * 0.19, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [goldBright, gold, goldBright], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: max(1, side * 0.025)
                    )
                    .padding(max(1.5, side * 0.045))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LifeRoute logo")
    }

    private func brandMountains(size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height * 0.73))
            path.addLine(to: CGPoint(x: size.width * 0.18, y: size.height * 0.57))
            path.addLine(to: CGPoint(x: size.width * 0.31, y: size.height * 0.66))
            path.addLine(to: CGPoint(x: size.width * 0.47, y: size.height * 0.49))
            path.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.64))
            path.addLine(to: CGPoint(x: size.width * 0.79, y: size.height * 0.52))
            path.addLine(to: CGPoint(x: size.width, y: size.height * 0.69))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
    }

    private func brandTopo(size: CGSize) -> Path {
        Path { path in
            for index in 0..<4 {
                let y = size.height * (0.18 + CGFloat(index) * 0.12)
                path.move(to: CGPoint(x: -size.width * 0.08, y: y))
                path.addCurve(
                    to: CGPoint(x: size.width * 1.08, y: y + size.height * 0.035),
                    control1: CGPoint(x: size.width * 0.26, y: y + size.height * 0.07),
                    control2: CGPoint(x: size.width * 0.72, y: y - size.height * 0.06)
                )
            }
        }
    }

    private func brandRoute(size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: size.width * 0.25, y: size.height * 0.92))
            path.addCurve(
                to: CGPoint(x: size.width * 0.40, y: size.height * 0.69),
                control1: CGPoint(x: size.width * 0.29, y: size.height * 0.84),
                control2: CGPoint(x: size.width * 0.37, y: size.height * 0.77)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.60, y: size.height * 0.55),
                control1: CGPoint(x: size.width * 0.45, y: size.height * 0.60),
                control2: CGPoint(x: size.width * 0.58, y: size.height * 0.62)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.50, y: size.height * 0.40),
                control1: CGPoint(x: size.width * 0.64, y: size.height * 0.49),
                control2: CGPoint(x: size.width * 0.56, y: size.height * 0.44)
            )
        }
    }
}

struct LifeRouteSectionLabel: View {
    @Environment(\.lifeRoutePalette) private var palette
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(palette.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

struct LifeRouteIconBadge: View {
    @Environment(\.lifeRoutePalette) private var palette
    let systemImage: String
    var prominent = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(prominent ? palette.accent : palette.textPrimary)
            .frame(width: LifeRouteDesign.Layout.minimumTouchTarget, height: LifeRouteDesign.Layout.minimumTouchTarget)
            .background(
                RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.iconContainer, style: .continuous)
                    .fill(prominent ? palette.accent.opacity(0.14) : palette.panelElevated.opacity(0.72))
            )
            .overlay {
                RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.iconContainer, style: .continuous)
                    .stroke(prominent ? palette.accent.opacity(0.28) : Color.white.opacity(0.07), lineWidth: LifeRouteDesign.Stroke.subtle)
            }
    }
}

struct LifeRoutePill: View {
    @Environment(\.lifeRoutePalette) private var palette
    let title: String
    var systemImage: String? = nil
    var isSelected = false

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(isSelected ? Color.black.opacity(0.82) : palette.textSecondary)
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .background {
            if isSelected {
                Capsule().fill(palette.accentGradient)
            } else {
                Capsule().fill(palette.panelElevated.opacity(0.72))
            }
        }
        .overlay {
            Capsule()
                .stroke(isSelected ? palette.accentSecondary.opacity(0.32) : Color.white.opacity(0.08), lineWidth: LifeRouteDesign.Stroke.subtle)
        }
    }
}

struct LifeRouteScreenHeader: View {
    @Environment(\.lifeRoutePalette) private var palette
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let systemImage {
                LifeRouteIconBadge(systemImage: systemImage, prominent: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LifeRouteModalChromeModifier: ViewModifier {
    @Environment(\.lifeRoutePalette) private var palette

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(palette.backgroundGradient.ignoresSafeArea())
            .presentationDragIndicator(.visible)
            .tint(palette.accent)
    }
}

extension View {
    func lifeRouteModalChrome() -> some View {
        modifier(LifeRouteModalChromeModifier())
    }
}

struct LifeRouteThemeArtwork: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette
    var compact = false

    var body: some View {
        GeometryReader { proxy in
            let symbols = theme.artworkSymbols
            ZStack {
                Image(systemName: symbols.primary)
                    .font(.system(size: compact ? max(38, proxy.size.height * 0.56) : max(110, proxy.size.width * 0.38), weight: .black))
                    .foregroundStyle(palette.accent.opacity(compact ? 0.32 : 0.075))
                    .rotationEffect(.degrees(primaryRotation))
                    .position(x: proxy.size.width * 0.72, y: proxy.size.height * (compact ? 0.52 : 0.30))

                Image(systemName: symbols.secondary)
                    .font(.system(size: compact ? max(25, proxy.size.height * 0.34) : max(82, proxy.size.width * 0.27), weight: .bold))
                    .foregroundStyle(palette.accentSecondary.opacity(compact ? 0.22 : 0.055))
                    .rotationEffect(.degrees(secondaryRotation))
                    .position(x: proxy.size.width * 0.24, y: proxy.size.height * (compact ? 0.64 : 0.72))

                Circle()
                    .fill(palette.accentSecondary.opacity(compact ? 0.12 : 0.055))
                    .frame(width: compact ? 34 : 120, height: compact ? 34 : 120)
                    .blur(radius: compact ? 8 : 28)
                    .position(x: proxy.size.width * 0.86, y: proxy.size.height * 0.16)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var primaryRotation: Double {
        switch theme {
        case .carbon, .slate: return -12
        case .aurora, .sapphireTide: return 8
        case .electricStorm, .solarFlare: return -8
        default: return 0
        }
    }

    private var secondaryRotation: Double {
        switch theme {
        case .obsidian, .titanium, .phantomSilver: return 18
        case .forest, .plum: return -10
        default: return 0
        }
    }
}

struct LifeRouteCoreGlassEnvironment: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                palette.backgroundGradient

                RadialGradient(
                    colors: [palette.accent.opacity(0.22), palette.accent.opacity(0.05), .clear],
                    center: .topTrailing,
                    startRadius: 4,
                    endRadius: max(size.width, size.height) * 0.72
                )

                RadialGradient(
                    colors: [palette.accentSecondary.opacity(0.13), .clear],
                    center: .bottomLeading,
                    startRadius: 8,
                    endRadius: max(size.width, size.height) * 0.62
                )

                Ellipse()
                    .fill(palette.accentSecondary.opacity(0.09))
                    .frame(width: size.width * 1.05, height: size.width * 0.46)
                    .blur(radius: 30)
                    .rotationEffect(.degrees(glassAngle))
                    .offset(x: size.width * 0.34, y: -size.height * 0.22)

                RoundedRectangle(cornerRadius: max(36, size.width * 0.12), style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.11),
                                palette.accentSecondary.opacity(0.055),
                                Color.white.opacity(0.015),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size.width * 1.25, height: max(90, size.height * 0.18))
                    .blur(radius: 12)
                    .rotationEffect(.degrees(glassAngle - 9))
                    .offset(x: -size.width * 0.18, y: size.height * 0.18)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.075),
                        .clear,
                        palette.accent.opacity(0.035),
                        .clear,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.screen)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var glassAngle: Double {
        switch theme {
        case .royal, .midnight, .coreOcean, .arctic:
            return -24
        case .obsidian, .titanium, .coreUltraviolet, .emerald:
            return 18
        case .coreAurora, .roseQuartz:
            return -12
        case .coreSolarFlare, .coreEmber:
            return 26
        default:
            return -18
        }
    }
}

struct LifeRouteLiquidRibbon: Shape {
    let phase: Double
    let amplitude: CGFloat
    let verticalBias: CGFloat
    let thickness: CGFloat
    let frequency: Double

    func path(in rect: CGRect) -> Path {
        let steps = 20
        let width = max(1, rect.width)
        let centerY = rect.height * verticalBias

        func waveY(_ index: Int, offset: Double = 0) -> CGFloat {
            let progress = Double(index) / Double(steps)
            let radians = progress * Double.pi * 2 * frequency + phase + offset
            let secondary = sin(radians * 0.53 + 1.2) * 0.24
            return centerY + CGFloat(sin(radians) + secondary) * amplitude
        }

        var top: [CGPoint] = []
        var bottom: [CGPoint] = []
        for index in 0...steps {
            let x = width * CGFloat(index) / CGFloat(steps)
            top.append(CGPoint(x: x, y: waveY(index)))
            bottom.append(CGPoint(x: x, y: waveY(index, offset: 0.42) + thickness))
        }

        var path = Path()
        guard let first = top.first else { return path }
        path.move(to: first)
        for point in top.dropFirst() { path.addLine(to: point) }
        for point in bottom.reversed() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}

// v0.7.0 Theme Phase 2 compile compatibility
fileprivate struct LifeRouteDynamicMotionSignature {
    let speed: Double
    let amplitude: CGFloat
    let ribbonAngle: Double
    let stillPhase: Double
}

extension LifeRouteTheme {
    fileprivate var dynamicMotionSignature: LifeRouteDynamicMotionSignature {
        switch self {
        case .royalCurrent: return .init(speed: 0.12, amplitude: 32, ribbonAngle: -7, stillPhase: 0.7)
        case .midnightPrism: return .init(speed: 0.095, amplitude: 38, ribbonAngle: 9, stillPhase: 1.4)
        case .auroraBloom: return .init(speed: 0.085, amplitude: 44, ribbonAngle: -11, stillPhase: 2.1)
        case .solarPulse: return .init(speed: 0.14, amplitude: 34, ribbonAngle: 6, stillPhase: 0.2)
        case .emeraldFlow: return .init(speed: 0.10, amplitude: 40, ribbonAngle: -5, stillPhase: 1.8)
        case .arcticHalo: return .init(speed: 0.07, amplitude: 28, ribbonAngle: 12, stillPhase: 2.7)
        case .oceanGlass: return .init(speed: 0.105, amplitude: 42, ribbonAngle: -3, stillPhase: 1.1)
        case .roseEmber: return .init(speed: 0.115, amplitude: 35, ribbonAngle: 8, stillPhase: 2.4)
        case .obsidianSpectra: return .init(speed: 0.075, amplitude: 46, ribbonAngle: -9, stillPhase: 0.9)
        case .plasmaOrchid: return .init(speed: 0.125, amplitude: 39, ribbonAngle: 7, stillPhase: 1.6)
        case .verdantMist: return .init(speed: 0.065, amplitude: 30, ribbonAngle: -4, stillPhase: 2.9)
        case .titaniumGlow: return .init(speed: 0.08, amplitude: 26, ribbonAngle: 10, stillPhase: 0.4)
        default: return .init(speed: 0.09, amplitude: 32, ribbonAngle: 0, stillPhase: 0.8)
        }
    }
}

struct LifeRouteDynamicGlassFrame: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let signature = theme.dynamicMotionSignature
            let longSide = max(size.width, size.height)

            ZStack {
                // v0.7.0 Theme Phase 2 full-frame background-motion QA fix:
                // the entire backdrop now drifts and refracts instead of leaving a static black field behind foreground ribbons.
                LinearGradient(
                    colors: [
                        palette.backgroundTop,
                        palette.panelElevated.opacity(0.94),
                        palette.backgroundBottom,
                        palette.accent.opacity(0.28),
                        palette.backgroundTop,
                    ],
                    startPoint: UnitPoint(
                        x: CGFloat(0.02 + 0.16 * (0.5 + 0.5 * sin(phase * 0.17))),
                        y: CGFloat(0.02 + 0.14 * (0.5 + 0.5 * cos(phase * 0.13)))
                    ),
                    endPoint: UnitPoint(
                        x: CGFloat(0.98 - 0.14 * (0.5 + 0.5 * cos(phase * 0.15))),
                        y: CGFloat(0.98 - 0.16 * (0.5 + 0.5 * sin(phase * 0.11)))
                    )
                )

                AngularGradient(
                    gradient: Gradient(colors: [
                        palette.backgroundTop,
                        palette.accent.opacity(0.34),
                        palette.panel.opacity(0.64),
                        palette.accentSecondary.opacity(0.28),
                        palette.backgroundBottom,
                        palette.backgroundTop,
                    ]),
                    center: UnitPoint(
                        x: CGFloat(0.50 + 0.06 * sin(phase * 0.19)),
                        y: CGFloat(0.48 + 0.05 * cos(phase * 0.16))
                    ),
                    angle: .degrees(phase * 11.0)
                )
                .scaleEffect(1.55)
                .blur(radius: 24)
                .opacity(0.88)

                LinearGradient(
                    colors: [
                        palette.accentSecondary.opacity(0.12),
                        .clear,
                        palette.accent.opacity(0.10),
                        .clear,
                    ],
                    startPoint: UnitPoint(
                        x: CGFloat(0.08 + 0.12 * sin(phase * 0.21)),
                        y: 0
                    ),
                    endPoint: UnitPoint(
                        x: CGFloat(0.90 + 0.08 * cos(phase * 0.18)),
                        y: 1
                    )
                )
                .blendMode(.screen)

                RadialGradient(
                    colors: [palette.accent.opacity(0.48), palette.accent.opacity(0.13), .clear],
                    center: UnitPoint(
                        x: CGFloat(0.72 + 0.14 * cos(phase * 0.41)),
                        y: CGFloat(0.18 + 0.09 * sin(phase * 0.33))
                    ),
                    startRadius: 5,
                    endRadius: longSide * 0.84
                )

                RadialGradient(
                    colors: [palette.accentSecondary.opacity(0.38), palette.accentSecondary.opacity(0.08), .clear],
                    center: UnitPoint(
                        x: CGFloat(0.22 + 0.12 * sin(phase * 0.29)),
                        y: CGFloat(0.76 + 0.08 * cos(phase * 0.37))
                    ),
                    startRadius: 8,
                    endRadius: longSide * 0.78
                )

                LifeRouteLiquidRibbon(
                    phase: phase,
                    amplitude: signature.amplitude,
                    verticalBias: 0.30,
                    thickness: max(74, size.height * 0.12),
                    frequency: 1.04
                )
                .fill(
                    LinearGradient(
                        colors: [
                            palette.accent.opacity(0.05),
                            palette.accentSecondary.opacity(0.24),
                            Color.white.opacity(0.075),
                            palette.accent.opacity(0.08),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .blur(radius: 13)
                .rotationEffect(.degrees(signature.ribbonAngle))
                .offset(y: -size.height * 0.05)

                LifeRouteLiquidRibbon(
                    phase: -phase * 0.82 + 1.7,
                    amplitude: signature.amplitude * 0.78,
                    verticalBias: 0.57,
                    thickness: max(62, size.height * 0.10),
                    frequency: 0.82
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.025),
                            palette.accent.opacity(0.18),
                            palette.accentSecondary.opacity(0.13),
                            .clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 18)
                .rotationEffect(.degrees(-signature.ribbonAngle * 0.62))

                LifeRouteLiquidRibbon(
                    phase: phase * 0.64 + 3.0,
                    amplitude: signature.amplitude * 0.52,
                    verticalBias: 0.76,
                    thickness: max(48, size.height * 0.075),
                    frequency: 1.22
                )
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.09),
                            palette.accentSecondary.opacity(0.15),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .blur(radius: 10)
                .blendMode(.screen)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.085),
                        .clear,
                        palette.accentSecondary.opacity(0.025),
                        .clear,
                    ],
                    startPoint: UnitPoint(x: CGFloat(0.16 + 0.05 * sin(phase * 0.22)), y: 0),
                    endPoint: UnitPoint(x: CGFloat(0.84 + 0.05 * cos(phase * 0.22)), y: 1)
                )
                .blendMode(.screen)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .compositingGroup()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct LifeRouteDynamicGlassEnvironment: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette
    let reduceMotion: Bool
    let isActive: Bool

    var body: some View {
        let signature = theme.dynamicMotionSignature
        // One system-driven root timeline only. Paused schedules do no continuous work while
        // Reduce Motion is enabled or LifeRoute is inactive/backgrounded.
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 20.0,
                paused: reduceMotion || !isActive
            )
        ) { context in
            let livePhase = context.date.timeIntervalSinceReferenceDate * signature.speed
            LifeRouteDynamicGlassFrame(
                theme: theme,
                palette: palette,
                phase: reduceMotion ? signature.stillPhase : livePhase
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct LifeRouteChromeModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.lifeRouteTheme) private var theme

    func body(content: Content) -> some View {
        // v0.7.0 Theme Phase 2 persistent environment host: still Core, live Dynamic, legacy Scenery.
        ZStack {
            if theme.isPhaseOneCoreGlass {
                LifeRouteCoreGlassEnvironment(theme: theme, palette: palette)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            } else if theme.isPhaseTwoDynamic {
                LifeRouteDynamicGlassEnvironment(
                    theme: theme,
                    palette: palette,
                    reduceMotion: reduceMotion,
                    isActive: scenePhase == .active
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            } else {
                // Scenery remains the validated legacy renderer until Phase 3.
                LifeRouteCinematicBackdrop(theme: theme, palette: palette)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            content
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: theme)
        .environment(\.defaultMinListRowHeight, 52)
        .tint(palette.accent)
        .preferredColorScheme(theme == .light ? .light : .dark)
    }
}

private struct LifeRouteThemeBackdrop: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch theme.category {
                case .core:
                    coreBackdrop(size: proxy.size)
                case .metallic:
                    metallicBackdrop(size: proxy.size)
                case .scenery:
                    sceneryBackdrop(size: proxy.size)
                case .dynamic:
                    dynamicBackdrop(size: proxy.size)
                case .fluid:
                    fluidBackdrop(size: proxy.size)
                }

                LifeRouteThemeArtwork(theme: theme, palette: palette)
            }
            .clipped()
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func coreBackdrop(size: CGSize) -> some View {
        ForEach(0..<5, id: \.self) { index in
            Circle()
                .fill(palette.accent.opacity(index.isMultiple(of: 2) ? 0.08 : 0.045))
                .frame(width: CGFloat(4 + index * 2), height: CGFloat(4 + index * 2))
                .position(
                    x: size.width * CGFloat(0.14 + Double(index) * 0.17),
                    y: size.height * CGFloat(0.10 + Double(index % 3) * 0.08)
                )
        }
    }

    @ViewBuilder
    private func metallicBackdrop(size: CGSize) -> some View {
        ForEach(0..<5, id: \.self) { index in
            Image(systemName: "hexagon.fill")
                .font(.system(size: CGFloat(92 + index * 28), weight: .ultraLight))
                .foregroundStyle(index.isMultiple(of: 2) ? palette.accent.opacity(0.035) : palette.accentSecondary.opacity(0.028))
                .rotationEffect(.degrees(Double(index * 12)))
                .position(
                    x: size.width * CGFloat(index.isMultiple(of: 2) ? 0.82 : 0.18),
                    y: size.height * CGFloat(0.10 + Double(index) * 0.19)
                )
        }

        LinearGradient(
            colors: [.clear, palette.accentSecondary.opacity(0.055), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .rotationEffect(.degrees(-14))
        .offset(x: size.width * 0.25)
    }

    @ViewBuilder
    private func sceneryBackdrop(size: CGSize) -> some View {
        Circle()
            .fill(palette.accentSecondary.opacity(0.09))
            .frame(width: size.width * 0.42, height: size.width * 0.42)
            .blur(radius: 18)
            .position(x: size.width * 0.82, y: size.height * 0.16)

        if isAurora {
            Capsule()
                .fill(palette.accentSecondary.opacity(0.055))
                .frame(width: size.width * 1.2, height: 54)
                .blur(radius: 24)
                .rotationEffect(.degrees(-24))
                .offset(x: -size.width * 0.10, y: -size.height * 0.18)
        }
    }

    @ViewBuilder
    private func dynamicBackdrop(size: CGSize) -> some View {
        ForEach(0..<4, id: \.self) { index in
            Capsule()
                .fill(index.isMultiple(of: 2) ? palette.accent.opacity(0.055) : palette.accentSecondary.opacity(0.045))
                .frame(width: size.width * 0.95, height: CGFloat(20 + index * 8))
                .blur(radius: CGFloat(8 + index * 2))
                .rotationEffect(.degrees(-32))
                .offset(x: CGFloat(index - 2) * 42, y: CGFloat(index - 1) * 170)
        }
    }

    @ViewBuilder
    private func fluidBackdrop(size: CGSize) -> some View {
        Ellipse()
            .fill(palette.accent.opacity(0.07))
            .frame(width: size.width * 1.05, height: size.width * 0.52)
            .blur(radius: 28)
            .rotationEffect(.degrees(-18))
            .offset(x: size.width * 0.32, y: -size.height * 0.18)

        Ellipse()
            .stroke(palette.accentSecondary.opacity(0.07), lineWidth: 22)
            .frame(width: size.width * 1.15, height: size.width * 0.58)
            .blur(radius: 8)
            .rotationEffect(.degrees(16))
            .offset(x: -size.width * 0.36, y: size.height * 0.24)
    }

    private var isAurora: Bool {
        switch theme {
        case .aurora: return true
        default: return false
        }
    }
}

extension View {
    func lifeRouteCard() -> some View { modifier(LifeRouteCardModifier()) }
    func lifeRouteChrome() -> some View { modifier(LifeRouteChromeModifier()) }
}

enum LifeRouteAppearance {
    static func configure(theme: LifeRouteTheme) {
        let palette = theme.palette
        let background = UIColor(palette.backgroundTop)
        let panel = UIColor(palette.panel)
        let elevated = UIColor(palette.panelElevated)
        let accent = UIColor(palette.accent)
        let primary = UIColor(palette.textPrimary)
        let secondary = UIColor(palette.textSecondary)

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        nav.backgroundColor = background.withAlphaComponent(0.78)
        nav.shadowColor = accent.withAlphaComponent(0.10)
        nav.titleTextAttributes = [.foregroundColor: primary, .font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
        nav.largeTitleTextAttributes = [.foregroundColor: primary, .font: UIFont.systemFont(ofSize: 34, weight: .bold)]

        let navButton = UIBarButtonItemAppearance(style: .plain)
        navButton.normal.titleTextAttributes = [
            .foregroundColor: accent,
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
        ]
        navButton.highlighted.titleTextAttributes = [
            .foregroundColor: accent.withAlphaComponent(0.68),
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
        ]
        nav.buttonAppearance = navButton
        nav.backButtonAppearance = navButton

        let doneButton = UIBarButtonItemAppearance(style: .done)
        doneButton.normal.titleTextAttributes = [
            .foregroundColor: accent,
            .font: UIFont.systemFont(ofSize: 16, weight: .bold)
        ]
        nav.doneButtonAppearance = doneButton

        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = accent
        UIBarButtonItem.appearance().tintColor = accent

        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        tab.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tab.backgroundColor = background.withAlphaComponent(0.88)
        tab.shadowColor = accent.withAlphaComponent(0.09)
        configure(tab.stackedLayoutAppearance, accent: accent, secondary: secondary)
        configure(tab.inlineLayoutAppearance, accent: accent, secondary: secondary)
        configure(tab.compactInlineLayoutAppearance, accent: accent, secondary: secondary)
        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tab
        tabBar.scrollEdgeAppearance = tab
        tabBar.tintColor = accent
        tabBar.unselectedItemTintColor = secondary
        tabBar.itemPositioning = .fill
        tabBar.selectionIndicatorImage = makeTabSelectionIndicator(accent: accent)

        let segmented = UISegmentedControl.appearance()
        segmented.backgroundColor = panel.withAlphaComponent(0.72)
        segmented.selectedSegmentTintColor = accent
        segmented.setTitleTextAttributes([
            .foregroundColor: secondary,
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
        ], for: .normal)
        segmented.setTitleTextAttributes([
            .foregroundColor: UIColor.black.withAlphaComponent(0.78),
            .font: UIFont.systemFont(ofSize: 13, weight: .bold)
        ], for: .selected)

        UISwitch.appearance().onTintColor = accent
        UIStepper.appearance().tintColor = accent
        UIDatePicker.appearance().tintColor = accent
        UITextField.appearance().tintColor = accent
        UITextField.appearance().backgroundColor = elevated.withAlphaComponent(0.24)
        UITextView.appearance().tintColor = accent
        UITextView.appearance().backgroundColor = panel.withAlphaComponent(0.28)
        UIActivityIndicatorView.appearance().color = accent
        UIProgressView.appearance().progressTintColor = accent

        let table = UITableView.appearance()
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.sectionHeaderTopPadding = 12

        let cell = UITableViewCell.appearance()
        cell.backgroundColor = panel.withAlphaComponent(0.42)
        cell.tintColor = accent

        let sectionLabel = UILabel.appearance(whenContainedInInstancesOf: [UITableViewHeaderFooterView.self])
        sectionLabel.textColor = accent.withAlphaComponent(0.84)
        sectionLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)

        let tableButton = UIButton.appearance(whenContainedInInstancesOf: [UITableViewCell.self])
        tableButton.tintColor = accent

        UICollectionView.appearance().backgroundColor = .clear
    }

    private static func makeTabSelectionIndicator(accent: UIColor) -> UIImage {
        let size = CGSize(width: 64, height: 46)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let rect = CGRect(x: 3, y: 3, width: 58, height: 40)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 20)
            accent.withAlphaComponent(0.13).setFill()
            path.fill()
            accent.withAlphaComponent(0.20).setStroke()
            path.lineWidth = 1
            path.stroke()
        }
        return image.resizableImage(
            withCapInsets: UIEdgeInsets(top: 22, left: 31, bottom: 22, right: 31),
            resizingMode: .stretch
        )
    }

    private static func configure(_ item: UITabBarItemAppearance, accent: UIColor, secondary: UIColor) {
        item.normal.iconColor = secondary
        item.normal.titleTextAttributes = [.foregroundColor: secondary, .font: UIFont.systemFont(ofSize: 10, weight: .medium)]
        item.selected.iconColor = accent
        item.selected.titleTextAttributes = [.foregroundColor: accent, .font: UIFont.systemFont(ofSize: 10, weight: .bold)]
    }
}

@main
struct LifeRouteApp: App {
    @StateObject private var themeStore = LifeRouteThemeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .lifeRouteChrome()
                .environmentObject(themeStore)
                .environment(\.lifeRoutePalette, themeStore.palette)
                .environment(\.lifeRouteTheme, themeStore.selectedTheme)
        }
    }
}
