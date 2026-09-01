#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"

exec bash "$SCRIPT_DIRECTORY/run_swift_contract_test.sh" \
  "Session Note" \
  "session-note-contract-tests" \
  LifeRoute/SessionNoteContracts.swift \
  scripts/session_note_contract_tests.swift
