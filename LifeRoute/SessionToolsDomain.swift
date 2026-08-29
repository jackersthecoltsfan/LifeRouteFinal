import Foundation
import Combine
import AVFoundation

enum SessionToolRoute: Hashable {
    case visualTimer
    case quickNotes
    case firstThen
    case sessionPlan
}

struct QuickSessionNote: Identifiable, Hashable {
    let id: UUID
    let clientCode: String?
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), clientCode: String?, text: String, createdAt: Date = Date()) {
        self.id = id
        self.clientCode = clientCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
    }
}

struct SessionPlanSnapshot: Hashable {
    let clientCode: String?
    let durationMinutes: Int
    let targets: [String]
    let reinforcers: [String]
    let createdAt: Date
}

enum SessionToolsCoreError: LocalizedError {
    case emptyNote
    case noTargets

    var errorDescription: String? {
        switch self {
        case .emptyNote:
            return "Enter a note before saving."
        case .noTargets:
            return "Add at least one supervisor-approved target or priority."
        }
    }
}

@MainActor
private final class VisualTimerToneEngine {
    private static let sampleRate = 44_100.0
    private static let pulseDuration = 0.14

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(
        standardFormatWithSampleRate: VisualTimerToneEngine.sampleRate,
        channels: 1
    )!
    private var isPrepared = false
    private var completionStopTask: Task<Void, Never>?

    func playPulse(frequency: Double, gain: Float) {
        guard prepareIfNeeded(), let buffer = pulseBuffer(frequency: frequency) else { return }
        player.volume = max(0, min(1, gain))
        player.scheduleBuffer(buffer, at: nil, options: [])
        if !player.isPlaying { player.play() }
    }

    func playCompletion(gain: Float) {
        guard prepareIfNeeded(), let buffer = completionBuffer() else { return }
        player.volume = max(0, min(1, gain))
        player.scheduleBuffer(buffer, at: nil, options: [])
        if !player.isPlaying { player.play() }

        completionStopTask?.cancel()
        completionStopTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 650_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func stop() {
        completionStopTask?.cancel()
        completionStopTask = nil
        player.stop()
        engine.pause()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func prepareIfNeeded() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            if !isPrepared {
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
                player.volume = 1
                isPrepared = true
            }
            if !engine.isRunning { try engine.start() }
            return engine.isRunning
        } catch {
            return false
        }
    }

    private func pulseBuffer(frequency: Double) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(Self.sampleRate * Self.pulseDuration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / Self.sampleRate
            let attack = min(1, t / 0.012)
            let decay = exp(-18 * t)
            let releaseStart = Self.pulseDuration * 0.62
            let releaseProgress = max(0, (t - releaseStart) / (Self.pulseDuration - releaseStart))
            // v0.6.3 cosine release reaches silence smoothly so the buffer cannot end on a click.
            let release = releaseProgress <= 0 ? 1 : 0.5 * (1 + cos(Double.pi * min(1, releaseProgress)))
            let fundamental = sin(2 * Double.pi * frequency * t)
            let softSecond = 0.12 * sin(2 * Double.pi * frequency * 2.0 * t)
            let softDetune = 0.025 * sin(2 * Double.pi * frequency * 1.004 * t)
            samples[frame] = Float((fundamental + softSecond + softDetune) * attack * decay * release * 0.46)
        }
        return buffer
    }

    private func completionBuffer() -> AVAudioPCMBuffer? {
        let totalDuration = 0.52
        let frameCount = AVAudioFrameCount(Self.sampleRate * totalDuration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        let notes: [(start: Double, frequency: Double)] = [
            (0.00, 864),
            (0.14, 1_296),
            (0.29, 1_728),
        ]

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / Self.sampleRate
            var value = 0.0
            for note in notes {
                let localTime = t - note.start
                guard localTime >= 0, localTime <= 0.19 else { continue }
                let attack = min(1, localTime / 0.012)
                let decay = exp(-16 * localTime)
                let releaseStart = 0.12
                let releaseProgress = max(0, (localTime - releaseStart) / (0.19 - releaseStart))
                let release = releaseProgress <= 0 ? 1 : 0.5 * (1 + cos(Double.pi * min(1, releaseProgress)))
                let fundamental = sin(2 * Double.pi * note.frequency * localTime)
                let softSecond = 0.10 * sin(2 * Double.pi * note.frequency * 2.0 * localTime)
                value += (fundamental + softSecond) * attack * decay * release * 0.68
            }
            samples[frame] = Float(max(-0.92, min(0.92, value)))
        }
        return buffer
    }
}

