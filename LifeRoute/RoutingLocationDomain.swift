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


// v0.7.0 native weekly To-Dos restore: recovers the flexible task/errand model
// that existed in the pre-native LifeRoute experience without reactivating WebView.
enum LifeRouteTodoCategory: String, CaseIterable, Codable, Identifiable, Hashable {
    case errand = "Errand"
    case shopping = "Shopping"
    case pickup = "Pickup"
    case chore = "Chore"
    case call = "Call"
    case other = "Other"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .errand: return "bag.fill"
        case .shopping: return "cart.fill"
        case .pickup: return "shippingbox.fill"
        case .chore: return "checklist"
        case .call: return "phone.fill"
        case .other: return "checkmark.circle.fill"
        }
    }
}

enum LifeRouteTodoPriority: String, CaseIterable, Codable, Identifiable, Hashable {
    case low
    case normal
    case high

    var id: Self { self }

    var title: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        }
    }

    var sortWeight: Int {
        switch self {
        case .low: return 0
        case .normal: return 1
        case .high: return 2
        }
    }
}

struct LifeRouteTodo: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var category: LifeRouteTodoCategory
    var durationMinutes: Int
    var savedPlaceID: UUID?
    var address: String
    var priority: LifeRouteTodoPriority
    var dueDate: Date
    var notes: String
    var completed: Bool
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        category: LifeRouteTodoCategory,
        durationMinutes: Int,
        savedPlaceID: UUID?,
        address: String,
        priority: LifeRouteTodoPriority,
        dueDate: Date,
        notes: String,
        completed: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.category = category
        self.durationMinutes = max(5, min(240, durationMinutes))
        self.savedPlaceID = savedPlaceID
        self.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        self.priority = priority
        self.dueDate = dueDate
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        self.completed = completed
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

struct LifeRouteAddressSuggestion: Identifiable, Hashable {
    let title: String
    let subtitle: String

    var id: String { title + "\n" + subtitle }

    var addressText: String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSubtitle.isEmpty else { return cleanTitle }
        guard !cleanTitle.localizedCaseInsensitiveContains(cleanSubtitle) else { return cleanTitle }
        return "\(cleanTitle), \(cleanSubtitle)"
    }
}


// v0.7.0 flexible destination intents: a To-Do may name the kind/brand of place
// rather than prematurely locking the user to one street address. The stored value
// stays human-readable while routing adapters receive a clean natural-language query.
struct LifeRouteDestinationIntent: Identifiable, Hashable {
    let storedValue: String
    let naturalLanguageQuery: String
    let systemImage: String
    let keywords: [String]

    var id: String { storedValue }

    static let todoOptions: [LifeRouteDestinationIntent] = [
        .init(storedValue: "Any grocery store", naturalLanguageQuery: "grocery store", systemImage: "cart.fill", keywords: ["grocery", "groceries", "supermarket", "food store"]),
        .init(storedValue: "Any Walmart", naturalLanguageQuery: "Walmart", systemImage: "cart.fill", keywords: ["walmart", "wal mart"]),
        .init(storedValue: "Any BJ's", naturalLanguageQuery: "BJ's Wholesale Club", systemImage: "cart.fill", keywords: ["bjs", "bj's", "bj wholesale", "warehouse"]),
        .init(storedValue: "Any Target", naturalLanguageQuery: "Target", systemImage: "scope", keywords: ["target"]),
        .init(storedValue: "Any Costco", naturalLanguageQuery: "Costco", systemImage: "cart.fill", keywords: ["costco", "warehouse"]),
        .init(storedValue: "Any pharmacy", naturalLanguageQuery: "pharmacy", systemImage: "cross.case.fill", keywords: ["pharmacy", "drugstore", "medicine"]),
        .init(storedValue: "Any gas station", naturalLanguageQuery: "gas station", systemImage: "fuelpump.fill", keywords: ["gas", "fuel", "gas station"]),
        .init(storedValue: "Any coffee shop", naturalLanguageQuery: "coffee shop", systemImage: "cup.and.saucer.fill", keywords: ["coffee", "cafe", "coffee shop"]),
        .init(storedValue: "Any convenience store", naturalLanguageQuery: "convenience store", systemImage: "storefront.fill", keywords: ["convenience", "corner store"]),
        .init(storedValue: "Any hardware store", naturalLanguageQuery: "hardware store", systemImage: "wrench.and.screwdriver.fill", keywords: ["hardware", "home improvement"]),
        .init(storedValue: "Any bank", naturalLanguageQuery: "bank", systemImage: "building.columns.fill", keywords: ["bank", "atm"]),
        .init(storedValue: "Any post office", naturalLanguageQuery: "post office", systemImage: "envelope.fill", keywords: ["post", "mail", "usps", "post office"]),
    ]

