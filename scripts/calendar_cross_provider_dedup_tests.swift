import Foundation

#if !canImport(Combine)
protocol ObservableObject: AnyObject {}

@propertyWrapper
struct Published<Value> {
    var wrappedValue: Value

    init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}
#endif

@MainActor
final class LifeRoutePersistenceStore {
    static let shared = LifeRoutePersistenceStore()

    private(set) var manualEvents: [LifeRouteCalendarEvent] = []
    private(set) var providerEvents: [LifeRouteCalendarEvent] = []

    func reset(
        manualEvents: [LifeRouteCalendarEvent] = [],
        providerEvents: [LifeRouteCalendarEvent] = []
    ) {
        self.manualEvents = manualEvents
        self.providerEvents = providerEvents
    }

    func loadManualCalendarEvents() -> [LifeRouteCalendarEvent] { manualEvents }
    func loadProviderCalendarEvents() -> [LifeRouteCalendarEvent] { providerEvents }
    func saveManualCalendarEvents(_ events: [LifeRouteCalendarEvent]) { manualEvents = events }
    func saveProviderCalendarEvents(_ events: [LifeRouteCalendarEvent]) { providerEvents = events }
}

@main
struct CalendarCrossProviderDedupTests {
    private static var assertionCount = 0

    @MainActor
    static func main() throws {
        observedOccurrenceRepresentation()
        try exactCrossProviderDuplicate()
        multipleDuplicatePairs()
        distinctEventsDoNotMerge()
        recurrenceInstanceSafety()
        providerOnlyControls()
        downstreamPlannerControl()
        try existingBehaviorRegression()

        precondition(assertionCount >= 34, "Calendar B regression floor requires at least 34 assertions; found \(assertionCount).")
        print("Calendar B cross-provider deduplication fixtures passed (\(assertionCount) assertions).")
    }

