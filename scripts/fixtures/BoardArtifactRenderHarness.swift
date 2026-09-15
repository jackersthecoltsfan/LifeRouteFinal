import SwiftUI
import UIKit
import PDFKit
import ImageIO
import CryptoKit

// Harmless external host stub; does not alter the copied product source.
extension View {
    func lifeRouteModalScope() -> some View { self }
}

private struct Fixture {
    let name: String
    let board: BoardArtifact
}

@MainActor
private enum BoardReview {
    static let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("BoardReview-" + (ProcessInfo.processInfo.environment["BOARD_REVIEW_RUN_ID"] ?? "Manual"), isDirectory: true)
    static var records: [[String: Any]] = []
    static var checks: [[String: Any]] = []
    static var layoutRecords: [[String: Any]] = []
    static let fixedDate = Date(timeIntervalSince1970: 1_789_488_000)

    static func check(_ result: Bool, _ name: String) {
        checks.append(["name": name, "pass": result])
    }

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func pixelHash(_ image: UIImage) -> String {
        guard let cg = image.cgImage else { return "NO_CGIMAGE" }
        let width = cg.width, height = cg.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &bytes, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return "NO_CONTEXT" }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        return hash(Data(bytes))
    }

    static func vectorImage(index: Int, size: CGSize) -> Data {
        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemTeal]
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.pngData { render in
            let context = render.cgContext
            colors[index % colors.count].setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let shortest = min(size.width, size.height)
            let radius = shortest * 0.27
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            UIColor.white.setFill()
            switch index % 3 {
            case 0:
                context.fill(CGRect(x: center.x - radius, y: center.y - radius,
                                    width: radius * 2, height: radius * 2))
            case 1:
                context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                              width: radius * 2, height: radius * 2))
            default:
                context.move(to: CGPoint(x: center.x, y: center.y - radius))
                context.addLine(to: CGPoint(x: center.x + radius, y: center.y + radius))
                context.addLine(to: CGPoint(x: center.x - radius, y: center.y + radius))
                context.closePath()
                context.fillPath()
            }
            UIColor.black.setFill()
            let marker = shortest * 0.055, inset = shortest * 0.08
            for x in [inset, size.width - inset - marker] {
                for y in [inset, size.height - inset - marker] {
                    context.fill(CGRect(x: x, y: y, width: marker, height: marker))
                }
            }
        }
    }

    static func fixtures() throws -> [Fixture] {
        let fixtureDir = output.appendingPathComponent("fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureDir, withIntermediateDirectories: true)
        let sizes: [CGSize] = [CGSize(width: 4096, height: 1024), CGSize(width: 1024, height: 4096),
                               CGSize(width: 2400, height: 2400), CGSize(width: 3072, height: 1536),
                               CGSize(width: 1536, height: 3072), CGSize(width: 2000, height: 2000)]
        let names = ["Red rectangle", "Blue circle", "Green triangle", "Orange square", "Purple circle", "Teal triangle"]
        var items: [BoardArtifact.Item] = []
        for index in sizes.indices {
            let original = vectorImage(index: index, size: sizes[index])
            let source = CGImageSourceCreateWithData(original as CFData, nil)!
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
            let encoded = NSMutableData()
            let destination = CGImageDestinationCreateWithData(encoded, "public.png" as CFString, 1, nil)!
            let metadata: [CFString: Any] = [
                kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "SYNTHETIC_SOURCE_SENTINEL"],
                kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 1.234, kCGImagePropertyGPSLatitudeRef: "N", kCGImagePropertyGPSLongitude: 2.345, kCGImagePropertyGPSLongitudeRef: "E"]
            ]
            CGImageDestinationAddImage(destination, image, metadata as CFDictionary)
            precondition(CGImageDestinationFinalize(destination))
            let data = encoded as Data
            try data.write(to: fixtureDir.appendingPathComponent("fixture_\(index + 1).png"))
            let imageID = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!
            items.append(.init(id: imageID, label: names[index], imageID: imageID, imageData: data))
        }
        var schedule: [BoardArtifact.Item] = []
        for index in 0..<9 {
            let image = items[index % items.count]
            schedule.append(.init(id: UUID(), label: String(format: "Step %02d — ", index + 1) + image.label,
                                  imageID: image.imageID, imageData: image.imageData))
        }
        let longSchedule: [BoardArtifact.Item] = (0..<21).map { index in
            let image = items[index % items.count]
            return .init(id: UUID(), label: String(format: "Step %02d — ", index + 1) + image.label,
                         imageID: UUID(), imageData: image.imageData)
        }
        let long = "A deliberately long instructional label for a calm transition between preferred activities and the next learning opportunity"
        let longItems = items.enumerated().map { index, item in
            BoardArtifact.Item(id: item.id, label: "\(index + 1). \(long)", imageID: item.imageID, imageData: item.imageData)
        }
        return [
            Fixture(name: "first_then", board: .init(id: UUID(), kind: .firstThen, title: "First / Then — image fit", items: Array(items.prefix(2)))),
            Fixture(name: "choice_2_columns", board: .init(id: UUID(), kind: .choice, title: "Choose an activity", items: items, columns: 2)),
            Fixture(name: "choice_3_columns", board: .init(id: UUID(), kind: .choice, title: "Six clear choices", items: items, columns: 3)),
            Fixture(name: "schedule_9_items", board: .init(id: UUID(), kind: .schedule, title: "Nine-step visual schedule", items: schedule)),
            Fixture(name: "long_schedule_21", board: .init(id: UUID(), kind: .schedule, title: "Twenty-one-step schedule", items: longSchedule)),
            Fixture(name: "token_5", board: .init(id: UUID(), kind: .token, title: "Earn a preferred activity", items: [items[2]], tokenCount: 5)),
            Fixture(name: "token_10", board: .init(id: UUID(), kind: .token, title: "Ten-token reward board", items: [items[4]], tokenCount: 10)),
            Fixture(name: "long_labels", board: .init(id: UUID(), kind: .choice, title: "A long title for the instructional board remains outside every image cell", items: Array(longItems.prefix(3)), columns: 3)),
            Fixture(name: "text_only_choice", board: .init(id: UUID(), kind: .choice, title: "Two text choices", items: [.init(id: UUID(), label: "Read a book", imageID: nil, imageData: nil), .init(id: UUID(), label: "Take a quiet break", imageID: nil, imageData: nil)])),
            Fixture(name: "text_only_schedule", board: .init(id: UUID(), kind: .schedule, title: "Text schedule", items: [.init(id: UUID(), label: "Collect materials", imageID: nil, imageData: nil), .init(id: UUID(), label: "Choose the next activity", imageID: nil, imageData: nil)])),
            Fixture(name: "text_only_token", board: .init(id: UUID(), kind: .token, title: "Text-only reward", items: [.init(id: UUID(), label: "A quiet break in the reading corner", imageID: nil, imageData: nil)], tokenCount: 3))
        ]
    }

    static func writeImage(_ image: UIImage, to url: URL) throws {
        guard let png = image.pngData() else { throw BoardExportError.renderFailed }
        try png.write(to: url)
    }

    static func pdfImage(_ page: PDFPage) -> UIImage {
        let box = page.bounds(for: .mediaBox)
        let format = UIGraphicsImageRendererFormat()
        format.scale = min(2, 6000 / max(1, box.height))
        format.opaque = true
        return UIGraphicsImageRenderer(size: box.size, format: format).image { render in
            UIColor.white.setFill()
            render.fill(CGRect(origin: .zero, size: box.size))
            render.cgContext.translateBy(x: 0, y: box.height)
            render.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: render.cgContext)
        }
    }

    static func review(_ fixture: Fixture) async throws {
        let dir = output.appendingPathComponent(fixture.name, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for page in fixture.board.pages.indices {
            let loaded = try await BoardImageLoader.shared.load(fixture.board, page: page)
            let expected = Set(fixture.board.pages[page].compactMap(\.imageID))
            check(Set(loaded.keys) == expected, fixture.name + " page \(page + 1) exact image IDs decoded")
            if fixture.board.kind == .schedule { check(loaded.count <= 4, fixture.name + " page \(page + 1) at most four decoded images retained") }
        }
        let first = try await BoardExporter.export(fixture.board, format: .image, date: fixedDate)
        let repeated = try await BoardExporter.export(fixture.board, format: .image, date: fixedDate)
        check(first.count == fixture.board.pages.count, fixture.name + " PNG page count")
        var pngRecords: [[String: Any]] = []
        for index in first.indices {
            let data = try Data(contentsOf: first[index])
            let repeatedData = try Data(contentsOf: repeated[index])
            guard let image = UIImage(data: data), let other = UIImage(data: repeatedData), let cg = image.cgImage else {
                throw BoardExportError.renderFailed
            }
            let destination = dir.appendingPathComponent(String(format: "export_%02d.png", index + 1))
            try data.write(to: destination)
            let repeatedHash = pixelHash(other)
            let initialHash = pixelHash(image)
            check(initialHash == repeatedHash, fixture.name + " page \(index + 1) repeated PNG pixels")
            check(cg.width == 1836 && cg.height > 0, fixture.name + " page \(index + 1) raster size")
            let source = CGImageSourceCreateWithData(data as CFData, nil)!
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
            check(properties[kCGImagePropertyGPSDictionary as String] == nil && !String(describing: properties).contains("SYNTHETIC_SOURCE_SENTINEL"),
                  fixture.name + " page \(index + 1) no source comment or GPS")
            pngRecords.append(["page": index + 1, "width": cg.width, "height": cg.height,
                               "bytes": data.count, "pixel_sha256": initialHash,
                               "repeated_pixel_sha256": repeatedHash, "file": destination.lastPathComponent,
                               "export_name": first[index].lastPathComponent])
        }
        let pdfURL = try await BoardExporter.export(fixture.board, format: .pdf, date: fixedDate)[0]
        let repeatedPDF = try await BoardExporter.export(fixture.board, format: .pdf, date: fixedDate)[0]
        let pdfData = try Data(contentsOf: pdfURL)
        try pdfData.write(to: dir.appendingPathComponent("export.pdf"))
        guard let document = PDFDocument(data: pdfData), let other = PDFDocument(url: repeatedPDF) else {
            throw BoardExportError.renderFailed
        }
        check(document.pageCount == fixture.board.pages.count, fixture.name + " PDF page count")
        var pdfRecords: [[String: Any]] = []
        for index in 0..<document.pageCount {
            let page = document.page(at: index)!
            let text = page.string ?? ""
            func normalized(_ value: String) -> String { value.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ") }
            let normalizedText = normalized(text)
            let allLabels = fixture.board.pages[index].allSatisfy { normalizedText.contains(normalized($0.label)) }
            check(allLabels, fixture.name + " PDF page \(index + 1) all labels extract")
            check(normalizedText.contains(normalized(fixture.board.title)), fixture.name + " PDF page \(index + 1) title extracts")
            let forbidden = ["Share Image", "Save Image to Photos", "Share PDF / Save to Files", "Close board preview", "Preparing export"]
            check(!forbidden.contains(where: text.contains), fixture.name + " PDF page \(index + 1) no export chrome")
            let rendered = pdfImage(page)
            let otherImage = pdfImage(other.page(at: index)!)
            check(pixelHash(rendered) == pixelHash(otherImage), fixture.name + " PDF page \(index + 1) repeated pixels")
            try writeImage(rendered, to: dir.appendingPathComponent(String(format: "pdf_%02d.png", index + 1)))
            let box = page.bounds(for: .mediaBox)
            pdfRecords.append(["page": index + 1, "width": box.width, "height": box.height, "text": text,
                               "pixel_sha256": pixelHash(rendered)])
        }
        let images = try await BoardImageLoader.shared.load(fixture.board)
        var previews: [[String: Any]] = []
        for (tag, width, type) in [("narrow", CGFloat(304), DynamicTypeSize.large),
                                   ("wide", CGFloat(820), DynamicTypeSize.large),
                                   ("narrow_accessibility", CGFloat(304), DynamicTypeSize.accessibility5)] {
            let canvas = BoardCanvas(board: fixture.board, page: 0, images: images, width: width).environment(\.dynamicTypeSize, type)
            let renderer = ImageRenderer(content: canvas)
            renderer.proposedSize = .init(width: width, height: nil)
            renderer.scale = 2
            renderer.isOpaque = true
            var measured = CGSize.zero
            renderer.render { size, _ in measured = size }
            let measurement = try JSONSerialization.data(withJSONObject: ["width": measured.width, "height": measured.height], options: [.prettyPrinted])
            try measurement.write(to: dir.appendingPathComponent("measurement_\(tag).json"))
            if measured.height * 2 <= 8000, let image = renderer.uiImage, let cg = image.cgImage {
                try writeImage(image, to: dir.appendingPathComponent("preview_\(tag).png"))
                check(cg.width == Int(width * 2), fixture.name + " \(tag) canvas width")
                previews.append(["name": tag, "width": cg.width, "height": cg.height])
            } else {
                previews.append(["name": tag, "measured_width": measured.width, "measured_height": measured.height, "whole_image": "Tall canvas rendered in bounded tiles to avoid PNG encoder dimension limits"])
                check(measured.width == width && measured.height > 0, fixture.name + " \(tag) measured canvas size")
                guard measured.height <= 32000 else { throw BoardExportError.tooLarge }
                var tileIndex = 0
                for offset in stride(from: CGFloat(0), to: measured.height, by: 1200) {
                    tileIndex += 1
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1
                    format.opaque = true
                    let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: min(1200, measured.height - offset)), format: format).image { context in
                        UIColor.white.setFill()
                        context.fill(CGRect(x: 0, y: 0, width: width, height: min(1200, measured.height - offset)))
                        context.cgContext.translateBy(x: 0, y: -offset)
                        renderer.render { _, draw in draw(context.cgContext) }
                    }
                    try writeImage(image, to: dir.appendingPathComponent(String(format: "preview_\(tag)_tile_%02d.png", tileIndex)))
                }
            }
        }
        records.append(["name": fixture.name, "kind": fixture.board.kind.rawValue,
                        "png": pngRecords, "pdf": pdfRecords, "pdf_bytes": pdfData.count,
                        "previews": previews])
        try checkpoint(status: "RUNNING")
    }

    static func reviewCurrentLayout(_ fixture: Fixture, tag: String, width: CGFloat, type: DynamicTypeSize) async throws {
        let dir = output.appendingPathComponent("current-layouts/\(fixture.name)_\(tag)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var measurements: [[String: Any]] = []
        var sizes: [CGSize] = []
        func scaleFor(_ size: CGSize) -> CGFloat { min(max(3, 1836 / width), 8000 / size.height, sqrt(20_000_000 / (size.width * size.height))) }
        for page in fixture.board.pages.indices {
            let images = try await BoardImageLoader.shared.load(fixture.board, page: page)
            let renderer = ImageRenderer(content: BoardCanvas(board: fixture.board, page: page, images: images, width: width).environment(\.dynamicTypeSize, type))
            renderer.proposedSize = .init(width: width, height: nil)
            renderer.isOpaque = true
            var size = CGSize.zero
            renderer.render { value, _ in size = value }
            sizes.append(size)
            measurements.append(["page": page + 1, "width": size.width, "height": size.height,
                                 "raster_width": size.width * scaleFor(size), "raster_height": size.height * scaleFor(size)])
        }
        var record: [String: Any] = ["fixture": fixture.name, "layout": tag, "measurements": measurements]
        for format in [BoardExporter.Format.image, .pdf] {
            let isPNG = format == .image
            let key = isPNG ? "png" : "pdf"
            let withinBudget = sizes.allSatisfy { $0.height <= 4000 && $0.width * scaleFor($0) >= 600 }
            do {
                let files = try await BoardExporter.export(fixture.board, format: format, date: fixedDate,
                                                           layout: .init(width: width, textSize: type))
                record[key + "_status"] = "EXPORTED"
                if isPNG {
                    for index in files.indices {
                        let data = try Data(contentsOf: files[index])
                        let image = UIImage(data: data)!
                        try data.write(to: dir.appendingPathComponent(String(format: "export_%02d.png", index + 1)))
                        let images = try await BoardImageLoader.shared.load(fixture.board, page: index)
                        let renderer = ImageRenderer(content: BoardCanvas(board: fixture.board, page: index, images: images, width: width).environment(\.dynamicTypeSize, type))
                        renderer.proposedSize = .init(width: width, height: nil)
                        renderer.scale = scaleFor(sizes[index])
                        renderer.isOpaque = true
                        if let cg = renderer.cgImage {
                            let direct = UIImage(cgImage: cg)
                            check(pixelHash(image) == pixelHash(direct), fixture.name + " " + tag + " page \(index + 1) exported pixels match exact current canvas")
                        } else { check(false, fixture.name + " " + tag + " direct comparison render") }
                    }
                } else {
                    let data = try Data(contentsOf: files[0])
                    try data.write(to: dir.appendingPathComponent("export.pdf"))
                    let document = PDFDocument(data: data)!
                    check(document.pageCount == fixture.board.pages.count, fixture.name + " " + tag + " PDF page count")
                    for index in 0..<document.pageCount {
                        let page = document.page(at: index)!
                        let box = page.bounds(for: .mediaBox)
                        let images = try await BoardImageLoader.shared.load(fixture.board, page: index)
                        let direct = ImageRenderer(content: BoardCanvas(board: fixture.board, page: index, images: images, width: width).environment(\.dynamicTypeSize, type))
                        direct.proposedSize = .init(width: width, height: nil)
                        direct.scale = scaleFor(sizes[index])
                        var finalSize = CGSize.zero
                        direct.render { size, _ in finalSize = size }
                        check(abs(box.height - finalSize.height * 612 / width) < 0.05,
                              fixture.name + " " + tag + " PDF page \(index + 1) preserves exact preview aspect ratio")
                        // Keep bounded native PDF renders; full PDF remains retained.
                        if box.height < 6000 {
                            try writeImage(pdfImage(page), to: dir.appendingPathComponent(String(format: "pdf_%02d.png", index + 1)))
                        }
                    }
                }
            } catch {
                record[key + "_status"] = "REJECTED: \(error)"
                record[key + "_message"] = error.localizedDescription
                check(!withinBudget, fixture.name + " " + tag + " " + key + " rejects only a measured oversized fixture")
                let exportRoot = FileManager.default.temporaryDirectory.appendingPathComponent("LifeRouteBoardExports")
                let folders = (try? FileManager.default.contentsOfDirectory(at: exportRoot, includingPropertiesForKeys: nil)) ?? []
                let emptyFolders = folders.filter { ((try? FileManager.default.contentsOfDirectory(atPath: $0.path)) ?? []).isEmpty }
                check(emptyFolders.isEmpty, fixture.name + " " + tag + " " + key + " no empty failed export directory")
            }
        }
        layoutRecords.append(record)
        try checkpoint(status: "RUNNING")
    }

    static func checkpoint(status: String, error: String? = nil) throws {
        var report: [String: Any] = ["status": status, "records": records, "checks": checks,
                                   "failed_checks": checks.filter { ($0["pass"] as? Bool) != true }, "layout_records": layoutRecords]
        if let error { report["error"] = error }
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: output.appendingPathComponent("REPORT.json"), options: .atomic)
    }

    static func run() async -> String {
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let cases = try fixtures()
            if ProcessInfo.processInfo.arguments.contains("--probe-raster") {
                try await probeRaster(cases.first { $0.name == "choice_3_columns" }!)
                return "Raster probe complete"
            }
            for fixture in cases { try await review(fixture) }
            for fixture in cases where ["first_then", "choice_3_columns", "schedule_9_items", "token_5", "long_labels", "text_only_token"].contains(fixture.name) {
                for (tag, width, type) in [("narrow", CGFloat(304), DynamicTypeSize.large), ("wide", CGFloat(820), DynamicTypeSize.large), ("narrow_ax5", CGFloat(304), DynamicTypeSize.accessibility5)] {
                    try await reviewCurrentLayout(fixture, tag: tag, width: width, type: type)
                }
            }
            let invalidTokens = BoardArtifact(id: UUID(), kind: .token, title: "Invalid token count", items: [], tokenCount: 0)
            do {
                _ = try await BoardExporter.export(invalidTokens, format: .image, date: fixedDate)
                check(false, "Invalid token count fails before render")
            } catch { check(true, "Invalid token count fails before render") }
            let missing = BoardArtifact(id: UUID(), kind: .choice, title: "Missing image", items: [
                .init(id: UUID(), label: "Unreadable image", imageID: UUID(), imageData: Data([0, 1, 2]))
            ])
            do {
                _ = try await BoardExporter.export(missing, format: .image, date: fixedDate)
                check(false, "Missing image fails rather than silently exporting")
            } catch BoardExportError.missingImage {
                check(true, "Missing image fails rather than silently exporting")
            }
            try checkpoint(status: "COMPLETE")
            return "Complete: \(records.count) boards; \(checks.count) checks; \(checks.filter { ($0["pass"] as? Bool) != true }.count) reported failures"
        } catch {
            try? checkpoint(status: "ERROR", error: String(describing: error))
            return "Review error: \(error)"
        }
    }

    static func probeRaster(_ fixture: Fixture) async throws {
        let images = try await BoardImageLoader.shared.load(fixture.board)
        var result: [[String: Any]] = []
        for requestedHeight: CGFloat in [8000, 8192, 8300, 10000, 12000] {
            let renderer = ImageRenderer(content: BoardCanvas(board: fixture.board, page: 0, images: images, width: 304).environment(\.dynamicTypeSize, .accessibility5))
            renderer.proposedSize = .init(width: 304, height: nil)
            renderer.isOpaque = true
            var measured = CGSize.zero
            renderer.render { size, _ in measured = size }
            renderer.scale = requestedHeight / measured.height
            var record: [String: Any] = ["requested_height": requestedHeight]
            if let cg = renderer.cgImage {
                record["cg_width"] = cg.width
                record["cg_height"] = cg.height
                let url = output.appendingPathComponent("probe_\(Int(requestedHeight)).png")
                if let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, cg, [:] as CFDictionary)
                    record["PNG_finalize"] = CGImageDestinationFinalize(destination)
                } else { record["PNG_destination"] = false }
            } else { record["cg_image"] = false }
            result.append(record)
        }
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: output.appendingPathComponent("RASTER_PROBE.json"))
    }
}

@main
struct BoardArtifactTestsApp: App {
    @State private var status = "Running board export review"
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 20) {
                Text("Synthetic board review").font(.title)
                Text(status).accessibilityIdentifier("reviewStatus")
            }
            .padding()
            .task { status = await BoardReview.run() }
        }
    }
}
