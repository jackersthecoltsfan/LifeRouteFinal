set -euo pipefail

# Apply native/runtime patches in a deterministic order. The source files remain
# readable; build-time patches only add platform bridge behavior and stable markup.
PATCHES=(
  patch_route_times.py
  patch_location_context.py
  patch_transport_mode.py
  patch_store_route_guard.py
  patch_store_routing_resilience.py
  patch_store_mapitems.py
  patch_route_reliability_v2.py
  patch_route_reliability_v3.py
  patch_gap_multistop.py
  patch_route_origin_choice.py
  patch_selected_gap_routes.py
  patch_live_day.py
  patch_rbt_tools.py
  patch_sleek_icons.py
  patch_provider_selection.py
  patch_day_navigation.py
  patch_auth_gate.py
)
for patch in "${PATCHES[@]}"; do
  python3 "scripts/$patch"
done

# Normalize all core feature scripts into ONE startup order. Some older patch
# scripts still inject their own tags for backwards compatibility; remove every
# known core tag first, then append the canonical list once.
python3 - <<'PY'
from pathlib import Path

path = Path("LifeRoute/Web/index.html")
html = path.read_text()
core = [
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
]

if "</body>" not in html:
    raise SystemExit("Could not inject LifeRoute feature scripts: </body> not found")

for name in core:
    tag = f'<script src="{name}"></script>'
    html = html.replace(tag, "")

html = html.replace(
    "</body>",
    "\n".join(f'<script src="{name}"></script>' for name in core) + "\n</body>",
    1,
)
path.write_text(html)
print("LifeRoute core scripts normalized into one deterministic startup order.")
PY

# Fast build preflight. The deeper regression audit runs immediately after this
# in both Pages and iOS CI (and before any future TestFlight archive).
python3 -m py_compile scripts/*.py
plutil -lint LifeRoute/Info.plist

CORE_JS=(
  global-bridge.js calendar-hub.js auth-gate.js icons.js route-times.js smart-context.js
  todos.js grocery-stores.js transport-mode.js sleek-ui.js store-sleek-ui.js
  selected-gap-routes.js saved-place-gap-options.js live-day.js rbt-tools.js
  visual-resolver.js visual-tools.js visual-resolver-bridge.js live-themes.js
  day-route-experience.js boundary-stop-planner.js day-navigation-runtime.js refined-ui-v2.js
)
for js in "${CORE_JS[@]}"; do
  test -s "LifeRoute/Web/$js"
  node --check "LifeRoute/Web/$js"
  grep -q "<script src=\"$js\"></script>" LifeRoute/Web/index.html
done

BROWSER_JS=(
  welcome.js nav-cleanup.js icloud-calendar-web.js google-calendar-web.js
  google-calendar-stability.js google-calendar-persistence-web.js first-then-back.js
  visual-quality-web.js photo-source-picker-web.js end-home-route-web.js
  mileage-tracker-web.js resources-hub-web.js nature-settings-web.js
  settings-classic-themes-web.js photoreal-nature-web.js dynamic-themes-web.js
  web-routing-bridge.js web-store-search-fallback.js
)
for js in "${BROWSER_JS[@]}"; do
  test -s "LifeRoute/Web/$js"
  node --check "LifeRoute/Web/$js"
done

# Critical native bridge contracts.
for marker in \
  requestRouteTimes searchStoreLocations requestCurrentLocation CLLocationManagerDelegate \
  openRoute routeTransportType scheduleDayNotifications authSetCredentials authVerifyCredentials; do
  grep -q "$marker" LifeRoute/LifeRouteWebView.swift
done

# Critical Day/gap contracts.
grep -q 'class="lrDayPager"' LifeRoute/Web/index.html
grep -q 'id="dayPrevButton"' LifeRoute/Web/index.html
grep -q 'id="dayTodayButton"' LifeRoute/Web/index.html
grep -q 'id="dayNextButton"' LifeRoute/Web/index.html
grep -q 'data-lr-boundary-open' LifeRoute/Web/day-route-experience.js
grep -q 'lifeRouteOpenBoundaryPlanner' LifeRoute/Web/boundary-stop-planner.js
grep -q 'liferoute_boundary_stops_v2' LifeRoute/Web/boundary-stop-planner.js
grep -q 'planLifeRouteGapRoute' LifeRoute/Web/selected-gap-routes.js
grep -q 'Saved places' LifeRoute/Web/saved-place-gap-options.js

echo "LifeRoute feature preflight passed."