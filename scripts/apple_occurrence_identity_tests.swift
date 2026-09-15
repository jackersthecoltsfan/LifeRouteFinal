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

enum ClientVisualScheduleKind: String, Codable {
    case visualSchedule
    case firstThen
}

struct ClientVisualSchedule {
    var id: UUID
    var clientID: UUID
    var clientCode: String
    var title: String
    var steps: [ClientVisualScheduleStep]
    var kind: ClientVisualScheduleKind?
    var createdAt: Date
}

struct ClientTokenBoard {
    var id: UUID
    var clientID: UUID
    var clientCode: String
    var title: String
    var tokenCount: Int
    var rewardIconID: UUID?
    var rewardLabel: String
    var createdAt: Date
}

// Test doubles only for unrelated persisted domains and the EventKit store boundary.
struct ProbeEventStore {
    let input: [ProbeEKEvent]
    func predicateForEvents(withStart: Date, end: Date, calendars: [String]?) -> Bool { true }
    func events(matching: Bool) -> [ProbeEKEvent] { input }
}
struct ProbeEKEvent {
    var eventIdentifier: String? = "SERIES"
    var calendarItemIdentifier = "FALLBACK"
    var hasRecurrenceRules = true
    var isDetached = false
    var occurrenceDate: Date?
    var title: String? = "Synthetic recurring event"
    var startDate: Date
    var endDate: Date
    var location: String? = "Synthetic address"
    var calendar = ProbeCalendar()
    var isAllDay = false
    var calendarItemExternalIdentifier: String? = "synthetic@example.invalid"
    var timeZone: TimeZone? = TimeZone(secondsFromGMT: 0)
    var lastModifiedDate: Date? = nil
}
struct ProbeCalendar {
    let title = "Synthetic calendar"
    let calendarIdentifier = "CALENDAR"
    let source = ProbeSource()
}
struct ProbeSource { let sourceIdentifier = "ACCOUNT" }

