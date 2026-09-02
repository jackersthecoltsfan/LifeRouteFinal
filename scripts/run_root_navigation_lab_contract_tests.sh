#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SWIFT_COMPILER="$(command -v swiftc || true)"
if [[ -z "$SWIFT_COMPILER" ]]; then
  echo "Swift compiler unavailable; root navigation lab executable contract fixtures skipped on this host."
  exit 0
fi

TEMPORARY_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/liferoute-root-navigation-lab-contract.XXXXXX")"
trap 'rm -rf "$TEMPORARY_DIRECTORY"' EXIT

"$SWIFT_COMPILER" \
  -D DEBUG \
  -D LIFEROUTE_ROOT_SWIPE_CONTRACT_TEST \
  LifeRoute/AppNavigation.swift \
  scripts/root_navigation_lab_contract_tests.swift \
  -o "$TEMPORARY_DIRECTORY/root-navigation-lab-contract-tests"

"$TEMPORARY_DIRECTORY/root-navigation-lab-contract-tests"
