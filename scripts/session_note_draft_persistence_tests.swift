import Foundation

#if !canImport(Combine)
protocol ObservableObject: AnyObject {}
@propertyWrapper struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
#endif

struct LifeRouteClientProfile: Codable {
    var id = UUID()
    var first2 = "AA"
    var last2 = "BB"
    var address = ""
    var preferredActivities: [String] = []
    var currentTargets: [String] = []
    var behaviorsOfConcern: [String] = []
    var communicationNotes = ""
    var promptingNotes = ""
    var caregiverNotes = ""
    var clinicalNotes = ""
    var code: String { first2 + last2 }
}

enum ClientProfileCore {
    static func normalizedPair(_ value: String) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2)).uppercased()
    }
}

enum LifeRoutePlaceKind: String, Codable { case other }

struct LifeRouteSavedPlace: Codable {
    var id: UUID
    var name: String
    var address: String
    var kind: LifeRoutePlaceKind
    var minimumVisitMinutes: Int
    var useInGapSuggestions: Bool
}

enum LifeRouteTodoCategory: String, Codable { case other }
enum LifeRouteTodoPriority: String, Codable {
    case normal
    var sortWeight: Int { 0 }
}

struct LifeRouteTodo: Codable {
    var id: UUID
    var title: String
    var category: LifeRouteTodoCategory
    var durationMinutes: Int
    var savedPlaceID: UUID?
    var address: String
    var priority: LifeRouteTodoPriority
    var dueDate: Date
    var notes: String
    var completed: Bool
    var createdAt: Date
    var completedAt: Date?
}

struct ClientVisualIcon {
    var id: UUID
    var clientID: UUID
    var clientCode: String
    var label: String
    var imageData: Data?
    var createdAt: Date
}

struct ClientChoiceBoard {
    var id: UUID
    var clientID: UUID
    var clientCode: String
    var title: String
    var iconIDs: [UUID]
    var columns: Int
    var createdAt: Date
}

struct ClientVisualScheduleStep {
    var id: UUID
    var label: String
    var iconID: UUID?
}

struct ClientVisualSchedule {
    var id: UUID
    var clientID: UUID
    var clientCode: String
    var title: String
    var steps: [ClientVisualScheduleStep]
    var createdAt: Date
}

@main
@MainActor
enum SessionNoteDraftPersistenceTests {
    private static var assertionCount = 0

    static func main() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("liferoute-session-note-tests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let emptyStore = LifeRoutePersistenceStore(
            fileManager: fileManager,
            applicationSupportDirectory: root
        )
        expect(emptyStore.loadSessionNoteDraft() == .empty, "a new store starts without stale draft state")

        emptyStore.saveRoutingState(homeAddress: "Synthetic home", savedPlaces: [], todos: [], dayStops: [], routeBufferMinutes: 17)
        let event = LifeRouteCalendarEvent(id: "synthetic-calendar", title: "Synthetic event", start: Date(), end: Date().addingTimeInterval(1800), location: "Synthetic location", calendarTitle: "Synthetic calendar", isAllDay: false, source: .manual)
        emptyStore.saveManualCalendarEvents([event])
        emptyStore.saveProviderCalendarEvents([LifeRouteCalendarEvent(id: "synthetic-provider", title: "Synthetic provider event", start: event.start, end: event.end, location: "", calendarTitle: "Synthetic provider", isAllDay: false, source: .apple)])

        let alpha = SessionNoteDraft(
            selectedClientCode: "SYNT",
            sessionFacts: "synthetic draft alpha",
            generatedDraft: "synthetic generated alpha"
        )
        emptyStore.saveSessionNoteDraft(alpha)
        await emptyStore.flushPendingWrites()

        let stateFile = root
            .appendingPathComponent("LifeRoute/NativeState/native-state-v1.json", isDirectory: false)
        expect(fileManager.fileExists(atPath: stateFile.path), "draft save uses the existing Application Support state file")

        var reconstructed = LifeRoutePersistenceStore(
            fileManager: fileManager,
            applicationSupportDirectory: root
        )
        expect(reconstructed.loadSessionNoteDraft() == alpha, "root departure or process reconstruction restores every draft field")

        expect(reconstructed.loadRoutingState().homeAddress == "Synthetic home", "draft save preserves unrelated routing state")
        expect(reconstructed.loadRoutingState().routeBufferMinutes == 17, "draft save preserves route configuration")
        expect(reconstructed.loadManualCalendarEvents().first?.id == event.id, "draft save preserves manual calendar")
        expect(reconstructed.loadProviderCalendarEvents().first?.id == "synthetic-provider", "draft save preserves provider calendar")

        let beta = SessionNoteDraft(
            selectedClientCode: "SYNT",
            sessionFacts: "synthetic draft beta",
            generatedDraft: "synthetic generated beta"
        )
        reconstructed.saveSessionNoteDraft(alpha)
        reconstructed.saveSessionNoteDraft(beta)
        await reconstructed.flushPendingWrites()
        reconstructed = LifeRoutePersistenceStore(
            fileManager: fileManager,
            applicationSupportDirectory: root
        )
        expect(reconstructed.loadSessionNoteDraft() == beta, "the latest queued mutation wins on store reconstruction")

