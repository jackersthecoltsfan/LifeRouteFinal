#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute/LifeRouteApp.swift"
TODAY = ROOT / "LifeRoute/V054TodayView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.1 theme visual runtime patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


ROYAL_CURRENT_RENDERER = r'''// v0.7.1 Royal Current exemplar: broad layered glass-current artwork driven only by the root phase.
private struct LifeRouteRoyalCurrentBand: Shape {
    let phase: Double
    let verticalBias: CGFloat
    let amplitude: CGFloat
    let thickness: CGFloat
    let frequency: Double
    let shoulder: Double

    func path(in rect: CGRect) -> Path {
        let samples = 36

        func waveY(_ index: Int, lowerEdge: Bool) -> CGFloat {
            let progress = Double(index) / Double(samples)
            let primary = sin(progress * Double.pi * 2 * frequency + phase)
            let secondary = sin(progress * Double.pi * frequency * 1.72 + phase * 0.61 + shoulder) * 0.34
            let taper = 0.72 + 0.28 * sin(progress * Double.pi)
            let center = rect.height * verticalBias + CGFloat(primary + secondary) * amplitude
            return center + (lowerEdge ? thickness * CGFloat(taper) : 0)
        }

        var path = Path()
        for index in 0...samples {
            let x = rect.width * CGFloat(index) / CGFloat(samples)
            let point = CGPoint(x: x, y: waveY(index, lowerEdge: false))
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        for index in stride(from: samples, through: 0, by: -1) {
            let x = rect.width * CGFloat(index) / CGFloat(samples)
            path.addLine(to: CGPoint(x: x, y: waveY(index, lowerEdge: true)))
        }
        path.closeSubpath()
        return path
    }
}

private struct LifeRouteRoyalCurrentFrame: View {
    let palette: LifeRouteThemePalette
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let longSide = max(size.width, size.height)
            let pulse = 0.5 + 0.5 * sin(phase * 0.82)
            let drift = sin(phase * 0.64)

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.004, green: 0.025, blue: 0.085),
                        Color(red: 0.012, green: 0.105, blue: 0.245),
                        Color(red: 0.005, green: 0.035, blue: 0.105),
                    ],
                    startPoint: UnitPoint(x: 0.08, y: CGFloat(0.02 + 0.04 * pulse)),
                    endPoint: UnitPoint(x: CGFloat(0.92 - 0.05 * drift), y: 1)
                )

                RadialGradient(
                    colors: [
                        palette.accentSecondary.opacity(0.40),
                        palette.accent.opacity(0.16),
                        Color.clear,
                    ],
                    center: UnitPoint(x: CGFloat(0.28 + 0.08 * drift), y: 0.30),
                    startRadius: 2,
                    endRadius: longSide * 0.68
                )
                .blendMode(.screen)

                RadialGradient(
                    colors: [
                        Color(red: 0.10, green: 0.62, blue: 1.0).opacity(0.34),
                        Color.clear,
                    ],
                    center: UnitPoint(x: CGFloat(0.78 - 0.07 * drift), y: 0.70),
                    startRadius: 4,
                    endRadius: longSide * 0.62
                )
                .blendMode(.screen)

                LifeRouteRoyalCurrentBand(
                    phase: phase * 0.86,
                    verticalBias: 0.24,
                    amplitude: max(72, size.height * 0.12),
                    thickness: max(142, size.height * 0.22),
                    frequency: 0.58,
                    shoulder: 0.30
                )
                .fill(
                    LinearGradient(
                        colors: [
                            palette.backgroundBottom.opacity(0.18),
                            Color(red: 0.10, green: 0.52, blue: 0.96).opacity(0.54),
                            Color.white.opacity(0.32),
                            palette.accentSecondary.opacity(0.48),
                            palette.accent.opacity(0.20),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .blur(radius: 2.5)
                .rotationEffect(.degrees(-9 + drift * 2.2))
                .offset(x: -size.width * 0.04, y: -size.height * 0.04)
                .shadow(color: palette.accentSecondary.opacity(0.25), radius: 24)

                LifeRouteRoyalCurrentBand(
                    phase: -phase * 0.72 + 2.15,
                    verticalBias: 0.52,
                    amplitude: max(84, size.height * 0.14),
                    thickness: max(126, size.height * 0.19),
                    frequency: 0.52,
                    shoulder: 1.20
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            palette.accent.opacity(0.30),
                            Color.white.opacity(0.18),
                            Color(red: 0.05, green: 0.40, blue: 0.92).opacity(0.46),
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 4)
                .rotationEffect(.degrees(8 - drift * 1.8))
                .offset(x: size.width * 0.07, y: size.height * 0.02)
                .blendMode(.screen)

                LifeRouteRoyalCurrentBand(
                    phase: phase * 0.68 + 0.45,
                    verticalBias: 0.25,
                    amplitude: max(72, size.height * 0.12),
                    thickness: max(142, size.height * 0.22),
                    frequency: 0.58,
                    shoulder: 0.30
                )
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            palette.accentSecondary.opacity(0.88),
                            Color.white.opacity(0.96),
                            palette.accent.opacity(0.86),
                            Color.clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 0.8)
                .rotationEffect(.degrees(-9 + drift * 2.2))
                .offset(x: -size.width * 0.04, y: -size.height * 0.04)
                .blendMode(.screen)

                LifeRouteRoyalCurrentBand(
                    phase: -phase * 0.66 + 2.50,
                    verticalBias: 0.52,
                    amplitude: max(84, size.height * 0.14),
                    thickness: max(126, size.height * 0.19),
                    frequency: 0.52,
                    shoulder: 1.20
                )
                .stroke(
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.78), palette.accentSecondary.opacity(0.76), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 1.1)
                .rotationEffect(.degrees(8 - drift * 1.8))
                .offset(x: size.width * 0.07, y: size.height * 0.02)
                .blendMode(.screen)

                Ellipse()
                    .trim(from: 0.08, to: 0.78)
                    .stroke(
                        AngularGradient(
                            colors: [Color.clear, palette.accent.opacity(0.80), Color.white.opacity(0.90), Color(red: 0.12, green: 0.62, blue: 1.0).opacity(0.70), Color.clear],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: max(8, size.width * 0.025), lineCap: .round)
                    )
                    .frame(width: size.width * 1.18, height: size.height * 0.48)
                    .rotationEffect(.degrees(-24 + drift * 4.0))
                    .offset(x: -size.width * 0.20, y: -size.height * 0.14)
                    .blur(radius: 3.5)
                    .blendMode(.screen)

                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.clear, palette.accent.opacity(0.05), Color.clear],
                    startPoint: UnitPoint(x: CGFloat(0.10 + 0.05 * drift), y: 0),
                    endPoint: UnitPoint(x: CGFloat(0.88 - 0.04 * drift), y: 1)
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

'''


