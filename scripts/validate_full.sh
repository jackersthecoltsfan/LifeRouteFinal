#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 scripts/validate_current.py full
bash scripts/run_day_route_contract_tests.sh
bash scripts/run_calendar_edit_contract_tests.sh
bash scripts/run_session_note_contract_tests.sh
bash scripts/run_visual_timer_feedback_contract_tests.sh
bash scripts/run_runtime_feedback_contract_tests.sh
bash scripts/run_visual_activity_contract_tests.sh
bash scripts/run_scenery_effect_contract_tests.sh
bash scripts/run_root_swipe_contract_tests.sh
bash scripts/run_root_navigation_lab_contract_tests.sh
python3 scripts/today_full_route_action_contract_test.py
python3 scripts/theme_thumbnail_contract_test.py

echo "LifeRoute full validation complete."
