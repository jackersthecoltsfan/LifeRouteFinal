set -euo pipefail

# Apply native/runtime features in a deterministic order.
python3 scripts/patch_route_times.py
python3 scripts/patch_location_context.py
python3 scripts/patch_transport_mode.py
python3 scripts/patch_store_route_guard.py

python3 - <<'PY'
from pathlib import Path

path = Path("LifeRoute/Web/index.html")
html = path.read_text()
tags = [
    '<script src="route-times.js"></script>',
    '<script src="smart-context.js"></script>',
    '<script src="todos.js"></script>',
    '<script src="grocery-stores.js"></script>',
    '<script src="transport-mode.js"></script>',
    '<script src="sleek-ui.js"></script>',
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
python3 -m py_compile scripts/patch_route_times.py scripts/patch_location_context.py scripts/patch_transport_mode.py scripts/patch_store_route_guard.py
plutil -lint LifeRoute/Info.plist
for js in route-times.js smart-context.js todos.js grocery-stores.js transport-mode.js sleek-ui.js; do
  test -s "LifeRoute/Web/$js"
  node --check "LifeRoute/Web/$js"
  grep -q "<script src=\"$js\"></script>" LifeRoute/Web/index.html
done
grep -q 'requestRouteTimes' LifeRoute/LifeRouteWebView.swift
grep -q 'searchStoreLocations' LifeRoute/LifeRouteWebView.swift
grep -q 'requestCurrentLocation' LifeRoute/LifeRouteWebView.swift
grep -q 'CLLocationManagerDelegate' LifeRoute/LifeRouteWebView.swift
grep -q 'routeTransportType' LifeRoute/LifeRouteWebView.swift
grep -q 'ownedResults' LifeRoute/Web/route-times.js
echo "LifeRoute feature preflight passed."
