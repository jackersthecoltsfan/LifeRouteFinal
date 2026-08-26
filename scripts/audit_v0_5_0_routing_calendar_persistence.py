from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STORE = ROOT / "LifeRoute" / "PersistenceCore.swift"
CALENDAR = ROOT / "LifeRoute" / "CalendarDomain.swift"
ROUTING = ROOT / "LifeRoute" / "RoutingLocationDomain.swift"
CONTENT = ROOT / "LifeRoute" / "ContentView.swift"
PREPARE = ROOT / "scripts" / "prepare_build.sh"
WORKFLOW = ROOT / ".github" / "workflows" / "ios-ci.yml"
PROJECT = ROOT / "LifeRoute.xcodeproj" / "project.pbxproj"

errors: list[str] = []
checks: list[str] = []


def require(condition: bool, message: str) -> None:
    (checks if condition else errors).append(message)


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception as exc:
        errors.append(f"Could not read {path.relative_to(ROOT)}: {exc}")
        return ""


store = read(STORE)
calendar = read(CALENDAR)
routing = read(ROUTING)
content = read(CONTENT)
prepare = read(PREPARE)
workflow = read(WORKFLOW)
project = read(PROJECT)

require("schemaVersion: Int = 2" in store and "max(2, input.schemaVersion)" in store, "04B advances the native snapshot schema deterministically")
require("decodeIfPresent(String.self, forKey: .homeAddress)" in store, "Older snapshots can restore with a missing home address")
require("decodeIfPresent([LifeRouteSavedPlace].self, forKey: .savedPlaces)" in store, "Older snapshots can restore with no saved places")
require("decodeIfPresent([LifeRouteCalendarEvent].self, forKey: .manualCalendarEvents)" in store, "Older snapshots can restore with no manual appointments")
require("func loadRoutingState() -> RestoredRoutingPersistenceState" in store, "Routing inputs have one persistence read boundary")
require("func saveRoutingState(homeAddress: String, savedPlaces: [LifeRouteSavedPlace])" in store, "Routing inputs have one persistence write boundary")
require("func loadManualCalendarEvents() -> [LifeRouteCalendarEvent]" in store, "Manual appointments have one persistence read boundary")
require("func saveManualCalendarEvents(_ events: [LifeRouteCalendarEvent])" in store, "Manual appointments have one persistence write boundary")
require("events.filter { $0.source == .manual }" in store, "Only manual LifeRoute appointments are accepted by persistent calendar storage")
require("guard event.source == .manual" in store, "Restored calendar data is revalidated as manual-only")
require("CalendarProviderCore" not in store and "providerState" not in store, "Provider connection/cache objects are excluded from persistence")
require("currentLocation" not in store and "routeEstimates" not in store, "Live GPS coordinates and calculated routes are excluded from persistence")
require("FileProtectionType.completeUntilFirstUserAuthentication" in store and "data.write(to: fileURL, options: [.atomic])" in store, "04B data retains protected atomic storage")

require("LifeRoutePersistenceStore.shared.loadManualCalendarEvents()" in calendar, "Calendar restores manual appointments at native-state initialization")
require("saveManualCalendarEvents(events.filter { $0.source == .manual })" in calendar, "Calendar persists only its manual event subset")
require(calendar.count("persistManualEvents()") == 3, "Only manual add/remove paths invoke calendar persistence")
require("replaceProviderEvents" in calendar and "removeProviderEvents" in calendar, "Provider refresh/removal remains separately owned")

require("LifeRoutePersistenceStore.shared.loadRoutingState()" in routing, "Routing restores home/saved places at initialization")
require("func persistRoutingInputs()" in routing, "Routing has one persistence mutation helper")
require(routing.count("persistRoutingInputs()") == 4, "Home save, place add, and place remove persist through the shared routing helper")
require("currentLocation = location" in routing, "Live GPS location remains runtime-owned")
require("routeEstimates[place.id]" in routing, "Route estimates remain runtime-owned")

require("Appointment saved locally on this iPhone." in content, "Manual appointment UI states durable local storage")
require("Home and saved places are stored locally in protected LifeRoute app data." in content, "Routing UI states durable local storage")
require("Current GPS coordinates and route estimates are not persisted." in content, "Routing UI states transient location boundary")
require("Apple and Google events remain provider-refreshed data" in content, "Calendar UI states provider-cache exclusion")
for stale in [
    "Appointment added for this app session.",
    "Home and saved places are session-only until the persistence checkpoint.",
    "Saved place added for this app session.",
    "Home address saved for this app session.",
]:
    require(stale not in content, f"Superseded session-only copy is removed: {stale}")

require("PersistenceCore.swift in Sources" in project, "Shared native persistence remains compiled into the active target")
require("LifeRouteWebView.swift in Sources" not in project and "Web in Resources" not in project, "Legacy WebView runtime remains quarantined")
require("audit_v0_5_0_routing_calendar_persistence.py" in prepare, "Preparation runs the 04B persistence audit")
require("Audit checkpoint 04B routing calendar persistence" in workflow, "iOS CI exposes the 04B persistence audit")

if errors:
    print("LifeRoute v0.5.0 routing/calendar persistence audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute v0.5.0 routing/calendar persistence audit passed ({len(checks)} checks).")
for check in checks:
    print(f"- OK: {check}")
