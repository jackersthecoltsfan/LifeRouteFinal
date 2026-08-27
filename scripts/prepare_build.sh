#!/usr/bin/env bash
set -euo pipefail

# LifeRoute v0.7.0 Build B.2 preparation. Never reactivate the v0.4 WebView patch stack.
rm -rf build

# These two historical audits intentionally lock the pre-v0.6.2 timer/theme behavior.
# Run them on the shipped v0.6.1 source before materializing the requested v0.6.2+ replacements.
python3 scripts/audit_v0_5_0_session_tools_core.py
python3 scripts/audit_v0_5_4_restore.py

# Materialize the shipped v0.6.2 baseline first, then layer the v0.6.3 fixes.
python3 scripts/patch_v0_6_2_native.py
python3 scripts/patch_v0_6_2_compile_hotfix.py
python3 scripts/patch_v0_6_3_pre.py
python3 scripts/patch_v0_6_3_native.py
python3 scripts/patch_v0_6_3_compile_hotfix.py
python3 scripts/patch_v0_6_3_note_context_hotfix.py
python3 scripts/patch_v0_6_3_day_selector_hotfix.py
python3 scripts/patch_v0_6_3_core_theme_cleanup.py

# v0.7.0 checkpoints accumulate in order: shell/design system, Today/Home, device parity,
# saved visual-support reuse, the horizontal First -> Then preview, restored native weekly To-Dos,
# then the B.2 real-device QA correction for Home density and visual save/full-screen behavior.
python3 scripts/patch_v0_7_0_build_a.py
python3 scripts/patch_v0_7_0_build_b.py
python3 scripts/patch_v0_7_0_build_b1.py
python3 scripts/patch_v0_7_0_visual_library_reuse.py
python3 scripts/patch_v0_7_0_first_then_horizontal.py
# B.1 wrapper supersedes the direct python3 scripts/patch_v0_7_0_todos_restore.py Home integration.
python3 scripts/patch_v0_7_0_todos_restore_b1.py
python3 scripts/patch_v0_7_0_build_b2.py

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
  scripts/patch_v0_6_2_compile_hotfix.py \
  scripts/patch_v0_6_3_pre.py \
  scripts/patch_v0_6_3_native.py \
  scripts/patch_v0_6_3_compile_hotfix.py \
  scripts/patch_v0_6_3_note_context_hotfix.py \
  scripts/patch_v0_6_3_day_selector_hotfix.py \
  scripts/patch_v0_6_3_core_theme_cleanup.py \
  scripts/patch_v0_7_0_build_a.py \
  scripts/patch_v0_7_0_build_b.py \
  scripts/patch_v0_7_0_build_b1.py \
  scripts/patch_v0_7_0_visual_library_reuse.py \
  scripts/patch_v0_7_0_first_then_horizontal.py \
  scripts/patch_v0_7_0_todos_restore.py \
  scripts/patch_v0_7_0_todos_restore_b1.py \
  scripts/patch_v0_7_0_build_b2.py \
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
  scripts/audit_v0_6_2_patch.py \
  scripts/audit_v0_6_3_patch.py \
  scripts/audit_v0_7_0_checkpoint_0.py \
  scripts/audit_v0_7_0_build_a.py \
  scripts/audit_v0_7_0_build_b.py \
  scripts/audit_v0_7_0_build_b1.py \
  scripts/audit_v0_7_0_visual_library_reuse.py \
  scripts/audit_v0_7_0_first_then_horizontal.py \
  scripts/audit_v0_7_0_todos_restore.py \
  scripts/audit_v0_7_0_build_b2.py \
  scripts/audit_v0_7_0_testflight.py

plutil -lint LifeRoute/Info.plist
plutil -lint LifeRouteLiveActivityWidget/Info.plist

# Run all non-superseded regression coverage on the fully materialized Build B.2 tree.
python3 scripts/audit_v0_5_0_functional_shell.py
python3 scripts/audit_v0_5_0_core_navigation.py
python3 scripts/audit_v0_5_0_calendar_core.py
python3 scripts/audit_v0_5_0_routing_location_core.py
python3 scripts/audit_v0_5_0_clients_core.py
python3 scripts/audit_v0_5_0_calendar_providers.py
python3 scripts/audit_v0_5_0_client_visual_supports.py
python3 scripts/audit_v0_5_0_client_visual_persistence.py
python3 scripts/audit_v0_5_0_routing_calendar_persistence.py
python3 scripts/audit_v0_5_0_legacy_migration.py
python3 scripts/audit_v0_5_0_performance_architecture.py
python3 scripts/audit_v0_5_0_stability_architecture.py
python3 scripts/audit_v0_5_0_second_functionality_pass.py
python3 scripts/audit_v0_5_3_repair.py
python3 scripts/audit_v0_6_0_patch.py
python3 scripts/audit_v0_6_3_patch.py
python3 scripts/audit_v0_7_0_checkpoint_0.py
python3 scripts/audit_v0_7_0_build_a.py
python3 scripts/audit_v0_7_0_build_b.py
python3 scripts/audit_v0_7_0_build_b1.py
python3 scripts/audit_v0_7_0_visual_library_reuse.py
python3 scripts/audit_v0_7_0_first_then_horizontal.py
python3 scripts/audit_v0_7_0_todos_restore.py
python3 scripts/audit_v0_7_0_build_b2.py
python3 scripts/audit_v0_7_0_testflight.py

echo "LifeRoute v0.7.0 Build B.2 preparation passed: accepted Build A + Build B + B.1 behavior retained, Home tightened against the latest real-iPhone/reference comparison, Choice Boards and Visual Schedules have persistent Save & Preview controls with true full-screen session views, saved visual reuse + horizontal First -> Then + weekly To-Dos remain intact, accumulated regressions green, v0.7.0 TestFlight identity guarded, and legacy WebView runtime quarantined."
