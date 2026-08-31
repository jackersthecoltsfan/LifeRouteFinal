#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:?usage: run_simulator_smoke.sh APP_PATH OUTPUT_DIRECTORY}"
OUTPUT_DIRECTORY="${2:?usage: run_simulator_smoke.sh APP_PATH OUTPUT_DIRECTORY}"
BUNDLE_ID="Com.Brandongood.LifeRoute"

test -d "$APP_PATH"
mkdir -p "$OUTPUT_DIRECTORY"

bash "$(cd "$(dirname "$0")" && pwd)/run_session_note_contract_tests.sh"
bash "$(cd "$(dirname "$0")" && pwd)/run_day_route_contract_tests.sh"
bash "$(cd "$(dirname "$0")" && pwd)/run_visual_timer_feedback_contract_tests.sh"
bash "$(cd "$(dirname "$0")" && pwd)/run_runtime_feedback_contract_tests.sh"
bash "$(cd "$(dirname "$0")" && pwd)/run_scenery_effect_contract_tests.sh"

DEVICE_ID="$(xcrun simctl list --json devices available | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
preferred = []
fallback = []
for runtime, entries in devices.items():
    if "iOS" not in runtime:
        continue
    for device in entries:
        if not device.get("isAvailable") or not device.get("name", "").startswith("iPhone"):
            continue
        fallback.append(device["udid"])
        if "Pro" in device.get("name", ""):
            preferred.append(device["udid"])
print((preferred or fallback)[0])
')"
test -n "$DEVICE_ID"

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

launch_section() {
  local section="$1"
  xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" \
    -LifeRouteSectionOverride "$section"
  sleep 2
  xcrun simctl io "$DEVICE_ID" screenshot "$OUTPUT_DIRECTORY/${section}.png"
}

# These launches cover the five independent root stacks. Today and schedule
# supply the Today/calendar smoke; tools supplies the ABA/Visual Timer entry
# surface; repeated app launches exercise persisted-state restoration.
for section in today schedule tools resources setup; do
  launch_section "$section"
done

# Exercise the Visual Timer deep destination under its bounded local renderer.
xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" \
  -LifeRouteSectionOverride tools \
  -LifeRouteToolsDestinationOverride visualTimer \
  -LifeRouteVisualTimerAutoStart
sleep 3
xcrun simctl io "$DEVICE_ID" screenshot "$OUTPUT_DIRECTORY/visual-timer-running.png"

# Exercise the exact Build 120 Day/Night environment matrix without activating
# the quarantined WebView runtime. Each launch uses the same persistent host.
SCENERY_THEMES=(
  scenery.mountains.day scenery.mountains.night
  scenery.ocean.day scenery.ocean.night
  scenery.desert.day scenery.desert.night
  scenery.rainforest.day scenery.rainforest.night
  scenery.canyon.day scenery.canyon.night
  scenery.arctic.day scenery.arctic.night
)
for theme in "${SCENERY_THEMES[@]}"; do
  filename="${theme//./-}"
  xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" \
    -LifeRouteVisualFixture "$theme"
  sleep 2
  xcrun simctl io "$DEVICE_ID" screenshot "$OUTPUT_DIRECTORY/${filename}.png"
done

# Verify both the restrained Dynamic treatment and its Reduce Motion state.
xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" \
  -LifeRouteVisualFixture royal-current
sleep 2
xcrun simctl io "$DEVICE_ID" screenshot "$OUTPUT_DIRECTORY/theme-dynamic-motion.png"
xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" \
  -LifeRouteVisualFixture royal-current -LifeRouteFixtureReduceMotion
sleep 2
xcrun simctl io "$DEVICE_ID" screenshot "$OUTPUT_DIRECTORY/theme-reduce-motion.png"

# Ordinary glass must remain visually inspectable over real scenery, not only
# in an empty backdrop fixture.
xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" \
  -LifeRouteThemeOverride scenery.canyon.day \
  -LifeRouteSectionOverride today
sleep 3
xcrun simctl io "$DEVICE_ID" screenshot "$OUTPUT_DIRECTORY/ordinary-glass-today.png"

echo "LifeRoute simulator smoke passed on $DEVICE_ID."
