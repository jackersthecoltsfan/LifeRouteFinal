import Foundation
import Combine
import MapKit
import CoreLocation
import UIKit

struct LifeRouteDayRouteLeg: Identifiable, Hashable {
    let id: UUID
    let sequence: Int
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

enum DayRoutePlanningError: LocalizedError {
    case missingDestination
    case missingOrigin
    case locationNotFound(String)
    case routeUnavailable(String)
    case navigationUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingDestination:
            return "Add at least one calendar event with a location before building the route."
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
    @Published private(set) var isCalculating = false
    @Published private(set) var message: String?
    @Published private(set) var fullRoutePlan: LifeRouteFullRouteHandoffPlan?
    @Published private(set) var nextSequentialLegIndex: Int?
    @Published private(set) var hasStartedSequentialHandoff = false

    private var calculationTask: Task<Void, Never>?

    func calculate(
        appointments: [LifeRouteRouteAppointment],
        beforeStops: [LifeRouteDayStop],
        afterStops: [LifeRouteDayStop],
        returnHome: Bool,
        homeAddress: String,
        currentLocation: CLLocation?,
        mode: LifeRouteTransportMode
    ) {
        calculationTask?.cancel()
        legs = []
        fullRoutePlan = nil
        nextSequentialLegIndex = nil
        hasStartedSequentialHandoff = false
        isCalculating = true
        message = "Building day route…"

        calculationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let built = try await Self.buildLegs(
                    appointments: appointments,
                    beforeStops: beforeStops,
                    afterStops: afterStops,
                    returnHome: returnHome,
                    homeAddress: homeAddress,
                    currentLocation: currentLocation,
                    mode: mode
                )
                try Task.checkCancellation()
                self.legs = built
                self.fullRoutePlan = self.makeFullRoutePlan(mode: mode)
                self.message = built.isEmpty ? "No route legs were created." : "Day route ready."
            } catch is CancellationError {
                self.message = nil
            } catch {
                self.message = error.localizedDescription
            }
            self.isCalculating = false
            self.calculationTask = nil
        }
    }

    func cancel() {
        calculationTask?.cancel()
        calculationTask = nil
        isCalculating = false
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

    private static func buildLegs(
        appointments: [LifeRouteRouteAppointment],
        beforeStops: [LifeRouteDayStop],
        afterStops: [LifeRouteDayStop],
        returnHome: Bool,
        homeAddress: String,
        currentLocation: CLLocation?,
        mode: LifeRouteTransportMode
    ) async throws -> [LifeRouteDayRouteLeg] {
        let plannedWaypoints = LifeRouteDaySequenceBuilder.waypoints(
            appointments: appointments.filter { !$0.address.isEmpty },
            beforeStops: beforeStops,
            afterStops: afterStops
        )
        guard !plannedWaypoints.isEmpty else {
            throw DayRoutePlanningError.missingDestination
        }

        var waypoints: [(title: String, address: String, item: MKMapItem)] = []

        if let currentLocation {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: currentLocation.coordinate))
            item.name = "Current Location"
            waypoints.append(("Current Location", "Current Location", item))
        } else {
            let cleanHome = homeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanHome.isEmpty else { throw DayRoutePlanningError.missingOrigin }
            waypoints.append(("Home", cleanHome, try await mapItem(for: cleanHome, fallbackName: "Home")))
        }

        for waypoint in plannedWaypoints {
            waypoints.append(
                (
                    waypoint.title,
                    waypoint.address,
                    try await mapItem(for: waypoint.address, fallbackName: waypoint.title)
                )
            )
        }

        if returnHome {
            let cleanHome = homeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanHome.isEmpty else { throw DayRoutePlanningError.missingOrigin }
            waypoints.append(("Home", cleanHome, try await mapItem(for: cleanHome, fallbackName: "Home")))
        }

        guard waypoints.count >= 2 else { return [] }

        var result: [LifeRouteDayRouteLeg] = []
        for index in 0..<(waypoints.count - 1) {
            try Task.checkCancellation()
            let source = waypoints[index]
            let destination = waypoints[index + 1]
            let request = MKDirections.Request()
            request.source = source.item
            request.destination = destination.item
            request.transportType = mode.mapKitType
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else {
                throw DayRoutePlanningError.routeUnavailable(destination.title)
            }

            result.append(
                LifeRouteDayRouteLeg(
                    id: UUID(),
                    sequence: index + 1,
                    fromTitle: source.title,
                    fromAddress: source.address,
                    toTitle: destination.title,
                    toAddress: destination.address,
                    travelTimeSeconds: route.expectedTravelTime,
                    distanceMeters: route.distance
                )
            )
        }
        return result
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
