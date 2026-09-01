#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"

exec bash "$SCRIPT_DIRECTORY/run_swift_contract_test.sh" \
  "Calendar Edit" \
  "calendar-edit-contract-tests" \
  LifeRoute/CalendarDomain.swift \
  scripts/calendar_edit_contract_tests.swift
