from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
SEARCH = WEB / "stop-place-search-v4.js"
UI = WEB / "ui-simplify-v4.js"
FLUID = WEB / "fluid-scenes-v1.js"
INDEX = WEB / "index.html"
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"

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


search = read(SEARCH)
ui = read(UI)
fluid = read(FLUID)
index = read(INDEX)
swift = read(SWIFT)

# Search interaction ownership and rerender independence.
for marker in [
    "LifeRouteStopPlaceSearchV4",
    "lifeRouteStopSearchV4",
    'window.addEventListener("click"',
    'data-boundary-stores',
    'data-lr-place-search-open',
    'data-lr-stop-result',
    'lifeRouteSaveBoundaryStop',
    'PHOTON_URL',
    'NOMINATIM_URL',
    'browserSearch',
    'nativeSearch',
    'searchStoreLocations',
]:
    check(marker in search, f"search v4 capability: {marker}")
check("position:fixed" in search and "lrStopSearchOverlay" in search, "search results live outside rerendering Day timeline")
check("stopImmediatePropagation" in search, "search v4 owns store-search taps before legacy delegates")
check("Promise.allSettled" in search, "browser place search tolerates one provider failing")
check("No nearby matches" in search and "Search unavailable" in search, "search failures are visible instead of silent")
check("Search nearby places" in search, "Find-a-stop planner exposes general place search")

# Native path stays build-ready while web uses direct browser search.
check("searchStoreLocations" in swift, "native MapKit search bridge remains available")
check("requestRouteTimes" in swift, "native route-time bridge remains available")

# UI requirements from the audit pass.
check("#connectionStatus{display:none!important}" in ui, "Saved-to-Day/status pill is hidden globally")
check("Appointments, travel & stops." in ui, "Day hero copy is simplified")
check("Update day" in ui and 'setTextIfDifferent(end, "End")' in ui, "Live Day controls use concise copy")
check("End at Home" in ui and "Route home after last appointment." in ui, "End-home card copy is simplified")
check('content:"✓"' in ui and "lrThemeSelectedMark" in ui, "selected themes display check marks")

# Fluid screensaver section.
check("Fluid Motion" in fluid, "Fluid Motion settings section exists")
check("high-motion screensaver scenes" in fluid, "Fluid Motion section is clearly labeled")
check(fluid.count('["') >= 8, "Fluid Motion includes multiple scene choices")
check("lrFluidMorphA" in fluid and "lrFluidPulse" in fluid, "Fluid Motion uses high-motion animation")
check("prefers-reduced-motion" in fluid, "Fluid Motion honors reduced-motion accessibility")

# Privacy: production state must start empty and user-specific data must never be
# baked into runtime source as sample fixtures. Provider/local data may populate
# these arrays only at runtime on the user's own device/session.
check('let events=Array.isArray(saved.events)?saved.events:[];' in index, "events bootstrap from device storage or empty state")
check('let places=Array.isArray(saved.places)?saved.places:[];' in index, "places bootstrap from device storage or empty state")

runtime_text = "\n".join(read(path) for path in sorted(WEB.glob("*.js"))) + "\n" + index + "\n" + swift
for forbidden in [
    "600 Valley Rd",
    "9611 Cowden St",
    "Brandon Good",
]:
    check(forbidden.lower() not in runtime_text.lower(), f"no user-specific runtime fixture: {forbidden}")

# Preserve exact mixed-case client labels so generic English words like "life"
# do not create false positives.
for forbidden_code in ["JaHe", "LiFe"]:
    pattern = re.compile(rf"(?<![A-Za-z]){re.escape(forbidden_code)}(?![A-Za-z])")
    check(not pattern.search(runtime_text), f"no client code baked into runtime: {forbidden_code}")

print(f"LifeRoute stop/place + privacy audit: {len(passes)} passed, {len(failures)} failed")
if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(1)
print("LifeRoute stop/place search, UI, theme, and privacy audit passed.")
