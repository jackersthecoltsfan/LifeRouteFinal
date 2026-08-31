import SwiftUI

/// The protected scenic artwork is sampled once as a fixed, grounded camera
/// composition. It intentionally has no time input and no transform API.
struct LifeRouteFixedSceneryBase: View {
    let scene: LifeRouteScenerySceneID

    var body: some View {
        GeometryReader { proxy in
            Image(decorative: scene.assetName)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Static readability grading lives outside the environment clock so neither
/// image decoding nor full-screen gradients are invalidated by every tick.
struct LifeRouteFixedSceneryGrade: View {
    let profile: LifeRouteScenerySceneProfile
    let palette: LifeRouteThemePalette

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(profile.scene.isNight ? 0.08 : 0.025),
                    Color.clear,
                    Color.black.opacity(profile.scene.isNight ? 0.18 : 0.10),
                    Color.black.opacity(profile.scene.isNight ? 0.27 : 0.18),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    palette.accentSecondary.opacity(profile.scene.isNight ? 0.035 : 0.025),
                    Color.clear,
                    palette.accent.opacity(0.018),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One low-allocation localized effect layer serves every retained scene. The
/// base image and camera never enter this Canvas.
struct LifeRouteSceneryEffectLayer: View {
    let profile: LifeRouteScenerySceneProfile
    let palette: LifeRouteThemePalette
    let time: TimeInterval
    var intensity: Double = 1

    var body: some View {
        let safeTime = time.isFinite ? max(0, time) : 0
        let safeIntensity = min(1, max(0, intensity.isFinite ? intensity : 0))

        ZStack {
            LifeRouteLocalizedWaterTextureLayer(
                profile: profile,
                time: safeTime,
                intensity: safeIntensity
            )

            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                for effect in profile.effects {
                    switch effect {
                    case .clouds:
                        drawClouds(in: &context, size: size, time: safeTime, intensity: safeIntensity)
                    case .valleyFog:
                        drawValleyFog(in: &context, size: size, time: safeTime, intensity: safeIntensity)
                    case .waterRipple, .waterfallFlow, .streamFlow, .riverFlow:
                        // These effect families move the baked water pixels in
                        // LifeRouteLocalizedWaterTextureLayer. Do not stack a
                        // generic line or shimmer substitute over the artwork.
                        break
                    case .heatMirage:
                        drawHeatMirage(in: &context, size: size, time: safeTime, intensity: safeIntensity)
                    case .sandGust:
                        drawGust(in: &context, size: size, time: safeTime, snow: false, intensity: safeIntensity)
                    case .mistCycle:
                        drawMist(in: &context, size: size, time: safeTime, intensity: safeIntensity)
                    case .rain:
                        drawRain(in: &context, size: size, time: safeTime, intensity: safeIntensity)
                    case .fogCycle:
                        drawCanyonFog(in: &context, size: size, time: safeTime, intensity: safeIntensity)
                    case .celestialDrift:
                        drawCelestialGlints(in: &context, size: size, time: safeTime, intensity: safeIntensity)
                    case .snowfall:
                        drawSnowfall(in: &context, size: size, time: safeTime, intensity: safeIntensity)
                    case .aurora:
                        drawAurora(in: &context, size: size, time: safeTime, intensity: safeIntensity)
                    case .snowGust:
                        drawGust(in: &context, size: size, time: safeTime, snow: true, intensity: safeIntensity)
                    }
                }
            }
            .blendMode(.screen)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawClouds(
        in context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        intensity: Double
    ) {
        let region: (minX: Double, maxX: Double, baseY: Double, yStep: Double, width: Double)
        switch profile.scene {
        case .rainforestNight:
            region = (0.20, 0.80, 0.10, 0.050, 0.19)
        case .desertNight:
            region = (0.15, 0.85, 0.12, 0.065, 0.20)
        case .mountainsNight, .canyonNight, .oceanNight:
            region = (-0.10, 1.10, 0.12, 0.070, 0.23)
        default:
            region = (-0.12, 1.12, 0.11, 0.072, 0.24)
        }
        let nightMultiplier = profile.scene.isNight ? 0.72 : 1.0
        let cloudCount = profile.scene == .rainforestNight ? 2 : 3

        for index in 0..<cloudCount {
            let duration = 88.0 + Double(index) * 17.0
            let progress = wrapped(time / duration + Double(index) * 0.37)
            let width = region.width + Double(index) * 0.035
            let startX = region.minX + progress * (region.maxX - region.minX) - width * 0.5
            let y = region.baseY + Double(index) * region.yStep

            for strand in 0..<3 {
                let path = horizontalWave(
                    size: size,
                    startX: startX - Double(strand) * 0.018,
                    endX: startX + width + Double(strand) * 0.022,
                    y: y + Double(strand) * 0.008,
                    amplitude: 0.0038 + Double(strand) * 0.0012,
                    frequency: 0.72 + Double(strand) * 0.13,
                    phase: time * 0.025 + Double(index) * 0.9 + Double(strand) * 0.7
                )
                context.stroke(
                    path,
                    with: .color(Color.white.opacity((0.028 - Double(strand) * 0.004) * nightMultiplier * intensity)),
                    style: StrokeStyle(
                        lineWidth: max(5, size.width * (0.030 - CGFloat(strand) * 0.004)),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
    }

    private func drawValleyFog(
        in context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        intensity: Double
    ) {
        let rise = wrapped(time / 38.0)
        let breath = 0.55 + 0.45 * sin(time * 0.12)
        for index in 0..<4 {
            let path = horizontalWave(
                size: size,
                startX: -0.18 + Double(index) * 0.05,
                endX: 1.08,
                y: 0.70 - rise * 0.16 + Double(index) * 0.026,
                amplitude: 0.006 + Double(index % 2) * 0.002,
                frequency: 0.64 + Double(index) * 0.08,
                phase: time * 0.055 + Double(index) * 0.8
            )
            context.stroke(
                path,
                with: .color(
                    Color.white.opacity(
                        (profile.scene.isNight ? 0.026 : 0.040) * breath * intensity
                    )
                ),
                style: StrokeStyle(
                    lineWidth: max(8, size.height * 0.018),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }

    private func drawHeatMirage(
        in context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        intensity: Double
    ) {
        for index in 0..<7 {
            let path = horizontalWave(
                size: size,
                y: 0.42 + Double(index) * 0.035,
                amplitude: 0.0035,
                frequency: 1.7 + Double(index) * 0.11,
                phase: time * 0.62 + Double(index) * 0.71
            )
            context.stroke(
                path,
                with: .color(palette.accentSecondary.opacity(0.078 * intensity)),
                lineWidth: 1.6
            )
        }
    }

    private func drawGust(
        in context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        snow: Bool,
        intensity: Double
    ) {
        let seed = snow ? 23.7 : (profile.scene.isNight ? 17.1 : 8.3)
        let envelope = LifeRouteSceneryGustPolicy.envelope(at: time, seed: seed) * intensity
        guard envelope > 0.01 else { return }

        for index in 0..<14 {
            let progress = wrapped(time * (snow ? 0.21 : 0.16) + Double(index) * 0.083)
            let x = size.width * CGFloat(progress * 1.20 - 0.10)
            let baseY = snow ? 0.48 : 0.64
            let y = size.height * CGFloat(baseY + Double(index % 7) * 0.042)
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(
                to: CGPoint(
                    x: x + size.width * (snow ? 0.085 : 0.12),
                    y: y + size.height * (snow ? 0.032 : -0.018)
                )
            )
            context.stroke(
                path,
                with: .color(
                    (snow ? Color.white : palette.accentSecondary)
                        .opacity((snow ? 0.16 : 0.12) * envelope)
                ),
                lineWidth: snow ? 1.4 : 1.0
            )
        }
    }

    private func drawMist(
        in context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        intensity: Double
    ) {
        let cycle = min(1, max(0, 0.42 + 0.30 * sin(time * 0.053) + 0.20 * sin(time * 0.031 + 1.1)))
        for index in 0..<4 {
            let drift = sin(time * 0.07 + Double(index)) * 0.08
            let path = horizontalWave(
                size: size,
                startX: -0.24 + Double(index) * 0.18 + drift,
                endX: 0.55 + Double(index) * 0.18 + drift,
                y: 0.43 + Double(index) * 0.072,
                amplitude: 0.006 + Double(index % 2) * 0.002,
                frequency: 0.70 + Double(index) * 0.09,
                phase: time * 0.045 + Double(index) * 0.93
            )
            context.stroke(
                path,
                with: .color(Color.white.opacity((0.016 + cycle * 0.026) * intensity)),
                style: StrokeStyle(
                    lineWidth: max(10, size.height * 0.020),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }

    private func drawRain(
        in context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        intensity: Double
    ) {
        for index in 0..<24 {
            let seed = Double(index) * 0.61803398875
            let fall = wrapped(time * 0.42 + seed)
            let x = size.width * CGFloat(wrapped(seed * 1.73 + fall * 0.05))
            let y = size.height * CGFloat(fall)
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x - 3, y: y + 11))
            context.stroke(
                path,
                with: .color(Color.white.opacity((profile.scene.isNight ? 0.10 : 0.13) * intensity)),
                lineWidth: 0.8
            )
        }
    }

    private func drawCanyonFog(
        in context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        intensity: Double
    ) {
        let cycle = min(1, max(0, 0.40 + 0.34 * sin(time * 0.035) + 0.17 * sin(time * 0.017 + 0.8)))
        for index in 0..<4 {
            let drift = sin(time * 0.026 + Double(index) * 0.7) * 0.055
            let path = horizontalWave(
                size: size,
                startX: -0.20 + Double(index) * 0.17 + drift,
                endX: 0.56 + Double(index) * 0.17 + drift,
                y: 0.49 + Double(index) * 0.047,
                amplitude: 0.005 + Double(index % 2) * 0.002,
                frequency: 0.62 + Double(index) * 0.08,
                phase: time * 0.032 + Double(index) * 0.82
            )
            context.stroke(
                path,
                with: .color(Color.white.opacity((0.014 + cycle * 0.030) * intensity)),
                style: StrokeStyle(
                    lineWidth: max(9, size.height * 0.017),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }

    private func drawCelestialGlints(
        in context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        intensity: Double
    ) {
        let drift = wrapped(time / 1_800.0) * 0.035
        let points: [(Double, Double)] = [(0.18, 0.09), (0.42, 0.16), (0.68, 0.08), (0.83, 0.20)]
        for (index, point) in points.enumerated() {
            let pulse = 0.55 + 0.45 * sin(time * 0.025 + Double(index) * 1.7)
            let center = CGPoint(
                x: size.width * CGFloat(point.0 + drift),
                y: size.height * CGFloat(point.1)
            )
            let radius = CGFloat(1.1 + Double(index % 2) * 0.7)
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Color.white.opacity(0.13 * pulse * intensity))
            )
        }

        let halo = CGRect(
            x: size.width * CGFloat(0.125 + drift),
            y: size.height * 0.075,
            width: size.width * 0.11,
            height: size.width * 0.11
        )
        context.stroke(
            Path(ellipseIn: halo),
            with: .color(Color.white.opacity(0.028 * intensity)),
            lineWidth: 2
        )
    }

    private func drawSnowfall(
        in context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        intensity: Double
    ) {
        for index in 0..<20 {
            let seed = Double(index) * 0.61803398875
            let fall = wrapped(time * (0.055 + Double(index % 3) * 0.008) + seed)
            let sway = sin(time * 0.20 + seed * 8) * 0.018
            let x = size.width * CGFloat(wrapped(seed * 1.91 + sway))
            let y = size.height * CGFloat(fall)
            let diameter = CGFloat(1.4 + Double(index % 4) * 0.55)
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                with: .color(Color.white.opacity((profile.scene.isNight ? 0.17 : 0.21) * intensity))
            )
        }
    }

    private func drawAurora(
        in context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        intensity: Double
    ) {
        for index in 0..<3 {
            var path = Path()
            let segments = 24
            for segment in 0...segments {
                let progress = Double(segment) / Double(segments)
                let x = size.width * CGFloat(progress)
                let wave = sin(progress * Double.pi * (1.25 + Double(index) * 0.18) + time * 0.16 + Double(index))
                let y = size.height * CGFloat(0.16 + Double(index) * 0.055 + wave * 0.035)
                if segment == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            let color = index.isMultiple(of: 2) ? palette.accentSecondary : Color.cyan
            context.stroke(
                path,
                with: .color(color.opacity((0.050 - Double(index) * 0.006) * intensity)),
                style: StrokeStyle(
                    lineWidth: 46 - CGFloat(index) * 9,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            context.stroke(
                path,
                with: .color(Color.white.opacity((0.020 - Double(index) * 0.003) * intensity)),
                style: StrokeStyle(
                    lineWidth: 8 - CGFloat(index) * 1.4,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }

    private func horizontalWave(
        size: CGSize,
        startX: Double = 0,
        endX: Double = 1,
        y: Double,
        amplitude: Double,
        frequency: Double,
        phase: Double
    ) -> Path {
        var path = Path()
        let segments = 28
        for index in 0...segments {
            let progress = Double(index) / Double(segments)
            let x = size.width * CGFloat(startX + progress * (endX - startX))
            let waveY = size.height * CGFloat(y + sin(progress * 2 * Double.pi * frequency + phase) * amplitude)
            if index == 0 { path.move(to: CGPoint(x: x, y: waveY)) }
            else { path.addLine(to: CGPoint(x: x, y: waveY)) }
        }
        return path
    }

    private func wrapped(_ value: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: 1)
        return result < 0 ? result + 1 : result
    }
}

private struct LifeRouteLocalizedWaterTextureLayer: View {
    let profile: LifeRouteScenerySceneProfile
    let time: TimeInterval
    let intensity: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(regions) { region in
                    distortedArtwork(region: region, size: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func distortedArtwork(region: LifeRouteWaterRegion, size: CGSize) -> some View {
        let primary = sin(time * Double(region.speed) + Double(region.phase))
        let secondary = cos(time * Double(region.speed) * 0.63 + Double(region.phase) * 0.47)
        let strength = CGFloat(intensity)
        let artwork = Image(decorative: profile.scene.assetName)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)

        // The moving duplicate is visible only inside a scene-shaped water
        // mask. Differential translation and scaling changes the actual baked
        // water texture; the underlying full-scene image remains fixed.
        ZStack {
            artwork
                .scaleEffect(
                    x: 1 + CGFloat(secondary) * 0.0018 * strength,
                    y: 1 + CGFloat(primary) * 0.0012 * strength,
                    anchor: .center
                )
                .offset(
                    x: CGFloat(primary) * CGFloat(region.directionX * region.amplitude) * strength,
                    y: CGFloat(secondary) * CGFloat(region.directionY * region.amplitude) * strength
                )
        }
        .mask(
            LifeRouteWaterRegionMask(region: region.kind)
                .blur(radius: 1.5)
        )
        .opacity(0.94)
    }

    private var regions: [LifeRouteWaterRegion] {
        profile.textureMotionRegions.map { kind in
            switch (profile.scene, kind) {
            case (.oceanDay, .oceanFar):
                return .init(kind: kind, directionX: 1, directionY: 0.08, amplitude: 1.6, speed: 0.50, phase: 0.3)
            case (.oceanDay, .oceanNear):
                return .init(kind: kind, directionX: -1, directionY: 0.16, amplitude: 2.4, speed: 0.66, phase: 1.5)
            case (.oceanNight, .oceanFar):
                return .init(kind: kind, directionX: 1, directionY: 0.06, amplitude: 1.3, speed: 0.42, phase: 1.2)
            case (.oceanNight, .oceanNear):
                return .init(kind: kind, directionX: -1, directionY: 0.12, amplitude: 1.9, speed: 0.54, phase: 2.0)
            case (.rainforestDay, .rainforestDayWaterfall):
                return .init(kind: kind, directionX: 0.08, directionY: 1, amplitude: 2.4, speed: 1.15, phase: 0.4)
            case (.rainforestDay, .rainforestDayStream):
                return .init(kind: kind, directionX: 0.35, directionY: 1, amplitude: 1.7, speed: 0.88, phase: 1.4)
            case (.rainforestNight, .rainforestNightStream):
                return .init(kind: kind, directionX: 1, directionY: 0.18, amplitude: 1.5, speed: 0.54, phase: 0.7)
            case (.canyonDay, .canyonDayRiver):
                return .init(kind: kind, directionX: 0.18, directionY: 1, amplitude: 1.7, speed: 0.72, phase: 0.2)
            case (.canyonNight, .canyonNightRiver):
                return .init(kind: kind, directionX: -0.55, directionY: 1, amplitude: 1.5, speed: 0.62, phase: 1.1)
            case (.arcticDay, .arcticDayWater):
                return .init(kind: kind, directionX: 1, directionY: 0.12, amplitude: 1.4, speed: 0.48, phase: 0.5)
            default:
                preconditionFailure("Unexpected water-region/profile pairing: \(profile.scene) / \(kind)")
            }
        }
    }
}

private struct LifeRouteWaterRegion: Identifiable {
    let kind: LifeRouteSceneryTextureMotionRegion
    let directionX: Float
    let directionY: Float
    let amplitude: Float
    let speed: Float
    let phase: Float

    var id: LifeRouteSceneryTextureMotionRegion { kind }
}

private struct LifeRouteWaterRegionMask: Shape {
    let region: LifeRouteSceneryTextureMotionRegion

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch region {
        case .oceanFar:
            path.move(to: point(0, 0.31, rect))
            path.addLine(to: point(1, 0.31, rect))
            path.addLine(to: point(1, 0.59, rect))
            path.addLine(to: point(0, 0.59, rect))
            path.closeSubpath()

        case .oceanNear:
            path.move(to: point(0, 0.56, rect))
            path.addLine(to: point(1, 0.56, rect))
            path.addLine(to: point(1, 1, rect))
            path.addLine(to: point(0, 1, rect))
            path.closeSubpath()

        case .rainforestDayWaterfall:
            path.move(to: point(0.515, 0.375, rect))
            path.addLine(to: point(0.575, 0.375, rect))
            path.addLine(to: point(0.595, 0.575, rect))
            path.addLine(to: point(0.505, 0.575, rect))
            path.closeSubpath()

        case .rainforestDayStream:
            path.move(to: point(0.50, 0.535, rect))
            path.addLine(to: point(0.60, 0.535, rect))
            path.addCurve(
                to: point(0.69, 0.76, rect),
                control1: point(0.70, 0.64, rect),
                control2: point(0.66, 0.71, rect)
            )
            path.addLine(to: point(0.48, 0.76, rect))
            path.addCurve(
                to: point(0.50, 0.535, rect),
                control1: point(0.54, 0.70, rect),
                control2: point(0.43, 0.63, rect)
            )
            path.closeSubpath()

        case .rainforestNightStream:
            path.move(to: point(0.16, 0.50, rect))
            path.addCurve(to: point(0.92, 0.50, rect), control1: point(0.36, 0.46, rect), control2: point(0.70, 0.48, rect))
            path.addLine(to: point(0.87, 0.79, rect))
            path.addLine(to: point(0.08, 0.79, rect))
            path.closeSubpath()

        case .canyonDayRiver:
            path.move(to: point(0.52, 0.42, rect))
            path.addCurve(to: point(0.66, 0.53, rect), control1: point(0.59, 0.45, rect), control2: point(0.66, 0.49, rect))
            path.addCurve(to: point(0.57, 0.68, rect), control1: point(0.63, 0.58, rect), control2: point(0.54, 0.62, rect))
            path.addLine(to: point(0.48, 0.68, rect))
            path.addCurve(to: point(0.55, 0.54, rect), control1: point(0.50, 0.63, rect), control2: point(0.57, 0.58, rect))
            path.addCurve(to: point(0.52, 0.42, rect), control1: point(0.62, 0.52, rect), control2: point(0.57, 0.47, rect))
            path.closeSubpath()

        case .canyonNightRiver:
            path.move(to: point(0.51, 0.42, rect))
            path.addCurve(to: point(0.31, 0.63, rect), control1: point(0.52, 0.50, rect), control2: point(0.40, 0.57, rect))
            path.addCurve(to: point(0.17, 0.90, rect), control1: point(0.20, 0.72, rect), control2: point(0.17, 0.83, rect))
            path.addLine(to: point(0.03, 0.90, rect))
            path.addCurve(to: point(0.24, 0.59, rect), control1: point(0.06, 0.76, rect), control2: point(0.13, 0.66, rect))
            path.addCurve(to: point(0.51, 0.42, rect), control1: point(0.36, 0.51, rect), control2: point(0.46, 0.46, rect))
            path.closeSubpath()

        case .arcticDayWater:
            path.move(to: point(0.02, 0.39, rect))
            path.addCurve(to: point(0.56, 0.41, rect), control1: point(0.18, 0.37, rect), control2: point(0.42, 0.38, rect))
            path.addCurve(to: point(0.48, 0.67, rect), control1: point(0.64, 0.49, rect), control2: point(0.56, 0.58, rect))
            path.addLine(to: point(0.27, 0.91, rect))
            path.addLine(to: point(0, 0.91, rect))
            path.closeSubpath()
        }
        return path
    }

    private func point(_ x: CGFloat, _ y: CGFloat, _ rect: CGRect) -> CGPoint {
        CGPoint(x: rect.width * x, y: rect.height * y)
    }
}
