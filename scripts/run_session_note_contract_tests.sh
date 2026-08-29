#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "Swift compiler unavailable; Session Note executable contract fixtures skipped on this host."
  exit 0
fi

FIXTURE_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/liferoute-session-note-contracts.XXXXXX")"
trap 'rm -rf "$FIXTURE_DIRECTORY"' EXIT

swiftc \
  LifeRoute/SessionNoteContracts.swift \
  scripts/session_note_contract_tests.swift \
  -o "$FIXTURE_DIRECTORY/session-note-contract-tests"

"$FIXTURE_DIRECTORY/session-note-contract-tests"
