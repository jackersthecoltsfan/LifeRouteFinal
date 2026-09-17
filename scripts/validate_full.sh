#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VALIDATION_HOST="$(uname -s)"
case "$VALIDATION_HOST" in
  Darwin|Linux) ;;
  *)
    echo "LifeRoute full validation does not define contract placement for host: $VALIDATION_HOST" >&2
    exit 2
    ;;
esac

command -v swiftc >/dev/null || {
  echo "LifeRoute full validation requires swiftc; executable contracts cannot be skipped." >&2
  exit 1
}

if [[ "${LIFEROUTE_FULL_SKIP_FAST:-0}" == "1" ]]; then
  test "${LIFEROUTE_VALIDATION_PREREQUISITE_GATE:-}" = "Q-PREP"
  python3 scripts/validate_qualification_prerequisite.py \
    --gate "$LIFEROUTE_VALIDATION_PREREQUISITE_GATE" \
    --sha "${LIFEROUTE_VALIDATION_SOURCE_SHA:?missing validated source SHA}" \
    --tree "${LIFEROUTE_VALIDATION_SOURCE_TREE:?missing validated source tree}"
  export LIFEROUTE_SKIP_FAST_VALIDATION=1
fi

python3 scripts/validate_current.py full
bash scripts/run_visual_support_prompt_contract_tests.sh
bash scripts/run_visual_support_persistence_tests.sh
bash scripts/run_day_route_contract_tests.sh
bash scripts/run_calendar_edit_contract_tests.sh
bash scripts/run_calendar_cross_provider_dedup_tests.sh
bash scripts/run_apple_occurrence_identity_tests.sh
bash scripts/run_session_note_contract_tests.sh
bash scripts/run_session_note_refinement_tests.sh
bash scripts/run_session_note_draft_persistence_tests.sh
bash scripts/run_visual_timer_feedback_contract_tests.sh
bash scripts/run_runtime_feedback_contract_tests.sh

if [[ "$VALIDATION_HOST" == "Darwin" ]]; then
  bash scripts/run_visual_activity_contract_tests.sh
else
  echo "Visual activity contract requires Combine; assigned to ios-ci native-validation on macos-26."
fi

bash scripts/run_scenery_effect_contract_tests.sh

if [[ "$VALIDATION_HOST" == "Darwin" ]]; then
  bash scripts/run_living_theme_tests.sh
else
  echo "Living Themes contract requires CoreGraphics; assigned to ios-ci native-validation on macos-26."
fi

python3 scripts/root_paging_ambient_suspension_contract_test.py
python3 scripts/today_full_route_action_contract_test.py
python3 scripts/theme_thumbnail_contract_test.py

echo "LifeRoute full validation complete."
