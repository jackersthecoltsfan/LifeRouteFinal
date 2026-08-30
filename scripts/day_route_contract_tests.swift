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

        print("Day route executable contract fixtures passed (\(assertionCount) assertions).")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertionCount += 1
        guard condition() else {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
