#!/usr/bin/env bash
set -euo pipefail

# Release-control touch: preserve exact-SHA push validation for authorized TestFlight.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

test -f LifeRoute.xcodeproj/project.pbxproj
test -f LifeRoute/LifeRouteApp.swift
test -f LifeRouteLiveActivityWidget/LiveDayLiveActivityWidget.swift

if [[ "${LIFEROUTE_PREPARE_SKIP_FAST:-0}" == "1" ]]; then
  test "${LIFEROUTE_PREPARE_PREREQUISITE_GATE:-}" = "Q-SEM-FULL"
  python3 scripts/validate_qualification_prerequisite.py \
    --gate "$LIFEROUTE_PREPARE_PREREQUISITE_GATE" \
    --sha "${LIFEROUTE_VALIDATION_SOURCE_SHA:?missing validated source SHA}" \
    --tree "${LIFEROUTE_VALIDATION_SOURCE_TREE:?missing validated source tree}"
  echo "Skipped fast validation: exact Q-SEM-FULL prerequisite was verified."
else
  bash scripts/validate_fast.sh
fi

echo "Prepared canonical LifeRoute v0.9.1 source."
