import SwiftUI
import Foundation
import OSLog
import PhotosUI

// v0.7.0 Build D clinical presentation: visual hierarchy only; generation contracts are unchanged.
// v0.8.0 session-note runtime repair: explicit terminal states, retained cancellation,
// per-pass watchdogs, reasoned availability, and injectable DEBUG outcomes.
enum SessionNoteGenerationState: Equatable {
    case idle
    case checkingAvailability
    case generating
    case compacting
    case repairing
    case completed(SessionNoteFinalOutcome)
    case unavailable(String)
    case failed(String)
    case timedOut
    case cancelled

    var isActive: Bool {
        switch self {
        case .checkingAvailability, .generating, .compacting, .repairing:
            return true
        default:
            return false
        }
    }
}

// v0.8.0 follow-up session-note refinement:
// Multiple screenshots keep stable UI identity while their bytes remain in-memory only.
private struct SessionNoteScreenshotAttachment: Identifiable {
    let id: UUID
    let pickerItem: PhotosPickerItem
    let data: Data
}

@MainActor
protocol SessionNoteGenerating: AnyObject {
    func availability() async -> SessionNoteModelAvailability
    func generateNote(
        narrative: String,
        screenshotDataItems: [Data],
        client: LifeRouteClientProfile?,
        progress: @escaping (SessionNoteGenerationProgress) async -> Void
    ) async throws -> SessionNoteGenerationResult
}

@MainActor
final class FoundationModelSessionNoteGenerator: SessionNoteGenerating {
    private var isBusy = false

    func availability() async -> SessionNoteModelAvailability {
        LifeRouteIntelligenceCore.sessionNoteModelAvailability()
    }

    func generateNote(
        narrative: String,
        screenshotDataItems: [Data],
        client: LifeRouteClientProfile?,
        progress: @escaping (SessionNoteGenerationProgress) async -> Void
    ) async throws -> SessionNoteGenerationResult {
        guard !isBusy else {
            throw LifeRouteIntelligenceError.generationFailed(
                "The previous on-device model request is still cancelling. Wait a moment, then try again."
            )
        }
        isBusy = true
        defer { isBusy = false }
        return try await LifeRouteIntelligenceCore.generateABASessionNote(
            narrative: narrative,
            screenshotDataItems: screenshotDataItems,
            client: client,
            progress: progress
        )
    }
}

@MainActor
final class AISessionNoteRuntimeModel: ObservableObject {
    private static let logger = Logger(
        subsystem: "Com.Brandongood.LifeRoute",
        category: "SessionNoteRuntime"
    )

    @Published private(set) var state: SessionNoteGenerationState = .idle
    @Published var generatedNote = ""
    @Published private(set) var diagnosticReceipt = ""

    private let generator: SessionNoteGenerating
    private let timeoutSeconds: UInt64
    private var activeTask: Task<Void, Never>?
    private var activeRace: SessionNoteRequestRace<SessionNoteGenerationResult>?
    private var draftLedger = SessionNoteDraftLedger()

    init(generator: SessionNoteGenerating, timeoutSeconds: UInt64 = 75) {
        self.generator = generator
        self.timeoutSeconds = timeoutSeconds
    }

    var isGenerating: Bool { state.isActive }