    @MainActor
    private static func observedOccurrenceRepresentation() {
        let start = date("2026-09-09T14:00:00Z")
        let unix = Int64(start.timeIntervalSince1970)
        let reference = unix - 978_307_200
        let uid = "synthetic-series-ABCD"
        let occurrence = "instant:\(unix)"
        func event(_ source: LifeRouteCalendarSource, _ id: String, _ external: String,
                   recurrence: String? = nil, recurring: Bool = true) -> LifeRouteCalendarEvent {
            providerEvent(source: source, id: id, externalIdentifier: external,
                          recurrenceIdentifier: recurrence ?? occurrence, isRecurring: recurring,
                          start: start, modifiedAt: start)
        }
        let apple = event(.apple, "apple-rid", uid + "/RID=\(reference)")
        let google = event(.google, "google-base", uid)
        expect(LifeRouteCalendarCanonicalizer.canonicalEvents(from: [apple, google]) == [google], "RID exact UID plus Apple epoch occurrence produces one canonical event")
        expect(LifeRouteCalendarCanonicalizer.canonicalEvents(from: [google, apple]) == [google], "RID reverse order retains deterministic preferred record")
        var moved = google
        moved.start = start.addingTimeInterval(3600)
        moved.end = moved.start.addingTimeInterval(3600)
        moved.title = "Different provider display"
        moved.location = "Different provider display address"
        expect(LifeRouteCalendarCanonicalizer.canonicalEvents(from: [apple, moved]) == [moved], "RID uses original recurrence identity despite moved display fields")
        let state = makeState(with: [apple, google], now: start)
        expect(state.rawProviderEvents == [apple, google], "RID raw records and identifiers are unchanged")
        expect(state.events.count == 1, "RID Calendar receives one event")
        let appointments = state.events.map { LifeRouteRouteAppointment(id: $0.id, title: $0.title, address: $0.location, start: $0.start, end: $0.end, isAllDay: $0.isAllDay) }
        expect(LifeRouteDaySequenceBuilder.waypoints(appointments: appointments, beforeStops: [], afterStops: []).count == 1, "RID downstream route receives one waypoint and no duplicate inter-event leg")
        let secondApple = event(.apple, "apple-second", uid + "/RID=\(reference + 86400)", recurrence: "instant:\(unix + 86400)")
        let secondGoogle = event(.google, "google-second", uid, recurrence: "instant:\(unix + 86400)")
        let records = [apple, google, secondApple, secondGoogle]
        for ordered in permutations(records) {
            expect(Set(LifeRouteCalendarCanonicalizer.canonicalEvents(from: ordered).map(\.id)) == Set([google.id, secondGoogle.id]), "RID recurring instances stay separate across input permutations")
        }
        for malformed in ["", "-\(reference)", "+\(reference)", "\(reference).0", "\(reference)x", "0\(reference)", "99999999999999999999999", "１２３４５６７８９", "\(reference)/RID=\(reference)", "\(unix)", "\(reference + 1)"] {
            let invalid = event(.apple, "invalid", uid + "/RID=" + malformed)
            expect(LifeRouteCalendarCanonicalizer.canonicalEvents(from: [invalid, google]).count == 2, "RID rejects malformed, unsupported epoch, or mismatched occurrence suffix")
        }
        for invalid in [
            event(.apple, "wrong-case", uid.lowercased() + "/RID=\(reference)"),
            event(.apple, "wrong-base", "other" + "/RID=\(reference)"),
            event(.apple, "wrong-delimiter", uid + "/rid=\(reference)"),
            event(.apple, "not-recurring", uid + "/RID=\(reference)", recurring: false),
            event(.apple, "wrong-recurrence", uid + "/RID=\(reference)", recurrence: "instant:\(unix + 1)")
        ] {
            expect(LifeRouteCalendarCanonicalizer.canonicalEvents(from: [invalid, google]).count == 2, "RID rejects case, base, delimiter, recurrence or classification mismatch")
        }
        var allDay = apple; allDay.isAllDay = true
        expect(LifeRouteCalendarCanonicalizer.canonicalEvents(from: [allDay, google]).count == 2, "RID never aliases all-day identity")
        let sameProvider = event(.apple, "apple-base", uid)
        expect(LifeRouteCalendarCanonicalizer.canonicalEvents(from: [apple, sameProvider]).count == 2, "RID never merges within one provider")
        let third = event(.apple, "apple-exact", uid)
        let thirdGoogle = event(.google, "google-suffix", uid + "/RID=\(reference)")
        for ambiguous in [[apple, google, third], [apple, google, thirdGoogle], [apple, google, event(.google, "second-account", uid)]] {
            for ordered in permutations(ambiguous) {
                expect(LifeRouteCalendarCanonicalizer.canonicalEvents(from: ordered) == ordered, "RID exact plus alias overlap retains entire ambiguous group")
            }
        }
        let distinct = event(.google, "distinct", "separate-series")
        expect(LifeRouteCalendarCanonicalizer.canonicalEvents(from: [apple, distinct]).count == 2, "RID same title/time/location does not establish identity")
    }

    private static func permutations<T>(_ values: [T]) -> [[T]] {
        guard !values.isEmpty else { return [[]] }
        return values.indices.flatMap { index in
            var remainder = values; let first = remainder.remove(at: index)
            return permutations(remainder).map { [first] + $0 }
        }
    }

