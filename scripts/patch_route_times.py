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
    '            case "disconnectGoogleCalendar":\n                disconnectGoogleCalendar()\n            case "requestRouteTimes":\n                calculateRouteTimes(body["segments"] as? [[String: Any]] ?? [])\n            case "searchStoreLocations":\n                searchStoreLocations(\n                    requestID: (body["requestID"] as? String) ?? UUID().uuidString,\n                    queries: body["queries"] as? [String] ?? [],\n                    nearAddresses: body["nearAddresses"] as? [String] ?? [],\n                    limitPerQuery: (body["limitPerQuery"] as? NSNumber)?.intValue ?? 4\n                )\n',
    "route/store bridge actions",
)

route_code = r'''
        // MARK: - Route time data + nearby store search (Apple MapKit)

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
                        let sourceItem = try await resolveMapItem(
                            origin,
                            latitude: number(segment["originLatitude"]),
                            longitude: number(segment["originLongitude"])
                        )
                        let destinationItem = try await resolveMapItem(
                            destination,
                            latitude: number(segment["destinationLatitude"]),
                            longitude: number(segment["destinationLongitude"])
                        )

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

        private func searchStoreLocations(
            requestID: String,
            queries: [String],
            nearAddresses: [String],
            limitPerQuery: Int
        ) {
            let cleanedQueries = Array(Set(queries.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty })).sorted()

            guard !cleanedQueries.isEmpty else {
                emit(type: "storeLocations", payload: [
                    "requestID": requestID,
                    "engine": "apple-mapkit",
                    "locations": []
                ])
                return
            }

            Task {
                let region = await storeSearchRegion(nearAddresses)
                var locations: [[String: Any]] = []
                var seen = Set<String>()
                let perQuery = max(1, min(8, limitPerQuery))

                for query in cleanedQueries {
                    do {
                        let request = MKLocalSearch.Request()
                        request.naturalLanguageQuery = query
                        request.resultTypes = [.pointOfInterest, .address]
                        if let region { request.region = region }

                        let response = try await MKLocalSearch(request: request).start()
                        for item in response.mapItems.prefix(perQuery) {
                            let coordinate = item.placemark.coordinate
                            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                            let address = displayAddress(item.placemark)
                            let key = String(format: "%.5f|%.5f|%@", coordinate.latitude, coordinate.longitude, (name ?? query).lowercased())
                            guard !seen.contains(key) else { continue }
                            seen.insert(key)

                            locations.append([
                                "brand": query,
                                "name": name?.isEmpty == false ? name! : query,
                                "address": address.isEmpty ? (item.placemark.title ?? query) : address,
                                "latitude": coordinate.latitude,
                                "longitude": coordinate.longitude
                            ])
                        }
                    } catch {
                        // One chain failing should not prevent other preferred chains from returning.
                        continue
                    }
                }

                emit(type: "storeLocations", payload: [
                    "requestID": requestID,
                    "engine": "apple-mapkit",
                    "locations": locations
                ])
            }
        }

        private func storeSearchRegion(_ nearAddresses: [String]) async -> MKCoordinateRegion? {
            var coordinates: [CLLocationCoordinate2D] = []
            for address in nearAddresses.prefix(2) {
                let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                if let item = try? await resolveMapItem(trimmed) {
                    coordinates.append(item.placemark.coordinate)
                }
            }
            guard let first = coordinates.first else { return nil }
            if coordinates.count == 1 {
                return MKCoordinateRegion(
                    center: first,
                    span: MKCoordinateSpan(latitudeDelta: 0.32, longitudeDelta: 0.32)
                )
            }

            let second = coordinates[1]
            let center = CLLocationCoordinate2D(
                latitude: (first.latitude + second.latitude) / 2,
                longitude: (first.longitude + second.longitude) / 2
            )
            let latDelta = max(0.22, abs(first.latitude - second.latitude) * 2.4 + 0.12)
            let lonDelta = max(0.22, abs(first.longitude - second.longitude) * 2.4 + 0.12)
            return MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: min(1.2, latDelta), longitudeDelta: min(1.2, lonDelta))
            )
        }

        private func displayAddress(_ placemark: MKPlacemark) -> String {
            let street = [placemark.subThoroughfare, placemark.thoroughfare]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let cityStateZip = [placemark.locality, placemark.administrativeArea, placemark.postalCode]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return [street, cityStateZip].filter { !$0.isEmpty }.joined(separator: ", ")
        }

        private func resolveMapItem(
            _ query: String,
            latitude: Double? = nil,
            longitude: Double? = nil
        ) async throws -> MKMapItem {
            if let latitude, let longitude,
               (-90.0...90.0).contains(latitude),
               (-180.0...180.0).contains(longitude) {
                return MKMapItem(placemark: MKPlacemark(
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                ))
            }

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

        private func number(_ value: Any?) -> Double? {
            if let number = value as? NSNumber { return number.doubleValue }
            if let value = value as? Double { return value }
            if let value = value as? String { return Double(value) }
            return nil
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
    "MapKit route/store functions",
)

replace_once(
    '                "googleCalendarConnected": googleCalendarConnected,\n                "googleMapsHandoffAvailable": true,\n',
    '                "googleCalendarConnected": googleCalendarConnected,\n                "routeTimeEngine": "apple-mapkit",\n                "storeSearchEngine": "apple-mapkit",\n                "googleMapsHandoffAvailable": true,\n',
    "native route/store status",
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

web_path = Path("LifeRoute/Web/index.html")
html = web_path.read_text()
store_tag = '<script src="grocery-stores.js"></script>'
if store_tag not in html:
    if "</body>" not in html:
        raise SystemExit("Could not enable grocery store preferences: </body> not found")
    html = html.replace("</body>", f"{store_tag}\n</body>", 1)
    web_path.write_text(html)

print("Patched LifeRoute with Apple MapKit route times, store search, and grocery store preferences.")
