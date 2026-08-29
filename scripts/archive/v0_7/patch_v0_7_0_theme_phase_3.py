#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute/LifeRouteApp.swift"
THEMES = ROOT / "LifeRoute/V054ThemeCenterView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 Theme Phase 3 patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def replace_region(text: str, start_token: str, end_token: str, replacement: str, label: str) -> str:
    try:
        start = text.index(start_token)
        end = text.index(end_token, start)
    except ValueError as exc:
        raise SystemExit(f"v0.7.0 Theme Phase 3 patch failed: {label} boundary missing") from exc
    return text[:start] + replacement + text[end:]


def patch_app() -> None:
    text = APP.read_text(encoding="utf-8")
    marker = "v0.7.0 Theme Phase 3 Scenery catalog"
    if marker in text:
        return

    required = [
        "v0.7.0 Theme Phase 2 Dynamic Liquid Glass catalog",
        "v0.7.0 Theme Phase 2 full-frame background-motion QA fix",
        "v0.7.0 live theme surface visibility repair",
        "static let phaseOneCoreGlassCatalog",
        "static let phaseTwoDynamicCatalog",
        "struct LifeRouteDynamicGlassFrame: View",
        "struct LifeRouteDynamicGlassEnvironment: View",
        "v0.7.0 Theme Phase 2 persistent environment host",
        "minimumInterval: 1.0 / 20.0",
        "paused: reduceMotion || !isActive",
        "private static func resolveStoredTheme(_ identifier: String?) -> LifeRouteTheme",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Theme Phase 3 patch failed: validated post-QA baseline missing {missing}")

    text = replace_once(
        text,
        '    case titaniumGlow = "dynamic.titaniumGlow"\n',
        '''    case titaniumGlow = "dynamic.titaniumGlow"

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
''',
        "stable Scenery identifiers",
    )

    text = replace_once(
        text,
        '''    var isPhaseTwoDynamic: Bool {
        Self.phaseTwoDynamicCatalog.contains(self)
    }
''',
        '''    var isPhaseTwoDynamic: Bool {
        Self.phaseTwoDynamicCatalog.contains(self)
    }

    // v0.7.0 Theme Phase 3 Scenery catalog: exactly 10 families × explicit Day/Night variants.
    static let phaseThreeSceneryCatalog: [LifeRouteTheme] = [
        .sceneryMountainsDay, .sceneryMountainsNight,
        .sceneryOceanDay, .sceneryOceanNight,
        .sceneryDesertDay, .sceneryDesertNight,
        .sceneryAlpineDay, .sceneryAlpineNight,
        .sceneryRainforestDay, .sceneryRainforestNight,
        .sceneryGrasslandDay, .sceneryGrasslandNight,
        .sceneryVolcanicDay, .sceneryVolcanicNight,
        .sceneryCanyonDay, .sceneryCanyonNight,
        .sceneryArcticDay, .sceneryArcticNight,
        .sceneryCoastalCliffsDay, .sceneryCoastalCliffsNight,
    ]

    var isPhaseThreeScenery: Bool {
        Self.phaseThreeSceneryCatalog.contains(self)
    }
''',
        "approved Scenery catalog",
    )

    text = replace_once(
        text,
        '''        case .titaniumGlow: return "Titanium Glow"
        }''',
        '''        case .titaniumGlow: return "Titanium Glow"
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
        }''',
        "Scenery theme names",
    )

    dynamic_category = "        case .solarFlare, .electricStorm, .ultraviolet, .arcticPulse, .royalCurrent, .midnightPrism, .auroraBloom, .solarPulse, .emeraldFlow, .arcticHalo, .oceanGlass, .roseEmber, .obsidianSpectra, .plasmaOrchid, .verdantMist, .titaniumGlow: return .dynamic\n"
    text = replace_once(
        text,
        dynamic_category,
        dynamic_category
        + "        case .sceneryMountainsDay, .sceneryMountainsNight, .sceneryOceanDay, .sceneryOceanNight, .sceneryDesertDay, .sceneryDesertNight, .sceneryAlpineDay, .sceneryAlpineNight, .sceneryRainforestDay, .sceneryRainforestNight, .sceneryGrasslandDay, .sceneryGrasslandNight, .sceneryVolcanicDay, .sceneryVolcanicNight, .sceneryCanyonDay, .sceneryCanyonNight, .sceneryArcticDay, .sceneryArcticNight, .sceneryCoastalCliffsDay, .sceneryCoastalCliffsNight: return .scenery\n",
        "Scenery categories",
    )

    text = replace_once(
        text,
        '''        case .titaniumGlow: return ("hexagon.fill", "sparkles")
        }''',
        '''        case .titaniumGlow: return ("hexagon.fill", "sparkles")
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
        }''',
        "Scenery artwork exhaustiveness",
    )

    text = replace_once(
        text,
        '''        case .titaniumGlow: return makeThemePalette(0x111820, 0x2d3c4c, 0x222d37, 0x465b6c, 0x9ac9f4, 0xe9f5ff)
        }''',
        '''        case .titaniumGlow: return makeThemePalette(0x111820, 0x2d3c4c, 0x222d37, 0x465b6c, 0x9ac9f4, 0xe9f5ff)
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
        }''',
        "Scenery palettes",
    )

    text = replace_once(
        text,
        '''        case "sapphireTide":
            return .oceanGlass
        default:
            return LifeRouteTheme(rawValue: identifier) ?? .royal''',
        '''        case "sapphireTide":
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
        default:
            return LifeRouteTheme(rawValue: identifier) ?? .royal''',
        "legacy Scenery migration",
    )

    environment = r'''private enum LifeRouteSceneryFamily {
    case mountains
    case ocean
    case desert
    case alpine
    case rainforest
    case grassland
    case volcanic
    case canyon
    case arctic
    case coastalCliffs
}

private struct LifeRouteSceneryMotionSignature {
    let speed: Double
    let drift: CGFloat
    let stillPhase: Double
}

extension LifeRouteTheme {
    fileprivate var sceneryFamily: LifeRouteSceneryFamily? {
        switch self {
        case .sceneryMountainsDay, .sceneryMountainsNight: return .mountains
        case .sceneryOceanDay, .sceneryOceanNight: return .ocean
        case .sceneryDesertDay, .sceneryDesertNight: return .desert
        case .sceneryAlpineDay, .sceneryAlpineNight: return .alpine
        case .sceneryRainforestDay, .sceneryRainforestNight: return .rainforest
        case .sceneryGrasslandDay, .sceneryGrasslandNight: return .grassland
        case .sceneryVolcanicDay, .sceneryVolcanicNight: return .volcanic
        case .sceneryCanyonDay, .sceneryCanyonNight: return .canyon
        case .sceneryArcticDay, .sceneryArcticNight: return .arctic
        case .sceneryCoastalCliffsDay, .sceneryCoastalCliffsNight: return .coastalCliffs
        default: return nil
        }
    }

    fileprivate var sceneryIsNight: Bool {
        switch self {
        case .sceneryMountainsNight, .sceneryOceanNight, .sceneryDesertNight,
             .sceneryAlpineNight, .sceneryRainforestNight, .sceneryGrasslandNight,
             .sceneryVolcanicNight, .sceneryCanyonNight, .sceneryArcticNight,
             .sceneryCoastalCliffsNight:
            return true
        default:
            return false
        }
    }

    fileprivate var sceneryMotionSignature: LifeRouteSceneryMotionSignature {
        switch sceneryFamily {
        case .mountains: return .init(speed: 0.020, drift: 0.060, stillPhase: 0.8)
        case .ocean: return .init(speed: 0.030, drift: 0.045, stillPhase: 1.4)
        case .desert: return .init(speed: 0.016, drift: 0.035, stillPhase: 2.0)
        case .alpine: return .init(speed: 0.018, drift: 0.050, stillPhase: 2.6)
        case .rainforest: return .init(speed: 0.015, drift: 0.032, stillPhase: 1.1)
        case .grassland: return .init(speed: 0.018, drift: 0.040, stillPhase: 1.7)
        case .volcanic: return .init(speed: 0.018, drift: 0.030, stillPhase: 2.3)
        case .canyon: return .init(speed: 0.014, drift: 0.028, stillPhase: 2.9)
        case .arctic: return .init(speed: 0.017, drift: 0.040, stillPhase: 0.5)
        case .coastalCliffs: return .init(speed: 0.024, drift: 0.050, stillPhase: 1.9)
        case nil: return .init(speed: 0.018, drift: 0.040, stillPhase: 0.8)
        }
    }

    var sceneryPreviewPhase: Double { sceneryMotionSignature.stillPhase }

    var sceneryVariantLabel: String {
        isPhaseThreeScenery ? (sceneryIsNight ? "NIGHT" : "DAY") : ""
    }
}

private struct LifeRouteSceneryRidge: Shape {
    let horizon: CGFloat
    let amplitude: CGFloat
    let seed: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let segments = 7
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height * horizon))
        for index in 0...segments {
            let progress = Double(index) / Double(segments)
            let x = rect.width * CGFloat(progress)
            let wave = 0.55 + 0.45 * sin(progress * 11.7 + seed)
            let secondary = 0.5 + 0.5 * sin(progress * 19.3 + seed * 1.7)
            let y = rect.height * horizon - rect.height * amplitude * CGFloat(0.62 * wave + 0.38 * secondary)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct LifeRouteSceneryDune: Shape {
    let horizon: CGFloat
    let amplitude: CGFloat
    let phase: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = rect.height * horizon
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: y))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.52, y: y - rect.height * amplitude * 0.55),
            control1: CGPoint(x: rect.width * 0.16, y: y - rect.height * amplitude * CGFloat(0.85 + 0.08 * sin(phase))),
            control2: CGPoint(x: rect.width * 0.34, y: y + rect.height * amplitude * 0.18)
        )
        path.addCurve(
            to: CGPoint(x: rect.width, y: y - rect.height * amplitude * 0.18),
            control1: CGPoint(x: rect.width * 0.70, y: y - rect.height * amplitude * CGFloat(1.05 + 0.06 * cos(phase))),
            control2: CGPoint(x: rect.width * 0.88, y: y + rect.height * amplitude * 0.08)
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct LifeRouteSceneryWave: Shape {
    let phase: Double
    let verticalBias: CGFloat
    let amplitude: CGFloat
    let frequency: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let segments = 24
        for index in 0...segments {
            let progress = Double(index) / Double(segments)
            let x = rect.width * CGFloat(progress)
            let y = rect.height * verticalBias + CGFloat(sin(progress * Double.pi * 2 * frequency + phase)) * amplitude
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

struct LifeRouteSceneryFrame: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let signature = theme.sceneryMotionSignature
            let driftX = CGFloat(sin(phase * 0.73)) * size.width * signature.drift

            ZStack {
                palette.backgroundGradient
                skyIllumination(size: size)
                celestialBody(size: size)

                if let family = theme.sceneryFamily {
                    sceneryLayers(family: family, size: size, driftX: driftX)
                }

                LinearGradient(
                    colors: [Color.white.opacity(theme.sceneryIsNight ? 0.015 : 0.045), .clear, Color.black.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .compositingGroup()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func skyIllumination(size: CGSize) -> some View {
        RadialGradient(
            colors: [
                palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.10 : 0.22),
                palette.accent.opacity(theme.sceneryIsNight ? 0.04 : 0.10),
                .clear,
            ],
            center: UnitPoint(
                x: CGFloat(0.73 + 0.05 * sin(phase * 0.17)),
                y: CGFloat(0.16 + 0.025 * cos(phase * 0.13))
            ),
            startRadius: 4,
            endRadius: max(size.width, size.height) * 0.68
        )
    }

    private func celestialBody(size: CGSize) -> some View {
        Circle()
            .fill(theme.sceneryIsNight ? Color.white.opacity(0.74) : palette.accentSecondary.opacity(0.66))
            .frame(width: max(42, size.width * 0.13), height: max(42, size.width * 0.13))
            .blur(radius: theme.sceneryIsNight ? 0.7 : 2.2)
            .shadow(color: palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.12 : 0.24), radius: 20)
            .position(x: size.width * 0.78, y: size.height * 0.16)
    }

    @ViewBuilder
    private func sceneryLayers(family: LifeRouteSceneryFamily, size: CGSize, driftX: CGFloat) -> some View {
        switch family {
        case .mountains:
            mountainLayers(size: size, driftX: driftX, alpine: false)
        case .ocean:
            oceanLayers(size: size, driftX: driftX)
        case .desert:
            desertLayers(size: size, driftX: driftX)
        case .alpine:
            mountainLayers(size: size, driftX: driftX, alpine: true)
        case .rainforest:
            rainforestLayers(size: size, driftX: driftX)
        case .grassland:
            grasslandLayers(size: size, driftX: driftX)
        case .volcanic:
            volcanicLayers(size: size, driftX: driftX)
        case .canyon:
            canyonLayers(size: size, driftX: driftX)
        case .arctic:
            arcticLayers(size: size, driftX: driftX)
        case .coastalCliffs:
            coastalLayers(size: size, driftX: driftX)
        }
    }

    private func cloudBand(size: CGSize, driftX: CGFloat, y: CGFloat, opacity: Double) -> some View {
        Capsule()
            .fill(Color.white.opacity(opacity))
            .frame(width: size.width * 0.92, height: max(34, size.height * 0.065))
            .blur(radius: 18)
            .offset(x: driftX, y: size.height * y)
    }

    private func mountainLayers(size: CGSize, driftX: CGFloat, alpine: Bool) -> some View {
        ZStack {
            cloudBand(size: size, driftX: -driftX * 0.65, y: -0.20, opacity: theme.sceneryIsNight ? 0.035 : 0.075)
            LifeRouteSceneryRidge(horizon: 0.69, amplitude: alpine ? 0.29 : 0.24, seed: alpine ? 3.7 : 1.2)
                .fill(palette.panelElevated.opacity(theme.sceneryIsNight ? 0.58 : 0.46))
                .offset(y: size.height * 0.04)
            LifeRouteSceneryRidge(horizon: 0.79, amplitude: alpine ? 0.34 : 0.30, seed: alpine ? 5.1 : 2.6)
                .fill(palette.panel.opacity(theme.sceneryIsNight ? 0.90 : 0.78))
            if alpine {
                LifeRouteSceneryRidge(horizon: 0.69, amplitude: 0.23, seed: 3.7)
                    .stroke(Color.white.opacity(theme.sceneryIsNight ? 0.12 : 0.30), lineWidth: 2.2)
                    .offset(y: size.height * 0.04)
            }
            cloudBand(size: size, driftX: driftX, y: 0.19, opacity: theme.sceneryIsNight ? 0.028 : 0.060)
        }
    }

    private func oceanLayers(size: CGSize, driftX: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [palette.accent.opacity(0.13), palette.panel.opacity(0.72), palette.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: size.height * 0.58)
            .offset(y: size.height * 0.28)
            LifeRouteSceneryWave(phase: phase * 0.72, verticalBias: 0.61, amplitude: 8, frequency: 1.35)
                .stroke(palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.18 : 0.38), lineWidth: 2.2)
            LifeRouteSceneryWave(phase: -phase * 0.58 + 1.8, verticalBias: 0.72, amplitude: 11, frequency: 1.05)
                .stroke(Color.white.opacity(theme.sceneryIsNight ? 0.08 : 0.19), lineWidth: 2.0)
            cloudBand(size: size, driftX: driftX, y: -0.24, opacity: theme.sceneryIsNight ? 0.030 : 0.065)
        }
    }

    private func desertLayers(size: CGSize, driftX: CGFloat) -> some View {
        ZStack {
            cloudBand(size: size, driftX: driftX * 0.55, y: -0.23, opacity: theme.sceneryIsNight ? 0.020 : 0.040)
            LifeRouteSceneryDune(horizon: 0.64, amplitude: 0.20, phase: phase * 0.20)
                .fill(palette.accent.opacity(theme.sceneryIsNight ? 0.17 : 0.28))
            LifeRouteSceneryDune(horizon: 0.76, amplitude: 0.26, phase: -phase * 0.16 + 2.0)
                .fill(palette.panel.opacity(0.82))
            Ellipse()
                .fill(palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.035 : 0.10))
                .frame(width: size.width * 1.1, height: size.height * 0.18)
                .blur(radius: 24)
                .offset(x: -driftX, y: size.height * 0.26)
        }
    }

    private func rainforestLayers(size: CGSize, driftX: CGFloat) -> some View {
        ZStack {
            LifeRouteSceneryRidge(horizon: 0.70, amplitude: 0.17, seed: 6.3)
                .fill(palette.panelElevated.opacity(0.52))
            LifeRouteSceneryRidge(horizon: 0.82, amplitude: 0.22, seed: 8.8)
                .fill(palette.panel.opacity(0.92))
            Ellipse()
                .fill(palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.05 : 0.12))
                .frame(width: size.width * 0.72, height: size.height * 0.22)
                .blur(radius: 26)
                .offset(x: size.width * 0.24 + driftX * 0.35, y: -size.height * 0.20)
            cloudBand(size: size, driftX: driftX * 0.55, y: 0.14, opacity: theme.sceneryIsNight ? 0.035 : 0.075)
            Circle()
                .fill(palette.panel.opacity(0.88))
                .frame(width: size.width * 0.50, height: size.width * 0.50)
                .offset(x: -size.width * 0.42, y: size.height * 0.31)
            Circle()
                .fill(palette.panelElevated.opacity(0.70))
                .frame(width: size.width * 0.42, height: size.width * 0.42)
                .offset(x: size.width * 0.44, y: size.height * 0.27)
        }
    }

    private func grasslandLayers(size: CGSize, driftX: CGFloat) -> some View {
        ZStack {
            cloudBand(size: size, driftX: driftX, y: -0.22, opacity: theme.sceneryIsNight ? 0.028 : 0.070)
            LifeRouteSceneryDune(horizon: 0.68, amplitude: 0.10, phase: phase * 0.12)
                .fill(palette.accent.opacity(theme.sceneryIsNight ? 0.08 : 0.16))
            LifeRouteSceneryDune(horizon: 0.77, amplitude: 0.14, phase: -phase * 0.10 + 1.1)
                .fill(palette.panel.opacity(0.88))
            LinearGradient(
                colors: [.clear, palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.025 : 0.08), .clear],
                startPoint: UnitPoint(x: CGFloat(0.12 + 0.04 * sin(phase * 0.14)), y: 0.45),
                endPoint: .bottomTrailing
            )
        }
    }

    private func volcanicLayers(size: CGSize, driftX: CGFloat) -> some View {
        ZStack {
            RadialGradient(
                colors: [palette.accent.opacity(theme.sceneryIsNight ? 0.30 : 0.18), .clear],
                center: UnitPoint(x: 0.53, y: 0.67),
                startRadius: 4,
                endRadius: size.width * 0.48
            )
            LifeRouteSceneryRidge(horizon: 0.78, amplitude: 0.36, seed: 4.4)
                .fill(palette.panel.opacity(0.94))
            LifeRouteSceneryWave(phase: phase * 0.18, verticalBias: 0.80, amplitude: 4.5, frequency: 0.72)
                .stroke(palette.accent.opacity(theme.sceneryIsNight ? 0.62 : 0.38), lineWidth: 3.0)
                .blur(radius: 1.5)
            Ellipse()
                .fill(Color.white.opacity(theme.sceneryIsNight ? 0.035 : 0.055))
                .frame(width: size.width * 0.52, height: size.height * 0.12)
                .blur(radius: 20)
                .offset(x: driftX * 0.55, y: -size.height * 0.17)
            Ellipse()
                .fill(palette.accent.opacity(0.08))
                .frame(width: size.width * 0.38, height: size.height * 0.10)
                .blur(radius: 16)
                .offset(x: -driftX * 0.40, y: -size.height * 0.11)
        }
    }

    private func canyonLayers(size: CGSize, driftX: CGFloat) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height * 0.28))
                path.addLine(to: CGPoint(x: size.width * 0.28, y: size.height * 0.40))
                path.addLine(to: CGPoint(x: size.width * 0.38, y: size.height * 0.72))
                path.addLine(to: CGPoint(x: size.width * 0.46, y: size.height))
                path.closeSubpath()
            }
            .fill(palette.panel.opacity(0.90))
            Path { path in
                path.move(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.24))
                path.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.38))
                path.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.70))
                path.addLine(to: CGPoint(x: size.width * 0.54, y: size.height))
                path.closeSubpath()
            }
            .fill(palette.panelElevated.opacity(0.82))
            LinearGradient(
                colors: [palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.04 : 0.12), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: size.width * 0.26)
            .blur(radius: 12)
            .offset(x: driftX * 0.20, y: size.height * 0.17)
            cloudBand(size: size, driftX: driftX * 0.65, y: -0.24, opacity: theme.sceneryIsNight ? 0.022 : 0.050)
        }
    }

    private func arcticLayers(size: CGSize, driftX: CGFloat) -> some View {
        ZStack {
            if theme.sceneryIsNight {
                LifeRouteSceneryWave(phase: phase * 0.34, verticalBias: 0.24, amplitude: 18, frequency: 0.72)
                    .stroke(palette.accentSecondary.opacity(0.26), lineWidth: 24)
                    .blur(radius: 14)
                    .blendMode(.screen)
                LifeRouteSceneryWave(phase: -phase * 0.29 + 1.4, verticalBias: 0.30, amplitude: 14, frequency: 0.84)
                    .stroke(palette.accent.opacity(0.18), lineWidth: 18)
                    .blur(radius: 11)
                    .blendMode(.screen)
            } else {
                cloudBand(size: size, driftX: driftX * 0.65, y: -0.22, opacity: 0.080)
            }
            LifeRouteSceneryRidge(horizon: 0.76, amplitude: 0.22, seed: 7.2)
                .fill(Color.white.opacity(theme.sceneryIsNight ? 0.14 : 0.34))
            LifeRouteSceneryRidge(horizon: 0.84, amplitude: 0.17, seed: 9.5)
                .fill(palette.panel.opacity(theme.sceneryIsNight ? 0.82 : 0.68))
            LinearGradient(
                colors: [Color.white.opacity(theme.sceneryIsNight ? 0.05 : 0.17), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: size.height * 0.28)
            .offset(y: size.height * 0.36)
        }
    }

    private func coastalLayers(size: CGSize, driftX: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [palette.accent.opacity(0.08), palette.backgroundBottom.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: size.height * 0.55)
            .offset(y: size.height * 0.31)
            Path { path in
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height * 0.32))
                path.addLine(to: CGPoint(x: size.width * 0.32, y: size.height * 0.48))
                path.addLine(to: CGPoint(x: size.width * 0.42, y: size.height * 0.72))
                path.addLine(to: CGPoint(x: size.width * 0.52, y: size.height))
                path.closeSubpath()
            }
            .fill(palette.panel.opacity(0.92))
            LifeRouteSceneryWave(phase: phase * 0.62, verticalBias: 0.70, amplitude: 7, frequency: 1.18)
                .stroke(Color.white.opacity(theme.sceneryIsNight ? 0.08 : 0.19), lineWidth: 2.0)
            LifeRouteSceneryWave(phase: -phase * 0.54 + 1.2, verticalBias: 0.78, amplitude: 9, frequency: 0.96)
                .stroke(palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.12 : 0.24), lineWidth: 2.0)
            cloudBand(size: size, driftX: driftX, y: -0.20, opacity: theme.sceneryIsNight ? 0.030 : 0.070)
            cloudBand(size: size, driftX: -driftX * 0.55, y: 0.08, opacity: theme.sceneryIsNight ? 0.022 : 0.050)
        }
    }
}

// Phase 3 keeps the historical Dynamic renderer type as a lightweight frame wrapper while moving
// timing ownership to the single shared root environment clock used by Dynamic OR selected Scenery.
struct LifeRouteDynamicGlassEnvironment: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette
    let phase: Double

    var body: some View {
        LifeRouteDynamicGlassFrame(theme: theme, palette: palette, phase: phase)
    }
}

struct LifeRouteLiveThemeEnvironment: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette
    let reduceMotion: Bool
    let isActive: Bool

    var body: some View {
        // v0.7.0 Theme Phase 3 single shared root environment clock. Only the selected live
        // environment is mounted; Reduce Motion and inactive/background lifecycle pause the schedule.
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 20.0,
                paused: reduceMotion || !isActive
            )
        ) { context in
            liveFrame(at: context.date)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func liveFrame(at date: Date) -> some View {
        if theme.isPhaseTwoDynamic {
            let signature = theme.dynamicMotionSignature
            let livePhase = date.timeIntervalSinceReferenceDate * signature.speed
            LifeRouteDynamicGlassEnvironment(
                theme: theme,
                palette: palette,
                phase: reduceMotion ? signature.stillPhase : livePhase
            )
        } else if theme.isPhaseThreeScenery {
            let signature = theme.sceneryMotionSignature
            let livePhase = date.timeIntervalSinceReferenceDate * signature.speed
            LifeRouteSceneryFrame(
                theme: theme,
                palette: palette,
                phase: reduceMotion ? signature.stillPhase : livePhase
            )
        }
    }
}

private struct LifeRouteChromeModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.lifeRouteTheme) private var theme

    func body(content: Content) -> some View {
        // v0.7.0 Theme Phase 3 persistent environment host: one mount above the five-tab shell.
        ZStack {
            if theme.isPhaseOneCoreGlass {
                LifeRouteCoreGlassEnvironment(theme: theme, palette: palette)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            } else if theme.isPhaseTwoDynamic || theme.isPhaseThreeScenery {
                LifeRouteLiveThemeEnvironment(
                    theme: theme,
                    palette: palette,
                    reduceMotion: reduceMotion,
                    isActive: scenePhase == .active
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            } else {
                // Non-user-facing retired themes retain a deterministic fallback while stored
                // Dynamic/Scenery selections are migrated into the approved catalogs.
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

'''

    text = replace_region(
        text,
        "struct LifeRouteDynamicGlassEnvironment: View {",
        "private struct LifeRouteThemeBackdrop: View {",
        environment,
        "single-clock Dynamic + Scenery environment host",
    )

    APP.write_text(text, encoding="utf-8")


def patch_theme_center() -> None:
    text = THEMES.read_text(encoding="utf-8")
    if "v0.7.0 Theme Phase 3 Theme Center" in text:
        return

    required = [
        "v0.7.0 Theme Phase 2 Theme Center",
        "LifeRouteTheme.phaseOneCoreGlassCatalog",
        "LifeRouteTheme.phaseTwoDynamicCatalog",
        "private let sceneryThemes: [LifeRouteTheme] = [.mountain, .ocean, .space, .desert, .forest, .sunshine]",
        "LifeRouteDynamicGlassFrame(",
        "phase: theme.dynamicPreviewPhase",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Theme Phase 3 patch failed: Phase 2 Theme Center baseline missing {missing}")

    final = r'''import SwiftUI

struct V054ThemeCenterView: View {
    // v0.7.0 Theme Phase 3 Theme Center: exactly 12 Core + 12 Dynamic + 20 Scenery themes.
    @Environment(\.lifeRoutePalette) private var palette
    @EnvironmentObject private var themeStore: LifeRouteThemeStore

    @State private var selectedCategory: ThemeFilter = .core

    private enum ThemeFilter: String, CaseIterable, Identifiable {
        case core = "Core"
        case dynamic = "Dynamic"
        case scenery = "Scenery"

        var id: String { rawValue }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                selectedThemeHeader
                categoryStrip

                HStack {
                    LifeRouteSectionLabel(title: sectionTitle)
                    Spacer()
                    Text("\(filteredThemes.count)")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(palette.accentSecondary)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(filteredThemes) { theme in
                        themeCard(theme)
                    }
                }

                Label(sectionDescription, systemImage: sectionIcon)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedCategory = category(for: themeStore.selectedTheme)
        }
        .onChange(of: themeStore.selectedTheme) { theme in
            selectedCategory = category(for: theme)
        }
    }

    private var filteredThemes: [LifeRouteTheme] {
        switch selectedCategory {
        case .core:
            return LifeRouteTheme.phaseOneCoreGlassCatalog
        case .dynamic:
            return LifeRouteTheme.phaseTwoDynamicCatalog
        case .scenery:
            return LifeRouteTheme.phaseThreeSceneryCatalog
        }
    }

    private var sectionTitle: String {
        switch selectedCategory {
        case .core: return "Core Glass"
        case .dynamic: return "Dynamic Liquid Glass"
        case .scenery: return "Scenery"
        }
    }

    private var sectionDescription: String {
        switch selectedCategory {
        case .core:
            return "12 still app-wide glass environments with no continuous ambient motion."
        case .dynamic:
            return "12 slow, full-frame liquid-glass environments. Reduce Motion retains a still equivalent."
        case .scenery:
            return "20 cinematic environments across 10 families, with Day and Night selected independently. Reduce Motion keeps the chosen scene and freezes ambient motion."
        }
    }

    private var sectionIcon: String {
        switch selectedCategory {
        case .core: return "sparkles"
        case .dynamic: return "waveform.path"
        case .scenery: return "mountain.2.fill"
        }
    }

    private func category(for theme: LifeRouteTheme) -> ThemeFilter {
        if theme.isPhaseOneCoreGlass { return .core }
        if theme.isPhaseTwoDynamic { return .dynamic }
        if theme.isPhaseThreeScenery { return .scenery }
        return .core
    }

    private var selectedThemeHeader: some View {
        HStack(spacing: 12) {
            themePreview(themeStore.selectedTheme)
                .frame(width: 82, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(themeStore.selectedTheme.palette.accent.opacity(0.42), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIVE THEME")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(palette.accentSecondary)
                Text(themeStore.selectedTheme.name)
                    .font(.title3.weight(.black))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                HStack(spacing: 5) {
                    Text(category(for: themeStore.selectedTheme).rawValue)
                    if themeStore.selectedTheme.isPhaseTwoDynamic {
                        Image(systemName: "waveform.path")
                            .accessibilityHidden(true)
                    } else if themeStore.selectedTheme.isPhaseThreeScenery {
                        Text(themeStore.selectedTheme.sceneryVariantLabel)
                            .font(.caption2.weight(.black))
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 4)

            Image(systemName: "checkmark.circle.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)
        }
        .padding(12)
        .background(palette.panel.opacity(0.42), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accent.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active theme, \(themeStore.selectedTheme.name), \(category(for: themeStore.selectedTheme).rawValue)")
    }

    private var categoryStrip: some View {
        HStack(spacing: 7) {
            ForEach(ThemeFilter.allCases) { filter in
                Button {
                    selectedCategory = filter
                    LifeRouteHaptics.selection()
                } label: {
                    LifeRoutePill(title: filter.rawValue, isSelected: selectedCategory == filter)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .frame(minHeight: LifeRouteDesign.Layout.minimumTouchTarget)
                .accessibilityLabel("\(filter.rawValue) themes")
                .accessibilityValue(selectedCategory == filter ? "Selected" : "Not selected")
            }
        }
    }

    private func themeCard(_ theme: LifeRouteTheme) -> some View {
        let selected = themeStore.selectedTheme == theme
        let coreGlass = theme.isPhaseOneCoreGlass
        let dynamicGlass = theme.isPhaseTwoDynamic
        let scenery = theme.isPhaseThreeScenery

        return Button {
            themeStore.selectedTheme = theme
            LifeRouteHaptics.success()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    themePreview(theme)
                        .frame(height: 78)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    if coreGlass || dynamicGlass || scenery {
                        HStack(spacing: 4) {
                            if dynamicGlass {
                                Image(systemName: "waveform.path")
                                    .font(.system(size: 8, weight: .black))
                            } else if scenery {
                                Image(systemName: theme.sceneryVariantLabel == "NIGHT" ? "moon.stars.fill" : "sun.max.fill")
                                    .font(.system(size: 8, weight: .black))
                            }
                            Text(coreGlass ? "STILL" : (dynamicGlass ? "LIVE" : theme.sceneryVariantLabel))
                                .font(.system(size: 8, weight: .black))
                                .tracking(0.7)
                        }
                        .foregroundStyle(.white.opacity(0.90))
                        .padding(.horizontal, 6)
                        .frame(minHeight: 22)
                        .background(Color.black.opacity(0.30), in: Capsule())
                        .padding(7)
                    }

                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline.weight(.black))
                            .foregroundStyle(theme.palette.accentSecondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                }

                Text(theme.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)

                Text(coreGlass ? "CORE GLASS" : (dynamicGlass ? "DYNAMIC GLASS" : "SCENERY"))
                    .font(.caption2.weight(.black))
                    .tracking(0.5)
                    .foregroundStyle(selected ? palette.accentSecondary : palette.textSecondary)
            }
            .padding(9)
            .background(selected ? palette.panelElevated.opacity(0.50) : palette.panel.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? palette.accent.opacity(0.72) : Color.white.opacity(0.07), lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 132)
        .accessibilityLabel("Use \(theme.name) theme")
        .accessibilityValue(selected ? "Selected" : (dynamicGlass || scenery ? "Ambient theme" : "Not selected"))
    }

    @ViewBuilder
    private func themePreview(_ theme: LifeRouteTheme) -> some View {
        if theme.isPhaseOneCoreGlass {
            LifeRouteCoreGlassEnvironment(theme: theme, palette: theme.palette)
        } else if theme.isPhaseTwoDynamic {
            // Static representative snapshot only: the grid never starts competing timelines.
            LifeRouteDynamicGlassFrame(
                theme: theme,
                palette: theme.palette,
                phase: theme.dynamicPreviewPhase
            )
        } else if theme.isPhaseThreeScenery {
            // All 20 Scenery thumbnails are deterministic still frames; only the selected root scene can animate.
            LifeRouteSceneryFrame(
                theme: theme,
                palette: theme.palette,
                phase: theme.sceneryPreviewPhase
            )
        } else {
            ZStack {
                theme.palette.backgroundGradient
                LifeRouteThemeArtwork(theme: theme, palette: theme.palette, compact: true)
            }
        }
    }
}

private extension LifeRouteTheme {
    var dynamicPreviewPhase: Double {
        switch self {
        case .royalCurrent: return 0.7
        case .midnightPrism: return 1.4
        case .auroraBloom: return 2.1
        case .solarPulse: return 0.2
        case .emeraldFlow: return 1.8
        case .arcticHalo: return 2.7
        case .oceanGlass: return 1.1
        case .roseEmber: return 2.4
        case .obsidianSpectra: return 0.9
        case .plasmaOrchid: return 1.6
        case .verdantMist: return 2.9
        case .titaniumGlow: return 0.4
        default: return 0.8
        }
    }
}
'''

    THEMES.write_text(final, encoding="utf-8")


def main() -> None:
    patch_app()
    patch_theme_center()
    print(
        "LifeRoute v0.7.0 Theme Phase 3 applied: 20 stable user-selectable Scenery Day/Night identities now render as native cinematic environments from the single persistent app-wide clock, with deterministic legacy migration, static Theme Center previews, Reduce Motion still frames, lifecycle pausing, and the protected 12 Core / 12 Dynamic catalogs unchanged."
    )


if __name__ == "__main__":
    main()
