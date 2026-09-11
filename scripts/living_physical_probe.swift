import Foundation
import Metal

// The external driver compiles exact expressions extracted from production
// fragments, together with their original production helper implementations.
@main struct PhysicalProbe {
    static func main() throws {
        let args = CommandLine.arguments
        let device = MTLCreateSystemDefaultDevice()!, queue = device.makeCommandQueue()!
        let library = try device.makeLibrary(URL: URL(fileURLWithPath: args[1]))
        let pipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "physicalProbe")!)
        let snow = args[2] == "snow"
        var requests: [SIMD4<Float>] = []
        if snow {
            // Actual unobstructed open-sky ROI, at 20 independent scene times.
            for t in 0..<20 { for y in 0..<128 { for x in 0..<256 {
                requests.append(SIMD4(0.08+Float(x)/255*0.82,0.08+Float(y)/127*0.19,Float(t),0))
            } } }
        } else {
            requests = (0...100).map { SIMD4(0.4,0.6,Float($0)/10,0) }
        }
        let input = device.makeBuffer(bytes: requests, length: requests.count*16, options: .storageModeShared)!
        let output = device.makeBuffer(length: requests.count*4, options: .storageModeShared)!
        let command = queue.makeCommandBuffer()!, encoder = command.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(input, offset: 0, index: 0); encoder.setBuffer(output, offset: 0, index: 1)
        encoder.dispatchThreads(MTLSize(width: requests.count,height: 1,depth: 1),
            threadsPerThreadgroup: MTLSize(width: min(256,pipeline.maxTotalThreadsPerThreadgroup),height: 1,depth: 1))
        encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
        precondition(command.status == .completed)
        let values = Array(UnsafeBufferPointer(start: output.contents().assumingMemoryBound(to: Float.self), count: requests.count))
        var result: [String: Any] = ["kind":args[2],"sampleCount":values.count,"gpu":device.name]
        if snow {
            result["visible_particle_threshold"] = 0.05
            result["meanParticleIntensity"] = Double(values.reduce(0,+))/Double(values.count)
            result["visibleParticleFraction"] = Double(values.filter { $0 > 0.05 }.count)/Double(values.count)
            result["perSecondFraction"] = (0..<20).map { t in
                Double(values[(t*32768)..<((t+1)*32768)].filter { $0 > 0.05 }.count)/32768
            }
        } else {
            let rates = zip(values,values.dropFirst()).map { Double($1-$0)*10 }
            result["times"] = requests.map { $0.z }
            result["phaseValues"] = values
            result["meanPhaseRate"] = rates.reduce(0,+)/Double(rates.count)
        }
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted,.sortedKeys])
            .write(to: URL(fileURLWithPath: args[3]))
    }
}
