import re
from pathlib import Path


DASHBOARD_PATH = Path("LifeRoute/V054ToolsDashboard.swift")
VISUALS_PATH = Path("LifeRoute/SessionToolsViews.swift")
MARKER = "v0.8.0 follow-up visible ABA visual generator"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"v0.8.0 visual-generator follow-up failed: expected one {label}, found {count}"
        )
    return text.replace(old, new, 1)


dashboard = DASHBOARD_PATH.read_text(encoding="utf-8")
visuals = VISUALS_PATH.read_text(encoding="utf-8")

if MARKER in dashboard and MARKER in visuals:
    print("LifeRoute v0.8.0 visual-generator follow-up is already materialized.")
    raise SystemExit(0)
if MARKER in dashboard or MARKER in visuals:
    raise SystemExit("v0.8.0 visual-generator follow-up is only partially materialized")


new_icon_card = r'''    // v0.8.0 follow-up visible ABA visual generator:
    // Route the primary Visual Supports experience to the real photo/text illustrated workflow.
    private var iconAICard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Illustrated Icon Generator")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                    Text("Turn a text description or reference photo into a consistent ABA visual-support icon.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.title2)
                    .foregroundStyle(palette.accent)
            }

            HStack(spacing: 8) {
                visualGeneratorModeBadge("TEXT ONLY", systemImage: "textformat")
                visualGeneratorModeBadge("PHOTO", systemImage: "photo.fill")
                visualGeneratorModeBadge("REGENERATE", systemImage: "arrow.clockwise")
            }

            HStack(spacing: 10) {
                VStack(spacing: 7) {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(palette.textSecondary)
                    Text("REFERENCE")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 94)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Image(systemName: "arrow.right")
                    .font(.headline.weight(.black))
                    .foregroundStyle(palette.accent)
                    .accessibilityHidden(true)

                VStack(spacing: 7) {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.title2)
                        .foregroundStyle(palette.accent)
                    Text("ILLUSTRATED ICON")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(palette.accentSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 94)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Reference photo or text becomes an illustrated ABA visual-support icon")

            NavigationLink {
                ClientVisualIconLibraryView(
                    visualState: visualState,
                    clientCode: selectedClientCode
                )
            } label: {
                HStack {
                    Label("Open Illustrated Icon Generator", systemImage: "apple.intelligence")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.black))
                }
                .foregroundStyle(Color.black.opacity(0.82))
                .padding(.horizontal, 13)
                .frame(minHeight: 48)
                .background(palette.accent, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })

            Text("The generator opens directly in \(libraryDisplayName)’s existing visual library. LifeRoute keeps the exact label separate from the artwork, shows the reference and generated result clearly, and saves only after your review.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .lifeRouteCard()
    }

    private func visualGeneratorModeBadge(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.black))
            .foregroundStyle(palette.accentSecondary)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(palette.panelElevated.opacity(0.34), in: Capsule())
            .accessibilityLabel(title.capitalized)
    }

'''
dashboard, card_count = re.subn(
    r"    private var iconAICard: some View \{.*?\n    private var manualWorkspaceCard: some View \{",
    new_icon_card + "    private var manualWorkspaceCard: some View {",
    dashboard,
    count=1,
    flags=re.DOTALL,
)
if card_count != 1:
    raise SystemExit("v0.8.0 visual-generator follow-up failed: primary icon card anchor missing")


visuals = replace_once(
    visuals,
    "struct ClientVisualIconLibraryView: View {",
    "// v0.8.0 follow-up visible ABA visual generator: reference/result clarity and progress.\n"
    "struct ClientVisualIconLibraryView: View {",
    "generator-screen marker",
)

visuals = replace_once(
    visuals,
    '''    @State private var photoPreviewID = UUID()
    @State private var isGeneratedArtwork = false''',
    '''    @State private var photoPreviewID = UUID()
    @State private var referencePreviewID = UUID()
    @State private var isGeneratedArtwork = false''',
    "reference preview identity state",
)

preview_anchor = r'''                    if let photoData {
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
'''
preview_replacement = r'''                    if let photoData {
                        if isGeneratedArtwork, let referencePhotoData {
                            VStack(alignment: .leading, spacing: 9) {
                                Text("Reference → generated visual")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(palette.textPrimary)

                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .top, spacing: 9) {
                                        visualComparisonPreview(
                                            title: "REFERENCE PHOTO",
                                            imageData: referencePhotoData,
                                            requestID: referencePreviewID
                                        )
                                        visualComparisonPreview(
                                            title: "GENERATED ICON",
                                            imageData: photoData,
                                            requestID: photoPreviewID
                                        )
                                    }
                                    VStack(spacing: 9) {
                                        visualComparisonPreview(
                                            title: "REFERENCE PHOTO",
                                            imageData: referencePhotoData,
                                            requestID: referencePreviewID
                                        )
                                        visualComparisonPreview(
                                            title: "GENERATED ICON",
                                            imageData: photoData,
                                            requestID: photoPreviewID
                                        )
                                    }
                                }

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
                                    .stroke(palette.accent.opacity(0.32), lineWidth: 1)
                            }
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("Reference photo and generated visual support comparison for \(displayLabel)")
                        } else {
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
                    }
'''
visuals = replace_once(visuals, preview_anchor, preview_replacement, "reference/result comparison")

