import Foundation

struct LegacyMigrationPayload {
    var clients: [LifeRouteClientProfile]
    var manualCalendarEvents: [LifeRouteCalendarEvent]
    var homeAddress: String
    var savedPlaces: [LifeRouteSavedPlace]

    static let empty = LegacyMigrationPayload(
        clients: [],
        manualCalendarEvents: [],
        homeAddress: "",
        savedPlaces: []
    )

    var isEmpty: Bool {
        clients.isEmpty && manualCalendarEvents.isEmpty && homeAddress.isEmpty && savedPlaces.isEmpty
    }
}

enum LegacyMigrationCore {
    private static let legacyCalendarTitle = "Imported from LifeRoute v0.4"

    static func mapLegacyV4State(
        data: Data,
        dedicatedHomeAddress: String? = nil,
        calendar inputCalendar: Calendar = .current
    ) -> LegacyMigrationPayload {
        guard let root = try? JSONSerialization.jsonObject(with: data),
              let state = root as? [String: Any] else {
            return .empty
        }

        var calendar = inputCalendar
        calendar.locale = .current
        calendar.timeZone = .current

        let prefs = state["prefs"] as? [String: Any] ?? [:]
        let rawPlaces = state["places"] as? [[String: Any]] ?? []

        let clients = mapClients(prefs["clients"] as? [[String: Any]] ?? [])
        let events = mapManualEvents(state["events"] as? [[String: Any]] ?? [], calendar: calendar)
        let places = mapPlaces(rawPlaces)
        let home = resolveHomeAddress(
            dedicated: dedicatedHomeAddress,
            preferences: prefs,
            rawPlaces: rawPlaces
        )

        return LegacyMigrationPayload(
            clients: clients,
            manualCalendarEvents: events,
            homeAddress: home,
            savedPlaces: places
        )
    }

    private static func mapClients(_ rawClients: [[String: Any]]) -> [LifeRouteClientProfile] {
        var seenCodes = Set<String>()
        var output: [LifeRouteClientProfile] = []

        for raw in rawClients {
            let first = ClientProfileCore.normalizedPair(string(raw["first2"]))
            let last = ClientProfileCore.normalizedPair(string(raw["last2"]))
            guard first.count == 2, last.count == 2 else { continue }
            let code = first + last
            let key = code.lowercased()
            guard seenCodes.insert(key).inserted else { continue }

            output.append(
                LifeRouteClientProfile(
                    id: deterministicUUID(namespace: "legacy-client", value: key),
                    first2: first,
                    last2: last,
                    address: clean(raw["address"]),
                    preferredActivities: list(raw["preferredActivities"] ?? raw["reinforcers"]),
                    currentTargets: list(raw["currentTargets"] ?? raw["targets"]),
                    behaviorsOfConcern: list(raw["behaviorsOfConcern"] ?? raw["behaviors"]),
                    communicationNotes: clean(raw["communicationNotes"] ?? raw["fctNotes"]),
                    promptingNotes: clean(raw["promptingNotes"] ?? raw["reinforcementNotes"]),
                    caregiverNotes: clean(raw["caregiverNotes"] ?? raw["settingNotes"]),
                    clinicalNotes: clean(raw["clinicalNotes"] ?? raw["notes"]),
                    updatedAt: isoDate(raw["updatedAt"]) ?? Date(timeIntervalSince1970: 0)
                )
            )
        }

        return output.sorted { $0.code.localizedCaseInsensitiveCompare($1.code) == .orderedAscending }
    }

