import Foundation
import AVFoundation

@main struct CompressLivingEvidence {
    static func main() async throws {
        let args = CommandLine.arguments
        let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
        let duration = try await asset.load(.duration)
        let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset960x540)!
        try await export.export(to: URL(fileURLWithPath: args[2]), as: .mp4)
        let result = AVURLAsset(url: URL(fileURLWithPath: args[2]))
        let after = try await result.load(.duration)
        precondition(abs(duration.seconds - after.seconds) < 0.1)
        print("VIDEO_VERIFIED duration=\(after.seconds)")
    }
}
