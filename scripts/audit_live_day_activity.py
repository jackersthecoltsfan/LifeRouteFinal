from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
DAY = WEB / "day-controls-v5.js"
LIVE = WEB / "live-day.js"
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"
MANAGER = ROOT / "LifeRoute" / "LiveActivityManager.swift"
ATTRIBUTES = ROOT / "LifeRouteShared" / "LifeRouteActivityAttributes.swift"
WIDGET = ROOT / "LifeRouteLiveActivity" / "LifeRouteLiveActivityWidget.swift"
PBX = ROOT / "LifeRoute.xcodeproj" / "project.pbxproj"
PLIST = ROOT / "LifeRoute" / "Info.plist"
EXT_PLIST = ROOT / "LifeRouteLiveActivity" / "Info.plist"
AUTO = ROOT / ".github" / "workflows" / "auto-testflight.yml"

failures: list[str] = []
passes: list[str] = []


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception as exc:
        failures.append(f"read {path.relative_to(ROOT)}: {exc}")
        return ""


def check(condition: bool, label: str) -> None:
    (passes if condition else failures).append(label)


day = read(DAY)
live = read(LIVE)
swift = read(SWIFT)
manager = read(MANAGER)
attributes = read(ATTRIBUTES)
widget = read(WIDGET)
pbx = read(PBX)
plist = read(PLIST)
ext_plist = read(EXT_PLIST)
auto = read(AUTO)

# UI: remove the oversized commitments hero while keeping controls available.
check("lrDayHeroRemoved" in day and "display:none!important" in day, "Day commitments hero is removed")
check("lrDayCommandStrip" in day, "compact Day command strip exists")
check("Clear day" in day and "Clear all" in day, "Clear day and Clear all controls exist")
clear_day = day[day.find("const clearDay ="):day.find("let clearAllArmedUntil")]
clear_all = day[day.find("let clearAllArmedUntil"):day.find("const install =")]
check("window.confirm" not in clear_day, "Clear day works without WKWebView JavaScript confirm UI")
check("window.events = window.events.filter" not in clear_day, "Clear day never deletes calendar/manual appointments")
check("window.persist?.()" not in clear_day, "Clear day does not persist unrelated event mutations")
check("clearDateKeys(GENERATED_STORE, day)" in clear_day, "Clear day removes selected day's generated state")
check("clearLifeRouteGapRoutesForDay(day)" in clear_day, "Clear day clears selected day's gap routes through in-memory owner")
check("clearLifeRouteBoundaryStopsForDay(day)" in clear_day, "Clear day clears selected day's boundary stops through in-memory owner")
check("liferoute_selected_gap_routes_v2" in day and "liferoute_boundary_stops_v2" in day, "Clear day owns only selected gap and boundary plan stores")
check("liferoute:day-cleared" in clear_day and "Cleared ✓" in clear_day, "Clear day visibly confirms completion")
check("appointments and saved data kept" in clear_day, "Clear day status explicitly states preserved data")
check("window.confirm" not in clear_all, "Clear all does not depend on WKWebView JavaScript confirm UI")
check("clearAllArmedUntil" in clear_all and "Tap again to clear all" in clear_all and "4000" in clear_all, "Clear all uses bounded two-tap destructive confirmation")
check('localStorage.getItem(AUTH_STORE)' in clear_all and 'localStorage.setItem(AUTH_STORE, auth)' in clear_all, "Clear all preserves dormant local auth credential for future restoration")
check('window.postNative({ action: "authClearCredentials" })' not in clear_all, "Clear all does not destroy native Keychain auth credentials")

# Generate Day -> reminders + Live Activity handoff.
check("generateLifeRouteDay" in live and "scheduleNotifications(plan)" in live, "Generate Day still schedules leave reminders")
check("startLiveDayActivity" in day, "Generate Day starts native Live Activity")
check("buildActivityCheckpoints" in day, "Live Activity payload is built from current Day plan")
check("lifeRouteSelectedGapFor" in day, "Live Activity includes selected between-event stops")
check("endDayAtHome" in day, "Live Activity can include Return Home final leg")
check("endLiveDayActivity" in day, "End/Clear actions end the Live Activity")

# Native ActivityKit host bridge.
for marker in ["startLiveDayActivity", "updateLiveDayActivity", "endLiveDayActivity", "LifeRouteLiveActivityManager"]:
    check(marker in swift, f"native Live Activity bridge: {marker}")
check("ActivityAuthorizationInfo" in manager, "Live Activity availability is checked")
check("Activity<LifeRouteActivityAttributes>.request" in manager, "native Live Activity request is implemented")
check("endAll" in manager, "native Live Activity can be ended cleanly")
check("checkpoints.prefix(12)" in manager, "Live Activity payload is bounded")

# Shared model and Lock Screen / Dynamic Island presentation.
check("ActivityAttributes" in attributes and "Checkpoint" in attributes, "shared ActivityKit attributes model exists")
check("ActivityConfiguration(for: LifeRouteActivityAttributes.self)" in widget, "Lock Screen ActivityConfiguration exists")
check("DynamicIsland" in widget, "Dynamic Island presentation exists")
check("Text(timerInterval:" in widget, "Lock Screen displays live leave/start countdown")
check("nextCheckpoint" in widget and "ProgressView" in widget, "Lock Screen tracks next stop and day progress")
check("TimelineView(.periodic" in widget, "Live Activity reevaluates progress over time")

# Xcode target/Info.plist wiring.
check("LifeRouteLiveActivity.appex" in pbx, "Live Activity app extension product is embedded")
check("Embed App Extensions" in pbx, "host app embeds Live Activity extension")
check("LifeRouteActivityAttributes.swift in Sources" in pbx, "shared Activity attributes compile in targets")
check("LifeRouteLiveActivityWidget.swift in Sources" in pbx, "Live Activity widget source is in extension target")
check("NSSupportsLiveActivities" in plist, "host app declares Live Activity support")
check("com.apple.widgetkit-extension" in ext_plist, "extension uses WidgetKit extension point")

# Release safety while this native build is being prepared but not shipped.
check('[no-testflight]' in auto, "automatic TestFlight dispatcher honors no-testflight marker")
check("No-TestFlight commit validated; skipping TestFlight dispatch." in auto, "no-testflight skip is explicit")

print(f"LifeRoute Live Day audit: {len(passes)} passed, {len(failures)} failed")
if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(1)
print("LifeRoute Day UI, route-scoped Clear Day/Clear All controls, reminders, and Live Activity audit passed.")
