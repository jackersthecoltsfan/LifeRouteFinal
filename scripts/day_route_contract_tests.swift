import Foundation

@main
struct DayRouteContractTests {
    private static var assertionCount = 0

    static func main() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = ISO8601DateFormatter().date(from: "2026-08-30T12:00:00Z")!
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!

        let before = LifeRouteDayStop(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: "Pharmacy",
            address: "1 Main Street",
            position: .before,
            day: day
        )
        let after = LifeRouteDayStop(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: "Grocery",
            address: "2 Main Street",
            position: .after,
            day: day
        )

        var stored: [LifeRouteDayStop] = []
        let firstInsert = LifeRouteDayStopCollection.adding(before, to: stored, calendar: calendar)
        stored = firstInsert.stops
        expect(firstInsert.inserted, "first stop inserts")
        expect(stored.count == 1, "first stop is retained")

        let duplicate = LifeRouteDayStop(
            title: " Pharmacy ",
            address: " 1 MAIN STREET ",
            position: .before,
            day: day
        )
        let duplicateInsert = LifeRouteDayStopCollection.adding(duplicate, to: stored, calendar: calendar)
        stored = duplicateInsert.stops
        expect(!duplicateInsert.inserted, "semantic duplicate is rejected")
        expect(stored.count == 1, "duplicate is not inserted")

        let secondInsert = LifeRouteDayStopCollection.adding(after, to: stored, calendar: calendar)
        stored = secondInsert.stops
        expect(secondInsert.inserted, "distinct stop inserts")
        expect(LifeRouteDayStopCollection.stops(on: day, in: stored, calendar: calendar).count == 2, "same-day stops restore")
        expect(LifeRouteDayStopCollection.stops(on: nextDay, in: stored, calendar: calendar).isEmpty, "stops remain scoped to their day")

        let appointments = [
            LifeRouteRouteAppointment(id: "late", title: "Second appointment", address: "20 Main Street", start: day.addingTimeInterval(7_200)),
            LifeRouteRouteAppointment(id: "unlocated", title: "Remote appointment", address: "", start: day.addingTimeInterval(5_400)),
            LifeRouteRouteAppointment(id: "early", title: "First appointment", address: "10 Main Street", start: day.addingTimeInterval(3_600))
        ]
        let sequence = LifeRouteDaySequenceBuilder.waypoints(
            appointments: appointments,
            beforeStops: [before, before],
            afterStops: [after, after]
        )

        expect(sequence.map(\.title) == ["Pharmacy", "First appointment", "Remote appointment", "Second appointment", "Grocery"], "full-day sequence preserves boundary-stop and appointment order")
        expect(sequence.filter { $0.kind == .stop }.count == 2, "each intended stop appears once")
        expect(sequence.filter { $0.kind == .appointment }.count == 3, "all appointments remain in the generated day")
        expect(sequence.contains { $0.title == "Remote appointment" && $0.address.isEmpty }, "events without a route address are not silently removed")
        expect(!LifeRouteDaySequenceBuilder.waypoints(appointments: [], beforeStops: [before], afterStops: []).isEmpty, "a saved stop can generate a stop-only day")

        let encoded = try JSONEncoder().encode(stored)
        let decoded = try JSONDecoder().decode([LifeRouteDayStop].self, from: encoded)
        expect(decoded == stored, "persisted stops round-trip with stable identity")

        let removed = LifeRouteDayStopCollection.removing(id: before.id, from: decoded)
        expect(removed.count == 1 && removed.first?.id == after.id, "removal prevents a deleted stop from returning")

        testFullRouteHandoffs()

