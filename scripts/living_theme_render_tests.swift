import Foundation
import MetalKit
import ImageIO
import UniformTypeIdentifiers

@main struct LivingThemeRenderTests {
    static func main() throws {
        let args = CommandLine.arguments
        precondition(args.count == 4, "library, original artwork, output directory required")
        let output = URL(fileURLWithPath: args[3], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let device = MTLCreateSystemDefaultDevice()!
        let library = try device.makeLibrary(URL: URL(fileURLWithPath: args[1]))
        let pipelineDescription = MTLRenderPipelineDescriptor()
        pipelineDescription.vertexFunction = library.makeFunction(name: "livingSceneVertex")
        pipelineDescription.fragmentFunction = library.makeFunction(name: LivingThemeScene.rainforestDay.fragmentFunction)
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
        let still = render(time: 0, motion: 0)
        expect(still == render(time: 900, motion: 0), "Reduce Motion is exactly static at any time")
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
        let regions: [(String,[Double],Bool)] = [
            ("falling water",[0.535,0.425,0.567,0.492],true),
            ("stream surface",[0.573,0.571,0.636,0.607],true),
            ("leaf cluster",[0.67,0.18,0.76,0.22],true),
            ("fixed trunk",[0.02,0.15,0.12,0.55],false),
            ("fixed canopy",[0.32,0.03,0.48,0.13],false),
            ("fixed rock bank",[0.35,0.58,0.43,0.68],false),
        ]
        var measured: [String:Double] = [:]
        for (name,box,moving) in regions {
            let value = difference(first,next,box:box)
            measured[name] = value
            expect(moving ? value > 0.4 : value == 0, "\(name) expected \(moving ? "motion" : "fixed") but difference=\(value)")
        }
        let mistOn = render(time: 0.3), mistOff = render(time: 0.3, atmosphere: 0)
        expect(difference(mistOn,mistOff,box:[0.56,0.51,0.61,0.55]) > 0.2, "mist has localized visible contribution")
        let wrap:Float = 1.0 / 0.63
        let before = render(time: wrap - 0.0001), after = render(time: wrap + 0.0001)
        let wrapDifference = difference(before,after,box:[0.53,0.41,0.58,0.54])
        expect(wrapDifference < 0.2, "water phase handover has no discontinuity")
        expect(stride(from: 3, to: first.count, by: 4).allSatisfy { first[$0] == 255 }, "one opaque pass")
        try png(first,name:"rainforest-0.3s")
        try png(next,name:"rainforest-1.3s")
        try png(still,name:"rainforest-reduced")
        // A short locally rendered sequence makes the motion inspectable; no
        // renderer code or external service substitutes for the production shader.
        for frame in 0..<90 { try png(render(time: Float(frame)/30), name:String(format:"frame-%03d",frame)) }
        let metrics:[String:Any] = ["assertions":assertions,"artworkPixels":[width,height],"textureBytes":texture.allocatedSize,
            "regionMeanByteDifferences":measured,"phaseWrapMeanByteDifference":wrapDifference,
            "gpuMeanMilliseconds":durations.reduce(0,+)/Double(durations.count),
            "gpuMaximumMilliseconds":durations.max()!,"device":device.name,
            "limitation":"Host Metal render at original artwork resolution; not physical iPhone pacing or thermal acceptance"]
        try JSONSerialization.data(withJSONObject:metrics,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("render-metrics.json"))
        print("PASS: Living Themes V2 \(assertions) GPU render assertions; \(measured)")
    }
}
