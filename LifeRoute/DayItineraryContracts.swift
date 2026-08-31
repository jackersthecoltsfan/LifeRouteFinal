import Foundation

/// Extra margin applied once to each fixed timed appointment arrival.
/// Raw MapKit travel durations remain unchanged and independently visible.
struct LifeRouteRouteBuffer: Codable, Hashable, Sendable {
    static let maximumCustomMinutes = 180

    static let none = LifeRouteRouteBuffer(minutes: 0)
    static let fiveMinutes = LifeRouteRouteBuffer(minutes: 5)
    static let tenMinutes = LifeRouteRouteBuffer(minutes: 10)
    static let fifteenMinutes = LifeRouteRouteBuffer(minutes: 15)
    static let twentyMinutes = LifeRouteRouteBuffer(minutes: 20)
    static let thirtyMinutes = LifeRouteRouteBuffer(minutes: 30)

    static let presets: [LifeRouteRouteBuffer] = [
        .none,
        .fiveMinutes,
        .tenMinutes,
        .fifteenMinutes,
        .twentyMinutes,
        .thirtyMinutes,
    ]

    let minutes: Int

    init(minutes: Int = 10) {
        self.minutes = Self.clamped(minutes)
    }

    init(customMinutes: Int) {
        self.init(minutes: customMinutes)
    }

    var seconds: TimeInterval {
        TimeInterval(minutes * 60)
    }

    private static func clamped(_ minutes: Int) -> Int {
        min(max(0, minutes), maximumCustomMinutes)
    }

    private enum CodingKeys: String, CodingKey {
        case minutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(minutes: try container.decode(Int.self, forKey: .minutes))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(minutes, forKey: .minutes)
    }
}

/// One stable, displayable place in the generated route order.
struct LifeRouteItineraryNode: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        case origin
        case appointment
        case stop
        case home
    }

    let id: String
    let kind: Kind
    let title: String
    let address: String
    let start: Date?
    let end: Date?
    let isAllDay: Bool
    let isRoutable: Bool
    let stopDurationSeconds: TimeInterval

    init(
        id: String,
        kind: Kind,
        title: String,
        address: String,
        start: Date? = nil,
        end: Date? = nil,
        isAllDay: Bool = false,
        isRoutable: Bool? = nil,
        stopDurationSeconds: TimeInterval = 0
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.address = address
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.isRoutable = isRoutable
            ?? !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        self.stopDurationSeconds = max(0, stopDurationSeconds)
    }
}

/// One raw MapKit result between adjacent canonical itinerary nodes.
struct LifeRouteItineraryLeg: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let sequence: Int
    let fromNodeID: String
    let toNodeID: String
    let rawTravelSeconds: TimeInterval
    let rawDistanceMeters: Double

    init(
        id: String,
        sequence: Int,
        fromNodeID: String,
        toNodeID: String,
        rawTravelSeconds: TimeInterval,
        rawDistanceMeters: Double
    ) {
        self.id = id
        self.sequence = sequence
        self.fromNodeID = fromNodeID
        self.toNodeID = toNodeID
        self.rawTravelSeconds = max(0, rawTravelSeconds)
        self.rawDistanceMeters = max(0, rawDistanceMeters)
    }
}

struct LifeRouteGapCandidate: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        case located
        case locationlessTodo
    }

    let id: String
    let kind: Kind
    let title: String
    let durationSeconds: TimeInterval
    let inboundTravelSeconds: TimeInterval?
    let outboundTravelSeconds: TimeInterval?

    static func located(
        id: String,
        title: String,
        durationSeconds: TimeInterval,
        inboundTravelSeconds: TimeInterval?,
        outboundTravelSeconds: TimeInterval?
    ) -> Self {
        Self(
            id: id,
            kind: .located,
            title: title,
            durationSeconds: durationSeconds,
            inboundTravelSeconds: inboundTravelSeconds,
            outboundTravelSeconds: outboundTravelSeconds
        )
    }

    static func locationlessTodo(
        id: String,
        title: String,
        durationSeconds: TimeInterval
    ) -> Self {
        Self(
            id: id,
            kind: .locationlessTodo,
            title: title,
            durationSeconds: durationSeconds,
            inboundTravelSeconds: nil,
            outboundTravelSeconds: nil
        )
    }

    private init(
        id: String,
        kind: Kind,
        title: String,
        durationSeconds: TimeInterval,
        inboundTravelSeconds: TimeInterval?,
        outboundTravelSeconds: TimeInterval?
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.durationSeconds = max(0, durationSeconds)
        self.inboundTravelSeconds = inboundTravelSeconds.map { max(0, $0) }
        self.outboundTravelSeconds = outboundTravelSeconds.map { max(0, $0) }
    }
}

