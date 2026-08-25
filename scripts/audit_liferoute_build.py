from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
SCRIPTS = ROOT / "scripts"
INDEX = WEB / "index.html"
WEB_PREVIEW = SCRIPTS / "web-preview.js"
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"
PREPARE = SCRIPTS / "prepare_build.sh"
TESTFLIGHT = ROOT / ".github" / "workflows" / "testflight.yml"
AUTO_TESTFLIGHT = ROOT / ".github" / "workflows" / "auto-testflight.yml"
PAGES = ROOT / ".github" / "workflows" / "pages.yml"
IOS_CI = ROOT / ".github" / "workflows" / "ios-ci.yml"

errors: list[str] = []
checks: list[str] = []


def require(condition: bool, message: str) -> None:
    if condition:
        checks.append(message)
    else:
        errors.append(message)


def text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception as exc:
        errors.append(f"Readable file: {path.relative_to(ROOT)} ({exc})")
        return ""


CORE_FILES = [
    "global-bridge.js",
    "calendar-hub.js",
    "auth-gate.js",
    "icons.js",
    "route-times.js",
    "smart-context.js",
    "todos.js",
    "grocery-stores.js",
    "transport-mode.js",
    "sleek-ui.js",
    "store-sleek-ui.js",
    "selected-gap-routes.js",
    "saved-place-gap-options.js",
    "live-day.js",
    "rbt-tools.js",
    "visual-resolver.js",
    "visual-tools.js",
    "visual-resolver-bridge.js",
    "live-themes.js",
    "day-route-experience.js",
    "boundary-stop-planner.js",
    "day-navigation-runtime.js",
    "refined-ui-v2.js",
    "stability-runtime.js",
]

BROWSER_FILES = [
    "welcome.js",
    "nav-cleanup.js",
    "icloud-calendar-web.js",
    "google-calendar-web.js",
    "google-calendar-stability.js",
    "google-calendar-persistence-web.js",
    "first-then-back.js",
    "visual-quality-web.js",
    "photo-source-picker-web.js",
    "end-home-route-web.js",
    "mileage-tracker-web.js",
    "resources-hub-web.js",
    "nature-settings-web.js",
    "settings-classic-themes-web.js",
    "photoreal-nature-web.js",
    "dynamic-themes-web.js",
    "web-routing-bridge.js",
    "web-store-search-fallback.js",
]

for name in CORE_FILES + BROWSER_FILES:
    require((WEB / name).is_file() and (WEB / name).stat().st_size > 0, f"Required feature file: {name}")

node = shutil.which("node")
require(bool(node), "Node.js available for JavaScript syntax audit")
if node:
    for path in sorted(WEB.rglob("*.js")):
        proc = subprocess.run([node, "--check", str(path)], capture_output=True, text=True)
        require(proc.returncode == 0, f"JavaScript syntax: {path.relative_to(ROOT)}")
        if proc.returncode != 0:
            errors.append((proc.stderr or proc.stdout).strip())

for path in sorted(SCRIPTS.glob("*.py")):
    proc = subprocess.run([sys.executable, "-m", "py_compile", str(path)], capture_output=True, text=True)
    require(proc.returncode == 0, f"Python syntax: {path.relative_to(ROOT)}")
    if proc.returncode != 0:
        errors.append((proc.stderr or proc.stdout).strip())

index = text(INDEX)
preview = text(WEB_PREVIEW)
swift = text(SWIFT)
prepare = text(PREPARE)
auth = text(WEB / "auth-gate.js")
global_bridge = text(WEB / "global-bridge.js")
day_route = text(WEB / "day-route-experience.js")
day_nav = text(WEB / "day-navigation-runtime.js")
boundary = text(WEB / "boundary-stop-planner.js")
selected_gap = text(WEB / "selected-gap-routes.js")
saved_place_gap = text(WEB / "saved-place-gap-options.js")
settings = text(WEB / "settings-classic-themes-web.js")
dynamic = text(WEB / "dynamic-themes-web.js")
photo = text(WEB / "photoreal-nature-web.js")
resources = text(WEB / "resources-hub-web.js")
visuals = text(WEB / "visual-tools.js")
route_bridge = text(WEB / "web-routing-bridge.js")
store_fallback = text(WEB / "web-store-search-fallback.js")
refined = text(WEB / "refined-ui-v2.js")
stability = text(WEB / "stability-runtime.js")

# Deterministic startup order.
script_refs = re.findall(r'<script[^>]+src=["\']([^"\']+\.js)(?:\?[^"\']*)?["\']', index, flags=re.I)
counts = Counter(script_refs)
for ref, count in counts.items():
    require(count == 1, f"No duplicate prepared script tag: {ref}")
for name in CORE_FILES:
    require(name in script_refs, f"Prepared HTML loads core feature: {name}")
    require((WEB / name).is_file(), f"Prepared core script resolves: {name}")

