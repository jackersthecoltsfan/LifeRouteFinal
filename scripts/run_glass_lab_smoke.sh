#!/usr/bin/env bash
set -euo pipefail

# Capture every DEBUG Glass Lab candidate over both canonical Canyon states.
# Usage: run_glass_lab_smoke.sh APP_PATH DEVICE_UDID OUTPUT_DIRECTORY
APP_PATH="${1:?usage: run_glass_lab_smoke.sh APP_PATH DEVICE_UDID OUTPUT_DIRECTORY}"
DEVICE_ID="${2:?usage: run_glass_lab_smoke.sh APP_PATH DEVICE_UDID OUTPUT_DIRECTORY}"
OUTPUT_DIRECTORY="${3:?usage: run_glass_lab_smoke.sh APP_PATH DEVICE_UDID OUTPUT_DIRECTORY}"
BUNDLE_ID="Com.Brandongood.LifeRoute"

test -d "$APP_PATH"
mkdir -p "$OUTPUT_DIRECTORY"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun simctl bootstatus "$DEVICE_ID" -b >/dev/null
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

for candidate in clear regular material; do
    for scene in bright dark; do
        output="$OUTPUT_DIRECTORY/${candidate}-${scene}.png"
        xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" \
            -LifeRouteGlassLab \
            -LifeRouteGlassLabCandidate "$candidate" \
            -LifeRouteGlassLabScene "$scene" >/dev/null
        sleep 1
        xcrun simctl io "$DEVICE_ID" screenshot "$output" >/dev/null
    done
done

count=$(find "$OUTPUT_DIRECTORY" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')
test "$count" -eq 6
echo "LifeRoute DEBUG Glass Lab smoke passed: $count candidate/scene screenshots in $OUTPUT_DIRECTORY"
