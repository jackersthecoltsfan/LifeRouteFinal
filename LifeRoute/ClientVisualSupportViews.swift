import SwiftUI
import PhotosUI
import UIKit
import ImageIO
import AVFoundation

#if canImport(ImagePlayground)
import ImagePlayground
#endif

struct ClientVisualSupportCenter: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var visualState: ClientVisualSupportCore
    @ObservedObject var clientState: ClientProfileCore
    @State private var selectedClientCode: String

    init(visualState: ClientVisualSupportCore, clientState: ClientProfileCore, initialClientCode: String = ClientVisualSupportCore.generalClientCode) {
        self.visualState = visualState
        self.clientState = clientState
        _selectedClientCode = State(initialValue: initialClientCode.isEmpty ? ClientVisualSupportCore.generalClientCode : initialClientCode)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                visualHero

                VStack(alignment: .leading, spacing: 10) {
                    Text("Visual library")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)

                    Picker("Visual library", selection: $selectedClientCode) {
                        Text(ClientVisualSupportCore.generalDisplayName)
                            .tag(ClientVisualSupportCore.generalClientCode)
                        ForEach(clientState.clients) { client in
                            Text(client.code).tag(client.code)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(libraryExplanation)
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Create & use")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: columns, spacing: 10) {
                        NavigationLink {
                            ClientVisualIconLibraryView(visualState: visualState, clientCode: selectedClientCode)
                        } label: {
                            VisualWorkspaceCard(title: "Icon Library", subtitle: "Photos, text, or illustrated icons", systemImage: "photo.on.rectangle.angled")
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ClientChoiceBoardBuilderView(visualState: visualState, clientCode: selectedClientCode)
                        } label: {
                            VisualWorkspaceCard(title: "Choice Boards", subtitle: "Build fast choice grids", systemImage: "square.grid.2x2.fill")
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ClientFirstThenVisualView(visualState: visualState, clientState: clientState, initialClientCode: selectedClientCode)
                        } label: {
                            VisualWorkspaceCard(title: "First / Then", subtitle: "Create a two-step visual", systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(.plain)

                    }
                }

                HStack(spacing: 8) {
                    VisualLibraryMetric(value: visualState.icons(for: selectedClientCode).count, label: "Icons")
                    VisualLibraryMetric(value: visualState.choiceBoards(for: selectedClientCode).count, label: "Boards")
                }
                .lifeRouteCard()

                // v0.7.0 saved visual library reuse: saved boards and schedules are discoverable
                // from the library itself instead of being stranded at the bottom of builder screens.
                savedVisualLibrary

                Text("\(libraryDisplayName) visual supports are saved locally in protected LifeRoute app data on this iPhone.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
            }
            .padding(18)
            .padding(.bottom, 24)
        }
        .navigationTitle("Visual Supports")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { validateSelectedLibrary() }
        .onReceive(clientState.$clients) { _ in validateSelectedLibrary() }
    }

    private var savedVisualLibrary: some View {
        let boards = visualState.choiceBoards(for: selectedClientCode)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved visuals")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(boards.count)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(palette.accent.opacity(0.12), in: Capsule())
            }

            if boards.isEmpty {
                VisualBuilderEmptyState(
                    title: "No saved boards yet",
                    subtitle: "Save a Choice Board and it will be available here to reopen and use.",
                    systemImage: "square.stack.3d.up"
                )
            } else {
                if !boards.isEmpty {
                    Text("CHOICE BOARDS")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(palette.textSecondary)

                    ForEach(boards) { board in
                        NavigationLink {
                            ClientChoiceBoardPreviewView(
                                visualState: visualState,
                                board: board,
                                clientCode: selectedClientCode
                            )
                        } label: {
                            SavedVisualLibraryRow(
                                title: board.title,
                                detail: "\(board.iconIDs.count) choices · \(board.columns) columns",
                                systemImage: "square.grid.2x2.fill",
                                actionLabel: "Open"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .lifeRouteCard()
    }

    private var visualHero: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.accent.opacity(0.16))
                Image(systemName: "rectangle.3.group.fill")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 5) {
                Text("Visual workspace")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text("Create general or client-specific icons, choice boards, and First / Then visuals.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .lifeRouteCard()
    }

    private var libraryDisplayName: String {
        selectedClientCode == ClientVisualSupportCore.generalClientCode ? "General" : selectedClientCode
    }

    private var libraryExplanation: String {
        if selectedClientCode == ClientVisualSupportCore.generalClientCode {
            return "General works immediately without a saved client. Visuals here stay separate from every client-specific library."
        }
        return "Only \(selectedClientCode)’s icons are available to its builders. Other clients and General remain isolated."
    }

    private func validateSelectedLibrary() {
        guard selectedClientCode != ClientVisualSupportCore.generalClientCode else { return }
        if clientState.client(code: selectedClientCode) == nil {
            selectedClientCode = ClientVisualSupportCore.generalClientCode
        }
    }
}

// v0.7.0 B.3 compatibility anchor: struct ClientVisualIconMakerView: View {
private struct VisualWorkspaceCard: View {
    @Environment(\.lifeRoutePalette) private var palette
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(palette.accent.opacity(0.14))
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 44, height: 44)

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.textPrimary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(palette.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 125, alignment: .leading)
        .padding(14)
        .background(palette.panelGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accent.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct VisualLibraryMetric: View {
    @Environment(\.lifeRoutePalette) private var palette
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.title3.weight(.black))
                .foregroundStyle(palette.accentSecondary)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// v0.8.0 follow-up visible ABA visual generator: reference/result clarity and progress.
private enum VisualSupportInputMethod: String, CaseIterable, Identifiable {
    case textOnly
    case camera
    case photoLibrary

    var id: Self { self }
}

private enum VisualSupportFocusedField: Hashable {
    case label
    case description
}

private struct VisualSupportScrollContainer<Content: View>: View {
    let scrolls: Bool
    let content: Content

    init(scrolls: Bool, @ViewBuilder content: () -> Content) {
        self.scrolls = scrolls
        self.content = content()
    }

    var body: some View {
        if scrolls {
            ScrollView { content }
        } else {
            content
        }
    }
}

struct ClientVisualIconLibraryView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var visualState: ClientVisualSupportCore
    let clientCode: String
    var embedded = false
    @State private var label = ""
    @State private var visualDescription = ""
    @State private var inputMethod: VisualSupportInputMethod = .textOnly
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var referencePhotoData: Data?
    @State private var referenceSourceImage: Image?
    @State private var photoData: Data?
    @State private var photoPreviewID = UUID()
    @State private var referencePreviewID = UUID()
    @State private var isGeneratedArtwork = false
    @State private var message: String?
    @State private var isCameraPresented = false
    @FocusState private var focusedInput: VisualSupportFocusedField?

    var body: some View {
        VisualSupportScrollContainer(scrolls: !embedded) {
            LazyVStack(spacing: 16) {
                if !embedded {
                    VisualBuilderHero(
                        title: "Icon Library",
                        subtitle: "Create exact-label photo, text, or illustrated ABA visuals for \(libraryName).",
                        clientCode: libraryName,
                        systemImage: "photo.on.rectangle.angled"
                    )
                }

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

                    Text("Input method")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.textPrimary)

                    VStack(spacing: 8) {
                        Button {
                            selectTextOnly()
                        } label: {
                            inputMethodLabel(
                                "Text only",
                                subtitle: "Create from the exact label and optional description",
                                systemImage: "textformat",
                                method: .textOnly
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            requestCamera()
                        } label: {
                            inputMethodLabel(
                                "Take photo",
                                subtitle: "Capture a reference without saving it first",
                                systemImage: "camera.fill",
                                method: .camera
                            )
                        }
                        .buttonStyle(.plain)

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            inputMethodLabel(
                                "Photo Library",
                                subtitle: "Choose one reference image",
                                systemImage: "photo.on.rectangle",
                                method: .photoLibrary
                            )
                        }
                    }

                    TextField("Exact icon label", text: $label)
                        .focused($focusedInput, equals: .label)
                        .textInputAutocapitalization(.words)
                        .padding(12)
                        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    TextField("Optional visual description", text: $visualDescription, axis: .vertical)
                        .focused($focusedInput, equals: .description)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text("Describe only what helps identify the real item, place, activity, or concept. The exact label stays editable and is rendered by LifeRoute beneath the artwork.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)

                    if let photoData {
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

                    #if canImport(ImagePlayground)
                    if #available(iOS 26.4, *) { // v0.8.0 ABA visual-support Image Playground 26.4 gate
                        ABAVisualSupportImageGeneratorButton(
                            label: label,
                            visualDescription: visualDescription,
                            referencePhotoData: referencePhotoData,
                            sourceImage: referenceSourceImage,
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
            .padding(.horizontal, embedded ? 0 : 18)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(embedded ? "Visual AI Studio" : "\(libraryName) Icons")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedInput = nil }
                    .fontWeight(.semibold)
            }
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            VisualSupportCameraPicker { imageData in
                inputMethod = .camera
                Task { await prepareReferencePhoto(imageData, sourceMessage: "Camera reference ready.") }
            } onCancel: {
                if referencePhotoData == nil { inputMethod = .textOnly }
            }
            .ignoresSafeArea()
        }
        .task(id: selectedPhotoItem) {
            guard let selectedPhotoItem else {
                if inputMethod != .camera { clearReferencePhoto() }
                return
            }
            let loadedData = try? await selectedPhotoItem.loadTransferable(type: Data.self)
            guard !Task.isCancelled,
                  selectedPhotoItem == self.selectedPhotoItem else { return }
            guard let loadedData else {
                message = "LifeRoute could not load that photo."
                return
            }
            inputMethod = .photoLibrary
            await prepareReferencePhoto(
                loadedData,
                sourceMessage: "Photo Library reference ready."
            )
        }
    }

    private func inputMethodLabel(
        _ title: String,
        subtitle: String,
        systemImage: String,
        method: VisualSupportInputMethod
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(inputMethod == method ? Color.black.opacity(0.78) : palette.accent)
                .frame(width: 38, height: 38)
                .background(
                    inputMethod == method ? palette.accent : palette.accent.opacity(0.13),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer()
            Image(systemName: inputMethod == method ? "checkmark.circle.fill" : "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(inputMethod == method ? palette.accentSecondary : palette.textSecondary)
        }
        .padding(11)
        .frame(minHeight: 58)
        .background(
            palette.panelElevated.opacity(inputMethod == method ? 0.48 : 0.28),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(inputMethod == method ? .isSelected : [])
    }

    private func selectTextOnly() {
        focusedInput = nil
        inputMethod = .textOnly
        selectedPhotoItem = nil
        clearReferencePhoto()
        message = "Text-only input selected. Enter the exact label and optional visual description."
        LifeRouteHaptics.selection()
    }

    private func requestCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            message = "A camera is not available on this device. Text only and Photo Library remain available."
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            focusedInput = nil
            selectedPhotoItem = nil
            inputMethod = .camera
            isCameraPresented = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        focusedInput = nil
                        selectedPhotoItem = nil
                        inputMethod = .camera
                        isCameraPresented = true
                    } else {
                        message = "Camera access was not granted. Text only and Photo Library remain available."
                    }
                }
            }
        case .denied, .restricted:
            message = "Camera access is off for LifeRoute. Text only and Photo Library remain available."
        @unknown default:
            message = "The camera is unavailable right now. Text only and Photo Library remain available."
        }
    }

    @MainActor
    private func prepareReferencePhoto(_ data: Data, sourceMessage: String) async {
        guard !data.isEmpty else {
            message = "LifeRoute could not load that reference photo."
            return
        }
        // Decode outside SwiftUI body evaluation and keep the source in memory until explicit save.
        let requestID = UUID()
        let decodedReference = await ClientVisualThumbnailCache.shared.thumbnail(
            for: ClientVisualThumbnailRequest(
                assetID: requestID,
                maximumPixelDimension: 1_024
            ),
            imageData: data
        )
        guard !Task.isCancelled else { return }
        referencePhotoData = data
        referenceSourceImage = decodedReference.map { Image(uiImage: $0) }
        photoData = data
        isGeneratedArtwork = false
        referencePreviewID = requestID
        photoPreviewID = requestID
        message = "\(sourceMessage) Review it, save it directly, or generate an illustrated icon."
    }

    private func clearReferencePhoto() {
        referencePhotoData = nil
        referenceSourceImage = nil
        photoData = nil
        isGeneratedArtwork = false
        referencePreviewID = UUID()
        photoPreviewID = UUID()
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

    private func visualComparisonPreview(
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
        Label(
            "Illustrated generation requires a supported iOS 26.4 Apple Intelligence device. Photo and text-only visual saving remain available.",
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
            focusedInput = nil
            _ = try visualState.addIcon(clientCode: clientCode, label: label, imageData: photoData)
            label = ""
            visualDescription = ""
            selectedPhotoItem = nil
            inputMethod = .textOnly
            clearReferencePhoto()
            message = "Icon saved to \(libraryName)’s visual library on this iPhone."
        } catch { message = error.localizedDescription }
    }
}

private struct VisualSupportCameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: VisualSupportCameraPicker

        init(parent: VisualSupportCameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            defer { parent.dismiss() }
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.90) else {
                parent.onCancel()
                return
            }
            parent.onCapture(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
            parent.dismiss()
        }
    }
}

