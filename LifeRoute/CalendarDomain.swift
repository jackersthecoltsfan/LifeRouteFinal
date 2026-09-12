import Foundation
#if canImport(Combine)
import Combine
#endif

/// Presentation only: provider titles, persisted data and route fingerprints stay raw.
enum LifeRouteCalendarDisplay {
    private static let misplacedPossessive = try? NSRegularExpression(pattern: #"(?<=\p{L})[ \t]+(['’]s)(?=\s|$)"#)

    static func title(_ value: String) -> String {
        guard let expression = misplacedPossessive else { return value }
        return expression.stringByReplacingMatches(
            in: value, range: NSRange(value.startIndex..., in: value), withTemplate: "$1"
        )
    }
}

enum LifeRouteCalendarSource: String, Codable, CaseIterable, Hashable {
    case manual
    case apple
    case google
    case calendarLink
}

/// Provider metadata retained with each raw imported event. Calendar and route
/// consumers continue to use `LifeRouteCalendarEvent`; this metadata only gives
/// the upstream projection enough exact identity to recognize the same event
/// arriving through two providers.
struct LifeRouteCalendarProviderIdentity: Codable, Hashable {
    let eventIdentifier: String
    let externalIdentifier: String?
    let recurrenceIdentifier: String?
    let isRecurring: Bool
    let calendarIdentifier: String
    let accountIdentifier: String?
    let timeZoneIdentifier: String?
    let modifiedAt: Date?
    let revision: Int?
}

enum LifeRouteCalendarRange: String, CaseIterable, Identifiable, Hashable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var id: Self { self }
}

struct LifeRouteCalendarEvent: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var start: Date
    var end: Date
    var location: String
    var calendarTitle: String
    var isAllDay: Bool
    var source: LifeRouteCalendarSource
    var providerIdentity: LifeRouteCalendarProviderIdentity?

    init(
        id: String = UUID().uuidString,
        title: String,
        start: Date,
        end: Date,
        location: String = "",
        calendarTitle: String = "",
        isAllDay: Bool = false,
        source: LifeRouteCalendarSource = .manual,
        providerIdentity: LifeRouteCalendarProviderIdentity? = nil
    ) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.title = cleanTitle.isEmpty ? "Untitled event" : cleanTitle
        self.start = start
        self.end = max(start, end)
        self.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        self.calendarTitle = calendarTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isAllDay = isAllDay
        self.source = source
        self.providerIdentity = providerIdentity
    }

    var displayTitle: String { LifeRouteCalendarDisplay.title(title) }

    var durationMinutes: Int {
        guard !isAllDay else { return 0 }
        return max(0, Int(end.timeIntervalSince(start) / 60))
    }
}

enum LifeRouteCalendarCanonicalizer {
    private struct CrossProviderKey: Hashable {
        let externalIdentifier: String
        let occurrence: String
    }

