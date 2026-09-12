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

struct LifeRouteItineraryNavigationLeg: Hashable, Sendable {
    let leg: LifeRouteItineraryLeg
    let source: LifeRouteItineraryNode
    let destination: LifeRouteItineraryNode
}

enum LifeRouteDayNavigationDecision: Hashable, Sendable {
    case ready(LifeRouteItineraryNavigationLeg)
    case stale
    case wrongDay
    case noPhysicalDestination

    var navigationLeg: LifeRouteItineraryNavigationLeg? {
        guard case .ready(let navigationLeg) = self else { return nil }
        return navigationLeg
    }

    var leg: LifeRouteItineraryLeg? { navigationLeg?.leg }
    var destination: LifeRouteItineraryNode? { navigationLeg?.destination }
}

struct LifeRouteMapsLaunchGate {
    private var activeToken: UUID?

    var isLaunching: Bool { activeToken != nil }

    mutating func begin() -> UUID? {
        guard activeToken == nil else { return nil }
        let token = UUID()
        activeToken = token
        return token
    }

    mutating func finish(_ token: UUID) {
        guard activeToken == token else { return }
        activeToken = nil
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

            let routeOriginIndex = nodes.indices[...previousIndex].last { index in
                let node = nodes[index]
                return node.isRoutable && !node.isAllDay
            }
            let routeDestinationIndex = nodes.indices[previousIndex...nextIndex].last { index in
                let node = nodes[index]
                return node.isRoutable && !node.isAllDay
            } ?? routeOriginIndex
            let routeNodes: [LifeRouteItineraryNode]
            if let routeOriginIndex,
               let routeDestinationIndex,
               routeOriginIndex <= routeDestinationIndex {
                routeNodes = nodes[routeOriginIndex...routeDestinationIndex].filter {
                    $0.isRoutable && !$0.isAllDay
                }
            } else {
                routeNodes = []
            }
            let hasUnsafePlannedStop = nodes[previousIndex...nextIndex].contains { node in
                node.kind == .stop && !node.isRoutable
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

            let requiredStop = nodes[previousIndex...nextIndex].dropFirst().dropLast().reduce(0) {
                result,
                node in
                result + (node.kind == .stop ? node.stopDurationSeconds : 0)
            }
            let arrivalBuffer = next.isRoutable ? routeBuffer.seconds : 0
            let isRouteSafe = routeOriginIndex != nil
                && routeDestinationIndex != nil
                && !hasUnsafePlannedStop
                && allLegsPresent
            let usable = isRouteSafe
                ? max(0, rawGap - requiredTravel - requiredStop - arrivalBuffer)
                : nil

            return LifeRouteUsableGap(
                id: "\(previous.id)->\(next.id)",
                previousAppointmentNodeID: previous.id,
                nextAppointmentNodeID: next.id,
                rawCalendarGapSeconds: rawGap,
                requiredTravelSeconds: requiredTravel,
                requiredStopSeconds: requiredStop,
                bufferSeconds: arrivalBuffer,
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

    func startRouteDecision(
        selectedDay: Date,
        itineraryIsCurrent: Bool,
        now: Date,
        calendar: Calendar = .current
    ) -> LifeRouteDayNavigationDecision {
        guard calendar.isDate(self.selectedDay, inSameDayAs: selectedDay) else {
            return .wrongDay
        }
        guard itineraryIsCurrent else {
            return .stale
        }

        let nodeIndexByID = Dictionary(
            uniqueKeysWithValues: nodes.enumerated().map { ($0.element.id, $0.offset) }
        )
        let lastStartedAppointmentIndex: Int?
        if calendar.isDate(selectedDay, inSameDayAs: now) {
            lastStartedAppointmentIndex = nodes.indices.last { index in
                let node = nodes[index]
                return node.kind == .appointment
                    && !node.isAllDay
                    && node.start.map { $0 <= now } == true
            }
        } else {
            lastStartedAppointmentIndex = nil
        }
        let minimumDestinationIndex = lastStartedAppointmentIndex.map { $0 + 1 } ?? nodes.startIndex

        for leg in legs.sorted(by: { $0.sequence < $1.sequence }) {
            guard let sourceIndex = nodeIndexByID[leg.fromNodeID],
                  let destinationIndex = nodeIndexByID[leg.toNodeID],
                  destinationIndex >= minimumDestinationIndex else {
                continue
            }
            let source = nodes[sourceIndex]
            let destination = nodes[destinationIndex]
            guard destination.kind != .origin,
                  destination.isRoutable,
                  !destination.isAllDay else {
                continue
            }
            return .ready(
                LifeRouteItineraryNavigationLeg(
                    leg: leg,
                    source: source,
                    destination: destination
                )
            )
        }
        return .noPhysicalDestination
    }

    func departureGuidance(at now: Date) -> LifeRouteDepartureGuidance? {
        guard let targetIndex = nodes.indices.first(where: { index in
            let node = nodes[index]
            return node.kind == .appointment
                && !node.isAllDay
                && node.isRoutable
                && node.start.map { $0 >= now } == true
        }) else {
            return nil
        }

        let target = nodes[targetIndex]
        guard let appointmentStart = target.start else {
            return nil
        }

        let previousTimedAppointmentIndex = nodes.indices[..<targetIndex].last { index in
            let node = nodes[index]
            return node.kind == .appointment
                && !node.isAllDay
                && node.start != nil
                && node.end != nil
        }
        let routeSearchEnd = previousTimedAppointmentIndex ?? nodes.startIndex
        guard let routeOriginIndex = nodes.indices[...routeSearchEnd].last(where: { index in
            let node = nodes[index]
            return node.isRoutable && !node.isAllDay
        }), routeOriginIndex < targetIndex else {
            return nil
        }

        let routeRange = routeOriginIndex...targetIndex
        let routeNodes = nodes[routeRange].filter { $0.isRoutable && !$0.isAllDay }

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
        let blockingVirtualCommitment = nodes[routeOriginIndex..<targetIndex].contains { node in
            node.kind == .appointment
                && !node.isAllDay
                && !node.isRoutable
                && node.end.map { $0 > leaveBy && $0 > now } == true
        }
        guard !blockingVirtualCommitment else { return nil }
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

/// A clock projection of the plan, not evidence of physical arrival or departure.
/// Both presentation and ActivityKit use these half-open schedule boundaries.
struct LifeRouteLiveDayProjection: Codable, Hashable, Sendable {
    enum Phase: String, Codable, Hashable, Sendable {
        case upcoming, departure, travelling, stopActive, eventActive, gap, dayCompleted
    }

    let phase: Phase
    let currentNodeID: String?
    let currentLegID: String?
    let nextNodeID: String?
    let completedNodeIDs: [String]
    let nextTransition: Date?
    let departure: LifeRouteDepartureGuidance?
    let phaseLabel: String
    let primaryTitle: String
    let secondaryText: String?
    let countdownTarget: Date?
    let appointmentStart: Date?
    let appointmentEnd: Date?
    let routeSummary: String
    let plannedStopSummary: String?
    let returnHomePlanned: Bool

    private struct Window {
        let phase: Phase
        let node: LifeRouteItineraryNode
        let legID: String?
        let start: Date
        let end: Date
    }

    static func make(from itinerary: LifeRouteGeneratedItinerary, at now: Date) -> Self? {
        let nodes = itinerary.nodes
        let events = nodes.filter { $0.kind == .appointment && !$0.isAllDay && $0.start != nil }
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        var windows: [Window] = []
        var boundaries: [Date] = []
        // Keep raw route math and the once-per-appointment buffer authoritative.
        for event in events {
            let start = event.start!
            boundaries.append(start)
            if let end = event.end, end > start { boundaries.append(end) }
            guard let guidance = itinerary.departureGuidance(at: start),
                  guidance.appointmentNodeID == event.id,
                  let origin = nodes.firstIndex(where: { $0.id == guidance.routeOriginNodeID }),
                  let target = nodes.firstIndex(where: { $0.id == event.id }), origin < target else { continue }
            let route = nodes[origin...target].filter { $0.isRoutable && !$0.isAllDay }
            var cursor = guidance.leaveBy
            boundaries += [cursor.addingTimeInterval(-15 * 60), cursor]
            for (from, to) in zip(route, route.dropFirst()) {
                guard let leg = itinerary.legs.first(where: { $0.fromNodeID == from.id && $0.toNodeID == to.id }) else { break }
                let arrival = cursor.addingTimeInterval(leg.rawTravelSeconds)
                windows.append(Window(phase: .travelling, node: to, legID: leg.id, start: cursor, end: arrival))
                boundaries += [cursor, arrival]
                cursor = arrival
                if to.kind == .stop {
                    let end = cursor.addingTimeInterval(to.stopDurationSeconds)
                    windows.append(Window(phase: .stopActive, node: to, legID: nil, start: cursor, end: end))
                    boundaries.append(end)
                    cursor = end
                }
            }
        }
        // A virtual commitment supplies a deadline but no physical destination.
        // Anchor intervening errands to the previous event end when the whole
        // interval fits; never invent travel to a virtual meeting.
        for (eventIndex, event) in events.enumerated() where !event.isRoutable && eventIndex > 0 {
            let previous = events[eventIndex - 1]
            guard let previousEnd = previous.end,
                  let previousIndex = nodes.firstIndex(where: { $0.id == previous.id }),
                  let targetIndex = nodes.firstIndex(where: { $0.id == event.id }), previousIndex < targetIndex,
                  let origin = nodes[...previousIndex].last(where: { $0.isRoutable && !$0.isAllDay }),
                  origin.kind != .stop || windows.contains(where: { $0.node.id == origin.id && $0.phase == .stopActive }) else { continue }
            var source = origin
            var cursor = max(previous.start!, previousEnd)
            var proposed: [Window] = []
            var complete = true
            for stop in nodes[(previousIndex + 1)..<targetIndex] where stop.kind == .stop && stop.isRoutable {
                guard let leg = itinerary.legs.first(where: { $0.fromNodeID == source.id && $0.toNodeID == stop.id }) else { complete = false; break }
                let arrival = cursor.addingTimeInterval(leg.rawTravelSeconds)
                let end = arrival.addingTimeInterval(stop.stopDurationSeconds)
                proposed.append(Window(phase: .travelling, node: stop, legID: leg.id, start: cursor, end: arrival))
                proposed.append(Window(phase: .stopActive, node: stop, legID: nil, start: arrival, end: end))
                cursor = end
                source = stop
            }
            if complete && cursor <= event.start! {
                windows += proposed
                boundaries += proposed.flatMap { [$0.start, $0.end] }
            }
        }
        // Trailing errands/return-home are planned from the final commitment's end.
        // An untimed stop-only route has no clock anchor and remains upcoming.
        if let last = events.last, let end = last.end,
           let lastIndex = nodes.firstIndex(where: { $0.id == last.id }) {
            var cursor = max(last.start!, events.compactMap(\.end).max() ?? end)
            var source = nodes[...lastIndex].last { $0.isRoutable && !$0.isAllDay }
            for node in nodes.dropFirst(lastIndex + 1) where node.isRoutable && !node.isAllDay {
                guard let from = source,
                      from.kind != .stop || windows.contains(where: { $0.node.id == from.id && $0.phase == .stopActive }),
                      let leg = itinerary.legs.first(where: { $0.fromNodeID == from.id && $0.toNodeID == node.id }) else { break }
                let arrival = cursor.addingTimeInterval(leg.rawTravelSeconds)
                windows.append(Window(phase: .travelling, node: node, legID: leg.id, start: cursor, end: arrival))
                boundaries += [cursor, arrival]
                cursor = arrival
                if node.kind == .stop {
                    let end = cursor.addingTimeInterval(node.stopDurationSeconds)
                    windows.append(Window(phase: .stopActive, node: node, legID: nil, start: cursor, end: end))
                    boundaries.append(end)
                    cursor = end
                }
                source = node
            }
        }
        windows.sort { $0.start < $1.start }
        let completed = nodes.filter { node in
            if node.kind == .appointment, !node.isAllDay, let start = node.start {
                return max(start, node.end ?? start) <= now
            }
            return windows.contains { $0.node.id == node.id && $0.end <= now &&
                ($0.phase == .stopActive || node.kind == .home) }
        }.map(\.id)
        let active = events.first { node in
            node.start! <= now && now < (node.end ?? node.start!)
        }
        let nextEvent = events.first { $0.start! > now }
        let window = windows.first { $0.start <= now && now < $0.end &&
            !completed.contains($0.node.id) }
        let nextWindow = windows.first { $0.start > now && !completed.contains($0.node.id) }
        let guidance = itinerary.departureGuidance(at: now)
        let phase: Phase
        let node: LifeRouteItineraryNode?
        let target: Date?
        let label: String
        if let active {
            phase = .eventActive; node = active; target = active.end; label = "EVENT ACTIVE · ENDS AT"
        } else if let window {
            phase = window.phase; node = window.node; target = window.end
            label = phase == .travelling ? "PLANNED TRAVEL · UNTIL" : "PLANNED STOP · UNTIL"
        } else if let nextEvent {
            node = nextEvent
            if let guidance, guidance.appointmentNodeID == nextEvent.id, guidance.leaveBy > now {
                phase = completed.isEmpty ? (guidance.leaveBy.timeIntervalSince(now) <= 900 ? .departure : .upcoming) : .gap
                target = guidance.leaveBy; label = phase == .gap ? "GAP · LEAVE AT" : "LEAVE AT"
            } else {
                phase = completed.isEmpty ? .upcoming : .gap
                target = nextEvent.start; label = phase == .gap ? "GAP · NEXT AT" : "UPCOMING · STARTS AT"
            }
        } else if let nextWindow {
            phase = .gap; node = nextWindow.node; target = nextWindow.start; label = "GAP · NEXT AT"
        } else if let untimed = nodes.first(where: { candidate in candidate.kind != .origin && !candidate.isAllDay && !completed.contains(candidate.id) &&
            !windows.contains(where: { $0.node.id == candidate.id }) }) {
            phase = .upcoming; node = untimed; target = nil; label = "UPCOMING · TIME NOT SET"
        } else {
            guard !nodes.isEmpty else { return nil }
            phase = .dayCompleted; node = nil; target = nil; label = "DAY COMPLETE"
        }
        let futureCandidates: [(Date, String)] = [
            nextEvent.flatMap { event in event.start.map { ($0, event.id) } },
            nextWindow.map { ($0.start, $0.node.id) }
        ].compactMap { $0 }
        let nextNodeID = active == nil && window?.phase == .travelling
            ? window?.node.id
            : futureCandidates.min(by: { $0.0 < $1.0 })?.1 ?? (active == nil ? node?.id : nil)
        let displayGuidance = guidance?.appointmentNodeID == node?.id ? guidance : nil
        let routeSummary = displayGuidance.map {
            "\(roundedUpMinutes($0.rawTravelSeconds)) min drive · +\(roundedUpMinutes($0.bufferSeconds)) min buffer"
        } ?? (phase == .dayCompleted ? "Scheduled day finished" : "Following the generated schedule")
        let stopLabels = displayGuidance?.intermediateStopNodeIDs.compactMap { id -> String? in
            guard let stop = byID[id], !completed.contains(id) else { return nil }
            return "\(stop.title) · \(roundedUpMinutes(stop.stopDurationSeconds)) min"
        } ?? []
        return Self(
            phase: phase, currentNodeID: active?.id ?? window?.node.id,
            currentLegID: active == nil ? window?.legID : nil, nextNodeID: nextNodeID,
            completedNodeIDs: completed, nextTransition: boundaries.filter { $0 > now }.min(),
            departure: displayGuidance, phaseLabel: label, primaryTitle: node?.title ?? "All scheduled stops complete",
            secondaryText: node?.address.isEmpty == false ? node?.address : nil,
            countdownTarget: target, appointmentStart: node?.start, appointmentEnd: node?.end,
            routeSummary: routeSummary, plannedStopSummary: stopLabels.isEmpty ? nil : stopLabels.joined(separator: " · "),
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
