#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

test -f LifeRoute.xcodeproj/project.pbxproj
test -f LifeRoute/LifeRouteApp.swift
test -f LifeRouteLiveActivityWidget/LiveDayLiveActivityWidget.swift

bash scripts/validate_fast.sh

echo "Prepared canonical LifeRoute v0.8.1 source."