struct LifeRouteGapFitResult: Codable, Hashable, Sendable {
    enum State: String, Codable, Hashable, Sendable {
        case fits
        case doesNotFit
        case routeUnavailable
    }

    let candidateID: String
    let state: State
    let availableActivitySeconds: TimeInterval?
    let remainingSeconds: TimeInterval?
}

/// The route-safe portion of a raw interval between two timed appointments.
struct LifeRouteUsableGap: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let previousAppointmentNodeID: String
    let nextAppointmentNodeID: String
    let rawCalendarGapSeconds: TimeInterval
    let requiredTravelSeconds: TimeInterval
    let requiredStopSeconds: TimeInterval
    let bufferSeconds: TimeInterval
    let usableSeconds: TimeInterval?
    let isRouteSafe: Bool

    func fit(_ candidate: LifeRouteGapCandidate) -> LifeRouteGapFitResult {
        guard isRouteSafe, let usableSeconds else {
            return LifeRouteGapFitResult(
                candidateID: candidate.id,
                state: .routeUnavailable,
                availableActivitySeconds: nil,
                remainingSeconds: nil
            )
        }

        let available: TimeInterval
        switch candidate.kind {
        case .locationlessTodo:
            available = usableSeconds
        case .located:
            guard
                let inboundTravelSeconds = candidate.inboundTravelSeconds,
                let outboundTravelSeconds = candidate.outboundTravelSeconds
            else {
                return LifeRouteGapFitResult(
                    candidateID: candidate.id,
                    state: .routeUnavailable,
                    availableActivitySeconds: nil,
                    remainingSeconds: nil
                )
            }
            available = max(
                0,
                rawCalendarGapSeconds
                    - inboundTravelSeconds
                    - outboundTravelSeconds
                    - requiredStopSeconds
                    - bufferSeconds
            )
        }

        let remaining = available - candidate.durationSeconds
        return LifeRouteGapFitResult(
            candidateID: candidate.id,
            state: remaining >= 0 ? .fits : .doesNotFit,
            availableActivitySeconds: available,
            remainingSeconds: max(0, remaining)
        )
    }
}

struct LifeRouteDepartureGuidance: Codable, Hashable, Sendable {
    enum State: String, Codable, Hashable, Sendable {
        case leaveIn
        case leaveNow
        case overdue
    }

    let appointmentNodeID: String
    let appointmentStart: Date
    let routeOriginNodeID: String
    let intermediateStopNodeIDs: [String]
    let leaveBy: Date
    let rawTravelSeconds: TimeInterval
    let intermediateStopSeconds: TimeInterval
    let bufferSeconds: TimeInterval
    let state: State
    let secondsUntilDeparture: TimeInterval
    let overdueSeconds: TimeInterval
}

struct LifeRouteItineraryTimelineItem: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        case origin
        case drive
        case stop
        case appointment
        case usableGap
        case home
    }

    let id: String
    let kind: Kind
    let node: LifeRouteItineraryNode?
    let leg: LifeRouteItineraryLeg?
    let gap: LifeRouteUsableGap?

    fileprivate static func node(_ node: LifeRouteItineraryNode) -> Self {
        let kind: Kind
        switch node.kind {
        case .origin:
            kind = .origin
        case .appointment:
            kind = .appointment
        case .stop:
            kind = .stop
        case .home:
            kind = .home
        }
        return Self(id: "node:\(node.id)", kind: kind, node: node, leg: nil, gap: nil)
    }

    fileprivate static func drive(_ leg: LifeRouteItineraryLeg) -> Self {
        Self(id: "drive:\(leg.id)", kind: .drive, node: nil, leg: leg, gap: nil)
    }

    fileprivate static func usableGap(_ gap: LifeRouteUsableGap) -> Self {
        Self(id: "gap:\(gap.id)", kind: .usableGap, node: nil, leg: nil, gap: gap)
    }
}

