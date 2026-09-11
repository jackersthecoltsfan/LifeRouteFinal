import Foundation
import MetalKit
import ImageIO
import UniformTypeIdentifiers

@main struct LivingThemeRenderTests {
    static func main() throws {
        let args = CommandLine.arguments
        precondition(args.count == 4 || args.count == 5, "library, original artwork, output directory required")
        let scene = args.count == 5 ? LivingThemeScene.scene(for: args[4])! : .rainforestDay
        let output = URL(fileURLWithPath: args[3], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let device = MTLCreateSystemDefaultDevice()!
        let library = try device.makeLibrary(URL: URL(fileURLWithPath: args[1]))
        let pipelineDescription = MTLRenderPipelineDescriptor()
        pipelineDescription.vertexFunction = library.makeFunction(name: "livingSceneVertex")
        pipelineDescription.fragmentFunction = library.makeFunction(name: scene.fragmentFunction)
        pipelineDescription.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        let pipeline = try device.makeRenderPipelineState(descriptor: pipelineDescription)
        let texture = try MTKTextureLoader(device: device).newTexture(URL: URL(fileURLWithPath: args[2]), options: [.SRGB:true, .generateMipmaps:false])
        let queue = device.makeCommandQueue()!
        let width = texture.width, height = texture.height
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let target = device.makeTexture(descriptor: descriptor)!
        var durations: [Double] = []
        func render(time: Float, motion: Float = 1, atmosphere: Float = 1) -> [UInt8] {
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = target
            pass.colorAttachments[0].loadAction = .dontCare
            pass.colorAttachments[0].storeAction = .store
            var uniforms = LivingSceneUniforms(uvScale: SIMD2(repeating: 1), textureSize: SIMD2(Float(width), Float(height)), time: time, motion: motion, atmosphere: atmosphere)
            let command = queue.makeCommandBuffer()!
            let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LivingSceneUniforms>.stride, index: 0)
            if var ocean = scene.ocean {
                encoder.setFragmentBytes(&ocean, length: MemoryLayout<LivingOceanConfiguration>.stride, index: 1)
            }
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            command.commit()
            command.waitUntilCompleted() // Offline test only; never used by the app.
            precondition(command.status == .completed, "GPU command must complete")
            durations.append((command.gpuEndTime - command.gpuStartTime) * 1000)
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            target.getBytes(&bytes, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            return bytes
        }
        func png(_ bytes: [UInt8], name: String) throws {
            let data = Data(bytes) as CFData
            let provider = CGDataProvider(data: data)!
            let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
            let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(name).appendingPathExtension("png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(destination, cg, nil)
            precondition(CGImageDestinationFinalize(destination))
        }
        var assertions = 0
        func expect(_ condition: Bool, _ reason: String) { assertions += 1; precondition(condition, reason) }
        if scene.ocean != nil {
            let probe = try device.makeComputePipelineState(function: library.makeFunction(name: "livingOceanWaveProbe")!)
            func waves(_ times: [Float], eventIDs: [Float]? = nil) -> [SIMD4<Float>] {
                let requests = times.enumerated().map { SIMD2($0.element, eventIDs?[$0.offset] ?? 0) }
                let input = device.makeBuffer(bytes: requests, length: requests.count * 8, options: .storageModeShared)!
                let output = device.makeBuffer(length: times.count * 3 * MemoryLayout<SIMD4<Float>>.stride, options: .storageModeShared)!
                let command = queue.makeCommandBuffer()!, encoder = command.makeComputeCommandEncoder()!
                encoder.setComputePipelineState(probe)
                encoder.setBuffer(input, offset: 0, index: 0); encoder.setBuffer(output, offset: 0, index: 1)
                encoder.dispatchThreads(MTLSize(width: times.count, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
                encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
                expect(command.status == .completed, "production wave probe executes on GPU")
                return Array(UnsafeBufferPointer(start: output.contents().assumingMemoryBound(to: SIMD4<Float>.self), count: times.count * 3))
            }
            let origin = waves([0])[0], start = -origin.x, life = origin.y
            let phases: [Float] = [
                LIVING_OCEAN_ENVELOPE_START - 0.01,
                (LIVING_OCEAN_ENVELOPE_FULL + LIVING_OCEAN_CREST_START) / 2,
                (LIVING_OCEAN_CREST_START + LIVING_OCEAN_CREST_FULL) / 2,
                (LIVING_OCEAN_BREAK_START + LIVING_OCEAN_BREAK_FULL) / 2,
                (LIVING_OCEAN_BREAK_FULL + LIVING_OCEAN_FOAM_FULL) / 2,
                (LIVING_OCEAN_FOAM_FULL + LIVING_OCEAN_FOAM_DECAY) / 2,
                (LIVING_OCEAN_DISSIPATION_START + LIVING_OCEAN_DISSIPATION_END) / 2,
                LIVING_OCEAN_DISSIPATION_END + 0.01]
            let samples = waves(phases.map { start + $0 * life })
            expect(samples[2].x == 0 && samples[23].x == 0, "individual wave enters and completely dissipates")
            expect(samples[4].x > 0 && samples[4].y == 0 && samples[4].w == 0, "swell precedes crest and foam")
            expect(samples[7].y > 0 && samples[7].z == 0, "crest develops before break")
            expect(samples[10].z > 0 && samples[10].w == 0, "break precedes foam wake")
            expect(samples[16].w > samples[13].w && samples[19].w < samples[16].w, "foam expands then decays")
            expect((1..<7).allSatisfy { samples[$0 * 3].w > samples[($0 - 1) * 3].w }, "front advances through water rather than rocking in place")
            expect(samples[20].x < samples[17].x, "late wave loses strength")
            // Query real GPU event starts, lifetimes and strengths, including the
            // negative IDs that provide pre-existing water at first presentation.
            let eventIDs = (-(Int(LIVING_OCEAN_EVENT_SLOTS) - 1)...20).map(Float.init)
            let origins = waves(eventIDs.map { _ in 0 }, eventIDs: eventIDs)
            expect(abs(LIVING_OCEAN_LIFETIME_MIN + LIVING_OCEAN_LIFETIME_VARIATION - LIVING_OCEAN_LIFETIME_MAX) < 0.00001, "authority lifetime bounds agree")
            let latestNextArrival = LIVING_OCEAN_ARRIVAL_SPACING + LIVING_OCEAN_START_JITTER
            expect(latestNextArrival + LIVING_OCEAN_OVERLAP_SWELL_PROGRESS * LIVING_OCEAN_LIFETIME_MAX < LIVING_OCEAN_LIFETIME_MIN * LIVING_OCEAN_DISSIPATION_START, "authority guarantees a developed new swell before earliest old dissipation")
            var overlaps: [[String: Float]] = []
            for i in 0..<(eventIDs.count - 1) {
                let earlierStart = -origins[i * 3].x, laterStart = -origins[(i + 1) * 3].x
                let earlierLife = origins[i * 3].y, laterLife = origins[(i + 1) * 3].y
                expect(earlierLife > 0 && earlierLife <= LIVING_OCEAN_LIFETIME_MAX && laterLife <= LIVING_OCEAN_LIFETIME_MAX, "bounded wave lifetimes never exceed 18 seconds")
                expect(laterStart > earlierStart, "subsequent wave has a distinct later arrival")
                // A fifth of its lifetime gives the new wave time to develop;
                // this excludes mathematically overlapping but invisible tails.
                let sharedTime = laterStart + laterLife * LIVING_OCEAN_OVERLAP_SWELL_PROGRESS
                let coexist = waves([sharedTime, sharedTime], eventIDs: [eventIDs[i], eventIDs[i+1]])
                expect(coexist[2].x > 0.3 && coexist[5].x > 0.3, "two substantial wave envelopes coexist")
                expect(coexist[4].x > 0.8 && coexist[1].y + coexist[1].z + coexist[1].w > 0.05, "new developed swell overlaps earlier crest, break or foam")
                expect(coexist[0].w - coexist[3].w > 0.1, "coexisting wave fronts occupy different water positions")
                expect(sharedTime < earlierStart + earlierLife, "later swell begins before earlier dissipation finishes")
                overlaps.append(["earlierID":eventIDs[i], "laterID":eventIDs[i+1], "earlierStart":earlierStart,
                    "laterStart":laterStart, "sampleTime":sharedTime, "earlierLifetime":earlierLife, "laterLifetime":laterLife,
                    "earlierEnvelope":coexist[2].x, "laterEnvelope":coexist[5].x])
            }
            expect(Set(eventIDs.indices.map { origins[$0 * 3].y }).count > 4, "subsequent waves vary in lifetime")
            expect(Set(eventIDs.indices.map { origins[$0 * 3 + 2].z }).count > 4, "subsequent waves vary in strength")
            let payload: [String: Any] = ["scene": scene.themeIdentifier, "lifetime": life, "arrivalSpacing": LIVING_OCEAN_ARRIVAL_SPACING,
                "overlapSamples": overlaps, "phaseFractions": phases, "productionGPUValues": samples.map { [$0.x, $0.y, $0.z, $0.w] }]
            try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("ocean-wave-phases.json"))
        }
        let still = render(time: 0, motion: 0)
        expect(still == render(time: 900, motion: 0), "Still is exactly static at any time")
        let first = render(time: 0.3)
        expect(first == render(time: 0.3), "same scene/time yields identical pixels")
        let next = render(time: 1.3)
        func difference(_ a: [UInt8], _ b: [UInt8], box: [Double]) -> Double {
            var difference = 0.0, pixels = 0
            for y in Int(box[1] * Double(height))..<Int(box[3] * Double(height)) {
                for x in Int(box[0] * Double(width))..<Int(box[2] * Double(width)) {
                    let offset = (y * width + x) * 4
                    for c in 0..<3 { difference += abs(Double(a[offset+c]) - Double(b[offset+c])) }
                    pixels += 3
                }
            }
            return difference / Double(max(1, pixels))
        }
        let rainforestRegions: [(String,[Double],Bool)] = [
            ("falling water",[0.535,0.425,0.567,0.492],true),
            ("stream surface",[0.573,0.571,0.636,0.607],true),
            ("leaf cluster",[0.67,0.18,0.76,0.22],true),
            ("fixed trunk",[0.02,0.15,0.12,0.55],false),
            ("fixed canopy",[0.32,0.03,0.48,0.13],false),
            ("fixed rock bank",[0.35,0.58,0.43,0.68],false),
        ]
        let dayRegions: [(String,[Double],Bool)] = [
            ("mid-distance water",[0.18,0.36,0.70,0.43],true),
            ("water crest",[0.56,0.49,0.76,0.53],true),
            ("shallow surface",[0.70,0.72,0.90,0.87],true),
            ("fixed sky",[0.38,0.05,0.62,0.15],false),
            ("fixed horizon",[0.20,0.300,0.80,0.303],false),
        ]
        let nightRegions: [(String,[Double],Bool)] = [
            ("water outside moonlight",[0.60,0.39,0.87,0.48],true),
            ("moonlit water",[0.25,0.40,0.45,0.54],true),
            ("foreground wave",[0.56,0.59,0.80,0.69],true),
            ("fixed moon",[0.322,0.129,0.367,0.160],false),
            ("fixed sky",[0.72,0.04,0.92,0.12],false),
            ("fixed horizon",[0.50,0.331,0.90,0.334],false),
        ]
        let regions = scene == .rainforestDay ? rainforestRegions : (scene == .oceanDay ? dayRegions : nightRegions)
        var measured: [String:Double] = [:]
        for (name,box,moving) in regions {
            let value = difference(first,next,box:box)
            measured[name] = value
            expect(moving ? value > (scene == .rainforestDay ? 0.4 : 0.1) : value == 0, "\(name) expected \(moving ? "motion" : "fixed") but difference=\(value)")
        }
        if scene == .rainforestDay {
        let mistOn = render(time: 0.3), mistOff = render(time: 0.3, atmosphere: 0)
        expect(difference(mistOn,mistOff,box:[0.56,0.51,0.61,0.55]) > 0.2, "mist has localized visible contribution")
        let wrap:Float = 1.0 / 0.63
        let before = render(time: wrap - 0.0001), after = render(time: wrap + 0.0001)
        let wrapDifference = difference(before,after,box:[0.53,0.41,0.58,0.54])
        expect(wrapDifference < 0.2, "water phase handover has no discontinuity")
        }
        expect(stride(from: 3, to: first.count, by: 4).allSatisfy { first[$0] == 255 }, "one opaque pass")
        try png(first,name:"scene-0.3s")
        try png(next,name:"scene-1.3s")
        try png(still,name:"scene-still")
        let calmA = render(time: 0.3, motion: 0.25, atmosphere: 0)
        let calmB = render(time: 1.3, motion: 0.25, atmosphere: 0)
        expect(difference(calmA,calmB,box:regions[0].1) > 0, "calm retains primary environmental motion")
        try png(calmA,name:"scene-calm")
        // A short locally rendered sequence makes the motion inspectable; no
        // renderer code or external service substitutes for the production shader.
        for frame in 0..<90 { try png(render(time: Float(frame)/30), name:String(format:"frame-%03d",frame)) }
        let metrics:[String:Any] = ["assertions":assertions,"artworkPixels":[width,height],"textureBytes":texture.allocatedSize,
            "regionMeanByteDifferences":measured,"scene":scene.themeIdentifier,
            "gpuMeanMilliseconds":durations.reduce(0,+)/Double(durations.count),
            "gpuMaximumMilliseconds":durations.max()!,"device":device.name,
            "limitation":"Host Metal render at original artwork resolution; not physical iPhone pacing or thermal acceptance"]
        try JSONSerialization.data(withJSONObject:metrics,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("render-metrics.json"))
        print("PASS: Living Themes V2 \(assertions) GPU render assertions; \(measured)")
    }
}
