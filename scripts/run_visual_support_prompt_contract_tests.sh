#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
command -v swiftc >/dev/null || { echo "Visual support prompt contracts require swiftc." >&2; exit 1; }

exec bash "$SCRIPT_DIRECTORY/run_swift_contract_test.sh" \
  "Visual support prompt" \
  "visual-support-prompt-contract-tests" \
  LifeRoute/VisualSupportImagePrompt.swift \
  scripts/visual_support_prompt_contract_tests.swift