        precondition(assertionCount >= 30, "Day Route contract assertion floor regressed below 30")
        print("Day route executable contract fixtures passed (\(assertionCount) assertions).")
    }

    private static func testFullRouteHandoffs() {
        let fourLegs = routeLegs(count: 4)
        let googlePlan = LifeRouteFullRouteHandoffPlanner.plan(
            provider: .googleMaps,
            legs: fourLegs,
            travelMode: "driving"
        )!
        expect(googlePlan.orderedLegs == fourLegs, "Google full-route planning preserves the exact leg order")
        expect(!googlePlan.requiresSequentialContinuation, "Google uses one complete handoff within the mobile waypoint limit")
        if case .completeGoogleMaps(let url) = googlePlan.strategy {
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            expect(query.first(where: { $0.name == "origin" }) == nil, "Google omits origin for current-location routes")
            expect(query.first(where: { $0.name == "destination" })?.value == "4 Main Street", "Google keeps the final ordered destination")
            expect(query.first(where: { $0.name == "waypoints" })?.value == "1 Main Street|2 Main Street|3 Main Street", "Google preserves every intermediate waypoint in order")
            expect(url.absoluteString.count <= LifeRouteFullRouteHandoffPlanner.maximumURLLength, "Google complete handoff stays within the documented URL limit")
        } else {
            expect(false, "Google within-limit route produces a complete URL")
        }

        let overLimitGoogle = LifeRouteFullRouteHandoffPlanner.plan(
            provider: .googleMaps,
            legs: routeLegs(count: 5),
            travelMode: "driving"
        )!
        expect(overLimitGoogle.requiresSequentialContinuation, "Google never truncates a route beyond three mobile waypoints")
        expect(overLimitGoogle.orderedLegs.count == 5, "Google fallback retains every ordered leg")

        let longAddress = String(repeating: "Long Address Segment ", count: 150)
        let oversizedURLPlan = LifeRouteFullRouteHandoffPlanner.plan(
            provider: .googleMaps,
            legs: [
                LifeRouteFullRouteLegDescriptor(sequence: 1, fromTitle: "Home", fromAddress: longAddress, toTitle: "Stop", toAddress: longAddress)
            ],
            travelMode: "driving"
        )!
        expect(oversizedURLPlan.requiresSequentialContinuation, "Google falls back rather than emitting an oversized URL")

        let appleSingle = LifeRouteFullRouteHandoffPlanner.plan(
            provider: .appleMaps,
            legs: routeLegs(count: 1),
            travelMode: "driving"
        )!
        expect(appleSingle.strategy == .completeAppleMaps, "Apple hands off a complete single-leg route")

        let appleMulti = LifeRouteFullRouteHandoffPlanner.plan(
            provider: .appleMaps,
            legs: fourLegs,
            travelMode: "driving"
        )!
        expect(appleMulti.requiresSequentialContinuation, "Apple multi-leg routes use LifeRoute sequential continuation")
        expect(appleMulti.orderedLegs == fourLegs, "Apple continuation retains the exact ordered legs")

        let wazePlan = LifeRouteFullRouteHandoffPlanner.plan(
            provider: .waze,
            legs: fourLegs,
            travelMode: "driving"
        )!
        expect(wazePlan.requiresSequentialContinuation, "Waze uses explicit sequential fallback")
        expect(wazePlan.orderedLegs == fourLegs, "Waze fallback retains every ordered leg")

        let malformed = [fourLegs[1], fourLegs[0]]
        let malformedPlan = LifeRouteFullRouteHandoffPlanner.plan(
            provider: .googleMaps,
            legs: malformed,
            travelMode: "driving"
        )!
        expect(malformedPlan.requiresSequentialContinuation, "an unverified sequence never receives a complete provider handoff")
        expect(malformedPlan.orderedLegs == malformed, "fallback never silently sorts or rewrites malformed input")
    }

    private static func routeLegs(count: Int) -> [LifeRouteFullRouteLegDescriptor] {
        (1...count).map { sequence in
            LifeRouteFullRouteLegDescriptor(
                sequence: sequence,
                fromTitle: sequence == 1 ? "Current Location" : "Stop \(sequence - 1)",
                fromAddress: sequence == 1 ? "Current Location" : "\(sequence - 1) Main Street",
                toTitle: "Stop \(sequence)",
                toAddress: "\(sequence) Main Street"
            )
        }
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertionCount += 1
        guard condition() else {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