// v0.8.0 ABA visual-support generator foundation:
// The system model creates artwork; LifeRoute owns the exact label, library, and protected persistence.
private enum ABAVisualSupportPrompt {
    static func make(label: String, visualDescription: String, hasReference: Bool) -> String {
        let cleanLabel = String(label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        let cleanDescription = String(visualDescription.trimmingCharacters(in: .whitespacesAndNewlines).prefix(700))
        let functionalConcept = ABAVisualSupportConceptInterpreter.describe(
            label: cleanLabel,
            visualDescription: cleanDescription,
            hasReference: hasReference
        )

        return """
        Create one ABA visual-support icon for the exact user label “\(cleanLabel)”.
        Functional concept: \(functionalConcept)

        Create a realistically illustrated cartoon that remains clearly recognizable as the real object, location, activity, or concept. Use clean bold outlines, soft natural shading, bright but natural colors, strong visual contrast, and a simple child-friendly ABA visual-support presentation. Use a clean white background. Center one primary subject and let it occupy most of a square 1:1 composition. Remove distracting or irrelevant background information. Preserve identifying characteristics needed for recognition. Do not introduce unrelated objects or scenery. Do not include people unless a person is necessary to communicate the concept.

        Treat the result as part of one coordinated professionally designed ABA visual-support library. Keep the illustration style, line weight, shading, proportions, neutral front or three-quarter viewing angle, pure-white background treatment, and icon scale consistent. Prioritize immediate functional recognition and visual clarity over decorative detail for use in visual schedules, choice boards, First/Then boards, communication books, transition supports, and activity schedules.

        Do not render letters, words, captions, labels, logos, borders, or watermarks inside the artwork. LifeRoute renders the exact user label beneath the artwork separately so spelling and typography remain correct.
        """
    }
}

private enum ABAVisualSupportImageProcessor {
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

#if canImport(ImagePlayground)
@available(iOS 26.4, *)
private struct ABAVisualSupportImageGeneratorButton: View {
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var showingPlayground = false
    @State private var isPreparingResult = false

    let label: String
    let visualDescription: String
    let referencePhotoData: Data?
    let sourceImage: Image?
    let isRegeneration: Bool
    let onImageReady: (Data?) -> Void

    private var cleanLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
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
        options.personalization = .disabled
        return options
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
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
            )
            .imagePlaygroundOptions(options)
            .imagePlaygroundGenerationStyle(.illustration, in: [.illustration])

            Text(
                supportsImagePlayground
                    ? "Apple’s Image Playground opens for review. Illustration style, square output, disabled person personalization, and the Master ABA visual prompt are preconfigured."
                    : "Image generation is unavailable in the current device, language, region, or Apple Intelligence settings."
            )
            .font(.caption)
            .foregroundStyle(palette.textSecondary)
        }
    }
}
#endif
