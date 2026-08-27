import Foundation
import Combine
import MapKit
import CoreLocation

struct LifeRouteDayStop: Identifiable, Hashable {
    enum Position: String, CaseIterable, Identifiable {
        case before = "Before appointment"
        case after = "After appointment"

        var id: String { rawValue }
    }

    let id: UUID
    var title: String
    var address: String
    var position: Position

    init(id: UUID = UUID(), title: String, address: String, position: Position) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        self.position = position
    }
}

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

    var errorDescription: String? {
        switch self {
        case .missingDestination:
            return "Choose a calendar event with a location before building the route."
        case .missingOrigin:
            return "Start live location or save a home address before building the route."
        case .locationNotFound(let value):
            return "LifeRoute could not find \(value)."
        case .routeUnavailable(let value):
            return "A route could not be calculated for \(value)."
        }
    }
}

@MainActor
final class DayRoutePlanningCore: ObservableObject {
    @Published private(set) var legs: [LifeRouteDayRouteLeg] = []
    @Published private(set) var isCalculating = false
    @Published private(set) var message: String?

    private var calculationTask: Task<Void, Never>?

    func calculate(
        eventTitle: String,
        eventAddress: String,
        beforeStops: [LifeRouteDayStop],
        afterStops: [LifeRouteDayStop],
        returnHome: Bool,
        homeAddress: String,
        currentLocation: CLLocation?,
        mode: LifeRouteTransportMode
    ) {
        calculationTask?.cancel()
        legs = []
        isCalculating = true
        message = "Building day route…"

        calculationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let built = try await Self.buildLegs(
                    eventTitle: eventTitle,
                    eventAddress: eventAddress,
                    beforeStops: beforeStops,
                    afterStops: afterStops,
                    returnHome: returnHome,
                    homeAddress: homeAddress,
                    currentLocation: currentLocation,
                    mode: mode
                )
                try Task.checkCancellation()
                self.legs = built
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

    func openLegInAppleMaps(_ leg: LifeRouteDayRouteLeg, mode: LifeRouteTransportMode) {
        Task {
            do {
                let source = try await Self.mapItem(for: leg.fromAddress, fallbackName: leg.fromTitle)
                let destination = try await Self.mapItem(for: leg.toAddress, fallbackName: leg.toTitle)
                source.name = leg.fromTitle
                destination.name = leg.toTitle
                MKMapItem.openMaps(
                    with: [source, destination],
                    launchOptions: [MKLaunchOptionsDirectionsModeKey: mode.mapsLaunchMode]
                )
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private static func buildLegs(
        eventTitle: String,
        eventAddress: String,
        beforeStops: [LifeRouteDayStop],
        afterStops: [LifeRouteDayStop],
        returnHome: Bool,
        homeAddress: String,
        currentLocation: CLLocation?,
        mode: LifeRouteTransportMode
    ) async throws -> [LifeRouteDayRouteLeg] {
        let cleanEventAddress = eventAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEventAddress.isEmpty else { throw DayRoutePlanningError.missingDestination }

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

        for stop in beforeStops {
            guard !stop.address.isEmpty else { continue }
            waypoints.append((stop.title.isEmpty ? "Stop" : stop.title, stop.address, try await mapItem(for: stop.address, fallbackName: stop.title)))
        }

        waypoints.append((eventTitle.isEmpty ? "Appointment" : eventTitle, cleanEventAddress, try await mapItem(for: cleanEventAddress, fallbackName: eventTitle)))

        for stop in afterStops {
            guard !stop.address.isEmpty else { continue }
            waypoints.append((stop.title.isEmpty ? "Stop" : stop.title, stop.address, try await mapItem(for: stop.address, fallbackName: stop.title)))
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
        if query == "Current Location" {
            throw DayRoutePlanningError.locationNotFound(query)
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else {
            throw DayRoutePlanningError.locationNotFound(query)
        }
        item.name = fallbackName.isEmpty ? query : fallbackName
        return item
    }
}