@main @MainActor enum AppleOccurrenceIdentityTests {
    private static var count = 0
    private static let utc = TimeZone(secondsFromGMT: 0)!
    private static func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private static func expect(_ condition: @autoclosure () -> Bool, _ label: String) {
        count += 1
        guard condition() else { print("FAIL: \(label)"); exit(1) }
    }
    private static func imported(_ events: [ProbeEKEvent]) -> [LifeRouteCalendarEvent] {
        AppleImportProbe(eventStore: ProbeEventStore(input: events)).fetch()
    }
    private static func raw(_ start: Date, duration: TimeInterval = 3600) -> ProbeEKEvent {
        ProbeEKEvent(occurrenceDate: start, startDate: start, endDate: start.addingTimeInterval(duration))
    }
    private static func rekey(_ event: LifeRouteCalendarEvent, id: String) throws -> LifeRouteCalendarEvent {
        let encoder = JSONEncoder()
        var object = try JSONSerialization.jsonObject(with: encoder.encode(event)) as! [String: Any]
        object["id"] = id
        return try JSONDecoder().decode(LifeRouteCalendarEvent.self, from: JSONSerialization.data(withJSONObject: object))
    }
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("apple-occurrence-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let aDate = date("2026-09-14T14:00:00Z"), bDate = date("2026-09-21T14:00:00Z")
        let aRaw = raw(aDate), bRaw = raw(bDate)
        let pair = imported([aRaw, bRaw])
        let a = pair[0], b = pair[1]

        var single = aRaw
        single.hasRecurrenceRules = false
        expect(imported([single])[0].id == "apple-SERIES", "1 nonrecurring importer preserves legacy ID")
        single.eventIdentifier = nil
        expect(imported([single])[0].id == "apple-FALLBACK", "1 nil eventIdentifier uses calendarItemIdentifier")
        expect(a.id != b.id, "2 weekly occurrences sharing base ID receive distinct IDs")
        expect(a.id == "appleOccurrence:v1:U0VSSUVT:aW5zdGFudDoxNzg5Mzk0NDAw", "2 versioned ID format is locked")
        expect(a.providerIdentity?.eventIdentifier == "SERIES", "2 provider metadata retains raw base ID")
        expect(a.providerIdentity?.calendarIdentifier == "CALENDAR" && a.providerIdentity?.accountIdentifier == "ACCOUNT", "2 calendar and account metadata preserved")
        expect(imported([aRaw])[0] == a, "3 repeated construction is stable")
        var detached = aRaw
        detached.startDate = bDate.addingTimeInterval(7200)
        detached.endDate = detached.startDate.addingTimeInterval(3600)
        detached.hasRecurrenceRules = false
        detached.isDetached = true
        let moved = imported([detached])[0]
        expect(moved.id == a.id && moved.start != a.start, "4 moved detached occurrence keeps original identity")
        expect(moved.providerIdentity?.recurrenceIdentifier == a.providerIdentity?.recurrenceIdentifier, "4 detached cross-provider occurrence metadata preserved")

        for (label, input) in [("forward", pair), ("reverse", pair.reversed().map { $0 })] {
            let directory = root.appendingPathComponent(label)
            let store = LifeRoutePersistenceStore(applicationSupportDirectory: directory)
            store.saveProviderCalendarEvents(input)
            expect(store.loadProviderCalendarEvents().count == 2, "5/6 \(label) saved count = 2")
            await store.flushPendingWrites()
            expect(store.recoveryMessage == nil, "5/6 \(label) disk write succeeded")
            let reload = LifeRoutePersistenceStore(applicationSupportDirectory: directory)
            expect(Set(reload.loadProviderCalendarEvents()) == Set(pair), "5/6 \(label) disk reload retains both complete events")
            let hydrated = CalendarCoreState(now: aDate, events: reload.loadProviderCalendarEvents())
            expect(hydrated.events(on: aDate).count == 1 && hydrated.events(on: bDate).count == 1, "5/6 \(label) both dates represented after hydration")
        }

        let overlapRaw = [raw(aDate, duration: 25 * 3600), raw(aDate.addingTimeInterval(86400), duration: 25 * 3600)]
        let overlap = imported(overlapRaw)
        let state = CalendarCoreState(now: overlap[1].start, events: overlap)
        let day = state.events(on: overlap[1].start)
        expect(day.count == 2 && Set(day.map(\.id)).count == 2, "7 overlapping daily occurrences have two unique same-day IDs")
        let appointments = day.map { LifeRouteRouteAppointment(id: $0.id, title: $0.title, address: $0.location, start: $0.start, end: $0.end, isAllDay: $0.isAllDay) }
        let waypoints = LifeRouteDaySequenceBuilder.waypoints(appointments: appointments, beforeStops: [], afterStops: [])
        expect(waypoints.count == 2 && Set(waypoints.map(\.id)).count == 2, "8 real day sequence retains both waypoint identities")
        let nodes = appointments.map(AppleRouteNodeProbe.node)
        let itinerary = LifeRouteGeneratedItinerary(id: "synthetic", selectedDay: overlap[1].start, generatedAt: aDate,
            returnHome: false, routeBuffer: .none, inputFingerprint: "synthetic", nodes: nodes, legs: [])
        expect(itinerary.nodes.count == 2 && Set(itinerary.nodes.map(\.id)).count == 2, "8 production node construction and itinerary uniqueness retain both occurrences")
        expect(Set(itinerary.nodes.compactMap(\.start)) == Set(overlap.map(\.start)), "8 both appointment dates remain in generated nodes")

        let google = pair.enumerated().map { index, event in
            LifeRouteCalendarEvent(id: "google-\(index)", title: event.title, start: event.start, end: event.end,
                source: .google, providerIdentity: event.providerIdentity)
        }
        expect(Set(LifeRouteCalendarCanonicalizer.canonicalEvents(from: pair + google)) == Set(google), "9 Apple/Google recurrence instances match independently")
        expect(LifeRouteCalendarCanonicalizer.canonicalEvents(from: [moved, google[0]]).count == 1, "9 moved occurrence still matches original recurrence identity")
        let alias = try rekey(a, id: "apple-alias")
        expect(LifeRouteCalendarCanonicalizer.canonicalEvents(from: [a, alias, google[0]]).count == 3, "9 ambiguous provider groups still pass through")

        let legacy = try pair.map { try rekey($0, id: "apple-SERIES") }
        for input in [legacy, Array(legacy.reversed())] {
            let store = LifeRoutePersistenceStore(applicationSupportDirectory: root.appendingPathComponent(UUID().uuidString))
            store.saveProviderCalendarEvents(input)
            expect(Set(store.loadProviderCalendarEvents()) == Set(pair), "10 legacy normalization happens before dedup regardless of input order")
            await store.flushPendingWrites()
        }
        let legacySingle = imported([raw(aDate)])[0]
        var nonrecurringRaw = aRaw
        nonrecurringRaw.hasRecurrenceRules = false
        let nonrecurring = imported([nonrecurringRaw])[0]
        let legacyDirectory = root.appendingPathComponent("legacy-json")
        let stop = LifeRouteDayStop(title: "Synthetic stop", address: "Synthetic stop address", position: .after, day: aDate, afterAppointmentID: "apple-SERIES")
        try writeLegacySnapshot(events: [legacy[0], nonrecurring], stops: [stop], at: legacyDirectory)
        let migrated = LifeRoutePersistenceStore(applicationSupportDirectory: legacyDirectory)
        expect(Set(migrated.loadProviderCalendarEvents()) == Set([legacySingle, nonrecurring]), "10/11 real legacy JSON hydration rekeys recurring survivor and keeps nonrecurring identity")
        expect(migrated.loadProviderCalendarEvents().count == 2, "10 no missing occurrences fabricated")
        expect(migrated.loadRoutingState().dayStops.first?.afterAppointmentID == a.id, "10 unambiguous same-day legacy stop anchor follows migrated ID")
        migrated.saveProviderCalendarEvents(migrated.loadProviderCalendarEvents())
        await migrated.flushPendingWrites()
        let migratedAgain = LifeRoutePersistenceStore(applicationSupportDirectory: legacyDirectory)
        expect(Set(migratedAgain.loadProviderCalendarEvents()) == Set(migrated.loadProviderCalendarEvents()), "10 migration is idempotent after save and second reload")

        let ambiguousDirectory = root.appendingPathComponent("ambiguous")
        let overlapLegacy = try overlap.map { try rekey($0, id: "apple-SERIES") }
        let ambiguousStop = LifeRouteDayStop(title: "Ambiguous", address: "Synthetic", position: .after, day: overlap[1].start, afterAppointmentID: "apple-SERIES")
        let missingStop = LifeRouteDayStop(title: "Missing", address: "Synthetic", position: .after, day: bDate, afterAppointmentID: "apple-SERIES")
        try writeLegacySnapshot(events: overlapLegacy, stops: [ambiguousStop, missingStop], at: ambiguousDirectory)
        let ambiguousStore = LifeRoutePersistenceStore(applicationSupportDirectory: ambiguousDirectory)
        expect(ambiguousStore.loadProviderCalendarEvents().count == 2, "10 legacy same-day collisions normalize before hydration filtering")
        expect(ambiguousStore.loadRoutingState().dayStops.allSatisfy { $0.afterAppointmentID == "apple-SERIES" }, "10 ambiguous or missing occurrence anchors are never guessed")

        var missing = aRaw
        missing.occurrenceDate = nil
        let incomplete = imported([missing])[0]
        expect(incomplete.id == "apple-SERIES" && incomplete.providerIdentity?.recurrenceIdentifier == nil, "missing occurrence evidence keeps legacy ID without inventing current-start identity")
        expect(LifeRouteAppleEventIdentity.normalizedID(for: incomplete) == incomplete.id, "incomplete legacy metadata remains unchanged")
        var fallback = aRaw
        fallback.eventIdentifier = nil
        expect(imported([fallback])[0].providerIdentity?.eventIdentifier == "FALLBACK", "recurring base identifier fallback retained")
        expect(imported([fallback])[0].id != a.id, "different base identifiers remain distinct")
        let unknown = try rekey(a, id: "unrecognized-existing-id")
        expect(LifeRouteAppleEventIdentity.normalizedID(for: unknown) == unknown.id, "unrecognized existing ID remains unchanged")
        expect(LifeRouteAppleEventIdentity.normalizedID(for: google[0]) == google[0].id, "Google identity remains unchanged")

        let allDayUTC = LifeRouteAppleEventIdentity(eventIdentifier: "SERIES", calendarItemIdentifier: "unused", hasRecurrenceRules: true,
            isDetached: false, occurrenceDate: date("2026-09-14T00:00:00Z"), isAllDay: true, timeZone: utc)
        let allDayNY = LifeRouteAppleEventIdentity(eventIdentifier: "SERIES", calendarItemIdentifier: "unused", hasRecurrenceRules: true,
            isDetached: false, occurrenceDate: date("2026-09-14T04:00:00Z"), isAllDay: true, timeZone: TimeZone(identifier: "America/New_York")!)
        expect(allDayUTC.recurrenceIdentifier == "date:2026-09-14", "all-day identity uses Gregorian machine date")
        expect(allDayUTC.lifeRouteID == allDayNY.lifeRouteID, "floating all-day occurrence preserves date identity across represented time zones")
        expect(allDayUTC.lifeRouteID != a.id, "all-day and timed discriminators remain distinct")
        let timedOtherZone = LifeRouteAppleEventIdentity(eventIdentifier: "SERIES", calendarItemIdentifier: "unused", hasRecurrenceRules: true,
            isDetached: false, occurrenceDate: aDate, isAllDay: false, timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        expect(timedOtherZone.lifeRouteID == a.id, "timed identity does not depend on timezone")
        var punctuation = aRaw
        punctuation.eventIdentifier = "SERIES:instant:|/é"
        let encoded = imported([punctuation])[0].id.split(separator: ":", omittingEmptySubsequences: false)
        expect(encoded.count == 4 && String(data: Data(base64Encoded: String(encoded[2]))!, encoding: .utf8) == punctuation.eventIdentifier, "structured ID keeps opaque delimiters and Unicode unambiguous")
        print("Apple occurrence identity: PASS (\(count) assertions; production importer/node seams, real cache save/reload; no EventKit or MapKit access)")
    }
    private static func writeLegacySnapshot(events: [LifeRouteCalendarEvent], stops: [LifeRouteDayStop], at root: URL) throws {
        let directory = root.appendingPathComponent("LifeRoute/NativeState")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let eventJSON = try JSONSerialization.jsonObject(with: encoder.encode(events))
        let stopJSON = try JSONSerialization.jsonObject(with: encoder.encode(stops))
        let object: [String: Any] = ["schemaVersion": 7, "providerCalendarEvents": eventJSON, "dayStops": stopJSON]
        try JSONSerialization.data(withJSONObject: object).write(to: directory.appendingPathComponent("native-state-v1.json"))
    }
}
