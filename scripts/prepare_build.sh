set -euo pipefail

# Apply native/runtime features in a deterministic order.
python3 scripts/patch_route_times.py
python3 scripts/patch_location_context.py
python3 scripts/patch_transport_mode.py
python3 scripts/patch_store_route_guard.py
python3 scripts/patch_store_routing_resilience.py
python3 scripts/patch_store_mapitems.py
python3 scripts/patch_route_reliability_v2.py
python3 scripts/patch_route_reliability_v3.py
python3 scripts/patch_gap_multistop.py
python3 scripts/patch_route_origin_choice.py
python3 scripts/patch_selected_gap_routes.py
python3 scripts/patch_live_day.py
python3 scripts/patch_rbt_tools.py
python3 scripts/patch_sleek_icons.py
python3 scripts/patch_provider_selection.py
python3 scripts/patch_auth_gate.py

python3 - <<'PY'
from pathlib import Path

path = Path("LifeRoute/Web/index.html")
html = path.read_text()
tags = [
    '<script src="auth-gate.js"></script>',
    '<script src="icons.js"></script>',
    '<script src="route-times.js"></script>',
    '<script src="smart-context.js"></script>',
    '<script src="todos.js"></script>',
    '<script src="grocery-stores.js"></script>',
    '<script src="transport-mode.js"></script>',
    '<script src="sleek-ui.js"></script>',
    '<script src="store-sleek-ui.js"></script>',
    '<script src="selected-gap-routes.js"></script>',
    '<script src="live-day.js"></script>',
    '<script src="rbt-tools.js"></script>',
    '<script src="visual-resolver.js"></script>',
    '<script src="visual-tools.js"></script>',
    '<script src="visual-resolver-bridge.js"></script>',
    '<script src="live-themes.js"></script>',
]

if "</body>" not in html:
    raise SystemExit("Could not inject LifeRoute feature scripts: </body> not found")

for tag in tags:
    html = html.replace(tag, "")
html = html.replace("</body>", "\n".join(tags) + "\n</body>", 1)
path.write_text(html)
print("LifeRoute feature scripts enabled in safe startup order.")
PY

# Fast preflight checks before Xcode spends time compiling.
python3 -m py_compile scripts/patch_route_times.py scripts/patch_location_context.py scripts/patch_transport_mode.py scripts/patch_store_route_guard.py scripts/patch_store_routing_resilience.py scripts/patch_store_mapitems.py scripts/patch_route_reliability_v2.py scripts/patch_route_reliability_v3.py scripts/patch_gap_multistop.py scripts/patch_route_origin_choice.py scripts/patch_selected_gap_routes.py scripts/patch_live_day.py scripts/patch_rbt_tools.py scripts/patch_sleek_icons.py scripts/patch_provider_selection.py scripts/patch_auth_gate.py
plutil -lint LifeRoute/Info.plist
for js in auth-gate.js icons.js route-times.js smart-context.js todos.js grocery-stores.js transport-mode.js sleek-ui.js store-sleek-ui.js selected-gap-routes.js live-day.js rbt-tools.js visual-resolver.js visual-tools.js visual-resolver-bridge.js live-themes.js; do
  test -s "LifeRoute/Web/$js"
  node --check "LifeRoute/Web/$js"
  grep -q "<script src=\"$js\"></script>" LifeRoute/Web/index.html
done
# Browser-only welcome code is loaded dynamically by the Pages preview, so validate
# the file itself here without requiring it to be injected into the native app HTML.
test -s "LifeRoute/Web/welcome.js"
node --check "LifeRoute/Web/welcome.js"

