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
    @Published private(set) var locationRequestInFlight = false
    @Published private(set) var routeRequestsInFlight: Set<UUID> = []
    @Published private(set) var mapsOpenInFlight = false

    private let locationManager = CLLocationManager()
    private var locationRequestPendingAuthorization = false
    private var routeTasks: [UUID: Task<Void, Never>] = [:]
    private var routeGenerationByPlace: [UUID: UInt64] = [:]
    private var routeMessageTokenByPlace: [UUID: UInt64] = [:]
    private var mapsOpenTask: Task<Void, Never>?
    private var mapsOpenGeneration: UInt64 = 0
    private var routeMessageGeneration: UInt64 = 0

    override init() {
        let restored = LifeRoutePersistenceStore.shared.loadRoutingState()
        self.savedPlaces = restored.savedPlaces
        self.homeAddress = restored.homeAddress
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
        updateLocationMessage(for: authorizationStatus)
    }

    func requestCurrentLocation() {
        guard !locationRequestInFlight else { return }
        authorizationStatus = locationManager.authorizationStatus
        switch authorizationStatus {
        case .notDetermined:
            locationRequestInFlight = true
            locationRequestPendingAuthorization = true
            locationMessage = "Requesting location permission…"
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationRequestInFlight = true
            locationMessage = "Updating current location…"
            locationManager.requestLocation()
        case .denied:
            locationRequestPendingAuthorization = false
            locationMessage = "Location access is denied. You can enable it in iPhone Settings."
        case .restricted:
            locationRequestPendingAuthorization = false
            locationMessage = "Location access is restricted on this iPhone."
        @unknown default:
            locationRequestPendingAuthorization = false
            locationMessage = "Location status is unavailable."
        }
    }

    func setHomeAddress(_ address: String) throws {
        let cleaned = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw RoutingLocationCoreError.missingAddress }
        homeAddress = cleaned
        persistRoutingInputs()
        publishRouteMessage("Home address saved locally.")
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
        persistRoutingInputs()
        publishRouteMessage("Saved place stored locally.")
    }

    func removeSavedPlace(id: UUID) {
        cancelRouteOperation(for: id)
        savedPlaces.removeAll { $0.id == id }
        routeEstimates[id] = nil
        persistRoutingInputs()
    }

    func calculateRoute(to place: LifeRouteSavedPlace, mode: LifeRouteTransportMode) {
        guard routeTasks[place.id] == nil,
              savedPlaces.contains(where: { $0.id == place.id }) else { return }

        let generation = routeGenerationByPlace[place.id, default: 0] &+ 1
        routeGenerationByPlace[place.id] = generation
        routeRequestsInFlight.insert(place.id)
        let messageToken = publishRouteMessage("Calculating route…")
        routeMessageTokenByPlace[place.id] = messageToken
        routeTasks[place.id] = Task { @MainActor [weak self] in
            await self?.performRouteCalculation(
                to: place,
                mode: mode,
                generation: generation,
                messageToken: messageToken
            )
        }
    }

    func openInAppleMaps(_ place: LifeRouteSavedPlace, mode: LifeRouteTransportMode) {
        guard mapsOpenTask == nil,
              savedPlaces.contains(where: { $0.id == place.id }) else { return }

        mapsOpenGeneration &+= 1
        let generation = mapsOpenGeneration
        mapsOpenInFlight = true
        let messageToken = publishRouteMessage("Opening Apple Maps…")
        mapsOpenTask = Task { @MainActor [weak self] in
            await self?.performMapsOpen(
                place,
                mode: mode,
                generation: generation,
                messageToken: messageToken
            )
        }
    }

    func cancelPendingOperations() {
        let hadPendingWork = !routeTasks.isEmpty || mapsOpenTask != nil
        for task in routeTasks.values { task.cancel() }
        for placeID in Array(routeGenerationByPlace.keys) {
            routeGenerationByPlace[placeID, default: 0] &+= 1
        }
        routeTasks.removeAll()
        routeMessageTokenByPlace.removeAll()
        routeRequestsInFlight.removeAll()

        mapsOpenTask?.cancel()
        mapsOpenTask = nil
        mapsOpenGeneration &+= 1
        mapsOpenInFlight = false

        locationRequestPendingAuthorization = false
        locationRequestInFlight = false
        locationManager.stopUpdatingLocation()

        if hadPendingWork {
            _ = publishRouteMessage(nil)
        }
    }

    private func performRouteCalculation(
        to place: LifeRouteSavedPlace,
        mode: LifeRouteTransportMode,
        generation: UInt64,
        messageToken: UInt64
    ) async {
        do {
            let source = try await originMapItem()
            try validateRouteOperation(for: place.id, generation: generation)
            let destination = try await mapItem(for: place.address)
            try validateRouteOperation(for: place.id, generation: generation)
            let request = MKDirections.Request()
            request.source = source
            request.destination = destination
            request.transportType = mode.mapKitType

            let response = try await MKDirections(request: request).calculate()
            try validateRouteOperation(for: place.id, generation: generation)
            guard let route = response.routes.first else { throw RoutingLocationCoreError.routeUnavailable }
            routeEstimates[place.id] = LifeRouteRouteEstimate(
                placeID: place.id,
                mode: mode,
                distanceMeters: route.distance,
                travelTimeSeconds: route.expectedTravelTime
            )
            setRouteMessage("Route estimate updated.", token: messageToken)
        } catch is CancellationError {
            setRouteMessage(nil, token: messageToken)
        } catch {
            setRouteMessage(error.localizedDescription, token: messageToken)
        }
        finishRouteOperation(for: place.id, generation: generation)
    }

    private func performMapsOpen(
        _ place: LifeRouteSavedPlace,
        mode: LifeRouteTransportMode,
        generation: UInt64,
        messageToken: UInt64
    ) async {
        do {
            let destination = try await mapItem(for: place.address)
            try validateMapsOpen(placeID: place.id, generation: generation)
            destination.name = place.name
            destination.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: mode.mapsLaunchMode
            ])
            setRouteMessage(nil, token: messageToken)
        } catch is CancellationError {
            setRouteMessage(nil, token: messageToken)
        } catch {
            setRouteMessage(error.localizedDescription, token: messageToken)
        }
        finishMapsOpen(generation: generation)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        updateLocationMessage(for: authorizationStatus)
        let shouldRequestLocation = locationRequestPendingAuthorization
        locationRequestPendingAuthorization = false
        if shouldRequestLocation,
           (authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse) {
            locationRequestInFlight = true
            locationMessage = "Updating current location…"
            manager.requestLocation()
        } else if authorizationStatus != .notDetermined {
            locationRequestInFlight = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard locationRequestInFlight else { return }
        locationRequestInFlight = false
        guard let location = locations.last else {
            locationMessage = "Location unavailable; no position was returned."
            return
        }
        currentLocation = location
        locationMessage = "Current location ready"
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard locationRequestInFlight else { return }
        locationRequestInFlight = false
        locationMessage = "Location unavailable: \(error.localizedDescription)"
    }

    @discardableResult
    private func publishRouteMessage(_ message: String?) -> UInt64 {
        routeMessageGeneration &+= 1
        routeMessage = message
        return routeMessageGeneration
    }

    private func setRouteMessage(_ message: String?, token: UInt64) {
        guard token == routeMessageGeneration else { return }
        routeMessage = message
    }

    private func validateRouteOperation(for placeID: UUID, generation: UInt64) throws {
        try Task.checkCancellation()
        guard routeGenerationByPlace[placeID] == generation,
              savedPlaces.contains(where: { $0.id == placeID }) else {
            throw CancellationError()
        }
    }

    private func finishRouteOperation(for placeID: UUID, generation: UInt64) {
        guard routeGenerationByPlace[placeID] == generation else { return }
        routeTasks[placeID] = nil
        routeMessageTokenByPlace[placeID] = nil
        routeRequestsInFlight.remove(placeID)
    }

    private func cancelRouteOperation(for placeID: UUID) {
        routeTasks.removeValue(forKey: placeID)?.cancel()
        routeGenerationByPlace[placeID, default: 0] &+= 1
        routeRequestsInFlight.remove(placeID)
        if let token = routeMessageTokenByPlace.removeValue(forKey: placeID),
           token == routeMessageGeneration {
            _ = publishRouteMessage(nil)
        }
    }

    private func validateMapsOpen(placeID: UUID, generation: UInt64) throws {
        try Task.checkCancellation()
        guard mapsOpenGeneration == generation,
              savedPlaces.contains(where: { $0.id == placeID }) else {
            throw CancellationError()
        }
    }

    private func finishMapsOpen(generation: UInt64) {
        guard mapsOpenGeneration == generation else { return }
        mapsOpenTask = nil
        mapsOpenInFlight = false
    }

    private func persistRoutingInputs() {
        LifeRoutePersistenceStore.shared.saveRoutingState(homeAddress: homeAddress, savedPlaces: savedPlaces)
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
