@MainActor
final class FlexiblePlaceRouteAwareChecks {
    private(set) var count = 0
    private(set) var failures = 0

    private func expect(_ value: @autoclosure () -> Bool, _ label: String) {
        count += 1
        if !value() {
            failures += 1
            print("FAIL: \(label)")
        }
    }

    private func date(_ hour: Int) -> Date {
        Calendar.current.date(
            from: DateComponents(year: 2026, month: 9, day: 10, hour: hour)
        )!
    }

    private func todo(
        _ title: String,
        address: String,
        minutes: Int = 30
    ) -> LifeRouteTodo {
        LifeRouteTodo(
            title: title,
            category: .errand,
            durationMinutes: minutes,
            savedPlaceID: nil,
            address: address,
            priority: .normal,
            dueDate: date(23),
            notes: ""
        )
    }

    private func settle(_ predicate: () -> Bool) async {
        for _ in 0..<10_000 {
            if predicate() { return }
            await Task.yield()
        }
        fatalError("Controlled flexible-place endpoint did not settle")
    }

    private func makeCore() async -> (
        DayRoutePlanningCore,
        LifeRouteGeneratedItinerary,
        LifeRouteUsableGap
    ) {
        let core = DayRoutePlanningCore(plannerAEnabled: true)
        core.calculate(
            selectedDay: date(0),
            appointments: [
                LifeRouteRouteAppointment(
                    id: "previous",
                    title: "Previous",
                    address: "Home Street",
                    start: date(9),
                    end: date(10),
                    isAllDay: false
                ),
                LifeRouteRouteAppointment(
                    id: "next",
                    title: "Next",
                    address: "Office Ave",
                    start: date(12),
                    end: date(13),
                    isAllDay: false
                ),
            ],
            beforeStops: [],
            afterStops: [],
            routeBufferMinutes: 10,
            homeAddress: "Home Base",
            currentLocation: nil
        )
        await settle { !core.isCalculating }
        let itinerary = core.generatedItinerary!
        let gap = itinerary.usableGaps.first { $0.isRouteSafe }!
        return (core, itinerary, gap)
    }

    private func resetEndpoints() {
        DayRoutePlanningCore.fixtureQueries = []
        DayRoutePlanningCore.fixtureRouteQueries = []
        DayRoutePlanningCore.fixtureFailures = []
        DayRoutePlanningCore.fixtureLookupFailures = [:]
        DayRoutePlanningCore.fixtureRouteFailures = [:]
        DayRoutePlanningCore.fixtureSearchResults = [:]
        DayRoutePlanningCore.fixtureTravelSecondsByLeg = [:]
        DayRoutePlanningCore.fixtureTravelSeconds = 300
        DayRoutePlanningCore.fixtureSuspended = false
    }

    private func setTravel(
        option: String,
        inbound: TimeInterval,
        outbound: TimeInterval
    ) {
        DayRoutePlanningCore.fixtureTravelSecondsByLeg["Home Street->\(option)"] = inbound
        DayRoutePlanningCore.fixtureTravelSecondsByLeg["\(option)->Office Ave"] = outbound
    }

    private func evaluate(
        _ core: DayRoutePlanningCore,
        gap: LifeRouteUsableGap,
        itinerary: LifeRouteGeneratedItinerary,
        todos: [LifeRouteTodo]
    ) async -> [LifeRouteGapFillerRecommendation] {
        core.evaluateGapFillers(
            for: gap,
            itinerary: itinerary,
            savedPlaces: [],
            todos: todos
        )
        await core.fixtureGapTask(gap.id)?.value
        return core.gapRecommendationsByGapID[gap.id] ?? []
    }

    private func widened(_ gap: LifeRouteUsableGap) -> LifeRouteUsableGap {
        LifeRouteUsableGap(
            id: gap.id,
            previousAppointmentNodeID: gap.previousAppointmentNodeID,
            nextAppointmentNodeID: gap.nextAppointmentNodeID,
            rawCalendarGapSeconds: 15_300,
            requiredTravelSeconds: gap.requiredTravelSeconds,
            requiredStopSeconds: gap.requiredStopSeconds,
            bufferSeconds: gap.bufferSeconds,
            usableSeconds: 14_100,
            isRouteSafe: true
        )
    }