helper_anchor = '''    private var generatorUnavailableCopy: some View {
        Label('''
helper_replacement = r'''    private func visualComparisonPreview(
        title: String,
        imageData: Data,
        requestID: UUID
    ) -> some View {
        VStack(spacing: 7) {
            Text(title)
                .font(.caption2.weight(.black))
                .tracking(0.6)
                .foregroundStyle(Color.black.opacity(0.70))
            ClientVisualDraftPhotoPreview(
                imageData: imageData,
                requestID: requestID,
                maximumHeight: 170
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    private var generatorUnavailableCopy: some View {
        Label('''
visuals = replace_once(visuals, helper_anchor, helper_replacement, "comparison preview helper")

visuals = replace_once(
    visuals,
    '''                referenceSourceImage = nil
                photoData = nil
                isGeneratedArtwork = false
                photoPreviewID = UUID()''',
    '''                referenceSourceImage = nil
                photoData = nil
                isGeneratedArtwork = false
                referencePreviewID = UUID()
                photoPreviewID = UUID()''',
    "empty photo reset",
)
visuals = replace_once(
    visuals,
    '''            referencePhotoData = loadedData
            referenceSourceImage = decodedReference.map { Image(uiImage: $0) }
            photoData = loadedData
            isGeneratedArtwork = false
            photoPreviewID = requestID''',
    '''            referencePhotoData = loadedData
            referenceSourceImage = decodedReference.map { Image(uiImage: $0) }
            photoData = loadedData
            isGeneratedArtwork = false
            referencePreviewID = requestID
            photoPreviewID = requestID''',
    "loaded photo identities",
)
visuals = replace_once(
    visuals,
    r'''            referenceSourceImage = nil
            photoData = nil
            isGeneratedArtwork = false
            message = "Icon saved to \(libraryName)’s visual library on this iPhone."''',
    r'''            referenceSourceImage = nil
            photoData = nil
            isGeneratedArtwork = false
            referencePreviewID = UUID()
            photoPreviewID = UUID()
            message = "Icon saved to \(libraryName)’s visual library on this iPhone."''',
    "post-save preview reset",
)

visuals = replace_once(
    visuals,
    r'''    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var showingPlayground = false''',
    r'''    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var showingPlayground = false
    @State private var isPreparingResult = false''',
    "generated result progress state",
)

button_anchor = r'''            Button {
                showingPlayground = true
            } label: {
                Label(
                    isRegeneration ? "Regenerate illustrated icon" : "Generate illustrated icon",
                    systemImage: "apple.intelligence"
                )
            }
            .buttonStyle(LifeRouteSecondaryButtonStyle())
            .disabled(cleanLabel.isEmpty || !supportsImagePlayground)
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
            )'''
button_replacement = r'''            Button {
                showingPlayground = true
            } label: {
                if isPreparingResult {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Preparing approved visual…")
                    }
                } else {
                    Label(
                        isRegeneration ? "Regenerate illustrated icon" : "Generate illustrated icon",
                        systemImage: "apple.intelligence"
                    )
                }
            }
            .buttonStyle(LifeRouteSecondaryButtonStyle())
            .disabled(cleanLabel.isEmpty || !supportsImagePlayground || isPreparingResult)
            .imagePlaygroundSheet(
                isPresented: $showingPlayground,
                concepts: concepts,
                sourceImage: sourceImage,
                onCompletion: { url in
                    isPreparingResult = true
                    Task {
                        let data = await ABAVisualSupportImageProcessor.normalizedSquarePNG(from: url)
                        isPreparingResult = false
                        onImageReady(data)
                    }
                },
                onCancellation: {
                    isPreparingResult = false
                }
            )'''
visuals = replace_once(visuals, button_anchor, button_replacement, "visible result preparation")

visuals = replace_once(
    visuals,
    '''        Treat the result as part of one coordinated professionally designed ABA visual-support library. Keep the illustration style, line weight, shading, proportions, background treatment, and icon scale consistent. Prioritize immediate functional recognition and visual clarity over decorative detail for use in visual schedules, choice boards, First/Then boards, communication books, transition supports, and activity schedules.''',
    '''        Treat the result as part of one coordinated professionally designed ABA visual-support library. Keep the illustration style, line weight, shading, proportions, neutral front or three-quarter viewing angle, pure-white background treatment, and icon scale consistent. Prioritize immediate functional recognition and visual clarity over decorative detail for use in visual schedules, choice boards, First/Then boards, communication books, transition supports, and activity schedules.''',
    "style consistency prompt",
)


DASHBOARD_PATH.write_text(dashboard, encoding="utf-8")
VISUALS_PATH.write_text(visuals, encoding="utf-8")

print(
    "LifeRoute v0.8.0 visual-generator follow-up applied: the primary Visual Supports screen now "
    "opens the real text/photo illustrated generator, reference and generated results are distinct, "
    "result normalization has visible progress, and the protected library save flow is unchanged."
)
