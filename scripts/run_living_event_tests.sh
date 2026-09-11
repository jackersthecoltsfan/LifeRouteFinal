#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$1"
KIND="$2"
mkdir -p "$OUTPUT"
xcrun -sdk macosx metal -c "$ROOT/LifeRoute/LivingRainforest.metal" -o "$OUTPUT/events.air"
xcrun -sdk macosx metallib "$OUTPUT/events.air" -o "$OUTPUT/events.metallib"
xcrun -sdk macosx swiftc -parse-as-library "$ROOT/scripts/living_event_tests.swift" -o "$OUTPUT/event-tests"
"$OUTPUT/event-tests" "$OUTPUT/events.metallib" "$KIND" "$OUTPUT/states.json"