    private static func mapManualEvents(
        _ rawEvents: [[String: Any]],
        calendar: Calendar
    ) -> [LifeRouteCalendarEvent] {
        var seenIDs = Set<String>()
        var output: [LifeRouteCalendarEvent] = []

        for (index, raw) in rawEvents.enumerated() {
            let source = clean(raw["source"]).lowercased()
            guard source.isEmpty || source == "manual" else { continue }

            let dateString = clean(raw["date"])
            guard let day = dateComponents(dateString) else { continue }
            let allDay = bool(raw["allDay"])

            let start: Date
            let end: Date
            if allDay {
                var components = day
                components.hour = 0
                components.minute = 0
                guard let resolvedStart = calendar.date(from: components),
                      let resolvedEnd = calendar.date(byAdding: .day, value: 1, to: resolvedStart) else { continue }
                start = resolvedStart
                end = resolvedEnd
            } else {
                guard let startTime = timeComponents(clean(raw["start"])),
                      let endTime = timeComponents(clean(raw["end"])) else { continue }
                var startParts = day
                startParts.hour = startTime.hour
                startParts.minute = startTime.minute
                var endParts = day
                endParts.hour = endTime.hour
                endParts.minute = endTime.minute
                guard let resolvedStart = calendar.date(from: startParts),
                      let resolvedEnd = calendar.date(from: endParts),
                      resolvedEnd > resolvedStart else { continue }
                start = resolvedStart
                end = resolvedEnd
            }

            let oldID = clean(raw["id"])
            let stableSourceID = oldID.isEmpty
                ? "\(dateString)|\(clean(raw["start"]))|\(clean(raw["title"]))|\(index)"
                : oldID
            let id = "legacy-v4-\(stableSourceID)"
            guard seenIDs.insert(id).inserted else { continue }

            let title = clean(raw["title"])
            let location = clean(raw["address"] ?? raw["location"])
            output.append(
                LifeRouteCalendarEvent(
                    id: id,
                    title: title.isEmpty ? "Appointment" : title,
                    start: start,
                    end: end,
                    location: location,
                    calendarTitle: legacyCalendarTitle,
                    isAllDay: allDay,
                    source: .manual
                )
            )
        }

        return output.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private static func mapPlaces(_ rawPlaces: [[String: Any]]) -> [LifeRouteSavedPlace] {
        var seenKeys = Set<String>()
        var output: [LifeRouteSavedPlace] = []

        for raw in rawPlaces {
            let name = clean(raw["name"])
            let address = clean(raw["address"])
            guard !name.isEmpty, !address.isEmpty else { continue }

            let identity = "\(name.lowercased())|\(address.lowercased())"
            guard seenKeys.insert(identity).inserted else { continue }

            let legacyID = clean(raw["id"])
            let idSeed = legacyID.isEmpty ? identity : legacyID
            let minimumVisit = integer(raw["minVisit"] ?? raw["min"], fallback: 60)
            let useInGaps = raw.keys.contains("useInGaps")
                ? bool(raw["useInGaps"])
                : clean(raw["member"]).lowercased() == "yes"

            output.append(
                LifeRouteSavedPlace(
                    id: deterministicUUID(namespace: "legacy-place", value: idSeed),
                    name: name,
                    address: address,
                    kind: placeKind(clean(raw["type"])),
                    minimumVisitMinutes: minimumVisit,
                    useInGapSuggestions: useInGaps
                )
            )
        }

        return output.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func resolveHomeAddress(
        dedicated: String?,
        preferences: [String: Any],
        rawPlaces: [[String: Any]]
    ) -> String {
        let dedicatedValue = dedicated?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !dedicatedValue.isEmpty { return dedicatedValue }

        let preference = clean(preferences["homeAddress"])
        if !preference.isEmpty { return preference }

        return rawPlaces.first {
            clean($0["type"]).caseInsensitiveCompare("Home") == .orderedSame
        }.map { clean($0["address"]) } ?? ""
    }

    private static func placeKind(_ raw: String) -> LifeRoutePlaceKind {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "gym": return .gym
        case "work": return .work
        case "coffee", "cafe", "café": return .coffee
        case "grocery", "groceries", "store": return .grocery
        case "park": return .park
        case "library": return .library
        case "errand": return .errand
        default: return .other
        }
    }

    private static func dateComponents(_ value: String) -> DateComponents? {
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1...12).contains(month),
              (1...31).contains(day) else { return nil }
        return DateComponents(year: year, month: month, day: day)
    }

    private static func timeComponents(_ value: String) -> (hour: Int, minute: Int)? {
        let parts = value.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else { return nil }
        return (hour, minute)
    }

    private static func list(_ value: Any?) -> [String] {
        let rawValues: [String]
        if let values = value as? [String] {
            rawValues = values
        } else if let value = value as? String {
            rawValues = value.components(separatedBy: CharacterSet(charactersIn: "\n,;"))
        } else if let values = value as? [Any] {
            rawValues = values.map { string($0) }
        } else {
            rawValues = []
        }

        var seen = Set<String>()
        var output: [String] = []
        for raw in rawValues {
            let item = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = item.lowercased()
            guard !item.isEmpty, seen.insert(key).inserted else { continue }
            output.append(item)
            if output.count == 60 { break }
        }
        return output
    }

    private static func isoDate(_ value: Any?) -> Date? {
        let raw = clean(value)
        guard !raw.isEmpty else { return nil }
        return ISO8601DateFormatter().date(from: raw)
    }

    private static func integer(_ value: Any?, fallback: Int) -> Int {
        if let number = value as? NSNumber { return number.intValue }
        if let text = value as? String, let number = Int(text) { return number }
        return fallback
    }

    private static func bool(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let number = value as? NSNumber { return number.boolValue }
        switch clean(value).lowercased() {
        case "true", "yes", "1", "on": return true
        default: return false
        }
    }

    private static func clean(_ value: Any?) -> String {
        string(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func string(_ value: Any?) -> String {
        if let value = value as? String { return value }
        if let number = value as? NSNumber { return number.stringValue }
        return ""
    }

    private static func deterministicUUID(namespace: String, value: String) -> UUID {
        let bytes = Array("\(namespace)|\(value)".utf8)
        let first = fnv1a64(bytes, offset: 0xcbf29ce484222325)
        let second = fnv1a64(bytes.reversed(), offset: 0x84222325cbf29ce4)
        let hex = String(format: "%016llx%016llx", first, second)
        let uuidString = [
            String(hex.prefix(8)),
            String(hex.dropFirst(8).prefix(4)),
            String(hex.dropFirst(12).prefix(4)),
            String(hex.dropFirst(16).prefix(4)),
            String(hex.dropFirst(20).prefix(12))
        ].joined(separator: "-")
        return UUID(uuidString: uuidString) ?? UUID()
    }

    private static func fnv1a64<S: Sequence>(_ bytes: S, offset: UInt64) -> UInt64 where S.Element == UInt8 {
        var hash = offset
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }
}
