#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"

exec bash "$SCRIPT_DIRECTORY/run_swift_contract_test.sh" \
  "Session Note draft persistence" \
  "session-note-draft-persistence-tests" \
  LifeRoute/PersistenceCore.swift \
  scripts/session_note_draft_persistence_tests.swift