/// Stable generated-day snapshot used by Today, Live Day, and Live Activity projection.
struct LifeRouteGeneratedItinerary: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let selectedDay: Date
    let generatedAt: Date
    let returnHome: Bool
    let routeBuffer: LifeRouteRouteBuffer
    let inputFingerprint: String
    let nodes: [LifeRouteItineraryNode]
    let legs: [LifeRouteItineraryLeg]

    var fingerprint: String {
        inputFingerprint
    }

    init(
        id: String,
        selectedDay: Date,
        generatedAt: Date,
        returnHome: Bool,
        routeBuffer: LifeRouteRouteBuffer,
        inputFingerprint: String,
        nodes: [LifeRouteItineraryNode],
        legs: [LifeRouteItineraryLeg]
    ) {
        self.id = id
        self.selectedDay = selectedDay
        self.generatedAt = generatedAt
        self.returnHome = returnHome
        self.routeBuffer = routeBuffer
        self.inputFingerprint = inputFingerprint
        self.nodes = Self.uniqued(nodes)
        self.legs = Self.uniqued(legs)
    }

    var totalRawTravelSeconds: TimeInterval {
        legs.reduce(0) { $0 + $1.rawTravelSeconds }
    }

    var totalRawDistanceMeters: Double {
        legs.reduce(0) { $0 + $1.rawDistanceMeters }
    }

    var usableGaps: [LifeRouteUsableGap] {
        let timedAppointmentIndices = nodes.indices.filter { index in
            let node = nodes[index]
            return node.kind == .appointment
                && !node.isAllDay
                && node.start != nil
                && node.end != nil
        }
        guard timedAppointmentIndices.count > 1 else {
            return []
        }

        let legsByPair = canonicalLegsByPair
        return zip(timedAppointmentIndices, timedAppointmentIndices.dropFirst()).compactMap {
            previousIndex,
            nextIndex in
            let previous = nodes[previousIndex]
            let next = nodes[nextIndex]
            guard
                let previousEnd = previous.end,
                let nextStart = next.start
            else {
                return nil
            }

            let rawGap = nextStart.timeIntervalSince(previousEnd)
            guard rawGap > 0 else {
                return nil
            }

            let routeRange = previousIndex...nextIndex
            let routeNodes = nodes[routeRange].filter { !$0.isAllDay }
            let nodesAreSafe = routeNodes.allSatisfy { node in
                guard node.isRoutable else {
                    return false
                }
                if node.kind == .appointment {
                    return node.start != nil && node.end != nil
                }
                return true
            }

            var requiredTravel: TimeInterval = 0
            var allLegsPresent = true
            for (source, destination) in zip(routeNodes, routeNodes.dropFirst()) {
                let key = LegKey(fromNodeID: source.id, toNodeID: destination.id)
                guard let leg = legsByPair[key] else {
                    allLegsPresent = false
                    continue
                }
                requiredTravel += leg.rawTravelSeconds
            }

            let requiredStop = routeNodes.dropFirst().dropLast().reduce(0) {
                result,
                node in
                result + (node.kind == .stop ? node.stopDurationSeconds : 0)
            }
            let isRouteSafe = nodesAreSafe && allLegsPresent
            let usable = isRouteSafe
                ? max(0, rawGap - requiredTravel - requiredStop - routeBuffer.seconds)
                : nil

            return LifeRouteUsableGap(
                id: "\(previous.id)->\(next.id)",
                previousAppointmentNodeID: previous.id,
                nextAppointmentNodeID: next.id,
                rawCalendarGapSeconds: rawGap,
                requiredTravelSeconds: requiredTravel,
                requiredStopSeconds: requiredStop,
                bufferSeconds: routeBuffer.seconds,
                usableSeconds: usable,
                isRouteSafe: isRouteSafe
            )
        }
    }

    var timeline: [LifeRouteItineraryTimelineItem] {
        let safeGapsByPreviousNodeID = Dictionary(
            uniqueKeysWithValues: usableGaps.compactMap { gap in
                gap.isRouteSafe ? (gap.previousAppointmentNodeID, gap) : nil
            }
        )
        let legsByDestination = legs.sorted { $0.sequence < $1.sequence }.reduce(
            into: [String: LifeRouteItineraryLeg]()
        ) {
            result,
            leg in
            if result[leg.toNodeID] == nil {
                result[leg.toNodeID] = leg
            }
        }
        var items: [LifeRouteItineraryTimelineItem] = []

        for index in nodes.indices {
            let node = nodes[index]
            if let leg = legsByDestination[node.id] {
                items.append(.drive(leg))
            }
            items.append(.node(node))
            if let gap = safeGapsByPreviousNodeID[node.id] {
                items.append(.usableGap(gap))
            }
        }
        return items
    }

    func departureGuidance(at now: Date) -> LifeRouteDepartureGuidance? {
        guard let targetIndex = nodes.indices.first(where: { index in
            let node = nodes[index]
            return node.kind == .appointment
                && !node.isAllDay
                && node.start.map { $0 >= now } == true
        }) else {
            return nil
        }

        let target = nodes[targetIndex]
        guard target.isRoutable, let appointmentStart = target.start else {
            return nil
        }

        let previousTimedAppointmentIndex = nodes.indices[..<targetIndex].last { index in
            let node = nodes[index]
            return node.kind == .appointment
                && !node.isAllDay
                && node.start != nil
                && node.end != nil
        }
        let routeOriginIndex = previousTimedAppointmentIndex ?? nodes.startIndex
        guard routeOriginIndex < targetIndex else {
            return nil
        }

        let routeRange = routeOriginIndex...targetIndex
        let routeNodes = nodes[routeRange].filter { !$0.isAllDay }
        guard routeNodes.allSatisfy({ node in
            guard node.isRoutable else {
                return false
            }
            if node.kind == .appointment && node.id != target.id && node.id != nodes[routeOriginIndex].id {
                return false
            }
            return !node.isAllDay
        }) else {
            return nil
        }

        let legsByPair = canonicalLegsByPair
        var rawTravel: TimeInterval = 0
        for (source, destination) in zip(routeNodes, routeNodes.dropFirst()) {
            let key = LegKey(fromNodeID: source.id, toNodeID: destination.id)
            guard let leg = legsByPair[key] else {
                return nil
            }
            rawTravel += leg.rawTravelSeconds
        }

        let intermediateStops = routeNodes.dropFirst().dropLast().filter {
            $0.kind == .stop
        }
        let stopSeconds = intermediateStops.reduce(0) { $0 + $1.stopDurationSeconds }
        let leaveBy = appointmentStart.addingTimeInterval(
            -(rawTravel + stopSeconds + routeBuffer.seconds)
        )
        let delta = leaveBy.timeIntervalSince(now)
        let state: LifeRouteDepartureGuidance.State
        let secondsUntilDeparture: TimeInterval
        let overdueSeconds: TimeInterval
        if delta > 0 {
            state = .leaveIn
            secondsUntilDeparture = floor(delta)
            overdueSeconds = 0
        } else if delta < 0 {
            state = .overdue
            secondsUntilDeparture = 0
            overdueSeconds = floor(-delta)
        } else {
            state = .leaveNow
            secondsUntilDeparture = 0
            overdueSeconds = 0
        }

        return LifeRouteDepartureGuidance(
            appointmentNodeID: target.id,
            appointmentStart: appointmentStart,
            routeOriginNodeID: nodes[routeOriginIndex].id,
            intermediateStopNodeIDs: intermediateStops.map(\.id),
            leaveBy: leaveBy,
            rawTravelSeconds: rawTravel,
            intermediateStopSeconds: stopSeconds,
            bufferSeconds: routeBuffer.seconds,
            state: state,
            secondsUntilDeparture: secondsUntilDeparture,
            overdueSeconds: overdueSeconds
        )
    }

    private var canonicalLegsByPair: [LegKey: LifeRouteItineraryLeg] {
        legs.reduce(into: [:]) { result, leg in
            let key = LegKey(fromNodeID: leg.fromNodeID, toNodeID: leg.toNodeID)
            if result[key] == nil {
                result[key] = leg
            }
        }
    }

    private static func uniqued<Element: Identifiable>(_ values: [Element]) -> [Element]
    where Element.ID: Hashable {
        var seen: Set<Element.ID> = []
        return values.filter { seen.insert($0.id).inserted }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case selectedDay
        case generatedAt
        case returnHome
        case routeBuffer
        case inputFingerprint
        case nodes
        case legs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            selectedDay: try container.decode(Date.self, forKey: .selectedDay),
            generatedAt: try container.decode(Date.self, forKey: .generatedAt),
            returnHome: try container.decode(Bool.self, forKey: .returnHome),
            routeBuffer: try container.decode(LifeRouteRouteBuffer.self, forKey: .routeBuffer),
            inputFingerprint: try container.decode(String.self, forKey: .inputFingerprint),
            nodes: try container.decode([LifeRouteItineraryNode].self, forKey: .nodes),
            legs: try container.decode([LifeRouteItineraryLeg].self, forKey: .legs)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(selectedDay, forKey: .selectedDay)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(returnHome, forKey: .returnHome)
        try container.encode(routeBuffer, forKey: .routeBuffer)
        try container.encode(inputFingerprint, forKey: .inputFingerprint)
        try container.encode(nodes, forKey: .nodes)
        try container.encode(legs, forKey: .legs)
    }
}

