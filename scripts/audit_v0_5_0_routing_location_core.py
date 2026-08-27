from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOMAIN = ROOT / "LifeRoute" / "RoutingLocationDomain.swift"
CONTENT = ROOT / "LifeRoute" / "ContentView.swift"
PLIST = ROOT / "LifeRoute" / "Info.plist"
PROJECT = ROOT / "LifeRoute.xcodeproj" / "project.pbxproj"

errors: list[str] = []
checks: list[str] = []


def require(condition: bool, message: str) -> None:
    if condition:
        checks.append(message)
    else:
        errors.append(message)


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception as exc:
        errors.append(f"Could not read {path.relative_to(ROOT)}: {exc}")
        return ""


domain = read(DOMAIN)
content = read(CONTENT)
plist = read(PLIST)
project = read(PROJECT)

for framework in ["CoreLocation", "MapKit", "Combine"]:
    require(f"import {framework}" in domain, f"Routing/location core uses native {framework}")
for forbidden in ["WebKit", "JavaScript", "WKWebView", "MutationObserver", "localStorage", "UserDefaults", "Timer(", "setInterval"]:
    require(forbidden not in domain, f"Routing/location core avoids legacy/browser persistence/timer dependency: {forbidden}")

require("final class RoutingLocationCore: NSObject, ObservableObject, CLLocationManagerDelegate" in domain, "One native object owns location and route state")
require("locationManager.requestWhenInUseAuthorization()" in domain, "Location permission is requested natively")
require("locationManager.startUpdatingLocation()" in domain, "Location can remain live while LifeRoute is in the foreground")
require("locationManager.requestLocation()" not in domain, "Legacy one-shot location request is not the active location contract")
require("allowsBackgroundLocationUpdates = false" in domain, "Live location remains foreground-only")
require("func stopLiveLocation()" in domain, "User can explicitly stop the foreground live-location session")
require("func locationManagerDidChangeAuthorization" in domain, "Authorization lifecycle is handled explicitly")
require("func locationManager(_ manager: CLLocationManager, didUpdateLocations" in domain, "Current location callback is owned explicitly")
require("MKLocalSearch.Request()" in domain, "Destination text resolves through native MapKit search")
require("MKLocalSearchCompleter" in domain, "Address autocomplete uses native MapKit completion")
require("MKDirections.Request()" in domain and "MKDirections(request: request).calculate()" in domain, "Route time/distance uses native MapKit directions")
require("destination.openInMaps" in domain, "Saved destinations can open in Apple Maps")
require("currentLocation" in domain and "homeAddress" in domain, "Current location is primary origin with home fallback")
require("struct LifeRouteSavedPlace: Identifiable, Codable, Hashable" in domain, "Saved place is a plain value model")
require("@Published private(set) var savedPlaces" in domain, "Saved place mutations stay owned by RoutingLocationCore")
require("func addSavedPlace(" in domain and "func removeSavedPlace" in domain, "Saved places have explicit add/remove ownership")
require("guard !cleanName.isEmpty" in domain and "guard !cleanAddress.isEmpty" in domain, "Saved place inputs are validated")

require("NSLocationWhenInUseUsageDescription" in plist, "Location permission usage description exists")
require("@StateObject private var routingState = RoutingLocationCore()" in content, "Root view owns one RoutingLocationCore")
today_call = re.search(r"TodayCoreView\(([^\n]*)\)", content)
require(bool(today_call) and "routingState: routingState" in today_call.group(1), "Today receives route state explicitly")
setup_call = re.search(r"SetupCoreView\(([^\n]*)\)", content)
require(bool(setup_call) and "routingState: routingState" in setup_call.group(1), "Setup receives route state explicitly even as other reviewed dependencies are added")
require(
    "routingState.requestCurrentLocation()" in content
    and "routingState.stopLiveLocation()" in content
    and "DashboardActionButton(" in content,
    "Today exposes semantic start/stop live-location controls",
)
require(
    "onEstimate: { routingState.calculateRoute(to: place" in content,
    "Saved-place route estimate action is wired through the dashboard card",
)
require(
    "onMaps: { routingState.openInAppleMaps(place" in content,
    "Saved-place Apple Maps action is wired through the dashboard card",
)
require("Button(\"Add saved place\")" in content, "Setup exposes semantic saved-place creation")
require("Home and saved places are stored locally in protected LifeRoute app data." in content, "Routing UI states durable routing-input storage truthfully")
require("Current GPS coordinates and route estimates are not persisted." in content, "Routing UI states transient location/route boundary truthfully")
require("@AppStorage" not in content and "UserDefaults" not in content, "Routing UI avoids ad-hoc preference persistence")
require("RoutingLocationDomain.swift in Sources" in project, "Routing/location core is compiled into the active target")
require("LifeRouteWebView.swift in Sources" not in project and "Web in Resources" not in project, "Legacy WebView runtime remains quarantined")

if errors:
    print("LifeRoute v0.5.0 routing/location-core audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute v0.5.0 routing/location-core audit passed ({len(checks)} checks).")
for check in checks:
    print(f"- OK: {check}")
