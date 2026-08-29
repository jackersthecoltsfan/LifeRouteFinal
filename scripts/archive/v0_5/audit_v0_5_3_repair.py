from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

FILES = {
    "content": ROOT / "LifeRoute" / "ContentView.swift",
    "v054_content": ROOT / "LifeRoute" / "V054ContentView.swift",
    "routing": ROOT / "LifeRoute" / "RoutingLocationDomain.swift",
    "clients": ROOT / "LifeRoute" / "ClientViews.swift",
    "v054_clients": ROOT / "LifeRoute" / "V054ClientViews.swift",
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
    if not path.exists():
        return ""
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
v054_content = read("v054_content")
routing = read("routing")
clients = read("clients")
v054_clients = read("v054_clients")
tools_domain = read("tools_domain")
tools_views = read("tools_views")
appearance = read("appearance")
project = read("project")
plist = read("plist")
active_shell = v054_content if "V054ContentView.swift in Sources" in project else content
active_clients = v054_clients if "V054ClientViews.swift in Sources" in project else clients
active_swift = "\n".join([active_shell, routing, active_clients, tools_domain, tools_views, appearance])

# 01 — release identity: the v0.5.3 guarantees remain inherited by v0.5.4.
versions = {version.strip() for version in re.findall(r"MARKETING_VERSION = ([^;]+);", project)}
require(bool(versions) and len(versions) == 1 and versions.issubset({"0.5.3", "0.5.4"}), "01 active shipping targets are on an approved repaired version")

# 02–06 — live-location behavior and lifecycle ownership
require("@Published private(set) var liveLocationEnabled = false" in routing, "02 live location has explicit observable state")
require("locationManager.startUpdatingLocation()" in routing, "03 location uses continuous foreground updates")
require("requestLocation()" not in routing, "04 one-shot requestLocation regression is absent")
require("allowsBackgroundLocationUpdates = false" in routing, "05 background location remains disabled")
require("resumeForegroundLocationIfNeeded()" in active_shell and "if phase == .active" in active_shell, "06 foreground scene resume restores an enabled live-location session")

# 07–10 — address autocomplete core remains native and v0.5.4 expands its reach.
require("final class LifeRouteAddressAutocomplete" in routing, "07 native MapKit autocomplete model exists")
require("MKLocalSearchCompleter" in routing and ".address" in routing and ".pointOfInterest" in routing, "08 autocomplete uses MapKit address/POI completion")
address_field = (ROOT / "LifeRoute" / "V054AddressField.swift").read_text(encoding="utf-8") if (ROOT / "LifeRoute" / "V054AddressField.swift").exists() else content
require("autocomplete.update(query:" in address_field or "homeAutocomplete.update(query:" in content, "09 address fields expose native suggestions")
require("suggestions" in address_field or "AddressSuggestionList" in content, "10 address suggestions are selectable in the UI")

# 11–14 — Generate / Live Day remains time-aware.
today = (ROOT / "LifeRoute" / "V054TodayView.swift").read_text(encoding="utf-8") if (ROOT / "LifeRoute" / "V054TodayView.swift").exists() else content
live_activity = (ROOT / "LifeRoute" / "LiveDayActivityCore.swift").read_text(encoding="utf-8") if (ROOT / "LifeRoute" / "LiveDayActivityCore.swift").exists() else content
require("Generate day" in content or "Generate day + start Live Activity" in today or "Generate + launch selected day" in today, "11 Generate Day action exists")
require("TimelineView(.periodic" in today or "TimelineView(.periodic" in content, "12 Live Day has a live ticking timeline")
require("calendarState.events(on: Date())" in today or "calendarState.events(on: Date())" in content or "calendarState.events(on: selectedDay)" in today, "13 Live Day reads native calendar events for the active day")
require("travelTimeSeconds + 10 * 60" in live_activity or "estimate.travelTimeSeconds + 10 * 60" in content, "14 leave timing uses known route duration plus buffer")

# 15–17 — interaction and client-save regressions
require(".simultaneousGesture(" not in appearance and ".onTapGesture(" not in appearance, "15 shared appearance/button layer does not compete for tap ownership")
require("@State private var isSaving = false" in active_clients and ".disabled(isSaving)" in active_clients and "guard !isSaving else" in active_clients, "16 client save is guarded against duplicate/reentrant taps")
require("JaHe" not in active_swift and 'TextField("Ab", text: $first2)' in active_clients and 'TextField("Cd", text: $last2)' in active_clients, "17 personal/demo client placeholder is absent from active SwiftUI")

# 18–22 — General/no-client visual workflows and isolation
require('static let generalClientCode = "GENERAL"' in tools_domain, "18 General visual library has a stable domain identity")
require("union([Self.generalClientID])" in tools_domain, "19 General visual data survives real-client retention cleanup")
require("visualOwner(for:" in tools_domain and "crossClientReference" in tools_domain, "20 visual ownership and cross-library isolation remain enforced")
require("ClientVisualSupportCore.generalDisplayName" in tools_views and "ClientVisualSupportCenter" in tools_views, "21 Visual Supports UI exposes General with no client required")
require("ClientFirstThenVisualView" in tools_views and "ClientVisualSupportCore.generalClientCode" in tools_views, "22 First/Then shares the General visual-library contract")

# 23–24 — timer audibility. Newer releases retain playback audibility while replacing abrupt high-amplitude waveform endings with a controlled crescendo and release envelope.
require("setCategory(.playback" in tools_domain and ("player.volume = 1" in tools_domain or "player.volume = max(0, min(1, gain))" in tools_domain), "23 timer audio uses playback category with explicit player gain control")
legacy_waveform = (
    ("* 0.60" in tools_domain and "* 0.85" in tools_domain and "max(-0.92, min(0.92, value))" in tools_domain)
    or ("* 0.12" in tools_domain and "* 0.17" in tools_domain)
)
modern_waveform = (
    "startGainForFiveDecibelCrescendo" in tools_domain
    and "signalGain(forRemaining:" in tools_domain
    and "v0.6.3 cosine release reaches silence smoothly" in tools_domain
    and "let release = releaseProgress <= 0 ? 1 : 0.5 * (1 + cos" in tools_domain
)
require(legacy_waveform or modern_waveform, "24 timer waveform meets the inherited audibility contract or the superseding controlled-crescendo/click-free-release contract")

# 25–27 — theme differentiation without touch interception
theme_views = (ROOT / "LifeRoute" / "CinematicThemeViews.swift").read_text(encoding="utf-8") if (ROOT / "LifeRoute" / "CinematicThemeViews.swift").exists() else ""
require("var artworkSymbols: (primary: String, secondary: String)" in appearance, "25 themes retain per-theme identities")
require("allowsHitTesting(false)" in appearance or "allowsHitTesting(false)" in theme_views, "26 theme artwork remains presentation-only")
require("LifeRouteCinematicThemeThumbnail" in theme_views or "ThemeChoiceCard" in content, "27 theme selection uses differentiated visual previews")

# 28–30 — quarantine, permissions, privacy
require("LifeRouteWebView.swift in Sources" not in project and "Web in Resources" not in project, "28 legacy WebView runtime remains quarantined")
require("NSFaceIDUsageDescription" not in plist, "29 stale unlock/Face ID permission copy is removed")
# v0.7.0 reviewed superset: routing persistence may include durable weekly To-Dos,
# but live GPS coordinates and calculated route estimates must remain runtime-only.
require(
    "private func persistRoutingInputs()" in routing
    and "homeAddress: homeAddress" in routing
    and "savedPlaces: savedPlaces" in routing
    and "todos: todos" in routing
    and "saveRoutingState(homeAddress: homeAddress, savedPlaces: savedPlaces, currentLocation:" not in routing
    and "currentLocation" not in (ROOT / "LifeRoute" / "PersistenceCore.swift").read_text(encoding="utf-8")
    and "routeEstimates" not in (ROOT / "LifeRoute" / "PersistenceCore.swift").read_text(encoding="utf-8"),
    "30 routing persistence remains limited to durable routing inputs and reviewed To-Dos, never live coordinates or calculated routes",
)

if errors:
    print("LifeRoute inherited v0.5.3 repair audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute inherited v0.5.3 repair audit passed ({len(checks)} checks across 30 repair angles).")
for check in checks:
    print(f"- OK: {check}")
