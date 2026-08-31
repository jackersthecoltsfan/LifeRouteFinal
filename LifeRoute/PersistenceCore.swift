import Foundation

struct RestoredClientVisualSupportState {
    var icons: [ClientVisualIcon]
    var choiceBoards: [ClientChoiceBoard]
    var schedules: [ClientVisualSchedule]

    static let empty = RestoredClientVisualSupportState(icons: [], choiceBoards: [], schedules: [])
}

struct RestoredRoutingPersistenceState {
    var homeAddress: String
    var savedPlaces: [LifeRouteSavedPlace]
    var todos: [LifeRouteTodo]
    var dayStops: [LifeRouteDayStop]
    var routeBufferMinutes: Int

    static let empty = RestoredRoutingPersistenceState(
        homeAddress: "",
        savedPlaces: [],
        todos: [],
        dayStops: [],
        routeBufferMinutes: 10
    )
}

@MainActor
final class LifeRoutePersistenceStore {
    static let shared = LifeRoutePersistenceStore()

    // This stable owner mirrors the General/no-client visual library in
    // ClientVisualSupportCore. General visuals are real persisted data even
    // though there is intentionally no synthetic client profile in Setup.
    private static let generalVisualLibraryID = UUID(uuidString: "7F164E34-BD4A-4A30-AFDB-70A4AE8C7D3E")!
    private static let generalVisualLibraryCode = "GENERAL"
    private static let providerCalendarEventLimit = 1_500

    private struct PersistedVisualIcon: Codable {
        var id: UUID
        var clientID: UUID
        var clientCode: String
        var label: String
        var imageData: Data?
        var imageFileName: String?
        var createdAt: Date

        init(
            id: UUID,
            clientID: UUID,
            clientCode: String,
            label: String,
            imageData: Data?,
            createdAt: Date
        ) {
            self.id = id
            self.clientID = clientID
            self.clientCode = clientCode
            self.label = label
            self.imageData = imageData
            self.imageFileName = imageData == nil ? nil : Self.fileName(for: id)
            self.createdAt = createdAt
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case clientID
            case clientCode
            case label
            case imageData
            case imageFileName
            case createdAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            clientID = try container.decode(UUID.self, forKey: .clientID)
            clientCode = try container.decode(String.self, forKey: .clientCode)
            label = try container.decode(String.self, forKey: .label)
            imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
            let hasExternalImage = try container.decodeIfPresent(String.self, forKey: .imageFileName) != nil
            imageFileName = hasExternalImage || imageData != nil ? Self.fileName(for: id) : nil
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(clientID, forKey: .clientID)
            try container.encode(clientCode, forKey: .clientCode)
            try container.encode(label, forKey: .label)
            try container.encodeIfPresent(resolvedImageFileName, forKey: .imageFileName)
            try container.encode(createdAt, forKey: .createdAt)
        }

        var resolvedImageFileName: String? {
            imageData != nil || imageFileName != nil ? Self.fileName(for: id) : nil
        }

        private static func fileName(for id: UUID) -> String {
            "\(id.uuidString.lowercased()).visual"
        }
    }

    private struct PersistedChoiceBoard: Codable {
        var id: UUID
        var clientID: UUID
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
        var clientID: UUID
        var clientCode: String
        var title: String
        var steps: [PersistedScheduleStep]
        var createdAt: Date
    }

    private struct NativeState: Codable, @unchecked Sendable {
        var schemaVersion: Int
        var clients: [LifeRouteClientProfile]
        var visualIcons: [PersistedVisualIcon]
        var choiceBoards: [PersistedChoiceBoard]
        var visualSchedules: [PersistedVisualSchedule]
        var homeAddress: String
        var savedPlaces: [LifeRouteSavedPlace]
        var todos: [LifeRouteTodo]
        var dayStops: [LifeRouteDayStop]
        var routeBufferMinutes: Int
        var manualCalendarEvents: [LifeRouteCalendarEvent]
        var providerCalendarEvents: [LifeRouteCalendarEvent]