CANYON_RENDERER = r'''// v0.7.1 Canyon Day exemplar: the bundled scene is authoritative; SwiftUI adds only restrained ambience.
private struct LifeRouteCanyonDayAssetFrame: View {
    let palette: LifeRouteThemePalette
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let drift = sin(phase * 6.4)
            let haze = 0.5 + 0.5 * cos(phase * 3.8)

            ZStack {
                Image(decorative: "SceneryCanyonDay")
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(1.035)
                    .offset(x: drift * 3.2, y: drift * 1.4)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.16),
                        Color.clear,
                        Color.clear,
                        Color.black.opacity(0.34),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        palette.accentSecondary.opacity(0.10 + haze * 0.05),
                        palette.accent.opacity(0.035),
                        Color.clear,
                    ],
                    center: UnitPoint(x: CGFloat(0.70 + drift * 0.012), y: 0.24),
                    startRadius: 3,
                    endRadius: max(size.width, size.height) * 0.58
                )
                .blendMode(.screen)

                Capsule()
                    .fill(Color.white.opacity(0.035 + haze * 0.018))
                    .frame(width: size.width * 1.10, height: max(44, size.height * 0.075))
                    .blur(radius: 22)
                    .offset(x: drift * 8, y: -size.height * 0.09)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .compositingGroup()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

'''