@MainActor
final class VisualTimerCore: ObservableObject {
    private static let startFrequency = 432.0
    private static let endFrequency = 1_728.0
    private static let startGainForFiveDecibelCrescendo = pow(10.0, -5.0 / 20.0)

    @Published private(set) var durationSeconds: TimeInterval = 5 * 60
    @Published private(set) var deadline: Date?
    @Published private(set) var pausedRemainingSeconds: TimeInterval = 5 * 60
    @Published private(set) var volume: Double = 0.86

    private let toneEngine = VisualTimerToneEngine()
    private var audioTask: Task<Void, Never>?

    var isRunning: Bool { deadline != nil }

    func start(minutes: Int, now: Date = Date()) {
        let seconds = TimeInterval(max(1, min(180, minutes)) * 60)
        durationSeconds = seconds
        pausedRemainingSeconds = seconds
        deadline = now.addingTimeInterval(seconds)
        startAudioLoop()
    }

    func remainingSeconds(at now: Date = Date()) -> TimeInterval {
        if let deadline {
            return max(0, deadline.timeIntervalSince(now))
        }
        return max(0, pausedRemainingSeconds)
    }

    func progress(at now: Date = Date()) -> Double {
        guard durationSeconds > 0 else { return 0 }
        return min(1, max(0, remainingSeconds(at: now) / durationSeconds))
    }

    func isFinished(at now: Date = Date()) -> Bool {
        remainingSeconds(at: now) <= 0
    }

    func pause(now: Date = Date()) {
        pausedRemainingSeconds = remainingSeconds(at: now)
        deadline = nil
        stopAudioLoop()
    }

    func resume(now: Date = Date()) {
        guard pausedRemainingSeconds > 0 else { return }
        deadline = now.addingTimeInterval(pausedRemainingSeconds)
        startAudioLoop()
    }

    func addMinute(now: Date = Date()) {
        durationSeconds += 60
        if let deadline {
            self.deadline = deadline.addingTimeInterval(60)
        } else {
            pausedRemainingSeconds = remainingSeconds(at: now) + 60
        }
    }

    func setVolume(_ value: Double) {
        volume = min(1, max(0, value))
    }

    func pulsesPerSecond(forRemaining remaining: TimeInterval) -> Double {
        if remaining <= 5 { return 5 }
        if remaining <= 10 { return 4 }
        if remaining <= 30 { return 3 }
        return 2
    }

    func reset() {
        deadline = nil
        pausedRemainingSeconds = durationSeconds
        stopAudioLoop()
    }

    private func startAudioLoop() {
        audioTask?.cancel()
        toneEngine.stop()
        audioTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                guard let deadline = self.deadline else { return }
                let remaining = max(0, deadline.timeIntervalSinceNow)

                if remaining <= 0 {
                    self.pausedRemainingSeconds = 0
                    self.deadline = nil
                    self.audioTask = nil
                    self.toneEngine.playCompletion(gain: Float(self.volume))
                    return
                }

                self.toneEngine.playPulse(
                    frequency: self.frequency(forRemaining: remaining),
                    gain: Float(self.signalGain(forRemaining: remaining))
                )
                let interval = 1.0 / self.pulsesPerSecond(forRemaining: remaining)
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    return
                }
            }
        }
    }

    private func stopAudioLoop() {
        audioTask?.cancel()
        audioTask = nil
        toneEngine.stop()
    }

    private func frequency(forRemaining remaining: TimeInterval) -> Double {
        guard durationSeconds > 0 else { return Self.startFrequency }
        let remainingFraction = min(1, max(0, remaining / durationSeconds))
        let elapsedFraction = 1 - remainingFraction
        return Self.startFrequency * pow(Self.endFrequency / Self.startFrequency, elapsedFraction)
    }

    private func signalGain(forRemaining remaining: TimeInterval) -> Double {
        guard durationSeconds > 0 else { return volume * Self.startGainForFiveDecibelCrescendo }
        let elapsed = min(1, max(0, 1 - remaining / durationSeconds))
        let crescendo = Self.startGainForFiveDecibelCrescendo + (1 - Self.startGainForFiveDecibelCrescendo) * elapsed
        return min(1, max(0, volume * crescendo))
    }
}

