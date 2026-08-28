#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:?Usage: capture_v0_7_1_visual_fixtures.sh APP_PATH OUTPUT_DIR}"
OUTPUT_DIR="${2:?Usage: capture_v0_7_1_visual_fixtures.sh APP_PATH OUTPUT_DIR}"
BUNDLE_ID="Com.Brandongood.LifeRoute"

test -d "$APP_PATH"
mkdir -p "$OUTPUT_DIR"

SIMULATOR_JSON="$(xcrun simctl list devices available -j)"
SIMULATOR_ID="$({ printf '%s' "$SIMULATOR_JSON"; } | python3 -c '
import json, sys
data = json.load(sys.stdin)
candidates = []
for runtime, devices in data.get("devices", {}).items():
    if ".iOS-" not in runtime:
        continue
    for device in devices:
        if device.get("isAvailable") and device.get("name", "").startswith("iPhone"):
            candidates.append((runtime, device))
if not candidates:
    raise SystemExit("No available iPhone Simulator found")
candidates.sort(
    key=lambda item: (
        item[1].get("state") == "Booted",
        "Pro" in item[1].get("name", ""),
        item[0],
        item[1].get("name", ""),
    ),
    reverse=True,
)
print(candidates[0][1]["udid"])
')"

SIMULATOR_STATE="$(xcrun simctl list devices -j | python3 -c '
import json, sys
target = sys.argv[1]
data = json.load(sys.stdin)
for devices in data.get("devices", {}).values():
    for device in devices:
        if device.get("udid") == target:
            print(device.get("state", "Shutdown"))
            raise SystemExit(0)
raise SystemExit("Selected Simulator disappeared")
' "$SIMULATOR_ID")"

BOOTED_BY_SCRIPT=0
if [ "$SIMULATOR_STATE" != "Booted" ]; then
  xcrun simctl boot "$SIMULATOR_ID"
  BOOTED_BY_SCRIPT=1
fi

cleanup() {
  xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  if [ "$BOOTED_BY_SCRIPT" = "1" ]; then
    xcrun simctl shutdown "$SIMULATOR_ID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

xcrun simctl bootstatus "$SIMULATOR_ID" -b
xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
xcrun simctl ui "$SIMULATOR_ID" appearance dark
xcrun simctl status_bar "$SIMULATOR_ID" override \
  --time 9:41 --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularBars 4 >/dev/null 2>&1 || true

capture_environment() {
  local fixture="$1"
  local output="$2"
  xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID" -LifeRouteVisualFixture "$fixture"
  sleep 4
  xcrun simctl io "$SIMULATOR_ID" screenshot "$OUTPUT_DIR/$output"
}

capture_today() {
  local theme_id="$1"
  local output="$2"
  xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl spawn "$SIMULATOR_ID" defaults write "$BUNDLE_ID" liferoute.selectedTheme "$theme_id"
  xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"
  sleep 4
  xcrun simctl io "$SIMULATOR_ID" screenshot "$OUTPUT_DIR/$output"
}

capture_environment "canyon-day" "canyon-day.png"
capture_environment "royal-current" "royal-current.png"
capture_today "scenery.canyon.day" "today-canyon-day.png"
capture_today "dynamic.royalCurrent" "today-royal-current.png"

test -s "$OUTPUT_DIR/canyon-day.png"
test -s "$OUTPUT_DIR/royal-current.png"
test -s "$OUTPUT_DIR/today-canyon-day.png"
test -s "$OUTPUT_DIR/today-royal-current.png"

echo "Captured Canyon Day, Royal Current, Today + Canyon Day, and Today + Royal Current Simulator screenshots."
