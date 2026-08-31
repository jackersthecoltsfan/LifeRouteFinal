#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash scripts/run_swift_contract_test.sh \
  "Session Note" \
  "session-note-contract-tests" \
  LifeRoute/SessionNoteContracts.swift \
  scripts/session_note_contract_tests.swift
