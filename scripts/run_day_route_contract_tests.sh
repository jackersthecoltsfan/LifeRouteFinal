#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"

exec bash "$SCRIPT_DIRECTORY/run_swift_contract_test.sh" \
  "Day Route" \
  "day-route-contract-tests" \
  LifeRoute/DayRouteContracts.swift \
  LifeRoute/DayItineraryContracts.swift \
  LifeRoute/LiveDayRunContracts.swift \
  LifeRoute/FullRouteHandoffContracts.swift \
  scripts/day_route_contract_tests.swift
