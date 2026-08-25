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


required_files = [
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
    "live-day.js",
    "rbt-tools.js",
    "visual-resolver.js",
    "visual-tools.js",
    "visual-resolver-bridge.js",
    "live-themes.js",
    "day-route-experience.js",
    "day-navigation-runtime.js",
    "boundary-stop-planner.js",
    "refined-ui-v2.js",
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
for name in required_files:
    require((WEB / name).is_file() and (WEB / name).stat().st_size > 0, f"Required feature file: {name}")

# Syntax-check every JS file, not just a hand-picked subset.
node = shutil.which("node")
require(bool(node), "Node.js available for JavaScript syntax audit")
if node:
    for path in sorted(WEB.rglob("*.js")):
        proc = subprocess.run([node, "--check", str(path)], capture_output=True, text=True)
        require(proc.returncode == 0, f"JavaScript syntax: {path.relative_to(ROOT)}")
        if proc.returncode != 0:
            errors.append((proc.stderr or proc.stdout).strip())

# Syntax-check every Python build/patch script.
for path in sorted(SCRIPTS.glob("*.py")):
    proc = subprocess.run([sys.executable, "-m", "py_compile", str(path)], capture_output=True, text=True)
    require(proc.returncode == 0, f"Python syntax: {path.relative_to(ROOT)}")
    if proc.returncode != 0:
        errors.append((proc.stderr or proc.stdout).strip())

index = text(INDEX)
preview = text(WEB_PREVIEW)
swift = text(SWIFT)
auth = text(WEB / "auth-gate.js")
day_nav = text(WEB / "day-navigation-runtime.js")
boundary = text(WEB / "boundary-stop-planner.js")
selected_gap = text(WEB / "selected-gap-routes.js")
settings = text(WEB / "settings-classic-themes-web.js")
dynamic = text(WEB / "dynamic-themes-web.js")
photo = text(WEB / "photoreal-nature-web.js")
resources = text(WEB / "resources-hub-web.js")
visuals = text(WEB / "visual-tools.js")

# Prepared HTML must contain the current core runtime.
for marker in [
    'auth-gate.js', 'icons.js', 'route-times.js', 'todos.js', 'grocery-stores.js',
    'selected-gap-routes.js', 'rbt-tools.js', 'visual-tools.js', 'live-themes.js',
    'day-route-experience.js', 'day-navigation-runtime.js'
]:
    require(marker in index, f"Prepared HTML loads core feature: {marker}")

# New core enhancement modules are loaded by the stable Day runtime so both web
# preview and native WKWebView use the same implementation.
require('boundary-stop-planner.js' in day_nav, "Day runtime loads persistent boundary-stop planner")
require('refined-ui-v2.js' in day_nav, "Day runtime loads refined UI layer")

# Every literal local script src in prepared HTML must resolve to a file.
script_refs = re.findall(r'<script[^>]+src=["\']([^"\']+\.js)(?:\?[^"\']*)?["\']', index, flags=re.I)
for ref in script_refs:
    if ref.startswith(("http://", "https://")):
        continue
    require((WEB / ref).is_file(), f"Local script reference resolves: {ref}")
counts = Counter(script_refs)
for ref, count in counts.items():
    require(count == 1, f"No duplicate prepared script tag: {ref}")

# Browser-only feature loader inventory: catch silent regressions where a file
# still exists but is no longer loaded.
preview_loaders = [
    "web-routing-bridge.js", "web-store-search-fallback.js", "welcome.js", "nav-cleanup.js",
    "icloud-calendar-web.js", "google-calendar-web.js", "google-calendar-stability.js",
    "google-calendar-persistence-web.js", "first-then-back.js", "visual-quality-web.js",
    "photo-source-picker-web.js", "end-home-route-web.js", "mileage-tracker-web.js",
    "resources-hub-web.js", "nature-settings-web.js", "settings-classic-themes-web.js",
    "photoreal-nature-web.js", "dynamic-themes-web.js"
]
for loader in preview_loaders:
    require(f'loadPreviewScript("{loader}")' in preview, f"Web preview loads: {loader}")

# Authentication and security invariants.
require("username + 4-digit PIN" in auth, "Authentication remains username + 4-digit PIN")
require("PBKDF2" in auth, "Browser PIN uses PBKDF2 derivation")
require("liferoute_auth_browser_v2" in auth, "Current local auth storage version present")
all_code = "\n".join(text(path) for path in sorted(WEB.rglob("*.js"))) + "\n" + preview + "\n" + swift
require("PREVIEW_CODE" not in all_code and "246810" not in all_code, "Obsolete SMS preview code absent")
require(not re.search(r"client_secret\s*[:=]", all_code, flags=re.I), "No OAuth client secret embedded in app code")

# Day navigation and scroll-preservation invariants.
for marker in ["dayPrevButton", "dayTodayButton", "dayNextButton"]:
    require(marker in index, f"Day navigation control present: {marker}")
require("restoreScrollPosition" in day_nav, "Day arrows preserve viewport")
require('return "Tomorrow"' in day_nav and 'return "Next"' in day_nav, "Relative Day labels retained")
require("restoreGapScroll" in selected_gap, "Mid-day chosen routes preserve viewport")

# Gap planning and boundary-stop behavior.
require("liferoute_selected_gap_routes_v2" in selected_gap, "Mid-day selected routes persist")
require("liferoute_boundary_stops_v1" in boundary, "Before/after-day selected stops persist")
require("data-boundary-place" in boundary and "Add to Day" in boundary, "Saved Places can be added to Day boundary slots")
require("searchStoreLocations" in boundary and "Nearby stores" in boundary, "Boundary store search and results UI present")
require("requestRouteTimes" in boundary, "Boundary stores request route metrics")
require("Open route" in boundary and "Change" in boundary, "Planned boundary stop remains editable/navigable")

# Web routing/store resilience.
web_route = text(WEB / "web-routing-bridge.js")
store_fallback = text(WEB / "web-store-search-fallback.js")
for marker in ["requestRouteTimes", "searchStoreLocations", "requestCurrentLocation", "OSRM_URL", "NOMINATIM_URL"]:
    require(marker in web_route, f"Web routing capability: {marker}")
require("web-nominatim-fallback" in store_fallback, "Store search has Nominatim fallback")
require("fallback(requestID)" in store_fallback, "Empty/stalled store search triggers fallback")

# Native bridge capabilities required by the same UI.
for marker in [
    "requestRouteTimes", "searchStoreLocations", "requestCurrentLocation", "CLLocationManagerDelegate",
    "openRoute", "routeTransportType", "scheduleDayNotifications", "authSetCredentials", "authVerifyCredentials"
]:
    require(marker in swift, f"Native bridge capability: {marker}")

# Appearance/resources/tooling inventory.
require("Metallic Wave" in settings, "Metallic Wave theme family retained")
require("Scenery" in dynamic, "Scenery theme family retained")
require("Dynamic" in dynamic, "Dynamic theme family retained")
require("Unsplash photography" in photo, "Photoreal scenery layer retained")
require("CentralReach" in resources and "ADP" in resources, "Resources hub retained")
require("choiceBoardTool" in visuals and "firstThenFirstMode" in visuals, "RBT visual tools retained")
require((WEB / "assets" / "visuals" / "table-work.jpg").is_file(), "Table-work visual asset retained")
require((WEB / "assets" / "visuals" / "outside.jpg").is_file(), "Outside visual asset retained")

# The prepared build should no longer contain emoji transport glyphs that were
# replaced by the vector icon system.
for glyph in ["🚙", "🚗", "🚘"]:
    require(glyph not in index, f"Prepared UI has no legacy transport emoji: {glyph}")

# Manifest must remain valid JSON.
manifest = WEB / "manifest.webmanifest"
try:
    json.loads(manifest.read_text(encoding="utf-8"))
    require(True, "Web manifest JSON is valid")
except Exception as exc:
    errors.append(f"Web manifest JSON is valid ({exc})")

# Project/build essentials.
require((ROOT / "LifeRoute.xcodeproj" / "project.pbxproj").is_file(), "Xcode project exists")
require((ROOT / "LifeRoute" / "Info.plist").is_file(), "Info.plist exists")

print(f"LifeRoute audit: {len(checks)} checks passed, {len(errors)} failed")
if errors:
    for error in errors:
        print(f"FAIL: {error}")
    raise SystemExit(1)
print("LifeRoute full regression audit passed.")
