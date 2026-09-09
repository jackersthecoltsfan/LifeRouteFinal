@MainActor
final class PlannerAChecks {
    private(set) var count = 0
    private(set) var failures = 0

    private func expect(_ value: @autoclosure () -> Bool, _ label: String) {
        count += 1
        if !value() {
            failures += 1
            print("FAIL: \(label)")
        }
    }

    private func date(_ day: Int, hour: Int = 0) -> Date {
        Calendar.current.date(
            from: DateComponents(year: 2026, month: 9, day: day, hour: hour)
        )!
    }

    private func todo(
        _ title: String,
        address: String,
        minutes: Int = 10,
        dueDay: Int = 15
    ) -> LifeRouteTodo {
        LifeRouteTodo(
            title: title,
            category: .errand,
            durationMinutes: minutes,
            savedPlaceID: nil,
            address: address,
            priority: .normal,
            dueDate: date(dueDay),
            notes: ""
        )
    }

    private func appointments() -> [LifeRouteRouteAppointment] {
        [
            LifeRouteRouteAppointment(
                id: "previous",
                title: "Morning",
                address: "Home Street",
                start: date(10, hour: 9),
                end: date(10, hour: 10),
                isAllDay: false
            ),
            LifeRouteRouteAppointment(
                id: "next",
                title: "Noon",
                address: "Office Ave",
                start: date(10, hour: 12),
                end: date(10, hour: 13),
                isAllDay: false
            ),
        ]
    }

    private func duplicatedAppointments() -> [LifeRouteRouteAppointment] {
        [
            LifeRouteRouteAppointment(
                id: "apple-previous",
                title: "Duplicated morning",
                address: "Home Street",
                start: date(10, hour: 9),
                end: date(10, hour: 10),
                isAllDay: false
            ),
            LifeRouteRouteAppointment(
                id: "google-previous",
                title: "Duplicated morning",
                address: "Home Street",
                start: date(10, hour: 9),
                end: date(10, hour: 10),
                isAllDay: false
            ),
            LifeRouteRouteAppointment(
                id: "apple-next",
                title: "Duplicated noon",
                address: "Office Ave",
                start: date(10, hour: 12),
                end: date(10, hour: 13),
                isAllDay: false
            ),
            LifeRouteRouteAppointment(
                id: "google-next",
                title: "Duplicated noon",
                address: "Office Ave",
                start: date(10, hour: 12),
                end: date(10, hour: 13),
                isAllDay: false
            ),
        ]
    }

    private func settle(_ predicate: () -> Bool) async {
        for _ in 0..<10_000 {
            if predicate() { return }
            await Task.yield()
        }
        fatalError("Controlled Planner A endpoint did not settle")
    }

    private func makeCore(
        plannerAEnabled: Bool,
        appointments: [LifeRouteRouteAppointment]? = nil
    ) async -> (DayRoutePlanningCore, LifeRouteGeneratedItinerary, LifeRouteUsableGap) {
        let core = DayRoutePlanningCore(plannerAEnabled: plannerAEnabled)
        core.calculate(
            selectedDay: date(10),
            appointments: appointments ?? self.appointments(),
            beforeStops: [],
            afterStops: [],
            routeBufferMinutes: 10,
            homeAddress: "Home Base",
            currentLocation: nil
        )
        await settle { !core.isCalculating }
        let itinerary = core.generatedItinerary!
        let gap = itinerary.usableGaps.first { $0.isRouteSafe && $0.rawCalendarGapSeconds > 0 }!
        return (core, itinerary, gap)
    }

    private func recommendations(
        _ core: DayRoutePlanningCore,
        gap: LifeRouteUsableGap
    ) -> [LifeRouteGapFillerRecommendation] {
        core.gapRecommendationsByGapID[gap.id] ?? []
    }

    private func evaluate(
        _ core: DayRoutePlanningCore,
        gap: LifeRouteUsableGap,
        itinerary: LifeRouteGeneratedItinerary,
        todos: [LifeRouteTodo]
    ) async {
        core.evaluateGapFillers(
            for: gap,
            itinerary: itinerary,
            savedPlaces: [],
            todos: todos
        )
        await core.fixtureGapTask(gap.id)?.value
    }

    private func resetEndpoints() {
        DayRoutePlanningCore.fixtureQueries = []
        DayRoutePlanningCore.fixtureRouteQueries = []
        DayRoutePlanningCore.fixtureFailures = []
        DayRoutePlanningCore.fixtureLookupFailures = [:]
        DayRoutePlanningCore.fixtureRouteFailures = [:]
        DayRoutePlanningCore.fixtureTravelSeconds = 300
        DayRoutePlanningCore.fixtureSuspended = false
    }

