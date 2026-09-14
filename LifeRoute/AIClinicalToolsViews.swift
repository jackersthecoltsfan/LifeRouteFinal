import SwiftUI
import Foundation
import OSLog

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
    case blocked(SessionNoteBoundaryError)
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

@MainActor
protocol SessionNoteGenerating: AnyObject {
    func availability() async -> SessionNoteModelAvailability
    func generateNote(
        narrative: String,
        writerRole: SessionNoteWriterRole,
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
        writerRole: SessionNoteWriterRole,
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
            writerRole: writerRole,
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
    @Published var selectedClientCode: String {
        didSet { changeDraftOwner(from: oldValue) }
    }
    @Published var narrative: String {
        didSet { recordDraftMutation(from: oldValue, to: narrative) }
    }
    @Published var generatedNote: String {
        didSet { recordDraftMutation(from: oldValue, to: generatedNote) }
    }
    @Published private(set) var diagnosticReceipt = ""
    @Published private(set) var extractionSummary: SessionNoteExtractionSummary?
    @Published private(set) var completeness: SessionNoteOutputCompleteness = .reviewRequired

    private let generator: SessionNoteGenerating
    private let timeoutSeconds: UInt64
    private var activeTask: Task<Void, Never>?
    private var activeRace: SessionNoteRequestRace<SessionNoteGenerationResult>?
    private var draftLedger = SessionNoteDraftLedger()
    weak var presentationScope: LifeRoutePresentationScope?
    private var cancellationRequestedID: UUID?
    private var presentationLeave: [UInt64]?
    private let draftStore: (any SessionNoteDraftPersisting)?
    private let draftPersistenceDelayNanoseconds: UInt64
    private var draftRevision: UInt64 = 0
    private var requestDraftRevision: UInt64?
    private var pendingDraftPersistenceTask: Task<Void, Never>?
    private var isApplyingDraftSnapshot = false
    private var inactiveClientDrafts: [String: SessionNoteDraft.ClientDraft] = [:]

    func reconcilePresentation(_ context: LifeRouteEffectContext) {
        let previous = presentationLeave
        presentationLeave = context.leaveIdentity
        if (previous != nil && previous != context.leaveIdentity) || !context.alive || context.scene != .active {
            cancel()
        }
    }

    convenience init(
        generator: SessionNoteGenerating,
        timeoutSeconds: UInt64 = 75
    ) {
        self.init(
            generator: generator,
            timeoutSeconds: timeoutSeconds,
            draftStore: LifeRoutePersistenceStore.shared
        )
    }

    init(
        generator: SessionNoteGenerating,
        timeoutSeconds: UInt64 = 75,
        draftStore: (any SessionNoteDraftPersisting)?,
        draftPersistenceDelayNanoseconds: UInt64 = 300_000_000
    ) {
        self.generator = generator
        self.timeoutSeconds = timeoutSeconds
        self.draftStore = draftStore
        self.draftPersistenceDelayNanoseconds = draftPersistenceDelayNanoseconds
        let restored = draftStore?.loadSessionNoteDraft() ?? .empty
        self.selectedClientCode = restored.selectedClientCode
        self.narrative = restored.sessionFacts
        self.generatedNote = restored.generatedDraft
        self.inactiveClientDrafts = restored.inactiveClientDrafts
        self.inactiveClientDrafts.removeValue(forKey: restored.selectedClientCode)
    }

    var isGenerating: Bool { state.isActive }

    func start(narrative: String, writerCredential: String, client: LifeRouteClientProfile?) {
        guard !state.isActive else { return }
        extractionSummary = nil
        let writerRole: SessionNoteWriterRole
        do {
            try SessionNoteInputBounds.validateTypedFacts(characterCount: narrative.count)
            writerRole = try SessionNoteWriterRole.resolve(profileCredential: writerCredential)
        } catch let error as SessionNoteBoundaryError {
            state = .blocked(error)
            diagnosticReceipt = ""
            recordRuntimeDiagnostic(error.diagnosticCode)
            return
        } catch {
            return
        }

        guard (client?.code ?? "") == selectedClientCode, narrative == self.narrative else {
            state = .failed("Select the current client and session facts before generating.")
            diagnosticReceipt = ""
            recordRuntimeDiagnostic("clientOwnershipMismatch")
            return
        }

        let currentRequestID = UUID()
        let feedbackTicket = presentationScope?.feedbackTicket()
        cancellationRequestedID = nil
        draftLedger.begin(requestID: currentRequestID, preserving: generatedNote)
        requestDraftRevision = draftRevision
        diagnosticReceipt = ""
        state = .checkingAvailability
        Self.logger.notice("Session-note generation started; checking model availability")

        let race = SessionNoteRequestRace<SessionNoteGenerationResult>(timeoutSeconds: timeoutSeconds)
        activeRace = race
        activeTask = Task { [weak self] in
            guard let self else { return }
            let availability = await generator.availability()
            guard draftLedger.isCurrent(currentRequestID) else { return }
            guard !Task.isCancelled else {
                state = .cancelled
                recordRuntimeDiagnostic("cancelled")
                finish(requestID: currentRequestID)
                return
            }

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
                        writerRole: writerRole,
                        client: client
                    ) { progress in
                        await self.receive(progress: progress, requestID: currentRequestID)
                    }
                }
                guard draftLedger.isCurrent(currentRequestID) else { return }
                diagnosticReceipt = result.diagnostics.shareableText
                if let summary = result.extractionSummary { extractionSummary = summary }
                completeness = result.completeness
                guard result.outcome != .rejected else {
                    state = .failed(SessionNoteFinalOutcome.rejected.userFacingStatusMessage)
                    recordRuntimeDiagnostic("rejectedResult")
                    finish(requestID: currentRequestID)
                    return
                }
                let cleaned = result.draft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else {
                    state = .failed("Apple Intelligence returned an empty draft. Your session facts and any previous draft were preserved.")
                    recordRuntimeDiagnostic("emptyResult")
                    finish(requestID: currentRequestID)
                    return
                }
                guard requestDraftRevision == draftRevision else {
                    state = .cancelled
                    recordRuntimeDiagnostic("staleDraftResultIgnored")
                    finish(requestID: currentRequestID)
                    return
                }
                guard draftLedger.accept(cleaned, for: currentRequestID) else { return }
                generatedNote = draftLedger.draft
                state = .completed(result.outcome)
                Self.logger.notice("Session-note generation completed with outcome: \(result.outcome.rawValue, privacy: .public)")
                if result.outcome != .fallback, feedbackTicket?.isEligible == true {
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
            } catch let error as SessionNoteBoundaryError {
                guard draftLedger.isCurrent(currentRequestID) else { return }
                state = .blocked(error)
                recordRuntimeDiagnostic(error.diagnosticCode)
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
        guard state.isActive, let id = draftLedger.activeRequestID, cancellationRequestedID != id else { return }
        cancellationRequestedID = id
        Self.logger.notice("Session-note generation cancellation requested")
        activeRace?.cancel()
        activeTask?.cancel()
        if state == .checkingAvailability {
            state = .cancelled
            recordRuntimeDiagnostic("cancelled")
            finish(requestID: id)
        }
    }

    private func receive(progress: SessionNoteGenerationProgress, requestID: UUID) async {
        guard draftLedger.isCurrent(requestID), !Task.isCancelled else { return }
        switch progress {
        case .extracted(let summary):
            extractionSummary = summary
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
        requestDraftRevision = nil
    }

    var draftIsEmpty: Bool {
        narrative.isEmpty && generatedNote.isEmpty
    }

    func flushDraftPersistence() {
        pendingDraftPersistenceTask?.cancel()
        pendingDraftPersistenceTask = nil
        draftStore?.saveSessionNoteDraft(currentDraft)
    }

    func clearDraft() {
        activeRace?.cancel()
        activeTask?.cancel()
        activeTask = nil
        activeRace = nil
        cancellationRequestedID = nil
        requestDraftRevision = nil
        draftLedger = SessionNoteDraftLedger()
        state = .idle
        diagnosticReceipt = ""
        extractionSummary = nil
        completeness = .reviewRequired

        isApplyingDraftSnapshot = true
        inactiveClientDrafts.removeValue(forKey: selectedClientCode)
        narrative = ""
        generatedNote = ""
        isApplyingDraftSnapshot = false
        draftRevision &+= 1
        flushDraftPersistence()
    }

    private var currentDraft: SessionNoteDraft {
        SessionNoteDraft(
            selectedClientCode: selectedClientCode,
            sessionFacts: narrative,
            generatedDraft: generatedNote,
            inactiveClientDrafts: inactiveClientDrafts
        )
    }

    private func changeDraftOwner(from previousCode: String) {
        guard !isApplyingDraftSnapshot, previousCode != selectedClientCode else { return }
        if narrative.isEmpty && generatedNote.isEmpty {
            inactiveClientDrafts.removeValue(forKey: previousCode)
        } else {
            inactiveClientDrafts[previousCode] = .init(sessionFacts: narrative, generatedDraft: generatedNote)
        }
        let restored = inactiveClientDrafts.removeValue(forKey: selectedClientCode)
        // Invalidate request identity before any suspended completion can publish.
        activeRace?.cancel()
        activeTask?.cancel()
        activeRace = nil
        activeTask = nil
        draftLedger = SessionNoteDraftLedger()
        requestDraftRevision = nil
        cancellationRequestedID = nil
        state = .idle
        diagnosticReceipt = ""
        extractionSummary = nil
        completeness = .reviewRequired
        isApplyingDraftSnapshot = true
        narrative = restored?.sessionFacts ?? ""
        generatedNote = restored?.generatedDraft ?? ""
        isApplyingDraftSnapshot = false
        draftRevision &+= 1
        flushDraftPersistence()
    }

    private func recordDraftMutation(from oldValue: String, to newValue: String) {
        guard !isApplyingDraftSnapshot, oldValue != newValue else { return }
        draftRevision &+= 1
        scheduleDraftPersistence(for: draftRevision)
    }

    private func scheduleDraftPersistence(for scheduledRevision: UInt64) {
        pendingDraftPersistenceTask?.cancel()
        guard draftStore != nil else {
            pendingDraftPersistenceTask = nil
            return
        }
        pendingDraftPersistenceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: draftPersistenceDelayNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled, draftRevision == scheduledRevision else { return }
            pendingDraftPersistenceTask = nil
            draftStore?.saveSessionNoteDraft(currentDraft)
        }
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
        case overLimit = "over-limit"
        case outputLimit = "output-limit"
        case unfinishedOutput = "unfinished-output"

        static var current: Mode? {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: "-LifeRouteSessionNoteFixture"),
                  arguments.indices.contains(index + 1) else { return nil }
            return Mode(rawValue: arguments[index + 1])
        }
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
        writerRole: SessionNoteWriterRole,
        client: LifeRouteClientProfile?,
        progress: @escaping (SessionNoteGenerationProgress) async -> Void
    ) async throws -> SessionNoteGenerationResult {
        requestCount += 1
        await progress(.generating)
        switch mode {
        case .overLimit:
            try SessionNoteInputBounds.validateTypedFacts(characterCount: narrative.count)
            return try await Self.result(.generated, writerRole: writerRole)
        case .outputLimit, .unfinishedOutput:
            let packet = SessionNoteEvidencePacket.make(
                typedFacts: narrative, ocrEvidence: "", savedTerminologyContext: "", profileCode: nil
            )
            return try await SessionNoteGenerationPipeline.generateNote(packet: packet, writerRole: writerRole) { [mode] _ in
                mode == .outputLimit ? String(repeating: "x", count: 8_000) :
                    "The client practiced with the RBT. The RBT supported the client during"
            }
        case .success:
            return try await Self.result(.generated, writerRole: writerRole)
        case .delayedSuccess:
            try await Task.sleep(nanoseconds: 1_200_000_000)
            return try await Self.result(.generated, writerRole: writerRole)
        case .unavailable:
            throw LifeRouteIntelligenceError.unavailable
        case .error:
            throw LifeRouteIntelligenceError.generationFailed("Injected generation failure.")
        case .empty:
            return SessionNoteGenerationResult(draft: "", outcome: .rejected, issueCodes: [])
        case .timeout, .cancellation:
            try await Task.sleep(nanoseconds: 600_000_000_000)
            return try await Self.result(.generated, writerRole: writerRole)
        case .repair:
            await progress(.repairing)
            try await Task.sleep(nanoseconds: 400_000_000)
            return try await Self.result(.repaired, writerRole: writerRole)
        case .repairFailure:
            await progress(.repairing)
            throw LifeRouteIntelligenceError.generationFailed("Injected bounded repair failure.")
        case .contextRetrySuccess:
            await progress(.compacting)
            try await Task.sleep(nanoseconds: 300_000_000)
            return try await Self.result(.generated, writerRole: writerRole)
        case .contextRetryFailure:
            await progress(.compacting)
            throw LifeRouteIntelligenceError.contextWindowExceeded
        case .regenerationFailure:
            if requestCount == 1 { return try await Self.result(.generated, writerRole: writerRole) }
            throw LifeRouteIntelligenceError.generationFailed("Injected regeneration failure.")
        }
    }

