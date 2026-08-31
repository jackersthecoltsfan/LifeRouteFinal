#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash scripts/run_swift_contract_test.sh \
  "Visual Timer feedback" \
  "visual-timer-feedback-contract-tests" \
  LifeRoute/VisualTimerFeedbackContracts.swift \
  scripts/visual_timer_feedback_contract_tests.swift
