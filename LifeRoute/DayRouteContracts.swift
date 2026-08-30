import Foundation

struct LifeRouteDayStop: Identifiable, Codable, Hashable {
    enum Position: String, CaseIterable, Codable, Identifiable {
        case before = "Before first appointment"
        case after = "After last appointment"

        var id: String { rawValue }
    }

    let id: UUID
    var title: String
    var address: String
    var position: Position
    var day: Date

    init(
        id: UUID = UUID(),
        title: String,
        address: String,
        position: Position,
        day: Date
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        self.position = position
        self.day = Calendar.current.startOfDay(for: day)
    }
}

enum LifeRouteDayStopCollection {
    static func adding(
        _ candidate: LifeRouteDayStop,
        to input: [LifeRouteDayStop],
        calendar: Calendar = .current
    ) -> (stops: [LifeRouteDayStop], inserted: Bool) {
        let current = sanitized(input, calendar: calendar)
        let cleanCandidate = sanitized([candidate], calendar: calendar)
        guard let candidate = cleanCandidate.first,
              !current.contains(where: { duplicateKey(for: $0, calendar: calendar) == duplicateKey(for: candidate, calendar: calendar) }) else {
            return (current, false)
        }
        return (current + [candidate], true)
    }

    static func removing(id: UUID, from input: [LifeRouteDayStop]) -> [LifeRouteDayStop] {
        input.filter { $0.id != id }
    }

    static func stops(
        on day: Date,
        in input: [LifeRouteDayStop],
        calendar: Calendar = .current
    ) -> [LifeRouteDayStop] {
        let target = calendar.startOfDay(for: day)
        return sanitized(input, calendar: calendar).filter {
            calendar.isDate($0.day, inSameDayAs: target)
        }
    }

    static func sanitized(
        _ input: [LifeRouteDayStop],
        calendar: Calendar = .current
    ) -> [LifeRouteDayStop] {
        var seenIDs = Set<UUID>()
        var seenSemanticKeys = Set<String>()
        return input.compactMap { stop in
            let clean = LifeRouteDayStop(
                id: stop.id,
                title: stop.title,
                address: stop.address,
                position: stop.position,
                day: calendar.startOfDay(for: stop.day)
            )
            guard !clean.title.isEmpty,
                  !clean.address.isEmpty,
                  seenIDs.insert(clean.id).inserted,
                  seenSemanticKeys.insert(duplicateKey(for: clean, calendar: calendar)).inserted else {
                return nil
            }
            return clean
        }
    }

    private static func duplicateKey(for stop: LifeRouteDayStop, calendar: Calendar) -> String {
        let day = calendar.startOfDay(for: stop.day).timeIntervalSinceReferenceDate
        let title = stop.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let address = stop.address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(day)|\(stop.position.rawValue)|\(title)|\(address)"
    }
}

struct LifeRouteRouteAppointment: Identifiable, Hashable {
    let id: String
    var title: String
    var address: String
    var start: Date

    init(id: String, title: String, address: String, start: Date) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        self.start = start
    }
}

struct LifeRouteDayWaypoint: Identifiable, Hashable {
    enum Kind: Hashable {
        case stop
        case appointment
    }

    let id: String
    let title: String
    let address: String
    let kind: Kind
}

enum LifeRouteDaySequenceBuilder {
    static func waypoints(
        appointments: [LifeRouteRouteAppointment],
        beforeStops: [LifeRouteDayStop],
        afterStops: [LifeRouteDayStop]
    ) -> [LifeRouteDayWaypoint] {
        let before = uniqueStops(beforeStops).map {
            LifeRouteDayWaypoint(id: "stop:\($0.id.uuidString)", title: $0.title, address: $0.address, kind: .stop)
        }
        let events = appointments
            .sorted {
                if $0.start != $1.start { return $0.start < $1.start }
                return $0.id < $1.id
            }
            .map {
                LifeRouteDayWaypoint(
                    id: "event:\($0.id)",
                    title: $0.title.isEmpty ? "Appointment" : $0.title,
                    address: $0.address,
                    kind: .appointment
                )
            }
        let after = uniqueStops(afterStops).map {
            LifeRouteDayWaypoint(id: "stop:\($0.id.uuidString)", title: $0.title, address: $0.address, kind: .stop)
        }
        return before + events + after
    }

    private static func uniqueStops(_ input: [LifeRouteDayStop]) -> [LifeRouteDayStop] {
        var seen = Set<UUID>()
        return input.filter { !$0.address.isEmpty && seen.insert($0.id).inserted }
    }
}
