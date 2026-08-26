from pathlib import Path

path = Path("LifeRoute/LifeRouteWebView.swift")
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Live-location reliability patch failed: {label} marker not found")
    text = text.replace(old, new, 1)


replace_once(
    """            locationManager.activityType = .automotiveNavigation
            locationManager.pausesLocationUpdatesAutomatically = true
""",
    """            locationManager.activityType = .automotiveNavigation
            locationManager.pausesLocationUpdatesAutomatically = true
            locationManager.allowsBackgroundLocationUpdates = false
            locationManager.showsBackgroundLocationIndicator = false
""",
    "foreground-only manager configuration",
)

replace_once(
    """        private func startLiveLocation() {
            configureLocationManager(live: true)
            switch locationManager.authorizationStatus {
""",
    """        private func startLiveLocation() {
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
""",
    "location-services availability guard",
)

# A native start should not claim a usable live fix until coordinates arrive.
text = text.replace(
    """                liveLocationStreaming = true
                locationManager.startUpdatingLocation()
                emit(type: "currentLocationStatus", payload: ["status": "live"])
""",
    """                liveLocationStreaming = true
                locationManager.startUpdatingLocation()
                locationManager.requestLocation()
                emit(type: "currentLocationStatus", payload: ["status": "locating"])
""",
)
text = text.replace(
    """                    liveLocationStreaming = true
                    configureLocationManager(live: true)
                    manager.startUpdatingLocation()
                    emit(type: "currentLocationStatus", payload: ["status": "live"])
""",
    """                    liveLocationStreaming = true
                    configureLocationManager(live: true)
                    manager.startUpdatingLocation()
                    manager.requestLocation()
                    emit(type: "currentLocationStatus", payload: ["status": "locating"])
""",
)

replace_once(
    """        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            emit(type: "currentLocation", payload: [
""",
    """        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.reversed().first(where: { $0.horizontalAccuracy >= 0 }) else { return }
            emit(type: "currentLocation", payload: [
""",
    "valid location fix selection",
)

for marker in [
    "CLLocationManager.locationServicesEnabled()",
    "allowsBackgroundLocationUpdates = false",
    "showsBackgroundLocationIndicator = false",
    "locationManager.requestLocation()",
    "manager.requestLocation()",
    'payload: ["status": "locating"]',
    "locations.reversed().first(where: { $0.horizontalAccuracy >= 0 })",
]:
    if marker not in text:
        raise SystemExit(f"Live-location reliability verification missing {marker}")

path.write_text(text)
print("Native live-location reliability upgraded: service guard, initial fix nudge, valid-fix filtering, and foreground-only configuration.")
