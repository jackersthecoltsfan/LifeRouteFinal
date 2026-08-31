#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "Swift compiler unavailable; Scenery effect executable contract fixtures skipped on this host."
  exit 0
fi

FIXTURE_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/liferoute-scenery-effect-contracts.XXXXXX")"
trap 'rm -rf "$FIXTURE_DIRECTORY"' EXIT

swiftc \
  LifeRoute/SceneryEffectContracts.swift \
  scripts/scenery_effect_contract_tests.swift \
  -o "$FIXTURE_DIRECTORY/scenery-effect-contract-tests"

"$FIXTURE_DIRECTORY/scenery-effect-contract-tests"