@MainActor
final class SessionToolsCore: ObservableObject {
    @Published private(set) var notes: [QuickSessionNote] = []
    @Published private(set) var lastPlan: SessionPlanSnapshot?
    let timer = VisualTimerCore()

    func addNote(text: String, clientCode: String?) throws {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw SessionToolsCoreError.emptyNote }
        notes.append(QuickSessionNote(clientCode: normalizedClientCode(clientCode), text: clean))
    }

    func removeNote(id: UUID) {
        notes.removeAll { $0.id == id }
    }

    @discardableResult
    func buildPlan(
        clientCode: String?,
        durationMinutes: Int,
        targetsText: String,
        reinforcersText: String
    ) throws -> SessionPlanSnapshot {
        let targets = Self.list(from: targetsText)
        guard !targets.isEmpty else { throw SessionToolsCoreError.noTargets }
        let snapshot = SessionPlanSnapshot(
            clientCode: normalizedClientCode(clientCode),
            durationMinutes: max(15, min(480, durationMinutes)),
            targets: targets,
            reinforcers: Self.list(from: reinforcersText),
            createdAt: Date()
        )
        lastPlan = snapshot
        return snapshot
    }

    static func list(from value: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for part in value.split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == ";" }) {
            let item = String(part).trimmingCharacters(in: .whitespacesAndNewlines)
            let key = item.lowercased()
            guard !item.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(item)
            if result.count == 60 { break }
        }
        return result
    }

    private func normalizedClientCode(_ value: String?) -> String? {
        let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return clean.isEmpty ? nil : clean
    }
}

// MARK: - Checkpoint 03F / 04A: client-specific persistent visual supports

struct ClientVisualIcon: Identifiable, Hashable {
    let id: UUID
    let clientID: UUID
    var clientCode: String
    var label: String
    let imageData: Data?
    let createdAt: Date

    init(id: UUID = UUID(), clientID: UUID, clientCode: String, label: String, imageData: Data? = nil, createdAt: Date = Date()) {
        self.id = id
        self.clientID = clientID
        self.clientCode = clientCode
        self.label = label
        self.imageData = imageData
        self.createdAt = createdAt
    }
}

struct ClientChoiceBoard: Identifiable, Hashable {
    let id: UUID
    let clientID: UUID
    var clientCode: String
    var title: String
    var iconIDs: [UUID]
    var columns: Int
    let createdAt: Date

    init(id: UUID = UUID(), clientID: UUID, clientCode: String, title: String, iconIDs: [UUID], columns: Int, createdAt: Date = Date()) {
        self.id = id
        self.clientID = clientID
        self.clientCode = clientCode
        self.title = title
        self.iconIDs = iconIDs
        self.columns = columns
        self.createdAt = createdAt
    }
}

struct ClientVisualScheduleStep: Identifiable, Hashable {
    let id: UUID
    var label: String
    var iconID: UUID?

    init(id: UUID = UUID(), label: String, iconID: UUID? = nil) {
        self.id = id
        self.label = label
        self.iconID = iconID
    }
}

struct ClientVisualSchedule: Identifiable, Hashable {
    let id: UUID
    let clientID: UUID
    var clientCode: String
    var title: String
    var steps: [ClientVisualScheduleStep]
    let createdAt: Date

