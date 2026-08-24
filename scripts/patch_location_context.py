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
    "        private let eventStore = EKEventStore()\n        private let isoFormatter = ISO8601DateFormatter()\n        private let locationManager = CLLocationManager()\n        private var requestLocationAfterAuthorization = false\n",
    "location manager storage",
)

replace_once(
    '            case "requestNativeStatus":\n                emitNativeStatus()\n',
    '            case "requestNativeStatus":\n                emitNativeStatus()\n            case "requestCurrentLocation":\n                requestCurrentLocation()\n',
    "current location bridge action",
)

location_code = r'''
        // MARK: - Current location

        private func requestCurrentLocation() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters

            switch locationManager.authorizationStatus {
            case .notDetermined:
                requestLocationAfterAuthorization = true
                emit(type: "currentLocationStatus", payload: ["status": "requesting"])
                locationManager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                requestLocationAfterAuthorization = false
                emit(type: "currentLocationStatus", payload: ["status": "locating"])
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

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                emit(type: "currentLocationStatus", payload: ["status": "authorized"])
                if requestLocationAfterAuthorization {
                    requestLocationAfterAuthorization = false
                    manager.requestLocation()
                }
            case .denied:
                requestLocationAfterAuthorization = false
                emit(type: "currentLocationStatus", payload: ["status": "denied"])
            case .restricted:
                requestLocationAfterAuthorization = false
                emit(type: "currentLocationStatus", payload: ["status": "restricted"])
            case .notDetermined:
                emit(type: "currentLocationStatus", payload: ["status": "not-determined"])
            @unknown default:
                emit(type: "currentLocationStatus", payload: ["status": "unknown"])
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            emit(type: "currentLocation", payload: [
                "status": "ready",
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "accuracyMeters": max(0, location.horizontalAccuracy),
                "timestamp": isoFormatter.string(from: location.timestamp)
            ])
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
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
print("Current-location bridge enabled.")