    @MainActor
    private static func exactCrossProviderDuplicate() throws {
        let start = date("2026-09-09T14:00:00Z")
        let apple = providerEvent(
            source: .apple,
            id: "apple-event-1",
            externalIdentifier: "shared-appointment-1@example.com",
            start: start,
            title: "Appointment (Apple copy)",
            modifiedAt: date("2026-09-09T12:00:00Z")
        )
        let google = providerEvent(
            source: .google,
            id: "google-event-1",
            externalIdentifier: "shared-appointment-1@example.com",
            start: start.addingTimeInterval(15 * 60),
            title: "Appointment",
            modifiedAt: date("2026-09-09T13:00:00Z")
        )

        LifeRoutePersistenceStore.shared.reset()
        let state = CalendarCoreState(now: start)
        state.replaceProviderEvents([apple], source: .apple)
        state.replaceProviderEvents([google], source: .google)

        expect(state.rawProviderEvents.count == 2, "B1 raw Apple and Google records remain available")
        expect(Set(state.rawProviderEvents) == Set([apple, google]), "B1 raw provider records remain unchanged")
        expect(LifeRoutePersistenceStore.shared.providerEvents.count == 2, "B1 persistence retains both raw provider records")
        expect(state.events.count == 1, "B1 canonical schedule contains one appointment")
        expect(state.events(on: google.start).count == 1, "B1 Calendar-facing day contains one appointment")
        expect(state.events[0].id == google.id, "B1 newer provider update supplies the canonical record without mutating raw identity")
        expect(state.events[0].title == google.title && state.events[0].start == google.start, "B1 canonical fields come from the newest provider update")
        expect(state.presentation(for: .day).eventCount == 1, "B1 Calendar presentation count is one")

        let encoded = try JSONEncoder().encode(apple)
        let decoded = try JSONDecoder().decode(LifeRouteCalendarEvent.self, from: encoded)
        expect(decoded == apple, "B1 provider identity metadata round-trips without changing the raw event")
    }

    @MainActor
    private static func multipleDuplicatePairs() {
        let base = date("2026-09-09T14:00:00Z")
        var records: [LifeRouteCalendarEvent] = []
        for index in 0..<3 {
            let start = base.addingTimeInterval(TimeInterval(index * 7_200))
            let identifier = "shared-pair-\(index)@example.com"
            records.append(providerEvent(source: .apple, id: "apple-\(index)", externalIdentifier: identifier, start: start))
            records.append(providerEvent(source: .google, id: "google-\(index)", externalIdentifier: identifier, start: start))
        }

        let state = makeState(with: records, now: base)
        expect(state.rawProviderEvents.count == 6, "B2 six raw records remain")
        expect(state.events.count == 3, "B2 three Apple and Google pairs become three canonical appointments")
        expect(state.presentation(for: .day).eventCount == 3, "B2 Calendar day projection preserves all three pairs occurring on the selected day")
        expect(Set(state.events.map(\.source)) == [.google], "B2 deterministic tie-breaking is stable across every exact pair")
    }

    @MainActor
    private static func distinctEventsDoNotMerge() {
        let start = date("2026-09-10T15:00:00Z")
        let apple = providerEvent(
            source: .apple,
            id: "apple-similar",
            externalIdentifier: "genuine-event-a@example.com",
            start: start,
            title: "Same title",
            location: "10 Same Street"
        )
        let google = providerEvent(
            source: .google,
            id: "google-similar",
            externalIdentifier: "genuine-event-b@example.com",
            start: start,
            title: "Same title",
            location: "10 Same Street"
        )
        let state = makeState(with: [apple, google], now: start)
        expect(state.events.count == 2, "B3 title, time, and location alone never merge distinct appointments")
        expect(Set(state.events.map(\.id)) == Set([apple.id, google.id]), "B3 both distinct provider identities survive")

        let ambiguousSecondApple = providerEvent(
            source: .apple,
            id: "apple-ambiguous-copy",
            externalIdentifier: "ambiguous-shared@example.com",
            start: start
        )
        let ambiguousFirstApple = providerEvent(
            source: .apple,
            id: "apple-ambiguous-original",
            externalIdentifier: "ambiguous-shared@example.com",
            start: start
        )
        let ambiguousGoogle = providerEvent(
            source: .google,
            id: "google-ambiguous",
            externalIdentifier: "ambiguous-shared@example.com",
            start: start
        )
        let ambiguous = makeState(with: [ambiguousFirstApple, ambiguousSecondApple, ambiguousGoogle], now: start)
        expect(ambiguous.events.count == 3, "B3 an identity group with multiple records from one provider is not guessed into one appointment")

        let caseDistinct = makeState(with: [
            providerEvent(source: .apple, id: "apple-case", externalIdentifier: "Case-Sensitive@example.com", start: start),
            providerEvent(source: .google, id: "google-case", externalIdentifier: "case-sensitive@example.com", start: start),
        ], now: start)
        expect(caseDistinct.events.count == 2, "B3 external identifiers remain exact and case-sensitive")

        let missingIdentity = makeState(with: [
            providerEvent(source: .apple, id: "apple-identified", externalIdentifier: "one-sided@example.com", start: start),
            providerEvent(source: .google, id: "google-unidentified", externalIdentifier: nil, start: start),
        ], now: start)
        expect(missingIdentity.events.count == 2, "B3 one-sided identity evidence never falls back to fuzzy matching")
    }