if all(name in script_refs for name in CORE_FILES):
    positions = [script_refs.index(name) for name in CORE_FILES]
    require(positions == sorted(positions), "Core feature scripts load in canonical order")
    require(script_refs.index("global-bridge.js") < script_refs.index("calendar-hub.js"), "Global state bridge loads before calendar hub")
    require(script_refs.index("todos.js") < script_refs.index("saved-place-gap-options.js"), "To-Dos load before Saved Places gap enhancement")
    require(script_refs.index("selected-gap-routes.js") < script_refs.index("saved-place-gap-options.js"), "Persistent gap routes load before Saved Places gap enhancement")
    require(script_refs.index("day-route-experience.js") < script_refs.index("boundary-stop-planner.js"), "Boundary card shell loads before persistent boundary planner")
    require(script_refs.index("boundary-stop-planner.js") < script_refs.index("day-navigation-runtime.js"), "Boundary planner loads before Day navigation binding")
    require(script_refs.index("day-navigation-runtime.js") < script_refs.index("refined-ui-v2.js"), "Refined UI loads after Day behavior")
    require(script_refs.index("refined-ui-v2.js") < script_refs.index("stability-runtime.js"), "Stability runtime loads last")
require("loadCoreEnhancement" not in day_nav, "Day navigation no longer dynamically reinjects core modules")

for marker in ['expose("prefs"', 'expose("events"', 'expose("places"', 'expose("nativeState"', 'expose("selectedDate"']:
    require(marker in global_bridge, f"Global bridge exposes state: {marker}")
for loader in BROWSER_FILES:
    require(f'loadPreviewScript("{loader}")' in preview, f"Web preview loads: {loader}")

# Authentication / security.
require("username + 4-digit PIN" in auth, "Authentication remains username + 4-digit PIN")
require("PBKDF2" in auth, "Browser PIN uses PBKDF2 derivation")
require("liferoute_auth_browser_v2" in auth, "Current local auth storage version present")
all_code = "\n".join(text(path) for path in sorted(WEB.rglob("*.js"))) + "\n" + preview + "\n" + swift
require("PREVIEW_CODE" not in all_code and "246810" not in all_code, "Obsolete SMS preview code absent")
require(not re.search(r"client_secret\s*[:=]", all_code, flags=re.I), "No OAuth client secret embedded in app code")

# Day navigation / routing.
for marker in ["dayPrevButton", "dayTodayButton", "dayNextButton"]:
    require(marker in index, f"Day navigation control present: {marker}")
require("restoreScrollPosition" in day_nav, "Day arrows preserve viewport")
require('return "Tomorrow"' in day_nav and 'return "Next"' in day_nav, "Relative Day labels retained")
require("setSelectedKey" in day_nav, "Day navigation updates shared selected-day state")
require("lifeRouteChooseRouteOrigin" in day_route, "Saved-place directions use origin chooser")
require("Live location" in day_route and "Home" in day_route and "clientOrigins" in day_route, "Directions origin choices include live, home, and clients")
require("data-lr-boundary-open" in day_route, "Before/after Find a stop buttons expose stable delegated action")
require("BEFORE FIRST" in day_route and "AFTER LAST" in day_route, "Before/after boundary slots retained")
require("Stop on the way home" in day_route, "After-last boundary wording is clear")
require("storeRequests" not in day_route and "loadBoundaryStores" not in day_route, "Old duplicate boundary-store implementation removed")

# Mid-day gap planning.
require("liferoute_selected_gap_routes_v2" in selected_gap, "Mid-day selected routes persist")
require("restoreGapScroll" in selected_gap, "Mid-day chosen routes preserve viewport")
require("planLifeRouteGapRoute" in selected_gap, "Mid-day gap choices save into Day")
require("Open route" in selected_gap and "Change" in selected_gap, "Selected mid-day stops remain navigable/editable")
for marker in ["Saved places", "planLifeRouteGapRoute", "requestRouteTimes", "lrSavedPlaceGapSection"]:
    require(marker in saved_place_gap, f"Saved Places gap capability: {marker}")

# Before-first / after-last planner.
for marker in [
    "liferoute_boundary_stops_v2",
    "lifeRouteOpenBoundaryPlanner",
    "data-lr-boundary-open",
    "data-boundary-place",
    "data-boundary-todo",
    "data-boundary-stores",
    "Search stores",
    "Nearby branches",
    "requestRouteTimes",
    "searchStoreLocations",
    "Open route",
    "Change",
]:
    require(marker in boundary, f"Boundary planner capability: {marker}")
require('document.addEventListener("click", handleClick, true)' in boundary, "Boundary planner uses stable delegated click handling")
require("routeReadyPlaces" in boundary and "routeReadyTodos" in boundary, "Boundary chooser includes Saved Places and route-ready errands")
require("placesState()" in boundary and "todosState()" in boundary, "Boundary planner reads live shared state")
require("restoreScroll" in boundary, "Changing a boundary stop preserves viewport")
require("Store search unavailable" in boundary and "Search timed out" in boundary, "Boundary store search never fails silently")

# Web route/store resilience.
for marker in ["requestRouteTimes", "searchStoreLocations", "requestCurrentLocation", "OSRM_URL", "NOMINATIM_URL"]:
    require(marker in route_bridge, f"Web routing capability: {marker}")
