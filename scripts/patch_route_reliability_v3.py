from pathlib import Path

# Final route-time safety net. MKDirections occasionally refuses otherwise valid
# endpoints even after the normal request, no-departure retry, address cleanup,
# and alternate MapKit candidates. For planning UI, return a clearly marked
# map-distance estimate instead of leaving a useful gap as "Route unavailable".
# Navigation still hands off to Apple/Google Maps for the real turn-by-turn route.

path = Path("LifeRoute/LifeRouteWebView.swift")
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Could not patch {label}: marker not found")
    text = text.replace(old, new, 1)


old_catch = '''                    } catch {
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
'''
new_catch = '''                    } catch {
                        // If MapKit can locate both endpoints but cannot return a
                        // directions object, keep LifeRoute useful with a conservative,
                        // explicitly marked planning estimate. This is not presented as
                        // live traffic and never replaces the real route in Maps.
                        if let estimate = try? await approximateRouteFallback(
                            origin: origin,
                            destination: destination,
                            originLatitude: number(segment["originLatitude"]),
                            originLongitude: number(segment["originLongitude"]),
                            destinationLatitude: number(segment["destinationLatitude"]),
                            destinationLongitude: number(segment["destinationLongitude"]),
                            transportType: routeTransportType(segment["transportMode"] as? String)
                        ) {
                            var result: [String: Any] = [
                                "id": id,
                                "minutes": estimate.minutes,
                                "seconds": estimate.minutes * 60,
                                "distanceMeters": estimate.distanceMeters,
                                "origin": origin,
                                "destination": destination,
                                "approximate": true,
                                "routeSource": "map-distance-estimate"
                            ]
                            if let value = segment["toEventID"] as? String { result["toEventID"] = value }
                            if let value = segment["fromEventID"] as? String { result["fromEventID"] = value }
                            if let value = segment["date"] as? String { result["date"] = value }
                            results.append(result)
                        } else {
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
'''
replace_once(old_catch, new_catch, "route estimate safety net")

helper_marker = '''        private func number(_ value: Any?) -> Double? {
'''
helper_code = r'''        private func fallbackCoordinate(
            query: String,
            latitude: Double?,
            longitude: Double?
        ) async -> CLLocationCoordinate2D? {
            if let latitude, let longitude,
               (-90.0...90.0).contains(latitude),
               (-180.0...180.0).contains(longitude) {
                return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
            if let item = await routeMapItemCandidates(query, limit: 1).first {
                return item.placemark.coordinate
            }
            return nil
        }

        private func approximateRouteFallback(
            origin: String,
            destination: String,
            originLatitude: Double?,
            originLongitude: Double?,
            destinationLatitude: Double?,
            destinationLongitude: Double?,
            transportType: MKDirectionsTransportType
        ) async throws -> (minutes: Int, distanceMeters: Int) {
            guard let source = await fallbackCoordinate(
                query: origin,
                latitude: originLatitude,
                longitude: originLongitude
            ), let target = await fallbackCoordinate(
                query: destination,
                latitude: destinationLatitude,
                longitude: destinationLongitude
            ) else {
                throw RouteTimeError.noRoute
            }

            let straightMeters = CLLocation(
                latitude: source.latitude,
                longitude: source.longitude
            ).distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))

            guard straightMeters.isFinite, straightMeters > 20 else {
                return (1, max(20, Int(straightMeters.rounded())))
            }

            let roadFactor: Double
            let metersPerSecond: Double
            let fixedMinutes: Double
            switch transportType {
            case .walking:
                roadFactor = 1.12
                metersPerSecond = 1.34
                fixedMinutes = 0
            case .transit:
                roadFactor = 1.24
                metersPerSecond = 7.4
                fixedMinutes = 7
            default:
                roadFactor = 1.28
                metersPerSecond = 13.4
                fixedMinutes = 2
            }

            let estimatedMeters = straightMeters * roadFactor
            let estimatedMinutes = max(1, Int(ceil((estimatedMeters / metersPerSecond) / 60.0 + fixedMinutes)))
            return (estimatedMinutes, max(1, Int(estimatedMeters.rounded())))
        }

'''
replace_once(helper_marker, helper_code + helper_marker, "approximate route helpers")

path.write_text(text)
print("Added a conservative map-distance fallback for MapKit direction failures.")
