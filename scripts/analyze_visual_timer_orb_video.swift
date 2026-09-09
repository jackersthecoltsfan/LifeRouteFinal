import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct RGBFrame {
    let width: Int
    let height: Int
    let bytes: [UInt8]
}

struct DifferenceSample {
    let interiorMean: Double
    let interiorChangedFraction: Double
    let rimMean: Double
    let rimChangedFraction: Double
}

func renderedFrame(_ image: CGImage) -> RGBFrame {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
    let space = CGColorSpaceCreateDeviceRGB()
    let info = CGImageAlphaInfo.premultipliedLast.rawValue
        | CGBitmapInfo.byteOrder32Big.rawValue
    let context = CGContext(
        data: &bytes,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: space,
        bitmapInfo: info
    )!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return RGBFrame(width: width, height: height, bytes: bytes)
}

func difference(_ lhs: RGBFrame, _ rhs: RGBFrame) -> DifferenceSample {
    precondition(lhs.width == rhs.width && lhs.height == rhs.height)
    // Phase 1AJ full-screen iPhone layout: the Orb's center and radius are
    // expressed as screen fractions so the evidence remains resolution-aware.
    let centerX = Double(lhs.width) * 0.5
    let centerY = Double(lhs.height) * 0.405
    let radius = Double(lhs.width) * 0.382
    var interiorTotal = 0.0, rimTotal = 0.0
    var interiorChanged = 0, rimChanged = 0
    var interiorCount = 0, rimCount = 0

    for y in 0..<lhs.height {
        let dy = Double(y) - centerY
        for x in 0..<lhs.width {
            let dx = Double(x) - centerX
            let normalizedRadius = hypot(dx, dy) / radius
            let hidesReadout = abs(dx) < radius * 0.42 && abs(dy) < radius * 0.22
            let isInterior = normalizedRadius < 0.82 && !hidesReadout
            let isRim = (0.90...1.06).contains(normalizedRadius)
            guard isInterior || isRim else { continue }

            let offset = (y * lhs.width + x) * 4
            let delta = (0..<3).reduce(0.0) { total, channel in
                total + Double(abs(Int(lhs.bytes[offset + channel]) - Int(rhs.bytes[offset + channel])))
            } / 3
            if isInterior {
                interiorTotal += delta
                interiorCount += 1
                if delta >= 3 { interiorChanged += 1 }
            }
            if isRim {
                rimTotal += delta
                rimCount += 1
                if delta >= 3 { rimChanged += 1 }
            }
        }
    }

    return DifferenceSample(
        interiorMean: interiorTotal / Double(interiorCount),
        interiorChangedFraction: Double(interiorChanged) / Double(interiorCount),
        rimMean: rimTotal / Double(rimCount),
        rimChangedFraction: Double(rimChanged) / Double(rimCount)
    )
}

func summary(_ values: [Double]) -> String {
    let sorted = values.sorted()
    let middle = sorted[sorted.count / 2]
    return String(format: "min=%.4f median=%.4f max=%.4f", sorted.first!, middle, sorted.last!)
}

@main
struct OrbVideoAnalyzer {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            fatalError("usage: analyze_visual_timer_orb_video VIDEO")
        }
        let asset = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        var frames: [RGBFrame] = []
        for time in stride(from: 0.75, through: 6.75, by: 0.25) {
            let requested = CMTime(seconds: time, preferredTimescale: 600)
            let image = try generator.copyCGImage(at: requested, actualTime: nil)
            frames.append(renderedFrame(image))
        }
        precondition(frames.count > 2, "video must contain a settled multi-frame interval")

        let samples = zip(frames, frames.dropFirst()).map(difference)
        let interiorMeans = samples.map(\.interiorMean)
        let interiorFractions = samples.map(\.interiorChangedFraction)
        let rimMeans = samples.map(\.rimMean)
        let rimFractions = samples.map(\.rimChangedFraction)
        print("ORB_VIDEO frames=\(frames.count) interval=0.25s size=\(frames[0].width)x\(frames[0].height)")
        print("ORB_INTERIOR meanRGBDelta \(summary(interiorMeans))")
        print("ORB_INTERIOR changedFraction \(summary(interiorFractions))")
        print("ORB_RIM meanRGBDelta \(summary(rimMeans))")
        print("ORB_RIM changedFraction \(summary(rimFractions))")
    }
}
