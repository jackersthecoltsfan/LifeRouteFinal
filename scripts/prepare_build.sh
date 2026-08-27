#!/usr/bin/env bash
set -euo pipefail

# LifeRoute v0.6.2 native preparation. Never reactivate the v0.4 WebView patch stack.
rm -rf build

# Materialize the narrowly scoped v0.6.2 native changes before every validation/archive.
python3 scripts/patch_v0_6_2_native.py

# The premium LR icon is generated deterministically from checked-in vector-style drawing code
# so Simulator validation and the signed TestFlight archive ship the exact same 1024×1024 asset.
ICON="LifeRoute/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
swift scripts/generate_v0_6_1_app_icon.swift "$ICON"

# App Store Connect rejects large app icons that contain an alpha channel, even when they appear opaque.
test -s "$ICON"
test "$(sips -g pixelWidth "$ICON" | awk '/pixelWidth/ {print $2}')" = "1024"
test "$(sips -g pixelHeight "$ICON" | awk '/pixelHeight/ {print $2}')" = "1024"
test "$(sips -g hasAlpha "$ICON" | awk '/hasAlpha/ {print $2}')" = "no" || {
  echo "AppIcon release guard failed: $ICON contains an alpha channel."
  exit 1
}
echo "AppIcon release guard passed: 1024×1024 opaque RGB PNG with no alpha channel."

python3 -m py_compile \
  scripts/patch_v0_6_2_native.py \
  scripts/audit_v0_5_0_functional_shell.py \
  scripts/audit_v0_5_0_core_navigation.py \
  scripts/audit_v0_5_0_calendar_core.py \
  scripts/audit_v0_5_0_routing_location_core.py \
  scripts/audit_v0_5_0_clients_core.py \
  scripts/audit_v0_5_0_session_tools_core.py \
  scripts/audit_v0_5_0_calendar_providers.py \
  scripts/audit_v0_5_0_client_visual_supports.py \
  scripts/audit_v0_5_0_client_visual_persistence.py \
  scripts/audit_v0_5_0_routing_calendar_persistence.py \
  scripts/audit_v0_5_0_legacy_migration.py \
  scripts/audit_v0_5_0_performance_architecture.py \
  scripts/audit_v0_5_0_stability_architecture.py \
  scripts/audit_v0_5_0_second_functionality_pass.py \
  scripts/audit_v0_5_3_repair.py \
  scripts/audit_v0_5_4_restore.py \
  scripts/audit_v0_6_0_patch.py \
  scripts/audit_v0_6_2_patch.py

plutil -lint LifeRoute/Info.plist
plutil -lint LifeRouteLiveActivityWidget/Info.plist

python3 scripts/audit_v0_5_0_functional_shell.py
python3 scripts/audit_v0_5_0_core_navigation.py
python3 scripts/audit_v0_5_0_calendar_core.py
python3 scripts/audit_v0_5_0_routing_location_core.py
python3 scripts/audit_v0_5_0_clients_core.py
python3 scripts/audit_v0_5_0_session_tools_core.py
python3 scripts/audit_v0_5_0_calendar_providers.py
python3 scripts/audit_v0_5_0_client_visual_supports.py
python3 scripts/audit_v0_5_0_client_visual_persistence.py
python3 scripts/audit_v0_5_0_routing_calendar_persistence.py
python3 scripts/audit_v0_5_0_legacy_migration.py
python3 scripts/audit_v0_5_0_performance_architecture.py
python3 scripts/audit_v0_5_0_stability_architecture.py
python3 scripts/audit_v0_5_0_second_functionality_pass.py
python3 scripts/audit_v0_5_3_repair.py
python3 scripts/audit_v0_5_4_restore.py
python3 scripts/audit_v0_6_0_patch.py
python3 scripts/audit_v0_6_2_patch.py

echo "LifeRoute v0.6.2 preparation passed with v0.6.0/v0.5.4 regression coverage, v0.6.2 native product checks, and legacy WebView runtime quarantined."
