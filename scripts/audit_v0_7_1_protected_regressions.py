#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.1 protected regression audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


app = read("LifeRoute/LifeRouteApp.swift")
shell = read("LifeRoute/V054ContentView.swift")
today = read("LifeRoute/V054TodayView.swift")
prepare = read("scripts/prepare_build.sh")
router = read("LifeRoute/AppNavigation.swift")
calendar = read("LifeRoute/CalendarDomain.swift")
routing = read("LifeRoute/DayRoutePlanningCore.swift")
tools = read("LifeRoute/SessionToolsDomain.swift")
tools_view = read("LifeRoute/V054ToolsDashboard.swift")
persistence = read("LifeRoute/PersistenceCore.swift")

# --- Theme/runtime ownership -------------------------------------------------
require(app.count("final class LifeRouteThemeStore: ObservableObject") == 1,
        "LifeRouteThemeStore must remain the single persisted theme owner")
require('private static let storageKey = "liferoute.selectedTheme"' in app,
        "selected-theme persistence key changed or disappeared")
require_all(app, [
    "struct LifeRouteLiveThemeEnvironment: View",
    "@Environment(\\.scenePhase) private var scenePhase",
    "paused: reduceMotion || !isActive",
], "root live-theme lifecycle contract")
require(app.count("TimelineView(") == 1,
        "LifeRouteApp must keep exactly one shared live-theme TimelineView")

# Catalog counts are protected: 12 Core + 12 Dynamic + 20 Scenery.
for declaration, expected in [
    ("static let phaseOneCoreGlassCatalog: [LifeRouteTheme]", 12),
    ("static let phaseTwoDynamicCatalog: [LifeRouteTheme]", 12),
    ("static let phaseThreeSceneryCatalog: [LifeRouteTheme]", 20),
]:
    match = re.search(re.escape(declaration) + r"\s*=\s*\[(.*?)\n\s*\]", app, flags=re.S)
    require(match is not None, f"theme catalog declaration missing: {declaration}")
    require(match.group(1).count(".") == expected,
            f"theme catalog count changed for {declaration}; expected {expected}")

# --- Five-tab shell / navigation -------------------------------------------
for tab in ["today", "schedule", "tools", "resources", "setup"]:
    require(f".tag(AppSection.{tab})" in shell, f"protected tab missing: {tab}")
require(".tag(AppSection.routes)" not in shell, "unexpected sixth Routes tab returned")
require_all(shell, [
    "@StateObject private var router = AppRouter()",
    "@StateObject private var calendarState = CalendarCoreState()",
    "@StateObject private var routingState = RoutingLocationCore()",
    "@StateObject private var clientState = ClientProfileCore()",
    "@StateObject private var toolsState = SessionToolsCore()",
], "root domain-owner contract")
require("router.select(.today)" in shell, "liferoute URL routing back to Today disappeared")
require("resumeForegroundLocationIfNeeded" in shell,
        "foreground location resumption disappeared")
require("cancelPendingOperations" in shell,
        "background routing cancellation disappeared")

# AppRouter and the existing semantic route into Setup are explicitly protected.
require("final class AppRouter" in router or "class AppRouter" in router,
        "AppRouter declaration missing")
require_all(router, [
    "func select(_ section: AppSection)",
    "case setup",
], "AppRouter section-selection contract")
require("router.select(.setup)" in tools_view,
        "semantic open-Setup routing action disappeared")

# --- Today / selected day ----------------------------------------------------
require_all(today, [
    'Text("Life")',
    'Text("Route")',
    "ForEach(selectedDayEvents)",
], "Today approved wordmark + full selected-day agenda")
require("LifeRouteBrandMark(variant: .small)" not in today,
        "square LR mark must not return to Today hero")

# Horizontal selected-day navigation must remain present after materialization.
require(
    any(token in today for token in ["selectedDay", "selectedDate"]),
    "Today selected-day state/reference disappeared"
)
require(
    any(token in today for token in ["DragGesture", "swipe", "horizontal"]),
    "Today horizontal selected-day navigation contract disappeared"
)

# Live Day / Live Activity hooks must remain present.
require_all(today, [
    "LiveDayActivityCore",
    "liveActivity.start",
    "liveActivity.update",
    "liveActivity.end",
], "Today Live Day / Live Activity contract")

# --- Core functional owners -------------------------------------------------
require("CalendarCoreState" in calendar, "calendar domain owner missing")
require("RoutingLocationCore" in routing or "DayRoutePlanning" in routing,
        "routing/location domain contract missing")
require("SessionToolsCore" in tools, "session tools/timer domain owner missing")
require("Persistence" in persistence or "UserDefaults" in persistence,
        "persistence implementation unexpectedly missing")

# --- Canonical preparation / release safety --------------------------------
require_all(prepare, [
    "python3 scripts/patch_v0_7_0_theme_phase_3.py",
    "python3 scripts/audit_v0_7_0_theme_phase_3.py",
    "python3 scripts/audit_v0_7_0_testflight.py",
], "historical Phase 3 canonical preparation")
require("legacy WebView runtime" in prepare or "WebView" in prepare,
        "legacy WebView quarantine guard text disappeared")

# The official app icon must remain source-owned and guarded by preparation.
require("Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" in prepare,
        "official AppIcon generation/release guard disappeared")
require("hasAlpha" in prepare and '"no"' in prepare,
        "AppIcon no-alpha release guard disappeared")

print(
    "LifeRoute v0.7.1 protected regression audit passed: single theme owner/clock, "
    "12 Core + 12 Dynamic + 20 Scenery catalogs, five-tab shell, AppRouter/Setup routing, "
    "Today split wordmark + full selected-day agenda + horizontal day navigation, Live Day/Live Activity, "
    "calendar/routing/tools/persistence owners, canonical Phase 3 materialization, WebView quarantine, "
    "and official AppIcon release guards remain present."
)
