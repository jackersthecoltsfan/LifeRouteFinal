import SwiftUI
import PhotosUI

private struct SessionNoteScreenshotAttachment: Identifiable {
    let id: UUID
    let pickerItem: PhotosPickerItem
    let data: Data
}

private enum SessionNoteGenerationPhase: Equatable {
    case idle
    case checkingAvailability
    case generating
    case repairing
    case success
    case unavailable(String)
    case failed(String)
    case timedOut
    case cancelled

    var label: String {
        switch self {
        case .idle: return "Ready"
        case .checkingAvailability: return "Checking on-device availability…"
        case .generating: return "Drafting note…"
        case .repairing: return "Checking clinical format…"
        case .success: return "Draft ready"
        case .unavailable(let reason): return reason
        case .failed(let reason): return reason
        case .timedOut: return "Generation timed out."
        case .cancelled: return "Request cancelled."
        }
    }

    var symbol: String {
        switch self {
        case .idle: return "sparkles"
        case .checkingAvailability: return "checkmark.shield.fill"
        case .generating: return "sparkles"
        case .repairing: return "stethoscope"
        case .success: return "checkmark.circle.fill"
        case .unavailable: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.octagon.fill"
        case .timedOut: return "timer.badge.exclamationmark"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

// v0.7.0 Build D clinical presentation: visual hierarchy only; generation contracts are unchanged.
struct AISessionNoteGeneratorView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var clientState: ClientProfileCore
    @ObservedObject var toolsState: SessionToolsCore

    @State private var selectedClientCode = ""
    @State private var narrative = ""
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var screenshotAttachments: [SessionNoteScreenshotAttachment] = []
    @State private var isLoadingScreenshots = false
    @State private var generatedNote = ""
    @State private var message: String?
    @State private var localNotice: String?
    @State private var generationPhase: SessionNoteGenerationPhase = .idle
    @State private var generationTask: Task<Void, Never>?
    @State private var activeGenerationID = UUID()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                hero
                inputCard
                actionCard
                if !generatedNote.isEmpty { resultCard }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .navigationTitle("Session Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: selectedPhotoItems) {
            await loadSelectedScreenshots()
        }
        .onDisappear {
            if generationTask != nil {
                cancelGeneration()
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            LifeRouteScreenHeader(
                title: "Session Note",
                subtitle: "Draft from supplied session facts, optional local screenshot text, and reviewed client context.",
                systemImage: "sparkles.rectangle.stack.fill"
            )

            HStack(spacing: 8) {
                Label("ON-DEVICE", systemImage: "apple.intelligence")
                Text("·")
                Text("SUPPLIED FACTS ONLY")
            }
            .font(.caption2.weight(.black))
            .tracking(0.7)
            .foregroundStyle(palette.accentSecondary)
            .padding(.horizontal, 11)
            .frame(minHeight: 34)
            .background(palette.panelElevated.opacity(0.34), in: Capsule())
        }
        .padding(12)
        .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(palette.accent.opacity(0.17), lineWidth: 1)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Session facts")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)

            Picker("Client", selection: $selectedClientCode) {
                Text("General / no client").tag("")
                ForEach(clientState.clients) { client in
                    Text(client.code).tag(client.code)
                }
            }
            .pickerStyle(.menu)

            Menu {
                if matchingScratchNotes.count > 1 {
                    Button("Append all \(matchingScratchNotes.count) matching notes") {
                        let combined = matchingScratchNotes
                            .reversed()
                            .map(\.text)
                            .joined(separator: "\n\n")
                        appendToNarrative(combined)
                        message = "Matching scratch notes added to session facts."
                        LifeRouteHaptics.selection()
                    }
                }

                ForEach(matchingScratchNotes.prefix(12)) { note in
                    Button {
                        appendToNarrative(note.text)
                        message = "Scratch note added to session facts."
                        LifeRouteHaptics.selection()
                    } label: {
                        Text("\(note.createdAt.formatted(date: .omitted, time: .shortened)) · \(String(note.text.prefix(56)))")
                    }
                }

                if matchingScratchNotes.isEmpty {
                    Text("No matching scratch notes")
                }
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.title3)
                        .foregroundStyle(palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pull from Scratch Notes")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Text(scratchNoteStatus)
                            .font(.caption2)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .disabled(matchingScratchNotes.isEmpty)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $narrative)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                if narrative.isEmpty {
                    Text("Type or paste what happened during the session…")
                        .foregroundStyle(palette.textSecondary.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }

            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 6,
                matching: .images
            ) {
                HStack(spacing: 11) {
                    Image(systemName: screenshotAttachments.isEmpty ? "photo.badge.plus" : "photo.stack.fill")
                        .font(.title3)
                        .foregroundStyle(palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(screenshotAttachments.isEmpty ? "Attach data screenshots" : "Add or change screenshots")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Text("Up to 6 · text recognition runs locally")
                            .font(.caption2)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    if isLoadingScreenshots {
                        ProgressView()
                            .tint(palette.accent)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }

            if !screenshotAttachments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Attached data screenshots")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text("\(screenshotAttachments.count) of 6")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(palette.accentSecondary)
                    }

                    ForEach(Array(screenshotAttachments.enumerated()), id: \.element.id) { index, attachment in
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text.image.fill")
                                .foregroundStyle(palette.accent)
                            Text("Data screenshot \(index + 1)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.textPrimary)
                            Spacer()
                            Button(role: .destructive) {
                                removeScreenshot(attachment)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .accessibilityLabel("Remove data screenshot \(index + 1)")
                        }
                        .padding(.horizontal, 11)
                        .frame(minHeight: 44)
                        .background(palette.panelElevated.opacity(0.24), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Attached data screenshots")
            }

            if let selectedClient {
                Text("Saved context for \(selectedClient.code) can help the model understand terminology, but it is explicitly told not to claim a target or behavior occurred unless your session facts support it.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .lifeRouteCard()
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                startGeneration()
            } label: {
                Label(actionButtonTitle, systemImage: "sparkles")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())
            .disabled(generationTask != nil || (narrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && screenshotAttachments.isEmpty))

            if generationTask != nil {
                Button {
                    cancelGeneration()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
            }

            Label(generationPhase.label, systemImage: generationPhase.symbol)
                .font(.caption)
                .foregroundStyle(palette.textSecondary)

            if let message {
                Label(message, systemImage: generatedNote.isEmpty ? "info.circle.fill" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            if let localNotice {
                Label(localNotice, systemImage: "photo.stack.fill")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Text("Review every sentence before using a generated draft for documentation or billing.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .lifeRouteCard()
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Editable draft")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Button {
                    UIPasteboard.general.string = generatedNote
                    LifeRouteHaptics.success()
                    message = "Draft copied."
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .font(.caption.weight(.bold))
            }

            TextEditor(text: $generatedNote)
                .frame(minHeight: 230)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                startGeneration()
            } label: {
                Label("Regenerate from current facts", systemImage: "arrow.clockwise")
            }
            .buttonStyle(LifeRouteSecondaryButtonStyle())
            .disabled(generationTask != nil)
        }
        .lifeRouteCard()
    }

    private var selectedClient: LifeRouteClientProfile? {
        guard !selectedClientCode.isEmpty else { return nil }
        return clientState.client(code: selectedClientCode)
    }

    private var actionButtonTitle: String {
        if generationTask != nil {
            switch generationPhase {
            case .repairing:
                return "Checking format…"
            case .checkingAvailability:
                return "Checking availability…"
            default:
                return "Drafting…"
            }
        }
        return generatedNote.isEmpty ? "Draft note with AI" : "Regenerate note"
    }

    private var matchingScratchNotes: [QuickSessionNote] {
        let selectedCode = selectedClientCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = toolsState.notes.filter { note in
            if selectedCode.isEmpty { return note.clientCode == nil }
            return note.clientCode?.caseInsensitiveCompare(selectedCode) == .orderedSame
        }
        return Array(matches.reversed())
    }

    private var scratchNoteStatus: String {
        let count = matchingScratchNotes.count
        if count == 0 {
            return selectedClientCode.isEmpty ? "No General scratch notes yet" : "No scratch notes for \(selectedClientCode)"
        }
        return "\(count) matching note\(count == 1 ? "" : "s") · appends without overwriting"
    }

    private func appendToNarrative(_ value: String) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if narrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            narrative = clean
        } else {
            narrative += "\n\n\(clean)"
        }
    }

    @MainActor
    private func loadSelectedScreenshots() async {
        let selectedItems = Array(selectedPhotoItems.prefix(6))
        guard !selectedItems.isEmpty else {
            screenshotAttachments.removeAll()
            isLoadingScreenshots = false
            return
        }

        isLoadingScreenshots = true
        defer { isLoadingScreenshots = false }

        var loaded: [SessionNoteScreenshotAttachment] = []
        var failedCount = 0
        for item in selectedItems {
            guard !Task.isCancelled else { return }
            guard let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty else {
                failedCount += 1
                continue
            }
            let stableID = screenshotAttachments.first(where: { $0.pickerItem == item })?.id ?? UUID()
            loaded.append(SessionNoteScreenshotAttachment(id: stableID, pickerItem: item, data: data))
        }

        guard !Task.isCancelled, selectedPhotoItems == selectedItems else { return }
        screenshotAttachments = loaded
        if failedCount > 0 {
            localNotice = "\(failedCount) screenshot\(failedCount == 1 ? "" : "s") could not be loaded. The remaining attachments are ready."
        } else {
            localNotice = "\(loaded.count) data screenshot\(loaded.count == 1 ? "" : "s") ready for local text recognition."
        }
    }

    private func removeScreenshot(_ attachment: SessionNoteScreenshotAttachment) {
        selectedPhotoItems.removeAll { $0 == attachment.pickerItem }
        screenshotAttachments.removeAll { $0.id == attachment.id }
        localNotice = "Data screenshot removed."
    }

    private func startGeneration() {
        guard generationTask == nil else { return }
        let requestID = UUID()
        activeGenerationID = requestID
        generationTask = Task { await generate(requestID: requestID) }
    }

    private func cancelGeneration() {
        activeGenerationID = UUID()
        generationTask?.cancel()
        generationTask = nil
        generationPhase = .cancelled
        message = "The request stopped safely. Your facts, screenshots, and prior draft were preserved."
        LifeRouteHaptics.selection()
    }

    @MainActor
    private func generate(requestID: UUID) async {
        defer { generationTask = nil }

        guard activeGenerationID == requestID else { return }
        message = nil
        generationPhase = .checkingAvailability

        let hasExistingDraft = !generatedNote.isEmpty
        generationPhase = hasExistingDraft ? .repairing : .generating

        do {
            let result = try await LifeRouteIntelligenceCore.generateABASessionNote(
                narrative: narrative,
                screenshotDataItems: screenshotAttachments.map(\.data),
                client: selectedClient
            )
            guard !Task.isCancelled, activeGenerationID == requestID else { return }
            generatedNote = result
            generationPhase = .success
            message = "Draft generated on device."
            LifeRouteHaptics.success()
        } catch is CancellationError {
            guard activeGenerationID == requestID else { return }
            generationPhase = .cancelled
            message = "The request stopped safely. Your facts, screenshots, and prior draft were preserved."
        } catch let error as LifeRouteIntelligenceError {
            guard activeGenerationID == requestID else { return }
            switch error {
            case .unavailable:
                generationPhase = .unavailable(error.localizedDescription)
            case .emptyInput:
                generationPhase = .failed(error.localizedDescription)
            case .generationFailed(let text):
                generationPhase = text.lowercased().contains("time") ? .timedOut : .failed(text)
            }
            message = error.localizedDescription
        } catch {
            guard activeGenerationID == requestID else { return }
            generationPhase = .failed(error.localizedDescription)
            message = error.localizedDescription
        }
    }
}

struct AISessionPlanBuilderView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var clientState: ClientProfileCore

    @State private var selectedClientCode = ""
    @State private var durationMinutes = 120
    @State private var targetsText = ""
    @State private var reinforcersText = ""
    @State private var additionalContext = ""
    @State private var generatedPlan = ""
    @State private var message: String?
    @State private var isGenerating = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                hero
                contextCard
                inputsCard
                actionCard
                if !generatedPlan.isEmpty { resultCard }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .navigationTitle("Session Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: selectedClientCode) { _ in loadClientContext() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            LifeRouteScreenHeader(
                title: "Session Plan",
                subtitle: "Shape approved targets, known reinforcers, client context, and session time into a practical flow.",
                systemImage: "brain.head.profile"
            )

            Label("SUPERVISOR-APPROVED INPUTS ONLY", systemImage: "checkmark.shield.fill")
                .font(.caption2.weight(.black))
                .tracking(0.6)
                .foregroundStyle(palette.accentSecondary)
                .padding(.horizontal, 11)
                .frame(minHeight: 34)
                .background(palette.panelElevated.opacity(0.34), in: Capsule())
        }
        .padding(12)
        .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(palette.accent.opacity(0.17), lineWidth: 1)
        }
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Client", selection: $selectedClientCode) {
                Text("General / no client").tag("")
                ForEach(clientState.clients) { client in Text(client.code).tag(client.code) }
            }
            .pickerStyle(.menu)

            Picker("Session length", selection: $durationMinutes) {
                Text("1 hr").tag(60)
                Text("1.5 hr").tag(90)
                Text("2 hr").tag(120)
                Text("2.5 hr").tag(150)
                Text("3 hr").tag(180)
                Text("4 hr").tag(240)
                Text("6 hr").tag(360)
            }
            .pickerStyle(.menu)
        }
        .lifeRouteCard()
    }

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            plannerEditor(title: "Approved targets / priorities", text: $targetsText, minHeight: 120)
            plannerEditor(title: "Known reinforcers / preferred activities", text: $reinforcersText, minHeight: 100)
            plannerEditor(title: "Additional context for this session", text: $additionalContext, minHeight: 90)

            if selectedClient != nil {
                Button("Reload saved client context") { loadClientContext() }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())
            }
        }
        .lifeRouteCard()
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task { await generate() }
            } label: {
                Label(isGenerating ? "Building plan…" : "Build session plan with AI", systemImage: "sparkles")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())
            .disabled(isGenerating || SessionToolsCore.list(from: targetsText).isEmpty)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Text("This organizes supervisor-approved information. It does not create new treatment targets, behavior protocols, prompting procedures, or reinforcement schedules.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .lifeRouteCard()
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Proposed session flow")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Button {
                    UIPasteboard.general.string = generatedPlan
                    LifeRouteHaptics.success()
                    message = "Plan copied."
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .font(.caption.weight(.bold))
            }

            TextEditor(text: $generatedPlan)
                .frame(minHeight: 250)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .lifeRouteCard()
    }

    private func plannerEditor(title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accentSecondary)
            TextEditor(text: text)
                .frame(minHeight: minHeight)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var selectedClient: LifeRouteClientProfile? {
        guard !selectedClientCode.isEmpty else { return nil }
        return clientState.client(code: selectedClientCode)
    }

    private func loadClientContext() {
        guard let client = selectedClient else {
            targetsText = ""
            reinforcersText = ""
            return
        }
        targetsText = client.currentTargets.joined(separator: "\n")
        reinforcersText = client.preferredActivities.joined(separator: "\n")
    }

    @MainActor
    private func generate() async {
        guard !isGenerating else { return }
        isGenerating = true
        message = nil
        defer { isGenerating = false }

        do {
            generatedPlan = try await LifeRouteIntelligenceCore.generateSessionPlan(
                client: selectedClient,
                durationMinutes: durationMinutes,
                targets: SessionToolsCore.list(from: targetsText),
                reinforcers: SessionToolsCore.list(from: reinforcersText),
                additionalContext: additionalContext
            )
            message = "Session flow generated on device."
            LifeRouteHaptics.success()
        } catch {
            message = error.localizedDescription
        }
    }
}
