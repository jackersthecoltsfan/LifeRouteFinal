#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "Swift compiler unavailable; runtime feedback executable contract fixtures skipped on this host."
  exit 0
fi

FIXTURE_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/liferoute-runtime-feedback-contracts.XXXXXX")"
trap 'rm -rf "$FIXTURE_DIRECTORY"' EXIT

swiftc \
  LifeRoute/RuntimeFeedbackContracts.swift \
  scripts/runtime_feedback_contract_tests.swift \
  -o "$FIXTURE_DIRECTORY/runtime-feedback-contract-tests"

"$FIXTURE_DIRECTORY/runtime-feedback-contract-tests"
