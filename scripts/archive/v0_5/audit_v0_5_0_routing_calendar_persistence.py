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

require("schemaVersion: Int = 4" in store and "max(4, input.schemaVersion)" in store, "Native snapshot schema advances deterministically while retaining earlier persistence fields")
require("decodeIfPresent(String.self, forKey: .homeAddress)" in store, "Older snapshots can restore with a missing home address")
require("decodeIfPresent([LifeRouteSavedPlace].self, forKey: .savedPlaces)" in store, "Older snapshots can restore with no saved places")
require("decodeIfPresent([LifeRouteCalendarEvent].self, forKey: .manualCalendarEvents)" in store, "Older snapshots can restore with no manual appointments")
require("decodeIfPresent([LifeRouteCalendarEvent].self, forKey: .providerCalendarEvents)" in store, "Pre-v0.6 snapshots safely restore with no cached provider events")
require("func loadRoutingState() -> RestoredRoutingPersistenceState" in store, "Routing inputs have one persistence read boundary")
require("func saveRoutingState(homeAddress: String, savedPlaces: [LifeRouteSavedPlace])" in store, "Routing inputs have one persistence write boundary")
require("func loadManualCalendarEvents() -> [LifeRouteCalendarEvent]" in store, "Manual appointments have one persistence read boundary")
require("func saveManualCalendarEvents(_ events: [LifeRouteCalendarEvent])" in store, "Manual appointments have one persistence write boundary")
require("func loadProviderCalendarEvents() -> [LifeRouteCalendarEvent]" in store, "Provider calendar snapshots have one persistence read boundary")
require("func saveProviderCalendarEvents(_ events: [LifeRouteCalendarEvent])" in store, "Provider calendar snapshots have one persistence write boundary")
require("sanitizedManualCalendarEvents(events)" in store, "Only sanitized manual LifeRoute appointments are accepted by manual calendar storage")
require("sanitizedProviderCalendarEvents(events)" in store, "Only sanitized read-only provider events are accepted by provider calendar storage")
require("guard event.source == .manual" in store, "Restored manual calendar data is revalidated as manual-only")
require("guard event.source != .manual" in store, "Restored provider calendar data cannot masquerade as manual appointments")
require("providerCalendarEventLimit = 1_500" in store, "Cached provider calendars have a bounded local snapshot size")
require("CalendarProviderCore" not in store and "providerState" not in store, "Provider connection/runtime objects remain excluded from persistence")
require("currentLocation" not in store and "routeEstimates" not in store, "Live GPS coordinates and calculated routes are excluded from persistence")
require("FileProtectionType.completeUntilFirstUserAuthentication" in store and "data.write(to: fileURL, options: [.atomic])" in store, "v0.6 data retains protected atomic storage")

require("LifeRoutePersistenceStore.shared.loadManualCalendarEvents()" in calendar, "Calendar restores manual appointments at native-state initialization")
require("LifeRoutePersistenceStore.shared.loadProviderCalendarEvents()" in calendar, "Calendar restores the last read-only provider snapshot at initialization")
require("saveManualCalendarEvents(events.filter { $0.source == .manual })" in calendar, "Calendar persists only its manual event subset to manual storage")
require("saveProviderCalendarEvents(events.filter { $0.source != .manual })" in calendar, "Calendar persists only its non-manual provider subset to provider storage")
require(calendar.count("persistManualEvents()") == 3, "Only manual add/remove paths invoke manual calendar persistence")
require(calendar.count("persistProviderEvents()") == 3, "Only provider replace/remove paths and helper definition own provider snapshot persistence")
require("replaceProviderEvents" in calendar and "removeProviderEvents" in calendar, "Provider refresh/removal remains separately owned")
require("UserDefaults" not in calendar and "@AppStorage" not in calendar, "Calendar domain does not bypass the protected persistence owner")

require("LifeRoutePersistenceStore.shared.loadRoutingState()" in routing, "Routing restores home/saved places at initialization")
require("func persistRoutingInputs()" in routing, "Routing has one persistence mutation helper")
require(routing.count("persistRoutingInputs()") == 4, "Home save, place add, and place remove persist through the shared routing helper")
require("currentLocation = location" in routing, "Live GPS location remains runtime-owned")
require("routeEstimates[place.id]" in routing, "Route estimates remain runtime-owned")

require("Appointment saved locally on this iPhone." in content, "Manual appointment UI states durable local storage")
require("Home and saved places are stored locally in protected LifeRoute app data." in content, "Routing UI states durable local storage")
require("Current GPS coordinates and route estimates are not persisted." in content, "Routing UI states transient location boundary")
for stale in [
    "Appointment added for this app session.",
    "Home and saved places are session-only until the persistence checkpoint.",
    "Saved place added for this app session.",
    "Home address saved for this app session.",
]:
    require(stale not in content, f"Superseded session-only copy is removed: {stale}")

require("PersistenceCore.swift in Sources" in project, "Shared native persistence remains compiled into the active target")
require("LifeRouteWebView.swift in Sources" not in project and "Web in Resources" not in project, "Legacy WebView runtime remains quarantined")
require("audit_v0_5_0_routing_calendar_persistence.py" in prepare, "Preparation runs the persistence audit")
require("Audit checkpoint 04B routing calendar persistence" in workflow, "iOS CI exposes the persistence audit")

if errors:
    print("LifeRoute routing/calendar persistence audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute routing/calendar persistence audit passed ({len(checks)} checks).")
for check in checks:
    print(f"- OK: {check}")
