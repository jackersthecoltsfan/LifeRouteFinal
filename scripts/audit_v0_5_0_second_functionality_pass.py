from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def path(*parts: str) -> Path:
    return ROOT.joinpath(*parts)


FILES = {
    "app": path("LifeRoute", "LifeRouteApp.swift"),
    "navigation": path("LifeRoute", "AppNavigation.swift"),
    "content": path("LifeRoute", "ContentView.swift"),
    "calendar": path("LifeRoute", "CalendarDomain.swift"),
    "providers": path("LifeRoute", "CalendarProviderCore.swift"),
    "routing": path("LifeRoute", "RoutingLocationDomain.swift"),
    "clients": path("LifeRoute", "ClientProfileDomain.swift"),
    "client_views": path("LifeRoute", "ClientViews.swift"),
    "tools": path("LifeRoute", "SessionToolsDomain.swift"),
    "tool_views": path("LifeRoute", "SessionToolsViews.swift"),
    "persistence": path("LifeRoute", "PersistenceCore.swift"),
    "migration": path("LifeRoute", "LegacyMigrationCore.swift"),
    "plist": path("LifeRoute", "Info.plist"),
    "project": path("LifeRoute.xcodeproj", "project.pbxproj"),
    "prepare": path("scripts", "prepare_build.sh"),
    "workflow": path(".github", "workflows", "ios-ci.yml"),
}

errors: list[str] = []
checks: list[str] = []


def require(condition: bool, message: str) -> None:
    (checks if condition else errors).append(message)


def read(file_path: Path) -> str:
    try:
        return file_path.read_text(encoding="utf-8")
    except Exception as exc:
        errors.append(f"Could not read {file_path.relative_to(ROOT)}: {exc}")
        return ""


source = {name: read(file_path) for name, file_path in FILES.items()}

# Launch, interaction shell, and navigation journey.
require("WindowGroup" in source["app"] and "ContentView()" in source["app"], "The app launches directly into the native functional root")
require(source["content"].count("TabView(selection: $router.selectedSection)") == 1, "One native TabView owns top-level selection")
require(source["content"].count("NavigationStack(path: $router.") == 5, "All five top-level sections retain router-owned navigation stacks")
for section_name in ["today", "schedule", "tools", "resources", "setup"]:
    require(f"case {section_name}" in source["navigation"], f"Top-level section remains available: {section_name}")
    require(f".tag(AppSection.{section_name})" in source["content"], f"Top-level tab is wired: {section_name}")
require("func open(_ route: AppRoute, in section: AppSection)" in source["navigation"], "Cross-tab contextual navigation retains one owner")
require("func resetPath(for section: AppSection)" in source["navigation"], "Native navigation paths remain deterministically resettable")
require("Button(\"Close\") { dismiss() }" in source["content"], "Native detail routes retain semantic back/close behavior")

# Today + Setup routing journey: explicit location, durable home/saved places,
# route estimate, Apple Maps handoff, and transient runtime-only outputs.
for marker, label in [
    ("routingState.requestCurrentLocation()", "explicit current-location request"),
    ("routingState.calculateRoute(to: place, mode: routeMode)", "saved-place route estimate"),
    ("routingState.openInAppleMaps(place, mode: routeMode)", "Apple Maps handoff"),
    ("routingState.setHomeAddress(homeDraft)", "home-address save"),
    ("routingState.addSavedPlace(", "saved-place creation"),
    ("routingState.removeSavedPlace(id: place.id)", "saved-place removal"),
]:
    require(marker in source["content"], f"Routing UI retains {label}")
require("CLLocationManagerDelegate" in source["routing"] and "requestLocation()" in source["routing"], "Location remains native and one-shot")
require("MKLocalSearch" in source["routing"] and "MKDirections" in source["routing"], "Search and route calculation remain native MapKit flows")
require("if let currentLocation" in source["routing"] and "if !homeAddress.isEmpty" in source["routing"], "Route origin retains current-location then home fallback")
require("saveRoutingState(homeAddress: homeAddress, savedPlaces: savedPlaces)" in source["routing"], "Home and saved-place mutations persist together")
require("currentLocation" not in source["persistence"] and "routeEstimates" not in source["persistence"], "GPS coordinates and calculated routes remain transient")

# Calendar journey: manual CRUD, range navigation/presentation, and explicit
# read-only provider refreshes whose caches remain separate from persistence.
for calendar_range in ["case day", "case week", "case month"]:
    require(calendar_range in source["calendar"], f"Calendar range remains implemented: {calendar_range.removeprefix('case ')}")
