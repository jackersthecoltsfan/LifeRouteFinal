#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIRECTORY/run_swift_contract_test.sh" \
  "Session Note refinement" "session-note-refinement-tests" \
  LifeRoute/SessionNoteContracts.swift scripts/session_note_refinement_tests.swift