VISUAL_FIXTURES = r'''#if DEBUG
private enum LifeRouteVisualFixture: String {
    case canyonDay = "canyon-day"
    case royalCurrent = "royal-current"

    static var current: LifeRouteVisualFixture? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let keyIndex = arguments.firstIndex(of: "-LifeRouteVisualFixture") else { return nil }
        let valueIndex = arguments.index(after: keyIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return LifeRouteVisualFixture(rawValue: arguments[valueIndex])
    }

    var theme: LifeRouteTheme {
        switch self {
        case .canyonDay: return .sceneryCanyonDay
        case .royalCurrent: return .royalCurrent
        }
    }
}

private struct LifeRouteVisualFixtureView: View {
    let fixture: LifeRouteVisualFixture

    var body: some View {
        LifeRouteLiveThemeEnvironment(
            theme: fixture.theme,
            palette: fixture.theme.palette,
            reduceMotion: false,
            isActive: true
        )
        .ignoresSafeArea()
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
    }
}
#endif

'''


TODAY_SURFACES = r'''// v0.7.1 Today exemplar surfaces: native Liquid Glass on iOS 26 with an availability-safe material fallback.
private struct LifeRouteTodayGlassCardModifier: ViewModifier {
    @Environment(\.lifeRoutePalette) private var palette

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(LifeRouteDesign.Spacing.comfortable)
                .glassEffect(
                    .regular.tint(palette.panel.opacity(0.16)),
                    in: .rect(cornerRadius: LifeRouteDesign.Radius.card)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: LifeRouteDesign.Stroke.subtle)
                }
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
        } else {
            content
                .padding(LifeRouteDesign.Spacing.comfortable)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous))
                .background(
                    palette.panel.opacity(0.18),
                    in: RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.card, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: LifeRouteDesign.Stroke.subtle)
                }
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
        }
    }
}

private struct LifeRouteTodayQuickActionsContainerModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                content
            }
        } else {
            content
        }
    }
}

private struct LifeRouteTodayQuickActionSurfaceModifier: ViewModifier {
    let accent: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(.horizontal, 3)
                .padding(.vertical, 5)
                .glassEffect(
                    .regular.tint(accent.opacity(0.12)).interactive(),
                    in: .rect(cornerRadius: 14)
                )
        } else {
            content
                .padding(.horizontal, 3)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(accent.opacity(0.16), lineWidth: LifeRouteDesign.Stroke.subtle)
                }
        }
    }
}

'''


APP_ENTRY = r'''@main
struct LifeRouteApp: App {
    @StateObject private var themeStore = LifeRouteThemeStore()

    var body: some Scene {
        WindowGroup {
#if DEBUG
            if let fixture = LifeRouteVisualFixture.current {
                LifeRouteVisualFixtureView(fixture: fixture)
            } else {
                appContent
            }
#else
            appContent
#endif
        }
    }

    private var appContent: some View {
        ContentView()
            .lifeRouteChrome()
            .environmentObject(themeStore)
            .environment(\.lifeRoutePalette, themeStore.palette)
            .environment(\.lifeRouteTheme, themeStore.selectedTheme)
    }
}
'''


