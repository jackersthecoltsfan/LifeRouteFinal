import SwiftUI
import CoreGraphics
import ImageIO

@main
@MainActor
struct VisualTimerOrbRegionTests {
    private static var assertions = 0
    private static let scale: CGFloat = 3
    private static let side = 1020

    static func expect(_ condition: Bool, _ message: String) {
        assertions += 1
        precondition(condition, message)
    }

    /// Bitmap row zero is Canvas y=0 after explicitly converting Quartz coordinates.
    static func pixels(_ path: Path, clip: Bool = false) -> [UInt8] {
        let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8,
            bytesPerRow: side, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0
        )!
        // Convert Quartz's bottom-left drawing space to Canvas's top-left space.
        // Threshold antialiased coverage at 50% to avoid counting both edge pixels.
        context.setShouldAntialias(true)
        context.translateBy(x: 0, y: CGFloat(side))
        context.scaleBy(x: scale, y: -scale)
        context.setFillColor(gray: 1, alpha: 1)
        if path.isEmpty {
            return Array(repeating: 0, count: side * side)
        }
        context.addPath(path.cgPath)
        if clip {
            context.clip(using: .winding)
            context.fill(CGRect(x: 0, y: 0, width: 340, height: 340))
        } else {
            context.fillPath(using: .winding)
        }
        return Array(UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: side * side))
    }

    static func lit(_ data: [UInt8], _ point: CGPoint) -> Bool {
        data[Int(point.y * scale) * side + Int(point.x * scale)] > 127
    }

    static func main() throws {
        try testRendererWiring()
        testMotionTiming()
        testAnimatedRegions()
        let upper = CGPoint(x: 170, y: 70)
        let lower = CGPoint(x: 170, y: 300)
        let half = VisualTimerOrbRegions(progress: 0.5)
        expect(half.liquid.contains(lower), "50% liquid contains bottom-center")
        expect(!half.liquid.contains(upper), "50% liquid excludes top-center")
        expect(half.unsubmerged.contains(upper), "50% restoration contains top-center")
        expect(!half.unsubmerged.contains(lower), "50% restoration excludes bottom-center")
        let low = VisualTimerOrbRegions(progress: 0.1)
        expect(low.liquid.contains(lower), "10% includes lower reservoir")
        expect(!low.liquid.contains(CGPoint(x: 170, y: 250)), "10% excludes middle/lower air")
        expect(!low.liquid.contains(CGPoint(x: 60, y: 300)), "10% excludes outside circle")
        let nearFull = VisualTimerOrbRegions(progress: 0.98)
        expect(!nearFull.liquid.contains(CGPoint(x: 170, y: 28)), "98% excludes small top cap")
        expect(nearFull.liquid.contains(CGPoint(x: 170, y: 50)), "98% includes just below top cap")
        expect(VisualTimerOrbRegions(progress: 0).liquid.isEmpty, "zero has no liquid path")
        expect(VisualTimerOrbRegions(progress: 0).meniscus.isEmpty, "zero has no meniscus")
        expect(VisualTimerOrbRegions(progress: 1).unsubmerged.isEmpty, "full has no restoration")

        for progress: CGFloat in [0.98, 0.75, 0.5, 0.25, 0.1, 0.05, 0, 1, 0.001, 0.999] {
            let regions = VisualTimerOrbRegions(progress: progress)
            let body = pixels(regions.liquid)
            let air = pixels(regions.unsubmerged)
            let well = pixels(regions.well)
            let clipped = pixels(regions.liquid, clip: true)
            try saveMask(body, name: "liquid-\(Int((progress * 1000).rounded()))")
            try saveMask(air, name: "unsubmerged-\(Int((progress * 1000).rounded()))")
            expect(clipped == body, "\(progress): native winding clip keeps exactly the body region")
            let count = body.filter { $0 > 127 }.count
            let wellCount = well.filter { $0 > 127 }.count
            let fraction = Double(count) / Double(wellCount)
            expect(abs(fraction - Double(progress)) < 0.001, "\(progress): rendered area agrees with scalar within 0.1 percentage point")
            var overlap = 0, missing = 0, outside = 0
            for i in body.indices {
                let l = body[i] > 127, a = air[i] > 127, w = well[i] > 127
                if l && a { overlap += 1 }
                if w && !(l || a) { missing += 1 }
                if !w && (l || a) { outside += 1 }
            }
            // Native circular arcs are cubic approximations; allow <0.05% edge pixels.
            expect(Double(overlap + missing + outside) / Double(wellCount) < 0.0005,
                   "\(progress): regions partition the well without material overlap/gaps")
            if progress > 0 && progress < 1 {
                let topPoint = CGPoint(x: 170, y: (24 + regions.surfaceY) / 2)
                let bottomPoint = CGPoint(x: 170, y: (316 + regions.surfaceY) / 2)
                expect(!regions.liquid.contains(topPoint) && regions.liquid.contains(bottomPoint), "\(progress): Path containment owns lower side")
                expect(regions.unsubmerged.contains(topPoint) && !regions.unsubmerged.contains(bottomPoint), "\(progress): restoration owns upper side")
                expect(!lit(body, topPoint) && lit(body, bottomPoint), "\(progress): raster owns lower side")
                expect(lit(air, topPoint) && !lit(air, bottomPoint), "\(progress): raster restoration owns upper side")
                var surfacePoints: [CGPoint] = []
                regions.meniscus.forEach { element in
                    switch element {
                    case .move(let point): surfacePoints.append(point)
                    case .curve(let to, _, _): surfacePoints.append(to)
                    default: break
                    }
                }
                expect(surfacePoints.count == 3, "one shared two-curve meniscus")
                for endpoint in [surfacePoints.first!, surfacePoints.last!] {
                    expect(abs(hypot(endpoint.x - 170, endpoint.y - 170) - 146) < 0.00001, "\(progress): meniscus endpoint lies on circle")
                }
                // Sample the actual cubic segments and their rasterized boundary.
                // Path.contains flattens curves too coarsely for sub-point edge probes;
                // representative interior containment is checked separately above.
                var previous = CGPoint.zero
                var boundaryCorrect = true
                regions.meniscus.forEach { element in
                    switch element {
                    case .move(let point): previous = point
                    case .curve(let end, let c1, let c2):
                        for step in 1..<20 {
                            let t = CGFloat(step) / 20, u = 1 - t
                            let x = u*u*u*previous.x + 3*u*u*t*c1.x + 3*u*t*t*c2.x + t*t*t*end.x
                            let y = u*u*u*previous.y + 3*u*u*t*c1.y + 3*u*t*t*c2.y + t*t*t*end.y
                            let above = CGPoint(x: x, y: y - 0.5)
                            let below = CGPoint(x: x, y: y + 0.5)
                            if lit(well, above) && lit(well, below) {
                                boundaryCorrect = boundaryCorrect && !lit(body, above) && lit(body, below)
                                    && lit(air, above) && !lit(air, below)
                            }
                        }
                        previous = end
                    default: break
                    }
                }
                expect(boundaryCorrect, "\(progress): body and restoration share the rasterized curved meniscus")
            }
            print(String(format: "MASK expected=%.3f rendered=%.6f error=%+.6f overlap=%d missing=%d outside=%d", Double(progress), fraction, fraction - Double(progress), overlap, missing, outside))
        }
        try testSwiftUIMaskAndClip()
        print("Native Orb region fixtures passed (\(assertions) assertions).")
    }

    static func testRendererWiring() throws {
        // Wiring checks supplement executable native geometry/alpha/clip coverage;
        // they prevent a consumer from quietly introducing an independent region.
        let source = try String(contentsOfFile: "LifeRoute/ScenicRoyalVisualTimerView.swift", encoding: .utf8)
        expect(source.components(separatedBy: "VisualTimerOrbRegions(progress:").count == 2, "material stack creates exactly one region result")
        expect(source.contains("regions: regions\n            )"), "Canvas receives the stack's region result")
        let stack = source.components(separatedBy: "private struct ScenicRoyalOrbMaterialStack: View {")[1]
            .components(separatedBy: "private struct ScenicRoyalOrbAboveLiquidMask: Shape {")[0]
        expect(stack.components(separatedBy: "registeredMaterial(\"orb_v04_accepted_material\")").count == 2,
               "accepted coherent V04 base is drawn once")
        expect(!stack.contains(".mask") && !stack.contains("orb_middle_lens_material"),
               "one-base integration needs no overlapping restoration draw; native upper-region tests remain active")
        expect(source.contains("canvas.fill(\n                    regions.liquid,"), "body uses canonical liquid region")
        expect(source.contains("liquidOptics.clip(to: regions.liquid)"), "all liquid-local caustics use the body's region")
        expect(source.contains("submergedAccent.clip(to: regions.liquid)"), "lower meniscus accent stays submerged")
        expect(!source.contains("func liquidVolume(") && !source.contains("func aboveLiquid("), "legacy independent region builders remain removed")
    }

    static func testMotionTiming() {
        var clock = VisualTimerOrbMotionClock()
        expect(clock.elapsed(at: 100) == 0, "ready motion is still")
        clock.setActive(true, at: 100)
        clock.setActive(true, at: 101)
        expect(clock.elapsed(at: 102) == 2, "repeated activity updates do not reset phase")
        clock.setActive(false, at: 102)
        expect(clock.elapsed(at: 200) == 2, "pause/hidden/background time does not advance motion")
        let paused = VisualTimerOrbMotionFrame(elapsed: clock.elapsed(at: 200), progress: 0.5, urgency: 0)
        clock.setActive(true, at: 200)
        expect(VisualTimerOrbMotionFrame(elapsed: clock.elapsed(at: 200), progress: 0.5, urgency: 0) == paused,
               "resume begins at exactly the paused phase")
        expect(clock.elapsed(at: 201) == 3, "resume advances only active monotonic time")
        clock.setActive(false, at: .nan)
        expect(clock.elapsed(at: 202) == 4, "invalid clock input cannot corrupt animation")
        expect(VisualTimerOrbMotionFrame(elapsed: 0, progress: 0.5, urgency: 1) == .still,
               "motion begins at the accepted static finish")

        let driver = VisualTimerOrbPresentationDriver()
        let embedded = UUID()
        let fullScreen = UUID()
        driver.setActive(true, owner: embedded, at: 300)
        let beatInterval = 1 / VisualTimerFeedbackCurve.pulsesPerSecond(elapsedProgress: 0.5)
        driver.register(
            VisualTimerPresentationBeat(
                VisualTimerScheduledBeat(index: 8, generation: 1, plannedUptime: 300, interval: beatInterval)
            ),
            at: 300
        )
        expect(driver.timing(at: 300).pulsePhase == 0, "active Orb receives the authoritative beat onset")
        expect(abs(driver.timing(at: 300).pulse - 1) < 0.000_001,
               "shared driver reaches the coordinated pulse peak")
        let startup = VisualTimerOrbPresentationDriver()
        let startupOwner = UUID()
        startup.register(
            VisualTimerPresentationBeat(
                VisualTimerScheduledBeat(index: 1, generation: 1, plannedUptime: 701, interval: beatInterval)
            ),
            at: 700
        )
        startup.setActive(true, owner: startupOwner, at: 700.25)
        expect(startup.timing(at: 701).pulsePhase == 0,
               "a future shared beat survives layout activation and reaches the settled Orb")
        let future = VisualTimerOrbPresentationDriver()
        let futureOwner = UUID()
        future.setActive(true, owner: futureOwner, at: 500)
        future.register(
            VisualTimerPresentationBeat(
                VisualTimerScheduledBeat(index: 9, generation: 3, plannedUptime: 501, interval: beatInterval)
            ),
            at: 500
        )
        expect(future.timing(at: 500.5).pulse == 0,
               "Orb does not flash when an audio beat is merely enqueued for the future")
        expect(future.timing(at: 501).pulsePhase == 0,
               "Orb begins on the same planned monotonic instant as queued audio")
        future.invalidate(before: 4)
        future.register(
            VisualTimerPresentationBeat(
                VisualTimerScheduledBeat(index: 10, generation: 3, plannedUptime: 502, interval: beatInterval)
            ),
            at: 501
        )
        expect(future.timing(at: 502).beatIndex == nil,
               "invalidated generation clears the prior beat tracker instead of replaying an obsolete visual beat")
        future.register(
            VisualTimerPresentationBeat(
                VisualTimerScheduledBeat(index: 0, generation: 4, plannedUptime: 503, interval: beatInterval)
            ),
            at: 502
        )
        expect(future.timing(at: 503).beatIndex == 0 && future.timing(at: 503).pulse > 0.99,
               "a new generation restarts at beat zero and still reaches the active rim consumer")
        driver.setActive(true, owner: fullScreen, at: 301)
        driver.setActive(false, owner: embedded, at: 301)
        let overlappingElapsed = driver.timing(at: 302).elapsed
        expect(overlappingElapsed == 2, "cover handoff retains one continuous active presentation clock")
        driver.setActive(false, owner: fullScreen, at: 302)
        let pausedTiming = driver.timing(at: 400)
        driver.setActive(true, owner: embedded, at: 400)
        expect(driver.timing(at: 400) == pausedTiming, "inactive and Reduce Motion style suspension resumes without a phase reset")

        // A planned beat anticipates smoothly, crests on its actual schedule,
        // and never needs touch/beat publication to advance baseline motion.
        let continuous = VisualTimerOrbPresentationDriver()
        let visibleOwner = UUID()
        continuous.setActive(true, owner: visibleOwner, at: 900)
        for index in 0..<2 {
            continuous.register(VisualTimerPresentationBeat(VisualTimerScheduledBeat(
                index: UInt64(index), generation: 1,
                plannedUptime: 901 + Double(index), interval: 1)), at: 900)
        }
        let beforeCrest = continuous.timing(at: 900.999)
        let crest = continuous.timing(at: 901)
        let afterCrest = continuous.timing(at: 901.001)
        expect(crest.pulse == 1 && abs(beforeCrest.pulse - afterCrest.pulse) < 0.0001,
               "crest is centered on the scheduled beat with continuous anticipation/release")
        expect(continuous.timing(at: 901.5).pulse == 0,
               "natural turning point is brief rather than a flattened hold")
        expect(continuous.timing(at: 901.9).pulse > 0.9,
               "look-ahead supplies pressure before the next tick without an independent clock")
        continuous.invalidate(before: 2)
        expect(continuous.timing(at: 902).pulse == 0,
               "cancelled future beat cannot produce an anticipated stale crest")
        expect(continuous.timing(at: 906).elapsed == 6,
               "baseline life advances across many sparse or silent beat intervals")
        continuous.setActive(false, owner: visibleOwner, at: 906)
        expect(continuous.timing(at: 940).elapsed == 6, "offscreen motion remains intentionally frozen")
        continuous.setActive(true, owner: visibleOwner, at: 940)
        expect(continuous.timing(at: 941).elapsed == 7, "return resumes accumulated phase without a snap")

        var largestStep: CGFloat = 0
        var allFramesBounded = true
        var previous = VisualTimerOrbMotionFrame.still
        for tick in 0...1800 {
            let frame = VisualTimerOrbMotionFrame(elapsed: Double(tick) / 30, progress: 0.5, urgency: 1)
            largestStep = max(largestStep, abs(frame.driftX - previous.driftX))
            allFramesBounded = allFramesBounded && abs(frame.surfaceBend) <= 1 && abs(frame.surfaceRipple) <= 1
                   && abs(frame.driftX) <= 29 && abs(frame.driftY) <= 15
                   && (0.42...1.58).contains(frame.causticGain)
            previous = frame
        }
        expect(allFramesBounded, "motion stays bounded across 1,801 sampled frames")
        expect(largestStep < 3.2, "stronger living motion has no harsh phase reset or frame jump")
        let calm = VisualTimerOrbMotionFrame(elapsed: 4, progress: 0.5, urgency: 0)
        let urgent = VisualTimerOrbMotionFrame(elapsed: 4, progress: 0.5, urgency: 1)
        expect(abs(urgent.driftX) > abs(calm.driftX) && urgent.driftX * calm.driftX > 0,
               "urgency increases visible energy with continuous shared phases")
        let pulseRest = VisualTimerOrbMotionFrame(elapsed: 4, progress: 0.5, urgency: 0.5, pulsePhase: 1)
        let pulsePeak = VisualTimerOrbMotionFrame(elapsed: 4, progress: 0.5, urgency: 0.5, pulsePhase: 0)
        expect(pulsePeak.crystalEnergy == pulseRest.crystalEnergy && pulsePeak.pulse == 1,
               "beat pressure stays separate from continuous baseline energy")
        expect(abs(pulsePeak.surfaceBend - pulseRest.surfaceBend) > 0.5
               && abs(pulsePeak.surfaceRipple - pulseRest.surfaceRipple) > 0.4,
               "liquid geometry visibly participates in the shared heartbeat")
        for progress in [0.0, 1.0] {
            let frame = VisualTimerOrbMotionFrame(elapsed: 7, progress: progress, urgency: 1)
            expect(frame.driftX == 0 && frame.driftY == 0 && frame.surfaceRipple == 0 && frame.causticGain == 1,
                   "empty/full endpoints settle without false liquid optics")
        }
        for phase in [0.0, 0.08, 0.5, 0.99, 1.0] {
            let frame = VisualTimerOrbMotionFrame(elapsed: 7, progress: 0, urgency: 1, pulsePhase: phase)
            let regions = VisualTimerOrbRegions(progress: 0, motion: frame)
            expect(frame.causticGain == 1 && frame.sheen == 0 && frame.driftX == 0 && frame.driftY == 0,
                   "zero remains free of liquid-local optics at pulse phase \(phase)")
            expect(regions.liquid.isEmpty && regions.meniscus.isEmpty,
                   "zero remains free of liquid and meniscus at pulse phase \(phase)")
        }
    }

    static func testAnimatedRegions() {
        let well = pixels(VisualTimerOrbRegions(progress: 0.5).well)
        let wellCount = well.filter { $0 > 127 }.count
        for progress: CGFloat in [0, 0.001, 0.05, 0.1, 0.25, 0.5, 0.75, 0.98, 0.999, 1] {
            let baseline = VisualTimerOrbRegions(progress: progress)
            let still = VisualTimerOrbRegions(progress: progress, motion: .still)
            expect(baseline.liquid == still.liquid && baseline.unsubmerged == still.unsubmerged
                   && baseline.meniscus == still.meniscus, "static API keeps exactly the same paths")
            for time in [2.15, 5.9, 6.45, 8.85] {
                let motion = VisualTimerOrbMotionFrame(elapsed: time, progress: Double(progress), urgency: 1)
                let regions = VisualTimerOrbRegions(progress: progress, motion: motion)
                let liquid = pixels(regions.liquid)
                let air = pixels(regions.unsubmerged)
                let fraction = Double(liquid.filter { $0 > 127 }.count) / Double(wellCount)
                expect(abs(fraction - Double(progress)) < 0.001, "moving liquid preserves actual progress area")
                expect(regions.surfaceY == baseline.surfaceY && regions.well == baseline.well,
                       "motion preserves Phase 1K scalar level and well geometry")
                var discrepancies = 0
                for i in well.indices {
                    let l = liquid[i] > 127, a = air[i] > 127, w = well[i] > 127
                    if (l && a) || (w && !(l || a)) || (!w && (l || a)) { discrepancies += 1 }
                }
                expect(Double(discrepancies) / Double(wellCount) < 0.0005,
                       "moving liquid and restoration partition the native well")
                expect(pixels(regions.liquid, clip: true) == liquid, "moving caustic clip retains exactly the body")
                // Integrate the sampled surface independently; a ripple must not
                // change volume. Check common tangent and fixed contact points.
                var start = CGPoint.zero, previousEnd = CGPoint.zero, tangent: CGPoint?
                var integral: CGFloat = 0
                regions.meniscus.forEach { element in
                    switch element {
                    case .move(let point):
                        start = point; previousEnd = point
                        expect(abs(hypot(point.x - 170, point.y - 170) - 146) < 0.00001, "moving left contact stays on well")
                    case .curve(let end, let c1, let c2):
                        if let tangent {
                            // Native Path stores float coordinates (one ULP near
                            // the bottom is 0.0000305 pt); allow that precision.
                            expect(abs((c1.y - start.y) - tangent.y) < 0.0001,
                                   "moving meniscus tangent: progress=\(progress) time=\(time) difference=\((c1.y - start.y) - tangent.y)")
                        }
                        // Finer independent quadrature keeps the same area-error bound
                        // with the substantially larger moving curvature.
                        for step in 1...800 {
                            let t = CGFloat(step) / 800, u = 1 - t
                            let x = u*u*u*start.x + 3*u*u*t*c1.x + 3*u*t*t*c2.x + t*t*t*end.x
                            let y = u*u*u*start.y + 3*u*u*t*c1.y + 3*u*t*t*c2.y + t*t*t*end.y
                            integral += (x - previousEnd.x) * ((y + previousEnd.y) / 2 - regions.surfaceY)
                            previousEnd = CGPoint(x: x, y: y)
                        }
                        tangent = CGPoint(x: end.x - c2.x, y: end.y - c2.y)
                        start = end
                    default: break
                    }
                }
                expect(abs(integral) < 0.03, "moving surface signed area remains zero")
                if !regions.meniscus.isEmpty {
                    expect(abs(hypot(start.x - 170, start.y - 170) - 146) < 0.00001, "moving right contact stays on well")
                }
            }
        }
        // A visible surface must survive ordinary-size rendering, including the
        // shallow reservoir. These are geometry floors, not product acceptance.
        for progress: CGFloat in [0.98, 0.75, 0.5, 0.25, 0.1, 0.05] {
            var centers: [CGFloat] = []
            var surfaceContained = true
            for tick in 0...240 {
                let motion = VisualTimerOrbMotionFrame(elapsed: 2 + Double(tick) / 30,
                                                       progress: Double(progress), urgency: 0)
                let regions = VisualTimerOrbRegions(progress: progress, motion: motion)
                var start = CGPoint.zero
                regions.meniscus.forEach { element in
                    switch element {
                    case .move(let p): start = p
                    case .curve(let end, let c1, let c2):
                        if end.x == 170 { centers.append(end.y) }
                        for step in 0...40 {
                            let t = CGFloat(step) / 40, u = 1 - t
                            let p = CGPoint(x: u*u*u*start.x + 3*u*u*t*c1.x + 3*u*t*t*c2.x + t*t*t*end.x,
                                            y: u*u*u*start.y + 3*u*u*t*c1.y + 3*u*t*t*c2.y + t*t*t*end.y)
                            surfaceContained = surfaceContained && hypot(p.x - 170, p.y - 170) < 146.001
                        }
                        start = end
                    default: break
                    }
                }
            }
            let travel = centers.max()! - centers.min()!
            expect(travel > (progress > 0.95 ? 1.0 : 5.0), "surface travel is visibly stronger at \(progress): \(travel) pt")
            expect(surfaceContained, "every large-motion surface sample remains inside the well")
            print("LIVING_SURFACE progress=\(progress) earlyTravel=\(travel)")
        }
        let moving = VisualTimerOrbRegions(progress: 0.5,
            motion: VisualTimerOrbMotionFrame(elapsed: 2.15, progress: 0.5, urgency: 1))
        expect(pixels(moving.liquid) != pixels(VisualTimerOrbRegions(progress: 0.5).liquid),
               "actual liquid boundary moves; motion includes more than highlight styling")
    }

    static func saveMask(_ pixels: [UInt8], name: String) throws {
        guard let directory = ProcessInfo.processInfo.environment["LIFEROUTE_ORB_MASK_OUTPUT_DIRECTORY"] else { return }
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8,
                            bytesPerRow: side, space: CGColorSpaceCreateDeviceGray(),
                            bitmapInfo: [], provider: provider, decode: nil,
                            shouldInterpolate: false, intent: .defaultIntent)!
        let destination = CGImageDestinationCreateWithURL(folder.appendingPathComponent(name + ".png") as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        precondition(CGImageDestinationFinalize(destination), "mask evidence must be written")
    }

    static func testSwiftUIMaskAndClip() throws {
        // Exercise SwiftUI's alpha mask and GraphicsContext clip at the native seam.
        for progress: CGFloat in [0.98, 0.5, 0.1, 0] {
            let regions = VisualTimerOrbRegions(progress: progress)
            let maskRenderer = ImageRenderer(content: Color.white
                .frame(width: 340, height: 340)
                .mask { regions.unsubmerged.fill(.white) })
            let clipRenderer = ImageRenderer(content: Canvas { context, _ in
                var optics = context
                optics.clip(to: regions.liquid)
                optics.fill(Path(CGRect(x: 0, y: 0, width: 340, height: 340)), with: .color(.white))
            }.frame(width: 340, height: 340))
            guard let maskImage = maskRenderer.cgImage else { fatalError("SwiftUI mask did not render") }
            checkImage(maskImage, expected: regions.unsubmerged, name: "\(progress) restoration")
            guard let clipImage = clipRenderer.cgImage else { fatalError("SwiftUI Canvas clip did not render") }
            checkImage(clipImage, expected: regions.liquid, name: "\(progress) caustic clip")
        }
    }

    static func checkImage(_ image: CGImage, expected: Path, name: String) {
        let context = CGContext(data: nil, width: 340, height: 340, bitsPerComponent: 8,
                                bytesPerRow: 340 * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: 340, height: 340))
        let data = context.data!.assumingMemoryBound(to: UInt8.self)
        for point in [CGPoint(x: 170, y: 28), CGPoint(x: 170, y: 70), CGPoint(x: 170, y: 250), CGPoint(x: 170, y: 300), CGPoint(x: 10, y: 10)] {
            let alpha = data[(Int(point.y) * 340 + Int(point.x)) * 4 + 3]
            expect((alpha > 127) == expected.contains(point), "\(name): native pixel alpha at \(point)")
        }
    }
}
