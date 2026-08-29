from pathlib import Path


APP_PATH = Path("LifeRoute/LifeRouteApp.swift")
THEME_CENTER_PATH = Path("LifeRoute/V054ThemeCenterView.swift")
MARKER = "v0.7.1 retained Dynamic library: seven distinct production renderers"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.1 Dynamic finish patch failed: expected one {label}, found {count}")
    return text.replace(old, new, 1)


def replace_one_of(text: str, candidates: list[str], new: str, label: str) -> str:
    matches = [candidate for candidate in candidates if candidate in text]
    if len(matches) != 1:
        raise SystemExit(
            f"v0.7.1 Dynamic finish patch failed: expected one compatible {label}, found {len(matches)}"
        )
    return text.replace(matches[0], new, 1)


app = APP_PATH.read_text()
themes = THEME_CENTER_PATH.read_text()

if MARKER in app:
    print("LifeRoute v0.7.1 retained Dynamic library is already materialized.")
    raise SystemExit(0)

for prerequisite in [
    "v0.7.1 Royal Current exemplar",
    "v0.7.1 physical-device motion visibility repair",
    "struct LifeRouteLiveThemeEnvironment: View",
]:
    if prerequisite not in app:
        raise SystemExit(f"v0.7.1 Dynamic finish patch failed: missing prerequisite {prerequisite}")


DYNAMIC_CATALOG = r'''// v0.7.1 retained Dynamic library: seven distinct production renderers join Royal Current.
extension LifeRouteTheme {
    static let v071RetainedDynamicCatalog: [LifeRouteTheme] = [
        .royalCurrent,
        .midnightPrism,
        .auroraBloom,
        .solarPulse,
        .emeraldFlow,
        .oceanGlass,
        .obsidianSpectra,
        .plasmaOrchid,
    ]

    var isV071RetainedDynamic: Bool {
        Self.v071RetainedDynamicCatalog.contains(self)
    }
}

'''

app = replace_once(
    app,
    "struct LifeRouteLiquidRibbon: Shape {",
    DYNAMIC_CATALOG + "struct LifeRouteLiquidRibbon: Shape {",
    "retained Dynamic catalog insertion",
)