    func start(narrative: String, screenshotDataItems: [Data], client: LifeRouteClientProfile?) {
        guard !state.isActive else { return }

        let currentRequestID = UUID()
        draftLedger.begin(requestID: currentRequestID, preserving: generatedNote)
        diagnosticReceipt = ""
        state = .checkingAvailability
        Self.logger.notice("Session-note generation started; checking model availability")

        let race = SessionNoteRequestRace<SessionNoteGenerationResult>(timeoutSeconds: timeoutSeconds)
        activeRace = race
        activeTask = Task { [weak self] in
            guard let self else { return }
            let availability = await generator.availability()
            guard draftLedger.isCurrent(currentRequestID), !Task.isCancelled else { return }

            guard case .available = availability else {
                if case .unavailable(let explanation) = availability {
                    state = .unavailable(explanation)
                }
                recordRuntimeDiagnostic("modelUnavailable")
                Self.logger.notice("Session-note generation stopped because the model is unavailable")
                finish(requestID: currentRequestID)
                return
            }

            state = .generating
            do {
                let result = try await race.run {
                    try await self.generator.generateNote(
                        narrative: narrative,
                        screenshotDataItems: screenshotDataItems,
                        client: client
                    ) { progress in
                        await self.receive(progress: progress, requestID: currentRequestID)
                    }
                }
                guard draftLedger.isCurrent(currentRequestID) else { return }
                diagnosticReceipt = result.diagnostics.shareableText
                let cleaned = result.draft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else {
                    state = .failed("Apple Intelligence returned an empty draft. Your session facts and any previous draft were preserved.")
                    recordRuntimeDiagnostic("emptyResult")
                    finish(requestID: currentRequestID)
                    return
                }
                guard draftLedger.accept(cleaned, for: currentRequestID) else { return }
                generatedNote = draftLedger.draft
                state = .completed(result.outcome)
                Self.logger.notice("Session-note generation completed with outcome: \(result.outcome.rawValue, privacy: .public)")
                if result.outcome != .fallback {
                    LifeRouteHaptics.success()
                }
            } catch is CancellationError {
                guard draftLedger.isCurrent(currentRequestID) else { return }
                state = .cancelled
                recordRuntimeDiagnostic("cancelled")
                Self.logger.notice("Session-note generation cancelled")
            } catch is SessionNoteRequestRaceError {
                guard draftLedger.isCurrent(currentRequestID) else { return }
                state = .timedOut
                recordRuntimeDiagnostic("timedOut")
                Self.logger.error("Session-note generation timed out")
            } catch let error as LifeRouteIntelligenceError {
                guard draftLedger.isCurrent(currentRequestID) else { return }
                switch error {
                case .unavailable:
                    state = .unavailable(error.localizedDescription)
                    recordRuntimeDiagnostic("modelUnavailable")
                case .emptyInput:
                    state = .failed(error.localizedDescription)
                    recordRuntimeDiagnostic("emptyInput")
                case .contextWindowExceeded:
                    state = .failed(error.localizedDescription)
                    recordRuntimeDiagnostic("contextWindowExceeded")
                case .generationFailed:
                    state = .failed(error.localizedDescription)
                    recordRuntimeDiagnostic("generationFailed")
                }
            } catch {
                guard draftLedger.isCurrent(currentRequestID) else { return }
                state = .failed(error.localizedDescription)
                recordRuntimeDiagnostic("unexpectedFailure")
            }
            finish(requestID: currentRequestID)
        }
    }

    func cancel() {
        guard state.isActive else { return }
        Self.logger.notice("Session-note generation cancellation requested")
        activeRace?.cancel()
        activeTask?.cancel()
    }

    private func receive(progress: SessionNoteGenerationProgress, requestID: UUID) async {
        guard draftLedger.isCurrent(requestID), !Task.isCancelled else { return }
        switch progress {
        case .generating:
            state = .generating
            Self.logger.notice("Session-note first generation pass active")
        case .compacting:
            state = .compacting
            activeRace?.restartTimeout()
            Self.logger.notice("Session-note compact context retry active")
        case .repairing:
            state = .repairing
            activeRace?.restartTimeout()
            Self.logger.notice("Session-note bounded repair pass active")
        }
    }

    private func finish(requestID: UUID) {
        guard draftLedger.isCurrent(requestID) else { return }
        activeTask = nil
        activeRace = nil
        draftLedger.finish(requestID: requestID)
    }

    private func recordRuntimeDiagnostic(_ code: String) {
        if diagnosticReceipt.isEmpty {
            diagnosticReceipt = "SN-DIAG-1 | runtime=\(code)"
        } else if !diagnosticReceipt.contains("runtime=\(code)") {
            diagnosticReceipt += " | runtime=\(code)"
        }
        Self.logger.notice(
            "Session-note receipt: \(self.diagnosticReceipt, privacy: .public)"
        )
    }

}

