#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 ]]; then echo 'usage: run_living_theme_render_tests.sh EXTERNAL_OUTPUT_DIRECTORY [SCENE_ID]' >&2; exit 2; fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOLVED_OUTPUT="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve())' "$1")"
case "$RESOLVED_OUTPUT" in "$ROOT"|"$ROOT"/*) echo 'Output must be outside the repository' >&2; exit 2;; esac
mkdir -p "$RESOLVED_OUTPUT"
OUTPUT="$RESOLVED_OUTPUT"
if [[ -n "${LIFEROUTE_MOTION_CHECKPOINT:-}" ]]; then
    python3 "$ROOT/scripts/check_living_family_contracts.py" --checkpoint "$LIFEROUTE_MOTION_CHECKPOINT"
fi
python3 "$ROOT/scripts/check_ocean_timing_authority.py"
xcrun -sdk macosx metal -c "$ROOT/LifeRoute/LivingRainforest.metal" -o "$OUTPUT/LivingRainforest.air"
xcrun -sdk macosx metallib "$OUTPUT/LivingRainforest.air" -o "$OUTPUT/LivingRainforest.metallib"
xcrun -sdk macosx swiftc -import-objc-header "$ROOT/LifeRoute/LivingMotionContracts.h" -parse-as-library "$ROOT/LifeRoute/LivingThemeScene.swift" \
    "$ROOT/scripts/living_theme_render_tests.swift" -o "$OUTPUT/render-tests"
SCENE="${2:-scenery.rainforest.day}"
ARTWORK="$(python3 - "$SCENE" <<'PYMAP'
import sys
parts=sys.argv[1].split('.')
assert len(parts)==3 and parts[0]=='scenery' and parts[1] in ['rainforest','ocean','arctic','mountains','canyon','desert'] and parts[2] in ['day','night']
print('Scenery'+parts[1].title()+parts[2].title())
PYMAP
)"
ARTWORK_FILE="$(python3 - "$ROOT/LifeRoute/Assets.xcassets/$ARTWORK.imageset" <<'PYMAP'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]);print(p/next(i['filename'] for i in json.loads((p/'Contents.json').read_text())['images'] if 'filename' in i))
PYMAP
)"
"$OUTPUT/render-tests" "$OUTPUT/LivingRainforest.metallib" "$ARTWORK_FILE" "$OUTPUT" "$SCENE" "$ROOT/scripts/living_theme_roi_contract.json"
