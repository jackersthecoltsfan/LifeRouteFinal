#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash scripts/run_swift_contract_test.sh \
  "Runtime feedback" \
  "runtime-feedback-contract-tests" \
  LifeRoute/RuntimeFeedbackContracts.swift \
  scripts/runtime_feedback_contract_tests.swift