    @MainActor
    private static func recurrenceInstanceSafety() {
        let firstStart = date("2026-09-11T14:00:00Z")
        let secondStart = date("2026-09-18T14:00:00Z")
        let seriesIdentifier = "recurring-series@example.com"
        let firstOccurrence = "instant:1789135200"
        let secondOccurrence = "instant:1789740000"
        let records = [
            providerEvent(source: .apple, id: "apple-r1", externalIdentifier: seriesIdentifier, recurrenceIdentifier: firstOccurrence, isRecurring: true, start: firstStart),
            providerEvent(source: .google, id: "google-r1", externalIdentifier: seriesIdentifier, recurrenceIdentifier: firstOccurrence, isRecurring: true, start: firstStart),
            providerEvent(source: .apple, id: "apple-r2", externalIdentifier: seriesIdentifier, recurrenceIdentifier: secondOccurrence, isRecurring: true, start: secondStart),
            providerEvent(source: .google, id: "google-r2", externalIdentifier: seriesIdentifier, recurrenceIdentifier: secondOccurrence, isRecurring: true, start: secondStart),
        ]
        let state = makeState(with: records, now: firstStart)
        expect(state.rawProviderEvents.count == 4, "B4 all recurring provider instances remain raw")
        expect(state.events.count == 2, "B4 matching cross-provider recurring instances collapse independently")
        expect(state.events(on: firstStart).count == 1, "B4 first occurrence remains once")
        expect(state.events(on: secondStart).count == 1, "B4 different occurrence remains separately once")

        let missingInstance = makeState(with: [
            providerEvent(source: .apple, id: "apple-r-missing", externalIdentifier: seriesIdentifier, recurrenceIdentifier: nil, isRecurring: true, start: firstStart),
            providerEvent(source: .google, id: "google-r-missing", externalIdentifier: seriesIdentifier, recurrenceIdentifier: firstOccurrence, isRecurring: true, start: firstStart),
        ], now: firstStart)
        expect(missingInstance.events.count == 2, "B4 recurring records without complete instance identity are not merged")
    }

    @MainActor
    private static func providerOnlyControls() {
        let start = date("2026-09-12T16:00:00Z")
        let apple = providerEvent(source: .apple, id: "apple-only", externalIdentifier: "apple-only@example.com", start: start)
        let google = providerEvent(source: .google, id: "google-only", externalIdentifier: "google-only@example.com", start: start.addingTimeInterval(3_600))
        let state = makeState(with: [apple, google], now: start)
        expect(state.events.filter { $0.source == .apple }.count == 1, "B5 Apple-only event remains exactly once")
        expect(state.events.filter { $0.source == .google }.count == 1, "B5 Google-only event remains exactly once")
        expect(state.rawProviderEvents.count == state.events.count, "B5 canonicalization does not alter unrelated provider-only counts")
    }

    @MainActor
    private static func downstreamPlannerControl() {
        let start = date("2026-09-13T14:00:00Z")
        let identifier = "planner-pair@example.com"
        let state = makeState(with: [
            providerEvent(source: .apple, id: "apple-planner", externalIdentifier: identifier, start: start, location: "1 Route Street"),
            providerEvent(source: .google, id: "google-planner", externalIdentifier: identifier, start: start, location: "1 Route Street"),
        ], now: start)
        let appointments = state.events(on: start).map {
            LifeRouteRouteAppointment(
                id: $0.id,
                title: $0.title,
                address: $0.location,
                start: $0.start,
                end: $0.end,
                isAllDay: $0.isAllDay
            )
        }
        let waypoints = LifeRouteDaySequenceBuilder.waypoints(
            appointments: appointments,
            beforeStops: [],
            afterStops: []
        )
        expect(appointments.count == 1, "B6 Today maps a duplicate pair to one fixed planner appointment")
        expect(waypoints.filter { $0.kind == .appointment }.count == 1, "B6 route sequencing receives one appointment destination")
        expect(waypoints.count == 1, "B6 one routable canonical appointment produces one outbound route destination, not two")
    }

