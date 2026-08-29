from pathlib import Path

# General route reliability hardening. Calendar locations often contain a place
# name plus an address, and MapKit's first local-search hit is not always the
# routable entrance. If the normal request + no-departure retry both fail, try
# several cleaned address variants and several MapKit candidates before giving
# up. This applies to appointment routes and both legs of gap/store detours.

path = Path("LifeRoute/LifeRouteWebView.swift")
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Could not patch {label}: marker not found")
    text = text.replace(old, new, 1)


old_fallback = '''                            } catch let retryError {
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
'''
new_fallback = '''                            } catch let retryError {
                                // The first search result is not always the routable entrance.
                                // Retry across cleaned address variants and multiple nearby
                                // MapKit search candidates before declaring the leg unavailable.
                                if let resilient = try? await resilientRoute(
                                    origin: origin,
                                    destination: destination,
                                    transportType: request.transportType
                                ) {
                                    route = resilient
                                } else {
                                    throw retryError
                                }
                            }
'''
replace_once(old_fallback, new_fallback, "multi-candidate route fallback")

helper_marker = '''        private func number(_ value: Any?) -> Double? {
'''
helper_code = r'''        private func routeQueryVariants(_ raw: String) -> [String] {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [] }

            let flattened = trimmed
                .replacingOccurrences(of: "\n", with: ", ")
                .replacingOccurrences(of: "\r", with: ", ")
                .replacingOccurrences(of: "  ", with: " ")

            var variants = [trimmed]
            if flattened != trimmed { variants.append(flattened) }

            // Calendar locations are commonly stored as
            // "Client/Business Name, 123 Main St, City, PA". The business/name
            // prefix can cause MKLocalSearch to pick the wrong POI, so also try
            // the address beginning at the first street number.
            if let digit = flattened.firstIndex(where: { $0.isNumber }), digit != flattened.startIndex {
                let suffix = String(flattened[digit...])
                    .trimmingCharacters(in: CharacterSet(charactersIn: " ,;-"))
                if suffix.count >= 6 { variants.append(suffix) }
            }

            // Also try everything after the first comma when the first clause is
            // a label rather than the street address.
            if let comma = flattened.firstIndex(of: ",") {
                let after = String(flattened[flattened.index(after: comma)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if after.count >= 6 && after.contains(where: { $0.isNumber }) {
                    variants.append(after)
                }
            }

            var seen = Set<String>()
            return variants.filter { value in
                let key = value.lowercased()
                guard seen.insert(key).inserted else { return false }
                return true
            }
        }

        private func routeMapItemCandidates(_ rawQuery: String, limit: Int = 4) async -> [MKMapItem] {
            var output: [MKMapItem] = []
            var seenCoordinates = Set<String>()

            for variant in routeQueryVariants(rawQuery) {
                let cacheKey = variant.lowercased()
                if let cached = mapItemCache[cacheKey] {
                    let coordinate = cached.placemark.coordinate
                    let key = String(format: "%.5f|%.5f", coordinate.latitude, coordinate.longitude)
                    if seenCoordinates.insert(key).inserted { output.append(cached) }
                }

                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = variant
                request.resultTypes = [.address, .pointOfInterest]

                guard let response = try? await MKLocalSearch(request: request).start() else { continue }
                for item in response.mapItems.prefix(max(1, limit)) {
                    let coordinate = item.placemark.coordinate
                    let key = String(format: "%.5f|%.5f", coordinate.latitude, coordinate.longitude)
                    guard seenCoordinates.insert(key).inserted else { continue }
                    output.append(item)
                    if mapItemCache[cacheKey] == nil { mapItemCache[cacheKey] = item }
                }
            }

            return Array(output.prefix(max(1, limit)))
        }

        private func resilientRoute(
            origin: String,
            destination: String,
            transportType: MKDirectionsTransportType
        ) async throws -> MKRoute {
            let sources = await routeMapItemCandidates(origin, limit: 4)
            let destinations = await routeMapItemCandidates(destination, limit: 4)
            guard !sources.isEmpty, !destinations.isEmpty else {
                throw RouteTimeError.noRoute
            }

            var lastError: Error = RouteTimeError.noRoute
            var attempts = 0

            // The common case succeeds immediately. Only failed legs pay for
            // these alternate candidate combinations, capped to keep MapKit
            // traffic reasonable.
            for source in sources {
                for destinationItem in destinations {
                    attempts += 1
                    if attempts > 10 { break }

                    let request = MKDirections.Request()
                    request.source = source
                    request.destination = destinationItem
                    request.transportType = transportType
                    request.requestsAlternateRoutes = true

                    do {
                        let response = try await MKDirections(request: request).calculate()
                        if let route = response.routes.min(by: {
                            $0.expectedTravelTime < $1.expectedTravelTime
                        }) {
                            return route
                        }
                    } catch {
                        lastError = error
                        // A short pause helps when MapKit rejected the original
                        // batch because of transient service pressure.
                        try? await Task.sleep(nanoseconds: 90_000_000)
                    }
                }
                if attempts > 10 { break }
            }

            throw lastError
        }

'''
replace_once(helper_marker, helper_code + helper_marker, "resilient routing helpers")

path.write_text(text)
print("Added multi-candidate MapKit route recovery for calendar, gap, and store routes.")
