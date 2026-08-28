import AppKit
import Foundation
import Vision

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("v0.7.1 fixture text validation failed: \(message)\n".utf8))
    exit(1)
}

let pairs = CommandLine.arguments.dropFirst()
guard !pairs.isEmpty else {
    fail("usage: swift validate_v0_7_1_fixture_text.swift PNG=EXPECTED_TEXT ...")
}

for pair in pairs {
    guard let separator = pair.firstIndex(of: "=") else { fail("invalid PNG=EXPECTED_TEXT argument: \(pair)") }
    let path = String(pair[..<separator])
    let expected = String(pair[pair.index(after: separator)...]).lowercased()
    guard let image = NSImage(contentsOfFile: path), let data = image.tiffRepresentation,
          let representation = NSBitmapImageRep(data: data), let cgImage = representation.cgImage else {
        fail("cannot decode \(path)")
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    do { try VNImageRequestHandler(cgImage: cgImage).perform([request]) }
    catch { fail("Vision failed for \(path): \(error)") }
    let observations = request.results ?? []
    let recognized = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ").lowercased()
    let normalized = recognized.replacingOccurrences(of: " ", with: "")
    let normalizedExpected = expected.replacingOccurrences(of: " ", with: "")
    guard !normalized.contains("openinliferoute"), !normalized.contains("cancelopen") else {
        fail("\(URL(fileURLWithPath: path).lastPathComponent) contains a system URL confirmation: \(recognized)")
    }
    let foundNearTop = observations.contains { observation in
        guard observation.boundingBox.midY > 0.78,
              let text = observation.topCandidates(1).first?.string.lowercased() else {
            return false
        }
        return text.replacingOccurrences(of: " ", with: "").contains(normalizedExpected)
    }
    guard foundNearTop else {
        fail("\(URL(fileURLWithPath: path).lastPathComponent) did not contain top title '\(expected)'; recognized: \(recognized)")
    }
    print("text \(URL(fileURLWithPath: path).lastPathComponent): found top title '\(expected)' with no URL dialog")
}
