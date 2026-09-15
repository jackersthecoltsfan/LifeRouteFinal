import SwiftUI
import UIKit
import ImageIO
import Photos
import UniformTypeIdentifiers

/// A derived, immutable board. Source imagery and library ownership stay in
/// ClientVisualSupportCore; this value never writes to the image library.
struct BoardArtifact: Identifiable, Sendable {
    enum Kind: String, Sendable {
        case firstThen = "FirstThen"
        case choice = "ChoiceBoard"
        case schedule = "VisualSchedule"
        case token = "TokenBoard"

        var title: String {
            switch self {
            case .firstThen: return "First / Then"
            case .choice: return "Choice Board"
            case .schedule: return "Visual Schedule"
            case .token: return "Token Board"
            }
        }
    }

    struct Item: Identifiable, Sendable {
        let id: UUID
        var label: String
        var imageID: UUID?
        var imageData: Data?
    }

    let id: UUID
    var kind: Kind
    var title: String
    var items: [Item]
    var columns: Int = 2
    var tokenCount: Int = 5

    /// Long schedules become ordered, printable pages. The very same page
    /// boundaries appear in preview, PNG files, and the PDF.
    var pages: [[Item]] {
        guard kind == .schedule else { return [items] }
        return stride(from: 0, to: items.count, by: 4).map {
            Array(items[$0..<min($0 + 4, items.count)])
        }
    }
}

