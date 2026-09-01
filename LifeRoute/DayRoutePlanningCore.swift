import Foundation
import Combine
import MapKit
import CoreLocation
import UIKit

struct LifeRouteDayRouteLeg: Identifiable, Hashable {
    let id: String
    let sequence: Int
    let fromNodeID: String
    let toNodeID: String
    let fromTitle: String
    let fromAddress: String
    let toTitle: String
    let toAddress: String
    let travelTimeSeconds: TimeInterval
    let distanceMeters: CLLocationDistance

    var durationLabel: String {
        let minutes = max(1, Int((travelTimeSeconds / 60).rounded()))
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) hr" : "\(hours) hr \(remainder) min"
    }

    var distanceLabel: String {
        let miles = distanceMeters / 1609.344
        return miles < 0.1 ? "<0.1 mi" : String(format: "%.1f mi", miles)
    }
}

struct LifeRouteGapFillerRecommendation: Identifiable, Hashable {
    enum Source: Hashable {
        case savedPlace(UUID)
        case todo(UUID)
    }

    let id: String
    let source: Source
    let title: String
    let address: String
    let durationMinutes: Int
    let fit: LifeRouteGapFitResult
}

enum DayRoutePlanningError: LocalizedError {
    case missingDestination
    case missingOrigin
    case locationNotFound(String)
    case routeUnavailable(String)
    case navigationUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingDestination:
            return "Add at least one routed appointment or saved stop before building the route."
        case .missingOrigin:
            return "Start live location or save a home address before building the route."
        case .locationNotFound(let value):
            return "LifeRoute could not find \(value)."
        case .routeUnavailable(let value):
            return "A route could not be calculated for \(value)."
        case .navigationUnavailable(let app):
            return "LifeRoute could not open \(app)."
        }
    }
}

@MainActor
final class DayRoutePlanningCore: ObservableObject {
    @Published private(set) var legs: [LifeRouteDayRouteLeg] = []
    @Published private(set) var generatedItinerary: LifeRouteGeneratedItinerary?
    @Published private(set) var isCalculating = false
    @Published private(set) var message: String?
    @Published private(set) var fullRoutePlan: LifeRouteFullRouteHandoffPlan?
    @Published private(set) var nextSequentialLegIndex: Int?
    @Published private(set) var hasStartedSequentialHandoff = false
    @Published private(set) var gapRecommendationsByGapID: [String: [LifeRouteGapFillerRecommendation]] = [:]
    @Published private(set) var gapEvaluationInFlight: Set<String> = []
    @Published var routeMode: LifeRouteTransportMode = .driving
    @Published var returnHome = true

    private var calculationTask: Task<Void, Never>?
    private var calculationToken: LifeRouteRouteGenerationToken?
    private var gapEvaluationTasks: [String: Task<Void, Never>] = [:]
    private var gapEvaluationIDs: [String: UUID] = [:]

