#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/SessionToolsViews.swift"
text = PATH.read_text(encoding="utf-8")

MARKER = "v0.8.0 ABA visual-support async image decode"

if MARKER not in text:
    state_anchor = '''    @State private var referencePhotoData: Data?
    @State private var photoData: Data?'''
    state_replacement = '''    @State private var referencePhotoData: Data?
    @State private var referenceSourceImage: Image?
    @State private var photoData: Data?'''
    if text.count(state_anchor) != 1:
        raise SystemExit("v0.8.0 visual performance hotfix failed: reference-image state anchor missing")
    text = text.replace(state_anchor, state_replacement, 1)

    button_call_anchor = '''                            referencePhotoData: referencePhotoData,
                            isRegeneration: isGeneratedArtwork,'''
    button_call_replacement = '''                            referencePhotoData: referencePhotoData,
                            sourceImage: referenceSourceImage,
                            isRegeneration: isGeneratedArtwork,'''
    if text.count(button_call_anchor) != 1:
        raise SystemExit("v0.8.0 visual performance hotfix failed: generator call anchor missing")
    text = text.replace(button_call_anchor, button_call_replacement, 1)

    empty_selection_anchor = '''            guard let selectedPhotoItem else {
                referencePhotoData = nil
                photoData = nil
                isGeneratedArtwork = false
                photoPreviewID = UUID()
                return
            }'''
    empty_selection_replacement = '''            guard let selectedPhotoItem else {
                referencePhotoData = nil
                referenceSourceImage = nil
                photoData = nil
                isGeneratedArtwork = false
                photoPreviewID = UUID()
                return
            }'''
    if text.count(empty_selection_anchor) != 1:
        raise SystemExit("v0.8.0 visual performance hotfix failed: empty-selection reset anchor missing")
    text = text.replace(empty_selection_anchor, empty_selection_replacement, 1)

    save_reset_anchor = '''            selectedPhotoItem = nil
            referencePhotoData = nil
            photoData = nil
            isGeneratedArtwork = false'''
    save_reset_replacement = '''            selectedPhotoItem = nil
            referencePhotoData = nil
            referenceSourceImage = nil
            photoData = nil
            isGeneratedArtwork = false'''
    if text.count(save_reset_anchor) != 1:
        raise SystemExit("v0.8.0 visual performance hotfix failed: post-save reset anchor missing")
    text = text.replace(save_reset_anchor, save_reset_replacement, 1)

    loaded_anchor = '''            referencePhotoData = loadedData
            photoData = loadedData
            isGeneratedArtwork = false
            photoPreviewID = UUID()
            message = "Reference photo ready. Save it directly or generate an illustrated icon."'''
    loaded_replacement = '''            // v0.8.0 ABA visual-support async image decode:
            // Decode the Image Playground source through the existing actor-owned thumbnail path,
            // never synchronously from a SwiftUI body or computed view property.
            let requestID = UUID()
            let decodedReference = await ClientVisualThumbnailCache.shared.thumbnail(
                for: ClientVisualThumbnailRequest(
                    assetID: requestID,
                    maximumPixelDimension: 1_024
                ),
                imageData: loadedData
            )
            guard !Task.isCancelled,
                  selectedPhotoItem == self.selectedPhotoItem else { return }
            referencePhotoData = loadedData
            referenceSourceImage = decodedReference.map { Image(uiImage: $0) }
            photoData = loadedData
            isGeneratedArtwork = false
            photoPreviewID = requestID
            message = "Reference photo ready. Save it directly or generate an illustrated icon."'''
    if text.count(loaded_anchor) != 1:
        raise SystemExit("v0.8.0 visual performance hotfix failed: loaded-photo anchor missing")
    text = text.replace(loaded_anchor, loaded_replacement, 1)

    property_anchor = '''    let referencePhotoData: Data?
    let isRegeneration: Bool'''
    property_replacement = '''    let referencePhotoData: Data?
    let sourceImage: Image?
    let isRegeneration: Bool'''
    if text.count(property_anchor) != 1:
        raise SystemExit("v0.8.0 visual performance hotfix failed: generator property anchor missing")
    text = text.replace(property_anchor, property_replacement, 1)

    source_property_pattern = r'''\n    private var sourceImage: Image\? \{\n        guard let referencePhotoData, let image = UIImage\(data: referencePhotoData\) else \{ return nil \}\n        return Image\(uiImage: image\)\n    \}\n'''
    text, source_property_count = re.subn(source_property_pattern, "\n", text, count=1)
    if source_property_count != 1:
        raise SystemExit("v0.8.0 visual performance hotfix failed: synchronous source-image property missing")

    processor_pattern = r'''private enum ABAVisualSupportImageProcessor \{.*?\n\}\n\n#if canImport\(ImagePlayground\)'''
    processor_replacement = r'''private enum ABAVisualSupportImageProcessor {
    static func normalizedSquarePNG(from url: URL) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
            guard let source = CGImageSourceCreateWithURL(
                url as CFURL,
                sourceOptions as CFDictionary
            ) else { return nil }

            let imageOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2_048,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                imageOptions as CFDictionary
            ) else { return nil }

            let image = UIImage(cgImage: cgImage)
            let canvasSize = CGSize(width: 1_024, height: 1_024)
            let canvasRect = CGRect(origin: .zero, size: canvasSize)
            let contentRect = canvasRect.insetBy(dx: 36, dy: 36)
            let scale = min(contentRect.width / image.size.width, contentRect.height / image.size.height)
            let fittedSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let drawRect = CGRect(
                x: contentRect.midX - fittedSize.width / 2,
                y: contentRect.midY - fittedSize.height / 2,
                width: fittedSize.width,
                height: fittedSize.height
            )

            let format = UIGraphicsImageRendererFormat()
            format.opaque = true
            format.scale = 1
            let rendered = UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
                context.cgContext.setFillColor(UIColor.white.cgColor)
                context.cgContext.fill(canvasRect)
                image.draw(in: drawRect)
            }
            return rendered.pngData()
        }.value
    }
}

#if canImport(ImagePlayground)'''
    text, processor_count = re.subn(
        processor_pattern,
        lambda _: processor_replacement,
        text,
        count=1,
        flags=re.S,
    )
    if processor_count != 1:
        raise SystemExit("v0.8.0 visual performance hotfix failed: image processor anchor missing")

    if "UIImage(data:" in text:
        raise SystemExit("v0.8.0 visual performance hotfix failed: synchronous UIImage(data:) decode remains")

    PATH.write_text(text, encoding="utf-8")

print(
    "LifeRoute v0.8.0 ABA visual generator performance hotfix applied: reference-photo decoding uses the existing "
    "actor-owned thumbnail pipeline, approved-result decoding uses ImageIO off the render path, and no synchronous "
    "UIImage(data:) decode remains in SwiftUI views."
)