def patch_app() -> None:
    text = APP.read_text(encoding="utf-8")
    if "v0.7.1 Royal Current exemplar" in text:
        return

    required = [
        "struct LifeRouteDynamicGlassFrame: View",
        "struct LifeRouteSceneryFrame: View",
        "struct LifeRouteLiveThemeEnvironment: View",
        "case sceneryCanyonDay = \"scenery.canyon.day\"",
        "case royalCurrent = \"dynamic.royalCurrent\"",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.1 theme visual runtime patch failed: final v0.7.0 app baseline missing {missing}")

    text = replace_once(
        text,
        "struct LifeRouteDynamicGlassFrame: View {",
        ROYAL_CURRENT_RENDERER + "struct LifeRouteDynamicGlassFrame: View {",
        "Royal Current renderer insertion",
    )
    text = replace_once(
        text,
        '''struct LifeRouteDynamicGlassFrame: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette
    let phase: Double

    var body: some View {
        GeometryReader { proxy in''',
        '''struct LifeRouteDynamicGlassFrame: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette
    let phase: Double

    @ViewBuilder
    var body: some View {
        if theme == .royalCurrent {
            LifeRouteRoyalCurrentFrame(palette: palette, phase: phase)
        } else {
            legacyFrame
        }
    }

    private var legacyFrame: some View {
        GeometryReader { proxy in''',
        "Royal Current exemplar dispatch",
    )

    text = replace_once(
        text,
        "struct LifeRouteSceneryFrame: View {",
        CANYON_RENDERER + "struct LifeRouteSceneryFrame: View {",
        "Canyon renderer insertion",
    )
    text = replace_once(
        text,
        '''struct LifeRouteSceneryFrame: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette
    let phase: Double

    var body: some View {
        GeometryReader { proxy in''',
        '''struct LifeRouteSceneryFrame: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette
    let phase: Double

    @ViewBuilder
    var body: some View {
        if theme == .sceneryCanyonDay {
            LifeRouteCanyonDayAssetFrame(palette: palette, phase: phase)
        } else {
            legacyFrame
        }
    }

    private var legacyFrame: some View {
        GeometryReader { proxy in''',
        "Canyon Day exemplar dispatch",
    )

    text = replace_once(
        text,
        "private struct LifeRouteChromeModifier: ViewModifier {",
        VISUAL_FIXTURES + "private struct LifeRouteChromeModifier: ViewModifier {",
        "debug visual fixture insertion",
    )

    app_entry_start = text.index("@main\nstruct LifeRouteApp: App {")
    text = text[:app_entry_start] + APP_ENTRY
    APP.write_text(text, encoding="utf-8")


def patch_today() -> None:
    text = TODAY.read_text(encoding="utf-8")
    if "v0.7.1 Today exemplar surfaces" in text:
        return

    required = [
        "LifeRouteTodayHeroScene()",
        'Text("Life")',
        'Text("Route")',
        "ForEach(selectedDayEvents)",
        "private struct LifeRouteTodayHeroScene: View",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.1 theme visual runtime patch failed: final v0.7.0 Today baseline missing {missing}")

    text = replace_once(text, "import SwiftUI\n\n", "import SwiftUI\n\n" + TODAY_SURFACES, "Today glass surface insertion")
    text = replace_once(
        text,
        "            LifeRouteTodayHeroScene()",
        "            // v0.7.1 Today uses the persistent root environment as its only hero artwork.\n            Color.clear",
        "Today competing hero removal",
    )
    text = text.replace(".lifeRouteCard()", ".modifier(LifeRouteTodayGlassCardModifier())")

    quick_start = text.index("    private var quickActions: some View {")
    quick_end = text.index("    private var overviewCard: some View {", quick_start)
    quick = text[quick_start:quick_end]
    quick = replace_once(
        quick,
        "            }\n        }\n    }\n\n",
        "            }\n            .modifier(LifeRouteTodayQuickActionsContainerModifier())\n        }\n    }\n\n",
        "Today quick action glass container",
    )
    text = text[:quick_start] + quick + text[quick_end:]

    label_start = text.index("    private func quickActionLabel(")
    label_end = text.index("    private func overviewMetric(", label_start)
    label = text[label_start:label_end]
    label = replace_once(
        label,
        "        .contentShape(Rectangle())\n",
        "        .contentShape(Rectangle())\n        .modifier(LifeRouteTodayQuickActionSurfaceModifier(accent: accent))\n",
        "Today quick action glass surface",
    )
    text = text[:label_start] + label + text[label_end:]

    legacy_hero_start = text.index("\nprivate struct LifeRouteTodayHeroScene: View {")
    text = text[:legacy_hero_start].rstrip() + "\n"
    TODAY.write_text(text, encoding="utf-8")


def main() -> None:
    patch_app()
    patch_today()
    print(
        "LifeRoute v0.7.1 exemplar runtime applied: Canyon Day uses bundled cinematic artwork, "
        "Royal Current uses broad layered glass currents, Today reveals the shared root environment, "
        "and iOS 26 uses availability-gated native Liquid Glass surfaces."
    )


if __name__ == "__main__":
    main()
