#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"

COMPLETION_CUE="LifeRoute/Assets.xcassets/TimerCompletionCue.dataset/TIMER_SOUND_3s.wav"
EXPECTED_COMPLETION_CUE_SHA256="ddde780da9eb13cc1b7f00f0f7ba03d7f4bd50e8f480574078fd20092174e52b"
test -f "$COMPLETION_CUE"
test "$(shasum -a 256 "$COMPLETION_CUE" | awk '{print $1}')" = "$EXPECTED_COMPLETION_CUE_SHA256"
COMPLETION_CUE_INFO="$(afinfo "$COMPLETION_CUE")"
grep -Fq "2 ch,  44100 Hz" <<<"$COMPLETION_CUE_INFO"
grep -Fq "24-bit little-endian signed integer" <<<"$COMPLETION_CUE_INFO"
grep -Fq "estimated duration: 3.000000 sec" <<<"$COMPLETION_CUE_INFO"
echo "Approved completion WAV hash and media properties verified."

bash "$SCRIPT_DIRECTORY/run_swift_contract_test.sh" \
  "Visual Timer feedback" \
  "visual-timer-feedback-contract-tests" \
  LifeRoute/VisualTimerFeedbackContracts.swift \
  scripts/visual_timer_feedback_contract_tests.swift

# Native Path, mask alpha, and Canvas clipping need SwiftUI on a macOS host.
if [[ "$(uname -s)" == "Darwin" ]]; then
  command -v swiftc >/dev/null || { echo "Native Orb region tests require swiftc." >&2; exit 1; }
  bash "$SCRIPT_DIRECTORY/run_swift_contract_test.sh" \
    "Native Orb regions" \
    "visual-timer-orb-region-tests" \
    LifeRoute/VisualTimerFeedbackContracts.swift \
    scripts/visual_timer_orb_region_tests.swift
  bash "$SCRIPT_DIRECTORY/run_swift_contract_test.sh" \
    "Accepted V04 material" \
    "visual-timer-v04-material-tests" \
    scripts/visual_timer_v04_material_tests.swift
else
  echo "Native Orb region coverage requires a macOS SwiftUI host; not verified here."
fi

# Full-screen presentation ownership and lifecycle use the production core/state.
if [[ "$(uname -s)" == "Darwin" ]]; then
  python3 "$SCRIPT_DIRECTORY/run_visual_timer_presentation_tests.py"
fi