/// One layout vocabulary across interactive preview and both export formats.
/// Labels are outside the square image cells; image content always aspect-fits.
struct BoardCanvas: View {
    let board: BoardArtifact
    let page: Int
    let images: [UUID: UIImage]
    let width: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var items: [BoardArtifact.Item] { board.pages[page] }
    private var inset: CGFloat { 12 }
    private var gap: CGFloat { 8 }
    private var contentWidth: CGFloat { max(1, width - inset * 2) }
    private var columns: Int {
        if dynamicTypeSize.isAccessibilitySize { return 1 }
        return min(max(1, items.count), board.kind == .firstThen ? 2 : (board.columns == 3 ? 3 : 2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(board.title)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if board.kind == .schedule {
                VStack(spacing: gap) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        scheduleRow(item, number: page * 4 + index + 1)
                    }
                }
            } else if board.kind == .token {
                tokenContent
            } else {
                let side = (contentWidth - gap * CGFloat(columns - 1)) / CGFloat(columns)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<((items.count + columns - 1) / columns), id: \.self) { row in
                        HStack(alignment: .top, spacing: gap) {
                            ForEach(0..<columns, id: \.self) { column in
                                let index = row * columns + column
                                if index < items.count {
                                    tile(items[index], side: side, heading: board.kind == .firstThen ? (index == 0 ? "FIRST" : "THEN") : nil)
                                } else {
                                    Color.clear.frame(width: side, height: 1)
                                }
                            }
                        }
                    }
                }
            }

            if board.pages.count > 1 {
                Text("\(page + 1) / \(board.pages.count)")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel("Page \(page + 1) of \(board.pages.count)")
            }
        }
        .padding(inset)
        .frame(width: width, alignment: .topLeading)
        .foregroundStyle(.black)
        .background(.white)
        .environment(\.colorScheme, .light)
    }

    private func tile(_ item: BoardArtifact.Item, side: CGFloat, heading: String? = nil) -> some View {
        VStack(spacing: 6) {
            if let heading {
                Text(heading).font(.headline.weight(.bold))
            }
            if item.imageID == nil {
                Text(item.label).font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8).frame(width: side).frame(minHeight: side)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.black, lineWidth: 0.75))
            } else {
                imageCell(item, side: side)
                Text(item.label)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: side)
        .accessibilityElement(children: .combine)
    }

    private func scheduleRow(_ item: BoardArtifact.Item, number: Int) -> some View {
        let side = dynamicTypeSize.isAccessibilitySize ? contentWidth : min(240, contentWidth * 0.46)
        return (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .center, spacing: 12))) {
            if item.imageID != nil { imageCell(item, side: side) }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(number)").font(.subheadline.weight(.bold))
                Text(item.label).font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var tokenContent: some View {
        VStack(spacing: 16) {
            if let reward = items.first {
                (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))) {
                    if reward.imageID != nil {
                        imageCell(reward, side: dynamicTypeSize.isAccessibilitySize ? contentWidth : contentWidth * 0.48)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WORKING TOWARD").font(.subheadline.weight(.bold))
                        Text(reward.label).font(.title2.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            let count = board.tokenCount
            let across = count <= 5 ? count : (count + 1) / 2
            let side = (contentWidth - gap * CGFloat(across - 1)) / CGFloat(across)
            VStack(alignment: .leading, spacing: gap) {
                ForEach(0..<((count + across - 1) / across), id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<across, id: \.self) { column in
                            let index = row * across + column
                            if index < count {
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(.black, lineWidth: 0.75)
                                    .frame(width: side, height: side)
                                    .accessibilityLabel("Empty token slot \(index + 1) of \(count)")
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func imageCell(_ item: BoardArtifact.Item, side: CGFloat) -> some View {
        ZStack {
            Color.white
            if let id = item.imageID, let image = images[id] {
                Image(uiImage: image).resizable().scaledToFit().padding(2)
            } else if item.imageID != nil {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title).foregroundStyle(.gray)
            } else {
                Text(item.label).font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center).padding(8)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.black, lineWidth: 0.75))
        .accessibilityHidden(true)
    }
}

/// ImageIO decoding happens away from the main actor. Immutable saved images
/// are cached by UUID and requested resolution, with an explicit memory bound.
actor BoardImageLoader {
    static let shared = BoardImageLoader()
    private let cache = NSCache<NSString, UIImage>()

    init() { cache.totalCostLimit = 48 * 1_024 * 1_024; cache.countLimit = 40 }

    func load(_ board: BoardArtifact, page: Int = 0, pixels: Int = 1200) throws -> [UUID: UIImage] {
        var images: [UUID: UIImage] = [:]
        guard board.pages.indices.contains(page) else { throw BoardExportError.renderFailed }
        for item in board.pages[page] {
            try Task.checkCancellation()
            guard let id = item.imageID else { continue }
            if images[id] != nil { continue }
            let key = "\(id)-\(pixels)" as NSString
            if let cached = cache.object(forKey: key) { images[id] = cached; continue }
            guard let data = item.imageData,
                  let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: pixels,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else { throw BoardExportError.missingImage }
            let image = UIImage(cgImage: cg)
            cache.setObject(image, forKey: key, cost: cg.bytesPerRow * cg.height)
            images[id] = image
        }
        return images
    }
}

enum BoardExportError: LocalizedError {
    case missingImage, renderFailed, tooLarge, photosDenied
    var errorDescription: String? {
        switch self {
        case .missingImage: return "A saved image could not be opened. Check the board’s images in Image Library before exporting."
        case .renderFailed: return "The board could not be exported. Please try again."
        case .tooLarge: return "This page is too large to export. Shorten its labels or divide the schedule into smaller boards."
        case .photosDenied: return "Allow LifeRoute to add photos in Settings, or use Share Image to save the board elsewhere."
        }
    }
}

@MainActor
enum BoardExporter {
    enum Format { case image, pdf }

    struct Layout {
        var width: CGFloat = 612
        var textSize: DynamicTypeSize = .large
    }

    static func export(_ board: BoardArtifact, format: Format, date: Date = Date(), layout: Layout = Layout()) async throws -> [URL] {
        guard layout.width > 0, board.kind != .token || (3...10).contains(board.tokenCount) else { throw BoardExportError.renderFailed }
        guard !board.pages.isEmpty else { throw BoardExportError.renderFailed }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LifeRouteBoardExports", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: directory) } }
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: directory.path)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        let stem = "LifeRoute_\(board.kind.rawValue)_\(formatter.string(from: date))"
        var urls: [URL] = []
        let pdfURL = directory.appendingPathComponent(stem + "_001.pdf")
        let pdf = format == .pdf ? CGContext(pdfURL as CFURL, mediaBox: nil,
            [kCGPDFContextCreator: "LifeRoute", kCGPDFContextTitle: board.kind.title] as CFDictionary) : nil
        if format == .pdf, pdf == nil { throw BoardExportError.renderFailed }
        defer { pdf?.closePDF() }

        for page in board.pages.indices {
            try Task.checkCancellation()
            await Task.yield()
            // Only this page retains decoded images. A long schedule never
            // accumulates every full-resolution image before rendering begins.
            let images = try await BoardImageLoader.shared.load(board, page: page)
            let canvas = BoardCanvas(board: board, page: page, images: images, width: layout.width)
                .environment(\.dynamicTypeSize, layout.textSize)
            let renderer = ImageRenderer(content: canvas)
            renderer.proposedSize = ProposedViewSize(width: layout.width, height: nil)
            renderer.isOpaque = true
            var measuredSize = CGSize.zero
            renderer.render { size, _ in measuredSize = size }
            guard measuredSize.width > 0, measuredSize.height > 0,
                  measuredSize.height <= 4000 else { throw BoardExportError.tooLarge }
            // Bound allocation before requesting pixels, preserving layout at
            // large text sizes instead of cropping or allocating a giant image.
            let scale = min(max(3, 1836 / layout.width),
                            8000 / measuredSize.height,
                            sqrt(20_000_000 / (measuredSize.width * measuredSize.height)))
            guard measuredSize.width * scale >= 600 else { throw BoardExportError.tooLarge }
            renderer.scale = scale
            if let pdf {
                var rendered = false
                renderer.render { size, draw in
                    guard size.width > 0, size.height > 0, size.height <= 4000 else { return }
                    // Preserve the exact preview layout, scaled uniformly to
                    // printable width; never reflow labels only for export.
                    let printScale = 612 / size.width
                    var box = CGRect(x: 0, y: 0, width: 612, height: size.height * printScale)
                    let boxData = Data(bytes: &box, count: MemoryLayout<CGRect>.size)
                    pdf.beginPDFPage([kCGPDFContextMediaBox: boxData] as CFDictionary)
                    pdf.saveGState()
                    pdf.scaleBy(x: printScale, y: printScale)
                    draw(pdf)
                    pdf.restoreGState()
                    pdf.endPDFPage()
                    rendered = true
                }
                guard rendered else { throw BoardExportError.tooLarge }
            } else {
                guard let image = renderer.cgImage else { throw BoardExportError.renderFailed }
                let url = directory.appendingPathComponent(stem + String(format: "_%03d.png", page + 1))
                // Newly encoded board pixels carry no source EXIF, GPS, or names.
                guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw BoardExportError.renderFailed }
                CGImageDestinationAddImage(destination, image, [:] as CFDictionary)
                guard CGImageDestinationFinalize(destination) else { throw BoardExportError.renderFailed }
                urls.append(url)
            }
        }
        completed = true
        return format == .pdf ? [pdfURL] : urls
    }

    static func saveToPhotos(_ urls: [URL]) async throws {
        let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard authorization == .authorized || authorization == .limited else { throw BoardExportError.photosDenied }
        try await PHPhotoLibrary.shared().performChanges {
            for url in urls {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: url, options: nil)
            }
        }
    }
}

struct BoardShareSheet: UIViewControllerRepresentable {
    let urls: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct BoardArtifactPreview: View {
    let board: BoardArtifact
    @Environment(\.dismiss) private var dismiss
    @State private var images: [UUID: UIImage] = [:]
    @State private var loading = true
    @State private var busy = false
    @State private var message: String?
    @State private var exportURLs: [URL] = []
    @State private var sharing = false
    @State private var canvasWidth: CGFloat = 612
    @State private var page = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private struct ImageRequest: Hashable {
        let boardID: UUID
        let page: Int
        let imageIDs: [UUID]
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    if board.pages.count > 1 {
                        HStack {
                            Button { page -= 1 } label: { Label("Previous", systemImage: "chevron.left").frame(minHeight: 44) }
                                .disabled(page == 0 || busy)
                            Spacer()
                            Text("Page \(page + 1) of \(board.pages.count)").font(.subheadline)
                            Spacer()
                            Button { page += 1 } label: { Label("Next", systemImage: "chevron.right").frame(minHeight: 44) }
                                .disabled(page + 1 >= board.pages.count || busy)
                        }
                        .font(.subheadline).frame(minHeight: 44)
                        .foregroundStyle(Color.primary)
                    }
                    if loading { ProgressView("Opening images").padding() }
                    if board.pages.indices.contains(page) {
                        BoardCanvas(board: board, page: page, images: images, width: max(1, geometry.size.width - 16))
                    }
                }.padding(8)
            }
            .background(Color(uiColor: .systemGray5))
            .onAppear { canvasWidth = max(1, geometry.size.width - 16) }
            .onChange(of: geometry.size.width) { canvasWidth = max(1, $0 - 16) }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Button { dismiss() } label: {
                    Label("Close", systemImage: "xmark").labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                    .accessibilityLabel("Close board preview").disabled(busy)
                Text(board.kind.title).font(.headline)
                Spacer()
                if busy { ProgressView().accessibilityLabel("Preparing export") }
                Menu {
                    Button { export(.image) } label: { Label("Share Image", systemImage: "photo") }
                    Button { export(.image, photos: true) } label: { Label("Save Image to Photos", systemImage: "photo.badge.arrow.down") }
                    Button { export(.pdf) } label: { Label("Share PDF / Save to Files", systemImage: "doc") }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up").frame(minHeight: 44)
                }
                .disabled(loading || busy)
            }
            .padding(.horizontal, 12)
            .background(.regularMaterial)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .interactiveDismissDisabled(busy)
        .task(id: ImageRequest(boardID: board.id, page: page, imageIDs: board.items.compactMap(\.imageID))) {
            loading = true
            images = [:]
            do {
                let loaded = try await BoardImageLoader.shared.load(board, page: page)
                guard !Task.isCancelled else { return }
                images = loaded
            } catch {
                guard !Task.isCancelled else { return }
                message = error.localizedDescription
            }
            loading = false
        }
        .sheet(isPresented: $sharing, onDismiss: clearExportFiles) { BoardShareSheet(urls: exportURLs) }
        .alert("Board export", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private func export(_ format: BoardExporter.Format, photos: Bool = false) {
        guard !busy else { return }
        busy = true
        let layout = BoardExporter.Layout(width: canvasWidth, textSize: dynamicTypeSize)
        Task { @MainActor in
            defer { busy = false }
            do {
                let urls = try await BoardExporter.export(board, format: format, layout: layout)
                exportURLs = urls
                if photos {
                    defer { clearExportFiles() }
                    try await BoardExporter.saveToPhotos(urls)
                    message = urls.count == 1 ? "Board saved to Photos." : "\(urls.count) board pages saved to Photos."
                } else {
                    sharing = true
                }
            } catch { message = error.localizedDescription }
        }
    }

    private func clearExportFiles() {
        // These are only this preview's derived temporary exports. Originals
        // and anything the user saved through Photos/Files are separate copies.
        for directory in Set(exportURLs.map { $0.deletingLastPathComponent() }) {
            try? FileManager.default.removeItem(at: directory)
        }
        exportURLs = []
    }
}
