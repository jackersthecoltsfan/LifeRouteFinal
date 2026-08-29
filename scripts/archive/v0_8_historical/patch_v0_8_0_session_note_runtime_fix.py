#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VIEW_PATH = ROOT / "LifeRoute/AIClinicalToolsViews.swift"
CORE_PATH = ROOT / "LifeRoute/LifeRouteIntelligenceCore.swift"

VIEW_MARKER = "v0.8.0 session-note runtime repair"
CORE_MARKER = "v0.8.0 session-note runtime availability"

view = VIEW_PATH.read_text(encoding="utf-8")
core = CORE_PATH.read_text(encoding="utf-8")

if VIEW_MARKER not in view:
    if "import Foundation\n" not in view:
        view = view.replace("import SwiftUI\n", "import SwiftUI\nimport Foundation\n", 1)
    if "import OSLog\n" not in view:
        view = view.replace("import Foundation\n", "import Foundation\nimport OSLog\n", 1)
    start = view.index("struct AISessionNoteGeneratorView: View {")
    end = view.index("struct AISessionPlanBuilderView: View {")
    replacement = r'''// v0.8.0 session-note runtime repair: explicit terminal states, retained cancellation,
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

@MainActor
protocol SessionNoteGenerating: AnyObject {
    func availability() async -> SessionNoteModelAvailability
    func generateNote(
        narrative: String,
        screenshotData: Data?,
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
        screenshotData: Data?,
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
            screenshotData: screenshotData,
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

    func start(narrative: String, screenshotData: Data?, client: LifeRouteClientProfile?) {
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
                        screenshotData: screenshotData,
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
        screenshotData: Data?,
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
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var screenshotData: Data?
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
        .task(id: selectedPhotoItem) {
            guard let selectedPhotoItem else {
                screenshotData = nil
                return
            }
            let data = try? await selectedPhotoItem.loadTransferable(type: Data.self)
            guard !Task.isCancelled, selectedPhotoItem == self.selectedPhotoItem else { return }
            screenshotData = data
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

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 11) {
                    Image(systemName: screenshotData == nil ? "photo.badge.plus" : "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(screenshotData == nil ? "Attach data screenshot" : "Data screenshot ready")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Text("Optional · text recognition runs locally")
                            .font(.caption2)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
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
        !narrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || screenshotData != nil
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
            return "Apple Intelligence did not finish this step within 75 seconds. Your facts, screenshot, and prior draft were preserved."
        case .cancelled:
            return "The request stopped safely. Your facts, screenshot, and prior draft were preserved."
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
            screenshotData: screenshotData,
            client: selectedClient
        )
    }
}

'''
    view = view[:start] + replacement + view[end:]
    VIEW_PATH.write_text(view, encoding="utf-8")

if CORE_MARKER not in core:
    core_anchor = "enum LifeRouteIntelligenceCore {\n"
    core_types = r'''enum SessionNoteModelAvailability: Equatable {
    case available
    case unavailable(String)
}

enum SessionNoteGenerationProgress: Equatable {
    case generating
    case repairing
}

// v0.8.0 session-note runtime availability
'''
    if core.count(core_anchor) != 1:
        raise SystemExit("session-note runtime patch failed: intelligence-core anchor missing")
    core = core.replace(core_anchor, core_types + core_anchor, 1)

    availability_anchor = "enum LifeRouteIntelligenceCore {\n    static func recognizeText(in imageData: Data) async -> String {"
    availability = r'''enum LifeRouteIntelligenceCore {
    static func sessionNoteModelAvailability() -> SessionNoteModelAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .unavailable("Apple Intelligence is not supported on this iPhone.")
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable("Turn on Apple Intelligence in Settings, then return to LifeRoute and try again.")
            case .unavailable(.modelNotReady):
                return .unavailable("Apple Intelligence is still preparing its on-device model. Keep the iPhone connected to power and Wi-Fi, then try again later.")
            @unknown default:
                return .unavailable("Apple Intelligence is not available on this iPhone right now.")
            }
        }
        #endif
        return .unavailable("AI Session Note requires an Apple Intelligence-capable iPhone running iOS 26 or later.")
    }

    static func recognizeText(in imageData: Data) async -> String {'''
    if core.count(availability_anchor) != 1:
        raise SystemExit("session-note runtime patch failed: availability insertion anchor missing")
    core = core.replace(availability_anchor, availability, 1)

    old_signature = '''        screenshotData: Data?,
        client: LifeRouteClientProfile?
    ) async throws -> String {'''
    new_signature = '''        screenshotData: Data?,
        client: LifeRouteClientProfile?,
        progress: @escaping (SessionNoteGenerationProgress) async -> Void = { _ in }
    ) async throws -> String {'''
    if core.count(old_signature) != 1:
        raise SystemExit("session-note runtime patch failed: ABA generator signature anchor missing")
    core = core.replace(old_signature, new_signature, 1)

    first_anchor = '''        let firstDraft = try await generate(instructions: instructions, prompt: prompt)'''
    first_replacement = '''        await progress(.generating)
        let firstDraft = try await generate(instructions: instructions, prompt: prompt)'''
    if core.count(first_anchor) != 1:
        raise SystemExit("session-note runtime patch failed: first-pass anchor missing")
    core = core.replace(first_anchor, first_replacement, 1)

    repair_anchor = '''        let repairedDraft = try await generate(
            instructions: instructions + """'''
    repair_replacement = '''        await progress(.repairing)
        let repairedDraft = try await generate(
            instructions: instructions + """'''
    if core.count(repair_anchor) != 1:
        raise SystemExit("session-note runtime patch failed: repair-pass anchor missing")
    core = core.replace(repair_anchor, repair_replacement, 1)

    CORE_PATH.write_text(core, encoding="utf-8")

print(
    "LifeRoute v0.8.0 session-note runtime repair applied: explicit availability/generating/repairing/terminal states, "
    "retained cancellation, a resettable 75-second per-pass watchdog, preserved inputs/prior drafts, accessible retry UI, "
    "and DEBUG-injectable success/delay/unavailable/error/empty/timeout/cancellation/repair/regeneration outcomes."
)
