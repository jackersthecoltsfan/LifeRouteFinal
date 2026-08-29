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
    case repairing
    case success
    case unavailable(String)
    case failed(String)
    case timedOut
    case cancelled

    var isActive: Bool {
        switch self {
        case .checkingAvailability, .generating, .repairing:
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
    ) async throws -> String
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
    ) async throws -> String {
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

private enum SessionNoteRequestRaceError: LocalizedError {
    case timedOut

    var errorDescription: String? {
        "Apple Intelligence did not finish this generation step in time. Your session facts and any previous draft are still here."
    }
}

private final class SessionNoteRequestRace: @unchecked Sendable {
    private let lock = NSLock()
    private let timeoutNanoseconds: UInt64
    private var continuation: CheckedContinuation<String, Error>?
    private var generationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var timeoutGeneration = 0
    private var isFinished = false

    init(timeoutSeconds: UInt64) {
        timeoutNanoseconds = timeoutSeconds * 1_000_000_000
    }

    func run(operation: @escaping () async throws -> String) async throws -> String {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if isFinished {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.continuation = continuation
                lock.unlock()

                restartTimeout()
                let task = Task {
                    do {
                        resolve(.success(try await operation()))
                    } catch {
                        resolve(.failure(error))
                    }
                }
                installGenerationTask(task)
            }
        }, onCancel: {
            self.cancel()
        })
    }

    func restartTimeout() {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        timeoutGeneration += 1
        let generation = timeoutGeneration
        let previous = timeoutTask
        let task = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: self?.timeoutNanoseconds ?? 0)
            } catch {
                return
            }
            self?.timeoutFired(generation: generation)
        }
        timeoutTask = task
        lock.unlock()
        previous?.cancel()
    }

    func cancel() {
        resolve(.failure(CancellationError()))
    }

    private func installGenerationTask(_ task: Task<Void, Never>) {
        lock.lock()
        if isFinished {
            lock.unlock()
            task.cancel()
            return
        }
        generationTask = task
        lock.unlock()
    }

    private func timeoutFired(generation: Int) {
        lock.lock()
        let isCurrent = !isFinished && generation == timeoutGeneration
        lock.unlock()
        if isCurrent {
            resolve(.failure(SessionNoteRequestRaceError.timedOut))
        }
    }

    private func resolve(_ result: Result<String, Error>) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        let continuation = self.continuation
        self.continuation = nil
        let generationTask = self.generationTask
        let timeoutTask = self.timeoutTask
        self.generationTask = nil
        self.timeoutTask = nil
        lock.unlock()

        generationTask?.cancel()
        timeoutTask?.cancel()
        continuation?.resume(with: result)
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

    private let generator: SessionNoteGenerating
    private let timeoutSeconds: UInt64
    private var activeTask: Task<Void, Never>?
    private var activeRace: SessionNoteRequestRace?
    private var requestID: UUID?

    init(generator: SessionNoteGenerating, timeoutSeconds: UInt64 = 75) {
        self.generator = generator
        self.timeoutSeconds = timeoutSeconds
    }

    var isGenerating: Bool { state.isActive }

    func start(narrative: String, screenshotDataItems: [Data], client: LifeRouteClientProfile?) {
        guard !state.isActive else { return }

        let currentRequestID = UUID()
        requestID = currentRequestID
        state = .checkingAvailability
        Self.logger.notice("Session-note generation started; checking model availability")

        let race = SessionNoteRequestRace(timeoutSeconds: timeoutSeconds)
        activeRace = race
        activeTask = Task { [weak self] in
            guard let self else { return }
            let availability = await generator.availability()
            guard requestID == currentRequestID, !Task.isCancelled else { return }

            guard case .available = availability else {
                if case .unavailable(let explanation) = availability {
                    state = .unavailable(explanation)
                }
                Self.logger.notice("Session-note generation stopped because the model is unavailable")
                finish(requestID: currentRequestID)
                return
            }

            state = .generating
            do {
                let note = try await race.run {
                    try await self.generator.generateNote(
                        narrative: narrative,
                        screenshotDataItems: screenshotDataItems,
                        client: client
                    ) { progress in
                        await self.receive(progress: progress, requestID: currentRequestID)
                    }
                }
                guard requestID == currentRequestID else { return }
                let cleaned = note.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else {
                    state = .failed("Apple Intelligence returned an empty draft. Your session facts and any previous draft were preserved.")
                    finish(requestID: currentRequestID)
                    return
                }
                generatedNote = cleaned
                state = .success
                Self.logger.notice("Session-note generation completed successfully")
                LifeRouteHaptics.success()
            } catch is CancellationError {
                guard requestID == currentRequestID else { return }
                state = .cancelled
                Self.logger.notice("Session-note generation cancelled")
            } catch is SessionNoteRequestRaceError {
                guard requestID == currentRequestID else { return }
                state = .timedOut
                Self.logger.error("Session-note generation timed out")
            } catch let error as LifeRouteIntelligenceError {
                guard requestID == currentRequestID else { return }
                switch error {
                case .unavailable:
                    state = .unavailable(error.localizedDescription)
                default:
                    state = .failed(error.localizedDescription)
                }
            } catch {
                guard requestID == currentRequestID else { return }
                state = .failed(error.localizedDescription)
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
        guard self.requestID == requestID, !Task.isCancelled else { return }
        switch progress {
        case .generating:
            state = .generating
            Self.logger.notice("Session-note first generation pass active")
        case .repairing:
            state = .repairing
            activeRace?.restartTimeout()
            Self.logger.notice("Session-note bounded repair pass active")
        }
    }

    private func finish(requestID: UUID) {
        guard self.requestID == requestID else { return }
        activeTask = nil
        activeRace = nil
        self.requestID = nil
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
    ) async throws -> String {
        requestCount += 1
        await progress(.generating)
        switch mode {
        case .success:
            return Self.sampleDraft
        case .delayedSuccess:
            try await Task.sleep(nanoseconds: 1_200_000_000)
            return Self.sampleDraft
        case .unavailable:
            throw LifeRouteIntelligenceError.unavailable
        case .error:
            throw LifeRouteIntelligenceError.generationFailed("Injected generation failure.")
        case .empty:
            return ""
        case .timeout, .cancellation:
            try await Task.sleep(nanoseconds: 600_000_000_000)
            return Self.sampleDraft
        case .repair:
            await progress(.repairing)
            try await Task.sleep(nanoseconds: 400_000_000)
            return Self.sampleDraft
        case .regenerationFailure:
            if requestCount == 1 { return Self.sampleDraft }
            throw LifeRouteIntelligenceError.generationFailed("Injected regeneration failure.")
        }
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
                inputCard
                actionCard
                if !runtime.generatedNote.isEmpty { resultCard }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .navigationTitle("Session Note")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedPhotoItems) {
            await loadSelectedScreenshots()
        }
        .onDisappear {
            runtime.cancel()
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
        case .repairing: return "Checking clinical format"
        case .success: return "Draft ready"
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
        case .repairing:
            return "The first draft needs a bounded second pass to meet the Master ABA format."
        case .success:
            return "The editable draft is visible below. Review every sentence before use."
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
        case .success: return "checkmark.circle.fill"
        case .unavailable: return "apple.intelligence"
        case .failed, .timedOut: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle.fill"
        default: return "info.circle.fill"
        }
    }

    private var statusTint: Color {
        switch runtime.state {
        case .success: return .green
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
        runtime.start(
            narrative: narrative,
            screenshotDataItems: screenshotAttachments.map(\.data),
            client: selectedClient
        )
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