#if DEBUG
@MainActor
private final class SessionNoteFixtureGenerator: SessionNoteGenerating {
    enum Mode: String {
        case success
        case delayedSuccess = "delayed-success"
        case unavailable
        case error
        case empty
        case timeout
        case cancellation
        case repair
        case repairFailure = "repair-failure"
        case contextRetrySuccess = "context-retry-success"
        case contextRetryFailure = "context-retry-failure"
        case regenerationFailure = "regeneration-failure"
    }

    private let mode: Mode
    private var requestCount = 0

    init(mode: Mode) {
        self.mode = mode
    }

    func availability() async -> SessionNoteModelAvailability {
        if mode == .unavailable {
            return .unavailable("Apple Intelligence is unavailable in this DEBUG fixture.")
        }
        return .available
    }

    func generateNote(
        narrative: String,
        screenshotDataItems: [Data],
        client: LifeRouteClientProfile?,
        progress: @escaping (SessionNoteGenerationProgress) async -> Void
    ) async throws -> SessionNoteGenerationResult {
        requestCount += 1
        await progress(.generating)
        switch mode {
        case .success:
            return Self.result(.generated)
        case .delayedSuccess:
            try await Task.sleep(nanoseconds: 1_200_000_000)
            return Self.result(.generated)
        case .unavailable:
            throw LifeRouteIntelligenceError.unavailable
        case .error:
            throw LifeRouteIntelligenceError.generationFailed("Injected generation failure.")
        case .empty:
            return SessionNoteGenerationResult(draft: "", outcome: .rejected, issueCodes: [])
        case .timeout, .cancellation:
            try await Task.sleep(nanoseconds: 600_000_000_000)
            return Self.result(.generated)
        case .repair:
            await progress(.repairing)
            try await Task.sleep(nanoseconds: 400_000_000)
            return Self.result(.repaired)
        case .repairFailure:
            await progress(.repairing)
            throw LifeRouteIntelligenceError.generationFailed("Injected bounded repair failure.")
        case .contextRetrySuccess:
            await progress(.compacting)
            try await Task.sleep(nanoseconds: 300_000_000)
            return Self.result(.generated)
        case .contextRetryFailure:
            await progress(.compacting)
            throw LifeRouteIntelligenceError.contextWindowExceeded
        case .regenerationFailure:
            if requestCount == 1 { return Self.result(.generated) }
            throw LifeRouteIntelligenceError.generationFailed("Injected regeneration failure.")
        }
    }

    private static func result(_ outcome: SessionNoteFinalOutcome) -> SessionNoteGenerationResult {
        SessionNoteGenerationResult(draft: sampleDraft, outcome: outcome, issueCodes: [])
    }

    private static let sampleDraft = "The RBT met with the client at home with the caregiver present. The RBT began with pairing and FCT during play, and the client used a full verbal prompt to mand for more time. The client then transitioned to table work and required two redirections to attend.\n\nFollowing completion, the client earned outside play and responded well to the supplied reinforcement. The RBT will continue implementing the established treatment plan during future sessions."
}
#endif
@MainActor
private enum SessionNoteGeneratorFactory {
    static func make() -> SessionNoteGenerating {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let flagIndex = arguments.firstIndex(of: "-LifeRouteSessionNoteFixture"),
           arguments.indices.contains(flagIndex + 1),
           let mode = SessionNoteFixtureGenerator.Mode(rawValue: arguments[flagIndex + 1]) {
            return SessionNoteFixtureGenerator(mode: mode)
        }
        #endif
        return FoundationModelSessionNoteGenerator()
    }
}

@MainActor
struct AISessionNoteGeneratorView: View {
    private enum FocusedField: Hashable {
        case sessionFacts
        case generatedDraft
    }

    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var clientState: ClientProfileCore
    @ObservedObject var toolsState: SessionToolsCore
    @StateObject private var runtime: AISessionNoteRuntimeModel

