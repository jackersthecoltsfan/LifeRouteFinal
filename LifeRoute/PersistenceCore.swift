import Foundation

struct RestoredClientVisualSupportState {
    var icons: [ClientVisualIcon]
    var choiceBoards: [ClientChoiceBoard]
    var schedules: [ClientVisualSchedule]

    static let empty = RestoredClientVisualSupportState(icons: [], choiceBoards: [], schedules: [])
}

@MainActor
final class LifeRoutePersistenceStore {
    static let shared = LifeRoutePersistenceStore()

    private struct PersistedVisualIcon: Codable {
        var id: UUID
        var clientCode: String
        var label: String
        var imageData: Data?
        var createdAt: Date
    }

    private struct PersistedChoiceBoard: Codable {
        var id: UUID
        var clientCode: String
        var title: String
        var iconIDs: [UUID]
        var columns: Int
        var createdAt: Date
    }

    private struct PersistedScheduleStep: Codable {
        var id: UUID
        var label: String
        var iconID: UUID?
    }

    private struct PersistedVisualSchedule: Codable {
        var id: UUID
        var clientCode: String
        var title: String
        var steps: [PersistedScheduleStep]
        var createdAt: Date
    }

    private struct NativeState: Codable {
        var schemaVersion: Int
        var clients: [LifeRouteClientProfile]
        var visualIcons: [PersistedVisualIcon]
        var choiceBoards: [PersistedChoiceBoard]
        var visualSchedules: [PersistedVisualSchedule]

        init(
            schemaVersion: Int = 1,
            clients: [LifeRouteClientProfile] = [],
            visualIcons: [PersistedVisualIcon] = [],
            choiceBoards: [PersistedChoiceBoard] = [],
            visualSchedules: [PersistedVisualSchedule] = []
        ) {
            self.schemaVersion = schemaVersion
            self.clients = clients
            self.visualIcons = visualIcons
            self.choiceBoards = choiceBoards
            self.visualSchedules = visualSchedules
        }

        private enum CodingKeys: String, CodingKey {
            case schemaVersion
            case clients
            case visualIcons
            case choiceBoards
            case visualSchedules
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
            clients = try container.decodeIfPresent([LifeRouteClientProfile].self, forKey: .clients) ?? []
            visualIcons = try container.decodeIfPresent([PersistedVisualIcon].self, forKey: .visualIcons) ?? []
            choiceBoards = try container.decodeIfPresent([PersistedChoiceBoard].self, forKey: .choiceBoards) ?? []
            visualSchedules = try container.decodeIfPresent([PersistedVisualSchedule].self, forKey: .visualSchedules) ?? []
        }
    }