grep -q 'requestRouteTimes' LifeRoute/LifeRouteWebView.swift
grep -q 'searchStoreLocations' LifeRoute/LifeRouteWebView.swift
grep -q 'requestCurrentLocation' LifeRoute/LifeRouteWebView.swift
grep -q 'CLLocationManagerDelegate' LifeRoute/LifeRouteWebView.swift
grep -q 'routeTransportType' LifeRoute/LifeRouteWebView.swift
grep -q 'retryResponse' LifeRoute/LifeRouteWebView.swift
grep -q 'mapItemKey' LifeRoute/LifeRouteWebView.swift
grep -q 'resilientRoute' LifeRoute/LifeRouteWebView.swift
grep -q 'routeMapItemCandidates' LifeRoute/LifeRouteWebView.swift
grep -q 'approximateRouteFallback' LifeRoute/LifeRouteWebView.swift
grep -q 'map-distance-estimate' LifeRoute/LifeRouteWebView.swift
grep -q 'waypoints' LifeRoute/LifeRouteWebView.swift
grep -q 'ownedResults' LifeRoute/Web/route-times.js
grep -q 'seenBranches' LifeRoute/Web/grocery-stores.js
grep -q 'destinationMapItemKey' LifeRoute/Web/grocery-stores.js
grep -q 'routeGapStop(encodedStop,encodedFinal,encodedOrigin' LifeRoute/Web/index.html
grep -q 'planLifeRouteGapRoute' LifeRoute/Web/todos.js
grep -q 'planLifeRouteGapRoute' LifeRoute/Web/grocery-stores.js
grep -q 'outDistanceMeters' LifeRoute/Web/todos.js
grep -q 'gapRouteStartPlanner' LifeRoute/Web/selected-gap-routes.js
grep -q 'decorateLifeRouteSelectedGaps' LifeRoute/Web/selected-gap-routes.js
grep -q 'generateLifeRouteDay' LifeRoute/Web/live-day.js
grep -q 'scheduleDayNotifications' LifeRoute/LifeRouteWebView.swift
grep -q 'dayNotificationsStatus' LifeRoute/LifeRouteWebView.swift
grep -q 'fieldToolStyles' LifeRoute/Web/rbt-tools.js
grep -q 'visualTimerOverlay' LifeRoute/Web/rbt-tools.js
grep -q 'sessionPlanOutput' LifeRoute/Web/rbt-tools.js
grep -q 'visualIconTool' LifeRoute/Web/visual-tools.js
grep -q 'firstThenFirstMode' LifeRoute/Web/visual-tools.js
grep -q 'firstThenThenMode' LifeRoute/Web/visual-tools.js
grep -q 'makeAutoFirstThenVisual' LifeRoute/Web/visual-tools.js
grep -q 'REAL_IMAGE_VISUALS' LifeRoute/Web/visual-tools.js
grep -q 'LifeRouteVisualResolver' LifeRoute/Web/visual-resolver.js
grep -q 'commons.wikimedia.org' LifeRoute/Web/visual-resolver.js
grep -q 'LifeRouteSmartVisuals' LifeRoute/Web/visual-resolver-bridge.js
grep -q 'publicPhotoFallback' LifeRoute/Web/visual-resolver-bridge.js
grep -q 'Wrong is worse than blank' LifeRoute/Web/visual-resolver-bridge.js
test -s "LifeRoute/Web/assets/visuals/table-work.jpg"
test -s "LifeRoute/Web/assets/visuals/outside.jpg"
file "LifeRoute/Web/assets/visuals/table-work.jpg" | grep -q "JPEG image data"
file "LifeRoute/Web/assets/visuals/outside.jpg" | grep -q "JPEG image data"
grep -q 'choiceBoardTool' LifeRoute/Web/visual-tools.js
grep -q 'visual-resolver.js' LifeRoute/Web/index.html
grep -q 'visual-tools.js' LifeRoute/Web/index.html
grep -q 'visual-resolver-bridge.js' LifeRoute/Web/index.html
grep -q 'scheduleToolTimer' LifeRoute/LifeRouteWebView.swift
grep -q 'outMinutes' LifeRoute/Web/selected-gap-routes.js
grep -q 'lifeRouteMetalBackdrop' LifeRoute/Web/live-themes.js
grep -q 'requestAnimationFrame(animate)' LifeRoute/Web/live-themes.js
grep -q 'metalWave' LifeRoute/Web/live-themes.js
grep -q 'provider.active:after' LifeRoute/Web/sleek-ui.js
grep -q 'storeSleekUIStyles' LifeRoute/Web/store-sleek-ui.js
grep -q 'lifeRouteIcon' LifeRoute/Web/icons.js
grep -q 'iconName: "car"' LifeRoute/Web/transport-mode.js
grep -q 'lifeRouteIcon("car"' LifeRoute/Web/route-times.js
! grep -q '🚙' LifeRoute/Web/route-times.js
grep -q 'authSetCredentials' LifeRoute/LifeRouteWebView.swift
grep -q 'authVerifyCredentials' LifeRoute/LifeRouteWebView.swift
grep -q 'authKeychainService' LifeRoute/LifeRouteWebView.swift
grep -q 'normalizedAuthUsername' LifeRoute/LifeRouteWebView.swift
grep -q 'PBKDF2' LifeRoute/Web/auth-gate.js
grep -q 'validUsername' LifeRoute/Web/auth-gate.js
! grep -q 'PREVIEW_CODE' LifeRoute/Web/auth-gate.js
echo "LifeRoute feature preflight passed."
