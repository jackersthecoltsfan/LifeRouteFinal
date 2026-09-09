import Foundation
import Metal
import simd

@main
struct VisualTimerCrystalMotionTests {
    static func main() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Metal GPU required") }
        // Execute the production shader itself. The appended kernel measures its
        // coordinates, local Jacobian and next-frame travel; no copied flow model.
        let source = try String(contentsOfFile: "LifeRoute/VisualTimerOrbMotion.metal", encoding: .utf8)
        let kernel = """
        kernel void probeOrb(device const float4 *frames [[buffer(0)]],
                             device float4 *result [[buffer(1)]], uint id [[thread_position_in_grid]]) {
            uint cell = id % 4761;
            float2 p = float2(cell % 69, cell / 69) * 5.0;
            float4 f = frames[id / 4761];
            float2 v = livingOrbInterior(p, f.x, f.y, f.z, f.w);
            float2 dx = (livingOrbInterior(p + float2(0.05, 0), f.x, f.y, f.z, f.w) - v) / 0.05;
            float2 dy = (livingOrbInterior(p + float2(0, 0.05), f.x, f.y, f.z, f.w) - v) / 0.05;
            float2 next = livingOrbInterior(p, f.x + 1.0 / 30.0, f.y, f.z, f.w);
            result[id] = float4(v, dx.x * dy.y - dx.y * dy.x, length(next - v));
        }
        """
        // Remove only the SwiftUI linking attribute for direct compute invocation;
        // the function body and every production coefficient remain unchanged.
        let computeSource = source.replacingOccurrences(of: "[[ stitchable ]]", with: "")
        let library = try device.makeLibrary(source: computeSource + "\n" + kernel, options: nil)
        let pipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "probeOrb")!)
        var frames: [SIMD4<Float>] = []
        for urgency in [0.0, 0.5, 1.0] {
            // Shader frequencies are hundredths of radians/second. Sweep their
            // full common cycle (~628 seconds), including long-running timers.
            for tick in 0...1257 {
                let motion = VisualTimerOrbMotionFrame(elapsed: Double(tick) / 2, progress: 0.5, urgency: urgency)
                frames.append(SIMD4(Float(motion.crystalTime), Float(motion.crystalEnergy), Float(motion.alertness), 0))
                let pulsePeak = VisualTimerOrbMotionFrame(
                    elapsed: Double(tick) / 2,
                    progress: 0.5,
                    urgency: urgency,
                    pulsePhase: 0
                )
                frames.append(SIMD4(Float(pulsePeak.crystalTime), Float(pulsePeak.crystalEnergy), Float(pulsePeak.alertness), Float(pulsePeak.pulse)))
            }
        }
        let count = frames.count * 4761
        let input = device.makeBuffer(bytes: frames, length: frames.count * MemoryLayout<SIMD4<Float>>.stride)!
        let output = device.makeBuffer(length: count * MemoryLayout<SIMD4<Float>>.stride, options: .storageModeShared)!
        let command = device.makeCommandQueue()!.makeCommandBuffer()!
        let encoder = command.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(input, offset: 0, index: 0)
        encoder.setBuffer(output, offset: 0, index: 1)
        encoder.dispatchThreads(MTLSize(width: count, height: 1, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: pipeline.threadExecutionWidth, height: 1, depth: 1))
        encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
        precondition(command.status == .completed, "production shader must execute")
        let values = output.contents().bindMemory(to: SIMD4<Float>.self, capacity: count)
        var minJacobian: Float = 100, maxTravel: Float = 0, maxStep: Float = 0
        var outerFringeStable = true, restingRimStable = true, contained = true, stillExact = true
        var rimPeak: Float = 0
        var peaks: [Float] = [0, 0, 0]
        let anchors = [SIMD2<Float>(130, 140), SIMD2<Float>(170, 215), SIMD2<Float>(240, 105)]
        for i in 0..<count {
            let cell = i % 4761
            let p = SIMD2<Float>(Float(cell % 69) * 5, Float(cell / 69) * 5)
            let v = values[i], mapped = SIMD2(v.x, v.y)
            let travel = simd_length(mapped - p)
            minJacobian = min(minJacobian, v.z); maxTravel = max(maxTravel, travel); maxStep = max(maxStep, v.w)
            let radius = simd_length(p - SIMD2(repeating: 170))
            if radius >= 163 { outerFringeStable = outerFringeStable && mapped == p }
            if radius >= 145 && frames[i / 4761].w == 0 { restingRimStable = restingRimStable && mapped == p }
            if radius < 137 { contained = contained && simd_length(mapped - SIMD2(repeating: 170)) < 149 }
            if (149...157).contains(radius), frames[i / 4761].w > 0 {
                rimPeak = max(rimPeak, travel)
            }
            if frames[i / 4761].y == 0 { stillExact = stillExact && mapped == p }
            // Visibility floor is checked at high remaining time (zero urgency).
            if frames[i / 4761].z == 0 {
                for j in anchors.indices where p == anchors[j] { peaks[j] = max(peaks[j], travel) }
            }
        }
        let metrics = "CRYSTAL_METRICS minJacobian=\(minJacobian) maxTravel=\(maxTravel) maxFrameStep=\(maxStep) earlyFormPeaks=\(peaks) rimPeak=\(rimPeak)\n"
        FileHandle.standardError.write(Data(metrics.utf8))
        precondition(outerFringeStable, "pixels beyond the bounded rim band remain exactly stable")
        precondition(restingRimStable, "the rim returns exactly to V04 coordinates between beats")
        precondition(contained, "internal pixels cannot expose the shell boundary")
        precondition(stillExact, "static/Reduce Motion shader coordinates must be identical")
        precondition(minJacobian > 0.12, "flow must not fold or detach crystal material")
        precondition(maxTravel < 48, "displacement must respect SwiftUI sample bounds")
        precondition(maxStep < 2.2, "adjacent 30 Hz frames remain continuous")
        precondition(peaks.allSatisfy { $0 > 8 }, "all three crystal forms move visibly even without urgency")
        precondition(rimPeak > 2.5 && rimPeak < 5, "shared beat produces a bounded visible rim heartbeat")
        print("Crystal motion GPU checks passed (10 assertions, \(count) native shader samples). " +
              "minJacobian=\(minJacobian) maxTravel=\(maxTravel) maxFrameStep=\(maxStep) earlyFormPeaks=\(peaks) rimPeak=\(rimPeak)")
    }
}
