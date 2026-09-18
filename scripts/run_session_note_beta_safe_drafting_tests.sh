#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"

exec bash "$SCRIPT_DIRECTORY/run_swift_contract_test.sh" \
  "Session Note beta-safe deterministic drafting" \
  "session-note-beta-safe-drafting-tests" \
  LifeRoute/SessionNoteContracts.swift \
  scripts/session_note_beta_safe_drafting_tests.swift
