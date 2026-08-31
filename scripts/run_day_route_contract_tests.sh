#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash scripts/run_swift_contract_test.sh \
  "Day Route" \
  "day-route-contract-tests" \
  LifeRoute/DayRouteContracts.swift \
  LifeRoute/FullRouteHandoffContracts.swift \
  scripts/day_route_contract_tests.swift
