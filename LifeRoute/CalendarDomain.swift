import Foundation
import Combine

enum LifeRouteCalendarSource: String, Codable, CaseIterable, Hashable {
    case manual
    case apple
    case google
    case calendarLink
}

enum LifeRouteCalendarRange: String, CaseIterable, Identifiable {
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

    init(
        id: String = UUID().uuidString,
        title: String,
        start: Date,
        end: Date,
        location: String = "",
        calendarTitle: String = "",
        isAllDay: Bool = false,
        source: LifeRouteCalendarSource = .manual
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
    }

    var durationMinutes: Int {
        guard !isAllDay else { return 0 }
        return max(0, Int(end.timeIntervalSince(start) / 60))
    }
}

enum CalendarCoreError: LocalizedError {
    case missingTitle
    case invalidTimeRange

    var errorDescription: String? {
        switch self {
        case .missingTitle:
            return "Enter an appointment title."
        case .invalidTimeRange:
            return "The end time must be after the start time."
        }
    }
}

@MainActor
final class CalendarCoreState: ObservableObject {
    @Published var selectedDate: Date
    @Published private(set) var events: [LifeRouteCalendarEvent]

    private var calendar: Calendar

    init(now: Date = Date(), events: [LifeRouteCalendarEvent]? = nil) {
        var configured = Calendar(identifier: .gregorian)
        configured.locale = .current
        configured.timeZone = .current
        configured.firstWeekday = 2
        configured.minimumDaysInFirstWeek = 4
        self.calendar = configured
        self.selectedDate = now
        let restoredEvents = events ?? LifeRoutePersistenceStore.shared.loadManualCalendarEvents()
        self.events = restoredEvents.sorted(by: Self.eventSort)
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
        selectedDate = date
        persistManualEvents()
    }

    func replaceProviderEvents(_ incoming: [LifeRouteCalendarEvent], source: LifeRouteCalendarSource) {
        guard source != .manual else { return }
        events.removeAll { $0.source == source }
        events.append(contentsOf: incoming.filter { $0.source == source })
        events.sort(by: Self.eventSort)
    }

    func removeProviderEvents(source: LifeRouteCalendarSource) {
        guard source != .manual else { return }
        events.removeAll { $0.source == source }
    }

    func eventCount(source: LifeRouteCalendarSource) -> Int {
        events.filter { $0.source == source }.count
    }

    func removeEvent(id: LifeRouteCalendarEvent.ID) {
        let previousCount = events.count
        events.removeAll { $0.id == id && $0.source == .manual }
        if events.count != previousCount { persistManualEvents() }
    }

    func events(on date: Date) -> [LifeRouteCalendarEvent] {
        let interval = dayInterval(containing: date)
        return events.filter { event in
            event.start < interval.end && event.end > interval.start
        }
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
        monthDates().filter { !events(on: $0).isEmpty }
    }

    func timedMinutes(in range: LifeRouteCalendarRange) -> Int {
        visibleEvents(in: range).reduce(0) { $0 + $1.durationMinutes }
    }

    func visibleEvents(in range: LifeRouteCalendarRange) -> [LifeRouteCalendarEvent] {
        switch range {
        case .day:
            return events(on: selectedDate)
        case .week:
            let interval = weekInterval(containing: selectedDate)
            return events(overlapping: interval)
        case .month:
            guard let interval = calendar.dateInterval(of: .month, for: selectedDate) else { return [] }
            return events(overlapping: interval)
        }
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

    private func events(overlapping interval: DateInterval) -> [LifeRouteCalendarEvent] {
        events.filter { event in
            event.start < interval.end && event.end > interval.start
        }
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
