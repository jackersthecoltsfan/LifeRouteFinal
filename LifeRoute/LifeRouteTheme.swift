import SwiftUI
import UIKit

extension Color {
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

    // v0.7.0 Theme Phase 3 Scenery catalog uses explicit, stable Day/Night identifiers.
    case sceneryMountainsDay = "scenery.mountains.day"
    case sceneryMountainsNight = "scenery.mountains.night"
    case sceneryOceanDay = "scenery.ocean.day"
    case sceneryOceanNight = "scenery.ocean.night"
    case sceneryDesertDay = "scenery.desert.day"
    case sceneryDesertNight = "scenery.desert.night"
    case sceneryAlpineDay = "scenery.alpine.day"
    case sceneryAlpineNight = "scenery.alpine.night"
    case sceneryRainforestDay = "scenery.rainforest.day"
    case sceneryRainforestNight = "scenery.rainforest.night"
    case sceneryGrasslandDay = "scenery.grassland.day"
    case sceneryGrasslandNight = "scenery.grassland.night"
    case sceneryVolcanicDay = "scenery.volcanic.day"
    case sceneryVolcanicNight = "scenery.volcanic.night"
    case sceneryCanyonDay = "scenery.canyon.day"
    case sceneryCanyonNight = "scenery.canyon.night"
    case sceneryArcticDay = "scenery.arctic.day"
    case sceneryArcticNight = "scenery.arctic.night"
    case sceneryCoastalCliffsDay = "scenery.coastalCliffs.day"
    case sceneryCoastalCliffsNight = "scenery.coastalCliffs.night"

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

    // v0.7.1 reduced production theme catalog: eight distinct live Dynamic identities.
    static let phaseTwoDynamicCatalog: [LifeRouteTheme] = [
        .royalCurrent, .midnightPrism, .auroraBloom, .solarPulse,
        .emeraldFlow, .oceanGlass, .obsidianSpectra, .plasmaOrchid,
    ]

    var isPhaseTwoDynamic: Bool {
        Self.phaseTwoDynamicCatalog.contains(self)
    }

    // v0.7.1 reduced production theme catalog: six scenery families × explicit Day/Night variants.
    static let phaseThreeSceneryCatalog: [LifeRouteTheme] = [
        .sceneryMountainsDay, .sceneryMountainsNight,
        .sceneryOceanDay, .sceneryOceanNight,
        .sceneryDesertDay, .sceneryDesertNight,
        .sceneryRainforestDay, .sceneryRainforestNight,
        .sceneryCanyonDay, .sceneryCanyonNight,
        .sceneryArcticDay, .sceneryArcticNight,
    ]