    @State private var selectedClientCode = ""
    @State private var narrative = ""
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var screenshotAttachments: [SessionNoteScreenshotAttachment] = []
    @State private var isLoadingScreenshots = false
    @State private var localNotice: String?
    @FocusState private var focusedField: FocusedField?

    init(
        clientState: ClientProfileCore,
        toolsState: SessionToolsCore,
        generator: SessionNoteGenerating? = nil
    ) {
        self.clientState = clientState
        self.toolsState = toolsState
        _runtime = StateObject(
            wrappedValue: AISessionNoteRuntimeModel(
                generator: generator ?? SessionNoteGeneratorFactory.make()
            )
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                hero
                    .contentShape(Rectangle())
                    .onTapGesture { finishEditing() }
                inputCard
                actionCard
                if !runtime.generatedNote.isEmpty { resultCard }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Session Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { finishEditing() }
                    .fontWeight(.semibold)
            }
        }
        .task(id: selectedPhotoItems) {
            await loadSelectedScreenshots()
        }
        .onDisappear {
            focusedField = nil
            runtime.cancel()
        }
        .onChange(of: focusedField) { field in
            if field != .sessionFacts {
                narrative = ABATerminologyNormalizer.normalize(narrative)
            }
            if field != .generatedDraft {
                runtime.generatedNote = ABATerminologyNormalizer.normalize(runtime.generatedNote)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                runtime.cancel()
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            LifeRouteScreenHeader(
                title: "Session Note",
                subtitle: "Draft from supplied session facts, one or more local data screenshots, and reviewed client context.",
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

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.body.weight(.bold))
                    .foregroundStyle(palette.accentSecondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Experimental AI Tool")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text("AI-generated Session Notes may be incomplete or inaccurate. Review and edit every note before use. Do not rely on this tool as final clinical documentation.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(palette.accentSecondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(palette.accentSecondary.opacity(0.32), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Experimental AI Tool. AI-generated Session Notes may be incomplete or inaccurate. Review and edit every note before use. Do not rely on this tool as final clinical documentation.")
        }
        .padding(12)
        .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(palette.accent.opacity(0.17), lineWidth: 1)
        }
    }

    private var inputCard: some View {
        let hasScreenshots = !screenshotAttachments.isEmpty
        let loadingScreenshots = isLoadingScreenshots
        let pickerAccent = palette.accent
        let pickerTextPrimary = palette.textPrimary
        let pickerTextSecondary = palette.textSecondary
        let pickerPanelElevated = palette.panelElevated

        return VStack(alignment: .leading, spacing: 13) {
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
                        let combined = matchingScratchNotes.reversed().map(\.text).joined(separator: "\n\n")
                        appendToNarrative(combined)
                        localNotice = "Matching scratch notes added to session facts."
                        LifeRouteHaptics.selection()
                    }
                }

                ForEach(matchingScratchNotes.prefix(12)) { note in
                    Button {
                        appendToNarrative(note.text)
                        localNotice = "Scratch note added to session facts."
                        LifeRouteHaptics.selection()
                    } label: {
                        Text("\(note.createdAt.formatted(date: .omitted, time: .shortened)) · \(String(note.text.prefix(56)))")
                    }
                }

                if matchingScratchNotes.isEmpty { Text("No matching scratch notes") }
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
                    .focused($focusedField, equals: .sessionFacts)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .frame(minHeight: 160)
                    .lifeRouteReadableTextSurface()

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
            ) { [
                hasScreenshots,
                loadingScreenshots,
                pickerAccent,
                pickerTextPrimary,
                pickerTextSecondary,
                pickerPanelElevated
            ] in
                HStack(spacing: 11) {
                    Image(systemName: hasScreenshots ? "photo.stack.fill" : "photo.badge.plus")
                        .font(.title3)
                        .foregroundStyle(pickerAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hasScreenshots ? "Add or change screenshots" : "Attach data screenshots")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(pickerTextPrimary)
                        Text("Up to 6 · text recognition runs locally")
                            .font(.caption2)
                            .foregroundStyle(pickerTextSecondary)
                    }
                    Spacer()
                    if loadingScreenshots {
                        ProgressView()
                            .tint(pickerAccent)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(pickerTextSecondary)
                    }
                }
                .padding(12)
                .background(pickerPanelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
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
        VStack(alignment: .leading, spacing: 12) {
            Button {
                startGeneration()
            } label: {
                Label(runtime.isGenerating ? activeButtonTitle : "Draft note with AI", systemImage: "sparkles")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())
            .disabled(runtime.isGenerating || !hasEvidence)

            if runtime.state != .idle {
                generationStatusCard
            }

            if let localNotice {
                Label(localNotice, systemImage: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Text("Review every sentence before using a generated draft for documentation or billing.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .lifeRouteCard()
    }

    private var generationStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                if runtime.state.isActive {
                    ProgressView()
                        .tint(palette.accent)
                } else {
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusTint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)

            if runtime.state.isActive {
                Button("Cancel generation") { runtime.cancel() }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())
            } else if shouldOfferRetry {
                Button("Try again") { startGeneration() }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())
                    .disabled(!hasEvidence)
            }

            if shouldOfferDiagnostics {
                Button {
                    UIPasteboard.general.string = runtime.diagnosticReceipt
                    localNotice = "Privacy-safe troubleshooting details copied."
                } label: {
                    Label("Copy troubleshooting details", systemImage: "doc.on.doc")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
                .accessibilityHint("Copies reason codes and structural counts without session facts or generated note text.")
            }
        }
        .padding(12)
        .background(statusTint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(statusTint.opacity(0.30), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session note generation status")
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Editable draft")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Button {
                    UIPasteboard.general.string = runtime.generatedNote
                    LifeRouteHaptics.success()
                    localNotice = "Draft copied."
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .font(.caption.weight(.bold))
            }

            TextEditor(text: $runtime.generatedNote)
                .focused($focusedField, equals: .generatedDraft)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .frame(minHeight: 230)
                .lifeRouteReadableTextSurface()

            Button {
                startGeneration()
            } label: {
                Label("Regenerate from current facts", systemImage: "arrow.clockwise")
            }
            .buttonStyle(LifeRouteSecondaryButtonStyle())
            .disabled(runtime.isGenerating || !hasEvidence)
        }
        .lifeRouteCard()
    }

    private var selectedClient: LifeRouteClientProfile? {
        guard !selectedClientCode.isEmpty else { return nil }
        return clientState.client(code: selectedClientCode)
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

    private var hasEvidence: Bool {
        !narrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !screenshotAttachments.isEmpty
    }

    private var activeButtonTitle: String {
        runtime.state == .repairing ? "Checking clinical format…" : "Drafting…"
    }

    private var statusTitle: String {
        switch runtime.state {
        case .idle: return "Ready"
        case .checkingAvailability: return "Checking Apple Intelligence"
        case .generating: return "Drafting on device"
        case .compacting: return "Fitting evidence on device"
        case .repairing: return "Checking clinical format"
        case .completed(let outcome): return outcome.userFacingStatusTitle
        case .unavailable: return "Apple Intelligence unavailable"
        case .failed: return "Generation failed"
        case .timedOut: return "Generation timed out"
        case .cancelled: return "Generation cancelled"
        }
    }

    private var statusMessage: String {
        switch runtime.state {
        case .idle:
            return "Add session facts to begin."
        case .checkingAvailability:
            return "Confirming that the on-device model is ready."
        case .generating:
            return "LifeRoute is creating a draft from the facts you supplied."
        case .compacting:
            return "Apple Intelligence requested a smaller context. LifeRoute is retrying once with typed facts first and reduced supporting context."
        case .repairing:
            return "The first draft needs a bounded second pass to meet the Master ABA format."
        case .completed(let outcome):
            return outcome.userFacingStatusMessage
        case .unavailable(let explanation), .failed(let explanation):
            return explanation
        case .timedOut:
            return "Apple Intelligence did not finish this step within 75 seconds. Your facts, screenshots, and prior draft were preserved."
        case .cancelled:
            return "The request stopped safely. Your facts, screenshots, and prior draft were preserved."
        }
    }

    private var statusIcon: String {
        switch runtime.state {
        case .completed(.generated), .completed(.repaired): return "checkmark.circle.fill"
        case .completed(.fallback), .completed(.rejected): return "exclamationmark.triangle.fill"
        case .unavailable: return "apple.intelligence"
        case .failed, .timedOut: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle.fill"
        default: return "info.circle.fill"
        }
    }

    private var statusTint: Color {
        switch runtime.state {
        case .completed(.generated), .completed(.repaired): return .green
        case .completed(.fallback), .completed(.rejected): return .orange
        case .unavailable, .failed, .timedOut: return .orange
        case .cancelled: return palette.textSecondary
        default: return palette.accent
        }
    }

    private var shouldOfferRetry: Bool {
        switch runtime.state {
        case .unavailable, .failed, .timedOut, .cancelled:
            return true
        default:
            return false
        }
    }

    private var shouldOfferDiagnostics: Bool {
        guard !runtime.diagnosticReceipt.isEmpty else { return false }
        switch runtime.state {
        case .completed(.fallback), .completed(.rejected), .unavailable, .failed, .timedOut, .cancelled:
            return true
        default:
            return false
        }
    }

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

    private func appendToNarrative(_ value: String) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if narrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            narrative = clean
        } else {
            narrative += "\n\n\(clean)"
        }
    }

    private func startGeneration() {
        localNotice = nil
        focusedField = nil
        let normalizedFacts = ABATerminologyNormalizer.normalize(narrative)
        narrative = normalizedFacts
        runtime.start(
            narrative: normalizedFacts,
            screenshotDataItems: screenshotAttachments.map(\.data),
            client: selectedClient
        )
    }

    private func finishEditing() {
        narrative = ABATerminologyNormalizer.normalize(narrative)
        runtime.generatedNote = ABATerminologyNormalizer.normalize(runtime.generatedNote)
        focusedField = nil
    }
}

#if DEBUG
struct SessionNoteReadabilityFixtureView: View {
    @Environment(\.lifeRoutePalette) private var palette

