#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:?Usage: capture_v0_7_1_visual_fixtures.sh APP_PATH OUTPUT_DIR}"
OUTPUT_DIR="${2:?Usage: capture_v0_7_1_visual_fixtures.sh APP_PATH OUTPUT_DIR}"
BUNDLE_ID="Com.Brandongood.LifeRoute"
COMPARE_SCRIPT="scripts/compare_v0_7_1_theme_fixtures.py"
TEXT_SCRIPT="scripts/validate_v0_7_1_fixture_text.swift"
ANALYSIS_DIR="${RUNNER_TEMP:-$OUTPUT_DIR}/liferoute-fixture-analysis"
export LIFEROUTE_FIXTURE_ANALYSIS_DIR="$ANALYSIS_DIR"

DYNAMIC_THEMES=(
  "dynamic.royalCurrent|dynamic-royal-current"
  "dynamic.midnightPrism|dynamic-midnight-prism"
  "dynamic.auroraBloom|dynamic-aurora-bloom"
  "dynamic.solarPulse|dynamic-solar-pulse"
  "dynamic.emeraldFlow|dynamic-emerald-flow"
  "dynamic.oceanGlass|dynamic-ocean-glass"
  "dynamic.obsidianSpectra|dynamic-obsidian-spectra"
  "dynamic.plasmaOrchid|dynamic-plasma-orchid"
)

SCENERY_THEMES=(
  "scenery.mountains.day|scenery-mountains-day"
  "scenery.mountains.night|scenery-mountains-night"
  "scenery.ocean.day|scenery-ocean-day"
  "scenery.ocean.night|scenery-ocean-night"
  "scenery.desert.day|scenery-desert-day"
  "scenery.desert.night|scenery-desert-night"
  "scenery.rainforest.day|scenery-rainforest-day"
  "scenery.rainforest.night|scenery-rainforest-night"
  "scenery.canyon.day|scenery-canyon-day"
  "scenery.canyon.night|scenery-canyon-night"
  "scenery.arctic.day|scenery-arctic-day"
  "scenery.arctic.night|scenery-arctic-night"
)

ALL_THEMES=("${DYNAMIC_THEMES[@]}" "${SCENERY_THEMES[@]}")
SCENERY_PAIRS=(
  "scenery-mountains-day|scenery-mountains-night"
  "scenery-ocean-day|scenery-ocean-night"
  "scenery-desert-day|scenery-desert-night"
  "scenery-rainforest-day|scenery-rainforest-night"
  "scenery-canyon-day|scenery-canyon-night"
  "scenery-arctic-day|scenery-arctic-night"
)

test -d "$APP_PATH"
test -f "$COMPARE_SCRIPT"
test -f "$TEXT_SCRIPT"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$ANALYSIS_DIR"

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

launch_pid() {
  local launch_output="$1"
  printf '%s\n' "$launch_output" >&2
  printf '%s' "${launch_output##*: }"
}

capture_standalone() {
  local theme_id="$1"
  local output="$2"
  local reduce_motion="${3:-0}"
  local arguments=(-LifeRouteVisualFixture "$theme_id")
  if [ "$reduce_motion" = "1" ]; then
    arguments+=(-LifeRouteFixtureReduceMotion)
  fi
  local launch_output
  local app_pid
  launch_output="$(xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" "$BUNDLE_ID" "${arguments[@]}")"
  app_pid="$(launch_pid "$launch_output")"
  sleep 4
  kill -0 "$app_pid"
  xcrun simctl io "$SIMULATOR_ID" screenshot "$OUTPUT_DIR/$output"
}

capture_app_pair() {
  local theme_id="$1"
  local slug="$2"
  local launch_output
  local app_pid
  launch_output="$(xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" "$BUNDLE_ID" \
    -LifeRouteThemeOverride "$theme_id" \
    -LifeRouteSectionOverride today)"
  app_pid="$(launch_pid "$launch_output")"
  sleep 7
  kill -0 "$app_pid"
  xcrun simctl io "$SIMULATOR_ID" screenshot "$OUTPUT_DIR/today-$slug.png"
  xcrun simctl openurl "$SIMULATOR_ID" "liferoute://fixture/schedule"
  sleep 3
  kill -0 "$app_pid"
  xcrun simctl io "$SIMULATOR_ID" screenshot "$OUTPUT_DIR/schedule-$slug.png"
}

capture_app_single() {
  local theme_id="$1"
  local section="$2"
  local output="$3"
  local launch_output
  local app_pid
  launch_output="$(xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" "$BUNDLE_ID" \
    -LifeRouteThemeOverride "$theme_id" \
    -LifeRouteSectionOverride "$section")"
  app_pid="$(launch_pid "$launch_output")"
  sleep 7
  kill -0 "$app_pid"
  xcrun simctl io "$SIMULATOR_ID" screenshot "$OUTPUT_DIR/$output"
}

OCR_ARGUMENTS=()
REDUCE_FIXTURES=()