DYNAMIC_RENDERERS = r'''// MARK: - v0.7.1 retained Dynamic production renderers

private struct LifeRoutePrismFacet: Shape {
    let skew: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * (0.48 + skew), y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.34))
        path.addLine(to: CGPoint(x: rect.width * (0.68 - skew * 0.4), y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height * 0.70))
        path.closeSubpath()
        return path
    }
}

private struct LifeRouteAuroraVeil: Shape {
    let phase: Double
    let verticalBias: CGFloat
    let depth: CGFloat

    func path(in rect: CGRect) -> Path {
        let centerY = rect.height * verticalBias
        let sway = CGFloat(sin(phase)) * rect.height * 0.045
        var path = Path()
        path.move(to: CGPoint(x: -rect.width * 0.08, y: centerY - rect.height * depth * 0.42 + sway))
        path.addCurve(
            to: CGPoint(x: rect.width * 1.08, y: centerY + rect.height * depth * 0.18 - sway),
            control1: CGPoint(x: rect.width * 0.22, y: centerY + rect.height * depth * 0.52),
            control2: CGPoint(x: rect.width * 0.72, y: centerY - rect.height * depth * 0.62)
        )
        path.addCurve(
            to: CGPoint(x: -rect.width * 0.08, y: centerY - rect.height * depth * 0.42 + sway),
            control1: CGPoint(x: rect.width * 0.72, y: centerY + rect.height * depth * 0.58),
            control2: CGPoint(x: rect.width * 0.20, y: centerY + rect.height * depth * 0.18)
        )
        path.closeSubpath()
        return path
    }
}

private struct LifeRouteOceanGlassLens: Shape {
    let phase: Double
    let verticalBias: CGFloat
    let depth: CGFloat

    func path(in rect: CGRect) -> Path {
        let y = rect.height * verticalBias
        let crest = CGFloat(sin(phase)) * rect.height * 0.025
        var path = Path()
        path.move(to: CGPoint(x: -rect.width * 0.08, y: y + crest))
        path.addCurve(
            to: CGPoint(x: rect.width * 1.08, y: y - rect.height * depth * 0.15),
            control1: CGPoint(x: rect.width * 0.22, y: y - rect.height * depth),
            control2: CGPoint(x: rect.width * 0.68, y: y + rect.height * depth * 0.72)
        )
        path.addCurve(
            to: CGPoint(x: -rect.width * 0.08, y: y + crest),
            control1: CGPoint(x: rect.width * 0.76, y: y + rect.height * depth * 1.20),
            control2: CGPoint(x: rect.width * 0.20, y: y + rect.height * depth * 0.56)
        )
        path.closeSubpath()
        return path
    }
}

private struct LifeRoutePlasmaPetal: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.height),
            control1: CGPoint(x: rect.width * 1.04, y: rect.height * 0.25),
            control2: CGPoint(x: rect.width * 0.88, y: rect.height * 0.78)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: 0),
            control1: CGPoint(x: rect.width * 0.12, y: rect.height * 0.78),
            control2: CGPoint(x: -rect.width * 0.04, y: rect.height * 0.25)
        )
        path.closeSubpath()
        return path
    }
}

private struct LifeRouteMidnightPrismFrame: View {
    let palette: LifeRouteThemePalette
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let longSide = max(size.width, size.height)
            let drift = sin(phase * 0.72)
            let shimmer = 0.5 + 0.5 * cos(phase * 0.94)

            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x02030d), Color(hex: 0x0d1238), Color(hex: 0x030518)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                AngularGradient(
                    colors: [Color.clear, palette.accent.opacity(0.34), Color.white.opacity(0.10), palette.accentSecondary.opacity(0.28), Color.clear],
                    center: UnitPoint(x: CGFloat(0.52 + drift * 0.04), y: 0.48),
                    angle: .degrees(phase * 9.0)
                )
                .scaleEffect(1.7)
                .blur(radius: 16)
                .opacity(0.78)

                ForEach(0..<5, id: \.self) { index in
                    LifeRoutePrismFacet(skew: CGFloat(index - 2) * 0.025)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(index.isMultiple(of: 2) ? 0.18 : 0.07),
                                    palette.accentSecondary.opacity(index.isMultiple(of: 2) ? 0.18 : 0.30),
                                    palette.accent.opacity(0.08),
                                    Color.clear,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size.width * 0.72, height: size.height * 0.30)
                        .rotationEffect(.degrees(Double(index) * 31.0 - 58.0 + phase * (index.isMultiple(of: 2) ? 1.2 : -0.8)))
                        .offset(
                            x: size.width * CGFloat(index - 2) * 0.12 + CGFloat(drift) * 10,
                            y: size.height * (CGFloat(index) * 0.17 - 0.34)
                        )
                        .blendMode(.screen)
                        .shadow(color: palette.accentSecondary.opacity(0.18), radius: 18)
                }

                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.white.opacity(0.45 + shimmer * 0.18), palette.accentSecondary.opacity(0.42), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: longSide * 0.92, height: CGFloat(2 + index))
                        .rotationEffect(.degrees(-43 + Double(index) * 27 + drift * 3.0))
                        .offset(x: CGFloat(index - 1) * 46, y: CGFloat(index - 1) * size.height * 0.24)
                        .blur(radius: 0.8)
                        .blendMode(.screen)
                }

                RadialGradient(
                    colors: [palette.accentSecondary.opacity(0.30), palette.accent.opacity(0.08), Color.clear],
                    center: UnitPoint(x: CGFloat(0.68 - drift * 0.06), y: 0.58),
                    startRadius: 2,
                    endRadius: longSide * 0.54
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

private struct LifeRouteAuroraBloomFrame: View {
    let palette: LifeRouteThemePalette
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let longSide = max(size.width, size.height)
            let drift = sin(phase * 0.58)
            let bloom = 0.5 + 0.5 * sin(phase * 0.84)

            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x080316), Color(hex: 0x102a2c), Color(hex: 0x120526)],
                    startPoint: .top,
                    endPoint: .bottomTrailing
                )

                LifeRouteAuroraVeil(phase: phase * 0.72, verticalBias: 0.30, depth: 0.26)
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, palette.accentSecondary.opacity(0.62), Color.white.opacity(0.18), palette.accent.opacity(0.42), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .blur(radius: 12)
                    .offset(y: -size.height * 0.06)
                    .blendMode(.screen)

                LifeRouteAuroraVeil(phase: -phase * 0.54 + 1.7, verticalBias: 0.58, depth: 0.30)
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, palette.accent.opacity(0.36), Color.white.opacity(0.12), palette.accentSecondary.opacity(0.46), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 18)
                    .rotationEffect(.degrees(-8 + drift * 2.4))
                    .blendMode(.screen)

                ForEach(0..<6, id: \.self) { index in
                    LifeRoutePlasmaPetal()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.24),
                                    index.isMultiple(of: 2) ? palette.accent.opacity(0.38) : palette.accentSecondary.opacity(0.38),
                                    Color.clear,
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: size.width * 0.19, height: size.height * (0.20 + bloom * 0.018))
                        .offset(y: -size.height * 0.11)
                        .rotationEffect(.degrees(Double(index) * 60 + phase * 1.6))
                        .offset(x: drift * 7, y: size.height * 0.12)
                        .blur(radius: 2.2)
                        .blendMode(.screen)
                }

                RadialGradient(
                    colors: [Color.white.opacity(0.64), palette.accentSecondary.opacity(0.40), palette.accent.opacity(0.18), Color.clear],
                    center: UnitPoint(x: CGFloat(0.50 + drift * 0.018), y: 0.62),
                    startRadius: 2,
                    endRadius: longSide * (0.18 + bloom * 0.025)
                )
                .blendMode(.screen)

                LinearGradient(
                    colors: [Color.white.opacity(0.07), Color.clear, palette.accentSecondary.opacity(0.07), Color.clear],
                    startPoint: UnitPoint(x: CGFloat(0.12 + drift * 0.04), y: 0),
                    endPoint: .bottomTrailing
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

private struct LifeRouteSolarPulseFrame: View {
    let palette: LifeRouteThemePalette
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let longSide = max(size.width, size.height)
            let pulse = 0.5 + 0.5 * sin(phase * 1.15)
            let orbit = phase * 8.0

            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x160204), Color(hex: 0x4a1007), Color(hex: 0x120207)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [Color.white.opacity(0.95), palette.accentSecondary.opacity(0.92), palette.accent.opacity(0.58), Color.clear],
                    center: UnitPoint(x: 0.50, y: 0.46),
                    startRadius: 1,
                    endRadius: longSide * (0.34 + pulse * 0.045)
                )
                .blendMode(.screen)

                ForEach(0..<12, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.58), palette.accentSecondary.opacity(0.30), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: CGFloat(3 + index % 2), height: size.height * (0.18 + pulse * 0.018))
                        .offset(y: -size.height * 0.22)
                        .rotationEffect(.degrees(Double(index) * 30 + orbit))
                        .offset(y: -size.height * 0.04)
                        .blur(radius: 1.1)
                        .blendMode(.screen)
                }

                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .trim(from: CGFloat(index) * 0.07, to: 0.56 + CGFloat(index) * 0.08)
                        .stroke(
                            index.isMultiple(of: 2) ? palette.accentSecondary.opacity(0.58) : Color.white.opacity(0.35),
                            style: StrokeStyle(lineWidth: CGFloat(2 + index), lineCap: .round)
                        )
                        .frame(width: size.width * (0.46 + CGFloat(index) * 0.18), height: size.width * (0.46 + CGFloat(index) * 0.18))
                        .rotationEffect(.degrees((index.isMultiple(of: 2) ? orbit : -orbit) + Double(index) * 52))
                        .offset(y: -size.height * 0.04)
                        .blur(radius: index == 3 ? 2.5 : 0.8)
                        .blendMode(.screen)
                }

                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, palette.accentSecondary.opacity(0.22), Color.white.opacity(0.20), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size.width * 1.45, height: size.height * 0.10)
                    .rotationEffect(.degrees(-18 + sin(phase * 0.62) * 3.0))
                    .offset(y: size.height * 0.28)
                    .blur(radius: 7)
                    .blendMode(.screen)

                LinearGradient(
                    colors: [Color.black.opacity(0.14), Color.clear, Color.black.opacity(0.28)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .compositingGroup()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct LifeRouteEmeraldFlowFrame: View {
    let palette: LifeRouteThemePalette
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let longSide = max(size.width, size.height)
            let drift = sin(phase * 0.78)

            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x010d0a), Color(hex: 0x05382b), Color(hex: 0x01130f)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [palette.accentSecondary.opacity(0.34), palette.accent.opacity(0.12), Color.clear],
                    center: UnitPoint(x: CGFloat(0.28 + drift * 0.08), y: 0.22),
                    startRadius: 2,
                    endRadius: longSide * 0.62
                )
                .blendMode(.screen)

                ForEach(0..<4, id: \.self) { index in
                    LifeRouteAuroraVeil(
                        phase: phase * (0.58 + Double(index) * 0.08) + Double(index),
                        verticalBias: 0.34 + CGFloat(index) * 0.12,
                        depth: 0.22
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                index.isMultiple(of: 2) ? palette.accentSecondary.opacity(0.50) : palette.accent.opacity(0.42),
                                Color.white.opacity(0.14),
                                Color.clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size.height * 1.04, height: size.width * 0.90)
                    .rotationEffect(.degrees(84 + Double(index) * 5 + drift * 2.2))
                    .offset(x: size.width * (CGFloat(index) * 0.18 - 0.34), y: size.height * (CGFloat(index) * 0.06 - 0.10))
                    .blur(radius: CGFloat(5 + index * 3))
                    .blendMode(.screen)
                }

                ForEach(0..<3, id: \.self) { index in
                    Ellipse()
                        .trim(from: 0.06, to: 0.76)
                        .stroke(
                            LinearGradient(
                                colors: [Color.clear, Color.white.opacity(0.54), palette.accentSecondary.opacity(0.52), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: CGFloat(2 + index), lineCap: .round)
                        )
                        .frame(width: size.width * (0.72 + CGFloat(index) * 0.20), height: size.height * (0.28 + CGFloat(index) * 0.08))
                        .rotationEffect(.degrees(-48 + Double(index) * 34 + phase * (index.isMultiple(of: 2) ? 1.4 : -1.1)))
                        .offset(x: drift * CGFloat(8 + index * 3), y: size.height * (CGFloat(index) * 0.20 - 0.20))
                        .blur(radius: 1.2)
                        .blendMode(.screen)
                }

                LinearGradient(
                    colors: [Color.white.opacity(0.06), Color.clear, palette.accentSecondary.opacity(0.06), Color.clear],
                    startPoint: UnitPoint(x: CGFloat(0.16 + drift * 0.05), y: 0),
                    endPoint: .bottomTrailing
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

private struct LifeRouteOceanGlassFrame: View {
    let palette: LifeRouteThemePalette
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let longSide = max(size.width, size.height)
            let drift = sin(phase * 0.74)

            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x00101f), Color(hex: 0x004d67), Color(hex: 0x001527)],
                    startPoint: .top,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [palette.accentSecondary.opacity(0.42), palette.accent.opacity(0.12), Color.clear],
                    center: UnitPoint(x: CGFloat(0.72 - drift * 0.08), y: 0.24),
                    startRadius: 2,
                    endRadius: longSide * 0.64
                )
                .blendMode(.screen)

                LifeRouteOceanGlassLens(phase: phase * 0.84, verticalBias: 0.30, depth: 0.19)
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.white.opacity(0.26), palette.accentSecondary.opacity(0.58), palette.accent.opacity(0.22), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 4)
                    .rotationEffect(.degrees(-6 + drift * 2.0))
                    .blendMode(.screen)

                LifeRouteOceanGlassLens(phase: -phase * 0.72 + 1.8, verticalBias: 0.58, depth: 0.22)
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, palette.accent.opacity(0.38), Color.white.opacity(0.16), palette.accentSecondary.opacity(0.38), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .blur(radius: 9)
                    .rotationEffect(.degrees(7 - drift * 1.6))
                    .blendMode(.screen)

                LifeRouteOceanGlassLens(phase: phase * 0.62 + 3.1, verticalBias: 0.77, depth: 0.13)
                    .stroke(
                        LinearGradient(
                            colors: [Color.clear, Color.white.opacity(0.78), palette.accentSecondary.opacity(0.60), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                    )
                    .blur(radius: 1.0)
                    .blendMode(.screen)

                ForEach(0..<4, id: \.self) { index in
                    Ellipse()
                        .trim(from: 0.06 + CGFloat(index) * 0.04, to: 0.64 + CGFloat(index) * 0.05)
                        .stroke(Color.white.opacity(0.20 - Double(index) * 0.025), lineWidth: CGFloat(1 + index))
                        .frame(width: size.width * (0.50 + CGFloat(index) * 0.22), height: size.height * (0.16 + CGFloat(index) * 0.05))
                        .rotationEffect(.degrees(-24 + Double(index) * 19 + phase * (index.isMultiple(of: 2) ? 1.2 : -0.9)))
                        .offset(x: drift * CGFloat(7 + index * 2), y: size.height * (CGFloat(index) * 0.18 - 0.24))
                        .blur(radius: 0.8)
                        .blendMode(.screen)
                }

                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.clear, Color.black.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottom
                )
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .compositingGroup()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct LifeRouteObsidianSpectraFrame: View {
    let palette: LifeRouteThemePalette
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let longSide = max(size.width, size.height)
            let drift = sin(phase * 0.66)

            ZStack {
                LinearGradient(
                    colors: [Color.black, Color(hex: 0x080a12), Color(hex: 0x020204)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                AngularGradient(
                    colors: [Color.clear, Color(hex: 0x5f7cff).opacity(0.20), Color(hex: 0xff4fca).opacity(0.16), Color(hex: 0x54f3ff).opacity(0.18), Color.clear],
                    center: UnitPoint(x: CGFloat(0.48 + drift * 0.03), y: 0.52),
                    angle: .degrees(phase * 5.2)
                )
                .scaleEffect(1.65)
                .blur(radius: 22)

                ForEach(0..<4, id: \.self) { index in
                    LifeRoutePrismFacet(skew: CGFloat(index - 2) * 0.035)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.07), Color(hex: 0x151a27).opacity(0.94), Color.black.opacity(0.86)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            LifeRoutePrismFacet(skew: CGFloat(index - 2) * 0.035)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.clear, Color(hex: 0x67e8ff).opacity(0.48), Color(hex: 0xe766ff).opacity(0.38), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.4
                                )
                        }
                        .frame(width: size.width * 0.76, height: size.height * 0.32)
                        .rotationEffect(.degrees(-34 + Double(index) * 42 + phase * (index.isMultiple(of: 2) ? 0.9 : -0.7)))
                        .offset(x: size.width * (CGFloat(index) * 0.18 - 0.30), y: size.height * (CGFloat(index) * 0.21 - 0.34))
                        .shadow(color: Color(hex: 0x5ecfff).opacity(0.12), radius: 14)
                }

                ForEach(0..<5, id: \.self) { index in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, index.isMultiple(of: 2) ? Color(hex: 0x6ce8ff).opacity(0.58) : Color(hex: 0xff68da).opacity(0.48), Color.white.opacity(0.40), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: longSide * 0.92, height: CGFloat(1.2 + Double(index) * 0.7))
                        .rotationEffect(.degrees(-58 + Double(index) * 26 + drift * 3.5))
                        .offset(x: CGFloat(index - 2) * 34, y: size.height * (CGFloat(index) * 0.16 - 0.30))
                        .blur(radius: index == 2 ? 1.8 : 0.6)
                        .blendMode(.screen)
                }

                RadialGradient(
                    colors: [Color.white.opacity(0.12), palette.accentSecondary.opacity(0.16), Color.clear],
                    center: UnitPoint(x: CGFloat(0.64 - drift * 0.05), y: 0.62),
                    startRadius: 2,
                    endRadius: longSide * 0.48
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

private struct LifeRoutePlasmaOrchidFrame: View {
    let palette: LifeRouteThemePalette
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let longSide = max(size.width, size.height)
            let drift = sin(phase * 0.76)
            let pulse = 0.5 + 0.5 * cos(phase * 1.08)

            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x080014), Color(hex: 0x31043f), Color(hex: 0x0b0018)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [palette.accent.opacity(0.44), palette.accentSecondary.opacity(0.16), Color.clear],
                    center: UnitPoint(x: CGFloat(0.50 + drift * 0.025), y: 0.50),
                    startRadius: 2,
                    endRadius: longSide * 0.58
                )
                .blendMode(.screen)

                ForEach(0..<7, id: \.self) { index in
                    LifeRoutePlasmaPetal()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.34),
                                    index.isMultiple(of: 2) ? palette.accentSecondary.opacity(0.48) : palette.accent.opacity(0.54),
                                    Color(hex: 0x5614a0).opacity(0.22),
                                    Color.clear,
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            LifeRoutePlasmaPetal()
                                .stroke(Color.white.opacity(0.20), lineWidth: 1.2)
                        }
                        .frame(width: size.width * (0.19 + pulse * 0.012), height: size.height * (0.31 + pulse * 0.018))
                        .offset(y: -size.height * 0.17)
                        .rotationEffect(.degrees(Double(index) * (360.0 / 7.0) + phase * 2.2))
                        .offset(x: drift * 8, y: size.height * 0.09)
                        .blur(radius: 1.5)
                        .blendMode(.screen)
                        .shadow(color: palette.accent.opacity(0.18), radius: 16)
                }

                ForEach(0..<3, id: \.self) { index in
                    Ellipse()
                        .trim(from: 0.02 + CGFloat(index) * 0.08, to: 0.68 + CGFloat(index) * 0.06)
                        .stroke(
                            AngularGradient(
                                colors: [Color.clear, Color.white.opacity(0.60), palette.accentSecondary.opacity(0.58), palette.accent.opacity(0.64), Color.clear],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: CGFloat(2 + index * 2), lineCap: .round)
                        )
                        .frame(width: size.width * (0.72 + CGFloat(index) * 0.24), height: size.height * (0.25 + CGFloat(index) * 0.10))
                        .rotationEffect(.degrees(-38 + Double(index) * 41 + phase * (index.isMultiple(of: 2) ? 1.6 : -1.2)))
                        .offset(x: drift * CGFloat(7 + index * 2), y: size.height * (CGFloat(index) * 0.22 - 0.22))
                        .blur(radius: 1.3)
                        .blendMode(.screen)
                }

                RadialGradient(
                    colors: [Color.white.opacity(0.92), palette.accentSecondary.opacity(0.62), palette.accent.opacity(0.30), Color.clear],
                    center: UnitPoint(x: CGFloat(0.50 + drift * 0.015), y: 0.59),
                    startRadius: 1,
                    endRadius: longSide * (0.15 + pulse * 0.025)
                )
                .blendMode(.screen)

                LinearGradient(
                    colors: [Color.white.opacity(0.06), Color.clear, Color.black.opacity(0.20)],
                    startPoint: .topLeading,
                    endPoint: .bottom
                )
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

app = replace_once(
    app,
    "struct LifeRouteDynamicGlassFrame: View {",
    DYNAMIC_RENDERERS + "struct LifeRouteDynamicGlassFrame: View {",
    "retained Dynamic renderer insertion",
)


OLD_DYNAMIC_DISPATCH = r'''    @ViewBuilder
    var body: some View {
        if theme == .royalCurrent {
            LifeRouteRoyalCurrentFrame(palette: palette, phase: phase)
        } else {
            legacyFrame
        }
    }
