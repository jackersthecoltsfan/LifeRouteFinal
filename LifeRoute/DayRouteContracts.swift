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
    var savedPlaceID: UUID?
    var durationMinutes: Int
    var afterAppointmentID: String?

    init(
        id: UUID = UUID(),
        title: String,
        address: String,
        position: Position,
        day: Date,
        savedPlaceID: UUID? = nil,
        durationMinutes: Int = 20,
        afterAppointmentID: String? = nil
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        self.position = position
        self.day = Calendar.current.startOfDay(for: day)
        self.savedPlaceID = savedPlaceID
        self.durationMinutes = max(5, min(240, durationMinutes))
        let cleanAnchor = afterAppointmentID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.afterAppointmentID = cleanAnchor?.isEmpty == false ? cleanAnchor : nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case address
        case position
        case day
        case savedPlaceID
        case durationMinutes
        case afterAppointmentID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            address: try container.decode(String.self, forKey: .address),
            position: try container.decode(Position.self, forKey: .position),
            day: try container.decode(Date.self, forKey: .day),
            savedPlaceID: try container.decodeIfPresent(UUID.self, forKey: .savedPlaceID),
            durationMinutes: try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 20,
            afterAppointmentID: try container.decodeIfPresent(String.self, forKey: .afterAppointmentID)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(address, forKey: .address)
        try container.encode(position, forKey: .position)
        try container.encode(day, forKey: .day)
        try container.encodeIfPresent(savedPlaceID, forKey: .savedPlaceID)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encodeIfPresent(afterAppointmentID, forKey: .afterAppointmentID)
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
                day: calendar.startOfDay(for: stop.day),
                savedPlaceID: stop.savedPlaceID,
                durationMinutes: stop.durationMinutes,
                afterAppointmentID: stop.afterAppointmentID
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
        let anchor = stop.afterAppointmentID?.lowercased() ?? ""
        return "\(day)|\(stop.position.rawValue)|\(anchor)|\(title)|\(address)"
    }
}

struct LifeRouteRouteAppointment: Identifiable, Hashable {
    let id: String
    var title: String
    var address: String
    var start: Date
    var end: Date
    var isAllDay: Bool

    init(
        id: String,
        title: String,
        address: String,
        start: Date,
        end: Date? = nil,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        self.start = start
        self.end = max(start, end ?? start)
        self.isAllDay = isAllDay
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
        let uniqueAfter = uniqueStops(afterStops)
        let appointments = appointments.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.id < $1.id
        }
        let anchoredIDs = Set(appointments.map(\.id))
        let eventsAndAnchoredStops = appointments.flatMap { appointment -> [LifeRouteDayWaypoint] in
            let event = LifeRouteDayWaypoint(
                id: "event:\(appointment.id)",
                title: appointment.title.isEmpty ? "Appointment" : appointment.title,
                address: appointment.address,
                kind: .appointment
            )
            let anchored = uniqueAfter.filter { $0.afterAppointmentID == appointment.id }.map {
                LifeRouteDayWaypoint(id: "stop:\($0.id.uuidString)", title: $0.title, address: $0.address, kind: .stop)
            }
            return [event] + anchored
        }
        let after = uniqueAfter.filter {
            guard let anchor = $0.afterAppointmentID else { return true }
            return !anchoredIDs.contains(anchor)
        }.map {
            LifeRouteDayWaypoint(id: "stop:\($0.id.uuidString)", title: $0.title, address: $0.address, kind: .stop)
        }
        return before + eventsAndAnchoredStops + after
    }

    private static func uniqueStops(_ input: [LifeRouteDayStop]) -> [LifeRouteDayStop] {
        var seen = Set<UUID>()
        return input.filter { !$0.address.isEmpty && seen.insert($0.id).inserted }
    }
}