        init(
            schemaVersion: Int = 6,
            clients: [LifeRouteClientProfile] = [],
            visualIcons: [PersistedVisualIcon] = [],
            choiceBoards: [PersistedChoiceBoard] = [],
            visualSchedules: [PersistedVisualSchedule] = [],
            homeAddress: String = "",
            savedPlaces: [LifeRouteSavedPlace] = [],
            todos: [LifeRouteTodo] = [],
            dayStops: [LifeRouteDayStop] = [],
            routeBufferMinutes: Int = 10,
            manualCalendarEvents: [LifeRouteCalendarEvent] = [],
            providerCalendarEvents: [LifeRouteCalendarEvent] = []
        ) {
            self.schemaVersion = schemaVersion
            self.clients = clients
            self.visualIcons = visualIcons
            self.choiceBoards = choiceBoards
            self.visualSchedules = visualSchedules
            self.homeAddress = homeAddress
            self.savedPlaces = savedPlaces
            self.todos = todos
            self.dayStops = dayStops
            self.routeBufferMinutes = max(0, min(180, routeBufferMinutes))
            self.manualCalendarEvents = manualCalendarEvents
            self.providerCalendarEvents = providerCalendarEvents
        }

        private enum CodingKeys: String, CodingKey {
            case schemaVersion
            case clients
            case visualIcons
            case choiceBoards
            case visualSchedules
            case homeAddress
            case savedPlaces
            case todos
            case dayStops
            case routeBufferMinutes
            case manualCalendarEvents
            case providerCalendarEvents
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
            clients = try container.decodeIfPresent([LifeRouteClientProfile].self, forKey: .clients) ?? []
            visualIcons = try container.decodeIfPresent([PersistedVisualIcon].self, forKey: .visualIcons) ?? []
            choiceBoards = try container.decodeIfPresent([PersistedChoiceBoard].self, forKey: .choiceBoards) ?? []
            visualSchedules = try container.decodeIfPresent([PersistedVisualSchedule].self, forKey: .visualSchedules) ?? []
            homeAddress = try container.decodeIfPresent(String.self, forKey: .homeAddress) ?? ""
            savedPlaces = try container.decodeIfPresent([LifeRouteSavedPlace].self, forKey: .savedPlaces) ?? []
            todos = try container.decodeIfPresent([LifeRouteTodo].self, forKey: .todos) ?? []
            dayStops = try container.decodeIfPresent([LifeRouteDayStop].self, forKey: .dayStops) ?? []
            routeBufferMinutes = max(
                0,
                min(180, try container.decodeIfPresent(Int.self, forKey: .routeBufferMinutes) ?? 10)
            )
            manualCalendarEvents = try container.decodeIfPresent([LifeRouteCalendarEvent].self, forKey: .manualCalendarEvents) ?? []
            providerCalendarEvents = try container.decodeIfPresent([LifeRouteCalendarEvent].self, forKey: .providerCalendarEvents) ?? []
        }
    }

    private struct PersistenceWriteResult: Sendable {
        let revision: UInt64
        let errorMessage: String?
    }

    private actor SnapshotWriter {
        private let fileManager = FileManager.default
        private let fileURL: URL
        private let imageDirectoryURL: URL
        private var latestWrittenRevision: UInt64 = 0

        init(fileURL: URL, imageDirectoryURL: URL) {
            self.fileURL = fileURL
            self.imageDirectoryURL = imageDirectoryURL
        }

        func persist(_ snapshot: NativeState, revision: UInt64) -> PersistenceWriteResult {
            guard revision > latestWrittenRevision else {
                return PersistenceWriteResult(revision: revision, errorMessage: nil)
            }

            do {
                try fileManager.createDirectory(at: imageDirectoryURL, withIntermediateDirectories: true)
                try? fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: imageDirectoryURL.path
                )

                var retainedImageFiles = Set<String>()
                for icon in snapshot.visualIcons {
                    guard let imageData = icon.imageData,
                          let fileName = icon.resolvedImageFileName else { continue }
                    retainedImageFiles.insert(fileName)
                    let imageURL = imageDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
                    guard !fileManager.fileExists(atPath: imageURL.path) else { continue }
                    try imageData.write(to: imageURL, options: [.atomic])
                    try? fileManager.setAttributes(
                        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                        ofItemAtPath: imageURL.path
                    )
                }

                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.sortedKeys]
                let data = try encoder.encode(snapshot)
                try data.write(to: fileURL, options: [.atomic])
                try? fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: fileURL.path
                )

