#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"

exec bash "$SCRIPT_DIRECTORY/run_swift_contract_test.sh" \
  "Calendar B" \
  "calendar-cross-provider-dedup-tests" \
  LifeRoute/CalendarDomain.swift \
  LifeRoute/DayRouteContracts.swift \
  scripts/calendar_cross_provider_dedup_tests.swift