    init(id: UUID = UUID(), clientID: UUID, clientCode: String, title: String, steps: [ClientVisualScheduleStep], createdAt: Date = Date()) {
        self.id = id
        self.clientID = clientID
        self.clientCode = clientCode
        self.title = title
        self.steps = steps
        self.createdAt = createdAt
    }
}

enum ClientVisualSupportError: LocalizedError {
    case missingClient
    case missingLabel
    case missingTitle
    case noIcons
    case noSteps
    case crossClientReference

    var errorDescription: String? {
        switch self {
        case .missingClient:
            return "Choose a client or the General visual library before creating a visual support."
        case .missingLabel:
            return "Add a label for the visual icon."
        case .missingTitle:
            return "Add a title before saving this visual support."
        case .noIcons:
            return "Choose at least one icon from this visual library."
        case .noSteps:
            return "Add at least one step before saving the visual schedule."
        case .crossClientReference:
            return "A visual support can only use icons saved to the same visual library."
        }
    }
}

@MainActor
final class ClientVisualSupportCore: ObservableObject {
    static let generalClientCode = "GENERAL"
    static let generalDisplayName = "General / no client"
    private static let generalClientID = UUID(uuidString: "7F164E34-BD4A-4A30-AFDB-70A4AE8C7D3E")!

    @Published private(set) var icons: [ClientVisualIcon]
    @Published private(set) var choiceBoards: [ClientChoiceBoard]
    @Published private(set) var schedules: [ClientVisualSchedule]

    private var iconsByClientID: [UUID: [ClientVisualIcon]] = [:]
    private var choiceBoardsByClientID: [UUID: [ClientChoiceBoard]] = [:]
    private var schedulesByClientID: [UUID: [ClientVisualSchedule]] = [:]
    private var iconsByID: [UUID: ClientVisualIcon] = [:]
    private var iconIDsByClientID: [UUID: Set<UUID>] = [:]

    init(restoredState: RestoredClientVisualSupportState? = nil) {
        let restored = restoredState ?? LifeRoutePersistenceStore.shared.loadClientVisualSupports()
        self.icons = restored.icons
        self.choiceBoards = restored.choiceBoards
        self.schedules = restored.schedules
        rebuildVisualIndexes()
    }

    func icons(for clientCode: String) -> [ClientVisualIcon] {
        guard let owner = visualOwner(for: clientCode) else { return [] }
        return iconsByClientID[owner.id] ?? []
    }

    func choiceBoards(for clientCode: String) -> [ClientChoiceBoard] {
        guard let owner = visualOwner(for: clientCode) else { return [] }
        return choiceBoardsByClientID[owner.id] ?? []
    }

    func schedules(for clientCode: String) -> [ClientVisualSchedule] {
        guard let owner = visualOwner(for: clientCode) else { return [] }
        return schedulesByClientID[owner.id] ?? []
    }

    @discardableResult
    func addIcon(clientCode: String, label: String, imageData: Data?) throws -> ClientVisualIcon {
        guard let owner = visualOwner(for: clientCode) else {
            throw ClientVisualSupportError.missingClient
        }
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanLabel.isEmpty else { throw ClientVisualSupportError.missingLabel }
        let icon = ClientVisualIcon(clientID: owner.id, clientCode: owner.code, label: cleanLabel, imageData: imageData)
        icons.append(icon)
        rebuildVisualIndexes()
        persistVisualSupports()
        return icon
    }

    func removeIcon(id: UUID) {
        icons.removeAll { $0.id == id }
        choiceBoards = choiceBoards.compactMap { board in
            var updated = board
            updated.iconIDs.removeAll { $0 == id }
            return updated.iconIDs.isEmpty ? nil : updated
        }
        schedules = schedules.map { schedule in
            var updated = schedule
            updated.steps = updated.steps.map { step in
                var item = step
                if item.iconID == id { item.iconID = nil }
                return item
            }
            return updated
        }
        rebuildVisualIndexes()
        persistVisualSupports()
    }

