// Observed Cat food fields are unchanged. UUID and unused optional fields are
// test metadata, not a recovered phone database. Route/MapKit inputs are controlled.
@MainActor final class GapChecks {
    var count = 0
    var failures = 0
    func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        count += 1
        if !condition() { failures += 1; print("FAIL: \(message)") }
    }
    func settle(_ predicate: () -> Bool) async {
        for _ in 0..<10_000 {
            if predicate() { return }
            await Task.yield()
        }
        fatalError("Bounded endpoint did not settle")
    }
    func flush() async { for _ in 0..<100 { await Task.yield() } }
    func date(_ day: Int, hour: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }
    func run() async throws {
        let core = DayRoutePlanningCore()
        let appointments = [
            LifeRouteRouteAppointment(id: "previous", title: "Controlled previous appointment", address: "Controlled origin",
                start: date(10, hour: 8), end: date(10, hour: 9), isAllDay: false),
            LifeRouteRouteAppointment(id: "next", title: "Controlled next appointment", address: "Controlled destination",
                start: date(10, hour: 12), end: date(10, hour: 13), isAllDay: false)
        ]
        core.calculate(selectedDay: date(10), appointments: appointments, beforeStops: [], afterStops: [],
                       routeBufferMinutes: 10, homeAddress: "Controlled home", currentLocation: nil)
        await settle { !core.isCalculating }
        let itinerary = core.generatedItinerary!
        let gap = itinerary.usableGaps.first!
        expect(gap.isRouteSafe && gap.usableSeconds! > 900, "controlled long gap is route safe")

        // Actual observed values first; no clean/normalized replacement record.
        let observed = LifeRouteTodo(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: "Cat food", category: .errand, durationMinutes: 15, savedPlaceID: nil,
            address: "Any Walmart", priority: .normal, dueDate: date(15), notes: "", completed: false)
        let encoded = try JSONEncoder().encode(observed)
        let actualFields = try JSONDecoder().decode(LifeRouteTodo.self, from: encoded)
        expect(actualFields.title == "Cat food" && actualFields.category == .errand, "observed title and category decode unchanged")
        expect(actualFields.durationMinutes == 15 && actualFields.priority == .normal, "observed duration and priority decode unchanged")
        expect(actualFields.address == "Any Walmart" && !actualFields.completed, "observed flexible address and active state decode unchanged")
        expect(actualFields.dueDate == date(15), "observed due date retained")
        func recommendations() -> [LifeRouteGapFillerRecommendation] { core.gapRecommendationsByGapID[gap.id] ?? [] }
        func evaluate(_ todos: [LifeRouteTodo], places: [LifeRouteSavedPlace] = []) async {
            core.evaluateGapFillers(for: gap, itinerary: itinerary, savedPlaces: places, todos: todos)
            await settle { !core.gapEvaluationInFlight.contains(gap.id) }
        }
        await evaluate([actualFields])
        expect(DayRoutePlanningCore.fixtureQueries.contains("Any Walmart"), "actual future-deadline errand reaches location evaluation on Sep10")
        expect(recommendations().map(\.title) == ["Cat food"], "fitting actual record reaches selected recommendations before deadline")
        expect(recommendations().first?.durationMinutes == 15 && recommendations().first?.address == "Any Walmart", "published candidate preserves actual duration and address")
        expect(recommendations().first?.fit.state == .fits, "published actual candidate passes travel and duration checks")

        // Hidden exact due-time is immaterial: test both boundaries of its displayed day.
        var endOfDueDay = actualFields
        endOfDueDay.dueDate = date(16).addingTimeInterval(-0.001)
        await evaluate([endOfDueDay])
        expect(recommendations().map(\.title) == ["Cat food"], "unknown exact due-time does not become an earliest-eligible date")
        var completed = actualFields
        completed.completed = true
        await evaluate([completed])
        expect(recommendations().isEmpty, "completed errand remains excluded")

        DayRoutePlanningCore.fixtureTravelSeconds = 6_000
        await evaluate([actualFields])
        expect(recommendations().isEmpty, "travel infeasibility still excludes future-deadline errand")
        DayRoutePlanningCore.fixtureTravelSeconds = 300
        DayRoutePlanningCore.fixtureFailLocation = true
        await evaluate([actualFields])
        expect(recommendations().isEmpty, "location failure cannot publish an unproven fitting recommendation")
        DayRoutePlanningCore.fixtureFailLocation = false
        await evaluate([actualFields])
        expect(recommendations().map(\.title) == ["Cat food"], "retry after endpoint failure recomputes recommendation")

        DayRoutePlanningCore.fixtureSuspended = true
        core.evaluateGapFillers(for: gap, itinerary: itinerary, savedPlaces: [], todos: [actualFields])
        await settle { DayRoutePlanningCore.fixtureIsWaiting || core.gapEvaluationInFlight.isEmpty }
        core.cancel()
        DayRoutePlanningCore.fixtureSuspended = false
        DayRoutePlanningCore.resumeFixtureRoute()
        await flush()
        expect(recommendations().isEmpty, "cancelled evaluation cannot publish late candidate")
        await evaluate([actualFields])
        expect(recommendations().map(\.title) == ["Cat food"], "retry after cancellation succeeds")
        let first = recommendations()
        await evaluate([actualFields])
        expect(recommendations() == first, "same record and endpoint values produce deterministic selected candidates")
        print("LIMIT: fixture uses actual displayed fields, not recovered raw phone bytes or original route geometry.")
    }
}

@main struct GapTestMain {
    @MainActor static func main() async throws {
        let checks = GapChecks()
        try await checks.run()
        print("CORE_PRODUCT_REPAIR \(checks.failures == 0 ? "PASS" : "FAIL"): \(checks.count) assertions; \(checks.failures) failed")
        exit(checks.failures == 0 ? 0 : 1)
    }
}