    /// Returns a non-destructive projection. Ambiguous identity groups and all
    /// events without exact provider identity pass through unchanged.
    static func canonicalEvents(from rawEvents: [LifeRouteCalendarEvent]) -> [LifeRouteCalendarEvent] {
        var indicesByKey: [CrossProviderKey: [Int]] = [:]
        for (index, event) in rawEvents.enumerated() {
            guard let key = crossProviderKey(for: event) else { continue }
            indicesByKey[key, default: []].append(index)
        }

        // Join identity groups before applying uniqueness. An exact pair plus a
        // representation alias is still ambiguous and must retain all records.
        var parent = Array(rawEvents.indices)
        func root(_ index: Int) -> Int {
            var result = index
            while parent[result] != result { result = parent[result] }
            return result
        }
        func join(_ first: Int, _ second: Int) {
            let left = root(first), right = root(second)
            if left != right { parent[right] = left }
        }
        for indices in indicesByKey.values {
            guard let first = indices.first else { continue }
            for index in indices.dropFirst() { join(first, index) }
        }
        var googleByKey: [CrossProviderKey: [Int]] = [:]
        for (index, event) in rawEvents.enumerated() where event.source == .google {
            guard let key = strictTimedOccurrenceKey(for: event) else { continue }
            googleByKey[key, default: []].append(index)
        }
        for (index, event) in rawEvents.enumerated() where event.source == .apple {
            guard let alias = observedAppleOccurrenceAlias(for: event) else { continue }
            for googleIndex in googleByKey[alias] ?? [] { join(index, googleIndex) }
        }
        var indicesByIdentity: [Int: [Int]] = [:]
        for index in rawEvents.indices { indicesByIdentity[root(index), default: []].append(index) }

        var replacements: [Int: LifeRouteCalendarEvent] = [:]
        var suppressedIndices = Set<Int>()
        for indices in indicesByIdentity.values {
            guard indices.count == 2 else { continue }
            let appleIndices = indices.filter { rawEvents[$0].source == .apple }
            let googleIndices = indices.filter { rawEvents[$0].source == .google }
            guard appleIndices.count == 1, googleIndices.count == 1 else { continue }

            let firstIndex = min(appleIndices[0], googleIndices[0])
            replacements[firstIndex] = preferredCanonicalEvent(
                apple: rawEvents[appleIndices[0]],
                google: rawEvents[googleIndices[0]]
            )
            suppressedIndices.formUnion(indices.filter { $0 != firstIndex })
        }

        return rawEvents.enumerated().compactMap { index, event in
            if let replacement = replacements[index] { return replacement }
            return suppressedIndices.contains(index) ? nil : event
        }
    }

    private static func crossProviderKey(for event: LifeRouteCalendarEvent) -> CrossProviderKey? {
        guard event.source == .apple || event.source == .google,
              let identity = event.providerIdentity else { return nil }
        let externalIdentifier = identity.externalIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !externalIdentifier.isEmpty else { return nil }

        if identity.isRecurring {
            let recurrenceIdentifier = identity.recurrenceIdentifier?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !recurrenceIdentifier.isEmpty else { return nil }
            return CrossProviderKey(
                externalIdentifier: externalIdentifier,
                occurrence: "recurring:\(recurrenceIdentifier)"
            )
        }
        return CrossProviderKey(externalIdentifier: externalIdentifier, occurrence: "single")
    }

    /// Empirical adapter for the QA-observed representation only; not a general
    /// EventKit suffix rule. The exact base UID and both occurrence instants must
    /// agree. No title, current start time, location or account label is evidence.
    private static func observedAppleOccurrenceAlias(for event: LifeRouteCalendarEvent) -> CrossProviderKey? {
        guard let original = strictTimedOccurrenceKey(for: event),
              let identity = event.providerIdentity,
              let occurrence = identity.recurrenceIdentifier else { return nil }
        let pieces = original.externalIdentifier.components(separatedBy: "/RID=")
        guard pieces.count == 2, !pieces[0].isEmpty,
              pieces[1].utf8.count == 9,
              pieces[1].utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              let referenceSeconds = Int64(pieces[1]),
              occurrence == "instant:\(referenceSeconds + 978_307_200)" else { return nil }
        return CrossProviderKey(externalIdentifier: pieces[0], occurrence: original.occurrence)
    }

    private static func strictTimedOccurrenceKey(for event: LifeRouteCalendarEvent) -> CrossProviderKey? {
        guard !event.isAllDay, let identity = event.providerIdentity, identity.isRecurring,
              !identity.eventIdentifier.isEmpty, !identity.calendarIdentifier.isEmpty,
              let uid = identity.externalIdentifier, !uid.isEmpty,
              uid == uid.trimmingCharacters(in: .whitespacesAndNewlines),
              let occurrence = identity.recurrenceIdentifier,
              occurrence.hasPrefix("instant:") else { return nil }
        let seconds = String(occurrence.dropFirst("instant:".count))
        guard !seconds.isEmpty, seconds.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              let instant = Int64(seconds), seconds == String(instant) else { return nil }
        return CrossProviderKey(externalIdentifier: uid, occurrence: "recurring:\(occurrence)")
    }

