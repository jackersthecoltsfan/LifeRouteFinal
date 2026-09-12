// Regression target: starting regeneration used to remove the published route
// synchronously. A long Today timeline could therefore collapse under its
// current scroll offset and leave only the app background until a status-bar
// scroll-to-top event. These checks exercise the production publication owner;
// only the external asynchronous route service is controlled.
@MainActor
private final class RegenerateRoutePresentationChecks {
    private var assertions = 0
    private var failures = 0

    private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        if !condition() {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    private func settle(_ predicate: () -> Bool) async {
        for _ in 0..<10_000 {
            if predicate() { return }
            await Task.yield()
        }
        fatalError("Bounded route fixture did not settle")
    }

    private func date(_ hour: Int) -> Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 9, day: 9, hour: hour)
        )!
    }

    func run() async {
        let core = DayRoutePlanningCore()
        core.returnHome = false
        let appointments = [
            LifeRouteRouteAppointment(
                id: "first", title: "Controlled first stop", address: "1 Main Street",
                start: date(9), end: date(10), isAllDay: false
            ),
            LifeRouteRouteAppointment(
                id: "second", title: "Controlled second stop", address: "2 Main Street",
                start: date(12), end: date(13), isAllDay: false
            ),
        ]

        // R5: an initial generation still begins with no prior route and an
        // explicit loading state, then publishes the first visible route.
        DayRoutePlanningCore.fixtureBuildSuspended = true
        core.calculate(
            selectedDay: date(0), appointments: appointments,
            beforeStops: [], afterStops: [], routeBufferMinutes: 10,
            homeAddress: "", currentLocation: nil
        )
        await settle { DayRoutePlanningCore.fixtureBuildWaiting }
        expect(core.isCalculating, "initial generation is explicitly in flight")
        expect(core.generatedItinerary == nil && core.legs.isEmpty, "initial generation has no invented prior route")
        expect(core.message == "Generating day route…", "initial generation exposes its loading state")
        DayRoutePlanningCore.fixtureBuildSuspended = false
        DayRoutePlanningCore.resumeFixtureBuild()
        await settle { !core.isCalculating }
        guard let baseline = core.generatedItinerary else {
            expect(false, "initial generation publishes a visible route")
            report()
            return
        }
        let baselineLegs = core.legs
        expect(baselineLegs.count == 1 && core.fullRoutePlan != nil, "normal initial route presentation is unchanged")

        // R1/R2: while the replacement request is suspended, the existing
        // route remains published. Completion alone replaces it; no unrelated
        // top-area tap, navigation event, or focus change participates.
        DayRoutePlanningCore.fixtureBuildSuspended = true
        core.calculate(
            selectedDay: date(0), appointments: appointments,
            beforeStops: [], afterStops: [], routeBufferMinutes: 15,
            homeAddress: "", currentLocation: nil
        )
        await settle { DayRoutePlanningCore.fixtureBuildWaiting }
        expect(core.isCalculating, "regeneration enters an explicit loading state")
        expect(core.generatedItinerary == baseline, "regeneration retains the visible route while loading")
        expect(core.legs == baselineLegs && core.fullRoutePlan != nil, "regeneration does not collapse route presentation")
        expect(core.message == "Generating day route…", "regeneration identifies its visible loading state")
        DayRoutePlanningCore.fixtureBuildSuspended = false
        DayRoutePlanningCore.resumeFixtureBuild()
        await settle { !core.isCalculating }
        guard let replacement = core.generatedItinerary else {
            expect(false, "regeneration publishes a replacement without another user event")
            report()
            return
        }
        expect(replacement.id != baseline.id, "successful regeneration publishes a new route identity")
        expect(replacement.routeBuffer.minutes == 15 && core.legs.count == 1, "successful regeneration publishes the requested route")
        expect(core.message == "Day route ready.", "successful regeneration leaves a visible ready state")

        // R3: a failed replacement keeps the last usable route visible and
        // publishes a recoverable error instead of an empty presentation.
        DayRoutePlanningCore.fixtureBuildShouldFail = true
        core.calculate(
            selectedDay: date(0), appointments: appointments,
            beforeStops: [], afterStops: [], routeBufferMinutes: 20,
            homeAddress: "", currentLocation: nil
        )
        await settle { !core.isCalculating }
        expect(core.generatedItinerary == replacement && core.legs.count == 1, "failed regeneration retains the last visible route")
        expect(core.fullRoutePlan != nil, "failed regeneration retains the recoverable route action")
        expect(core.message?.contains("could not be calculated") == true, "failed regeneration publishes a visible error")
        DayRoutePlanningCore.fixtureBuildShouldFail = false

        // R4: two bounded replacement cycles each settle with a current route;
        // neither inherits a hidden or in-flight state from its predecessor.
        let priorID = core.generatedItinerary?.id
        core.calculate(
            selectedDay: date(0), appointments: appointments,
            beforeStops: [], afterStops: [], routeBufferMinutes: 20,
            homeAddress: "", currentLocation: nil
        )
        await settle { !core.isCalculating }
        let firstRepeatID = core.generatedItinerary?.id
        expect(firstRepeatID != nil && firstRepeatID != priorID, "first repeated regeneration settles with a visible replacement")
        expect(core.generatedItinerary?.routeBuffer.minutes == 20, "first repeated regeneration publishes its current inputs")

        core.calculate(
            selectedDay: date(0), appointments: appointments,
            beforeStops: [], afterStops: [], routeBufferMinutes: 30,
            homeAddress: "", currentLocation: nil
        )
        await settle { !core.isCalculating }
        expect(core.generatedItinerary?.id != firstRepeatID, "second repeated regeneration does not leave stale identity")
        expect(core.generatedItinerary?.routeBuffer.minutes == 30 && !core.isCalculating, "second repeated regeneration finishes visibly")

        report()
    }

    private func report() {
        let verdict = failures == 0 ? "PASS" : "FAIL"
        print(
            "REGENERATE_ROUTE_PRESENTATION \(verdict): "
                + "\(assertions) assertions; \(failures) failed"
        )
        if failures != 0 { exit(1) }
    }
}

@main
private struct RegenerateRoutePresentationTestMain {
    static func main() async {
        await RegenerateRoutePresentationChecks().run()
    }
}
