import Foundation
import MetalKit
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

@main struct LivingThemeRenderTests {
    static func main() throws {
        let args = CommandLine.arguments
        precondition(args.count == 6, "library, original artwork, output directory, scene and ROI contract required")
        let scene = LivingThemeScene.scene(for: args[4])!
        let roiContract = try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:args[5]))) as! [String:Any]
        let sceneROI = (roiContract["scenes"] as! [String:[String:Any]])[scene.themeIdentifier]!
        let artworkHash = SHA256.hash(data:try Data(contentsOf:URL(fileURLWithPath:args[2])))
            .map { String(format:"%02x",$0) }.joined()
        precondition(artworkHash == sceneROI["artwork_sha256"] as! String,"frozen ROI must match exact scene artwork")
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
        func render(time: Float, motion: Float = 1, atmosphere: Float = 1, weatherAmount: Float? = nil) -> [UInt8] {
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
            if var atmosphere = scene.atmosphere {
                if let weatherAmount { atmosphere.air.w = weatherAmount }
                encoder.setFragmentBytes(&atmosphere, length: MemoryLayout<LivingAtmosphereConfiguration>.stride, index: 2)
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
            ("evolving cloud layers",[0.38,0.05,0.62,0.15],true),
            ("fixed horizon",[0.20,0.300,0.80,0.303],false),
        ]
        let nightRegions: [(String,[Double],Bool)] = [
            ("water outside moonlight",[0.60,0.39,0.87,0.48],true),
            ("moonlit water",[0.25,0.40,0.45,0.54],true),
            ("foreground wave",[0.56,0.59,0.80,0.69],true),
            ("fixed moon",[0.322,0.129,0.367,0.160],false),
            ("evolving night atmosphere",[0.72,0.04,0.92,0.12],true),
            ("fixed horizon",[0.50,0.331,0.90,0.334],false),
        ]
        let otherRegions: [String: [(String,[Double],Bool)]] = [
            "scenery.rainforest.night": [("stream flow",[0.40,0.56,0.53,0.68],true),("fixed trunk",[0.03,0.12,0.10,0.39],false),("fixed moon",[0.52,0.163,0.55,0.18],false)],
            "scenery.arctic.day": [("broad drifting weather",[0.27,0.39,0.61,0.45],true),("sky cloud layers",[0.20,0.05,0.65,0.20],true),("fixed ice face",[0.78,0.67,0.90,0.82],false)],
            "scenery.arctic.night": [("aurora curtain",[0.49,0.22,0.85,0.31],true),("fixed mountain",[0.77,0.42,0.89,0.50],false),("fixed foreground",[0.02,0.86,0.14,0.95],false)],
            "scenery.mountains.day": [("evolving high cloud",[0.26,0.035,0.73,0.19],true),("valley atmosphere",[0.60,0.44,0.72,0.48],true),("fixed foreground rock",[0.20,0.80,0.40,0.90],false)],
            "scenery.mountains.night": [("evolving high cloud",[0.43,0.03,0.78,0.17],true),("rolling valley fog",[0.40,0.46,0.70,0.49],true),("fixed mountain",[0.05,0.33,0.14,0.42],false)],
            "scenery.canyon.day": [("evolving clouds",[0.29,0.06,0.73,0.20],true),("canyon atmosphere",[0.49,0.40,0.64,0.43],true),("fixed rock",[0.06,0.53,0.22,0.67],false)],
            "scenery.canyon.night": [("evolving night cloud",[0.42,0.055,0.70,0.17],true),("canyon mist",[0.45,0.39,0.56,0.43],true),("fixed rock",[0.75,0.45,0.88,0.65],false)],
            "scenery.desert.day": [("heat refraction",[0.37,0.23,0.64,0.29],true),("fixed dune",[0.36,0.55,0.70,0.80],false),("fixed ridge",[0.03,0.23,0.12,0.27],false)],
            "scenery.desert.night": [("evolving night atmosphere",[0.42,0.20,0.57,0.36],true),("fixed arch",[0.10,0.04,0.28,0.15],false),("fixed dune",[0.41,0.63,0.73,0.80],false)],
        ]
        let regions = scene == .rainforestDay ? rainforestRegions : (scene == .oceanDay ? dayRegions : (scene == .oceanNight ? nightRegions : otherRegions[scene.themeIdentifier]!))
        var measured: [String:Double] = [:]
        for (name,box,moving) in regions {
            let value = difference(first,next,box:box)
            measured[name] = value
            expect(moving ? value > (scene == .rainforestDay ? 0.4 : 0.02) : value == 0, "\(name) expected \(moving ? "motion" : "fixed") but difference=\(value)")
        }
        // Earlier small-region averages were only signal probes and could admit
        // effectively static scenes. A GPU PASS now also requires the complete
        // primary artwork ROI, moving-pixel magnitude, spread and static floor.
        // The same frozen polygons and thresholds govern native viewer evidence.
        func roiPixels(_ polygons: [[[Double]]]) -> [Int] {
            var mask = [UInt8](repeating:0,count:width * height)
            mask.withUnsafeMutableBytes { storage in
                let context = CGContext(data:storage.baseAddress,width:width,height:height,
                    bitsPerComponent:8,bytesPerRow:width,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:0)!
                // CoreGraphics bitmap coordinates are bottom-up; artwork UVs
                // and Metal readback rows are top-down. Keep the frozen matte
                // aligned with the same photographed geometry as native captures.
                context.translateBy(x:0,y:CGFloat(height));context.scaleBy(x:1,y:-1)
                context.setShouldAntialias(false);context.setFillColor(gray:1,alpha:1)
                for polygon in polygons {
                    context.beginPath()
                    context.move(to:CGPoint(x:polygon[0][0] * Double(width),y:polygon[0][1] * Double(height)))
                    for point in polygon.dropFirst() { context.addLine(to:CGPoint(x:point[0] * Double(width),y:point[1] * Double(height))) }
                    context.closePath();context.fillPath()
                }
            }
            let viewport = roiContract["viewport"] as! [Double]
            let scale = LivingSceneFraming.uvScale(viewport:CGSize(width:viewport[0],height:viewport[1]),artwork:CGSize(width:width,height:height))
            let left = (1 - Double(scale.x)) / 2, top = (1 - Double(scale.y)) / 2
            return mask.indices.filter { pixel in
                let x = (Double(pixel % width) + 0.5) / Double(width), y = (Double(pixel / width) + 0.5) / Double(height)
                return mask[pixel] != 0 && x >= left && x <= 1-left && y >= top && y <= 1-top
            }
        }
        let primaryPixels = roiPixels(sceneROI["primary"] as! [[[Double]]])
        let staticPixels = roiPixels(sceneROI["static"] as! [[[Double]]])
        expect(!primaryPixels.isEmpty && !staticPixels.isEmpty,"artwork-specific primary/static ROIs are nonempty")
        var low = render(time:1), high = low
        let seconds = sceneROI["seconds"] as! Int
        for second in 1...seconds {
            let sample = render(time:Float(1 + second))
            for index in sample.indices { low[index] = min(low[index],sample[index]);high[index] = max(high[index],sample[index]) }
        }
        func temporalStats(_ pixels: [Int]) -> [String:Double] {
            var moving = [Double]()
            let threshold = roiContract["motion_pixel_threshold_255"] as! Double
            for pixel in pixels {
                let index = pixel * 4
                let delta = (Double(high[index])-Double(low[index]) + Double(high[index+1])-Double(low[index+1]) + Double(high[index+2])-Double(low[index+2])) / 3
                if delta > threshold { moving.append(delta) }
            }
            moving.sort()
            let median = moving.isEmpty ? 0 : (moving[(moving.count-1)/2] + moving[moving.count/2]) / 2
            return ["pixels":Double(pixels.count),"movingPixels":Double(moving.count),"spread":Double(moving.count)/Double(pixels.count),"movingMedian255":median]
        }
        let primaryTemporal = temporalStats(primaryPixels), staticTemporal = temporalStats(staticPixels)
        let additionalPrimary = (sceneROI["additional_primary"] as? [[[Double]]]).map { temporalStats(roiPixels($0)) }
        let additionalStatic = (sceneROI["additional_static"] as? [[[Double]]]).map { temporalStats(roiPixels($0)) }
        var temporalEvidence: [String:Any] = ["primary":primaryTemporal,"static":staticTemporal,"seconds":seconds]
        if let additionalPrimary { temporalEvidence["additionalPrimary"] = additionalPrimary }
        if let additionalStatic { temporalEvidence["additionalStatic"] = additionalStatic }
        try JSONSerialization.data(withJSONObject:temporalEvidence,options:[.prettyPrinted,.sortedKeys])
            .write(to:output.appendingPathComponent("temporal-roi.json"))
        var maskAudit = first
        for pixel in primaryPixels { maskAudit[pixel*4+1] = 255 }
        for pixel in staticPixels { maskAudit[pixel*4+2] = 255 }
        try png(maskAudit,name:"roi-audit")
        expect(primaryTemporal["movingMedian255"]! >= (roiContract["minimum_moving_median_255"] as! Double),"primary moving-pixel magnitude >=3/255")
        expect(primaryTemporal["spread"]! >= (sceneROI["minimum_spread"] as! Double),"primary motion spread >=25%, or40% for Ocean")
        expect(staticTemporal["spread"]! <= (roiContract["maximum_static_spread"] as! Double),"fixed-control moving spread <=5%")
        if let additionalPrimary {
            expect(additionalPrimary["pixels"]! > 0,"additional artwork-traced primary ROI is nonempty")
            expect(additionalPrimary["movingMedian255"]! >= (roiContract["minimum_moving_median_255"] as! Double),"complete artwork-traced primary magnitude >=3/255")
            expect(additionalPrimary["spread"]! >= (sceneROI["minimum_spread"] as! Double),"complete artwork-traced primary meets unchanged spatial floor")
        }
        if let additionalStatic {
            expect(additionalStatic["pixels"]! > 0,"additional fixed artwork control is nonempty")
            expect(additionalStatic["spread"]! <= (roiContract["maximum_static_spread"] as! Double),"additional fixed geometry change <=5%")
        }
        if let depthRegions = sceneROI["depth_regions"] as? [String:[[[Double]]]] {
            var depths=[String:[String:Double]]()
            for name in depthRegions.keys.sorted() {
                let values=temporalStats(roiPixels(depthRegions[name]!));depths[name]=values
                expect(values["movingMedian255"]! >= 3,"Ocean \(name) depth has perceptible primary magnitude")
                expect(values["spread"]! >= 0.40,"Ocean \(name) depth participates across at least40percent")
            }
            try JSONSerialization.data(withJSONObject:depths,options:[.prettyPrinted,.sortedKeys])
                .write(to:output.appendingPathComponent("ocean-depth-roi.json"))
            for box in [[0.2,0.36,0.8,0.46],[0.15,0.53,0.85,0.69],[0.15,0.79,0.85,0.94]] {
                expect(difference(render(time:3,atmosphere:0),render(time:6,atmosphere:0),box:box)>1,
                    "Ocean primary motion reaches each depth without removable atmosphere")
            }
        }
        if scene == .oceanNight {
            let waterA=render(time:2,atmosphere:0),waterB=render(time:5,atmosphere:0)
            expect(difference(waterA,waterB,box:[0.27,0.39,0.43,0.72])>2,
                "Ocean Night current fragments the photographed moon trail without ambient garnish")
            expect(difference(waterA,waterB,box:[0.65,0.55,0.90,0.85])>1,
                "Ocean Night dark water participates away from reflected moonlight")
        }
        if scene == .rainforestDay {
        let mistOn = render(time: 0.3), mistOff = render(time: 0.3, atmosphere: 0)
        expect(difference(mistOn,mistOff,box:[0.56,0.51,0.61,0.55]) > 0.2, "mist has localized visible contribution")
        let wrap:Float = 1.0 / LIVING_RF_DAY_FALL_RATE
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
        if scene == .arcticNight {
            let auroraA = render(time:1,atmosphere:0), auroraB = render(time:12,atmosphere:0)
            for (name,box) in [("lower",[0.20,0.31,0.32,0.36]),("middle",[0.44,0.265,0.57,0.30]),("upper",[0.75,0.17,0.88,0.215])] {
                expect(difference(auroraA,auroraB,box:box) > 1,
                    "Arctic Night \(name) aurora evolves independently of optional weather")
            }
            expect(difference(auroraA,auroraB,box:[0.32,0.63,0.68,0.79]) == 0,
                "Frozen lake cracks do not deform with aurora motion")
            expect(difference(first,next,box:[0.275,0.424,0.289,0.44]) == 0,
                "Arctic moon remains fixed while aurora and clouds evolve")
        }
        if scene == .arcticDay {
            let waterA = render(time:1,atmosphere:0), waterB = render(time:8,atmosphere:0)
            expect(difference(waterA,waterB,box:[0.12,0.67,0.40,0.75]) > 1,
                "Arctic Day channel water moves where distance spindrift is absent and atmosphere disabled")
            expect(difference(render(time:1,motion:0.25,atmosphere:0),render(time:8,motion:0.25,atmosphere:0),box:[0.12,0.67,0.40,0.75]) > 0.25,
                "Arctic Day calm retains slow water motion")
            expect(difference(waterA,waterB,box:[0.70,0.72,0.87,0.80]) == 0,
                "Arctic foreground ice face stays fixed despite expanded water motion")
            expect(difference(render(time:3),render(time:3,weatherAmount:0),box:[0.10,0.09,0.88,0.25]) > 0.01,
                "Denser depth-layered snowfall contributes visible pixels in the open sky")
        }
        if scene == .rainforestNight {
            expect(difference(first,next,box:[0.51,0.247,0.57,0.267]) > 0.1,
                "Rainforest Night clouds travel through the actual canopy opening")
            expect(difference(render(time:1),render(time:8),box:[0.08,0.695,0.16,0.75]) > 0.03,
                "Rainforest Night photographed leaves respond to local wind")
            expect(difference(render(time:1,atmosphere:0),render(time:8,atmosphere:0),box:[0.40,0.56,0.53,0.68]) > 0.5,
                "Preserved Rainforest Night water remains independent of added air and foliage")
        }
        if scene == .canyonDay {
            let waterA = render(time:1,atmosphere:0), waterB = render(time:8,atmosphere:0)
            expect(difference(waterA,waterB,box:[0.435,0.54,0.495,0.552]) > 1,
                "Canyon Day broad left river bend flows independently of atmosphere")
            expect(difference(waterA,waterB,box:[0.58,0.607,0.63,0.62]) > 1,
                "Canyon Day foreground channel continues the river flow")
            expect(difference(render(time:1,motion:0.25,atmosphere:0),render(time:8,motion:0.25,atmosphere:0),box:[0.435,0.54,0.495,0.552]) > 0.25,
                "Canyon Day calm retains primary water")
            expect(difference(waterA,waterB,box:[0.545,0.549,0.56,0.555]) == 0,
                "River flow excludes the right bank inside the winding bend")
        }
        if scene == .canyonNight {
            let waterA = render(time:1,atmosphere:0), waterB = render(time:8,atmosphere:0)
            expect(difference(waterA,waterB,box:[0.315,0.643,0.36,0.679]) > 1,
                "Canyon Night moonlit channel flows without secondary atmosphere")
            expect(difference(waterA,waterB,box:[0.35,0.65,0.395,0.684]) > 0.5,
                "Canyon Night flow includes darker water beside the moonlit run")
            expect(difference(render(time:1,motion:0.25,atmosphere:0),render(time:8,motion:0.25,atmosphere:0),box:[0.315,0.643,0.36,0.679]) > 0.25,
                "Canyon Night calm retains primary river motion")
            expect(difference(waterA,waterB,box:[0.54,0.466,0.56,0.474]) == 0,
                "River excludes the upper wall traversed by the old approximate strip")
            expect(difference(first,next,box:[0.187,0.125,0.205,0.14]) == 0,
                "Cloud and reflected-light response leave the moon itself fixed")
        }
        if scene == .mountainsDay {
            let waterA = render(time:1,atmosphere:0), waterB = render(time:8,atmosphere:0)
            expect(difference(waterA,waterB,box:[0.59,0.485,0.70,0.51]) > 1,
                "Mountains Day lake remains perceptible without secondary atmosphere")
            expect(difference(render(time:1,motion:0.25,atmosphere:0),render(time:8,motion:0.25,atmosphere:0),box:[0.59,0.485,0.70,0.51]) > 0.25,
                "Mountains Day calm retains independent lake motion")
            expect(difference(waterA,waterB,box:[0.13,0.37,0.24,0.43]) == 0,
                "Lake and grass never displace fixed mountain faces")
            expect(difference(waterA,waterB,box:[0.615,0.523,0.63,0.527]) == 0,
                "Lake flow excludes the left-bank peninsula")
            expect(difference(waterA,waterB,box:[0.20,0.925,0.34,0.955]) > 0.1,
                "Material-gated foreground grass responds to wind")
        }
        if scene == .desertDay {
            let heatA=render(time:1,atmosphere:0,weatherAmount:0), heatB=render(time:8,atmosphere:0,weatherAmount:0)
            for box in [[0.48,0.255,0.59,0.275],[0.23,0.285,0.32,0.302],[0.51,0.32,0.65,0.346],[0.73,0.37,0.84,0.408]] {
                expect(difference(heatA,heatB,box:box)>0.5,"Each Desert Day depth zone retains independent heat shimmer")
            }
            expect(difference(render(time:2),render(time:2,weatherAmount:0),box:[0.46,0.30,0.68,0.35])>0.1,
                "Desert Day sand gusts contribute beyond heat refraction")
        }
        if scene == .desertNight {
            let meteorProbe = try device.makeComputePipelineState(function: library.makeFunction(name: "livingDesertMeteorProbe")!)
            let requests = (0..<32).map { SIMD2(Float($0),scene.atmosphere!.light.y) }
            let requestBuffer = device.makeBuffer(bytes:requests,length:requests.count * 8,options:.storageModeShared)!
            let resultBuffer = device.makeBuffer(length:requests.count * 8,options:.storageModeShared)!
            let command = queue.makeCommandBuffer()!, encoder = command.makeComputeCommandEncoder()!
            encoder.setComputePipelineState(meteorProbe)
            encoder.setBuffer(requestBuffer,offset:0,index:0); encoder.setBuffer(resultBuffer,offset:0,index:1)
            encoder.dispatchThreads(MTLSize(width:requests.count,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:1,height:1,depth:1))
            encoder.endEncoding();command.commit();command.waitUntilCompleted()
            expect(command.status == .completed,"production Desert meteor timing probe executes")
            let events = Array(UnsafeBufferPointer(start:resultBuffer.contents().assumingMemoryBound(to:SIMD2<Float>.self),count:requests.count))
            let intervals = zip(events.dropFirst(),events).map { $0.0.x - $0.1.x }
            expect(intervals.allSatisfy { $0 >= 8 && $0 <= 15 },"Desert shooting-star arrivals stay within8–15seconds")
            expect(Set(events.map(\.y)).count > 28,"successive meteor paths and phases vary")
            expect(difference(render(time:1,atmosphere:0),render(time:8,atmosphere:0),box:[0.44,0.53,0.65,0.59]) > 1,
                "Desert Night primary low haze evolves independently of celestial atmosphere")
            expect(difference(render(time:1,motion:0.25,atmosphere:0),render(time:8,motion:0.25,atmosphere:0),box:[0.44,0.53,0.65,0.59]) > 0.15,
                "Desert Night calm retains low haze")
            expect(difference(first,next,box:[0.67,0.23,0.69,0.26]) == 0,
                "Star drift and cloud masks leave the crescent fixed")
        }
        if scene == .mountainsNight {
            let meteorProbe = try device.makeComputePipelineState(function: library.makeFunction(name: "livingMountainsMeteorProbe")!)
            let requests = (0..<32).map { SIMD2(Float($0),scene.atmosphere!.light.y) }
            let requestBuffer = device.makeBuffer(bytes:requests,length:requests.count * 8,options:.storageModeShared)!
            let resultBuffer = device.makeBuffer(length:requests.count * 8,options:.storageModeShared)!
            let command = queue.makeCommandBuffer()!, encoder = command.makeComputeCommandEncoder()!
            encoder.setComputePipelineState(meteorProbe)
            encoder.setBuffer(requestBuffer,offset:0,index:0); encoder.setBuffer(resultBuffer,offset:0,index:1)
            encoder.dispatchThreads(MTLSize(width:requests.count,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:1,height:1,depth:1))
            encoder.endEncoding();command.commit();command.waitUntilCompleted()
            expect(command.status == .completed,"production Mountains meteor timing probe executes")
            let events = Array(UnsafeBufferPointer(start:resultBuffer.contents().assumingMemoryBound(to:SIMD2<Float>.self),count:requests.count))
            let intervals = zip(events.dropFirst(),events).map { $0.0.x - $0.1.x }
            expect(intervals.allSatisfy { $0 >= 20 && $0 <= 30 },"Mountains shooting-star arrivals stay within20–30seconds")
            expect(Set(events.map(\.y)).count > 28,"successive meteor paths and phases vary")
            // These are water checks, independent of the older cloud/fog
            // contribution probes. Full primary-ROI perceptibility is measured
            // from the unobstructed native capture with the frozen ROI contract.
            let waterBounds = [0.12,0.615,0.88,0.745]
            let waterA = render(time: 1, atmosphere: 0)
            let waterB = render(time: 8, atmosphere: 0)
            expect(difference(waterA,waterB,box:waterBounds) > 1.0,
                   "Mountains Night primary lake flows with secondary atmosphere removed")
            let calmWaterA = render(time: 1,motion:0.25,atmosphere:0)
            let calmWaterB = render(time: 8,motion:0.25,atmosphere:0)
            expect(difference(calmWaterA,calmWaterB,box:waterBounds) > 0.25,
                   "Mountains Night calm retains water independently of atmosphere")
            expect(difference(waterA,waterB,box:[0.30,0.37,0.34,0.42]) == 0,
                   "Water changes never move the fixed mountain control")
        }
        try png(calmA,name:"scene-calm")
        let laterA = render(time: 12.0), laterB = render(time: 24.7)
        expect(difference(laterA,laterB,box:regions[0].1) > 0.02, "primary continues evolving over a longer observation")
        try png(laterA,name:"scene-12s"); try png(laterB,name:"scene-24.7s")
        if scene.ocean != nil {
            expect(difference(render(time: 13.0),render(time: 19.3),box:regions[0].1) > 0.1, "new arrival period does not repeat the same water field")
        }

        // A short locally rendered sequence makes the motion inspectable; no
        // renderer code or external service substitutes for the production shader.
        for frame in 0..<90 { try png(render(time: Float(frame)/30), name:String(format:"frame-%03d",frame)) }
        let metrics:[String:Any] = ["assertions":assertions,"artworkPixels":[width,height],"textureBytes":texture.allocatedSize,
            "regionMeanByteDifferences":measured,"scene":scene.themeIdentifier,
            "primaryTemporalROI":primaryTemporal,"staticTemporalROI":staticTemporal,"temporalWindowSeconds":seconds,
            "gpuMeanMilliseconds":durations.reduce(0,+)/Double(durations.count),
            "gpuMaximumMilliseconds":durations.max()!,"device":device.name,
            "limitation":"Host Metal render at original artwork resolution; not physical iPhone pacing or thermal acceptance"]
        try JSONSerialization.data(withJSONObject:metrics,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("render-metrics.json"))
        print("PASS: Living Themes V2 \(assertions) GPU render assertions; \(measured)")
    }
}