require("calendarState.addManualEvent(" in source["content"], "Manual appointment form writes through CalendarCoreState")
require("calendarState.removeEvent(id: eventID)" in source["content"] and "if event.source == .manual" in source["content"], "Manual appointment deletion remains wired and provider events stay read-only")
require(".accessibilityLabel(\"Delete \\(event.title)\")" in source["content"], "Manual appointment deletion remains accessible")
require("func presentation(for range: LifeRouteCalendarRange)" in source["calendar"], "Day/Week/Month rendering shares the indexed presentation boundary")
require("calendarState.shiftSelection(selectedRange, by: -1)" in source["content"] and "calendarState.shiftSelection(selectedRange, by: 1)" in source["content"], "Calendar period navigation works in both directions")
require("calendarState.selectToday()" in source["content"], "Calendar can return to today")
require("providerState.connectOrRefreshApple { events in" in source["content"] and "source: .apple" in source["content"], "Apple Calendar refresh publishes normalized Apple events")
require("providerState.connectOrRefreshGoogle { events in" in source["content"] and "source: .google" in source["content"], "Google Calendar refresh publishes normalized Google events")
require("providerState.disconnectGoogle()" in source["content"] and "removeProviderEvents(source: .google)" in source["content"], "Google disconnect clears only its runtime event cache")
require("https://www.googleapis.com/auth/calendar.readonly" in source["providers"], "Google Calendar access remains read-only")
require("saveManualCalendarEvents(events.filter { $0.source == .manual })" in source["calendar"], "Only manual appointments cross the calendar persistence boundary")

# Client journey: add/edit/remove, ABA privacy code, full reviewed session
# context, and durable UUID ownership across editable display codes.
require("ClientProfilesView(clientState: clientState)" in source["content"], "Setup opens native client management")
require("clientState.saveProfile(" in source["client_views"], "Client editor retains add/edit save wiring")
require("clientState.removeClient(id: profile.id)" in source["client_views"], "Client removal remains wired")
require("let code = first + last" in source["clients"] and "first.count == 2" in source["clients"], "ABA client identity remains four normalized initials")
for field in [
    "preferredActivities", "currentTargets", "behaviorsOfConcern", "communicationNotes",
    "promptingNotes", "caregiverNotes", "clinicalNotes", "address",
]:
    require(field in source["clients"] and field in source["client_views"], f"Client workflow retains reviewed field: {field}")
require("LifeRoutePersistenceStore.shared.saveClients(clients)" in source["clients"], "Client add/edit/remove mutations remain durable")

# Session Tools journey: absolute-deadline timer, ephemeral quick notes,
# client-scoped visual supports, First/Then, and deterministic plan organizer.
for route in ["visualTimer", "quickNotes", "firstThen", "sessionPlan"]:
    require(f"case {route}" in source["tools"] and f"SessionToolRoute.{route}" in source["tool_views"], f"Session Tool route remains available: {route}")
require("deadline = now.addingTimeInterval(seconds)" in source["tools"] and "remainingSeconds(at:" in source["tools"], "Visual Timer retains absolute-deadline behavior")
for action in ["timer.start", "timer.pause", "timer.resume", "timer.addMinute", "timer.reset"]:
    require(action in source["tool_views"], f"Visual Timer control remains wired: {action}")
require("toolsState.addNote(" in source["tool_views"] and "toolsState.removeNote(id: note.id)" in source["tool_views"], "Quick Session Notes retain add/remove behavior")
require("func buildPlan(" in source["tools"] and "toolsState.buildPlan(" in source["tool_views"], "Session Plan Organizer remains deterministic and wired")
require("ClientVisualSupportCenter" in source["tool_views"], "Client visual-support hub remains reachable")
for operation, label in [
    ("visualState.addIcon", "icon creation"),
    ("visualState.saveChoiceBoard", "Choice Board creation"),
    ("ClientFirstThenVisualView", "First/Then"),
    ("visualState.saveSchedule", "Visual Schedule creation"),
]:
    require(operation in source["tool_views"], f"Client visual workflow retains {label}")
require("clientID: UUID" in source["tools"] and "crossClientReference" in source["tools"], "Visual ownership remains durable and same-client constrained")
require("visualState.retainClients(clientState.clients)" in source["tool_views"] and ".onReceive(clientState.$clients)" in source["tool_views"], "Client edits/deletes reconcile the active visual library")

# Persistence and migration journey: protected versioned native data, ordered
# atomic writes, corruption recovery, and reviewed legacy inputs only.
for marker, label in [
    ("schemaVersion", "versioned snapshot"),
    ("FileProtectionType.completeUntilFirstUserAuthentication", "sensitive-data protection"),
    ("options: [.atomic]", "atomic replacement"),
    ("corrupt-", "corrupt-state preservation"),
    ("SnapshotWriter", "serial off-main writer"),
    ("await previousTask?.value", "ordered writes"),
]:
    require(marker in source["persistence"], f"Native persistence retains {label}")
