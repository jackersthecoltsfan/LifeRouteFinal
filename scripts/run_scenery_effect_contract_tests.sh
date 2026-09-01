#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"

exec bash "$SCRIPT_DIRECTORY/run_swift_contract_test.sh" \
  "Scenery effect" \
  "scenery-effect-contract-tests" \
  LifeRoute/SceneryEffectContracts.swift \
  scripts/scenery_effect_contract_tests.swift