require("web-nominatim-fallback" in store_fallback, "Store search has Nominatim fallback")
require("fallback(requestID)" in store_fallback, "Empty/stalled store search triggers fallback")
require("6500" in store_fallback, "Store fallback activates after bounded primary wait")
for marker in [
    "requestRouteTimes", "searchStoreLocations", "requestCurrentLocation", "CLLocationManagerDelegate",
    "openRoute", "routeTransportType", "scheduleDayNotifications", "authSetCredentials", "authVerifyCredentials",
]:
    require(marker in swift, f"Native bridge capability: {marker}")

# Stability / performance guardrails.
for marker in [
    "overscroll-behavior-y:none",
    "lifeRouteStableRefreshCalendars",
    "lifeRouteStableOptimizeWeek",
    'data-life-route-runtime="native"',
]:
    require(marker in stability, f"Stability runtime capability: {marker}")
require("stability-runtime.js" in prepare and "patch_stability.py" in prepare, "Prepared build includes stability runtime and patch")

# Google Calendar / appearance / resources / tools.
google = text(WEB / "google-calendar-web.js")
google_persist = text(WEB / "google-calendar-persistence-web.js")
require("calendar.readonly" in google, "Google Calendar remains read-only")
require("apps.googleusercontent.com" in google, "Google web OAuth client ID remains configured")
require("Restoring Google Calendar" in google_persist, "Google Calendar reconnect restoration retained")
require("access token or refresh token" in google_persist, "Google persistence avoids local token storage")
require("Metallic Wave" in settings, "Metallic Wave theme family retained")
require("Scenery" in dynamic, "Scenery theme family retained")
require("Dynamic" in dynamic, "Dynamic theme family retained")
require("Unsplash photography" in photo, "Photoreal scenery layer retained")
require("CentralReach" in resources and "ADP" in resources, "Resources hub retained")
require("choiceBoardTool" in visuals and "firstThenFirstMode" in visuals, "RBT visual tools retained")
require((WEB / "assets" / "visuals" / "table-work.jpg").is_file(), "Table-work visual asset retained")
require((WEB / "assets" / "visuals" / "outside.jpg").is_file(), "Outside visual asset retained")

# UI refinement.
require("position:relative!important" in refined and "Back stays in document flow" in refined, "Back navigation cannot float over Day cards")
require("#webPreviewBadge span{display:none" in refined, "Mobile web preview banner is compact")
require("Ranked by fit, route, priority, and due date." in refined, "Gap helper copy is simplified")
for glyph in ["🚙", "🚗", "🚘"]:
    require(glyph not in index, f"Prepared UI has no legacy transport emoji: {glyph}")

# Workflow / release safety.
pages = text(PAGES)
ios_ci = text(IOS_CI)
testflight = text(TESTFLIGHT)
auto_testflight = text(AUTO_TESTFLIGHT)

require("python3 scripts/audit_liferoute_build.py" in pages, "Pages runs full regression audit")
require("python3 scripts/audit_liferoute_build.py" in ios_ci, "iOS CI runs full regression audit")
require("Full LifeRoute regression audit" in testflight and "python3 scripts/audit_liferoute_build.py" in testflight, "TestFlight releases are gated by full audit")
require("workflow_dispatch" in testflight, "TestFlight remains manually dispatchable")
require(not re.search(r"^\s*push\s*:", testflight, flags=re.M), "TestFlight has no direct automatic push trigger")

# Automatic release dispatcher: only a successful, current main CI build may
# trigger the manually-dispatchable TestFlight workflow. This keeps the release
# path automatic without bypassing the full regression audit.
require(AUTO_TESTFLIGHT.is_file(), "Automatic TestFlight dispatcher exists")
require('workflows: ["iOS Build Check"]' in auto_testflight, "Auto-TestFlight waits for iOS Build Check")
require("github.event.workflow_run.conclusion == 'success'" in auto_testflight, "Auto-TestFlight requires successful CI")
require("github.event.workflow_run.head_branch == 'main'" in auto_testflight, "Auto-TestFlight only releases main")
require("CURRENT_SHA" in auto_testflight and "VALIDATED_SHA" in auto_testflight, "Auto-TestFlight rejects stale validated commits")
require("gh workflow run testflight.yml" in auto_testflight, "Auto-TestFlight dispatches the audited TestFlight workflow")
require("actions: write" in auto_testflight and "contents: read" in auto_testflight, "Auto-TestFlight has minimal required permissions")

try:
    json.loads((WEB / "manifest.webmanifest").read_text(encoding="utf-8"))
    require(True, "Web manifest JSON is valid")
except Exception as exc:
    errors.append(f"Web manifest JSON is valid ({exc})")

require((ROOT / "LifeRoute.xcodeproj" / "project.pbxproj").is_file(), "Xcode project exists")
require((ROOT / "LifeRoute" / "Info.plist").is_file(), "Info.plist exists")

print(f"LifeRoute audit: {len(checks)} checks passed, {len(errors)} failed")
if errors:
    for error in errors:
        print(f"FAIL: {error}")
    raise SystemExit(1)
print("LifeRoute full regression audit passed.")
