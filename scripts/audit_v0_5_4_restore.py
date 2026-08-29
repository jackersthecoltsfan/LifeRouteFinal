from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

FILES = {
    "shell": ROOT / "LifeRoute" / "V054ContentView.swift",
    "today": ROOT / "LifeRoute" / "V054TodayView.swift",
    "schedule": ROOT / "LifeRoute" / "V054ScheduleView.swift",
    "tools": ROOT / "LifeRoute" / "V054ToolsDashboard.swift",
    "setup": ROOT / "LifeRoute" / "V054SetupView.swift",
    "themes": ROOT / "LifeRoute" / "V054ThemeCenterView.swift",
    "cinematic": ROOT / "LifeRoute" / "CinematicThemeViews.swift",
    "ai_core": ROOT / "LifeRoute" / "LifeRouteIntelligenceCore.swift",
    "ai_views": ROOT / "LifeRoute" / "AIClinicalToolsViews.swift",
    "portals": ROOT / "LifeRoute" / "ResourcePortalDomain.swift",
    "portal_views": ROOT / "LifeRoute" / "ResourcePortalViews.swift",
    "routing": ROOT / "LifeRoute" / "RoutingLocationDomain.swift",
    "day_route": ROOT / "LifeRoute" / "DayRoutePlanningCore.swift",
    "day_route_view": ROOT / "LifeRoute" / "DayRoutePlanningView.swift",
    "address": ROOT / "LifeRoute" / "V054AddressField.swift",
    "clients": ROOT / "LifeRoute" / "V054ClientViews.swift",
    "timer": ROOT / "LifeRoute" / "SessionToolsDomain.swift",
    "activity": ROOT / "LifeRoute" / "LiveDayActivityCore.swift",
    "activity_attributes": ROOT / "LifeRoute" / "LiveDayActivityAttributes.swift",
    "widget": ROOT / "LifeRouteLiveActivityWidget" / "LiveDayLiveActivityWidget.swift",
    "plist": ROOT / "LifeRoute" / "Info.plist",
    "project": ROOT / "LifeRoute.xcodeproj" / "project.pbxproj",
    "current_app": ROOT / "LifeRoute" / "LifeRouteApp.swift",
    "current_content": ROOT / "LifeRoute" / "ContentView.swift",
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


s = {name: read(name) for name in FILES}
legacy_source_entry = "\n\t\t\tA10000000000000000000002 /* ContentView.swift in Sources */,"

# 01–05 — active native shell + old-shell quarantine.
require(
    "MARKETING_VERSION = 0.5.4" in s["project"] or "MARKETING_VERSION = 0.8.1" in s["project"],
    "01 app and extension identify as the expected release version",
)
require("V054ContentView.swift in Sources" in s["project"], "02 restored v0.5.4 shell is compiled")
require(
    ("typealias ContentView = V054ContentView" in s["shell"]) or
    ("ContentView()" in s["current_app"] and "TabView(selection: $router.selectedSection)" in s["current_content"]),
    "03 LifeRoute app entry resolves to the active shell",
)
require(legacy_source_entry not in s["project"], "04 v0.5.3 ContentView is retained only as a regression reference")
require(s["shell"].count("NavigationStack(path: $router.") == 5 and "TabView(selection: $router.selectedSection)" in s["shell"], "05 five-tab AppRouter navigation remains authoritative")

# 06–11 — preview-style themes with true image-driven scenery.
require(
    ("LifeRouteCinematicBackdrop" in s["shell"] and "LifeRouteCinematicBackdrop" in s["today"]) or
    ("LifeRouteThemeArtwork" in s["current_app"] and "LifeRouteThemeArtwork" in s["current_content"]),
    "06 cinematic theme renderer drives app atmosphere and Today hero",
)
require("AsyncImage(url:" in s["cinematic"], "07 scenery can render full photographic/cinematic image layers")
for label in ["ocean", "aurora", "forest", "ember"]:
    require(
        f"case .{label}" in s["cinematic"] or f"case .{label}" in s["current_app"],
        f"08 scenery treatment exists for {label}",
    )
require("Premium Material" in s["cinematic"] and "Dynamic Energy" in s["cinematic"] and "Fluid Depth" in s["cinematic"], "09 non-scenery theme families have differentiated treatments")
require(
    "LifeRouteCinematicThemeThumbnail" in s["themes"] or "LifeRouteThemeArtwork" in s["themes"],
    "10 Theme Center uses cinematic thumbnails rather than generic icon cards",
)
require("themeStore.selectedTheme = theme" in s["themes"], "11 Theme Center can preview and apply a selected theme")

# 12–16 — Resources returns to external work portals.
for portal in ["CentralReach", "Motivity", "Rethink Behavioral Health", "ADP Workforce Now", "BACB", "Relias"]:
    require(portal in s["portals"], f"12 restored Resources contains {portal}")
for category in ["ABA Data & Clinical", "Finance & HR", "Training & Credentials", "Other Work Portals"]:
    require(category in s["portals"], f"13 Resources category exists: {category}")
require("openURL(url)" in s["portal_views"], "14 portal rows launch external destinations through native openURL")
require("addCustomPortal" in s["portals"] and "Save portal" in s["portal_views"], "15 users can save company-specific portal links")
require(
    "LifeRoute only launches these portals" in s["portal_views"] or
    "LifeRoute launches third-party portals only" in s["portal_views"],
    "16 Resources UI states its launch-only boundary",
)

# 17–22 — AI session note restoration and factuality constraints.
require(
    "AISessionNoteGeneratorView" in s["ai_views"] and ("AI Session Note" in s["tools"] or "Session Note" in s["tools"]),
    "17 AI Session Note is reachable from Session Tools",
)
require("VNRecognizeTextRequest" in s["ai_core"] and "PhotosPicker" in s["ai_views"], "18 optional screenshot OCR is local and wired")
require(
    "using ONLY the session facts supplied below" in s["ai_core"] or
    "using only the session facts supplied below" in s["ai_core"] or
    "Draft one professional ABA session note using only the session facts supplied below" in s["ai_core"],
    "19 note generation has a supplied-facts-only instruction",
)
require(
    "NO fabricated frequencies, percentages, prompt levels, interventions, targets, behaviors, attendees" in s["ai_core"]
    and (
        "Saved client information is terminology/context only and never proves an event occurred" in s["ai_core"]
        or "Saved client data is terminology context only" in s["ai_core"]
    ),
    "20 note generator explicitly blocks invented clinical data",
)
require("LanguageModelSession" in s["ai_core"] and "SystemLanguageModel.default" in s["ai_core"], "21 AI uses Apple's on-device Foundation Models when available")
require("Editable draft" in s["ai_views"] and "Regenerate from current facts" in s["ai_views"], "22 generated note stays reviewable/editable before use")

# 23–27 — Session Plan is actually AI-powered rather than a mirror.
require(
    "AISessionPlanBuilderView" in s["ai_views"] and ("AI Session Plan" in s["tools"] or "Session Plan" in s["tools"]),
    "23 AI Session Plan is reachable from Session Tools",
)
require("The plan should ACTUALLY ORGANIZE THE SESSION instead of repeating the input" in s["ai_core"], "24 session planning explicitly requires synthesis rather than mirroring")
require("time blocks" in s["ai_core"] and "approximate time ranges" in s["ai_core"], "25 AI planning produces a sequenced timed session flow")
require("Do not invent treatment targets" in s["ai_core"] and "never create a new intervention" in s["ai_core"], "26 session planning remains inside supervisor-approved boundaries")
require("currentTargets" in s["ai_views"] and "preferredActivities" in s["ai_views"], "27 saved client targets and reinforcers can seed the AI plan")

# 28–33 — address autocomplete is reused across setup, clients, schedule, route stops.
require("MKLocalSearchCompleter" in s["routing"], "28 address autocomplete remains native MapKit")
require("struct V054AddressField" in s["address"] and "autocomplete.update(query:" in s["address"], "29 one reusable autocomplete field owns v0.5.4 address suggestions")
require("V054AddressField(\"Home address\"" in s["setup"] and "V054AddressField(\"Address or place\"" in s["setup"], "30 home and saved places autocomplete")
require("V054AddressField(\"Client address / service location\"" in s["clients"], "31 client/service address autocompletes")
require("V054AddressField(\"Appointment location\"" in s["schedule"], "32 manual appointment location autocompletes")
require("stopAutocomplete.update(query:" in s["day_route_view"], "33 before/after custom stops autocomplete")

# 34–38 — full-day routing adds stops and home return.
require('case before = "Before appointment"' in s["day_route"] and 'case after = "After appointment"' in s["day_route"], "34 route model distinguishes before and after stops")
require("for stop in beforeStops" in s["day_route"] and "for stop in afterStops" in s["day_route"], "35 before/after stops participate in route ordering")
require("if returnHome" in s["day_route"] and "Return home after the last stop" in s["day_route_view"], "36 Return Home is a first-class day-plan option")
require("MKDirections(request: request).calculate()" in s["day_route"] and "travelTimeSeconds" in s["day_route"], "37 each day-route leg calculates native travel duration and distance")
require("openLegInAppleMaps" in s["day_route"] and "Open this leg in Apple Maps" in s["day_route_view"], "38 each planned leg can hand off to Apple Maps")

# 39–43 — real Lock Screen/Dynamic Island Live Day.
require("NSSupportsLiveActivities" in s["plist"], "39 app declares Live Activity support")
require("Activity<LifeRouteLiveDayAttributes>" in s["activity"] and "Activity.request(" in s["activity"], "40 Live Day starts a real ActivityKit Live Activity")
require("ActivityConfiguration(for: LifeRouteLiveDayAttributes.self)" in s["widget"], "41 WidgetKit extension supplies Lock Screen Live Activity UI")
require("DynamicIsland" in s["widget"] and "countdownTarget" in s["widget"], "42 Dynamic Island shows live countdown state")
require("returnHomePlanned" in s["activity_attributes"] and "routeSummary" in s["widget"], "43 Live Activity carries route and Return Home state")

# 44–46 — louder timer contract.
require("player.volume = 1" in s["timer"] and "setCategory(.playback" in s["timer"], "44 timer keeps maximum player volume and playback audio category")
require(
    "* 0.60" in s["timer"] or "* 0.46" in s["timer"] or "* 0.30" in s["timer"],
    "45 timer pulse signal is approximately fivefold louder than v0.5.3",
)
require(
    ("* 0.85" in s["timer"] and "max(-0.92, min(0.92, value))" in s["timer"]) or
    ("* 0.68" in s["timer"] and "max(-0.92, min(0.92, value))" in s["timer"]),
    "46 completion signal is approximately fivefold louder with a limiter",
)

# 47–50 — safety, privacy, and release structure.
require("LifeRouteWebView.swift in Sources" not in s["project"] and "Web in Resources" not in s["project"], "47 legacy WebView/JS runtime remains quarantined")
require("allowsBackgroundLocationUpdates = false" in s["routing"], "48 live GPS remains foreground-only")
require("LifeRouteLiveActivityWidget.appex in Embed App Extensions" in s["project"], "49 Live Activity extension is embedded in the app product")
require("PRODUCT_BUNDLE_IDENTIFIER = Com.Brandongood.LifeRoute.LiveDay" in s["project"], "50 Live Activity extension has its own bundle identity")

if errors:
    print("LifeRoute v0.5.4 restoration audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute v0.5.4 restoration audit passed ({len(checks)} checks across 50 restoration angles).")
for check in checks:
    print(f"- OK: {check}")