    @MainActor
    private static func existingBehaviorRegression() throws {
        let first = date("2026-09-14T09:00:00Z")
        let second = date("2026-09-14T11:00:00Z")
        let nextDay = date("2026-09-15T09:00:00Z")
        let events = [
            providerEvent(source: .google, id: "later", externalIdentifier: nil, start: second, title: "Later"),
            LifeRouteCalendarEvent(id: "manual", title: "Manual", start: nextDay, end: nextDay.addingTimeInterval(1_800), source: .manual),
            providerEvent(source: .apple, id: "earlier", externalIdentifier: nil, start: first, title: "Earlier"),
        ]
        let state = CalendarCoreState(now: first, events: events)
        expect(state.events.map(\.id) == ["earlier", "later", "manual"], "B7 unrelated chronological ordering remains unchanged")
        expect(state.events(on: first).map(\.id) == ["earlier", "later"], "B7 same-day indexing remains unchanged")
        expect(state.events(on: nextDay).map(\.id) == ["manual"], "B7 date boundaries remain unchanged")
        expect(state.events[0].durationMinutes == 60, "B7 timed duration behavior remains unchanged")

        let legacy = LegacyCalendarEvent(
            id: "legacy-provider",
            title: "Legacy provider event",
            start: first,
            end: first.addingTimeInterval(3_600),
            location: "Legacy Street",
            calendarTitle: "Legacy Calendar",
            isAllDay: false,
            source: .apple
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(LifeRouteCalendarEvent.self, from: encoder.encode(legacy))
        expect(decoded.providerIdentity == nil && decoded.id == legacy.id, "B7 existing persisted events decode without a migration")
    }

    @MainActor
    private static func makeState(with records: [LifeRouteCalendarEvent], now: Date) -> CalendarCoreState {
        LifeRoutePersistenceStore.shared.reset(providerEvents: records)
        return CalendarCoreState(now: now)
    }

    private static func providerEvent(
        source: LifeRouteCalendarSource,
        id: String,
        externalIdentifier: String?,
        recurrenceIdentifier: String? = nil,
        isRecurring: Bool = false,
        start: Date,
        title: String = "Appointment",
        location: String = "1 Main Street",
        modifiedAt: Date? = nil
    ) -> LifeRouteCalendarEvent {
        LifeRouteCalendarEvent(
            id: id,
            title: title,
            start: start,
            end: start.addingTimeInterval(3_600),
            location: location,
            calendarTitle: source == .apple ? "Apple Calendar" : "Google Calendar",
            source: source,
            providerIdentity: LifeRouteCalendarProviderIdentity(
                eventIdentifier: id,
                externalIdentifier: externalIdentifier,
                recurrenceIdentifier: recurrenceIdentifier,
                isRecurring: isRecurring,
                calendarIdentifier: "\(source.rawValue)-calendar",
                accountIdentifier: "\(source.rawValue)-account",
                timeZoneIdentifier: "America/New_York",
                modifiedAt: modifiedAt,
                revision: source == .google ? 1 : nil
            )
        )
    }

    private static func date(_ value: String) -> Date {
        guard let result = ISO8601DateFormatter().date(from: value) else {
            fatalError("Invalid fixture date: \(value)")
        }
        return result
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertionCount += 1
        guard condition() else {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }

    private struct LegacyCalendarEvent: Encodable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let location: String
        let calendarTitle: String
        let isAllDay: Bool
        let source: LifeRouteCalendarSource
    }
}
