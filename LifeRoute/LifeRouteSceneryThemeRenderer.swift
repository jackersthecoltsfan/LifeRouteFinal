import SwiftUI

private enum LifeRouteSceneryFamily {
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
        case .canyon: return .init(speed: 0.120, drift: 0.028, stillPhase: 2.9)
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

// v0.7.1 Canyon Day exemplar: the bundled scene is authoritative; SwiftUI adds only restrained ambience.
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

// MARK: - v0.7.1 retained Scenery production renderer

// v0.8.0 follow-up Scenery ambient motion:
// Small deterministic Canvas fields reuse the protected root phase; they add no clock or state.
private struct LifeRouteSceneryAmbientParticleField: View {
    enum Kind {
        case rainforestLeaves
        case arcticSnow
    }

    let kind: Kind
    let phase: Double
    let isNight: Bool

    var body: some View {
        Canvas { context, size in
            switch kind {
            case .rainforestLeaves:
                for index in 0..<9 {
                    let seed = Double(index) * 1.731 + 0.47
                    let baseX = size.width * CGFloat(0.08 + Double(index % 5) * 0.205)
                    let baseY = size.height * CGFloat(0.08 + Double(index / 5) * 0.17 + Double(index % 3) * 0.035)
                    let swayX = CGFloat(sin(phase * 6.2 + seed) * (4.0 + Double(index % 3)))
                    let swayY = CGFloat(cos(phase * 4.6 + seed * 1.3) * 2.4)
                    let leafWidth = CGFloat(7 + index % 3 * 2)
                    let leafHeight = leafWidth * 0.46

                    var leafContext = context
                    leafContext.translateBy(x: baseX + swayX, y: baseY + swayY)
                    leafContext.rotate(by: .degrees(sin(phase * 5.4 + seed) * 13 + Double(index % 2) * 18))
                    leafContext.fill(
                        Path(ellipseIn: CGRect(
                            x: -leafWidth / 2,
                            y: -leafHeight / 2,
                            width: leafWidth,
                            height: leafHeight
                        )),
                        with: .color(
                            Color(red: 0.62, green: 0.90, blue: 0.56)
                                .opacity(isNight ? 0.055 : 0.085)
                        )
                    )
                }

            case .arcticSnow:
                for index in 0..<18 {
                    let seed = Double(index) * 0.61803398875
                    let baseX = (seed * 0.754877666).truncatingRemainder(dividingBy: 1)
                    let fall = (phase * 2.6 + seed).truncatingRemainder(dividingBy: 1)
                    let sway = sin(phase * 7.0 + seed * 9.0) * 0.014
                    let diameter = CGFloat(1.6 + Double(index % 4) * 0.62)
                    let x = size.width * CGFloat((baseX + sway + 1).truncatingRemainder(dividingBy: 1))
                    let y = size.height * CGFloat(fall)
                    let flake = Path(ellipseIn: CGRect(
                        x: x - diameter / 2,
                        y: y - diameter / 2,
                        width: diameter,
                        height: diameter
                    ))
                    context.fill(
                        flake,
                        with: .color(Color.white.opacity(isNight ? 0.11 : 0.16))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct LifeRouteBundledSceneryAssetFrame: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette
    let assetName: String
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let longSide = max(size.width, size.height)
            let drift = sin(phase * 5.2)
            let breathe = 0.5 + 0.5 * cos(phase * 3.8)

            ZStack {
                Image(decorative: assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(1.026 + breathe * 0.008)
                    .offset(x: drift * 4.2, y: -breathe * 2.2)

                LinearGradient(
                    colors: [
                        Color.black.opacity(theme.sceneryIsNight ? 0.08 : 0.04),
                        Color.clear,
                        Color.black.opacity(theme.sceneryIsNight ? 0.20 : 0.13),
                        Color.black.opacity(theme.sceneryIsNight ? 0.34 : 0.25),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.10 + breathe * 0.03 : 0.08 + breathe * 0.035),
                        palette.accent.opacity(0.025),
                        Color.clear,
                    ],
                    center: UnitPoint(x: CGFloat(0.68 + drift * 0.018), y: theme.sceneryIsNight ? 0.24 : 0.18),
                    startRadius: 2,
                    endRadius: longSide * 0.62
                )
                .blendMode(.screen)

                familyAmbience(size: size, drift: drift, breathe: breathe)

                LinearGradient(
                    colors: [Color.white.opacity(theme.sceneryIsNight ? 0.025 : 0.045), Color.clear, palette.accent.opacity(0.020), Color.clear],
                    startPoint: UnitPoint(x: CGFloat(0.12 + drift * 0.025), y: 0),
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

    @ViewBuilder
    private func familyAmbience(size: CGSize, drift: Double, breathe: Double) -> some View {
        switch theme.sceneryFamily {
        case .mountains:
            Capsule()
                .fill(Color.white.opacity(theme.sceneryIsNight ? 0.028 : 0.050))
                .frame(width: size.width * 0.90, height: max(34, size.height * 0.052))
                .blur(radius: 20)
                .offset(x: drift * size.width * 0.035, y: -size.height * 0.08)
            Capsule()
                .fill(palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.022 : 0.034))
                .frame(width: size.width * 0.76, height: max(26, size.height * 0.040))
                .blur(radius: 17)
                .offset(x: -drift * size.width * 0.025, y: size.height * 0.16)

        case .ocean:
            LifeRouteSceneryWave(
                phase: phase * 8.4,
                verticalBias: 0.62,
                amplitude: max(4, size.height * 0.008),
                frequency: 1.18
            )
            .stroke(Color.white.opacity(theme.sceneryIsNight ? 0.15 : 0.24), lineWidth: 2.0)
            .blur(radius: 0.8)
            .blendMode(.screen)
            LifeRouteSceneryWave(
                phase: -phase * 7.2 + 1.4,
                verticalBias: 0.76,
                amplitude: max(5, size.height * 0.010),
                frequency: 0.92
            )
            .stroke(palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.16 : 0.26), lineWidth: 2.4)
            .blur(radius: 1.2)
            .blendMode(.screen)

        case .desert:
            Ellipse()
                .fill(palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.028 : 0.060 + breathe * 0.018))
                .frame(width: size.width * 1.16, height: size.height * 0.16)
                .blur(radius: 24)
                .offset(x: drift * size.width * 0.025, y: size.height * 0.18)
            LinearGradient(
                colors: [Color.clear, Color.white.opacity(theme.sceneryIsNight ? 0.018 : 0.045), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .rotationEffect(.degrees(-16 + drift * 1.8))
            .offset(y: size.height * 0.20)

        case .rainforest:
            LifeRouteSceneryAmbientParticleField(
                kind: .rainforestLeaves,
                phase: phase,
                isNight: theme.sceneryIsNight
            )
            Capsule()
                .fill(Color.white.opacity(theme.sceneryIsNight ? 0.040 : 0.060))
                .frame(width: size.width * 0.98, height: max(48, size.height * 0.075))
                .blur(radius: 26)
                .offset(x: drift * size.width * 0.030, y: size.height * 0.10)
            Ellipse()
                .fill(palette.accentSecondary.opacity(theme.sceneryIsNight ? 0.040 : 0.055))
                .frame(width: size.width * 0.78, height: size.height * 0.18)
                .blur(radius: 24)
                .offset(x: -drift * size.width * 0.024, y: -size.height * 0.18)

        case .canyon:
            Capsule()
                .fill(Color.white.opacity(theme.sceneryIsNight ? 0.030 : 0.044))
                .frame(width: size.width * 0.94, height: max(42, size.height * 0.060))
                .blur(radius: 24)
                .offset(x: drift * size.width * 0.028, y: -size.height * 0.04)
            RadialGradient(
                colors: [palette.accent.opacity(theme.sceneryIsNight ? 0.055 : 0.075), Color.clear],
                center: UnitPoint(x: CGFloat(0.54 + drift * 0.025), y: 0.58),
                startRadius: 2,
                endRadius: max(size.width, size.height) * 0.42
            )
            .blendMode(.screen)

        case .arctic:
            LifeRouteSceneryAmbientParticleField(
                kind: .arcticSnow,
                phase: phase,
                isNight: theme.sceneryIsNight
            )
            if theme.sceneryIsNight {
                LifeRouteSceneryWave(phase: phase * 5.8, verticalBias: 0.24, amplitude: 14, frequency: 0.72)
                    .stroke(palette.accentSecondary.opacity(0.17 + breathe * 0.04), lineWidth: 18)
                    .blur(radius: 13)
                    .blendMode(.screen)
                LifeRouteSceneryWave(phase: -phase * 4.9 + 1.4, verticalBias: 0.31, amplitude: 11, frequency: 0.86)
                    .stroke(palette.accent.opacity(0.11 + breathe * 0.03), lineWidth: 13)
                    .blur(radius: 11)
                    .blendMode(.screen)
            } else {
                Capsule()
                    .fill(Color.white.opacity(0.065 + breathe * 0.020))
                    .frame(width: size.width * 1.04, height: max(42, size.height * 0.055))
                    .blur(radius: 20)
                    .offset(x: drift * size.width * 0.025, y: -size.height * 0.17)
            }

        case .alpine, .grassland, .volcanic, .coastalCliffs, nil:
            EmptyView()
        }
    }
}

struct LifeRouteSceneryFrame: View {
    let theme: LifeRouteTheme
    let palette: LifeRouteThemePalette
    let phase: Double

    @ViewBuilder
    var body: some View {
        if theme == .sceneryCanyonDay {
            // Preserve the physically validated Build #98 Canyon Day reference verbatim.
            LifeRouteCanyonDayAssetFrame(palette: palette, phase: phase)
        } else if let assetName = theme.v071SceneryAssetName {
            LifeRouteBundledSceneryAssetFrame(
                theme: theme,
                palette: palette,
                assetName: assetName,
                phase: phase
            )
        } else {
            // Retired identifiers keep their procedural migration fallback but are not user-facing.
            legacyFrame
        }
    }

    private var legacyFrame: some View {
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
    let sceneryPhase: Double

    var body: some View {
        GeometryReader { proxy in
            let sceneryTheme = theme.scenicRoyalDynamicSceneryTheme

            ZStack {
                LifeRouteSceneryFrame(
                    theme: sceneryTheme,
                    palette: sceneryTheme.palette,
                    phase: sceneryPhase
                )

                // Preserve the scene's luminance and detail while shifting its atmosphere
                // into the selected Dynamic identity.
                palette.backgroundGradient
                    .opacity(theme == .royalCurrent ? 0.42 : 0.34)
                    .blendMode(.color)

                // Existing Dynamic motion becomes light and energy over the scene instead
                // of an opaque replacement. Timing remains owned by the single root clock.
                LifeRouteDynamicGlassFrame(theme: theme, palette: palette, phase: phase)
                    .opacity(theme == .royalCurrent ? 0.52 : 0.46)
                    .blendMode(.screen)

                LinearGradient(
                    colors: [
                        palette.backgroundTop.opacity(0.16),
                        Color.clear,
                        palette.backgroundBottom.opacity(0.20),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
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
                minimumInterval: 1.0 / 15.0,
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
            let sceneryTheme = theme.scenicRoyalDynamicSceneryTheme
            let scenerySignature = sceneryTheme.sceneryMotionSignature
            let sceneryLivePhase = date.timeIntervalSinceReferenceDate * scenerySignature.speed
            LifeRouteDynamicGlassEnvironment(
                theme: theme,
                palette: palette,
                phase: reduceMotion ? signature.stillPhase : livePhase,
                sceneryPhase: reduceMotion ? scenerySignature.stillPhase : sceneryLivePhase
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