for record in "${ALL_THEMES[@]}"; do
  IFS='|' read -r theme_id slug <<< "$record"
  echo "Capturing full app persistence pair for $theme_id"
  capture_app_pair "$theme_id" "$slug"
  OCR_ARGUMENTS+=("$OUTPUT_DIR/today-$slug.png=LifeRoute")
  OCR_ARGUMENTS+=("$OUTPUT_DIR/schedule-$slug.png=Schedule")
  echo "Capturing Reduce Motion still for $theme_id"
  capture_standalone "$theme_id" "reduce-motion-$slug.png" 1
  REDUCE_FIXTURES+=("$OUTPUT_DIR/reduce-motion-$slug.png")
done

for record in "${DYNAMIC_THEMES[@]}"; do
  IFS='|' read -r theme_id slug <<< "$record"
  launch_output="$(xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" "$BUNDLE_ID" -LifeRouteVisualFixture "$theme_id")"
  app_pid="$(launch_pid "$launch_output")"
  sleep 3
  kill -0 "$app_pid"
  xcrun simctl io "$SIMULATOR_ID" screenshot "$OUTPUT_DIR/motion-frame-a-$slug.png"
  sleep 3
  kill -0 "$app_pid"
  xcrun simctl io "$SIMULATOR_ID" screenshot "$OUTPUT_DIR/motion-frame-b-$slug.png"
  python3 "$COMPARE_SCRIPT" validate-motion "$OUTPUT_DIR/motion-frame-a-$slug.png" "$OUTPUT_DIR/motion-frame-b-$slug.png" \
    | tee -a "$OUTPUT_DIR/validation-results.txt"
done

for pair in "${SCENERY_PAIRS[@]}"; do
  IFS='|' read -r day_slug night_slug <<< "$pair"
  python3 "$COMPARE_SCRIPT" validate-identity "$OUTPUT_DIR/reduce-motion-$day_slug.png" "$OUTPUT_DIR/reduce-motion-$night_slug.png" \
    | tee -a "$OUTPUT_DIR/validation-results.txt"
done

python3 "$COMPARE_SCRIPT" validate-distinct "${REDUCE_FIXTURES[@]}" | tee -a "$OUTPUT_DIR/validation-results.txt"
python3 "$COMPARE_SCRIPT" validate-coverage "$OUTPUT_DIR"/today-*.png "$OUTPUT_DIR"/schedule-*.png \
  | tee -a "$OUTPUT_DIR/validation-results.txt"
python3 "$COMPARE_SCRIPT" validate-health "$OUTPUT_DIR"/*.png | tee -a "$OUTPUT_DIR/validation-results.txt"
swift "$TEXT_SCRIPT" "${OCR_ARGUMENTS[@]}" | tee -a "$OUTPUT_DIR/validation-results.txt"

# Preserve the Build #98 exemplar filenames while the complete matrix remains canonical.
cp "$OUTPUT_DIR/reduce-motion-scenery-canyon-day.png" "$OUTPUT_DIR/canyon-day.png"
cp "$OUTPUT_DIR/motion-frame-a-dynamic-royal-current.png" "$OUTPUT_DIR/royal-current-frame-a.png"
cp "$OUTPUT_DIR/motion-frame-b-dynamic-royal-current.png" "$OUTPUT_DIR/royal-current-frame-b.png"
cp "$OUTPUT_DIR/today-scenery-canyon-day.png" "$OUTPUT_DIR/today-canyon-day.png"
cp "$OUTPUT_DIR/schedule-scenery-canyon-day.png" "$OUTPUT_DIR/schedule-canyon-day.png"
cp "$OUTPUT_DIR/today-dynamic-royal-current.png" "$OUTPUT_DIR/today-royal-current.png"
capture_app_single "scenery.canyon.day" "tools" "tools-canyon-day.png"
capture_app_single "scenery.canyon.day" "resources" "resources-canyon-day.png"
capture_app_single "scenery.canyon.day" "setup" "setup-canyon-day.png"

for capture in "$OUTPUT_DIR"/*.png; do
  test -s "$capture"
  test "$(wc -c < "$capture")" -ge 150000
done

{
  printf 'app_bundle_kib=%s\n' "$(du -sk "$APP_PATH" | awk '{print $1}')"
  printf 'compiled_assets_bytes=%s\n' "$(find "$APP_PATH" -name Assets.car -exec stat -f '%z' {} \; | awk '{total += $1} END {print total + 0}')"
  printf 'new_scenery_source_asset_bytes=3658387\n'
  printf 'retained_dynamic_count=8\n'
  printf 'retained_scenery_count=12\n'
} > "$OUTPUT_DIR/bundle-size.txt"

echo "Captured and validated the complete v0.7.1 retained theme matrix: 20 Today/Schedule in-process pairs, 20 stable Reduce Motion phases, 8 Dynamic motion pairs, 6 materially distinct Scenery Day/Night pairs, and Build #98 Canyon Day/Royal Current compatibility fixtures."
