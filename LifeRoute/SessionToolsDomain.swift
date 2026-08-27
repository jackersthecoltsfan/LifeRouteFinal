import Foundation
import Combine

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
final class VisualTimerCore: ObservableObject {
    @Published private(set) var durationSeconds: TimeInterval = 5 * 60
    @Published private(set) var deadline: Date?
    @Published private(set) var pausedRemainingSeconds: TimeInterval = 5 * 60

    var isRunning: Bool { deadline != nil }

    func start(minutes: Int, now: Date = Date()) {
        let seconds = TimeInterval(max(1, min(180, minutes)) * 60)
        durationSeconds = seconds
        pausedRemainingSeconds = seconds
        deadline = now.addingTimeInterval(seconds)
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
    }

    func resume(now: Date = Date()) {
        guard pausedRemainingSeconds > 0 else { return }
        deadline = now.addingTimeInterval(pausedRemainingSeconds)
    }

    func addMinute(now: Date = Date()) {
        durationSeconds += 60
        if let deadline {
            self.deadline = deadline.addingTimeInterval(60)
        } else {
            pausedRemainingSeconds = remainingSeconds(at: now) + 60
        }
    }

    func reset() {
        deadline = nil
        pausedRemainingSeconds = durationSeconds
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
            return "Choose a client before creating a visual support."
        case .missingLabel:
            return "Add a label for the visual icon."
        case .missingTitle:
            return "Add a title before saving this visual support."
        case .noIcons:
            return "Choose at least one icon from this client’s visual library."
        case .noSteps:
            return "Add at least one step before saving the visual schedule."
        case .crossClientReference:
            return "A visual support can only use icons saved to the same client."
        }
    }
}

@MainActor
final class ClientVisualSupportCore: ObservableObject {
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
        guard let clientID = LifeRoutePersistenceStore.shared.clientID(forCode: normalizedRequiredClientCode(clientCode)) else { return [] }
        return iconsByClientID[clientID] ?? []
    }

    func choiceBoards(for clientCode: String) -> [ClientChoiceBoard] {
        guard let clientID = LifeRoutePersistenceStore.shared.clientID(forCode: normalizedRequiredClientCode(clientCode)) else { return [] }
        return choiceBoardsByClientID[clientID] ?? []
    }

    func schedules(for clientCode: String) -> [ClientVisualSchedule] {
        guard let clientID = LifeRoutePersistenceStore.shared.clientID(forCode: normalizedRequiredClientCode(clientCode)) else { return [] }
        return schedulesByClientID[clientID] ?? []
    }

    @discardableResult
    func addIcon(clientCode: String, label: String, imageData: Data?) throws -> ClientVisualIcon {
        let code = normalizedRequiredClientCode(clientCode)
        guard !code.isEmpty,
              let clientID = LifeRoutePersistenceStore.shared.clientID(forCode: code) else {
            throw ClientVisualSupportError.missingClient
        }
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanLabel.isEmpty else { throw ClientVisualSupportError.missingLabel }
        let icon = ClientVisualIcon(clientID: clientID, clientCode: code, label: cleanLabel, imageData: imageData)
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
        let code = normalizedRequiredClientCode(clientCode)
        guard !code.isEmpty,
              let clientID = LifeRoutePersistenceStore.shared.clientID(forCode: code) else {
            throw ClientVisualSupportError.missingClient
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw ClientVisualSupportError.missingTitle }

        let allowed = iconIDsByClientID[clientID] ?? []
        var seen = Set<UUID>()
        let requested = iconIDs.filter { seen.insert($0).inserted }
        guard !requested.isEmpty else { throw ClientVisualSupportError.noIcons }
        guard requested.allSatisfy(allowed.contains) else { throw ClientVisualSupportError.crossClientReference }

        let board = ClientChoiceBoard(
            clientID: clientID,
            clientCode: code,
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
        let code = normalizedRequiredClientCode(clientCode)
        guard !code.isEmpty,
              let clientID = LifeRoutePersistenceStore.shared.clientID(forCode: code) else {
            throw ClientVisualSupportError.missingClient
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw ClientVisualSupportError.missingTitle }
        guard !steps.isEmpty else { throw ClientVisualSupportError.noSteps }

        let allowed = iconIDsByClientID[clientID] ?? []
        let cleanedSteps = steps.compactMap { step -> ClientVisualScheduleStep? in
            let label = step.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { return nil }
            if let iconID = step.iconID, !allowed.contains(iconID) { return nil }
            return ClientVisualScheduleStep(id: step.id, label: label, iconID: step.iconID)
        }
        guard cleanedSteps.count == steps.count else { throw ClientVisualSupportError.crossClientReference }

        let schedule = ClientVisualSchedule(
            clientID: clientID,
            clientCode: code,
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
        guard let clientID = LifeRoutePersistenceStore.shared.clientID(forCode: normalizedRequiredClientCode(clientCode)) else { return nil }
        guard let icon = iconsByID[id], icon.clientID == clientID else { return nil }
        return icon
    }

    func retainClients(_ clients: [LifeRouteClientProfile]) {
        let clientIDs = Set(clients.map(\.id))
        let codeByID = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, normalizedRequiredClientCode($0.code)) })

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

    private func normalizedRequiredClientCode(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
