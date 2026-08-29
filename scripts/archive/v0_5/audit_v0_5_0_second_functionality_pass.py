from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

PATHS = {
    "app": ROOT / "LifeRoute" / "LifeRouteApp.swift",
    "shell": ROOT / "LifeRoute" / "V054ContentView.swift",
    "navigation": ROOT / "LifeRoute" / "AppNavigation.swift",
    "today": ROOT / "LifeRoute" / "V054TodayView.swift",
    "schedule": ROOT / "LifeRoute" / "V054ScheduleView.swift",
    "setup": ROOT / "LifeRoute" / "V054SetupView.swift",
    "clients": ROOT / "LifeRoute" / "ClientProfileDomain.swift",
    "client_views": ROOT / "LifeRoute" / "V054ClientViews.swift",
    "calendar": ROOT / "LifeRoute" / "CalendarDomain.swift",
    "providers": ROOT / "LifeRoute" / "CalendarProviderCore.swift",
    "routing": ROOT / "LifeRoute" / "RoutingLocationDomain.swift",
    "day_route": ROOT / "LifeRoute" / "DayRoutePlanningCore.swift",
    "tools": ROOT / "LifeRoute" / "SessionToolsDomain.swift",
    "tool_views": ROOT / "LifeRoute" / "SessionToolsViews.swift",
    "ai": ROOT / "LifeRoute" / "LifeRouteIntelligenceCore.swift",
    "persistence": ROOT / "LifeRoute" / "PersistenceCore.swift",
    "migration": ROOT / "LifeRoute" / "LegacyMigrationCore.swift",
    "project": ROOT / "LifeRoute.xcodeproj" / "project.pbxproj",
    "prepare": ROOT / "scripts" / "prepare_build.sh",
    "workflow": ROOT / ".github" / "workflows" / "ios-ci.yml",
}

errors: list[str] = []
checks: list[str] = []


def read(name: str) -> str:
    try:
        return PATHS[name].read_text(encoding="utf-8")
    except Exception as exc:
        errors.append(f"Could not read {PATHS[name].relative_to(ROOT)}: {exc}")
        return ""


def require(condition: bool, message: str) -> None:
    (checks if condition else errors).append(message)


s = {name: read(name) for name in PATHS}

# Launch + navigation.
require("WindowGroup" in s["app"] and "ContentView()" in s["app"], "App still launches through the reviewed ContentView entry")
require("typealias ContentView = V054ContentView" in s["shell"], "v0.5.4 owns the active ContentView identity")
require("TabView(selection: $router.selectedSection)" in s["shell"], "Top-level selection remains AppRouter-owned")
require(s["shell"].count("NavigationStack(path: $router.") == 5, "All five top-level sections retain independent router-owned stacks")
for section_name in ["today", "schedule", "tools", "resources", "setup"]:
    require(f".tag(AppSection.{section_name})" in s["shell"], f"Top-level tab is wired: {section_name}")
require("func resetPath(for section: AppSection)" in s["navigation"], "Navigation paths remain deterministically resettable")

# Today / routing journey.
require("routingState.requestCurrentLocation()" in s["today"] and "routingState.stopLiveLocation()" in s["today"], "Today retains explicit live-location start/stop")
require("startUpdatingLocation()" in s["routing"] and "allowsBackgroundLocationUpdates = false" in s["routing"], "Live GPS remains continuous while foreground-only")
require("MKLocalSearchCompleter" in s["routing"], "Native address autocomplete remains available")
# v0.7.0 reviewed superset: Home and Saved Places still mutate through one helper;
# the same protected snapshot now also carries restored weekly To-Dos. Keep the
# original mutation ownership strict instead of accepting arbitrary direct writes.
require(
    "private func persistRoutingInputs()" in s["routing"]
    and s["routing"].count("persistRoutingInputs()") == 4
    and "homeAddress: homeAddress" in s["routing"]
    and "savedPlaces: savedPlaces" in s["routing"]
    and "todos: todos" in s["routing"],
    "Home and saved-place mutations persist through one owner, with reviewed To-Dos in the same protected routing snapshot",
)
require("currentLocation" not in s["persistence"] and "routeEstimates" not in s["persistence"], "Live coordinates and calculated routes remain transient")
require("case before" in s["day_route"] and "case after" in s["day_route"] and "if returnHome" in s["day_route"], "Day routing supports before stops, after stops, and Return Home")

# Calendar journey.
for calendar_range in ["case day", "case week", "case month"]:
    require(calendar_range in s["calendar"], f"Calendar range remains implemented: {calendar_range.removeprefix('case ')}")
require("calendarState.addManualEvent(" in s["schedule"], "Manual appointment creation remains wired")
require("calendarState.removeEvent(id: event.id)" in s["schedule"], "Manual appointment deletion remains wired")
require("connectOrRefreshApple" in s["schedule"] and "connectOrRefreshGoogle" in s["schedule"], "Apple and Google calendar refresh remain user-triggered")
require("https://www.googleapis.com/auth/calendar.readonly" in s["providers"], "Google Calendar access remains read-only")
require("saveManualCalendarEvents(events.filter { $0.source == .manual })" in s["calendar"], "Only manual appointments cross calendar persistence")

