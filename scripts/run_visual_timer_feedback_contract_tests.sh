#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"

exec bash "$SCRIPT_DIRECTORY/run_swift_contract_test.sh" \
  "Visual Timer feedback" \
  "visual-timer-feedback-contract-tests" \
  LifeRoute/VisualTimerFeedbackContracts.swift \
  scripts/visual_timer_feedback_contract_tests.swift