    @discardableResult
    func saveChoiceBoard(clientCode: String, title: String, iconIDs: [UUID], columns: Int) throws -> ClientChoiceBoard {
        guard let owner = visualOwner(for: clientCode) else {
            throw ClientVisualSupportError.missingClient
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw ClientVisualSupportError.missingTitle }

        let allowed = iconIDsByClientID[owner.id] ?? []
        var seen = Set<UUID>()
        let requested = iconIDs.filter { seen.insert($0).inserted }
        guard !requested.isEmpty else { throw ClientVisualSupportError.noIcons }
        guard requested.allSatisfy(allowed.contains) else { throw ClientVisualSupportError.crossClientReference }

        let board = ClientChoiceBoard(
            clientID: owner.id,
            clientCode: owner.code,
            title: cleanTitle,
            iconIDs: Array(requested.prefix(9)),
            columns: columns == 3 ? 3 : 2
        )
        choiceBoards.append(board)
        rebuildVisualIndexes()
        persistVisualSupports()
        return board
    }

    func removeChoiceBoard(id: UUID) {
        choiceBoards.removeAll { $0.id == id }
        rebuildVisualIndexes()
        persistVisualSupports()
    }

    @discardableResult
    func saveSchedule(clientCode: String, title: String, steps: [ClientVisualScheduleStep]) throws -> ClientVisualSchedule {
        guard let owner = visualOwner(for: clientCode) else {
            throw ClientVisualSupportError.missingClient
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw ClientVisualSupportError.missingTitle }
        guard !steps.isEmpty else { throw ClientVisualSupportError.noSteps }

        let allowed = iconIDsByClientID[owner.id] ?? []
        let cleanedSteps = steps.compactMap { step -> ClientVisualScheduleStep? in
            let label = step.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { return nil }
            if let iconID = step.iconID, !allowed.contains(iconID) { return nil }
            return ClientVisualScheduleStep(id: step.id, label: label, iconID: step.iconID)
        }
        guard cleanedSteps.count == steps.count else { throw ClientVisualSupportError.crossClientReference }

        let schedule = ClientVisualSchedule(
            clientID: owner.id,
            clientCode: owner.code,
            title: cleanTitle,
            steps: cleanedSteps
        )
        schedules.append(schedule)
        rebuildVisualIndexes()
        persistVisualSupports()
        return schedule
    }

    func removeSchedule(id: UUID) {
        schedules.removeAll { $0.id == id }
        rebuildVisualIndexes()
        persistVisualSupports()
    }

    func icon(id: UUID, for clientCode: String) -> ClientVisualIcon? {
        guard let owner = visualOwner(for: clientCode) else { return nil }
        guard let icon = iconsByID[id], icon.clientID == owner.id else { return nil }
        return icon
    }