    private static func result(
        _ outcome: SessionNoteFinalOutcome, writerRole: SessionNoteWriterRole
    ) async throws -> SessionNoteGenerationResult {
        let packet = SessionNoteEvidencePacket.make(
            typedFacts: sampleDraft, ocrEvidence: "", savedTerminologyContext: "", profileCode: nil
        )
        let result = try await SessionNoteGenerationPipeline.generateNote(packet: packet, writerRole: writerRole) { _ in
            sampleDraft
        }
        return SessionNoteGenerationResult(
            draft: result.draft, outcome: outcome, issueCodes: result.issueCodes,
            diagnostics: result.diagnostics, completeness: result.completeness
        )
    }

    private static let sampleDraft = "At home, the client practiced Following Directions with the RBT at 80% accuracy with a verbal prompt. The client returned the blue folder to the caregiver."

}
#endif

@MainActor
enum SessionNoteGeneratorFactory {
    static func make() -> SessionNoteGenerating {
        #if DEBUG
        if let mode = SessionNoteFixtureGenerator.Mode.current {
            return SessionNoteFixtureGenerator(mode: mode)
        }
        #endif
        return FoundationModelSessionNoteGenerator()
    }
}

@MainActor
struct AISessionNoteGeneratorView: View {
    @Environment(\.lifeRoutePresentation) private var visibilityScope
    @State private var visibilityLeave: [UInt64]?