    func calculate(
        selectedDay: Date,
        appointments: [LifeRouteRouteAppointment],
        beforeStops: [LifeRouteDayStop],
        afterStops: [LifeRouteDayStop],
        routeBufferMinutes: Int,
        homeAddress: String,
        currentLocation: CLLocation?
    ) {
        calculationTask?.cancel()
        gapEvaluationTasks.values.forEach { $0.cancel() }
        gapEvaluationTasks = [:]
        gapEvaluationIDs = [:]
        gapEvaluationInFlight = []
        gapRecommendationsByGapID = [:]
        let token = LifeRouteRouteGenerationToken(selectedDay: selectedDay)
        calculationToken = token
        legs = []
        generatedItinerary = nil
        fullRoutePlan = nil
        nextSequentialLegIndex = nil
        hasStartedSequentialHandoff = false
        isCalculating = true
        message = "Building day route…"

        let mode = self.routeMode
        let returnHome = self.returnHome
        let routeBuffer = LifeRouteRouteBuffer(minutes: routeBufferMinutes)
        let fingerprint = Self.inputFingerprint(
            selectedDay: selectedDay,
            appointments: appointments,
            beforeStops: beforeStops,
            afterStops: afterStops,
            returnHome: returnHome,
            routeBuffer: routeBuffer,
            homeAddress: homeAddress,
            currentLocation: currentLocation,
            mode: mode
        )

        calculationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let built = try await Self.buildRoute(
                    appointments: appointments,
                    beforeStops: beforeStops,
                    afterStops: afterStops,
                    returnHome: returnHome,
                    homeAddress: homeAddress,
                    currentLocation: currentLocation,
                    mode: mode
                )
                try Task.checkCancellation()
                guard token.accepts(activeToken: self.calculationToken) else { return }
                self.legs = built.legs
                self.generatedItinerary = LifeRouteGeneratedItinerary(
                    id: UUID().uuidString,
                    selectedDay: Calendar.current.startOfDay(for: selectedDay),
                    generatedAt: Date(),
                    returnHome: returnHome,
                    routeBuffer: routeBuffer,
                    inputFingerprint: fingerprint,
                    nodes: built.nodes,
                    legs: built.legs.map {
                        LifeRouteItineraryLeg(
                            id: $0.id,
                            sequence: $0.sequence,
                            fromNodeID: $0.fromNodeID,
                            toNodeID: $0.toNodeID,
                            rawTravelSeconds: $0.travelTimeSeconds,
                            rawDistanceMeters: $0.distanceMeters
                        )
                    }
                )
                self.fullRoutePlan = self.makeFullRoutePlan(mode: mode)
                self.message = built.legs.isEmpty ? "No route legs were created." : "Day route ready."
            } catch is CancellationError {
                guard token.accepts(activeToken: self.calculationToken) else { return }
                self.message = nil
            } catch {
                guard token.accepts(activeToken: self.calculationToken) else { return }
                self.message = error.localizedDescription
            }
            guard token.accepts(activeToken: self.calculationToken) else { return }
            self.isCalculating = false
            self.calculationTask = nil
            self.calculationToken = nil
        }
    }

    func cancel() {
        let wasCalculating = isCalculating
        calculationTask?.cancel()
        calculationTask = nil
        calculationToken = nil
        gapEvaluationTasks.values.forEach { $0.cancel() }
        gapEvaluationTasks = [:]
        gapEvaluationIDs = [:]
        gapEvaluationInFlight = []
        isCalculating = false
        if wasCalculating {
            message = nil
        }
    }

    func matchesGeneratedItinerary(
        selectedDay: Date,
        appointments: [LifeRouteRouteAppointment],
        beforeStops: [LifeRouteDayStop],
        afterStops: [LifeRouteDayStop],
        routeBufferMinutes: Int,
        homeAddress: String,
        currentLocation: CLLocation?
    ) -> Bool {
        guard let generatedItinerary else { return false }
        let fingerprint = Self.inputFingerprint(
            selectedDay: selectedDay,
            appointments: appointments,
            beforeStops: beforeStops,
            afterStops: afterStops,
            returnHome: returnHome,
            routeBuffer: LifeRouteRouteBuffer(minutes: routeBufferMinutes),
            homeAddress: homeAddress,
            currentLocation: currentLocation,
            mode: routeMode
        )
        return generatedItinerary.inputFingerprint == fingerprint
    }

    func evaluateGapFillers(
        for gap: LifeRouteUsableGap,
        itinerary: LifeRouteGeneratedItinerary,
        savedPlaces: [LifeRouteSavedPlace],
        todos: [LifeRouteTodo]
    ) {
        guard generatedItinerary?.id == itinerary.id,
              generatedItinerary?.inputFingerprint == itinerary.inputFingerprint else {
            return
        }
        gapEvaluationTasks[gap.id]?.cancel()

        let calendar = Calendar.current
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: itinerary.selectedDay)
            ?? itinerary.selectedDay.addingTimeInterval(86_400)
        let eligibleTodos = todos.filter {
            !$0.completed && $0.dueDate < dayEnd
        }
        let locationlessRecommendations = eligibleTodos.compactMap { todo -> LifeRouteGapFillerRecommendation? in
            let address = Self.resolvedAddress(for: todo, savedPlaces: savedPlaces)
            guard address.isEmpty else { return nil }
            let fit = gap.fit(
                .locationlessTodo(
                    id: "todo:\(todo.id.uuidString)",
                    title: todo.title,
                    durationSeconds: TimeInterval(todo.durationMinutes * 60)
                )
            )
            guard fit.state == .fits else { return nil }
            return LifeRouteGapFillerRecommendation(
                id: "todo:\(todo.id.uuidString)",
                source: .todo(todo.id),
                title: todo.title,
                address: "",
                durationMinutes: todo.durationMinutes,
                fit: fit
            )
        }
        gapRecommendationsByGapID[gap.id] = locationlessRecommendations

        guard gap.isRouteSafe,
              gap.requiredStopSeconds == 0,
              let previous = itinerary.nodes.first(where: { $0.id == gap.previousAppointmentNodeID }),
              let next = itinerary.nodes.first(where: { $0.id == gap.nextAppointmentNodeID }),
              previous.isRoutable,
              next.isRoutable else {
            gapEvaluationInFlight.remove(gap.id)
            return
        }

        let existingAddresses = Set(
            itinerary.nodes
                .filter { $0.kind == .stop }
                .map { Self.normalizedAddress($0.address) }
        )
        var locatedCandidates: [GapLocationCandidate] = savedPlaces
            .filter {
                $0.useInGapSuggestions
                    && !existingAddresses.contains(Self.normalizedAddress($0.address))
            }
            .map {
                GapLocationCandidate(
                    id: "place:\($0.id.uuidString)",
                    source: .savedPlace($0.id),
                    title: $0.name,
                    address: $0.address,
                    durationMinutes: $0.minimumVisitMinutes
                )
            }
        locatedCandidates += eligibleTodos.compactMap { todo in
            let address = Self.resolvedAddress(for: todo, savedPlaces: savedPlaces)
            guard !address.isEmpty,
                  !existingAddresses.contains(Self.normalizedAddress(address)) else { return nil }
            return GapLocationCandidate(
                id: "todo:\(todo.id.uuidString)",
                source: .todo(todo.id),
                title: todo.title,
                address: address,
                durationMinutes: todo.durationMinutes
            )
        }
        locatedCandidates = Array(locatedCandidates.prefix(8))
        guard !locatedCandidates.isEmpty else {
            gapEvaluationInFlight.remove(gap.id)
            return
        }

        let token = UUID()
        gapEvaluationIDs[gap.id] = token
        gapEvaluationInFlight.insert(gap.id)
        let mode = routeMode
        gapEvaluationTasks[gap.id] = Task { [weak self] in
            guard let self else { return }
            var recommendations = locationlessRecommendations
            do {
                let sourceItem = try await Self.mapItem(for: previous.address, fallbackName: previous.title)
                let destinationItem = try await Self.mapItem(for: next.address, fallbackName: next.title)
                for candidate in locatedCandidates {
                    try Task.checkCancellation()
                    let candidateItem = try await Self.mapItem(
                        for: candidate.address,
                        fallbackName: candidate.title
                    )
                    let inbound = try await Self.routeDuration(
                        from: sourceItem,
                        to: candidateItem,
                        mode: mode
                    )
                    let outbound = try await Self.routeDuration(
                        from: candidateItem,
                        to: destinationItem,
                        mode: mode
                    )
                    let fit = gap.fit(
                        .located(
                            id: candidate.id,
                            title: candidate.title,
                            durationSeconds: TimeInterval(candidate.durationMinutes * 60),
                            inboundTravelSeconds: inbound,
                            outboundTravelSeconds: outbound
                        )
                    )
                    guard fit.state == .fits else { continue }
                    recommendations.append(
                        LifeRouteGapFillerRecommendation(
                            id: candidate.id,
                            source: candidate.source,
                            title: candidate.title,
                            address: candidate.address,
                            durationMinutes: candidate.durationMinutes,
                            fit: fit
                        )
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                // Keep already-proven locationless suggestions. A failed MapKit
                // candidate is never presented as fitting.
            }
            guard self.gapEvaluationIDs[gap.id] == token,
                  self.generatedItinerary?.id == itinerary.id,
                  self.generatedItinerary?.inputFingerprint == itinerary.inputFingerprint else { return }
            self.gapRecommendationsByGapID[gap.id] = recommendations
            self.gapEvaluationInFlight.remove(gap.id)
            self.gapEvaluationTasks[gap.id] = nil
            self.gapEvaluationIDs[gap.id] = nil
        }
    }

    func startFullRoute(mode: LifeRouteTransportMode) {
        guard let plan = makeFullRoutePlan(mode: mode) else { return }
        fullRoutePlan = plan
        nextSequentialLegIndex = nil
        hasStartedSequentialHandoff = false

        switch plan.strategy {
        case .completeGoogleMaps(let url):
            openURL(url, app: plan.provider) { [weak self] opened in
                if opened { self?.message = "Complete route sent to Google Maps." }
            }
        case .completeAppleMaps:
            guard let leg = plan.orderedLegs.first else { return }
            openAppleMaps(leg, mode: mode) { [weak self] opened in
                if opened { self?.message = "Route sent to Apple Maps." }
            }
        case .sequential:
            launchSequentialLeg(at: 0, plan: plan, mode: mode)
        }
    }

    func continueFullRoute(mode: LifeRouteTransportMode) {
        guard let plan = fullRoutePlan,
              plan.requiresSequentialContinuation,
              let nextSequentialLegIndex else { return }
        launchSequentialLeg(at: nextSequentialLegIndex, plan: plan, mode: mode)
    }

    private func launchSequentialLeg(
        at index: Int,
        plan: LifeRouteFullRouteHandoffPlan,
        mode: LifeRouteTransportMode
    ) {
        guard plan.orderedLegs.indices.contains(index) else { return }
        let leg = plan.orderedLegs[index]
        let completion: (Bool) -> Void = { [weak self] opened in
            guard opened, let self else { return }
            self.hasStartedSequentialHandoff = true
            let next = index + 1
            self.nextSequentialLegIndex = plan.orderedLegs.indices.contains(next) ? next : nil
            self.message = next < plan.orderedLegs.count
                ? "Leg \(index + 1) sent. Return to LifeRoute to continue the full route."
                : "Final route leg sent to \(plan.provider.title)."
        }

        switch plan.provider {
        case .appleMaps:
            openAppleMaps(leg, mode: mode, completion: completion)
        case .googleMaps:
            openURL(googleMapsURL(for: leg, mode: mode), app: plan.provider, completion: completion)
        case .waze:
            openURL(wazeURL(for: leg), app: plan.provider, completion: completion)
        }
    }

    private func openAppleMaps(
        _ leg: LifeRouteFullRouteLegDescriptor,
        mode: LifeRouteTransportMode,
        completion: @escaping (Bool) -> Void
    ) {
        Task {
            do {
                let source: MKMapItem
                if leg.fromAddress == "Current Location" {
                    source = MKMapItem.forCurrentLocation()
                } else {
                    source = try await Self.mapItem(for: leg.fromAddress, fallbackName: leg.fromTitle)
                }
                let destination = try await Self.mapItem(for: leg.toAddress, fallbackName: leg.toTitle)
                source.name = leg.fromTitle
                destination.name = leg.toTitle
                MKMapItem.openMaps(
                    with: [source, destination],
                    launchOptions: [MKLaunchOptionsDirectionsModeKey: mode.mapsLaunchMode]
                )
                completion(true)
            } catch {
                message = error.localizedDescription
                completion(false)
            }
        }
    }

    private func openURL(
        _ url: URL?,
        app: LifeRouteNavigationApp,
        completion: @escaping (Bool) -> Void
    ) {
        guard let url else {
            message = DayRoutePlanningError.navigationUnavailable(app.title).localizedDescription
            completion(false)
            return
        }
        UIApplication.shared.open(url, options: [:]) { [weak self] opened in
            Task { @MainActor in
                if !opened {
                    self?.message = DayRoutePlanningError.navigationUnavailable(app.title).localizedDescription
                }
                completion(opened)
            }
        }
    }

    private func googleMapsURL(
        for leg: LifeRouteFullRouteLegDescriptor,
        mode: LifeRouteTransportMode
    ) -> URL? {
        var components = URLComponents(string: "https://www.google.com/maps/dir/")
        var items = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "destination", value: LifeRouteDestinationIntent.naturalLanguageQuery(forStoredValue: leg.toAddress)),
            URLQueryItem(name: "travelmode", value: googleTravelMode(mode))
        ]
        if leg.fromAddress != "Current Location" {
            items.append(URLQueryItem(name: "origin", value: LifeRouteDestinationIntent.naturalLanguageQuery(forStoredValue: leg.fromAddress)))
        }
        components?.queryItems = items
        return components?.url
    }

    private func wazeURL(for leg: LifeRouteFullRouteLegDescriptor) -> URL? {
        var components = URLComponents(string: "https://www.waze.com/ul")
        components?.queryItems = [
            URLQueryItem(name: "q", value: LifeRouteDestinationIntent.naturalLanguageQuery(forStoredValue: leg.toAddress)),
            URLQueryItem(name: "navigate", value: "yes")
        ]
        return components?.url
    }

    private func googleTravelMode(_ mode: LifeRouteTransportMode) -> String {
        switch mode {
        case .driving: return "driving"
        case .walking: return "walking"
        case .transit: return "transit"
        }
    }

    private func makeFullRoutePlan(mode: LifeRouteTransportMode) -> LifeRouteFullRouteHandoffPlan? {
        let descriptors = legs.map {
            LifeRouteFullRouteLegDescriptor(
                sequence: $0.sequence,
                fromTitle: $0.fromTitle,
                fromAddress: providerAddress($0.fromAddress),
                toTitle: $0.toTitle,
                toAddress: providerAddress($0.toAddress)
            )
        }
        return LifeRouteFullRouteHandoffPlanner.plan(
            provider: LifeRouteNavigationApp.preferred,
            legs: descriptors,
            travelMode: googleTravelMode(mode)
        )
    }

    private func providerAddress(_ address: String) -> String {
        address == "Current Location"
            ? address
            : LifeRouteDestinationIntent.naturalLanguageQuery(forStoredValue: address)
    }

    private struct BuiltRoute {
        let nodes: [LifeRouteItineraryNode]
        let legs: [LifeRouteDayRouteLeg]
    }

    private struct ResolvedWaypoint {
        let node: LifeRouteItineraryNode
        let item: MKMapItem
    }

    private struct GapLocationCandidate {
        let id: String
        let source: LifeRouteGapFillerRecommendation.Source
        let title: String
        let address: String
        let durationMinutes: Int
    }

    private static func buildRoute(
        appointments: [LifeRouteRouteAppointment],
        beforeStops: [LifeRouteDayStop],
        afterStops: [LifeRouteDayStop],
        returnHome: Bool,
        homeAddress: String,
        currentLocation: CLLocation?,
        mode: LifeRouteTransportMode
    ) async throws -> BuiltRoute {
        let orderedAppointments = appointments.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.id < $1.id
        }
        let beforeNodes = LifeRouteDayStopCollection.sanitized(beforeStops)
            .filter { $0.position == .before }
            .map(Self.stopNode)
        let cleanAfterStops = LifeRouteDayStopCollection.sanitized(afterStops)
            .filter { $0.position == .after }
        let appointmentIDs = Set(orderedAppointments.map(\.id))
        let appointmentsAndAnchoredStops = orderedAppointments.flatMap { appointment -> [LifeRouteItineraryNode] in
            let appointmentNode = LifeRouteItineraryNode(
                id: "event:\(appointment.id)",
                kind: .appointment,
                title: appointment.title.isEmpty ? "Appointment" : appointment.title,
                address: appointment.address,
                start: appointment.start,
                end: appointment.end,
                isAllDay: appointment.isAllDay,
                isRoutable: appointment.isRoutable
            )
            let anchoredStops = cleanAfterStops
                .filter { $0.afterAppointmentID == appointment.id }
                .map(Self.stopNode)
            return [appointmentNode] + anchoredStops
        }
        let trailingNodes = cleanAfterStops.filter {
            guard let anchor = $0.afterAppointmentID else { return true }
            return !appointmentIDs.contains(anchor)
        }.map(Self.stopNode)
        let plannedNodes = beforeNodes + appointmentsAndAnchoredStops + trailingNodes
        guard plannedNodes.contains(where: \.isRoutable) else {
            throw DayRoutePlanningError.missingDestination
        }

        let originNode: LifeRouteItineraryNode
        let originItem: MKMapItem

        if let currentLocation {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: currentLocation.coordinate))
            item.name = "Current Location"
            originNode = LifeRouteItineraryNode(
                id: "origin:current",
                kind: .origin,
                title: "Current Location",
                address: "Current Location",
                isRoutable: true
            )
            originItem = item
        } else {
            let cleanHome = homeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanHome.isEmpty else { throw DayRoutePlanningError.missingOrigin }
            originNode = LifeRouteItineraryNode(
                id: "origin:home",
                kind: .origin,
                title: "Home",
                address: cleanHome,
                isRoutable: true
            )
            originItem = try await mapItem(for: cleanHome, fallbackName: "Home")
        }

        var routeWaypoints = [ResolvedWaypoint(node: originNode, item: originItem)]
        for node in plannedNodes where node.isRoutable {
            routeWaypoints.append(
                ResolvedWaypoint(
                    node: node,
                    item: try await mapItem(for: node.address, fallbackName: node.title)
                )
            )
        }

        var returnHomeNode: LifeRouteItineraryNode?
        if returnHome {
            let cleanHome = homeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanHome.isEmpty else { throw DayRoutePlanningError.missingOrigin }
            let node = LifeRouteItineraryNode(
                id: "home:return",
                kind: .home,
                title: "Home",
                address: cleanHome,
                isRoutable: true
            )
            returnHomeNode = node
            routeWaypoints.append(
                ResolvedWaypoint(
                    node: node,
                    item: try await mapItem(for: cleanHome, fallbackName: "Home")
                )
            )
        }

        guard routeWaypoints.count >= 2 else {
            return BuiltRoute(nodes: [originNode] + plannedNodes + [returnHomeNode].compactMap { $0 }, legs: [])
        }

        var result: [LifeRouteDayRouteLeg] = []
        for index in 0..<(routeWaypoints.count - 1) {
            try Task.checkCancellation()
            let source = routeWaypoints[index]
            let destination = routeWaypoints[index + 1]
            let request = MKDirections.Request()
            request.source = source.item
            request.destination = destination.item
            request.transportType = mode.mapKitType
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else {
                throw DayRoutePlanningError.routeUnavailable(destination.node.title)
            }

            result.append(
                LifeRouteDayRouteLeg(
                    id: "leg:\(source.node.id)->\(destination.node.id)",
                    sequence: index + 1,
                    fromNodeID: source.node.id,
                    toNodeID: destination.node.id,
                    fromTitle: source.node.title,
                    fromAddress: source.node.address,
                    toTitle: destination.node.title,
                    toAddress: destination.node.address,
                    travelTimeSeconds: route.expectedTravelTime,
                    distanceMeters: route.distance
                )
            )
        }
        return BuiltRoute(
            nodes: [originNode] + plannedNodes + [returnHomeNode].compactMap { $0 },
            legs: result
        )
    }

    private static func stopNode(_ stop: LifeRouteDayStop) -> LifeRouteItineraryNode {
        LifeRouteItineraryNode(
            id: "stop:\(stop.id.uuidString)",
            kind: .stop,
            title: stop.title,
            address: stop.address,
            isRoutable: !stop.address.isEmpty,
            stopDurationSeconds: TimeInterval(stop.durationMinutes * 60)
        )
    }

    private static func inputFingerprint(
        selectedDay: Date,
        appointments: [LifeRouteRouteAppointment],
        beforeStops: [LifeRouteDayStop],
        afterStops: [LifeRouteDayStop],
        returnHome: Bool,
        routeBuffer: LifeRouteRouteBuffer,
        homeAddress: String,
        currentLocation: CLLocation?,
        mode: LifeRouteTransportMode
    ) -> String {
        let appointmentParts = appointments.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.id < $1.id
        }.map {
            [
                $0.id,
                $0.title,
                $0.address,
                String($0.start.timeIntervalSinceReferenceDate),
                String($0.end.timeIntervalSinceReferenceDate),
                String($0.isAllDay),
            ].joined(separator: "~")
        }
        let stopParts = (beforeStops + afterStops).map {
            [
                $0.id.uuidString,
                $0.title,
                $0.address,
                $0.position.rawValue,
                String($0.durationMinutes),
                $0.afterAppointmentID ?? "",
            ].joined(separator: "~")
        }
        let cleanHome = homeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        // A generated itinerary is an immutable route snapshot. Live GPS drift
        // must not invalidate it while the user is actively traveling; only a
        // change between live-location and Home origin changes this input.
        let origin = currentLocation == nil ? "home:\(cleanHome)" : "current-location"
        let returnDestination = returnHome ? "return:\(cleanHome)" : "no-return"
        return ([
            String(Calendar.current.startOfDay(for: selectedDay).timeIntervalSinceReferenceDate),
            mode.rawValue,
            String(returnHome),
            String(routeBuffer.minutes),
            origin,
            returnDestination,
        ] + appointmentParts + stopParts).joined(separator: "|")
    }

    private static func resolvedAddress(
        for todo: LifeRouteTodo,
        savedPlaces: [LifeRouteSavedPlace]
    ) -> String {
        let direct = todo.address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !direct.isEmpty { return direct }
        guard let savedPlaceID = todo.savedPlaceID else { return "" }
        return savedPlaces.first(where: { $0.id == savedPlaceID })?.address ?? ""
    }

    private static func normalizedAddress(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func routeDuration(
        from source: MKMapItem,
        to destination: MKMapItem,
        mode: LifeRouteTransportMode
    ) async throws -> TimeInterval {
        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = mode.mapKitType
        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.first else {
            throw DayRoutePlanningError.routeUnavailable(destination.name ?? "destination")
        }
        return route.expectedTravelTime
    }

    private static func mapItem(for query: String, fallbackName: String) async throws -> MKMapItem {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = LifeRouteDestinationIntent.naturalLanguageQuery(forStoredValue: query)
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else {
            throw DayRoutePlanningError.locationNotFound(query)
        }
        item.name = fallbackName.isEmpty ? query : fallbackName
        return item
    }
}