    var isPhaseThreeScenery: Bool {
        Self.phaseThreeSceneryCatalog.contains(self)
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
        case .sceneryMountainsDay: return "Mountains — Day"
        case .sceneryMountainsNight: return "Mountains — Night"
        case .sceneryOceanDay: return "Ocean — Day"
        case .sceneryOceanNight: return "Ocean — Night"
        case .sceneryDesertDay: return "Desert — Day"
        case .sceneryDesertNight: return "Desert — Night"
        case .sceneryAlpineDay: return "Alpine — Day"
        case .sceneryAlpineNight: return "Alpine — Night"
        case .sceneryRainforestDay: return "Rainforest — Day"
        case .sceneryRainforestNight: return "Rainforest — Night"
        case .sceneryGrasslandDay: return "Grassland — Day"
        case .sceneryGrasslandNight: return "Grassland — Night"
        case .sceneryVolcanicDay: return "Volcanic — Day"
        case .sceneryVolcanicNight: return "Volcanic — Night"
        case .sceneryCanyonDay: return "Canyon — Day"
        case .sceneryCanyonNight: return "Canyon — Night"
        case .sceneryArcticDay: return "Arctic — Day"
        case .sceneryArcticNight: return "Arctic — Night"
        case .sceneryCoastalCliffsDay: return "Coastal Cliffs — Day"
        case .sceneryCoastalCliffsNight: return "Coastal Cliffs — Night"
        }
    }

    var category: LifeRouteThemeCategory {
        switch self {
        case .royal, .obsidian, .carbon, .midnight, .navyNoir, .sunflare, .noir, .golden, .cobaltShine, .light, .dark, .kaleidoscope, .classic, .accessible, .coreOcean, .coreAurora, .coreSolarFlare, .coreUltraviolet, .emerald, .roseQuartz, .arctic, .coreEmber: return .core
        case .titanium, .slate, .moltenGold, .phantomSilver: return .metallic
        case .ocean, .forest, .plum, .ember, .mountain, .space, .desert, .sunshine: return .scenery
        // v0.7.0 Theme Phase 2 category compatibility
        case .solarFlare, .electricStorm, .ultraviolet, .arcticPulse, .royalCurrent, .midnightPrism, .auroraBloom, .solarPulse, .emeraldFlow, .arcticHalo, .oceanGlass, .roseEmber, .obsidianSpectra, .plasmaOrchid, .verdantMist, .titaniumGlow: return .dynamic
        case .sceneryMountainsDay, .sceneryMountainsNight, .sceneryOceanDay, .sceneryOceanNight, .sceneryDesertDay, .sceneryDesertNight, .sceneryAlpineDay, .sceneryAlpineNight, .sceneryRainforestDay, .sceneryRainforestNight, .sceneryGrasslandDay, .sceneryGrasslandNight, .sceneryVolcanicDay, .sceneryVolcanicNight, .sceneryCanyonDay, .sceneryCanyonNight, .sceneryArcticDay, .sceneryArcticNight, .sceneryCoastalCliffsDay, .sceneryCoastalCliffsNight: return .scenery
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
        case .sceneryMountainsDay: return ("mountain.2.fill", "sun.max.fill")
        case .sceneryMountainsNight: return ("mountain.2.fill", "moon.stars.fill")
        case .sceneryOceanDay: return ("water.waves", "sun.max.fill")
        case .sceneryOceanNight: return ("water.waves", "moon.stars.fill")
        case .sceneryDesertDay: return ("sun.max.fill", "mountain.2.fill")
        case .sceneryDesertNight: return ("moon.stars.fill", "mountain.2.fill")
        case .sceneryAlpineDay: return ("snowflake", "mountain.2.fill")
        case .sceneryAlpineNight: return ("snowflake", "moon.stars.fill")
        case .sceneryRainforestDay: return ("tree.fill", "sun.max.fill")
        case .sceneryRainforestNight: return ("tree.fill", "moon.stars.fill")
        case .sceneryGrasslandDay: return ("leaf.fill", "sun.max.fill")
        case .sceneryGrasslandNight: return ("leaf.fill", "moon.stars.fill")
        case .sceneryVolcanicDay: return ("mountain.2.fill", "smoke.fill")
        case .sceneryVolcanicNight: return ("flame.fill", "smoke.fill")
        case .sceneryCanyonDay: return ("mountain.2.fill", "sun.max.fill")
        case .sceneryCanyonNight: return ("mountain.2.fill", "moon.stars.fill")
        case .sceneryArcticDay: return ("snowflake", "sun.max.fill")
        case .sceneryArcticNight: return ("snowflake", "moon.stars.fill")
        case .sceneryCoastalCliffsDay: return ("water.waves", "mountain.2.fill")
        case .sceneryCoastalCliffsNight: return ("water.waves", "moon.stars.fill")
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
        case .sceneryMountainsDay: return makeThemePalette(0x416b86, 0x1b3852, 0x14283b, 0x24445d, 0xd7ad5a, 0xb9d8e8)
        case .sceneryMountainsNight: return makeThemePalette(0x050d1b, 0x142c48, 0x0c1c30, 0x1c3a57, 0xd5ad61, 0x8cb9dd)
        case .sceneryOceanDay: return makeThemePalette(0x3d87a4, 0x0b405d, 0x0c2c40, 0x15546d, 0xe8c46d, 0x86e2e9)
        case .sceneryOceanNight: return makeThemePalette(0x03101f, 0x082b44, 0x081d30, 0x123d57, 0xd7bd79, 0x5fa9d5)
        case .sceneryDesertDay: return makeThemePalette(0x9a6d52, 0x4f3540, 0x33242b, 0x614139, 0xf1b86a, 0xf0d49a)
        case .sceneryDesertNight: return makeThemePalette(0x100d22, 0x30234d, 0x20182f, 0x44355d, 0xe2a866, 0xb596dc)
        case .sceneryAlpineDay: return makeThemePalette(0x7395aa, 0x31566f, 0x20394c, 0x46677c, 0xd9bb78, 0xd9edf4)
        case .sceneryAlpineNight: return makeThemePalette(0x061120, 0x1b344d, 0x10253a, 0x2a4b62, 0xc9b174, 0x9bc8df)
        case .sceneryRainforestDay: return makeThemePalette(0x1d563e, 0x103326, 0x102c21, 0x24503c, 0xd7b65d, 0x8ad1a6)
        case .sceneryRainforestNight: return makeThemePalette(0x03140f, 0x0c2c24, 0x0a231b, 0x184238, 0xd0aa61, 0x57a58c)
        case .sceneryGrasslandDay: return makeThemePalette(0x4b8798, 0x315b42, 0x20382d, 0x45604a, 0xe4bd66, 0xb9d88d)
        case .sceneryGrasslandNight: return makeThemePalette(0x071522, 0x18362d, 0x102820, 0x2a493d, 0xd6b165, 0x779f92)
        case .sceneryVolcanicDay: return makeThemePalette(0x5a3a35, 0x20272d, 0x281d1d, 0x4b302b, 0xe89a4f, 0xf1c06f)
        case .sceneryVolcanicNight: return makeThemePalette(0x09080b, 0x28100d, 0x1a1011, 0x421c17, 0xff7540, 0xf4b35f)
        case .sceneryCanyonDay: return makeThemePalette(0x8f5b4c, 0x4d3442, 0x35252c, 0x644035, 0xe9b365, 0xe5c79b)
        case .sceneryCanyonNight: return makeThemePalette(0x110c1e, 0x342342, 0x24182f, 0x4a3152, 0xd5a060, 0xa889c0)
        case .sceneryArcticDay: return makeThemePalette(0x7da6b7, 0x426a7e, 0x294757, 0x55788a, 0xd9c078, 0xe4f3f7)
        case .sceneryArcticNight: return makeThemePalette(0x041526, 0x12384d, 0x0c2939, 0x1f5060, 0xcdb773, 0x73d6ca)
        case .sceneryCoastalCliffsDay: return makeThemePalette(0x477c8e, 0x1f4653, 0x16333d, 0x315966, 0xd9b669, 0xa3d8dc)
        case .sceneryCoastalCliffsNight: return makeThemePalette(0x04131e, 0x153543, 0x0c2833, 0x244957, 0xd0ad67, 0x6baeb6)
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
#if DEBUG
        // v0.7.1 visual validation can select a theme without mutating persisted user preference.
        let savedIdentifier = LifeRouteVisualFixture.themeOverride?.rawValue
            ?? UserDefaults.standard.string(forKey: Self.storageKey)
#else
        let savedIdentifier = UserDefaults.standard.string(forKey: Self.storageKey)
#endif
        let theme = Self.shippingTheme(Self.resolveStoredTheme(savedIdentifier))
        selectedTheme = theme
        if savedIdentifier != theme.rawValue {
            UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey)
        }
        LifeRouteAppearance.configure(theme: theme)
    }

    var palette: LifeRouteThemePalette { selectedTheme.palette }

    // v0.7.1 shipping theme hold: preserve unfinished theme code while exposing only physically proven non-Core themes.
    private static func shippingTheme(_ theme: LifeRouteTheme) -> LifeRouteTheme {
        if theme.isV071RetainedDynamic { return theme }
        if theme.category == .dynamic { return .royalCurrent }
        if theme.isV071RetainedScenery { return theme }
        if theme.category == .scenery { return .sceneryCanyonDay }
        return theme
    }

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
        // Retired pre-Phase-3 Scenery identifiers migrate deterministically; Day/Night never changes automatically.
        case "mountain":
            return .sceneryMountainsDay
        case "ocean":
            return .sceneryOceanDay
        case "space":
            return .sceneryArcticNight
        case "desert":
            return .sceneryDesertDay
        case "forest":
            return .sceneryRainforestDay
        case "sunshine":
            return .sceneryGrasslandDay
        case "plum":
            return .sceneryCanyonNight
        case "ember":
            return .sceneryVolcanicNight
        // v0.7.1 reduced production theme catalog: retired choices migrate to the nearest retained identity.
        case "dynamic.arcticHalo":
            return .oceanGlass
        case "dynamic.roseEmber":
            return .solarPulse
        case "dynamic.verdantMist":
            return .emeraldFlow
        case "dynamic.titaniumGlow":
            return .obsidianSpectra
        case "scenery.alpine.day":
            return .sceneryMountainsDay
        case "scenery.alpine.night":
            return .sceneryMountainsNight
        case "scenery.grassland.day":
            return .sceneryRainforestDay
        case "scenery.grassland.night":
            return .sceneryRainforestNight
        case "scenery.volcanic.day":
            return .sceneryDesertDay
        case "scenery.volcanic.night":
            return .sceneryDesertNight
        case "scenery.coastalCliffs.day":
            return .sceneryOceanDay
        case "scenery.coastalCliffs.night":
            return .sceneryOceanNight
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
