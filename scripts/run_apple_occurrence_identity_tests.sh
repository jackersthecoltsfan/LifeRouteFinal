#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
SEAM_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/apple-occurrence-seams.XXXXXX")"
trap 'rm -rf "$SEAM_DIRECTORY"' EXIT
python3 "$SCRIPT_DIRECTORY/apple_occurrence_identity_seams.py" "$SEAM_DIRECTORY/Seams.swift"
bash "$SCRIPT_DIRECTORY/run_swift_contract_test.sh" \
  "Apple occurrence identity" \
  "apple-occurrence-identity-tests" \
  LifeRoute/CalendarDomain.swift \
  LifeRoute/PersistenceCore.swift \
  LifeRoute/DayRouteContracts.swift \
  LifeRoute/DayItineraryContracts.swift \
  scripts/apple_occurrence_identity_tests.swift \
  "$SEAM_DIRECTORY/Seams.swift"