    func retainClients(_ clients: [LifeRouteClientProfile]) {
        let clientIDs = Set(clients.map(\.id)).union([Self.generalClientID])
        var codeByID = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, normalizedRequiredClientCode($0.code)) })
        codeByID[Self.generalClientID] = Self.generalClientCode

        var changed = false
        let updatedIcons = icons.compactMap { icon -> ClientVisualIcon? in
            guard clientIDs.contains(icon.clientID), let currentCode = codeByID[icon.clientID] else {
                changed = true
                return nil
            }
            var updated = icon
            if updated.clientCode != currentCode { changed = true }
            updated.clientCode = currentCode
            return updated
        }
        let survivingIconIDs = Set(updatedIcons.map(\.id))
        let updatedBoards = choiceBoards.compactMap { board -> ClientChoiceBoard? in
            guard clientIDs.contains(board.clientID), let currentCode = codeByID[board.clientID] else {
                changed = true
                return nil
            }
            var updated = board
            if updated.clientCode != currentCode { changed = true }
            updated.clientCode = currentCode
            let originalIconIDs = updated.iconIDs
            updated.iconIDs.removeAll { !survivingIconIDs.contains($0) }
            if updated.iconIDs != originalIconIDs { changed = true }
            if updated.iconIDs.isEmpty {
                changed = true
                return nil
            }
            return updated
        }
        let updatedSchedules = schedules.compactMap { schedule -> ClientVisualSchedule? in
            guard clientIDs.contains(schedule.clientID), let currentCode = codeByID[schedule.clientID] else {
                changed = true
                return nil
            }
            var updated = schedule
            if updated.clientCode != currentCode { changed = true }
            updated.clientCode = currentCode
            updated.steps = updated.steps.map { step in
                var item = step
                if let iconID = item.iconID, !survivingIconIDs.contains(iconID) {
                    item.iconID = nil
                    changed = true
                }
                return item
            }
            return updated
        }
        guard changed else { return }

        icons = updatedIcons
        choiceBoards = updatedBoards
        schedules = updatedSchedules
        rebuildVisualIndexes()
        persistVisualSupports()
    }

    private func rebuildVisualIndexes() {
        iconsByClientID = Dictionary(grouping: icons, by: \.clientID).mapValues { clientIcons in
            clientIcons.sorted { lhs, rhs in
                lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
        }
        choiceBoardsByClientID = Dictionary(grouping: choiceBoards, by: \.clientID).mapValues { boards in
            boards.sorted { $0.createdAt > $1.createdAt }
        }
        schedulesByClientID = Dictionary(grouping: schedules, by: \.clientID).mapValues { clientSchedules in
            clientSchedules.sorted { $0.createdAt > $1.createdAt }
        }

        var iconLookup: [UUID: ClientVisualIcon] = [:]
        for icon in icons { iconLookup[icon.id] = icon }
        iconsByID = iconLookup
        iconIDsByClientID = iconsByClientID.mapValues { Set($0.map(\.id)) }
    }

    private func persistVisualSupports() {
        LifeRoutePersistenceStore.shared.saveClientVisualSupports(
            icons: icons,
            choiceBoards: choiceBoards,
            schedules: schedules
        )
    }

    private func visualOwner(for value: String) -> (id: UUID, code: String)? {
        let code = normalizedRequiredClientCode(value)
        if code.isEmpty || code.caseInsensitiveCompare(Self.generalClientCode) == .orderedSame {
            return (Self.generalClientID, Self.generalClientCode)
        }
        guard let clientID = LifeRoutePersistenceStore.shared.clientID(forCode: code) else { return nil }
        return (clientID, code)
    }

    private func normalizedRequiredClientCode(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ABAVisualSupportConceptInterpreter {
    static func describe(label: String, visualDescription: String, hasReference: Bool) -> String {
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = visualDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = "\(cleanLabel) \(cleanDescription)".lowercased()

        let functionalConcept: String
        switch true {
        case lowered.contains("water play"):
            functionalConcept = "A child-friendly water play cue showing hands in a small water table or basin with simple water toys."
        case lowered.contains("outside"), lowered.contains("outdoor"):
            functionalConcept = "A clear outside cue showing a doorway, yard, or playground setting that signals going outdoors."
        case lowered.contains("break"):
            functionalConcept = "A quiet break cue showing a calm resting spot or a child sitting peacefully for a short pause."
        case lowered.contains("help"):
            functionalConcept = "A clear help request cue showing a child asking an adult for assistance."
        case lowered.contains("more"):
            functionalConcept = "A simple more request cue showing a child requesting additional access, items, or activity."
        case lowered.contains("bathroom"), lowered.contains("toilet"), lowered.contains("restroom"):
            functionalConcept = "A bathroom cue showing a clearly recognizable toilet or bathroom doorway."
        case lowered.contains("eat"), lowered.contains("food"), lowered.contains("snack"):
            functionalConcept = "A food or eating cue showing a child with simple meal or snack items."
        case lowered.contains("sleep"), lowered.contains("bed"), lowered.contains("nap"):
            functionalConcept = "A sleep cue showing a bed or calm resting environment that clearly signals bedtime or nap time."
        default:
            functionalConcept = cleanDescription.isEmpty
                ? "A simple child-readable ABA visual support for \(cleanLabel)."
                : cleanDescription
        }

        let referenceNote = hasReference
            ? "Preserve the identifying features of the supplied reference image when they help the child connect the visual support to the real item, place, or activity."
            : "Create the most functionally recognizable version of the concept without decorative distractions."

        return "\(functionalConcept) \(referenceNote)"
    }
}
