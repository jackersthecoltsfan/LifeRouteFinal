from pathlib import Path

path = Path("LifeRoute/LifeRouteWebView.swift")
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Could not patch {label}: marker not found")
    text = text.replace(old, new, 1)


replace_once(
    "import Security\n",
    "import Security\nimport MapKit\n",
    "MapKit import",
)

replace_once(
    "        private var googleAccessTokenExpiry: Date?\n",
    "        private var googleAccessTokenExpiry: Date?\n        private var mapItemCache: [String: MKMapItem] = [:]\n",
    "MapKit cache",
)

replace_once(
    '            case "disconnectGoogleCalendar":\n                disconnectGoogleCalendar()\n',
    '            case "disconnectGoogleCalendar":\n                disconnectGoogleCalendar()\n            case "requestRouteTimes":\n                calculateRouteTimes(body["segments"] as? [[String: Any]] ?? [])\n',
    "route-time bridge action",
)

route_code = r'''
        // MARK: - Route time data (Apple MapKit)

        private func calculateRouteTimes(_ segments: [[String: Any]]) {
            guard !segments.isEmpty else {
                emit(type: "routeTimes", payload: ["engine": "apple-mapkit", "results": []])
                return
            }

            Task {
                var results: [[String: Any]] = []

                for segment in segments {
                    guard let id = segment["id"] as? String,
                          let origin = segment["origin"] as? String,
                          let destination = segment["destination"] as? String,
                          !origin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        continue
                    }

                    do {
                        let sourceItem = try await resolveMapItem(origin)
                        let destinationItem = try await resolveMapItem(destination)

                        let request = MKDirections.Request()
                        request.source = sourceItem
                        request.destination = destinationItem
                        request.transportType = .automobile
                        request.requestsAlternateRoutes = false

                        if let departure = segment["departure"] as? String,
                           let departureDate = parseRouteDate(departure) {
                            request.departureDate = departureDate
                        }

                        let response = try await MKDirections(request: request).calculate()
                        guard let route = response.routes.min(by: {
                            $0.expectedTravelTime < $1.expectedTravelTime
                        }) else {
                            throw RouteTimeError.noRoute
                        }

                        var result: [String: Any] = [
                            "id": id,
                            "minutes": max(1, Int(ceil(route.expectedTravelTime / 60.0))),
                            "seconds": Int(route.expectedTravelTime.rounded()),
                            "distanceMeters": Int(route.distance.rounded()),
                            "origin": origin,
                            "destination": destination
                        ]
                        if let value = segment["toEventID"] as? String { result["toEventID"] = value }
                        if let value = segment["fromEventID"] as? String { result["fromEventID"] = value }
                        if let value = segment["date"] as? String { result["date"] = value }
                        results.append(result)
                    } catch {
                        var result: [String: Any] = [
                            "id": id,
                            "origin": origin,
                            "destination": destination,
                            "error": error.localizedDescription
                        ]
                        if let value = segment["toEventID"] as? String { result["toEventID"] = value }
                        if let value = segment["fromEventID"] as? String { result["fromEventID"] = value }
                        if let value = segment["date"] as? String { result["date"] = value }
                        results.append(result)
                    }
                }

                emit(type: "routeTimes", payload: [
                    "engine": "apple-mapkit",
                    "results": results
                ])
            }
        }

        private func resolveMapItem(_ query: String) async throws -> MKMapItem {
            let key = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let cached = mapItemCache[key] {
                return cached
            }

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = [.address, .pointOfInterest]
            let response = try await MKLocalSearch(request: request).start()
            guard let mapItem = response.mapItems.first else {
                throw RouteTimeError.locationNotFound(query)
            }
            mapItemCache[key] = mapItem
            return mapItem
        }

        private func parseRouteDate(_ value: String) -> Date? {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: value) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: value)
        }

'''

replace_once(
    "        // MARK: - Google OAuth helpers / Keychain\n",
    route_code + "        // MARK: - Google OAuth helpers / Keychain\n",
    "MapKit route functions",
)

replace_once(
    '                "googleCalendarConnected": googleCalendarConnected,\n                "googleMapsHandoffAvailable": true,\n',
    '                "googleCalendarConnected": googleCalendarConnected,\n                "routeTimeEngine": "apple-mapkit",\n                "googleMapsHandoffAvailable": true,\n',
    "native route-time status",
)

if "private enum RouteTimeError" not in text:
    text += r'''

private enum RouteTimeError: LocalizedError {
    case locationNotFound(String)
    case noRoute

    var errorDescription: String? {
        switch self {
        case .locationNotFound(let query):
            return "Could not locate \(query)."
        case .noRoute:
            return "No driving route was returned."
        }
    }
}
'''

path.write_text(text)
print("Patched LifeRouteWebView.swift with native Apple MapKit route-time support.")