    private static func preferredCanonicalEvent(
        apple: LifeRouteCalendarEvent,
        google: LifeRouteCalendarEvent
    ) -> LifeRouteCalendarEvent {
        if let appleModified = apple.providerIdentity?.modifiedAt,
           let googleModified = google.providerIdentity?.modifiedAt,
           appleModified != googleModified {
            return appleModified > googleModified ? apple : google
        }
        // The direct Google record is deterministic when update timestamps are
        // equal or unavailable. No title/time/location heuristic participates.
        return google
    }
}

struct LifeRouteCalendarDayEvents: Identifiable, Hashable {
    let date: Date
    let events: [LifeRouteCalendarEvent]

    var id: Date { date }
}

struct LifeRouteCalendarRangePresentation: Hashable {
    let range: LifeRouteCalendarRange
    let days: [LifeRouteCalendarDayEvents]
    let visibleEvents: [LifeRouteCalendarEvent]

    var eventCount: Int { visibleEvents.count }
    var timedMinutes: Int { visibleEvents.reduce(0) { $0 + $1.durationMinutes } }
}

enum CalendarCoreError: LocalizedError, Equatable {
    case missingTitle
    case invalidTimeRange
    case eventNotFound
    case providerEventReadOnly

    var errorDescription: String? {
        switch self {
        case .missingTitle:
            return "Enter an appointment title."
        case .invalidTimeRange:
            return "The end time must be after the start time."
        case .eventNotFound:
            return "This LifeRoute appointment is no longer available."
        case .providerEventReadOnly:
            return "This appointment is managed by its calendar provider and is read-only in LifeRoute."
        }
    }
}

@MainActor
final class CalendarCoreState: ObservableObject {
    @Published var selectedDate: Date
    @Published private(set) var events: [LifeRouteCalendarEvent]
    private(set) var rawProviderEvents: [LifeRouteCalendarEvent]

    private var calendar: Calendar
    private var eventIndicesByDay: [Date: [Int]] = [:]
    private var eventCountsBySource: [LifeRouteCalendarSource: Int] = [:]

    init(now: Date = Date(), events: [LifeRouteCalendarEvent]? = nil) {
        var configured = Calendar(identifier: .gregorian)
        configured.locale = .current
        configured.timeZone = .current
        configured.firstWeekday = 2
        configured.minimumDaysInFirstWeek = 4
        self.calendar = configured
        self.selectedDate = now

        if let events {
            let manualEvents = events.filter { $0.source == .manual }
            let providerEvents = events.filter { $0.source != .manual }
            self.rawProviderEvents = providerEvents
            self.events = (
                manualEvents + LifeRouteCalendarCanonicalizer.canonicalEvents(from: providerEvents)
            ).sorted(by: Self.eventSort)
        } else {
            let manualEvents = LifeRoutePersistenceStore.shared.loadManualCalendarEvents()
            let providerEvents = LifeRoutePersistenceStore.shared.loadProviderCalendarEvents()
            self.rawProviderEvents = providerEvents
            self.events = (
                manualEvents + LifeRouteCalendarCanonicalizer.canonicalEvents(from: providerEvents)
            ).sorted(by: Self.eventSort)
        }
        rebuildEventIndexes()
    }

