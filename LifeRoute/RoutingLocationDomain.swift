import Foundation
import Combine
import CoreLocation
import MapKit

enum LifeRoutePlaceKind: String, CaseIterable, Codable, Identifiable {
    case gym = "Gym"
    case work = "Work"
    case coffee = "Coffee"
    case grocery = "Grocery"
    case park = "Park"
    case library = "Library"
    case errand = "Errand"
    case other = "Other"

    var id: Self { self }
}

enum LifeRouteTransportMode: String, CaseIterable, Identifiable, Codable {
    case driving = "Driving"
    case walking = "Walking"
    case transit = "Transit"

    var id: Self { self }

    var mapKitType: MKDirectionsTransportType {
        switch self {
        case .driving: return .automobile
        case .walking: return .walking
        case .transit: return .transit
        }
    }

    var mapsLaunchMode: String {
        switch self {
        case .driving: return MKLaunchOptionsDirectionsModeDriving
        case .walking: return MKLaunchOptionsDirectionsModeWalking
        case .transit: return MKLaunchOptionsDirectionsModeTransit
        }
    }
}

struct LifeRouteSavedPlace: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var address: String
    var kind: LifeRoutePlaceKind
    var minimumVisitMinutes: Int
    var useInGapSuggestions: Bool

    init(
        id: UUID = UUID(),
        name: String,
        address: String,
        kind: LifeRoutePlaceKind,
        minimumVisitMinutes: Int,
        useInGapSuggestions: Bool
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        self.kind = kind
        self.minimumVisitMinutes = max(5, minimumVisitMinutes)
        self.useInGapSuggestions = useInGapSuggestions
    }
}

struct LifeRouteRouteEstimate: Hashable {
    let placeID: UUID
    let mode: LifeRouteTransportMode
    let distanceMeters: CLLocationDistance
    let travelTimeSeconds: TimeInterval

    var distanceLabel: String {
        let miles = distanceMeters / 1609.344
        if miles < 0.1 { return "<0.1 mi" }
        return String(format: "%.1f mi", miles)
    }

    var durationLabel: String {
        let totalMinutes = max(1, Int((travelTimeSeconds / 60).rounded()))
        if totalMinutes < 60 { return "\(totalMinutes) min" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return minutes == 0 ? "\(hours) hr" : "\(hours) hr \(minutes) min"
    }
}

enum RoutingLocationCoreError: LocalizedError {
    case missingName
    case missingAddress
    case originUnavailable
    case destinationNotFound
    case routeUnavailable

    var errorDescription: String? {
        switch self {
        case .missingName: return "Enter a place name."
        case .missingAddress: return "Enter an address or searchable place."
        case .originUnavailable: return "Current location is not ready. Allow location access or add a home address as a fallback."
        case .destinationNotFound: return "LifeRoute could not find that destination."
        case .routeUnavailable: return "A route could not be calculated for that destination."
        }
    }
}

@MainActor
final class RoutingLocationCore: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var locationMessage = "Location not requested"
    @Published private(set) var savedPlaces: [LifeRouteSavedPlace] = []
    @Published private(set) var routeEstimates: [UUID: LifeRouteRouteEstimate] = [:]
    @Published private(set) var routeMessage: String?
    @Published private(set) var homeAddress = ""

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
        updateLocationMessage(for: authorizationStatus)
    }

    func requestCurrentLocation() {
        authorizationStatus = locationManager.authorizationStatus
        switch authorizationStatus {
        case .notDetermined:
            locationMessage = "Requesting location permission…"
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationMessage = "Updating current location…"
            locationManager.requestLocation()
        case .denied:
            locationMessage = "Location access is denied. You can enable it in iPhone Settings."
        case .restricted:
            locationMessage = "Location access is restricted on this iPhone."
        @unknown default:
            locationMessage = "Location status is unavailable."
        }
    }

    func setHomeAddress(_ address: String) throws {
        let cleaned = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw RoutingLocationCoreError.missingAddress }
        homeAddress = cleaned
        routeMessage = "Home address saved for this app session."
    }

    func addSavedPlace(
        name: String,
        address: String,
        kind: LifeRoutePlaceKind,
        minimumVisitMinutes: Int,
        useInGapSuggestions: Bool
    ) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw RoutingLocationCoreError.missingName }
        guard !cleanAddress.isEmpty else { throw RoutingLocationCoreError.missingAddress }

        savedPlaces.append(
            LifeRouteSavedPlace(
                name: cleanName,
                address: cleanAddress,
                kind: kind,
                minimumVisitMinutes: minimumVisitMinutes,
                useInGapSuggestions: useInGapSuggestions
            )
        )
        savedPlaces.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        routeMessage = "Saved place added for this app session."
    }

    func removeSavedPlace(id: UUID) {
        savedPlaces.removeAll { $0.id == id }
        routeEstimates[id] = nil
    }

    func calculateRoute(to place: LifeRouteSavedPlace, mode: LifeRouteTransportMode) async {
        routeMessage = "Calculating route…"
        do {
            let source = try await originMapItem()
            let destination = try await mapItem(for: place.address)
            let request = MKDirections.Request()
            request.source = source
            request.destination = destination
            request.transportType = mode.mapKitType

            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else { throw RoutingLocationCoreError.routeUnavailable }
            routeEstimates[place.id] = LifeRouteRouteEstimate(
                placeID: place.id,
                mode: mode,
                distanceMeters: route.distance,
                travelTimeSeconds: route.expectedTravelTime
            )
            routeMessage = "Route estimate updated."
        } catch {
            routeMessage = error.localizedDescription
        }
    }

    func openInAppleMaps(_ place: LifeRouteSavedPlace, mode: LifeRouteTransportMode) async {
        routeMessage = "Opening Apple Maps…"
        do {
            let destination = try await mapItem(for: place.address)
            destination.name = place.name
            destination.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: mode.mapsLaunchMode
            ])
            routeMessage = nil
        } catch {
            routeMessage = error.localizedDescription
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        updateLocationMessage(for: authorizationStatus)
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        locationMessage = "Current location ready"
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationMessage = "Location unavailable: \(error.localizedDescription)"
    }

    private func updateLocationMessage(for status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationMessage = "Location not requested"
        case .authorizedAlways, .authorizedWhenInUse:
            locationMessage = currentLocation == nil ? "Location allowed; waiting for a position" : "Current location ready"
        case .denied:
            locationMessage = "Location access is denied"
        case .restricted:
            locationMessage = "Location access is restricted"
        @unknown default:
            locationMessage = "Location status is unavailable"
        }
    }

    private func originMapItem() async throws -> MKMapItem {
        if let currentLocation {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: currentLocation.coordinate))
            item.name = "Current Location"
            return item
        }
        if !homeAddress.isEmpty {
            return try await mapItem(for: homeAddress)
        }
        throw RoutingLocationCoreError.originUnavailable
    }

    private func mapItem(for query: String) async throws -> MKMapItem {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw RoutingLocationCoreError.missingAddress }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = cleaned
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else { throw RoutingLocationCoreError.destinationNotFound }
        return item
    }
}