struct LifeRouteLiveDayProjection: Codable, Hashable, Sendable {
    let departure: LifeRouteDepartureGuidance
    let phaseLabel: String
    let primaryTitle: String
    let secondaryText: String?
    let countdownTarget: Date
    let appointmentStart: Date
    let appointmentEnd: Date?
    let routeSummary: String
    let plannedStopSummary: String?
    let returnHomePlanned: Bool

    static func make(
        from itinerary: LifeRouteGeneratedItinerary,
        at now: Date
    ) -> Self? {
        guard
            let departure = itinerary.departureGuidance(at: now),
            let appointment = itinerary.nodes.first(where: {
                $0.id == departure.appointmentNodeID
            })
        else {
            return nil
        }

        let phaseLabel: String
        let countdownTarget: Date
        switch departure.state {
        case .leaveIn:
            phaseLabel = "LEAVE IN"
            countdownTarget = departure.leaveBy
        case .leaveNow:
            phaseLabel = "LEAVE NOW"
            countdownTarget = departure.appointmentStart
        case .overdue:
            phaseLabel = "LEAVE NOW · DUE IN"
            countdownTarget = departure.appointmentStart
        }

        let rawMinutes = roundedUpMinutes(departure.rawTravelSeconds)
        let bufferMinutes = roundedUpMinutes(departure.bufferSeconds)
        let routeSummary = bufferMinutes > 0
            ? "\(rawMinutes) min drive · +\(bufferMinutes) min buffer"
            : "\(rawMinutes) min drive · no buffer"
        let stopsByID = Dictionary(uniqueKeysWithValues: itinerary.nodes.map { ($0.id, $0) })
        let stopLabels = departure.intermediateStopNodeIDs.compactMap { id -> String? in
            guard let stop = stopsByID[id] else {
                return nil
            }
            return "\(stop.title) · \(roundedUpMinutes(stop.stopDurationSeconds)) min"
        }

        return Self(
            departure: departure,
            phaseLabel: phaseLabel,
            primaryTitle: appointment.title,
            secondaryText: appointment.address.isEmpty ? nil : appointment.address,
            countdownTarget: countdownTarget,
            appointmentStart: departure.appointmentStart,
            appointmentEnd: appointment.end,
            routeSummary: routeSummary,
            plannedStopSummary: stopLabels.isEmpty ? nil : stopLabels.joined(separator: " · "),
            returnHomePlanned: itinerary.returnHome
        )
    }

    private static func roundedUpMinutes(_ seconds: TimeInterval) -> Int {
        Int(ceil(max(0, seconds) / 60))
    }
}

private struct LegKey: Hashable {
    let fromNodeID: String
    let toNodeID: String
}