    private enum FocusedField: Hashable {
        case sessionFacts
        case generatedDraft
    }

    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var clientState: ClientProfileCore
    @ObservedObject var toolsState: SessionToolsCore
    @ObservedObject var runtime: AISessionNoteRuntimeModel

    @AppStorage(SessionNoteWriterRole.profileCredentialKey) private var writerCredential = ""
    @State private var localNotice: String?
    @State private var showingClearConfirmation = false
    @FocusState private var focusedField: FocusedField?
    #if DEBUG
    @State private var seededSyntheticFixture = false
    #endif

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
        .onAppear {
            #if DEBUG
            seedSyntheticFixtureIfRequested()
            #endif
        }
        .lifeRouteReconcile { context in
            runtime.presentationScope = visibilityScope
            let previous = visibilityLeave
            visibilityLeave = context.leaveIdentity
            if (previous != nil && Array(previous!.prefix(2)) != Array(context.leaveIdentity.prefix(2))) || !context.alive {
                focusedField = nil
            }
            runtime.reconcilePresentation(context)
        }
        .onChange(of: focusedField) { field in
            if field != .sessionFacts {
                runtime.narrative = ABATerminologyNormalizer.normalize(runtime.narrative)
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
        .confirmationDialog(
            "Clear this Session Note draft?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Draft", role: .destructive) {
                runtime.clearDraft()
                focusedField = nil
                localNotice = "Draft cleared."
            }
            Button("Keep Draft", role: .cancel) {}
        } message: {
            Text("Session facts and editable prose for the selected client will be cleared. Other clients’ drafts will be kept.")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            #if DEBUG
            if SessionNoteFixtureGenerator.Mode.current != nil {
                Text("SYNTHETIC DEBUG FIXTURE · Model double; no FoundationModels quality evidence")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
            }
            #endif
            LifeRouteScreenHeader(
                title: "Session Note",
                subtitle: "Draft from supplied session facts and reviewed client context.",
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
            .ui01ScenicText()

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
        .ui01OpenSection()
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Session facts")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)

            Picker("Client", selection: $runtime.selectedClientCode) {
                Text("General / no client").tag("")
                if !runtime.selectedClientCode.isEmpty && selectedClient == nil {
                    Text("Unavailable client: \(runtime.selectedClientCode)").tag(runtime.selectedClientCode)
                }
                ForEach(clientState.clients) { client in
                    Text(client.code).tag(client.code)
                }
            }
            .pickerStyle(.menu)

            Text("Drafting for \(runtime.selectedClientCode.isEmpty ? "General / no client" : runtime.selectedClientCode)")
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("session-note-owner")
            Text("Each client keeps separate session facts and draft text. Switching clients restores their draft.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)

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
                TextEditor(text: $runtime.narrative)
                    .focused($focusedField, equals: .sessionFacts)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .frame(minHeight: 160)
                    .lifeRouteReadableTextSurface()
                    .accessibilityIdentifier("session-note-facts")

                if runtime.narrative.isEmpty {
                    Text("Type or paste what happened during the session…")
                        .foregroundStyle(palette.textSecondary.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }

            Text("\(runtime.narrative.count) / 5200 characters" + (runtime.narrative.count > 5_200 ? " · Over limit; complete input retained" : ""))
                .font(.caption)
                .foregroundStyle(runtime.narrative.count > 5_200 ? palette.accentSecondary : palette.textSecondary)
                .accessibilityIdentifier("session-note-input-count")

            Text("Only the current session facts supply content for this note.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
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

            if !runtime.draftIsEmpty {
                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("Clear draft", systemImage: "trash")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
                .accessibilityHint("Asks before removing the unfinished Session Note draft from this device.")
            }
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

            Text(runtime.completeness.message)
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
                .accessibilityIdentifier("session-note-completeness-status")

            TextEditor(text: $runtime.generatedNote)
                .focused($focusedField, equals: .generatedDraft)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .frame(minHeight: 230)
                .lifeRouteReadableTextSurface()
                .accessibilityIdentifier("session-note-draft")

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
        guard !runtime.selectedClientCode.isEmpty else { return nil }
        return clientState.client(code: runtime.selectedClientCode)
    }

    private var matchingScratchNotes: [QuickSessionNote] {
        let selectedCode = runtime.selectedClientCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = toolsState.notes.filter { note in
            if selectedCode.isEmpty { return note.clientCode == nil }
            return note.clientCode?.caseInsensitiveCompare(selectedCode) == .orderedSame
        }
        return Array(matches.reversed())
    }

    private var scratchNoteStatus: String {
        let count = matchingScratchNotes.count
        if count == 0 {
            return runtime.selectedClientCode.isEmpty ? "No General scratch notes yet" : "No scratch notes for \(runtime.selectedClientCode)"
        }
        return "\(count) matching note\(count == 1 ? "" : "s") · appends without overwriting"
    }

    private var hasEvidence: Bool {
        !runtime.narrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        case .blocked(let error): return error.statusTitle
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
            return "Apple Intelligence requested a smaller context. LifeRoute will retry once only if all session evidence fits; terminology context is omitted."
        case .repairing:
            return "The first draft needs a bounded second pass to meet the Master ABA format."
        case .completed(let outcome):
            return outcome.userFacingStatusMessage
        case .unavailable(let explanation), .failed(let explanation):
            return explanation
        case .blocked(let error):
            return error.localizedDescription
        case .timedOut:
            return "Apple Intelligence did not finish this step within 75 seconds. Your facts and prior draft were preserved."
        case .cancelled:
            return "The request stopped safely. Your facts and prior draft were preserved."
        }
    }

    private var statusIcon: String {
        switch runtime.state {
        case .completed(.generated), .completed(.repaired): return "doc.text.magnifyingglass"
        case .completed(.fallback), .completed(.rejected): return "exclamationmark.triangle.fill"
        case .unavailable: return "apple.intelligence"
        case .failed, .blocked, .timedOut: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle.fill"
        default: return "info.circle.fill"
        }
    }

    private var statusTint: Color {
        switch runtime.state {
        case .completed(.generated), .completed(.repaired): return palette.accentSecondary
        case .completed(.fallback), .completed(.rejected): return .orange
        case .unavailable, .failed, .blocked, .timedOut: return .orange
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
        case .completed(.fallback), .completed(.rejected), .unavailable, .failed, .blocked, .timedOut, .cancelled:
            return true
        default:
            return false
        }
    }

    private func appendToNarrative(_ value: String) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if runtime.narrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            runtime.narrative = clean
        } else {
            runtime.narrative += "\n\n\(clean)"
        }
    }

    private func startGeneration() {
        runtime.presentationScope = visibilityScope
        localNotice = nil
        focusedField = nil
        let normalizedFacts = ABATerminologyNormalizer.normalize(runtime.narrative)
        runtime.narrative = normalizedFacts
        runtime.start(
            narrative: normalizedFacts,
            writerCredential: writerCredential,
            client: selectedClient
        )
    }

    #if DEBUG
    private func seedSyntheticFixtureIfRequested() {
        guard !seededSyntheticFixture, let mode = SessionNoteFixtureGenerator.Mode.current else { return }
        seededSyntheticFixture = true
        runtime.narrative = "At home, the client practiced Following Directions with the RBT at 80% accuracy with a verbal prompt. The client returned the blue folder to the caregiver."
        if mode == .overLimit {
            runtime.narrative = String(repeating: "The client practiced with the RBT. ", count: 160) +
                "The client returned the blue folder to the caregiver."
        }
        runtime.generatedNote = "Previous synthetic draft: the client practiced with the RBT. Keep this edited draft if the next attempt fails or is cancelled."
        if ProcessInfo.processInfo.arguments.contains("-LifeRouteSessionNoteAutoStart") {
            startGeneration()
        }
    }
    #endif

    private func finishEditing() {
        runtime.narrative = ABATerminologyNormalizer.normalize(runtime.narrative)
        runtime.generatedNote = ABATerminologyNormalizer.normalize(runtime.generatedNote)
        focusedField = nil
    }
}

#if DEBUG
struct SessionNoteReadabilityFixtureView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @StateObject private var fixtureClients = ClientProfileCore(clients: [])
    @StateObject private var fixtureTools = SessionToolsCore()
    @StateObject private var fixtureRuntime = AISessionNoteRuntimeModel(
        generator: SessionNoteGeneratorFactory.make(),
        draftStore: nil
    )

    @State private var sessionFacts = """
    The RBT met with the client in the client's home while the LBS and family members were present. The session began with outdoor pairing and functional communication targets before the client transitioned indoors for instructional activities and waiting practice. The client later returned outdoors for play, transitioned inside for cooperative play and another instructional period, and engaged in elopement during the later work period.
    """
    @State private var generatedDraft = """
    The RBT met with the client in the client's home. Present during the session were the RBT, LBS, grandmother, mother, father, brother, and the brother's BHT. The session began with pairing outdoors while the RBT targeted FCT through full-sentence manding and requests for additional time. The RBT then transitioned the client indoors for instructional activities, targeted waiting, and transitioned the client back outdoors for additional play.

    The LBS and RBT later transitioned the client indoors for additional instructional activities, followed by cooperative play and another instructional period. During the later work period, the client engaged in elopement and required multiple redirections to return to and attend to the task. Following re-engagement, the client earned preferred outdoor time. The LBS also instructed the RBT regarding skill-acquisition targets, including newly implemented programs.

    The client participated in the supplied session activities. The RBT will continue implementing the established treatment plan during future sessions.
    """

    var body: some View {
        if SessionNoteFixtureGenerator.Mode.current != nil {
            AISessionNoteGeneratorView(
                clientState: fixtureClients,
                toolsState: fixtureTools,
                runtime: fixtureRuntime
            )
        } else {
            readabilityContent
        }
    }

    private var readabilityContent: some View {
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

struct AISessionPlanBuilderView: View {
    @Environment(\.lifeRoutePresentation) private var visibilityScope

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
                .ui01ScenicText()
        }
        .ui01OpenSection()
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
        .ui01ReadingPlane()
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
                .lifeRouteReadableTextSurface()
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
                .lifeRouteReadableTextSurface()
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
        let feedbackTicket = visibilityScope?.feedbackTicket()
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
            if feedbackTicket?.isEligible == true { LifeRouteHaptics.success() }
        } catch {
            message = error.localizedDescription
        }
    }
}
