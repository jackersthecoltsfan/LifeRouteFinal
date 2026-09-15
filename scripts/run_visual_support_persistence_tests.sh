#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
ROOT="${LIFEROUTE_ROOT:-$(cd "$SCRIPT_DIRECTORY/.." && pwd)}"
DOMAIN_SOURCE="$ROOT/LifeRoute/SessionToolsDomain.swift"
MARKER='// MARK: - Checkpoint 03F / 04A: client-specific persistent visual supports'
EXTRACTED_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/liferoute-visual-domain.XXXXXX")"
EXTRACTED_DOMAIN="$EXTRACTED_DIRECTORY/VisualDomain.swift"
trap 'rm -rf "$EXTRACTED_DIRECTORY"' EXIT

MARKER_COUNT="$(grep -Fxc "$MARKER" "$DOMAIN_SOURCE")"
if [[ "$MARKER_COUNT" != "1" ]]; then
  echo "Expected exactly one visual-support domain marker, found $MARKER_COUNT" >&2
  exit 1
fi

{
  printf '%s\n' 'import Foundation'
  printf '%s\n' '#if canImport(Combine)'
  printf '%s\n' 'import Combine'
  printf '%s\n' '#endif'
  awk -v marker="$MARKER" '$0 == marker { found = 1 } found { print }' "$DOMAIN_SOURCE"
} > "$EXTRACTED_DOMAIN"

cd "$ROOT"
bash scripts/run_swift_contract_test.sh \
  "Visual support model and persistence" \
  "visual-support-persistence-tests" \
  LifeRoute/PersistenceCore.swift \
  LifeRoute/CalendarDomain.swift \
  LifeRoute/DayRouteContracts.swift \
  "$EXTRACTED_DOMAIN" \
  "$SCRIPT_DIRECTORY/visual_support_persistence_tests.swift"