    @State private var sessionFacts = """
    The RBT met with the client in the client's home while the LBS and family members were present. The session began with outdoor pairing and functional communication targets before the client transitioned indoors for instructional activities and waiting practice. The client later returned outdoors for play, transitioned inside for cooperative play and another instructional period, and engaged in elopement during the later work period.
    """
    @State private var generatedDraft = """
    The RBT met with the client in the client's home. Present during the session were the RBT, LBS, grandmother, mother, father, brother, and the brother's BHT. The session began with pairing outdoors while the RBT targeted FCT through full-sentence manding and requests for additional time. The RBT then transitioned the client indoors for instructional activities, targeted waiting, and transitioned the client back outdoors for additional play.

    The LBS and RBT later transitioned the client indoors for additional instructional activities, followed by cooperative play and another instructional period. During the later work period, the client engaged in elopement and required multiple redirections to return to and attend to the task. Following re-engagement, the client earned preferred outdoor time. The LBS also instructed the RBT regarding skill-acquisition targets, including newly implemented programs.

    The client participated in the supplied session activities. The RBT will continue implementing the established treatment plan during future sessions.
    """

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                LifeRouteScreenHeader(
                    title: "Session Note",
                    subtitle: "Readability fixture for dense clinical text surfaces.",
                    systemImage: "doc.text.magnifyingglass"
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Session facts")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    TextEditor(text: $sessionFacts)
                        .frame(minHeight: 160)
                        .lifeRouteReadableTextSurface()
                }
                .lifeRouteCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Editable draft")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    TextEditor(text: $generatedDraft)
                        .frame(minHeight: 420)
                        .lifeRouteReadableTextSurface()
                }
                .lifeRouteCard()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }
}
#endif