        for cycle in 1...3 {
            reconstructed.saveSessionNoteDraft(beta)
            await reconstructed.flushPendingWrites()
            reconstructed = LifeRoutePersistenceStore(
                fileManager: fileManager,
                applicationSupportDirectory: root
            )
            expect(reconstructed.loadSessionNoteDraft() == beta, "departure cycle \(cycle) does not duplicate or corrupt the draft")
        }

        reconstructed.saveSessionNoteDraft(.empty)
        await reconstructed.flushPendingWrites()
        reconstructed = LifeRoutePersistenceStore(
            fileManager: fileManager,
            applicationSupportDirectory: root
        )
        expect(reconstructed.loadSessionNoteDraft().isEmpty, "explicit clear remains cleared after reconstruction")

        expect(reconstructed.loadRoutingState().homeAddress == "Synthetic home" && reconstructed.loadRoutingState().routeBufferMinutes == 17, "explicit note clear preserves routing data")
        expect(reconstructed.loadManualCalendarEvents().count == 1 && reconstructed.loadProviderCalendarEvents().count == 1, "explicit note clear preserves both calendar stores")

        let afterClear = SessionNoteDraft(
            selectedClientCode: "",
            sessionFacts: "synthetic draft gamma",
            generatedDraft: ""
        )
        reconstructed.saveSessionNoteDraft(afterClear)
        await reconstructed.flushPendingWrites()
        reconstructed = LifeRoutePersistenceStore(
            fileManager: fileManager,
            applicationSupportDirectory: root
        )
        expect(reconstructed.loadSessionNoteDraft() == afterClear, "a new draft persists after explicit clear")
        expect(!reconstructed.loadSessionNoteDraft().sessionFacts.contains("alpha"), "cleared content cannot resurrect into a later draft")

        let legacyDraft = try JSONDecoder().decode(SessionNoteDraft.self, from: Data(#"{"selectedClientCode":"SYN_A","sessionFacts":"Synthetic alpha facts.","generatedDraft":"Synthetic alpha prose."}"#.utf8))
        expect(legacyDraft.inactiveClientDrafts.isEmpty && legacyDraft.sessionFacts == "Synthetic alpha facts.", "legacy three-field drafts decode with the active owner intact")
        var separated = legacyDraft
        separated.inactiveClientDrafts["SYN_B"] = .init(sessionFacts: "Synthetic beta facts.", generatedDraft: "Synthetic beta prose.")
        reconstructed.saveSessionNoteDraft(separated)
        await reconstructed.flushPendingWrites()
        let separatedStore = LifeRoutePersistenceStore(fileManager: fileManager, applicationSupportDirectory: root)
        expect(separatedStore.loadSessionNoteDraft() == separated, "active and inactive client drafts reconstruct from the existing disk store")
        separated.sessionFacts = ""
        separated.generatedDraft = ""
        separatedStore.saveSessionNoteDraft(separated)
        await separatedStore.flushPendingWrites()
        let clearedOwner = LifeRoutePersistenceStore(fileManager: fileManager, applicationSupportDirectory: root).loadSessionNoteDraft()
        expect(clearedOwner.selectedClientCode == "SYN_A" && clearedOwner.sessionFacts.isEmpty && clearedOwner.generatedDraft.isEmpty, "scoped Clear reconstructs empty active content with retained owner")
        expect(clearedOwner.inactiveClientDrafts["SYN_B"]?.generatedDraft == "Synthetic beta prose.", "scoped Clear preserves the other client's draft on disk")

        let legacyRoot = fileManager.temporaryDirectory
            .appendingPathComponent("liferoute-session-note-legacy-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: legacyRoot) }
        let legacyDirectory = legacyRoot.appendingPathComponent("LifeRoute/NativeState", isDirectory: true)
        try fileManager.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        let legacyJSON: [String: Any] = [
            "schemaVersion": 6,
            "clients": [],
            "visualIcons": [],
            "choiceBoards": [],
            "visualSchedules": [],
            "homeAddress": "",
            "savedPlaces": [],
            "todos": [],
            "dayStops": [],
            "routeBufferMinutes": 10,
            "manualCalendarEvents": [],
            "providerCalendarEvents": [],
        ]
        let legacyData = try JSONSerialization.data(withJSONObject: legacyJSON, options: [.sortedKeys])
        try legacyData.write(
            to: legacyDirectory.appendingPathComponent("native-state-v1.json", isDirectory: false),
            options: [.atomic]
        )
        let migrated = LifeRoutePersistenceStore(
            fileManager: fileManager,
            applicationSupportDirectory: legacyRoot
        )
        expect(migrated.loadSessionNoteDraft() == .empty, "pre-draft schema loads with an empty backward-compatible draft")
        expect(migrated.recoveryMessage == nil, "missing legacy draft data is not treated as store corruption")

        print("Session Note draft persistence fixtures passed (\(assertionCount) assertions).")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertionCount += 1
        guard condition() else {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