    private func flagConfigurationContract() {
        let suiteName = "LifeRoutePlannerATests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let protectedKeys = [
            "liferoute.test.userTasks",
            "liferoute.test.rawAppleCalendar",
            "liferoute.test.rawGoogleCalendar",
            "liferoute.test.settings",
        ]
        for key in protectedKeys { defaults.set("protected", forKey: key) }
        for key in LifeRouteDevelopmentConfiguration.reconstructableDerivedCacheKeys {
            defaults.set("stale-derived", forKey: key)
        }

        let first = LifeRouteDevelopmentConfiguration.establishLive(defaults: defaults)
        expect(!first.live.plannerAEnabled, "flag defaults Planner A OFF")
        expect(first.previous == nil && first.configurationChanged,
               "absent previous launch configuration is different")
        expect(first.invalidatedReconstructableCaches,
               "absent previous configuration invalidates reconstructable caches")
        expect(LifeRouteDevelopmentConfiguration.reconstructableDerivedCacheKeys.allSatisfy {
            defaults.object(forKey: $0) == nil
        }, "only named reconstructable cache slots are cleared")
        expect(protectedKeys.allSatisfy { defaults.string(forKey: $0) == "protected" },
               "configuration change preserves source-of-truth records and settings")

        for key in LifeRouteDevelopmentConfiguration.reconstructableDerivedCacheKeys {
            defaults.set("current-derived", forKey: key)
        }
        let same = LifeRouteDevelopmentConfiguration.establishLive(defaults: defaults)
        expect(!same.configurationChanged && !same.invalidatedReconstructableCaches,
               "matching live configuration does not invalidate caches")
        expect(LifeRouteDevelopmentConfiguration.reconstructableDerivedCacheKeys.allSatisfy {
            defaults.string(forKey: $0) == "current-derived"
        }, "matching configuration retains current derived caches")

        defaults.set(true, forKey: LifeRouteDevelopmentConfiguration.pendingPlannerAKey)
        expect(!first.live.plannerAEnabled,
               "pending write cannot mutate immutable current live configuration")
        expect(LifeRouteDevelopmentConfiguration.reconstructableDerivedCacheKeys.allSatisfy {
            defaults.string(forKey: $0) == "current-derived"
        }, "pending write alone cannot invalidate running-process caches")