'''

NEW_DYNAMIC_DISPATCH = r'''    @ViewBuilder
    var body: some View {
        switch theme {
        case .royalCurrent:
            LifeRouteRoyalCurrentFrame(palette: palette, phase: phase)
        case .midnightPrism:
            LifeRouteMidnightPrismFrame(palette: palette, phase: phase)
        case .auroraBloom:
            LifeRouteAuroraBloomFrame(palette: palette, phase: phase)
        case .solarPulse:
            LifeRouteSolarPulseFrame(palette: palette, phase: phase)
        case .emeraldFlow:
            LifeRouteEmeraldFlowFrame(palette: palette, phase: phase)
        case .oceanGlass:
            LifeRouteOceanGlassFrame(palette: palette, phase: phase)
        case .obsidianSpectra:
            LifeRouteObsidianSpectraFrame(palette: palette, phase: phase)
        case .plasmaOrchid:
            LifeRoutePlasmaOrchidFrame(palette: palette, phase: phase)
        default:
            // Retired identifiers remain renderable for migration compatibility only.
            legacyFrame
        }
    }
'''

app = replace_once(app, OLD_DYNAMIC_DISPATCH, NEW_DYNAMIC_DISPATCH, "Dynamic renderer dispatch")

# Build #104 keeps the physically validated shipping canonicalizer. Expand only its retained
# Dynamic allow-list so retired migration identifiers still resolve to Royal Current.
app = replace_one_of(
    app,
    [
        '''        if theme == .royalCurrent { return theme }
        if theme.category == .dynamic { return .royalCurrent }
