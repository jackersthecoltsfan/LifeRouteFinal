from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

FILES = {
    "content": ROOT / "LifeRoute" / "ContentView.swift",
    "routing": ROOT / "LifeRoute" / "RoutingLocationDomain.swift",
    "clients": ROOT / "LifeRoute" / "ClientViews.swift",
    "tools_domain": ROOT / "LifeRoute" / "SessionToolsDomain.swift",
    "tools_views": ROOT / "LifeRoute" / "SessionToolsViews.swift",
    "appearance": ROOT / "LifeRoute" / "LifeRouteApp.swift",
    "project": ROOT / "LifeRoute.xcodeproj" / "project.pbxproj",
    "plist": ROOT / "LifeRoute" / "Info.plist",
}

errors: list[str] = []
checks: list[str] = []


def read(name: str) -> str:
    path = FILES[name]
    try:
        return path.read_text(encoding="utf-8")
    except Exception as exc:
        errors.append(f"Could not read {path.relative_to(ROOT)}: {exc}")
        return ""


def require(condition: bool, message: str) -> None:
    if condition:
        checks.append(message)
    else:
        errors.append(message)


content = read("content")
routing = read("routing")
clients = read("clients")
tools_domain = read("tools_domain")
tools_views = read("tools_views")
appearance = read("appearance")
project = read("project")
plist = read("plist")
active_swift = "\n".join([content, routing, clients, tools_domain, tools_views, appearance])

# 01 — release identity
versions = re.findall(r"MARKETING_VERSION = ([^;]+);", project)
require(bool(versions) and set(map(str.strip, versions)) == {"0.5.3"}, "01 version identity is v0.5.3 across active configurations")

# 02–06 — live-location behavior and lifecycle ownership
require("@Published private(set) var liveLocationEnabled = false" in routing, "02 live location has explicit observable state")
require("locationManager.startUpdatingLocation()" in routing, "03 location uses continuous foreground updates")
require("requestLocation()" not in routing, "04 one-shot requestLocation regression is absent")
require("allowsBackgroundLocationUpdates = false" in routing, "05 background location remains disabled")
require("resumeForegroundLocationIfNeeded()" in content and "if phase == .active" in content, "06 foreground scene resume restores an enabled live-location session")

# 07–10 — address autocomplete
require("final class LifeRouteAddressAutocomplete" in routing, "07 native MapKit autocomplete model exists")
require("MKLocalSearchCompleter" in routing and ".address" in routing and ".pointOfInterest" in routing, "08 autocomplete uses MapKit address/POI completion")
require("homeAutocomplete.update(query:" in content and "AddressSuggestionList(suggestions: homeAutocomplete.suggestions)" in content, "09 home address field exposes native suggestions")
require("placeAutocomplete.update(query:" in content and "AddressSuggestionList(suggestions: placeAutocomplete.suggestions)" in content, "10 saved-place address field exposes native suggestions")

# 11–14 — Generate / Live Day
require('Label("Generate day", systemImage: "sparkles")' in content, "11 Generate Day action is restored")
require("private struct LiveDayTimeline" in content and "TimelineView(.periodic" in content, "12 Live Day has a live ticking timeline")
require("calendarState.events(on: Date())" in content, "13 Live Day reads native calendar events for today")
require("estimate.travelTimeSeconds + 10 * 60" in content, "14 Live Day computes leave timing from known route duration plus buffer")

# 15–17 — interaction and client-save regressions
require(".simultaneousGesture(" not in appearance and ".onTapGesture(" not in appearance, "15 shared appearance/button layer does not compete for tap ownership")
require("@State private var isSaving = false" in clients and ".disabled(isSaving)" in clients and "guard !isSaving else" in clients, "16 client save is guarded against duplicate/reentrant taps")
require("JaHe" not in active_swift and 'TextField("Ab", text: $first2)' in clients and 'TextField("Cd", text: $last2)' in clients, "17 personal/demo client placeholder is absent from active SwiftUI")

# 18–22 — General/no-client visual workflows and isolation
require('static let generalClientCode = "GENERAL"' in tools_domain, "18 General visual library has a stable domain identity")
require("union([Self.generalClientID])" in tools_domain, "19 General visual data survives real-client retention cleanup")
require("visualOwner(for:" in tools_domain and "crossClientReference" in tools_domain, "20 visual ownership and cross-library isolation remain enforced")
require("ClientVisualSupportCore.generalDisplayName" in tools_views and "ClientVisualSupportCenter" in tools_views, "21 Visual Supports UI exposes General with no client required")
require("ClientFirstThenVisualView" in tools_views and tools_views.count("ClientVisualSupportCore.generalClientCode") >= 8, "22 First/Then and builders share the General visual-library contract")

# 23–24 — timer audibility
require("setCategory(.playback" in tools_domain and "player.volume = 1" in tools_domain, "23 timer audio uses playback category at full player volume")
require("* 0.12" in tools_domain and "* 0.17" in tools_domain, "24 timer pulse and completion amplitudes are materially stronger than v0.5.2")

# 25–27 — theme differentiation without touch interception
require("var artworkSymbols: (primary: String, secondary: String)" in appearance, "25 themes define per-theme artwork identities")
require("struct LifeRouteThemeArtwork" in appearance and "allowsHitTesting(false)" in appearance, "26 theme artwork is presentation-only and cannot intercept taps")
require("LifeRouteThemeArtwork(theme: theme" in content and "ThemeChoiceCard" in content, "27 theme thumbnails use differentiated artwork instead of category-only motifs")

# 28–30 — quarantine, permissions, privacy
require("LifeRouteWebView.swift in Sources" not in project and "Web in Resources" not in project, "28 legacy WebView runtime remains quarantined")
require("NSFaceIDUsageDescription" not in plist, "29 stale unlock/Face ID permission copy is removed")
require(
    "saveRoutingState(homeAddress: homeAddress, savedPlaces: savedPlaces)" in routing
    and "saveRoutingState(homeAddress: homeAddress, savedPlaces: savedPlaces, currentLocation:" not in routing,
    "30 routing persistence remains limited to home address and saved places, not live coordinates",
)

if errors:
    print("LifeRoute v0.5.3 repair audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute v0.5.3 repair audit passed ({len(checks)} checks across 30 repair angles).")
for check in checks:
    print(f"- OK: {check}")