        let relaunched = LifeRouteDevelopmentConfiguration.establishLive(defaults: defaults)
        expect(relaunched.live.plannerAEnabled && relaunched.configurationChanged,
               "cold-launch establishment applies pending Planner A ON")
        expect(relaunched.invalidatedReconstructableCaches,
               "changed live configuration invalidates reconstructable caches")
        expect(LifeRouteDevelopmentConfiguration.reconstructableDerivedCacheKeys.allSatisfy {
            defaults.object(forKey: $0) == nil
        }, "changed configuration clears all and only derived cache slots")
        expect(protectedKeys.allSatisfy { defaults.string(forKey: $0) == "protected" },
               "relaunch invalidation preserves protected source-of-truth values")
        print("PASS FLAG — pending/live launch scope and cache policy")
    }

    func run() async {
        flagConfigurationContract()

        let (core, itinerary, gap) = await makeCore(plannerAEnabled: true)
        expect(gap.rawCalendarGapSeconds == 7_200 && gap.isRouteSafe,
               "controlled causal gap is two hours and route safe")
        let bad = todo("Unavailable errand", address: "Unavailable candidate", minutes: 20)
        let good = todo("Feasible bakery", address: "123 Corner")
        let later = todo("Later feasible errand", address: "456 Corner")

        resetEndpoints()
        DayRoutePlanningCore.fixtureLookupFailures[bad.address] =
            DayRoutePlanningError.locationNotFound(bad.address)
        await evaluate(core, gap: gap, itinerary: itinerary, todos: [bad, good, later])
        expect(DayRoutePlanningCore.fixtureFailures == [bad.address],
               "A1 bad first lookup rejects only that candidate")
        expect(DayRoutePlanningCore.fixtureQueries.contains(good.address)
            && DayRoutePlanningCore.fixtureQueries.contains(later.address),
               "A1 candidates B and C continue after candidate A")
        expect(DayRoutePlanningCore.fixtureRouteQueries.contains("Home Street->123 Corner")
            && DayRoutePlanningCore.fixtureRouteQueries.contains("123 Corner->Office Ave"),
               "A1 later feasible candidate reaches both travel legs")
        expect(recommendations(core, gap: gap).map(\.title) == [good.title, later.title],
               "A1 later feasible candidates survive and preserve order")
        expect(recommendations(core, gap: gap).allSatisfy { $0.fit.state == .fits },
               "A1 only proven fitting candidates render")
        print("PASS A1 — failing-first candidate-local isolation")

        resetEndpoints()
        DayRoutePlanningCore.fixtureLookupFailures[bad.address] = MKError(.placemarkNotFound)
        await evaluate(core, gap: gap, itinerary: itinerary, todos: [good, bad, later])
        expect(recommendations(core, gap: gap).map(\.title) == [good.title, later.title],
               "A2 reverse order retains earlier and later feasible candidates")
        expect(DayRoutePlanningCore.fixtureQueries.suffix(3) == [good.address, bad.address, later.address],
               "A2 candidate evaluation remains in input order")
        for (label, leg, error): (String, String, Error) in [
            ("inbound", "Home Street->Unavailable candidate", DayRoutePlanningError.routeUnavailable("candidate")),
            ("outbound", "Unavailable candidate->Office Ave", MKError(.directionsNotFound)),
        ] {
            resetEndpoints()
            DayRoutePlanningCore.fixtureRouteFailures[leg] = error
            await evaluate(core, gap: gap, itinerary: itinerary, todos: [good, bad, later])
            expect(recommendations(core, gap: gap).map(\.title) == [good.title, later.title],
                   "A2 \(label) route failure remains candidate local")
        }
        print("PASS A2 — reverse-order and routing controls")

        resetEndpoints()
        DayRoutePlanningCore.fixtureLookupFailures[bad.address] = CancellationError()
        await evaluate(core, gap: gap, itinerary: itinerary, todos: [good, bad, later])
        expect(recommendations(core, gap: gap).isEmpty,
               "A3 cooperative cancellation publishes no partial candidates")
        expect(!DayRoutePlanningCore.fixtureQueries.contains(later.address),
               "A3 cooperative cancellation stops later work")
        expect(core.gapEvaluationInFlight.isEmpty && core.fixtureGapTask(gap.id) == nil,
               "A3 cancellation retires current evaluation ownership")

        resetEndpoints()
        DayRoutePlanningCore.fixtureLookupFailures[bad.address] = DayRoutePlanningError.missingOrigin
        await evaluate(core, gap: gap, itinerary: itinerary, todos: [bad, good])
        expect(!DayRoutePlanningCore.fixtureQueries.contains(good.address),
               "A3 unknown/global candidate error aborts the whole evaluation")

        resetEndpoints()
        DayRoutePlanningCore.fixtureLookupFailures["Home Street"] =
            DayRoutePlanningError.locationNotFound("shared origin")
        await evaluate(core, gap: gap, itinerary: itinerary, todos: [good])
        expect(DayRoutePlanningCore.fixtureQueries == ["Home Street"],
               "A3 invalid shared route context remains a global abort")

        resetEndpoints()
        DayRoutePlanningCore.fixtureSuspended = true
        core.evaluateGapFillers(for: gap, itinerary: itinerary, savedPlaces: [], todos: [bad, later])
        let oldTask = core.fixtureGapTask(gap.id)!
        await settle { DayRoutePlanningCore.fixtureIsWaiting }
        core.evaluateGapFillers(for: gap, itinerary: itinerary, savedPlaces: [], todos: [good])
        let newTask = core.fixtureGapTask(gap.id)!
        await settle { DayRoutePlanningCore.fixturePendingRouteCount == 2 }
        DayRoutePlanningCore.fixtureSuspended = false
        DayRoutePlanningCore.resumeFixtureRoute(error: DayRoutePlanningError.routeUnavailable("stale old route"))
        await oldTask.value
        expect(core.gapEvaluationInFlight.contains(gap.id) && core.fixtureGapTask(gap.id) != nil,
               "A3 superseded task cannot clear newer evaluation ownership")
        DayRoutePlanningCore.resumeFixtureRoute()
        await newTask.value
        expect(recommendations(core, gap: gap).map(\.title) == [good.title],
               "A3 stale generation cannot publish over newer result")
        expect(core.gapEvaluationInFlight.isEmpty,
               "A3 current generation retires its own in-flight state")
        print("PASS A3 — cancellation, stale generation, and global aborts")

        let locationless = todo("Locationless task", address: "", dueDay: 20)
        resetEndpoints()
        DayRoutePlanningCore.fixtureLookupFailures[bad.address] =
            DayRoutePlanningError.locationNotFound(bad.address)
        await evaluate(core, gap: gap, itinerary: itinerary, todos: [locationless, bad, good])
        expect(recommendations(core, gap: gap).map(\.title) == [locationless.title, good.title],
               "A4 locationless and future Do-by behavior are unchanged")
        expect(!DayRoutePlanningCore.fixtureQueries.contains(""),
               "A4 locationless suggestion does not enter MapKit")

        resetEndpoints()
        DayRoutePlanningCore.fixtureLookupFailures[bad.address] =
            DayRoutePlanningError.locationNotFound(bad.address)
        let capped = [bad] + (1...8).map { todo("Candidate \($0)", address: "Address \($0)") }
        await evaluate(core, gap: gap, itinerary: itinerary, todos: capped)
        expect(recommendations(core, gap: gap).map(\.title) == (1...7).map { "Candidate \($0)" },
               "A4 cap remains eight including one rejected candidate")
        expect(!DayRoutePlanningCore.fixtureQueries.contains("Address 8"),
               "A4 local failure does not replenish the accepted cap")
        let firstOrder = recommendations(core, gap: gap)
        await evaluate(core, gap: gap, itinerary: itinerary, todos: capped)
        expect(recommendations(core, gap: gap) == firstOrder,
               "A4 repeated input preserves deterministic ordering")

        resetEndpoints()
        DayRoutePlanningCore.fixtureTravelSeconds = 10_000
        await evaluate(core, gap: gap, itinerary: itinerary, todos: [good])
        expect(recommendations(core, gap: gap).isEmpty,
               "A4 Do-by deadline does not bypass route/gap fit")
        print("PASS A4 — cap, ordering, locationless, deadline, and fit semantics")

        resetEndpoints()
        let (duplicateCore, duplicateItinerary, duplicateGap) = await makeCore(
            plannerAEnabled: true,
            appointments: duplicatedAppointments()
        )
        expect(duplicateItinerary.nodes.filter { $0.kind == .appointment }.count == 4,
               "A5 representative Apple/Google duplicates remain undeduplicated")
        DayRoutePlanningCore.fixtureLookupFailures[bad.address] =
            DayRoutePlanningError.locationNotFound(bad.address)
        await evaluate(
            duplicateCore,
            gap: duplicateGap,
            itinerary: duplicateItinerary,
            todos: [bad, good]
        )
        expect(recommendations(duplicateCore, gap: duplicateGap).map(\.title) == [good.title],
               "A5 candidate isolation remains stable with duplicated calendar-style input")
        expect(duplicateCore.gapEvaluationInFlight.isEmpty,
               "A5 duplicate input does not corrupt candidate-loop state")
        print("PASS A5 — undeduplicated calendar-style input safety")

        resetEndpoints()
        let (offCore, offItinerary, offGap) = await makeCore(plannerAEnabled: false)
        DayRoutePlanningCore.fixtureLookupFailures[bad.address] =
            DayRoutePlanningError.locationNotFound(bad.address)
        await evaluate(offCore, gap: offGap, itinerary: offItinerary, todos: [bad, good])
        expect(recommendations(offCore, gap: offGap).isEmpty,
               "A6 Planner A OFF retains frozen-D failing-first result")
        expect(!DayRoutePlanningCore.fixtureQueries.contains(good.address),
               "A6 Planner A OFF retains frozen-D early loop exit")
        resetEndpoints()
        DayRoutePlanningCore.fixtureLookupFailures[bad.address] =
            DayRoutePlanningError.locationNotFound(bad.address)
        await evaluate(offCore, gap: offGap, itinerary: offItinerary, todos: [good, bad])
        expect(recommendations(offCore, gap: offGap).map(\.title) == [good.title],
               "A6 Planner A OFF retains frozen-D reverse-order result")
        print("PASS A6 — Planner A OFF frozen-D baseline")
    }
}

@main
struct PlannerATestMain {
    static func main() async {
        let checks = await PlannerAChecks()
        await checks.run()
        print(
            "PLANNER_A \(await checks.failures == 0 ? "PASS" : "FAIL"): "
                + "\(await checks.count) assertions; \(await checks.failures) failed"
        )
        exit(await checks.failures == 0 ? 0 : 1)
    }
}
