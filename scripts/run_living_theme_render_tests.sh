#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 ]]; then echo 'usage: run_living_theme_render_tests.sh EXTERNAL_OUTPUT_DIRECTORY [SCENE_ID]' >&2; exit 2; fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOLVED_OUTPUT="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve())' "$1")"
case "$RESOLVED_OUTPUT" in "$ROOT"|"$ROOT"/*) echo 'Output must be outside the repository' >&2; exit 2;; esac
mkdir -p "$RESOLVED_OUTPUT"
OUTPUT="$RESOLVED_OUTPUT"
xcrun -sdk macosx metal -c "$ROOT/LifeRoute/LivingRainforest.metal" -o "$OUTPUT/LivingRainforest.air"
xcrun -sdk macosx metallib "$OUTPUT/LivingRainforest.air" -o "$OUTPUT/LivingRainforest.metallib"
xcrun -sdk macosx swiftc -parse-as-library "$ROOT/LifeRoute/LivingThemeScene.swift" \
    "$ROOT/scripts/living_theme_render_tests.swift" -o "$OUTPUT/render-tests"
SCENE="${2:-scenery.rainforest.day}"
case "$SCENE" in
    scenery.rainforest.day) ARTWORK=SceneryRainforestDay ;;
    scenery.ocean.day) ARTWORK=SceneryOceanDay ;;
    scenery.ocean.night) ARTWORK=SceneryOceanNight ;;
    *) echo 'Unknown implemented Living scene' >&2; exit 2 ;;
esac
"$OUTPUT/render-tests" "$OUTPUT/LivingRainforest.metallib" \
    "$ROOT/LifeRoute/Assets.xcassets/$ARTWORK.imageset/$ARTWORK.jpg" "$OUTPUT" "$SCENE"