for reviewed in ["clients", "manualCalendarEvents", "places", "homeAddress"]:
    require(reviewed in source["migration"], f"Legacy mapper retains reviewed boundary: {reviewed}")
for forbidden in ["liferoute_visual_tools_v2", "googleAccessToken", "WKWebsiteDataStore", "localStorage"]:
    require(forbidden not in source["migration"], f"Legacy mapper excludes quarantined input: {forbidden}")

# Performance/stability regression gates from the immediately preceding passes.
require("private actor SnapshotWriter" in source["persistence"], "Snapshot encoding and I/O remain off the interaction owner")
require("iconsByClientID" in source["tools"] and "eventIndicesByDay" in source["calendar"], "Visual and calendar derived lookups remain indexed")
require("CGImageSourceCreateThumbnailAtIndex" in source["tool_views"] and "UIImage(data:" not in source["tool_views"], "Visual thumbnails remain downsampled outside SwiftUI body evaluation")
require("private var googleRefreshTask: Task<Void, Never>?" in source["providers"] and "private var routeTasks: [UUID: Task<Void, Never>]" in source["routing"], "Provider and routing async work retain explicit owners")
require("Task {" not in source["content"], "Root interactions create no fire-and-forget tasks")
require("if phase == .background" in source["content"] and "routingState.cancelPendingOperations()" in source["content"], "Background routing cancellation remains lifecycle-bounded")
require("providerState.cancelPendingOperations()" not in source["content"], "Transient inactive phases cannot abort provider permission/authentication")

# Build/release isolation and accumulated validation order.
active_files = [
    "LifeRouteApp.swift", "AppNavigation.swift", "CalendarDomain.swift", "CalendarProviderCore.swift",
    "RoutingLocationDomain.swift", "ClientProfileDomain.swift", "ClientViews.swift",
    "SessionToolsDomain.swift", "SessionToolsViews.swift", "PersistenceCore.swift",
    "LegacyMigrationCore.swift", "ContentView.swift",
]
for file_name in active_files:
    require(f"{file_name} in Sources" in source["project"], f"Active native target compiles {file_name}")
require("LifeRouteWebView.swift in Sources" not in source["project"] and "Web in Resources" not in source["project"], "Legacy WebView and JavaScript runtime remain quarantined")
approved_versions = [version for version in ("0.5.0", "0.5.1") if f"MARKETING_VERSION = {version};" in source["project"]]
require(
    len(approved_versions) == 1 and source["project"].count(f"MARKETING_VERSION = {approved_versions[0]};") >= 2,
    "Debug and Release shipping configurations use one approved v0.5 marketing version (0.5.0 or 0.5.1)",
)

accumulated_audits = [
    "audit_v0_5_0_functional_shell.py",
    "audit_v0_5_0_core_navigation.py",
    "audit_v0_5_0_calendar_core.py",
    "audit_v0_5_0_routing_location_core.py",
    "audit_v0_5_0_clients_core.py",
    "audit_v0_5_0_session_tools_core.py",
    "audit_v0_5_0_calendar_providers.py",
    "audit_v0_5_0_client_visual_supports.py",
    "audit_v0_5_0_client_visual_persistence.py",
    "audit_v0_5_0_routing_calendar_persistence.py",
    "audit_v0_5_0_legacy_migration.py",
    "audit_v0_5_0_performance_architecture.py",
    "audit_v0_5_0_stability_architecture.py",
    "audit_v0_5_0_second_functionality_pass.py",
]
last_position = -1
for audit in accumulated_audits:
    position = source["prepare"].find(f"python3 scripts/{audit}")
    require(position > last_position, f"Preparation executes accumulated gate in order: {audit}")
    if position >= 0:
        last_position = position
require("Audit checkpoint 07 second functionality pass" in source["workflow"], "iOS CI exposes Checkpoint 07 before Simulator compilation")

active_runtime = "\n".join(source[name] for name in [
    "app", "navigation", "content", "calendar", "providers", "routing", "clients",
    "client_views", "tools", "tool_views", "persistence", "migration",
])
for forbidden in ["WKWebView", "MutationObserver", "setInterval", "Timer.scheduledTimer", "sendEvent(", "touchesBegan("]:
    require(forbidden not in active_runtime, f"Second functionality pass adds no quarantined/global interaction mechanism: {forbidden}")

if errors:
    print("LifeRoute v0.5 second-functionality-pass audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute v0.5 second-functionality-pass audit passed ({len(checks)} checks).")
for check in checks:
    print(f"- OK: {check}")
