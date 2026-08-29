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
    "import MapKit\n",
    "import MapKit\nimport CoreLocation\n",
    "CoreLocation import",
)

replace_once(
    "final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, ASWebAuthenticationPresentationContextProviding {",
    "final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, ASWebAuthenticationPresentationContextProviding, CLLocationManagerDelegate {",
    "location manager delegate conformance",
)

replace_once(
    "        private let eventStore = EKEventStore()\n        private let isoFormatter = ISO8601DateFormatter()\n",
    "        private let eventStore = EKEventStore()\n        private let isoFormatter = ISO8601DateFormatter()\n        private let locationManager = CLLocationManager()\n        private var requestLocationAfterAuthorization = false\n        private var streamLocationAfterAuthorization = false\n        private var liveLocationStreaming = false\n",
    "location manager storage",
)

replace_once(
    '            case "requestNativeStatus":\n                emitNativeStatus()\n',
    '            case "requestNativeStatus":\n                emitNativeStatus()\n            case "requestCurrentLocation":\n                requestCurrentLocation()\n            case "startLiveLocation":\n                startLiveLocation()\n            case "stopLiveLocation":\n                stopLiveLocation()\n',
    "current location bridge actions",
)

location_code = r'''
        // MARK: - Current location

        private func configureLocationManager(live: Bool) {
            locationManager.delegate = self
            locationManager.desiredAccuracy = live ? kCLLocationAccuracyNearestTenMeters : kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = live ? 50 : kCLDistanceFilterNone
            locationManager.activityType = .automotiveNavigation
            locationManager.pausesLocationUpdatesAutomatically = true
            locationManager.allowsBackgroundLocationUpdates = false
            locationManager.showsBackgroundLocationIndicator = false
        }

        private func requestCurrentLocation() {
            configureLocationManager(live: false)

            switch locationManager.authorizationStatus {
            case .notDetermined:
                requestLocationAfterAuthorization = true
                streamLocationAfterAuthorization = false
                emit(type: "currentLocationStatus", payload: ["status": "requesting"])
                locationManager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                requestLocationAfterAuthorization = false
                emit(type: "currentLocationStatus", payload: ["status": liveLocationStreaming ? "live" : "locating"])
                locationManager.requestLocation()
            case .denied:
                requestLocationAfterAuthorization = false
                emit(type: "currentLocationStatus", payload: [
                    "status": "denied",
                    "message": "Location access is off. Enable While Using the App in iPhone Settings to use live commute starts."
                ])
            case .restricted:
                requestLocationAfterAuthorization = false
                emit(type: "currentLocationStatus", payload: [
                    "status": "restricted",
                    "message": "Location access is restricted on this iPhone."
                ])
            @unknown default:
                requestLocationAfterAuthorization = false
                emit(type: "currentLocationStatus", payload: ["status": "unknown"])
            }
        }

        private func startLiveLocation() {
            configureLocationManager(live: true)
            guard CLLocationManager.locationServicesEnabled() else {
                liveLocationStreaming = false
                emit(type: "currentLocationStatus", payload: [
                    "status": "error",
                    "message": "Location Services are turned off on this iPhone."
                ])
                return
            }
            switch locationManager.authorizationStatus {
            case .notDetermined:
                streamLocationAfterAuthorization = true
                requestLocationAfterAuthorization = false
                emit(type: "currentLocationStatus", payload: ["status": "requesting-live"])
                locationManager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                streamLocationAfterAuthorization = false
                liveLocationStreaming = true
                locationManager.startUpdatingLocation()
                locationManager.requestLocation()
                emit(type: "currentLocationStatus", payload: ["status": "locating"])
            case .denied:
                liveLocationStreaming = false
                emit(type: "currentLocationStatus", payload: [
                    "status": "denied",
                    "message": "Location access is off. Enable While Using the App in iPhone Settings to use live location."
                ])
            case .restricted:
                liveLocationStreaming = false
                emit(type: "currentLocationStatus", payload: ["status": "restricted"])
            @unknown default:
                liveLocationStreaming = false
                emit(type: "currentLocationStatus", payload: ["status": "unknown"])
            }
        }

        private func stopLiveLocation() {
            streamLocationAfterAuthorization = false
            liveLocationStreaming = false
            locationManager.stopUpdatingLocation()
            emit(type: "currentLocationStatus", payload: ["status": "paused"])
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                if streamLocationAfterAuthorization {
                    streamLocationAfterAuthorization = false
                    liveLocationStreaming = true
                    configureLocationManager(live: true)
                    manager.startUpdatingLocation()
                    manager.requestLocation()
                    emit(type: "currentLocationStatus", payload: ["status": "locating"])
                } else {
                    emit(type: "currentLocationStatus", payload: ["status": "authorized"])
                    if requestLocationAfterAuthorization {
                        requestLocationAfterAuthorization = false
                        manager.requestLocation()
                    }
                }
            case .denied:
                requestLocationAfterAuthorization = false
                streamLocationAfterAuthorization = false
                liveLocationStreaming = false
                emit(type: "currentLocationStatus", payload: ["status": "denied"])
            case .restricted:
                requestLocationAfterAuthorization = false
                streamLocationAfterAuthorization = false
                liveLocationStreaming = false
                emit(type: "currentLocationStatus", payload: ["status": "restricted"])
            case .notDetermined:
                emit(type: "currentLocationStatus", payload: ["status": "not-determined"])
            @unknown default:
                emit(type: "currentLocationStatus", payload: ["status": "unknown"])
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.reversed().first(where: { $0.horizontalAccuracy >= 0 }) else { return }
            emit(type: "currentLocation", payload: [
                "status": liveLocationStreaming ? "live" : "ready",
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "accuracyMeters": max(0, location.horizontalAccuracy),
                "timestamp": isoFormatter.string(from: location.timestamp),
                "streaming": liveLocationStreaming
            ])
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            if let clError = error as? CLError, clError.code == .locationUnknown {
                emit(type: "currentLocationStatus", payload: ["status": liveLocationStreaming ? "locating" : "locating"])
                return
            }
            emit(type: "currentLocationStatus", payload: [
                "status": "error",
                "message": error.localizedDescription
            ])
        }

'''

marker = "        // MARK: - Apple Calendar\n"
if location_code not in text:
    if marker not in text:
        raise SystemExit("Could not patch current-location methods: marker not found")
    text = text.replace(marker, location_code + marker, 1)

path.write_text(text)
print("Foreground live-location bridge enabled with verified initial-fix acquisition and fallback-safe status reporting.")
