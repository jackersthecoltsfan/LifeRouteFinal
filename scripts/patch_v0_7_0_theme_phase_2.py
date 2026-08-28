#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute/LifeRouteApp.swift"
THEMES = ROOT / "LifeRoute/V054ThemeCenterView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 Theme Phase 2 patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def replace_region(text: str, start_token: str, end_token: str, replacement: str, label: str) -> str:
    try:
        start = text.index(start_token)
        end = text.index(end_token, start)
    except ValueError as exc:
        raise SystemExit(f"v0.7.0 Theme Phase 2 patch failed: {label} boundary missing") from exc
    return text[:start] + replacement + text[end:]


def patch_app() -> None:
    text = APP.read_text(encoding="utf-8")
    if "v0.7.0 Theme Phase 2 Dynamic Liquid Glass catalog" in text:
        return

    required = [
        "v0.7.0 Theme Phase 1 Core Glass catalog",
        "static let phaseOneCoreGlassCatalog",
        "struct LifeRouteCoreGlassEnvironment: View",
        "v0.7.0 Theme Phase 1 persistent environment host",
        "private static func resolveStoredTheme(_ identifier: String?) -> LifeRouteTheme",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Theme Phase 2 patch failed: Phase 1 baseline missing {missing}")

    text = replace_once(
        text,
        '    case coreEmber = "core.ember"\n',
        '''    case coreEmber = "core.ember"

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
''',
        "stable Dynamic identifiers",
    )

    text = replace_once(
        text,
        '''    var isPhaseOneCoreGlass: Bool {
        Self.phaseOneCoreGlassCatalog.contains(self)
    }
''',
        '''    var isPhaseOneCoreGlass: Bool {
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
''',
        "approved Dynamic catalog",
    )

    text = replace_once(
        text,
        '''        case .coreEmber: return "Ember"
        }''',
        '''        case .coreEmber: return "Ember"
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
        }''',
        "Dynamic theme names",
    )

    text = replace_once(
        text,
        "        case .solarFlare, .electricStorm, .ultraviolet, .arcticPulse: return .dynamic\n",
        "        case .solarFlare, .electricStorm, .ultraviolet, .arcticPulse, .royalCurrent, .midnightPrism, .auroraBloom, .solarPulse, .emeraldFlow, .arcticHalo, .oceanGlass, .roseEmber, .obsidianSpectra, .plasmaOrchid, .verdantMist, .titaniumGlow: return .dynamic\n",
        "Dynamic categories",
    )

    text = replace_once(
        text,
        '''        case .coreEmber: return ("flame.fill", "circle.fill")
        }''',
        '''        case .coreEmber: return ("flame.fill", "circle.fill")
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
        }''',
        "Dynamic artwork exhaustiveness",
    )

    text = replace_once(
        text,
        '''        case .coreEmber: return makeThemePalette(0x240807, 0x57120d, 0x35100d, 0x6e1c13, 0xff4d32, 0xffa05d)
        }''',
        '''        case .coreEmber: return makeThemePalette(0x240807, 0x57120d, 0x35100d, 0x6e1c13, 0xff4d32, 0xffa05d)
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
        }''',
        "Dynamic palettes",
    )

    text = replace_once(
        text,
        '''        case "light":
            return .arctic
        default:
            return LifeRouteTheme(rawValue: identifier) ?? .royal''',
        '''        case "light":
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
            return LifeRouteTheme(rawValue: identifier) ?? .royal''',
        "legacy Dynamic migration",
    )

    dynamic_environment = r'''struct LifeRouteLiquidRibbon: Shape {
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

private struct LifeRouteDynamicMotionSignature {
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
                palette.backgroundGradient

                RadialGradient(
                    colors: [palette.accent.opacity(0.30), palette.accent.opacity(0.06), .clear],
                    center: UnitPoint(
                        x: 0.72 + 0.14 * cos(phase * 0.41),
                        y: 0.18 + 0.09 * sin(phase * 0.33)
                    ),
                    startRadius: 5,
                    endRadius: longSide * 0.68
                )

                RadialGradient(
                    colors: [palette.accentSecondary.opacity(0.20), .clear],
                    center: UnitPoint(
                        x: 0.22 + 0.12 * sin(phase * 0.29),
                        y: 0.76 + 0.08 * cos(phase * 0.37)
                    ),
                    startRadius: 8,
                    endRadius: longSide * 0.58
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
                        Color.white.opacity(0.055),
                        .clear,
                        palette.accentSecondary.opacity(0.025),
                        .clear,
                    ],
                    startPoint: UnitPoint(x: 0.16 + 0.05 * sin(phase * 0.22), y: 0),
                    endPoint: UnitPoint(x: 0.84 + 0.05 * cos(phase * 0.22), y: 1)
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

'''
    text = replace_region(
        text,
        "private struct LifeRouteChromeModifier: ViewModifier {",
        "private struct LifeRouteThemeBackdrop: View {",
        dynamic_environment,
        "Phase 2 dynamic environment host",
    )

    APP.write_text(text, encoding="utf-8")


def patch_theme_center() -> None:
    text = THEMES.read_text(encoding="utf-8")
    if "v0.7.0 Theme Phase 2 Theme Center" in text:
        return

    required = [
        "v0.7.0 Theme Phase 1 Theme Center",
        "LifeRouteTheme.phaseOneCoreGlassCatalog",
        "private let dynamicThemes: [LifeRouteTheme] = [.solarFlare, .electricStorm, .ultraviolet, .arcticPulse, .aurora, .sapphireTide]",
        "private let sceneryThemes: [LifeRouteTheme] = [.mountain, .ocean, .space, .desert, .forest, .sunshine]",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Theme Phase 2 patch failed: Phase 1 Theme Center baseline missing {missing}")

    final = r'''import SwiftUI

struct V054ThemeCenterView: View {
    // v0.7.0 Theme Phase 2 Theme Center: 12 still Core Glass + 12 live Dynamic Liquid Glass.
    @Environment(\.lifeRoutePalette) private var palette
    @EnvironmentObject private var themeStore: LifeRouteThemeStore

    @State private var selectedCategory: ThemeFilter = .core

    private enum ThemeFilter: String, CaseIterable, Identifiable {
        case core = "Core"
        case dynamic = "Dynamic"
        case scenery = "Scenery"

        var id: String { rawValue }
    }

    // Scenery remains exactly the validated pre-Phase-3 catalog until the dedicated scenery phase.
    private let sceneryThemes: [LifeRouteTheme] = [.mountain, .ocean, .space, .desert, .forest, .sunshine]

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
            return sceneryThemes
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
            return "12 slow, ambient liquid-glass environments. Reduce Motion keeps the selected theme but renders a still equivalent."
        case .scenery:
            return "Scenery is retained unchanged until its dedicated Phase 3 renderer."
        }
    }

    private var sectionIcon: String {
        switch selectedCategory {
        case .core: return "sparkles"
        case .dynamic: return "waveform.path"
        case .scenery: return "clock.arrow.circlepath"
        }
    }

    private func category(for theme: LifeRouteTheme) -> ThemeFilter {
        if theme.isPhaseOneCoreGlass { return .core }
        if theme.isPhaseTwoDynamic { return .dynamic }
        if sceneryThemes.contains(theme) { return .scenery }
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
                HStack(spacing: 5) {
                    Text(category(for: themeStore.selectedTheme).rawValue)
                    if themeStore.selectedTheme.isPhaseTwoDynamic {
                        Image(systemName: "waveform.path")
                            .accessibilityHidden(true)
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
        .background(palette.panel.opacity(0.52), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

        return Button {
            themeStore.selectedTheme = theme
            LifeRouteHaptics.success()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    themePreview(theme)
                        .frame(height: 78)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    if coreGlass || dynamicGlass {
                        HStack(spacing: 4) {
                            if dynamicGlass {
                                Image(systemName: "waveform.path")
                                    .font(.system(size: 8, weight: .black))
                            }
                            Text(dynamicGlass ? "LIVE" : "STILL")
                                .font(.system(size: 8, weight: .black))
                                .tracking(0.7)
                        }
                        .foregroundStyle(.white.opacity(0.86))
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
                    .minimumScaleFactor(0.78)

                Text(coreGlass ? "CORE GLASS" : (dynamicGlass ? "DYNAMIC GLASS" : "SCENERY"))
                    .font(.caption2.weight(.black))
                    .tracking(0.5)
                    .foregroundStyle(selected ? palette.accentSecondary : palette.textSecondary)
            }
            .padding(9)
            .background(selected ? palette.panelElevated.opacity(0.56) : palette.panel.opacity(0.42), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? palette.accent.opacity(0.72) : Color.white.opacity(0.07), lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 132)
        .accessibilityLabel("Use \(theme.name) theme")
        .accessibilityValue(selected ? "Selected" : (dynamicGlass ? "Animated theme" : "Not selected"))
    }

    @ViewBuilder
    private func themePreview(_ theme: LifeRouteTheme) -> some View {
        if theme.isPhaseOneCoreGlass {
            LifeRouteCoreGlassEnvironment(theme: theme, palette: theme.palette)
        } else if theme.isPhaseTwoDynamic {
            // Static representative snapshot only: the grid never starts 12 competing timelines.
            LifeRouteDynamicGlassFrame(
                theme: theme,
                palette: theme.palette,
                phase: theme.dynamicPreviewPhase
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
        "LifeRoute v0.7.0 Theme Phase 2 applied: the 12 approved Dynamic Liquid Glass themes use stable identifiers, one root system-driven timeline, low-layer flowing ribbons/refraction highlights, deterministic migration from legacy Dynamic IDs, Reduce Motion still equivalents, inactive/background pausing, and static Theme Center previews while Core Glass and pre-Phase-3 Scenery remain protected."
    )


if __name__ == "__main__":
    main()
