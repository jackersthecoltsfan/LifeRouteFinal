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

    private func makeCore(
        previousAddress: String = "Home Street",
        nextAddress: String = "Office Ave",
        currentLocation: CLLocation? = nil
    ) async -> (
        DayRoutePlanningCore,
        LifeRouteGeneratedItinerary,
        LifeRouteUsableGap
    ) {
        let core = DayRoutePlanningCore()
        core.calculate(
            selectedDay: date(0),
            appointments: [
                LifeRouteRouteAppointment(
                    id: "previous",
                    title: "Previous",
                    address: previousAddress,
                    start: date(9),
                    end: date(10),
                    isAllDay: false
                ),
                LifeRouteRouteAppointment(
                    id: "next",
                    title: "Next",
                    address: nextAddress,
                    start: date(12),
                    end: date(13),
                    isAllDay: false
                ),
            ],
            beforeStops: [],
            afterStops: [],
            routeBufferMinutes: 10,
            homeAddress: "Home Base",
            currentLocation: currentLocation
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
        DayRoutePlanningCore.fixtureCoordinates = [:]
        DayRoutePlanningCore.fixtureSearchRegions = []
        DayRoutePlanningCore.fixtureSearchContexts = []
        DayRoutePlanningCore.fixtureSearchResultCounts = []
        DayRoutePlanningCore.fixtureTravelSecondsByLeg = [:]
        DayRoutePlanningCore.fixtureTravelSeconds = 300
        DayRoutePlanningCore.fixtureSuspended = false
    }

    private func setTravel(
        option: String,
        inbound: TimeInterval,
        outbound: TimeInterval,
        from source: String = "Home Street",
        to destination: String = "Office Ave"
    ) {
        DayRoutePlanningCore.fixtureTravelSecondsByLeg["\(source)->\(option)"] = inbound
        DayRoutePlanningCore.fixtureTravelSecondsByLeg["\(option)->\(destination)"] = outbound
    }

    private func setCoordinate(
        _ address: String,
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees
    ) {
        DayRoutePlanningCore.fixtureCoordinates[address] = CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )
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
        let sameAnchor = "Shared Route Anchor"
        let (sameCore, sameItinerary, sameGap) = await makeCore(
            previousAddress: sameAnchor,
            nextAddress: sameAnchor
        )
        setCoordinate(sameAnchor, latitude: 40, longitude: -75)
        let sameAnchorOptions = (0..<8).map { "Same-anchor option \($0)" }
        for (index, option) in sameAnchorOptions.enumerated() {
            setCoordinate(
                option,
                latitude: 40.25 + (Double(index) * 0.01),
                longitude: -75.25
            )
        }
        setCoordinate(sameAnchorOptions[6], latitude: 40.001, longitude: -75.001)
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = sameAnchorOptions
        setTravel(
            option: sameAnchorOptions[6],
            inbound: 120,
            outbound: 120,
            from: sameAnchor,
            to: sameAnchor
        )
        result = await evaluate(
            sameCore,
            gap: sameGap,
            itinerary: sameItinerary,
            todos: [flexible]
        )
        expect(result.first?.address == sameAnchorOptions[6],
               "FD1 same-anchor gap shortlists and selects the near-anchor place")
        expect(DayRoutePlanningCore.fixtureSearchContexts == ["\(sameAnchor)->\(sameAnchor)"],
               "FD1 search and exact routing receive the actual shared route anchor")
        expect(DayRoutePlanningCore.fixtureSearchRegions.count == 1,
               "FD1 same-anchor search receives one route-derived region")
        if let region = DayRoutePlanningCore.fixtureSearchRegions.first {
            expect(abs(region.center.latitude - 40) < 0.001
                    && abs(region.center.longitude + 75) < 0.001
                    && region.span.latitudeDelta > 0.1,
                   "FD1 search region is centered on the shared route anchor")
        }

        resetEndpoints()
        setCoordinate("Home Street", latitude: 40, longitude: -75)
        setCoordinate("Office Ave", latitude: 40.10, longitude: -74.90)
        let routeContextOptions = (0..<8).map { "Route context option \($0)" }
        for (index, option) in routeContextOptions.enumerated() {
            setCoordinate(
                option,
                latitude: 41 + (Double(index) * 0.01),
                longitude: -76
            )
        }
        setCoordinate(routeContextOptions[6], latitude: 40.05, longitude: -74.95)
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = routeContextOptions
        setTravel(option: routeContextOptions[6], inbound: 120, outbound: 120)
        result = await evaluate(core, gap: gap, itinerary: itinerary, todos: [flexible])
        expect(result.first?.address == routeContextOptions[6],
               "FD2 route-context winner outside provider prefix reaches exact routing")
        expect(DayRoutePlanningCore.fixtureRouteQueries.contains("Home Street->\(routeContextOptions[6])"),
               "FD2 raw provider order does not exclude the route-context winner")
        expect(DayRoutePlanningCore.fixtureSearchResultCounts == [8]
                && DayRoutePlanningCore.fixtureRouteQueries.count == 8,
               "FD2 complete provider set feeds a four-option/eight-leg bound")
        expect(DayRoutePlanningCore.fixtureSearchRegions.count == 1,
               "FD2 distinct-endpoint search receives one route-derived region")
        if let region = DayRoutePlanningCore.fixtureSearchRegions.first {
            expect(abs(region.center.latitude - 40.05) < 0.001
                    && abs(region.center.longitude + 74.95) < 0.001,
                   "FD2 search region is centered on the endpoint midpoint")
        }

        resetEndpoints()
        let (corridorCore, corridorItinerary, corridorGap) = await makeCore(
            previousAddress: "Route Start",
            nextAddress: "Route End"
        )
        setCoordinate("Home Base", latitude: 39, longitude: -76)
        setCoordinate("Route Start", latitude: 41, longitude: -74)
        setCoordinate("Route End", latitude: 41.10, longitude: -73.90)
        let corridorOptions = (0..<8).map { "Corridor option \($0)" }
        for (index, option) in corridorOptions.enumerated() {
            setCoordinate(
                option,
                latitude: 39 + (Double(index) * 0.01),
                longitude: -76
            )
        }
        setCoordinate(corridorOptions[5], latitude: 41.05, longitude: -73.95)
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = corridorOptions
        setTravel(
            option: corridorOptions[5],
            inbound: 120,
            outbound: 120,
            from: "Route Start",
            to: "Route End"
        )
        result = await evaluate(
            corridorCore,
            gap: corridorGap,
            itinerary: corridorItinerary,
            todos: [flexible]
        )
        expect(result.first?.address == corridorOptions[5],
               "FD3 distinct-endpoint corridor place beats the provider-leading Home-biased place")
        expect(DayRoutePlanningCore.fixtureSearchContexts == ["Route Start->Route End"],
               "FD3 discovery uses the distinct planned route endpoints")

        let (liveOnCore, liveOnItinerary, liveOnGap) = await makeCore(
            previousAddress: "Planned Start",
            nextAddress: "Planned End",
            currentLocation: CLLocation(latitude: 35, longitude: -80)
        )
        let (liveOffCore, liveOffItinerary, liveOffGap) = await makeCore(
            previousAddress: "Planned Start",
            nextAddress: "Planned End",
            currentLocation: nil
        )
        let liveOptions = (0..<8).map { "Live-control option \($0)" }

        resetEndpoints()
        setCoordinate("Planned Start", latitude: 42, longitude: -72)
        setCoordinate("Planned End", latitude: 42.10, longitude: -71.90)
        for (index, option) in liveOptions.enumerated() {
            setCoordinate(option, latitude: 43 + (Double(index) * 0.01), longitude: -73)
        }
        setCoordinate(liveOptions[6], latitude: 42.05, longitude: -71.95)
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = liveOptions
        setTravel(
            option: liveOptions[6],
            inbound: 120,
            outbound: 120,
            from: "Planned Start",
            to: "Planned End"
        )
        let liveOnResult = await evaluate(
            liveOnCore,
            gap: liveOnGap,
            itinerary: liveOnItinerary,
            todos: [flexible]
        )
        let liveOnRegion = DayRoutePlanningCore.fixtureSearchRegions.first

        resetEndpoints()
        setCoordinate("Planned Start", latitude: 42, longitude: -72)
        setCoordinate("Planned End", latitude: 42.10, longitude: -71.90)
        for (index, option) in liveOptions.enumerated() {
            setCoordinate(option, latitude: 43 + (Double(index) * 0.01), longitude: -73)
        }
        setCoordinate(liveOptions[6], latitude: 42.05, longitude: -71.95)
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = liveOptions
        setTravel(
            option: liveOptions[6],
            inbound: 120,
            outbound: 120,
            from: "Planned Start",
            to: "Planned End"
        )
        let liveOffResult = await evaluate(
            liveOffCore,
            gap: liveOffGap,
            itinerary: liveOffItinerary,
            todos: [flexible]
        )
        let liveOffRegion = DayRoutePlanningCore.fixtureSearchRegions.first
        expect(liveOnResult.first?.address == liveOptions[6]
                && liveOffResult.first?.address == liveOptions[6],
               "FD4 Live Location ON/OFF preserves the valid planned-endpoint winner")
        expect(DayRoutePlanningCore.fixtureSearchContexts == ["Planned Start->Planned End"],
               "FD4 device location does not replace valid gap anchors")
        expect(liveOnRegion?.center.latitude == liveOffRegion?.center.latitude
                && liveOnRegion?.center.longitude == liveOffRegion?.center.longitude,
               "FD4 route-context search region is invariant to Live Location")

        resetEndpoints()
        setCoordinate("Home Street", latitude: 40, longitude: -75)
        setCoordinate("Office Ave", latitude: 40.10, longitude: -74.90)
        let authorityOptions = ["Geometric best", "Exact-route best", "Authority other 2", "Authority other 3"]
        setCoordinate(authorityOptions[0], latitude: 40.05, longitude: -74.95)
        setCoordinate(authorityOptions[1], latitude: 40.055, longitude: -74.945)
        setCoordinate(authorityOptions[2], latitude: 40.06, longitude: -74.94)
        setCoordinate(authorityOptions[3], latitude: 40.07, longitude: -74.93)
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = authorityOptions
        setTravel(option: authorityOptions[0], inbound: 600, outbound: 600)
        setTravel(option: authorityOptions[1], inbound: 120, outbound: 120)
        result = await evaluate(core, gap: gap, itinerary: itinerary, todos: [flexible])
        expect(result.first?.address == authorityOptions[1],
               "FD6 exact route cost remains final authority over geometric shortlist order")

        resetEndpoints()
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = [
            "Cancelled option", "Must not continue 1", "Must not continue 2", "Must not continue 3",
        ]
        DayRoutePlanningCore.fixtureRouteFailures["Home Street->Cancelled option"] = CancellationError()
        result = await evaluate(core, gap: gap, itinerary: itinerary, todos: [flexible])
        expect(result.isEmpty
                && !DayRoutePlanningCore.fixtureRouteQueries.contains("Home Street->Must not continue 1"),
               "FD10 cancellation remains a global abort for a flexible shortlist")

        resetEndpoints()
        setCoordinate(sameAnchor, latitude: 40, longitude: -75)
        let evidenceGap = widened(sameGap)
        let evidenceOptions = (0..<24).map { "Evidence option \($0)" }
        for (index, option) in evidenceOptions.enumerated() {
            setCoordinate(
                option,
                latitude: 40.30 + (Double(index) * 0.005),
                longitude: -75.30
            )
        }
        setCoordinate(evidenceOptions[17], latitude: 40.001, longitude: -75.001)
        DayRoutePlanningCore.fixtureSearchResults[flexible.address] = evidenceOptions
        setTravel(
            option: evidenceOptions[0],
            inbound: 4_125,
            outbound: 4_223,
            from: sameAnchor,
            to: sameAnchor
        )
        setTravel(
            option: evidenceOptions[1],
            inbound: 2_100,
            outbound: 2_160,
            from: sameAnchor,
            to: sameAnchor
        )
        setTravel(
            option: evidenceOptions[17],
            inbound: 120,
            outbound: 120,
            from: sameAnchor,
            to: sameAnchor
        )
        let firstFit = evidenceGap.fit(
            .located(
                id: "evidence-first",
                title: "Flexible evidence task",
                durationSeconds: 1_800,
                inboundTravelSeconds: 4_125,
                outboundTravelSeconds: 4_223
            )
        )
        result = await evaluate(
            sameCore,
            gap: evidenceGap,
            itinerary: sameItinerary,
            todos: [flexible]
        )
        expect(firstFit.state == .fits, "REAL SHAPE first 69/70-minute result is technically feasible")
        expect(result.first?.address == evidenceOptions[17],
               "FD11 adjacent later result reaches the shortlist and wins")
        expect(DayRoutePlanningCore.fixtureSearchResultCounts == [24]
                && DayRoutePlanningCore.fixtureRouteQueries.count == 8,
               "FD11 complete 24-result shape remains bounded to four evaluations")

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
