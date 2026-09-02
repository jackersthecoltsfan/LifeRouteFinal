#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"

exec bash "$SCRIPT_DIRECTORY/run_swift_contract_test.sh" \
  "Visual activity" \
  "visual-activity-contract-tests" \
  LifeRoute/LifeRouteVisualActivityCoordinator.swift \
  scripts/visual_activity_contract_tests.swift