    static func matches(_ input: String) -> [LifeRouteDestinationIntent] {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.count >= 2 else { return [] }

        return todoOptions.filter { option in
            let searchable = ([option.storedValue, option.naturalLanguageQuery] + option.keywords)
                .joined(separator: " ")
                .lowercased()
            return searchable.contains(query)
        }.prefix(6).map { $0 }
    }

    static func naturalLanguageQuery(forStoredValue value: String) -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let intent = todoOptions.first(where: {
            $0.storedValue.compare(cleaned, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else {
            return cleaned
        }
        return intent.naturalLanguageQuery
    }
}

final class LifeRouteAddressAutocomplete: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published private(set) var suggestions: [LifeRouteAddressSuggestion] = []
    @Published private(set) var message: String?

    private let completer = MKLocalSearchCompleter()
    private var lastQuery = ""

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String) {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned != lastQuery else { return }
        lastQuery = cleaned
        message = nil

        guard cleaned.count >= 3 else {
            suggestions = []
            completer.queryFragment = ""
            return
        }
        completer.queryFragment = cleaned
    }

    func clear() {
        lastQuery = ""
        suggestions = []
        message = nil
        completer.queryFragment = ""
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Ignore a stale delegate callback that arrives after a user has already selected/cleared a result.
        let requestedQuery = lastQuery
        guard !requestedQuery.isEmpty else { return }
        let next = Array(completer.results.prefix(6)).map {
            LifeRouteAddressSuggestion(title: $0.title, subtitle: $0.subtitle)
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.lastQuery == requestedQuery, !requestedQuery.isEmpty else { return }
            self.suggestions = next
            self.message = nil
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        let requestedQuery = lastQuery
        guard !requestedQuery.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.lastQuery == requestedQuery, !requestedQuery.isEmpty else { return }
            self.suggestions = []
            self.message = "Address suggestions are temporarily unavailable. You can still type the address manually."
        }
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
    case missingTodoTitle

    var errorDescription: String? {
        switch self {
        case .missingName: return "Enter a place name."
        case .missingAddress: return "Enter an address or searchable place."
        case .originUnavailable: return "Current location is not ready. Allow location access or add a home address as a fallback."
        case .destinationNotFound: return "LifeRoute could not find that destination."
        case .routeUnavailable: return "A route could not be calculated for that destination."
        case .missingTodoTitle: return "Add what you need to get done."
        }
    }
}

@MainActor
final class RoutingLocationCore: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var locationMessage = "Location not requested"
    @Published private(set) var savedPlaces: [LifeRouteSavedPlace] = []
    @Published private(set) var todos: [LifeRouteTodo] = []
    @Published private(set) var dayStops: [LifeRouteDayStop] = []
    @Published private(set) var routeEstimates: [UUID: LifeRouteRouteEstimate] = [:]
    @Published private(set) var routeMessage: String?
    @Published private(set) var homeAddress = ""
    @Published private(set) var routeBufferMinutes = 10
    @Published private(set) var locationRequestInFlight = false
    @Published private(set) var liveLocationEnabled = false
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
        self.todos = restored.todos
        self.dayStops = restored.dayStops
        self.homeAddress = restored.homeAddress
        self.routeBufferMinutes = restored.routeBufferMinutes
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 25
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = false
        authorizationStatus = locationManager.authorizationStatus
        updateLocationMessage(for: authorizationStatus)
    }

    var routeOriginLocation: CLLocation? {
        liveLocationEnabled ? currentLocation : nil
    }

    var routeOriginStatus: LifeRouteRouteOriginStatus {
        LifeRouteRouteOriginStatus.resolve(
            liveLocationEnabled: liveLocationEnabled,
            currentLocationAvailable: currentLocation != nil,
            homeAddress: homeAddress
        )
    }

    func requestCurrentLocation() {
        guard !locationRequestInFlight else { return }
        authorizationStatus = locationManager.authorizationStatus
        switch authorizationStatus {
        case .notDetermined:
            locationRequestInFlight = true
            locationRequestPendingAuthorization = true
            liveLocationEnabled = true
            locationMessage = "Requesting location permission…"
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            beginForegroundLocationUpdates()
        case .denied:
            locationRequestPendingAuthorization = false
            liveLocationEnabled = false
            locationMessage = "Location access is denied. You can enable it in iPhone Settings."
        case .restricted:
            locationRequestPendingAuthorization = false
            liveLocationEnabled = false
            locationMessage = "Location access is restricted on this iPhone."
        @unknown default:
            locationRequestPendingAuthorization = false
            liveLocationEnabled = false
            locationMessage = "Location status is unavailable."
        }
    }

    func resumeForegroundLocationIfNeeded() {
        authorizationStatus = locationManager.authorizationStatus
        guard liveLocationEnabled,
              (authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse) else {
            updateLocationMessage(for: authorizationStatus)
            return
        }
        locationManager.startUpdatingLocation()
        locationMessage = currentLocation == nil ? "Updating live location…" : "Live location active"
    }

    func stopLiveLocation() {
        liveLocationEnabled = false
        locationRequestInFlight = false
        locationRequestPendingAuthorization = false
        locationManager.stopUpdatingLocation()
        currentLocation = nil
        updateLocationMessage(for: locationManager.authorizationStatus)
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

    func addTodo(
        title: String,
        category: LifeRouteTodoCategory,
        durationMinutes: Int,
        savedPlaceID: UUID?,
        address: String,
        priority: LifeRouteTodoPriority,
        dueDate: Date,
        notes: String
    ) throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw RoutingLocationCoreError.missingTodoTitle }

        let linkedPlace = savedPlaceID.flatMap { id in savedPlaces.first(where: { $0.id == id }) }
        let cleanAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAddress = cleanAddress.isEmpty ? (linkedPlace?.address ?? "") : cleanAddress

        todos.append(
            LifeRouteTodo(
                title: cleanTitle,
                category: category,
                durationMinutes: durationMinutes,
                savedPlaceID: linkedPlace?.id,
                address: resolvedAddress,
                priority: priority,
                dueDate: dueDate,
                notes: notes
            )
        )
        sortTodos()
        persistTodoInputs()
    }

    func setTodoCompleted(id: UUID, completed: Bool) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].completed = completed
        todos[index].completedAt = completed ? Date() : nil
        sortTodos()
        persistTodoInputs()
    }

    func removeTodo(id: UUID) {
        todos.removeAll { $0.id == id }
        persistTodoInputs()
    }

    func dayStops(on day: Date) -> [LifeRouteDayStop] {
        LifeRouteDayStopCollection.stops(on: day, in: dayStops)
    }

    @discardableResult
    func addDayStop(
        title: String,
        address: String,
        position: LifeRouteDayStop.Position,
        day: Date,
        savedPlaceID: UUID? = nil,
        durationMinutes: Int = 20,
        afterAppointmentID: String? = nil
    ) -> Bool {
        let candidate = LifeRouteDayStop(
            title: title.isEmpty ? "Stop" : title,
            address: address,
            position: position,
            day: day,
            savedPlaceID: savedPlaceID,
            durationMinutes: durationMinutes,
            afterAppointmentID: afterAppointmentID
        )
        let result = LifeRouteDayStopCollection.adding(candidate, to: dayStops)
        guard result.inserted else { return false }
        dayStops = result.stops
        persistDayStopInputs()
        return true
    }

    func removeDayStop(id: UUID) {
        let updated = LifeRouteDayStopCollection.removing(id: id, from: dayStops)
        guard updated.count != dayStops.count else { return }
        dayStops = updated
        persistDayStopInputs()
    }

    func setRouteBufferMinutes(_ minutes: Int) {
        let bounded = max(0, min(180, minutes))
        guard routeBufferMinutes != bounded else { return }
        routeBufferMinutes = bounded
        persistRoutingInputs()
    }

    private func sortTodos() {
        todos.sort { lhs, rhs in
            if lhs.completed != rhs.completed { return !lhs.completed }
            if lhs.priority.sortWeight != rhs.priority.sortWeight {
                return lhs.priority.sortWeight > rhs.priority.sortWeight
            }
            if lhs.dueDate != rhs.dueDate { return lhs.dueDate < rhs.dueDate }
            return lhs.createdAt < rhs.createdAt
        }
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
        // Do not tear down an explicitly enabled foreground live-location session here.
        // With When-In-Use authorization iOS suspends delivery in the background and
        // the active scene resumes the same standard location service on return.

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
        let shouldBeginLiveUpdates = locationRequestPendingAuthorization || liveLocationEnabled
        locationRequestPendingAuthorization = false
        if shouldBeginLiveUpdates,
           (authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse) {
            beginForegroundLocationUpdates()
        } else if authorizationStatus != .notDetermined {
            locationRequestInFlight = false
            if authorizationStatus == .denied || authorizationStatus == .restricted {
                liveLocationEnabled = false
                currentLocation = nil
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard locationRequestInFlight || liveLocationEnabled else { return }
        guard let location = locations.last else {
            locationRequestInFlight = false
            locationMessage = "Location unavailable; no position was returned."
            return
        }
        currentLocation = location
        locationRequestInFlight = false
        locationMessage = liveLocationEnabled ? "Live location active" : "Current location ready"
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard locationRequestInFlight || liveLocationEnabled else { return }
        locationRequestInFlight = false
        if liveLocationEnabled {
            locationMessage = "Live location temporarily unavailable: \(error.localizedDescription)"
        } else {
            locationMessage = "Location unavailable: \(error.localizedDescription)"
        }
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
        LifeRoutePersistenceStore.shared.saveRoutingState(
            homeAddress: homeAddress,
            savedPlaces: savedPlaces,
            todos: todos,
            dayStops: dayStops,
            routeBufferMinutes: routeBufferMinutes
        )
    }

    private func persistTodoInputs() {
        LifeRoutePersistenceStore.shared.saveRoutingState(
            homeAddress: homeAddress,
            savedPlaces: savedPlaces,
            todos: todos,
            dayStops: dayStops,
            routeBufferMinutes: routeBufferMinutes
        )
    }

    private func persistDayStopInputs() {
        LifeRoutePersistenceStore.shared.saveRoutingState(
            homeAddress: homeAddress,
            savedPlaces: savedPlaces,
            todos: todos,
            dayStops: dayStops,
            routeBufferMinutes: routeBufferMinutes
        )
    }

    private func updateLocationMessage(for status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationMessage = "Location not requested"
        case .authorizedAlways, .authorizedWhenInUse:
            if liveLocationEnabled {
                locationMessage = currentLocation == nil ? "Updating live location…" : "Live location active"
            } else {
                locationMessage = currentLocation == nil ? "Location allowed; tap Locate to start" : "Current location ready"
            }
        case .denied:
            locationMessage = "Location access is denied"
        case .restricted:
            locationMessage = "Location access is restricted"
        @unknown default:
            locationMessage = "Location status is unavailable"
        }
    }

    private func beginForegroundLocationUpdates() {
        liveLocationEnabled = true
        locationRequestInFlight = true
        locationMessage = "Updating live location…"
        locationManager.startUpdatingLocation()
    }

    private func originMapItem() async throws -> MKMapItem {
        if let currentLocation = routeOriginLocation {
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
        request.naturalLanguageQuery = LifeRouteDestinationIntent.naturalLanguageQuery(forStoredValue: cleaned)
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else { throw RoutingLocationCoreError.destinationNotFound }
        return item
    }
}
