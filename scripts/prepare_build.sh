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

# Keep this checkpoint deterministic and small.
python3 -m py_compile scripts/audit_v0_5_0_functional_shell.py
plutil -lint LifeRoute/Info.plist

# Fail immediately if target membership, native navigation ownership, or the
# explicit 0.5.0 marketing-version contract regresses.
python3 scripts/audit_v0_5_0_functional_shell.py

echo "LifeRoute v0.5.0 functional-core preparation passed. Legacy WebView runtime remains quarantined."