# Client journey.
require("V054ClientProfilesView" in s["setup"], "Setup reaches native client management")
require("clientState.saveProfile(" in s["client_views"], "Client editor retains add/edit save wiring")
require("clientState.removeClient(id: profile.id)" in s["client_views"], "Client removal remains wired")
require("@State private var isSaving = false" in s["client_views"] and ".disabled(isSaving)" in s["client_views"], "Client save remains reentrancy guarded")
require("let code = first + last" in s["clients"] and "first.count == 2" in s["clients"], "ABA client identity remains four normalized initials")
for field in ["preferredActivities", "currentTargets", "behaviorsOfConcern", "communicationNotes", "promptingNotes", "caregiverNotes", "clinicalNotes", "address"]:
    require(field in s["clients"] and field in s["client_views"], f"Client workflow retains reviewed field: {field}")
require("LifeRoutePersistenceStore.shared.saveClients(clients)" in s["clients"], "Client mutations remain durable")

# Session Tools + AI journey.
require("deadline = now.addingTimeInterval(seconds)" in s["tools"] and "remainingSeconds(at:" in s["tools"], "Visual Timer retains absolute-deadline behavior")
for action in ["timer.start", "timer.pause", "timer.resume", "timer.addMinute", "timer.reset"]:
    require(action in s["tool_views"], f"Visual Timer control remains wired: {action}")
require('generalClientCode = "GENERAL"' in s["tools"] and "crossClientReference" in s["tools"], "General visual library and same-library ownership remain enforced")
require("LanguageModelSession" in s["ai"] and "SystemLanguageModel.default" in s["ai"], "Restored AI tools use Apple's on-device Foundation Model")
require("using ONLY the session facts supplied below" in s["ai"], "AI note generation retains supplied-facts-only guardrail")
require("ACTUALLY ORGANIZE THE SESSION" in s["ai"] and "never create a new intervention" in s["ai"], "AI planning synthesizes a session flow without inventing treatment")
legacy_timer_signal = "* 0.60" in s["tools"] and "* 0.85" in s["tools"]
modern_timer_signal = (
    "startGainForFiveDecibelCrescendo" in s["tools"]
    and "signalGain(forRemaining:" in s["tools"]
    and "v0.6.3 cosine release reaches silence smoothly" in s["tools"]
)
require(legacy_timer_signal or modern_timer_signal, "Timer retains either the approved legacy signal boost or the superseding controlled crescendo with click-free release")

# Persistence / migration / architecture.
for marker, label in [
    ("schemaVersion", "versioned snapshot"),
    ("FileProtectionType.completeUntilFirstUserAuthentication", "sensitive-data protection"),
    ("options: [.atomic]", "atomic writes"),
    ("SnapshotWriter", "serial off-main writer"),
    ("await previousTask?.value", "ordered writes"),
]:
    require(marker in s["persistence"], f"Native persistence retains {label}")
for reviewed in ["clients", "manualCalendarEvents", "places", "homeAddress"]:
    require(reviewed in s["migration"], f"Legacy mapper retains reviewed boundary: {reviewed}")
for forbidden in ["liferoute_visual_tools_v2", "googleAccessToken", "WKWebsiteDataStore", "localStorage"]:
    require(forbidden not in s["migration"], f"Legacy mapper excludes quarantined input: {forbidden}")
require("private actor SnapshotWriter" in s["persistence"], "Snapshot encoding and I/O remain off the interaction owner")
require("iconsByClientID" in s["tools"] and "eventIndicesByDay" in s["calendar"], "Visual and calendar derived lookups remain indexed")
require("private var googleRefreshTask: Task<Void, Never>?" in s["providers"] and "private var routeTasks: [UUID: Task<Void, Never>]" in s["routing"], "Provider and routing async work retain explicit owners")
require("if phase == .background" in s["shell"] and "routingState.cancelPendingOperations()" in s["shell"], "Background routing cleanup remains lifecycle-bounded")

# Build/release isolation.
for file_name in [
    "LifeRouteApp.swift", "AppNavigation.swift", "V054ContentView.swift", "V054TodayView.swift",
    "V054ScheduleView.swift", "V054ToolsDashboard.swift", "V054SetupView.swift",
    "CalendarDomain.swift", "CalendarProviderCore.swift", "RoutingLocationDomain.swift",
    "ClientProfileDomain.swift", "V054ClientViews.swift", "SessionToolsDomain.swift",
    "SessionToolsViews.swift", "PersistenceCore.swift", "LegacyMigrationCore.swift",
]:
    require(f"{file_name} in Sources" in s["project"], f"Active native target compiles {file_name}")
require("LifeRouteWebView.swift in Sources" not in s["project"] and "Web in Resources" not in s["project"], "Legacy WebView and JavaScript runtime remain quarantined")
require(s["project"].count("MARKETING_VERSION = 0.5.4;") >= 4, "App and Live Activity Debug/Release configurations share v0.5.4 identity")
require("audit_v0_5_4_restore.py" in s["prepare"], "Preparation includes the dedicated v0.5.4 restoration audit")
require("Audit checkpoint 07 second functionality pass" in s["workflow"], "iOS CI retains this cross-domain gate before Simulator compilation")

active_runtime = "\n".join(s[name] for name in ["app", "shell", "navigation", "calendar", "providers", "routing", "clients", "client_views", "tools", "tool_views", "persistence", "migration"])
for forbidden in ["WKWebView", "MutationObserver", "setInterval", "Timer.scheduledTimer", "sendEvent(", "touchesBegan("]:
    require(forbidden not in active_runtime, f"Active runtime adds no quarantined/global interaction mechanism: {forbidden}")

if errors:
    print("LifeRoute v0.5 cross-domain functionality audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute v0.5 cross-domain functionality audit passed ({len(checks)} checks).")
for check in checks:
    print(f"- OK: {check}")