    private let fileManager: FileManager
    private let fileURL: URL?
    private var state: NativeState
    private(set) var recoveryMessage: String?

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.state = NativeState()

        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            self.fileURL = nil
            self.recoveryMessage = "Application Support is unavailable; native data will remain in memory."
            return
        }

        let directory = applicationSupport
            .appendingPathComponent("LifeRoute", isDirectory: true)
            .appendingPathComponent("NativeState", isDirectory: true)
        let url = directory.appendingPathComponent("native-state-v1.json", isDirectory: false)
        self.fileURL = url

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: directory.path
            )

            guard fileManager.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(NativeState.self, from: data)
            self.state = Self.sanitized(decoded)
        } catch {
            let backupURL = directory.appendingPathComponent(
                "native-state-v1-corrupt-\(Int(Date().timeIntervalSince1970)).json",
                isDirectory: false
            )
            if fileManager.fileExists(atPath: url.path) {
                try? fileManager.moveItem(at: url, to: backupURL)
            }
            self.state = NativeState()
            self.recoveryMessage = "LifeRoute preserved an unreadable native state file and started with safe defaults."
        }
    }

    func loadClients() -> [LifeRouteClientProfile] {
        state.clients
    }

    func saveClients(_ clients: [LifeRouteClientProfile]) {
        var next = state
        next.clients = Self.sanitizedClients(clients)

        let validCodes = Set(next.clients.map { $0.code.lowercased() })
        next.visualIcons.removeAll { !validCodes.contains($0.clientCode.lowercased()) }
        next.choiceBoards.removeAll { !validCodes.contains($0.clientCode.lowercased()) }
        next.visualSchedules.removeAll { !validCodes.contains($0.clientCode.lowercased()) }

        state = Self.sanitized(next)
        persist()
    }

    func loadClientVisualSupports() -> RestoredClientVisualSupportState {
        state = Self.sanitized(state)

        let icons = state.visualIcons.map {
            ClientVisualIcon(
                id: $0.id,
                clientCode: $0.clientCode,
                label: $0.label,
                imageData: $0.imageData,
                createdAt: $0.createdAt
            )
        }
        let boards = state.choiceBoards.map {
            ClientChoiceBoard(
                id: $0.id,
                clientCode: $0.clientCode,
                title: $0.title,
                iconIDs: $0.iconIDs,
                columns: $0.columns,
                createdAt: $0.createdAt
            )
        }
        let schedules = state.visualSchedules.map {
            ClientVisualSchedule(
                id: $0.id,
                clientCode: $0.clientCode,
                title: $0.title,
                steps: $0.steps.map { ClientVisualScheduleStep(id: $0.id, label: $0.label, iconID: $0.iconID) },
                createdAt: $0.createdAt
            )
        }
        return RestoredClientVisualSupportState(icons: icons, choiceBoards: boards, schedules: schedules)
    }

    func saveClientVisualSupports(
        icons: [ClientVisualIcon],
        choiceBoards: [ClientChoiceBoard],
        schedules: [ClientVisualSchedule]
    ) {
        var next = state
        next.visualIcons = icons.map {
            PersistedVisualIcon(
                id: $0.id,
                clientCode: $0.clientCode,
                label: $0.label,
                imageData: $0.imageData,
                createdAt: $0.createdAt
            )
        }
        next.choiceBoards = choiceBoards.map {
            PersistedChoiceBoard(
                id: $0.id,
                clientCode: $0.clientCode,
                title: $0.title,
                iconIDs: $0.iconIDs,
                columns: $0.columns,
                createdAt: $0.createdAt
            )
        }
        next.visualSchedules = schedules.map {
            PersistedVisualSchedule(
                id: $0.id,
                clientCode: $0.clientCode,
                title: $0.title,
                steps: $0.steps.map { PersistedScheduleStep(id: $0.id, label: $0.label, iconID: $0.iconID) },
                createdAt: $0.createdAt
            )
        }
        state = Self.sanitized(next)
        persist()
    }

    private func persist() {
        guard let fileURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: [.atomic])
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
            recoveryMessage = nil
        } catch {
            recoveryMessage = "LifeRoute could not save native state: \(error.localizedDescription)"
        }
    }

    private static func sanitized(_ input: NativeState) -> NativeState {
        let clients = sanitizedClients(input.clients)
        let validCodes = Set(clients.map { $0.code.lowercased() })

        var seenIconIDs = Set<UUID>()
        let icons = input.visualIcons.filter { icon in
            let validClient = validCodes.contains(icon.clientCode.lowercased())
            let validLabel = !icon.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return validClient && validLabel && seenIconIDs.insert(icon.id).inserted
        }
        let iconOwner = Dictionary(uniqueKeysWithValues: icons.map { ($0.id, $0.clientCode.lowercased()) })

        var seenBoardIDs = Set<UUID>()
        let boards = input.choiceBoards.compactMap { board -> PersistedChoiceBoard? in
            let code = board.clientCode.lowercased()
            guard validCodes.contains(code), seenBoardIDs.insert(board.id).inserted else { return nil }
            var seen = Set<UUID>()
            let validIconIDs = board.iconIDs.filter {
                iconOwner[$0] == code && seen.insert($0).inserted
            }
            guard !validIconIDs.isEmpty else { return nil }
            var clean = board
            clean.title = board.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.title.isEmpty else { return nil }
            clean.iconIDs = Array(validIconIDs.prefix(9))
            clean.columns = board.columns == 3 ? 3 : 2
            return clean
        }

        var seenScheduleIDs = Set<UUID>()
        let schedules = input.visualSchedules.compactMap { schedule -> PersistedVisualSchedule? in
            let code = schedule.clientCode.lowercased()
            guard validCodes.contains(code), seenScheduleIDs.insert(schedule.id).inserted else { return nil }
            let title = schedule.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            let steps = schedule.steps.compactMap { step -> PersistedScheduleStep? in
                let label = step.label.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !label.isEmpty else { return nil }
                let safeIconID: UUID?
                if let iconID = step.iconID, iconOwner[iconID] == code {
                    safeIconID = iconID
                } else {
                    safeIconID = nil
                }
                return PersistedScheduleStep(id: step.id, label: label, iconID: safeIconID)
            }
            guard !steps.isEmpty else { return nil }
            var clean = schedule
            clean.title = title
            clean.steps = steps
            return clean
        }

        return NativeState(
            schemaVersion: max(1, input.schemaVersion),
            clients: clients,
            visualIcons: icons,
            choiceBoards: boards,
            visualSchedules: schedules
        )
    }

    private static func sanitizedClients(_ input: [LifeRouteClientProfile]) -> [LifeRouteClientProfile] {
        var seenCodes = Set<String>()
        var seenIDs = Set<UUID>()
        var output: [LifeRouteClientProfile] = []

        for client in input {
            let first = ClientProfileCore.normalizedPair(client.first2)
            let last = ClientProfileCore.normalizedPair(client.last2)
            guard first.count == 2, last.count == 2 else { continue }
            let key = (first + last).lowercased()
            guard seenCodes.insert(key).inserted, seenIDs.insert(client.id).inserted else { continue }

            var clean = client
            clean.first2 = first
            clean.last2 = last
            clean.address = client.address.trimmingCharacters(in: .whitespacesAndNewlines)
            clean.preferredActivities = cleanList(client.preferredActivities)
            clean.currentTargets = cleanList(client.currentTargets)
            clean.behaviorsOfConcern = cleanList(client.behaviorsOfConcern)
            clean.communicationNotes = client.communicationNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            clean.promptingNotes = client.promptingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            clean.caregiverNotes = client.caregiverNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            clean.clinicalNotes = client.clinicalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            output.append(clean)
        }

        return output.sorted { $0.code.localizedCaseInsensitiveCompare($1.code) == .orderedAscending }
    }

    private static func cleanList(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in values {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = value.lowercased()
            guard !value.isEmpty, seen.insert(key).inserted else { continue }
            result.append(value)
            if result.count == 60 { break }
        }
        return result
    }
}
