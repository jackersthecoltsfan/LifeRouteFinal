import Foundation

@MainActor
final class LifeRoutePersistenceStore {
    static let shared = LifeRoutePersistenceStore()

    private(set) var manualEvents: [LifeRouteCalendarEvent] = []
    private(set) var providerEvents: [LifeRouteCalendarEvent] = []
    private(set) var manualSaveCount = 0

    func reset(
        manualEvents: [LifeRouteCalendarEvent] = [],
        providerEvents: [LifeRouteCalendarEvent] = []
    ) {
        self.manualEvents = manualEvents
        self.providerEvents = providerEvents
        manualSaveCount = 0
    }

    func loadManualCalendarEvents() -> [LifeRouteCalendarEvent] { manualEvents }
    func loadProviderCalendarEvents() -> [LifeRouteCalendarEvent] { providerEvents }

    func saveManualCalendarEvents(_ events: [LifeRouteCalendarEvent]) {
        manualEvents = events
        manualSaveCount += 1
    }

    func saveProviderCalendarEvents(_ events: [LifeRouteCalendarEvent]) {
        providerEvents = events
    }
}

@main
struct CalendarEditContractTests {
    private static var assertionCount = 0

    @MainActor
    static func main() throws {
        let calendar = Calendar(identifier: .gregorian)
        let firstDay = date("2026-09-01T12:00:00Z")
        let secondDay = date("2026-09-02T12:00:00Z")
        let provider = LifeRouteCalendarEvent(
            id: "provider-1",
            title: "Provider event",
            start: firstDay,
            end: firstDay.addingTimeInterval(3_600),
            location: "1 Provider Street",
            source: .apple
        )
        LifeRoutePersistenceStore.shared.reset(providerEvents: [provider])

        let state = CalendarCoreState(now: firstDay)
        try state.addManualEvent(
            title: "Original title",
            date: firstDay,
            startTime: date("2026-09-01T14:00:00Z"),
            endTime: date("2026-09-01T15:00:00Z"),
            location: "1 First Street",
            isAllDay: false
        )
        try state.addManualEvent(
            title: "Unrelated",
            date: firstDay,
            startTime: date("2026-09-01T16:00:00Z"),
            endTime: date("2026-09-01T17:00:00Z"),
            location: "2 Other Street",
            isAllDay: false
        )
        let original = state.events.first { $0.title == "Original title" }!
        let unrelated = state.events.first { $0.title == "Unrelated" }!

        let updated = try state.updateManualEvent(
            id: original.id,
            title: "Updated title",
            date: secondDay,
            startTime: date("2026-09-02T09:30:00Z"),
            endTime: date("2026-09-02T11:00:00Z"),
            location: "3 Updated Street",
            isAllDay: false
        )
        expect(updated.id == original.id, "manual update preserves identity")
        expect(updated.source == .manual, "manual update preserves manual source")
        expect(state.events.filter { $0.id == original.id }.count == 1, "manual update never duplicates the event")
        expect(state.events.contains { $0 == unrelated }, "manual update retains unrelated manual events")
        expect(state.events.contains { $0 == provider }, "manual update retains provider events")
        expect(updated.title == "Updated title" && updated.location == "3 Updated Street", "manual update applies editable text fields")
        expect(calendar.isDate(updated.start, inSameDayAs: secondDay), "manual update moves the event to another date")
        expect(!state.events(on: firstDay).contains { $0.id == original.id }, "old day index drops a moved event")
        expect(state.events(on: secondDay).contains { $0.id == original.id }, "new day index receives a moved event")
        expect(calendar.isDate(state.selectedDate, inSameDayAs: secondDay), "saving selects the edited event date")
        expect(LifeRoutePersistenceStore.shared.manualEvents.filter { $0.id == original.id }.count == 1, "updated manual collection persists once without duplication")

        let restored = CalendarCoreState(now: firstDay)
        expect(restored.events.first { $0.id == original.id } == updated, "updated manual event restores from persistence")
        expect(restored.events.contains { $0 == unrelated }, "state reconstruction retains unrelated manual events")
        expect(restored.events.contains { $0 == provider }, "state reconstruction restores provider events independently")

        let allDay = try restored.updateManualEvent(
            id: original.id,
            title: "All-day title",
            date: secondDay,
            startTime: updated.start,
            endTime: updated.end,
            location: "3 Updated Street",
            isAllDay: true
        )
        let expectedStart = calendar.startOfDay(for: secondDay)
        let expectedEnd = calendar.date(byAdding: .day, value: 1, to: expectedStart)!
        expect(allDay.isAllDay, "manual update converts a timed event to all day")
        expect(allDay.start == expectedStart && allDay.end == expectedEnd, "all-day update uses the complete selected-day interval")

        let snapshotBeforeInvalidEdits = restored.events
        let savesBeforeInvalidEdits = LifeRoutePersistenceStore.shared.manualSaveCount
        expectThrows(.missingTitle, "empty-title update is rejected") {
            try restored.updateManualEvent(
                id: original.id,
                title: "   ",
                date: secondDay,
                startTime: updated.start,
                endTime: updated.end,
                location: "",
                isAllDay: false
            )
        }
        expectThrows(.invalidTimeRange, "invalid timed update is rejected") {
            try restored.updateManualEvent(
                id: original.id,
                title: "Still valid",
                date: secondDay,
                startTime: date("2026-09-02T12:00:00Z"),
                endTime: date("2026-09-02T11:00:00Z"),
                location: "",
                isAllDay: false
            )
        }
        expect(restored.events == snapshotBeforeInvalidEdits, "invalid edits do not mutate events")
        expect(LifeRoutePersistenceStore.shared.manualSaveCount == savesBeforeInvalidEdits, "invalid edits are not persisted")

        expectThrows(.providerEventReadOnly, "provider-event update is explicitly rejected") {
            try restored.updateManualEvent(
                id: provider.id,
                title: "Mutated provider",
                date: firstDay,
                startTime: provider.start,
                endTime: provider.end,
                location: provider.location,
                isAllDay: false
            )
        }
        expect(restored.events.contains { $0 == provider }, "provider-event rejection leaves provider data unchanged")
        expect(!restored.removeEvent(id: provider.id), "provider-event deletion is rejected")
        expect(restored.events.contains { $0 == provider }, "provider event remains after delete attempt")

        expect(restored.removeEvent(id: original.id), "selected manual event can be deleted")
        expect(!restored.events.contains { $0.id == original.id && $0.source == .manual }, "manual deletion removes only the selected event")
        expect(restored.events.contains { $0 == unrelated }, "manual deletion retains unrelated manual events")
        expect(restored.events.contains { $0 == provider }, "manual deletion retains provider events")
        let deletedRestore = CalendarCoreState(now: firstDay)
        expect(!deletedRestore.events.contains { $0.id == original.id && $0.source == .manual }, "manual deletion persists across reconstruction")

        precondition(assertionCount >= 29, "Calendar Edit regression floor requires at least 29 assertions; found \(assertionCount).")
        print("Calendar Edit executable contract fixtures passed (\(assertionCount) assertions).")
    }

    @MainActor
    private static func expectThrows(
        _ expected: CalendarCoreError,
        _ message: String,
        operation: () throws -> Void
    ) {
        do {
            try operation()
            expect(false, message)
        } catch let error as CalendarCoreError {
            expect(error == expected, message)
        } catch {
            expect(false, message)
        }
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
}