                if let existingFiles = try? fileManager.contentsOfDirectory(
                    at: imageDirectoryURL,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) {
                    for existingURL in existingFiles where !retainedImageFiles.contains(existingURL.lastPathComponent) {
                        try? fileManager.removeItem(at: existingURL)
                    }
                }

                latestWrittenRevision = revision
                return PersistenceWriteResult(revision: revision, errorMessage: nil)
            } catch {
                return PersistenceWriteResult(
                    revision: revision,
                    errorMessage: "LifeRoute could not save native state: \(error.localizedDescription)"
                )
            }
        }
    }

    private let fileManager: FileManager
    private var fileURL: URL?
    private var imageDirectoryURL: URL?
    private var state: NativeState
    private var clientIDByNormalizedCode: [String: UUID]
    private var snapshotWriter: SnapshotWriter?
    private var persistenceRevision: UInt64
    private var persistenceTask: Task<Void, Never>?
    private(set) var recoveryMessage: String?

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = nil
        self.imageDirectoryURL = nil
        self.state = NativeState()
        self.clientIDByNormalizedCode = [:]
        self.snapshotWriter = nil
        self.persistenceRevision = 0
        self.persistenceTask = nil
        self.recoveryMessage = nil

        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            self.recoveryMessage = "Application Support is unavailable; native data will remain in memory."
            return
        }

        let directory = applicationSupport
            .appendingPathComponent("LifeRoute", isDirectory: true)
            .appendingPathComponent("NativeState", isDirectory: true)
        let url = directory.appendingPathComponent("native-state-v1.json", isDirectory: false)
        let imagesURL = directory.appendingPathComponent("VisualImages", isDirectory: true)
        self.fileURL = url
        self.imageDirectoryURL = imagesURL

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: directory.path
            )

            if fileManager.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let decoded = try decoder.decode(NativeState.self, from: data)
                let hydrated = Self.hydratingVisualImages(in: decoded, from: imagesURL)
                self.state = Self.sanitized(hydrated)
            }
        } catch {
            let recoveryTimestamp = Int(Date().timeIntervalSince1970)
            let backupURL = directory.appendingPathComponent(
                "native-state-v1-corrupt-\(recoveryTimestamp).json",
                isDirectory: false
            )
            if fileManager.fileExists(atPath: url.path) {
                try? fileManager.moveItem(at: url, to: backupURL)
            }
            let imageBackupURL = directory.appendingPathComponent(
                "VisualImages-corrupt-\(recoveryTimestamp)",
                isDirectory: true
            )
            if fileManager.fileExists(atPath: imagesURL.path) {
                try? fileManager.moveItem(at: imagesURL, to: imageBackupURL)
            }
            self.state = NativeState()
            self.recoveryMessage = "LifeRoute preserved an unreadable native state file and started with safe defaults."
        }

        self.clientIDByNormalizedCode = Self.clientIndex(for: state.clients)
        self.snapshotWriter = SnapshotWriter(fileURL: url, imageDirectoryURL: imagesURL)
    }

    func loadClients() -> [LifeRouteClientProfile] {
        state.clients
    }

    func clientID(forCode code: String) -> UUID? {
        clientIDByNormalizedCode[Self.normalizedClientCode(code)]
    }

    func saveClients(_ clients: [LifeRouteClientProfile]) {
        var next = state
        next.clients = Self.sanitizedClients(clients)
        state = Self.sanitized(next)
        clientIDByNormalizedCode = Self.clientIndex(for: state.clients)
        persist()
    }

    func loadClientVisualSupports() -> RestoredClientVisualSupportState {
        let icons = state.visualIcons.map {
            ClientVisualIcon(
                id: $0.id,
                clientID: $0.clientID,
                clientCode: $0.clientCode,
                label: $0.label,
                imageData: $0.imageData,
                createdAt: $0.createdAt
            )
        }
        let boards = state.choiceBoards.map {
            ClientChoiceBoard(
                id: $0.id,
                clientID: $0.clientID,
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
                clientID: $0.clientID,
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
                clientID: $0.clientID,
                clientCode: $0.clientCode,
                label: $0.label,
                imageData: $0.imageData,
                createdAt: $0.createdAt
            )
        }
        next.choiceBoards = choiceBoards.map {
            PersistedChoiceBoard(
                id: $0.id,
                clientID: $0.clientID,
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
                clientID: $0.clientID,
                clientCode: $0.clientCode,
                title: $0.title,
                steps: $0.steps.map { PersistedScheduleStep(id: $0.id, label: $0.label, iconID: $0.iconID) },
                createdAt: $0.createdAt
            )
        }
        state = Self.sanitized(next)
        persist()
    }

    func loadRoutingState() -> RestoredRoutingPersistenceState {
        return RestoredRoutingPersistenceState(
            homeAddress: state.homeAddress,
            savedPlaces: state.savedPlaces,
            todos: state.todos,
            dayStops: state.dayStops,
            routeBufferMinutes: state.routeBufferMinutes
        )
    }

    // Keep the existing persistence API available for older call sites and audits.
    func saveRoutingState(homeAddress: String, savedPlaces: [LifeRouteSavedPlace]) {
        saveRoutingState(homeAddress: homeAddress, savedPlaces: savedPlaces, todos: state.todos)
    }

    func saveRoutingState(homeAddress: String, savedPlaces: [LifeRouteSavedPlace], todos: [LifeRouteTodo]) {
        saveRoutingState(
            homeAddress: homeAddress,
            savedPlaces: savedPlaces,
            todos: todos,
            dayStops: state.dayStops,
            routeBufferMinutes: state.routeBufferMinutes
        )
    }

    func saveRoutingState(
        homeAddress: String,
        savedPlaces: [LifeRouteSavedPlace],
        todos: [LifeRouteTodo],
        dayStops: [LifeRouteDayStop],
        routeBufferMinutes: Int
    ) {
        var next = state
        next.homeAddress = homeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        next.savedPlaces = Self.sanitizedSavedPlaces(savedPlaces)
        next.todos = todos
        next.dayStops = LifeRouteDayStopCollection.sanitized(dayStops)
        next.routeBufferMinutes = max(0, min(180, routeBufferMinutes))
        state = Self.sanitized(next)
        persist()
    }

    func loadManualCalendarEvents() -> [LifeRouteCalendarEvent] {
        return state.manualCalendarEvents
    }

    func saveManualCalendarEvents(_ events: [LifeRouteCalendarEvent]) {
        var next = state
        next.manualCalendarEvents = Self.sanitizedManualCalendarEvents(events)
        state = next
        persist()
    }

    func loadProviderCalendarEvents() -> [LifeRouteCalendarEvent] {
        state.providerCalendarEvents
    }

    func saveProviderCalendarEvents(_ events: [LifeRouteCalendarEvent]) {
        var next = state
        next.providerCalendarEvents = Self.sanitizedProviderCalendarEvents(events)
        state = next
        persist()
    }

    private func persist() {
        guard let snapshotWriter else { return }
        persistenceRevision &+= 1
        let revision = persistenceRevision
        let snapshot = state
        let previousTask = persistenceTask

        persistenceTask = Task { [weak self, snapshotWriter] in
            await previousTask?.value
            let result = await snapshotWriter.persist(snapshot, revision: revision)
            guard let self, result.revision == self.persistenceRevision else { return }
            self.recoveryMessage = result.errorMessage
        }
    }

    func flushPendingWrites() async {
        while true {
            let revisionAtStart = persistenceRevision
            await persistenceTask?.value
            guard revisionAtStart != persistenceRevision else { return }
        }
    }

    private static func sanitized(_ input: NativeState) -> NativeState {
        let clients = sanitizedClients(input.clients)
        var codeByClientID = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0.code) })
        codeByClientID[Self.generalVisualLibraryID] = Self.generalVisualLibraryCode

        var seenIconIDs = Set<UUID>()
        let icons = input.visualIcons.compactMap { icon -> PersistedVisualIcon? in
            guard let currentCode = codeByClientID[icon.clientID],
                  !icon.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  seenIconIDs.insert(icon.id).inserted else { return nil }
            var clean = icon
            clean.clientCode = currentCode
            clean.label = icon.label.trimmingCharacters(in: .whitespacesAndNewlines)
            return clean
        }
        let iconOwner = Dictionary(uniqueKeysWithValues: icons.map { ($0.id, $0.clientID) })

        var seenBoardIDs = Set<UUID>()
        let boards = input.choiceBoards.compactMap { board -> PersistedChoiceBoard? in
            guard let currentCode = codeByClientID[board.clientID],
                  seenBoardIDs.insert(board.id).inserted else { return nil }
            var seen = Set<UUID>()
            let validIconIDs = board.iconIDs.filter {
                iconOwner[$0] == board.clientID && seen.insert($0).inserted
            }
            guard !validIconIDs.isEmpty else { return nil }
            let title = board.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            var clean = board
            clean.clientCode = currentCode
            clean.title = title
            clean.iconIDs = Array(validIconIDs.prefix(9))
            clean.columns = board.columns == 3 ? 3 : 2
            return clean
        }

        var seenScheduleIDs = Set<UUID>()
        let schedules = input.visualSchedules.compactMap { schedule -> PersistedVisualSchedule? in
            guard let currentCode = codeByClientID[schedule.clientID],
                  seenScheduleIDs.insert(schedule.id).inserted else { return nil }
            let title = schedule.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            let steps = schedule.steps.compactMap { step -> PersistedScheduleStep? in
                let label = step.label.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !label.isEmpty else { return nil }
                let safeIconID: UUID?
                if let iconID = step.iconID, iconOwner[iconID] == schedule.clientID {
                    safeIconID = iconID
                } else {
                    safeIconID = nil
                }
                return PersistedScheduleStep(id: step.id, label: label, iconID: safeIconID)
            }
            guard !steps.isEmpty else { return nil }
            var clean = schedule
            clean.clientCode = currentCode
            clean.title = title
            clean.steps = steps
            return clean
        }

        let homeAddress = input.homeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedPlaces = sanitizedSavedPlaces(input.savedPlaces)
        let savedPlaceIDs = Set(savedPlaces.map(\.id))
        let todos = sanitizedTodos(input.todos, savedPlaceIDs: savedPlaceIDs)
        let dayStops = LifeRouteDayStopCollection.sanitized(input.dayStops)
        let manualCalendarEvents = sanitizedManualCalendarEvents(input.manualCalendarEvents)
        let providerCalendarEvents = sanitizedProviderCalendarEvents(input.providerCalendarEvents)

        return NativeState(
            schemaVersion: max(6, input.schemaVersion),
            clients: clients,
            visualIcons: icons,
            choiceBoards: boards,
            visualSchedules: schedules,
            homeAddress: homeAddress,
            savedPlaces: savedPlaces,
            todos: todos,
            dayStops: dayStops,
            routeBufferMinutes: max(0, min(180, input.routeBufferMinutes)),
            manualCalendarEvents: manualCalendarEvents,
            providerCalendarEvents: providerCalendarEvents
        )
    }

    private static func hydratingVisualImages(in input: NativeState, from directory: URL) -> NativeState {
        var hydrated = input
        hydrated.visualIcons = input.visualIcons.map { storedIcon in
            guard storedIcon.imageData == nil,
                  let fileName = storedIcon.resolvedImageFileName else { return storedIcon }
            var icon = storedIcon
            icon.imageData = try? Data(
                contentsOf: directory.appendingPathComponent(fileName, isDirectory: false),
                options: [.mappedIfSafe]
            )
            if icon.imageData == nil { icon.imageFileName = nil }
            return icon
        }
        return hydrated
    }

    private static func clientIndex(for clients: [LifeRouteClientProfile]) -> [String: UUID] {
        Dictionary(uniqueKeysWithValues: clients.map { (normalizedClientCode($0.code), $0.id) })
    }

    private static func normalizedClientCode(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func sanitizedSavedPlaces(_ input: [LifeRouteSavedPlace]) -> [LifeRouteSavedPlace] {
        var seenPlaceIDs = Set<UUID>()
        return input.compactMap { place -> LifeRouteSavedPlace? in
            let name = place.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let address = place.address.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !address.isEmpty, seenPlaceIDs.insert(place.id).inserted else { return nil }
            return LifeRouteSavedPlace(
                id: place.id,
                name: name,
                address: address,
                kind: place.kind,
                minimumVisitMinutes: place.minimumVisitMinutes,
                useInGapSuggestions: place.useInGapSuggestions
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func sanitizedTodos(_ input: [LifeRouteTodo], savedPlaceIDs: Set<UUID>) -> [LifeRouteTodo] {
        var seenTodoIDs = Set<UUID>()
        return input.compactMap { todo -> LifeRouteTodo? in
            let title = todo.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, seenTodoIDs.insert(todo.id).inserted else { return nil }
            let safeSavedPlaceID = todo.savedPlaceID.flatMap { savedPlaceIDs.contains($0) ? $0 : nil }
            return LifeRouteTodo(
                id: todo.id,
                title: title,
                category: todo.category,
                durationMinutes: todo.durationMinutes,
                savedPlaceID: safeSavedPlaceID,
                address: todo.address,
                priority: todo.priority,
                dueDate: todo.dueDate,
                notes: todo.notes,
                completed: todo.completed,
                createdAt: todo.createdAt,
                completedAt: todo.completed ? todo.completedAt : nil
            )
        }.sorted { lhs, rhs in
            if lhs.completed != rhs.completed { return !lhs.completed }
            if lhs.priority.sortWeight != rhs.priority.sortWeight {
                return lhs.priority.sortWeight > rhs.priority.sortWeight
            }
            if lhs.dueDate != rhs.dueDate { return lhs.dueDate < rhs.dueDate }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private static func sanitizedManualCalendarEvents(_ input: [LifeRouteCalendarEvent]) -> [LifeRouteCalendarEvent] {
        var seenManualEventIDs = Set<String>()
        return input.compactMap { event -> LifeRouteCalendarEvent? in
            guard event.source == .manual,
                  event.end > event.start,
                  seenManualEventIDs.insert(event.id).inserted else { return nil }
            return LifeRouteCalendarEvent(
                id: event.id,
                title: event.title,
                start: event.start,
                end: event.end,
                location: event.location,
                calendarTitle: event.calendarTitle,
                isAllDay: event.isAllDay,
                source: .manual
            )
        }.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private static func sanitizedProviderCalendarEvents(_ input: [LifeRouteCalendarEvent]) -> [LifeRouteCalendarEvent] {
        var seenProviderEventIDs = Set<String>()
        let sanitized = input.compactMap { event -> LifeRouteCalendarEvent? in
            guard event.source != .manual,
                  event.end >= event.start else { return nil }
            let dedupeKey = "\(event.source.rawValue):\(event.id)"
            guard seenProviderEventIDs.insert(dedupeKey).inserted else { return nil }
            return LifeRouteCalendarEvent(
                id: event.id,
                title: event.title,
                start: event.start,
                end: event.end,
                location: event.location,
                calendarTitle: event.calendarTitle,
                isAllDay: event.isAllDay,
                source: event.source
            )
        }.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            if $0.source != $1.source { return $0.source.rawValue < $1.source.rawValue }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        return Array(sanitized.prefix(providerCalendarEventLimit))
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
