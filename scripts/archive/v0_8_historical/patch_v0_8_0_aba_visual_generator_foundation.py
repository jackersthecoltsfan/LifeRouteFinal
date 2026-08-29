#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/SessionToolsViews.swift"
text = PATH.read_text(encoding="utf-8")

MARKER = "v0.8.0 ABA visual-support generator foundation"

if MARKER not in text:
    import_anchor = "import ImageIO\n"
    guarded_import = """import ImageIO

#if canImport(ImagePlayground)
import ImagePlayground
#endif
"""
    if text.count(import_anchor) != 1:
        raise SystemExit("v0.8.0 ABA visual generator patch failed: ImageIO import anchor missing")
    text = text.replace(import_anchor, guarded_import, 1)

    text = text.replace(
        'VisualWorkspaceCard(title: "Icon Library", subtitle: "Photos or text visuals", systemImage: "photo.on.rectangle.angled")',
        'VisualWorkspaceCard(title: "Icon Library", subtitle: "Photos, text, or illustrated icons", systemImage: "photo.on.rectangle.angled")',
        1,
    )

    pattern = r"struct ClientVisualIconLibraryView: View \{.*?\n\}\n\nstruct ClientChoiceBoardBuilderView: View \{"
    replacement = r'''struct ClientVisualIconLibraryView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientCode: String
    @State private var label = ""
    @State private var visualDescription = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var referencePhotoData: Data?
    @State private var photoData: Data?
    @State private var photoPreviewID = UUID()
    @State private var isGeneratedArtwork = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                VisualBuilderHero(
                    title: "Icon Library",
                    subtitle: "Create exact-label photo, text, or illustrated ABA visuals for \(libraryName).",
                    clientCode: libraryName,
                    systemImage: "photo.on.rectangle.angled"
                )

                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Text("Create visual")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text(draftBadge)
                            .font(.caption2.weight(.black))
                            .tracking(0.8)
                            .foregroundStyle(photoData == nil ? palette.textSecondary : palette.accentSecondary)
                    }

                    TextField("Exact icon label", text: $label)
                        .textInputAutocapitalization(.words)
                        .padding(12)
                        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    TextField("Optional visual description", text: $visualDescription, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text("Describe only what helps identify the real item, place, activity, or concept. The exact label stays editable and is rendered by LifeRoute beneath the artwork.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 11) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(palette.accent.opacity(0.14))
                                Image(systemName: referencePhotoData == nil ? "photo.badge.plus" : "photo.fill")
                                    .foregroundStyle(palette.accent)
                            }
                            .frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(referencePhotoData == nil ? "Choose reference photo" : "Change reference photo")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(palette.textPrimary)
                                Text("Optional · use the child’s actual item or environment")
                                    .font(.caption2)
                                    .foregroundStyle(palette.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.textSecondary)
                        }
                        .padding(12)
                        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if let photoData {
                        VStack(spacing: 10) {
                            ClientVisualDraftPhotoPreview(
                                imageData: photoData,
                                requestID: photoPreviewID,
                                maximumHeight: 230
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Text(displayLabel)
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(Color.black)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(12)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(palette.accent.opacity(0.28), lineWidth: 1)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Visual support preview: \(displayLabel)")
                    }

                    #if canImport(ImagePlayground)
                    if #available(iOS 26.0, *) {
                        ABAVisualSupportImageGeneratorButton(
                            label: label,
                            visualDescription: visualDescription,
                            referencePhotoData: referencePhotoData,
                            isRegeneration: isGeneratedArtwork,
                            onImageReady: receiveGeneratedImage
                        )
                    } else {
                        generatorUnavailableCopy
                    }
                    #else
                    generatorUnavailableCopy
                    #endif

                    if isGeneratedArtwork, let referencePhotoData {
                        Button {
                            photoData = referencePhotoData
                            photoPreviewID = UUID()
                            isGeneratedArtwork = false
                            message = "Original reference photo restored."
                        } label: {
                            Label("Use original photo instead", systemImage: "photo")
                        }
                        .buttonStyle(LifeRouteSecondaryButtonStyle())
                    }

                    Button("Save icon to \(libraryName)") { saveIcon() }
                        .buttonStyle(LifeRoutePrimaryButtonStyle())

                    if let message {
                        Label(message, systemImage: isGeneratedArtwork ? "sparkles" : "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }

                    Text("Saving a photo directly keeps it in LifeRoute’s protected local data. When you choose Generate, Apple’s system Image Playground handles the prompt and optional reference under Apple Intelligence privacy protections; LifeRoute stores only the image you approve. Batch generation and printable PDF sheets remain later checkpoints.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text("\(libraryName) icon library")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text("\(visualState.icons(for: clientCode).count)")
                            .font(.caption.weight(.black))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(palette.accent.opacity(0.12), in: Capsule())
                    }

                    let icons = visualState.icons(for: clientCode)
                    if icons.isEmpty {
                        VisualBuilderEmptyState(
                            title: "No icons yet",
                            subtitle: "Create the first reusable visual for \(libraryName).",
                            systemImage: "photo.on.rectangle.angled"
                        )
                    } else {
                        ForEach(icons) { icon in
                            HStack(spacing: 12) {
                                ClientVisualIconThumbnail(icon: icon, size: 64)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(icon.label)
                                        .font(.headline)
                                        .foregroundStyle(palette.textPrimary)
                                    Label(icon.imageData == nil ? "Text visual" : "Image visual", systemImage: icon.imageData == nil ? "textformat" : "photo.fill")
                                        .font(.caption)
                                        .foregroundStyle(palette.textSecondary)
                                }
                                Spacer()
                                Button(role: .destructive) { visualState.removeIcon(id: icon.id) } label: {
                                    Image(systemName: "trash")
                                        .font(.caption.weight(.bold))
                                }
                                .accessibilityLabel("Delete \(icon.label)")
                            }
                            .padding(12)
                            .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
                .lifeRouteCard()
            }
            .padding(18)
            .padding(.bottom, 24)
        }
        .navigationTitle("\(libraryName) Icons")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedPhotoItem) {
            guard let selectedPhotoItem else {
                referencePhotoData = nil
                photoData = nil
                isGeneratedArtwork = false
                photoPreviewID = UUID()
                return
            }
            let loadedData = try? await selectedPhotoItem.loadTransferable(type: Data.self)
            guard !Task.isCancelled,
                  selectedPhotoItem == self.selectedPhotoItem else { return }
            guard let loadedData else {
                message = "LifeRoute could not load that photo."
                return
            }
            referencePhotoData = loadedData
            photoData = loadedData
            isGeneratedArtwork = false
            photoPreviewID = UUID()
            message = "Reference photo ready. Save it directly or generate an illustrated icon."
        }
    }

    private var libraryName: String {
        clientCode == ClientVisualSupportCore.generalClientCode ? "General" : clientCode
    }

    private var displayLabel: String {
        let clean = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "EXACT LABEL" : clean
    }

    private var draftBadge: String {
        if isGeneratedArtwork { return "ILLUSTRATED" }
        if photoData != nil { return "PHOTO READY" }
        return "TEXT OR IMAGE"
    }

    private var generatorUnavailableCopy: some View {
        Label(
            "Illustrated generation requires a supported iOS 26 Apple Intelligence device. Photo and text-only visual saving remain available.",
            systemImage: "info.circle.fill"
        )
        .font(.caption)
        .foregroundStyle(palette.textSecondary)
    }

    private func receiveGeneratedImage(_ data: Data?) {
        guard let data else {
            message = "LifeRoute could not import that generated image. Try generating again."
            return
        }
        photoData = data
        photoPreviewID = UUID()
        isGeneratedArtwork = true
        message = "Illustrated ABA visual ready. Review the artwork and exact label before saving."
        LifeRouteHaptics.success()
    }

    private func saveIcon() {
        do {
            _ = try visualState.addIcon(clientCode: clientCode, label: label, imageData: photoData)
            label = ""
            visualDescription = ""
            selectedPhotoItem = nil
            referencePhotoData = nil
            photoData = nil
            isGeneratedArtwork = false
            message = "Icon saved to \(libraryName)’s visual library on this iPhone."
        } catch { message = error.localizedDescription }
    }
}

// v0.8.0 ABA visual-support generator foundation:
// The system model creates artwork; LifeRoute owns the exact label, library, and protected persistence.
private enum ABAVisualSupportPrompt {
    static func make(label: String, visualDescription: String, hasReference: Bool) -> String {
        let cleanLabel = String(label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        let cleanDescription = String(visualDescription.trimmingCharacters(in: .whitespacesAndNewlines).prefix(700))
        let subject = cleanDescription.isEmpty ? cleanLabel : "\(cleanLabel). \(cleanDescription)"
        let referenceRule = hasReference
            ? "Use the supplied reference image as the basis. Preserve the specific identifying physical characteristics of the real item or environment that help a child recognize and generalize it."
            : "Create the requested object, location, activity, or concept from the supplied description without adding unrelated details."

        return """
        Create one ABA visual-support icon for the exact user label “\(cleanLabel)”.
        Subject or concept: \(subject)
        \(referenceRule)

        Create a realistically illustrated cartoon that remains clearly recognizable as the real object, location, activity, or concept. Use clean bold outlines, soft natural shading, bright but natural colors, strong visual contrast, and a simple child-friendly presentation. Use a clean white background. Center one primary subject and let it occupy most of a square 1:1 composition. Remove distracting or irrelevant background information. Preserve identifying characteristics needed for recognition. Do not introduce unrelated objects or scenery. Do not include people unless a person is necessary to communicate the concept.

        Treat the result as part of one coordinated professionally designed ABA visual-support library. Keep the illustration style, line weight, shading, proportions, background treatment, and icon scale consistent. Prioritize immediate functional recognition and visual clarity over decorative detail for use in visual schedules, choice boards, First/Then boards, communication books, transition supports, and activity schedules.

        Do not render letters, words, captions, labels, logos, borders, or watermarks inside the artwork. LifeRoute renders the exact user label beneath the artwork separately so spelling and typography remain correct.
        """
    }
}

private enum ABAVisualSupportImageProcessor {
    static func normalizedSquarePNG(from url: URL) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            guard let originalData = try? Data(contentsOf: url),
                  let image = UIImage(data: originalData),
                  image.size.width > 0,
                  image.size.height > 0 else { return nil }

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

#if canImport(ImagePlayground)
@available(iOS 26.0, *)
private struct ABAVisualSupportImageGeneratorButton: View {
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.supportsImageGeneration) private var supportsImageGeneration
    @State private var showingPlayground = false

    let label: String
    let visualDescription: String
    let referencePhotoData: Data?
    let isRegeneration: Bool
    let onImageReady: (Data?) -> Void

    private var cleanLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sourceImage: Image? {
        guard let referencePhotoData, let image = UIImage(data: referencePhotoData) else { return nil }
        return Image(uiImage: image)
    }

    private var concepts: [ImagePlaygroundConcept] {
        [
            .extracted(
                from: ABAVisualSupportPrompt.make(
                    label: cleanLabel,
                    visualDescription: visualDescription,
                    hasReference: referencePhotoData != nil
                ),
                title: "ABA visual-support icon"
            )
        ]
    }

    private var options: ImagePlaygroundOptions {
        var options = ImagePlaygroundOptions()
        options.sizeSpecification = .closest(to: CGSize(width: 1_024, height: 1_024))
        options.personalization = .disabled
        return options
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                showingPlayground = true
            } label: {
                Label(
                    isRegeneration ? "Regenerate illustrated icon" : "Generate illustrated icon",
                    systemImage: "apple.intelligence"
                )
            }
            .buttonStyle(LifeRouteSecondaryButtonStyle())
            .disabled(cleanLabel.isEmpty || !supportsImageGeneration)
            .imagePlaygroundSheet(
                isPresented: $showingPlayground,
                concepts: concepts,
                sourceImage: sourceImage,
                onCompletion: { url in
                    Task {
                        let data = await ABAVisualSupportImageProcessor.normalizedSquarePNG(from: url)
                        onImageReady(data)
                    }
                },
                onCancellation: {}
            )
            .imagePlaygroundOptions(options)
            .imagePlaygroundGenerationStyle(.illustration, in: [.illustration])

            Text(
                supportsImageGeneration
                    ? "Apple’s Image Playground opens for review. Illustration style, square output, disabled person personalization, and the Master ABA visual prompt are preconfigured."
                    : "Image generation is unavailable in the current device, language, region, or Apple Intelligence settings."
            )
            .font(.caption)
            .foregroundStyle(palette.textSecondary)
        }
    }
}
#endif

struct ClientChoiceBoardBuilderView: View {'''

    text, count = re.subn(pattern, lambda _: replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit("v0.8.0 ABA visual generator patch failed: icon-library view anchor missing")

    PATH.write_text(text, encoding="utf-8")

print(
    "LifeRoute v0.8.0 ABA visual-support generator foundation applied: canonical photo/text-to-illustrated-icon workflow, "
    "exact native labels, Image Playground review, square white normalization, protected-library reuse, and unsupported-device fallback."
)
