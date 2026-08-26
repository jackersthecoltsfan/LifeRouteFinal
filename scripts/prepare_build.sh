#!/usr/bin/env bash
set -euo pipefail

# LifeRoute v0.5.0 functional-core preparation.
#
# This intentionally does NOT run the v0.4.0 patch stack or inject the legacy
# WebView JavaScript runtime. Old files remain in Git as migration/reference
# material, but preparation must never reactivate them implicitly.

# Remove repository-local output from any previous archive/build attempt. CI
# runners are fresh already; this protects local/manual invocations too.
rm -rf build

# Keep preparation deterministic and limited to the active native core.
python3 -m py_compile \
  scripts/audit_v0_5_0_functional_shell.py \
  scripts/audit_v0_5_0_core_navigation.py \
  scripts/audit_v0_5_0_calendar_core.py
plutil -lint LifeRoute/Info.plist

# Checkpoint-specific gates. Each new layer keeps every prior invariant active.
python3 scripts/audit_v0_5_0_functional_shell.py
python3 scripts/audit_v0_5_0_core_navigation.py
python3 scripts/audit_v0_5_0_calendar_core.py

echo "LifeRoute v0.5.0 functional-core preparation passed. Legacy WebView runtime remains quarantined."
