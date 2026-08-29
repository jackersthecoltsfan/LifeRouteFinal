from pathlib import Path

# Store searches already return exact MKMapItems, but the web bridge previously
# threw those objects away and reconstructed bare coordinate-only placemarks for
# directions. Some POIs (notably certain Walmart branches) then return
# MKErrorDirectionsNotFound even though Apple Maps can route to the actual place.
# Preserve the original MKMapItem in the native cache and send a lightweight key
# through JavaScript so directions use the exact routable POI first.

swift_path = Path("LifeRoute/LifeRouteWebView.swift")
swift = swift_path.read_text()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"Could not patch {label}: marker not found")
    return text.replace(old, new, 1)


swift = replace_once(
    swift,
    '''                        let sourceItem = try await resolveMapItem(
                            origin,
                            latitude: number(segment["originLatitude"]),
                            longitude: number(segment["originLongitude"])
                        )
                        let destinationItem = try await resolveMapItem(
                            destination,
                            latitude: number(segment["destinationLatitude"]),
                            longitude: number(segment["destinationLongitude"])
                        )
''',
    '''                        let sourceItem = try await resolveMapItem(
                            origin,
                            mapItemKey: segment["originMapItemKey"] as? String,
                            latitude: number(segment["originLatitude"]),
                            longitude: number(segment["originLongitude"])
                        )
                        let destinationItem = try await resolveMapItem(
                            destination,
                            mapItemKey: segment["destinationMapItemKey"] as? String,
                            latitude: number(segment["destinationLatitude"]),
                            longitude: number(segment["destinationLongitude"])
                        )
''',
    "route endpoint MapItem keys",
)

swift = replace_once(
    swift,
    '''                            guard !seen.contains(key) else { continue }
                            seen.insert(key)

                            locations.append([
                                "brand": query,
                                "name": name?.isEmpty == false ? name! : query,
                                "address": address.isEmpty ? (item.placemark.title ?? query) : address,
                                "latitude": coordinate.latitude,
                                "longitude": coordinate.longitude
                            ])
''',
    '''                            guard !seen.contains(key) else { continue }
                            seen.insert(key)

                            // Keep the exact POI returned by MKLocalSearch. A bare
                            // coordinate can be inside a large parking lot/building and
                            // occasionally has no routable road snap, while the original
                            // MKMapItem carries Apple's place/routing metadata.
                            let mapItemKey = "store-route|\\(requestID)|\\(key)"
                            mapItemCache[mapItemKey] = item

                            locations.append([
                                "brand": query,
                                "name": name?.isEmpty == false ? name! : query,
                                "address": address.isEmpty ? (item.placemark.title ?? query) : address,
                                "latitude": coordinate.latitude,
                                "longitude": coordinate.longitude,
                                "mapItemKey": mapItemKey
                            ])
''',
    "store MapItem caching",
)

swift = replace_once(
    swift,
    '''        private func resolveMapItem(
            _ query: String,
            latitude: Double? = nil,
            longitude: Double? = nil
        ) async throws -> MKMapItem {
            if let latitude, let longitude,
''',
    '''        private func resolveMapItem(
            _ query: String,
            mapItemKey: String? = nil,
            latitude: Double? = nil,
            longitude: Double? = nil
        ) async throws -> MKMapItem {
            if let mapItemKey,
               let exactItem = mapItemCache[mapItemKey] {
                return exactItem
            }

            if let latitude, let longitude,
''',
    "MapItem resolver cache key",
)

# The existing resilience patch retries without a departure date. Add one final
# fallback that resolves both endpoints by their human-readable address/name.
# This catches the remaining MapKit cases where an exact POI or coordinate is
# temporarily not routable but its street address is.
swift = replace_once(
    swift,
    '''                        } catch {
                            // A time-specific request can fail transiently even when a
                            // normal route exists. Retry without traffic/departure timing
                            // before declaring the leg unavailable.
                            request.departureDate = nil
                            let retryResponse = try await MKDirections(request: request).calculate()
                            guard let fallback = retryResponse.routes.min(by: {
                                $0.expectedTravelTime < $1.expectedTravelTime
                            }) else {
                                throw error
                            }
                            route = fallback
                        }
''',
    '''                        } catch {
                            // A time-specific request can fail transiently even when a
                            // normal route exists. Retry without traffic/departure timing
                            // before declaring the leg unavailable.
                            request.departureDate = nil
                            do {
                                let retryResponse = try await MKDirections(request: request).calculate()
                                guard let fallback = retryResponse.routes.min(by: {
                                    $0.expectedTravelTime < $1.expectedTravelTime
                                }) else {
                                    throw RouteTimeError.noRoute
                                }
                                route = fallback
                            } catch let retryError {
                                // Last resort: resolve the displayed street/name text again
                                // instead of the POI coordinate. This fixes valid stores that
                                // MapKit reports as "Directions Not Available" from a bare
                                // parking-lot/building coordinate.
                                request.source = try await resolveMapItem(origin)
                                request.destination = try await resolveMapItem(destination)
                                let addressResponse = try await MKDirections(request: request).calculate()
                                guard let addressFallback = addressResponse.routes.min(by: {
                                    $0.expectedTravelTime < $1.expectedTravelTime
                                }) else {
                                    throw retryError
                                }
                                route = addressFallback
                            }
                        }
''',
    "address-based directions fallback",
)

swift_path.write_text(swift)

js_path = Path("LifeRoute/Web/grocery-stores.js")
js = js_path.read_text()
js = replace_once(
    js,
    '''        destination: location.address || location.name || location.brand,
        destinationLatitude: location.latitude,
        destinationLongitude: location.longitude,
        departure: departureISO(request.dateKey, request.previous.end, 0)
''',
    '''        destination: location.address || location.name || location.brand,
        destinationMapItemKey: location.mapItemKey,
        destinationLatitude: location.latitude,
        destinationLongitude: location.longitude,
        departure: departureISO(request.dateKey, request.previous.end, 0)
''',
    "store outbound MapItem key",
)
js = replace_once(
    js,
    '''        origin: location.address || location.name || location.brand,
        originLatitude: location.latitude,
        originLongitude: location.longitude,
        destination: request.next.address,
''',
    '''        origin: location.address || location.name || location.brand,
        originMapItemKey: location.mapItemKey,
        originLatitude: location.latitude,
        originLongitude: location.longitude,
        destination: request.next.address,
''',
    "store return MapItem key",
)
js_path.write_text(js)

print("Preserved exact store MKMapItems and added address fallback routing.")
