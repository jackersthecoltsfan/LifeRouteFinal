#!/usr/bin/env bash
set -euo pipefail

# Capture the static Theme Center catalog from the production renderer. The
# DEBUG fixture's Reduce Motion path supplies each Dynamic renderer's declared
# stillPhase, so no live clock or hand-built thumbnail art enters the assets.
# Scenery catalog files intentionally remain the existing canonical Day/Night
# artwork and are not regenerated here.
#
# Usage:
#   capture_theme_thumbnail_assets.sh APP_PATH DEVICE_UDID OUTPUT_DIRECTORY

APP_PATH="${1:?usage: capture_theme_thumbnail_assets.sh APP_PATH DEVICE_UDID OUTPUT_DIRECTORY}"
DEVICE_ID="${2:?usage: capture_theme_thumbnail_assets.sh APP_PATH DEVICE_UDID OUTPUT_DIRECTORY}"
OUTPUT_DIRECTORY="${3:?usage: capture_theme_thumbnail_assets.sh APP_PATH DEVICE_UDID OUTPUT_DIRECTORY}"
REPOSITORY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSET_ROOT="$REPOSITORY_ROOT/LifeRoute/Assets.xcassets"
BUNDLE_ID="Com.Brandongood.LifeRoute"

test -d "$APP_PATH"
test -d "$ASSET_ROOT"
mkdir -p "$OUTPUT_DIRECTORY"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

capture() {
  local fixture="$1"
  local output_name="$2"
  local crop_offset="$3"
  local full_path="$OUTPUT_DIRECTORY/$output_name-full.png"
  local cropped_path="$OUTPUT_DIRECTORY/$output_name.png"

  xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" \
    -LifeRouteVisualFixture "$fixture" -LifeRouteFixtureReduceMotion >/dev/null
  sleep 1
  xcrun simctl io "$DEVICE_ID" screenshot "$full_path" >/dev/null
  cp "$full_path" "$cropped_path"
  sips -c 670 1206 --cropOffset "$crop_offset" 0 "$cropped_path" >/dev/null
  sips --resampleWidth 540 "$cropped_path" >/dev/null
}

xcrun simctl install "$DEVICE_ID" "$APP_PATH"
xcrun simctl bootstatus "$DEVICE_ID" -b >/dev/null

capture royal core-royal 976
capture obsidian core-obsidian 976
capture midnight core-midnight 976
capture titanium core-titanium 976
capture core.ocean core-ocean 976
capture core.aurora core-aurora 976
capture core.solarFlare core-solar-flare 976
capture core.ultraviolet core-ultraviolet 976
capture core.emerald core-emerald 976
capture core.roseQuartz core-rose-quartz 976
capture core.arctic core-arctic 976
capture core.ember core-ember 976

# Dynamic crops show the renderer's fixed-phase treatment over its canonical
# companion scene while avoiding the simulator's Dynamic Island/home indicator.
capture dynamic.royalCurrent dynamic-royal-current 500
capture dynamic.midnightPrism dynamic-midnight-prism 500
capture dynamic.auroraBloom dynamic-aurora-bloom 500
capture dynamic.solarPulse dynamic-solar-pulse 500
capture dynamic.emeraldFlow dynamic-emerald-flow 500
capture dynamic.oceanGlass dynamic-ocean-glass 500
capture dynamic.obsidianSpectra dynamic-obsidian-spectra 500
capture dynamic.plasmaOrchid dynamic-plasma-orchid 500

echo "Captured 20 fixed-phase Theme Center source previews in $OUTPUT_DIRECTORY."