    func addManualEvent(
        title: String,
        date: Date,
        startTime: Date,
        endTime: Date,
        location: String,
        isAllDay: Bool
    ) throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw CalendarCoreError.missingTitle }

        let start: Date
        let end: Date
        if isAllDay {
            start = calendar.startOfDay(for: date)
            end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        } else {
            start = combine(date: date, time: startTime)
            end = combine(date: date, time: endTime)
            guard end > start else { throw CalendarCoreError.invalidTimeRange }
        }

        events.append(
            LifeRouteCalendarEvent(
                title: cleanTitle,
                start: start,
                end: end,
                location: location,
                isAllDay: isAllDay,
                source: .manual
            )
        )
        events.sort(by: Self.eventSort)
        rebuildEventIndexes()
        selectedDate = date
        persistManualEvents()
    }

    @discardableResult
    func updateManualEvent(
        id: LifeRouteCalendarEvent.ID,
        title: String,
        date: Date,
        startTime: Date,
        endTime: Date,
        location: String,
        isAllDay: Bool
    ) throws -> LifeRouteCalendarEvent {
        guard let eventIndex = events.firstIndex(where: { $0.id == id && $0.source == .manual }) else {
            if events.contains(where: { $0.id == id && $0.source != .manual }) {
                throw CalendarCoreError.providerEventReadOnly
            }
            throw CalendarCoreError.eventNotFound
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw CalendarCoreError.missingTitle }

        let start: Date
        let end: Date
        if isAllDay {
            start = calendar.startOfDay(for: date)
            end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        } else {
            start = combine(date: date, time: startTime)
            end = combine(date: date, time: endTime)
            guard end > start else { throw CalendarCoreError.invalidTimeRange }
        }

        let existing = events[eventIndex]
        let updated = LifeRouteCalendarEvent(
            id: existing.id,
            title: cleanTitle,
            start: start,
            end: end,
            location: location,
            calendarTitle: existing.calendarTitle,
            isAllDay: isAllDay,
            source: .manual
        )
        events[eventIndex] = updated
        events.sort(by: Self.eventSort)
        rebuildEventIndexes()
        selectedDate = date
        persistManualEvents()
        return updated
    }

    func replaceProviderEvents(_ incoming: [LifeRouteCalendarEvent], source: LifeRouteCalendarSource) {
        guard source != .manual else { return }
        let nextRawProviderEvents = (
            rawProviderEvents.filter { $0.source != source }
                + incoming.filter { $0.source == source }
        )
        let nextEvents = (
            events.filter { $0.source == .manual }
                + LifeRouteCalendarCanonicalizer.canonicalEvents(from: nextRawProviderEvents)
        ).sorted(by: Self.eventSort)
        guard nextRawProviderEvents != rawProviderEvents || nextEvents != events else { return }
        rawProviderEvents = nextRawProviderEvents
        events = nextEvents
        rebuildEventIndexes()
        persistProviderEvents()
    }

    func removeProviderEvents(source: LifeRouteCalendarSource) {
        guard source != .manual else { return }
        let nextRawProviderEvents = rawProviderEvents.filter { $0.source != source }
        let nextEvents = (
            events.filter { $0.source == .manual }
                + LifeRouteCalendarCanonicalizer.canonicalEvents(from: nextRawProviderEvents)
        ).sorted(by: Self.eventSort)
        guard nextRawProviderEvents != rawProviderEvents || nextEvents != events else { return }
        rawProviderEvents = nextRawProviderEvents
        events = nextEvents
        rebuildEventIndexes()
        persistProviderEvents()
    }

    func eventCount(source: LifeRouteCalendarSource) -> Int {
        eventCountsBySource[source, default: 0]
    }

    @discardableResult
    func removeEvent(id: LifeRouteCalendarEvent.ID) -> Bool {
        let previousCount = events.count
        events.removeAll { $0.id == id && $0.source == .manual }
        if events.count != previousCount {
            rebuildEventIndexes()
            persistManualEvents()
            return true
        }
        return false
    }

    func events(on date: Date) -> [LifeRouteCalendarEvent] {
        (eventIndicesByDay[calendar.startOfDay(for: date)] ?? []).map { events[$0] }
    }

    func weekDates(containing date: Date? = nil) -> [Date] {
        let anchor = date ?? selectedDate
        let start = weekInterval(containing: anchor).start
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }

    func monthDates(containing date: Date? = nil) -> [Date] {
        let anchor = date ?? selectedDate
        guard let interval = calendar.dateInterval(of: .month, for: anchor),
              let dayRange = calendar.range(of: .day, in: .month, for: anchor) else { return [] }
        return dayRange.compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset - 1, to: interval.start)
        }
    }

    func activeDaysInSelectedMonth() -> [Date] {
        presentation(for: .month).days.map(\.date)
    }

    func timedMinutes(in range: LifeRouteCalendarRange) -> Int {
        presentation(for: range).timedMinutes
    }

    func visibleEvents(in range: LifeRouteCalendarRange) -> [LifeRouteCalendarEvent] {
        presentation(for: range).visibleEvents
    }

    func presentation(for range: LifeRouteCalendarRange) -> LifeRouteCalendarRangePresentation {
        let dates: [Date]
        switch range {
        case .day:
            dates = [selectedDate]
        case .week:
            dates = weekDates()
        case .month:
            dates = monthDates()
        }

        var visibleIndices = Set<Int>()
        var days = dates.map { date -> LifeRouteCalendarDayEvents in
            let indices = eventIndicesByDay[calendar.startOfDay(for: date)] ?? []
            visibleIndices.formUnion(indices)
            return LifeRouteCalendarDayEvents(date: date, events: indices.map { events[$0] })
        }
        if range == .month { days.removeAll { $0.events.isEmpty } }

        let visible = visibleIndices.sorted().map { events[$0] }
        return LifeRouteCalendarRangePresentation(range: range, days: days, visibleEvents: visible)
    }

    func periodLabel(for range: LifeRouteCalendarRange) -> String {
        switch range {
        case .day:
            return selectedDate.formatted(date: .abbreviated, time: .omitted)
        case .week:
            let dates = weekDates()
            guard let first = dates.first, let last = dates.last else { return "Week" }
            return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return selectedDate.formatted(.dateTime.month(.wide).year())
        }
    }

    func shiftSelection(_ range: LifeRouteCalendarRange, by amount: Int) {
        let component: Calendar.Component
        let value: Int
        switch range {
        case .day:
            component = .day
            value = amount
        case .week:
            component = .day
            value = amount * 7
        case .month:
            component = .month
            value = amount
        }
        selectedDate = calendar.date(byAdding: component, value: value, to: selectedDate) ?? selectedDate
    }

    func selectToday() {
        selectedDate = Date()
    }

    private func persistManualEvents() {
        LifeRoutePersistenceStore.shared.saveManualCalendarEvents(events.filter { $0.source == .manual })
    }

    private func persistProviderEvents() {
        LifeRoutePersistenceStore.shared.saveProviderCalendarEvents(rawProviderEvents)
    }

    private func rebuildEventIndexes() {
        var indicesByDay: [Date: [Int]] = [:]
        var countsBySource: [LifeRouteCalendarSource: Int] = [:]

        for (index, event) in events.enumerated() {
            countsBySource[event.source, default: 0] += 1
            var dayStart = calendar.startOfDay(for: event.start)

            while dayStart < event.end {
                let interval = dayInterval(containing: dayStart)
                if event.start < interval.end && event.end > interval.start {
                    indicesByDay[dayStart, default: []].append(index)
                }
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart),
                      nextDay > dayStart else { break }
                dayStart = nextDay
            }
        }

        eventIndicesByDay = indicesByDay
        eventCountsBySource = countsBySource
    }

    private func dayInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .day, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 86_400)
    }

    private func weekInterval(containing date: Date) -> DateInterval {
        if let interval = calendar.dateInterval(of: .weekOfYear, for: date) {
            return interval
        }
        let start = calendar.startOfDay(for: date)
        return DateInterval(start: start, duration: 7 * 86_400)
    }

    private func combine(date: Date, time: Date) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: date
        ) ?? date
    }

    private static func eventSort(_ lhs: LifeRouteCalendarEvent, _ rhs: LifeRouteCalendarEvent) -> Bool {
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}
