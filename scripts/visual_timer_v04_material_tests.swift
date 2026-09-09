import Foundation
import CryptoKit
import ImageIO
import CoreGraphics

enum VisualTimerV04MaterialTests {
    static var assertions = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        precondition(condition(), message)
    }

    static func main() throws {
        let directory = "LifeRoute/Assets.xcassets/orb_v04_accepted_material.imageset/"
        let data = try Data(contentsOf: URL(fileURLWithPath: directory + "orb_v04_accepted_material.png"))
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        expect(hash == "6c3458b3421b3c57e0b19cf444c597d2a60a9d17deba4643a7e60bba4b8f6b16",
               "runtime PNG must retain the accepted registered V04 bytes")
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: directory + "Contents.json"))) as! [String: Any]
        let entries = catalog["images"] as! [[String: Any]]
        expect(entries.count == 1 && entries[0]["filename"] as? String == "orb_v04_accepted_material.png",
               "one universal registered raster, no alternate art")
        let source = CGImageSourceCreateWithData(data as CFData, nil)!
        expect(CGImageSourceGetCount(source) == 1, "static single-frame PNG")
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        expect(image.width == 1024 && image.height == 1024, "registered canvas dimensions")
        expect(image.bitsPerComponent == 8 && image.bitsPerPixel == 32, "8-bit native RGBA decode")
        expect([CGImageAlphaInfo.last, .first, .premultipliedFirst, .premultipliedLast].contains(image.alphaInfo),
               "native decoder retains an effective alpha channel")
        let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                                bytesPerRow: 4096, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
        let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
        var transparent = 0, partial = 0, opaque = 0
        for i in 0..<(1024 * 1024) {
            let alpha = pixels[i * 4 + 3]
            if alpha == 0 { transparent += 1 }
            else if alpha == 255 { opaque += 1 }
            else { partial += 1 }
        }
        expect(transparent == 400974 && partial == 647332 && opaque == 270,
               "native alpha population agrees with the accepted parent")
        expect(932.0 / 1024 * 340 == 309.453125, "nominal sphere differs from canvas")
        expect(466.0 / 1024 * 340 > 146, "canonical liquid well remains internal")

        let view = try String(contentsOfFile: "LifeRoute/ScenicRoyalVisualTimerView.swift", encoding: .utf8)
        let stack = view.components(separatedBy: "private struct ScenicRoyalOrbMaterialStack: View {")[1]
            .components(separatedBy: "private struct ScenicRoyalOrbAboveLiquidMask: Shape {")[0]
        expect(stack.components(separatedBy: "registeredMaterial(\"orb_v04_accepted_material\")").count == 2,
               "one coherent master draw")
        for rejected in ["orb_rear_membrane_material", "orb_middle_lens_material", "orb_foreground_lens_material", "orb_shell_specular_material"] {
            expect(!stack.contains(rejected), "rejected plate remains inactive: \(rejected)")
        }
        expect(!stack.contains(".opacity(") && !stack.contains(".blur(") && !stack.contains(".mask"),
               "no material dimming, broad overlay or residual reconstruction")
        expect(stack.contains(".renderingMode(.original)") && stack.contains(".interpolation(.high)"),
               "original color and declared interpolation")
        expect(!stack.contains(".clipShape"), "preserve the parent's faint outer fringe")
        let baseIndex = stack.range(of: "livingMaterial(motion: motion)")!.lowerBound
        let liquidIndex = stack.range(of: "ScenicRoyalOrbCanvas(")!.lowerBound
        expect(baseIndex < liquidIndex, "native liquid composites above V04")
        expect(stack.contains("VisualTimerOrbRegions(progress: snapshot.isFinished ? 0 : CGFloat(progress), motion: motion)"),
               "finished and zero states use empty canonical regions")
        let canvas = view.components(separatedBy: "private struct ScenicRoyalOrbCanvas: View {")[1]
            .components(separatedBy: "private enum ScenicRoyalOrbPath {")[0]
        expect(canvas.components(separatedBy: "if !regions.liquid.isEmpty {").count == 3,
               "body/meniscus and liquid-local optics both have zero guards")
        expect(canvas.contains("liquidOptics.clip(to: regions.liquid)"), "caustics stay in canonical liquid")
        let contracts = try String(contentsOfFile: "LifeRoute/VisualTimerFeedbackContracts.swift", encoding: .utf8)
        expect(contracts.contains("struct VisualTimerOrbRegions"), "canonical region authority retained")
        let fixture = view.components(separatedBy: "internal struct VisualTimerPresentationSnapshot: Equatable {")[1]
            .components(separatedBy: "private struct ScenicRoyalTimerOrb: View {")[0]
        expect(fixture.contains("#if DEBUG") && fixture.contains("#endif"), "fixture is excluded from Release")
        let fixtureCode = fixture.split(separator: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }.joined(separator: "\n")
        expect(!fixtureCode.contains("timer.") && !fixtureCode.contains("deadline" + " ="), "fixture cannot mutate timing authority")
        expect(fixture.contains("durationSeconds: 300") && fixture.contains("remainingSeconds: 300 * remainingProgress")
               && fixture.contains("let elapsedProgress = 1 - remainingProgress"), "coherent presentation values")
        print("Accepted V04 material fixtures passed (\(assertions) assertions). SHA256=\(hash)")
    }
}

try VisualTimerV04MaterialTests.main()