''',
        '''        if theme.isV071RetainedDynamic { return theme }
        if theme.category == .dynamic { return .royalCurrent }
''',
    ],
    '''        if theme.isV071RetainedDynamic { return theme }
        if theme.category == .dynamic { return .royalCurrent }
''',
    "Build #104 Dynamic shipping canonicalizer",
)

themes = replace_one_of(
    themes,
    [
        "            return LifeRouteTheme.phaseTwoDynamicCatalog\n",
        "            return [.royalCurrent]\n",
    ],
    "            return LifeRouteTheme.v071RetainedDynamicCatalog\n",
    "Theme Center Dynamic catalog",
)
themes = replace_one_of(
    themes,
    [
        '            return "12 slow, full-frame liquid-glass environments. Reduce Motion retains a still equivalent."\n',
        '            return "Royal Current is the currently validated live Dynamic theme. Additional Dynamic themes are being finished separately."\n',
    ],
    '            return "8 distinct full-frame Liquid Glass environments. Reduce Motion retains a finished still phase."\n',
    "Theme Center Dynamic description",
)

APP_PATH.write_text(app)
THEME_CENTER_PATH.write_text(themes)

print(
    "LifeRoute v0.7.1 retained Dynamic library applied: Royal Current stays unchanged; Midnight Prism, "
    "Aurora Bloom, Solar Pulse, Emerald Flow, Ocean Glass, Obsidian Spectra, and Plasma Orchid now use "
    "distinct full-frame compositions driven only by the protected root phase; retired identifiers remain "
    "available for migration but are hidden from the retained Theme Center catalog."
)
