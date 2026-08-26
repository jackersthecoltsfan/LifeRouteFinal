#!/usr/bin/env bash
set -euo pipefail

# LifeRoute v0.5.0 functional-core preparation. Never reactivate the v0.4 WebView patch stack.
rm -rf build

python3 -m py_compile \
  scripts/audit_v0_5_0_functional_shell.py \
  scripts/audit_v0_5_0_core_navigation.py \
  scripts/audit_v0_5_0_calendar_core.py \
  scripts/audit_v0_5_0_routing_location_core.py \
  scripts/audit_v0_5_0_clients_core.py
plutil -lint LifeRoute/Info.plist

python3 scripts/audit_v0_5_0_functional_shell.py
python3 scripts/audit_v0_5_0_core_navigation.py
python3 scripts/audit_v0_5_0_calendar_core.py
python3 scripts/audit_v0_5_0_routing_location_core.py
python3 scripts/audit_v0_5_0_clients_core.py

echo "LifeRoute v0.5.0 functional-core preparation passed. Legacy WebView runtime remains quarantined."
