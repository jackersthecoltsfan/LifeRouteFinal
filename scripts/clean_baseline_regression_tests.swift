// All identities, times, names and coordinates below are synthetic.
@MainActor
final class CleanBaselineChecks {
    private(set) var count = 0
    private(set) var failures = 0

    private func expect(_ condition: @autoclosure () -> Bool, _ label: String) {
        count += 1
        if !condition() { failures += 1; print("FAIL: \(label)") }
    }

    private func date(_ hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2032, month: 4, day: 6, hour: hour))!
    }

    private func settle(_ predicate: () -> Bool) async {
        for _ in 0..<10_000 {
            if predicate() { return }
            await Task.yield()
        }
        fatalError("Controlled clean-baseline endpoint did not settle")
    }

    private func event(_ source: LifeRouteCalendarSource, identity: String) -> LifeRouteCalendarEvent {
        LifeRouteCalendarEvent(
            id: "synthetic-\(source.rawValue)", title: "Synthetic appointment",
            start: date(9), end: date(10), location: "Synthetic route anchor", source: source,
            providerIdentity: LifeRouteCalendarProviderIdentity(
                eventIdentifier: "synthetic-\(source.rawValue)", externalIdentifier: identity,
                recurrenceIdentifier: nil, isRecurring: false,
                calendarIdentifier: "synthetic-calendar-\(source.rawValue)",
                accountIdentifier: nil, timeZoneIdentifier: "UTC", modifiedAt: nil, revision: nil
            )
        )
    }

    private func calendarSupportedPair() async {
        let priorFailures = failures
        let raw = [event(.apple, identity: "synthetic-pair@example.invalid"),
                   event(.google, identity: "synthetic-pair@example.invalid")]
        let state = CalendarCoreState(now: date(0), events: raw)
        expect(state.rawProviderEvents == raw && state.rawProviderEvents.count == 2,
               "supported pair retains two unchanged raw provider records")
        expect(state.events.count == 1 && state.presentation(for: .day).eventCount == 1,
               "supported external identity produces one canonical Calendar appointment")
        let appointments = CleanBaselineTodayProjection(calendarState: state).routeAppointments
        expect(appointments.count == 1, "actual Today projection passes one appointment downstream")
        let core = DayRoutePlanningCore()
        core.calculate(selectedDay: date(0), appointments: appointments, beforeStops: [], afterStops: [],
                       routeBufferMinutes: 10, homeAddress: "Synthetic home", currentLocation: nil)
        await settle { !core.isCalculating }
        expect(core.generatedItinerary?.nodes.filter { $0.kind == .appointment }.count == 1,
               "Planner fixed-event input produces one appointment node")
        core.calculate(selectedDay: date(0), appointments: appointments, beforeStops: [], afterStops: [],
                       routeBufferMinutes: 10, homeAddress: "Synthetic home", currentLocation: nil)
        expect(core.generatedItinerary != nil && core.isCalculating,
               "Regenerate retains the canonical itinerary while recalculating")
        await settle { !core.isCalculating }
        expect(core.generatedItinerary?.nodes.filter { $0.kind == .appointment }.count == 1,
               "Regenerate completes with the same one canonical appointment")
        let distinct = CalendarCoreState(now: date(0), events: [
            event(.apple, identity: "synthetic-distinct-a@example.invalid"),
            event(.google, identity: "synthetic-distinct-b@example.invalid"),
        ])
        expect(distinct.events.count == 2
                && CleanBaselineTodayProjection(calendarState: distinct).routeAppointments.count == 2,
               "identical synthetic title/time/location with distinct identities never merges")
        print("ANONYMOUS_CALENDAR_SUPPORTED \(failures == priorFailures ? "PASS" : "FAIL")")
    }

    private func routeAnchorCase() async {
        let priorFailures = failures
        let anchor = "Synthetic route anchor"
        let home = "Synthetic home"
        let core = DayRoutePlanningCore()
        let appointments = [
            LifeRouteRouteAppointment(id: "synthetic-before", title: "Synthetic before", address: anchor,
                                     start: date(8), end: date(9), isAllDay: false),
            LifeRouteRouteAppointment(id: "synthetic-after", title: "Synthetic after", address: anchor,
                                     start: date(12), end: date(13), isAllDay: false),
        ]
        core.calculate(selectedDay: date(0), appointments: appointments, beforeStops: [], afterStops: [],
                       routeBufferMinutes: 10, homeAddress: home,
                       currentLocation: CLLocation(latitude: -12, longitude: -34))
        await settle { !core.isCalculating }
        guard let itinerary = core.generatedItinerary, let gap = itinerary.usableGaps.first(where: { $0.isRouteSafe }) else {
            expect(false, "synthetic same-anchor itinerary generates a route-safe gap")
            return
        }
        let todo = LifeRouteTodo(title: "Synthetic flexible errand", category: .errand, durationMinutes: 20,
                                 savedPlaceID: nil, address: "Any grocery store", priority: .normal,
                                 dueDate: date(23), notes: "")
        let options = (0..<24).map { "Synthetic place \($0)" }
        let unavailable = LifeRouteTodo(title: "Synthetic unavailable errand", category: .errand, durationMinutes: 10,
                                       savedPlaceID: nil, address: "Synthetic unavailable place", priority: .normal,
                                       dueDate: date(23), notes: "")
        DayRoutePlanningCore.fixtureLookupFailures[unavailable.address] =
            DayRoutePlanningError.locationNotFound(unavailable.address)
        DayRoutePlanningCore.fixtureCoordinates[anchor] = CLLocationCoordinate2D(latitude: 12, longitude: 34)
        DayRoutePlanningCore.fixtureCoordinates[home] = CLLocationCoordinate2D(latitude: -11, longitude: -33)
        for (index, option) in options.enumerated() {
            DayRoutePlanningCore.fixtureCoordinates[option] = CLLocationCoordinate2D(
                latitude: 12.3 + Double(index) * 0.005, longitude: 34.3)
            DayRoutePlanningCore.fixtureTravelSecondsByLeg["\(anchor)->\(option)"] = 2_400
            DayRoutePlanningCore.fixtureTravelSecondsByLeg["\(option)->\(anchor)"] = 2_400
        }
        let nearby = options[17]
        DayRoutePlanningCore.fixtureCoordinates[nearby] = CLLocationCoordinate2D(latitude: 12.001, longitude: 34.001)
        DayRoutePlanningCore.fixtureTravelSecondsByLeg["\(anchor)->\(nearby)"] = 120
        DayRoutePlanningCore.fixtureTravelSecondsByLeg["\(nearby)->\(anchor)"] = 120
        DayRoutePlanningCore.fixtureSearchResults[todo.address] = options
        DayRoutePlanningCore.fixtureRouteQueries = []
        DayRoutePlanningCore.fixtureSearchContexts = []
        DayRoutePlanningCore.fixtureSearchRegions = []
        DayRoutePlanningCore.fixtureSearchResultCounts = []
        core.evaluateGapFillers(for: gap, itinerary: itinerary, savedPlaces: [], todos: [unavailable, todo])
        await core.fixtureGapTask(gap.id)?.value
        expect(DayRoutePlanningCore.fixtureSearchContexts == ["\(anchor)->\(anchor)"],
               "valid same-anchor endpoints govern discovery despite displaced Home and live location")
        let region = DayRoutePlanningCore.fixtureSearchRegions.first
        expect(region.map { abs($0.center.latitude - 12) < 0.0001 && abs($0.center.longitude - 34) < 0.0001 } == true,
               "search region centers on the synthetic route anchor")
        expect(DayRoutePlanningCore.fixtureSearchResultCounts == [24]
                && DayRoutePlanningCore.fixtureRouteQueries.count == 8,
               "all 24 provider results reach cheap ranking and only four receive exact routing")
        expect(DayRoutePlanningCore.fixtureRouteQueries.contains("\(anchor)->\(nearby)"),
               "near-anchor place outside the original provider prefix reaches the shortlist")
        let result = core.gapRecommendationsByGapID[gap.id]?.first
        expect(result?.address == nearby && result?.fit.state == .fits,
               "exact route cost selects the nearby feasible place")
        expect(core.gapRecommendationsByGapID[gap.id]?.count == 1
                && DayRoutePlanningCore.fixtureFailures.contains(unavailable.address),
               "default Planner rejects only the failed candidate and continues without a flag")
        expect(gap.fit(.located(id: "synthetic-far", title: "Synthetic far option", durationSeconds: 1_200,
                                inboundTravelSeconds: 2_400, outboundTravelSeconds: 2_400)).state == .fits,
               "the provider-leading distant option is feasible but loses on route cost")
        print("ANONYMOUS_ROUTE_CONTEXT \(failures == priorFailures ? "PASS" : "FAIL")")

        let ties = ["Synthetic provider-first tie", "Synthetic geometric-first tie"]
        DayRoutePlanningCore.fixtureCoordinates[ties[0]] = CLLocationCoordinate2D(latitude: 12.01, longitude: 34.01)
        DayRoutePlanningCore.fixtureCoordinates[ties[1]] = CLLocationCoordinate2D(latitude: 12.001, longitude: 34.001)
        for (index, option) in ties.enumerated() {
            let legCost: TimeInterval = index == 0 ? 300.4 : 300
            DayRoutePlanningCore.fixtureTravelSecondsByLeg["\(anchor)->\(option)"] = legCost
            DayRoutePlanningCore.fixtureTravelSecondsByLeg["\(option)->\(anchor)"] = legCost
        }
        DayRoutePlanningCore.fixtureSearchResults[todo.address] = ties
        core.evaluateGapFillers(for: gap, itinerary: itinerary, savedPlaces: [], todos: [todo])
        await core.fixtureGapTask(gap.id)?.value
        expect(core.gapRecommendationsByGapID[gap.id]?.first?.address == ties[0],
               "effectively equal exact route costs preserve original provider order after shortlisting")
    }

    func run() async {
        await calendarSupportedPair()
        await routeAnchorCase()
        print("CLEAN_BASELINE \(failures == 0 ? "PASS" : "FAIL"): \(count) assertions; \(failures) failed")
    }
}

#if os(iOS)
import UIKit

private final class CleanBaselineTestDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        self.window = window
        Task { @MainActor in
            let checks = CleanBaselineChecks()
            await checks.run()
            NSLog("CLEAN_BASELINE_NATIVE %@: %d assertions; %d failed",
                  checks.failures == 0 ? "PASS" : "FAIL", checks.count, checks.failures)
            fflush(stdout)
            exit(checks.failures == 0 ? 0 : 1)
        }
        return true
    }
}

@main struct CleanBaselineNativeMain {
    static func main() {
        UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil,
                          NSStringFromClass(CleanBaselineTestDelegate.self))
    }
}
#else
@main struct CleanBaselineMain {
    @MainActor static func main() async {
        let checks = CleanBaselineChecks()
        await checks.run()
        exit(checks.failures == 0 ? 0 : 1)
    }
}
#endif
