from pathlib import Path

checks=[]
def require(v,label): checks.append((bool(v),label))

def text(path): return Path(path).read_text()

swift=text("LifeRoute/LifeRouteWebView.swift")
info=text("LifeRoute/Info.plist")
live=text("LifeRoute/Web/live-location-v2.js")
home=text("LifeRoute/Web/home-location-v3.js")
smart=text("LifeRoute/Web/smart-context.js")
boundary=text("LifeRoute/Web/boundary-stop-planner.js")
search=text("LifeRoute/Web/stop-place-search-v4.js")

# Native authorization + lifecycle.
for marker in ["CLLocationManagerDelegate","requestWhenInUseAuthorization","startUpdatingLocation()","stopUpdatingLocation()","didUpdateLocations","didFailWithError"]:
    require(marker in swift, f"native location bridge contains {marker}")
require("kCLLocationAccuracyNearestTenMeters" in swift, "live native location requests navigation-grade accuracy")
require("distanceFilter = live ? 50" in swift, "native live updates are movement-filtered")
require("pausesLocationUpdatesAutomatically = true" in swift, "CoreLocation may pause unnecessary updates")
require("NSLocationWhenInUseUsageDescription" in info, "When-In-Use location purpose string exists")
require("UIBackgroundModes" not in info or "location" not in info, "app does not silently request persistent background GPS")

# Browser lifecycle.
for marker in ["navigator.geolocation.watchPosition","navigator.geolocation.clearWatch","visibilitychange","pagehide","pageshow"]:
    require(marker in live, f"web live location lifecycle contains {marker}")
require('enableHighAccuracy: true' in live, "web requests high-accuracy foreground position")
require('maximumAge: 12000' in live, "web watcher limits accepted cached positions")
require('timeout: 15000' in live, "web location acquisition has timeout")
require('webWatch != null' in live, "web prevents duplicate location watchers")

# One UI action owns one live-location request path. Lifecycle/state modules do
# not also attach competing #locationButton listeners.
require('document.addEventListener("click"' not in live,
        "live-location lifecycle does not own Setup button clicks")
require('document.addEventListener("click"' not in home,
        "Home state layer does not own competing Setup button clicks")
require('window.LifeRouteHomeLocationV3?.startLiveLocation?.()' in smart,
        "Setup live-location button delegates through the Home/location facade")
require('postNative({ action: "startLiveLocation" })' in smart,
        "Setup has a native streaming fallback")
require('postNative({ action: "requestCurrentLocation" })' not in smart,
        "Setup no longer duplicates one-shot location requests")
require('Location permission is user-initiated from the Home & location control.' in smart,
        "first location permission request is user-initiated")
require('setTimeout(() => {\n      if (!nativeState.currentLocation' not in smart,
        "Setup no longer auto-prompts location on startup")

# Freshness and downstream consumers.
require("LIVE_LOCATION_MAX_AGE_MS = 120000" in smart, "smart routing rejects coordinates older than two minutes")
require("freshLiveLocation()" in smart, "smart-context route origin uses freshness helper")
require("locationDistanceMeters" in smart and ">= 35" in smart, "route refresh is movement-gated")
require("30000" in smart and "liveRouteRefreshTimer" in smart, "route refresh is time-gated and debounced")
require("observer.observe(document.body" not in smart, "smart-context no longer watches entire DOM")
require("freshLiveLocation" in boundary and "age <= 120000" in boundary, "boundary stop planner rejects stale location")
require("freshLiveLocation" in search and "age <= 120000" in search, "stop search rejects stale location")

# Location state must carry the values route calculations need.
for marker in ["latitude", "longitude", "accuracyMeters", "timestamp", "streaming"]:
    require(marker in swift, f"native currentLocation event carries {marker}")
require("locationUpdatedAt = Date.now()" in live, "browser/native wrapper records freshness timestamp")
require("locationAccuracyMeters" in live, "location accuracy is retained for diagnostics")

failed=[label for ok,label in checks if not ok]
print(f"LifeRoute deep live-location audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed: print("FAIL:",label)
    raise SystemExit(1)
print("Foreground authorization, single-request UI ownership, streaming, freshness, stale-coordinate rejection, route refresh pressure, and cleanup passed.")