    func run() async {
        let (core, itinerary, gap) = await makeCore()
        let flexible = todo("Flexible errand", address: "Any grocery store")

        resetEndpoints()
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = ["Distant 0", "Nearby 1", "Alternative 2"]
        setTravel(option: "Distant 0", inbound: 1_800, outbound: 1_800)
        setTravel(option: "Nearby 1", inbound: 240, outbound: 240)
        setTravel(option: "Alternative 2", inbound: 900, outbound: 900)
        var result = await evaluate(core, gap: gap, itinerary: itinerary, todos: [flexible])
        expect(result.first?.address == "Nearby 1", "FP1 later feasible result with lower route cost wins")
        expect(result.first?.fit.state == .fits, "FP1 selected later result still passes unchanged fit")

        resetEndpoints()
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = ["Too far 0", "Fits 1"]
        setTravel(option: "Too far 0", inbound: 4_000, outbound: 4_000)
        setTravel(option: "Fits 1", inbound: 300, outbound: 300)
        result = await evaluate(core, gap: gap, itinerary: itinerary, todos: [flexible])
        expect(result.first?.address == "Fits 1", "FP2 later feasible result wins when result zero does not fit")

        resetEndpoints()
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = ["Broken 0", "Valid 1"]
        DayRoutePlanningCore.fixtureRouteFailures["Home Street->Broken 0"] =
            DayRoutePlanningError.routeUnavailable("place option")
        setTravel(option: "Valid 1", inbound: 300, outbound: 300)
        result = await evaluate(core, gap: gap, itinerary: itinerary, todos: [flexible])
        expect(result.first?.address == "Valid 1", "FP3 recoverable first-option route failure does not kill flexible candidate")
        expect(DayRoutePlanningCore.fixtureFailures == ["Home Street->Broken 0"], "FP3 records only failed place option")

        resetEndpoints()
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = ["Best 0", "Worse 1"]
        setTravel(option: "Best 0", inbound: 180, outbound: 180)
        setTravel(option: "Worse 1", inbound: 600, outbound: 600)
        result = await evaluate(core, gap: gap, itinerary: itinerary, todos: [flexible])
        expect(result.first?.address == "Best 0", "FP4 result zero remains selected when genuinely best")

        resetEndpoints()
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = ["Too far 0", "Too far 1"]
        setTravel(option: "Too far 0", inbound: 4_000, outbound: 4_000)
        setTravel(option: "Too far 1", inbound: 3_900, outbound: 3_900)
        result = await evaluate(core, gap: gap, itinerary: itinerary, todos: [flexible])
        expect(result.isEmpty, "FP5 no feasible bounded result preserves candidate rejection")

        resetEndpoints()
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = ["Tie 0", "Tie 1"]
        setTravel(option: "Tie 0", inbound: 300, outbound: 300)
        setTravel(option: "Tie 1", inbound: 300.4, outbound: 300.4)
        result = await evaluate(core, gap: gap, itinerary: itinerary, todos: [flexible])
        expect(result.first?.address == "Tie 0", "FP6 effectively equal route cost preserves provider order")

        resetEndpoints()
        let fixed = todo("Fixed errand", address: "123 Fixed Street", minutes: 10)
        DayRoutePlanningCore.fixtureSearchResults[fixed.address] = ["Must not fan out", "Must not route"]
        result = await evaluate(core, gap: gap, itinerary: itinerary, todos: [fixed])
        expect(result.first?.address == fixed.address, "FP7 fixed-location recommendation address is unchanged")
        expect(DayRoutePlanningCore.fixtureQueries.filter { $0 == fixed.address }.count == 1,
               "FP7 fixed location keeps the single-result lookup path")
        expect(DayRoutePlanningCore.fixtureRouteQueries == [
            "Home Street->123 Fixed Street",
            "123 Fixed Street->Office Ave",
        ], "FP7 fixed location keeps exactly two route legs")

        resetEndpoints()
        let brokenCandidate = todo("Broken candidate", address: "Unavailable address", minutes: 10)
        let laterCandidate = todo("Later candidate", address: "456 Valid Street", minutes: 10)
        DayRoutePlanningCore.fixtureLookupFailures[brokenCandidate.address] =
            DayRoutePlanningError.locationNotFound(brokenCandidate.address)
        result = await evaluate(
            core,
            gap: gap,
            itinerary: itinerary,
            todos: [brokenCandidate, laterCandidate]
        )
        expect(result.map(\.title) == [laterCandidate.title], "FP8 Planner A still isolates one candidate-local failure")
        expect(DayRoutePlanningCore.fixtureQueries.contains(laterCandidate.address), "FP8 later candidate still executes")

        resetEndpoints()
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = ["Barely over 0", "Farther 1"]
        setTravel(option: "Barely over 0", inbound: 2_400, outbound: 2_401)
        setTravel(option: "Farther 1", inbound: 2_500, outbound: 2_500)
        result = await evaluate(core, gap: gap, itinerary: itinerary, todos: [flexible])
        expect(result.isEmpty, "FP9 best place is rejected when task plus travel and buffer exceed gap")

        resetEndpoints()
        let boundedOptions = (0..<6).map { "Bounded \($0)" }
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = boundedOptions
        for (index, option) in boundedOptions.enumerated() {
            let seconds = TimeInterval(900 - index * 100)
            setTravel(option: option, inbound: seconds, outbound: seconds)
        }
        result = await evaluate(core, gap: gap, itinerary: itinerary, todos: [flexible])
        expect(result.first?.address == "Bounded 3", "FP10 best result inside bounded prefix is selected")
        expect(DayRoutePlanningCore.fixtureRouteQueries.count == 8, "FP10 only four place results produce eight route legs")
        expect(!DayRoutePlanningCore.fixtureRouteQueries.contains { $0.contains("Bounded 4") || $0.contains("Bounded 5") },
               "FP10 results beyond bounded prefix are not routed")

        resetEndpoints()
        let evidenceGap = widened(gap)
        let evidenceOptions = (0..<24).map { "Evidence option \($0)" }
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = evidenceOptions
        setTravel(option: evidenceOptions[0], inbound: 4_125, outbound: 4_223)
        setTravel(option: evidenceOptions[1], inbound: 600, outbound: 660)
        setTravel(option: evidenceOptions[2], inbound: 1_200, outbound: 1_200)
        setTravel(option: evidenceOptions[3], inbound: 1_500, outbound: 1_500)
        let firstFit = evidenceGap.fit(
            .located(
                id: "evidence-first",
                title: "Flexible evidence task",
                durationSeconds: 1_800,
                inboundTravelSeconds: 4_125,
                outboundTravelSeconds: 4_223
            )
        )
        result = await evaluate(core, gap: evidenceGap, itinerary: itinerary, todos: [flexible])
        expect(firstFit.state == .fits, "REAL SHAPE first 69/70-minute result is technically feasible")
        expect(result.first?.address == evidenceOptions[1], "REAL SHAPE lower-cost later result beats first of 24")
        expect(DayRoutePlanningCore.fixtureRouteQueries.count == 8, "REAL SHAPE 24 results remain bounded to four evaluations")

        print(
            "FLEXIBLE_PLACE_ROUTE_AWARE \(failures == 0 ? "PASS" : "FAIL"): "
                + "\(count) assertions; \(failures) failed"
        )
    }
}

#if os(iOS)
import UIKit

private final class FlexiblePlaceRouteAwareTestAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        self.window = window
        Task { @MainActor in
            let checks = FlexiblePlaceRouteAwareChecks()
            await checks.run()
            NSLog(
                "FLEXIBLE_PLACE_ROUTE_AWARE_NATIVE %@: %d assertions; %d failed",
                checks.failures == 0 ? "PASS" : "FAIL",
                checks.count,
                checks.failures
            )
            fflush(stdout)
            exit(checks.failures == 0 ? 0 : 1)
        }
        return true
    }
}

@main
struct FlexiblePlaceRouteAwareNativeTestMain {
    static func main() {
        UIApplicationMain(
            CommandLine.argc,
            CommandLine.unsafeArgv,
            nil,
            NSStringFromClass(FlexiblePlaceRouteAwareTestAppDelegate.self)
        )
    }
}
#else
@main
struct FlexiblePlaceRouteAwareTestMain {
    static func main() async {
        let checks = await FlexiblePlaceRouteAwareChecks()
        await checks.run()
        exit(await checks.failures == 0 ? 0 : 1)
    }
}
#endif
