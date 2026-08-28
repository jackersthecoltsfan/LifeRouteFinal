#!/usr/bin/env bash
set -euo pipefail

# LifeRoute v0.7.0 Build E preparation. Never reactivate the v0.4 WebView patch stack.
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
# B.2/B.3 real-device QA, Build C Schedule, Build D Tools/ABA, then Build E supporting surfaces.
python3 scripts/patch_v0_7_0_build_a.py
python3 scripts/patch_v0_7_0_build_b.py
python3 scripts/patch_v0_7_0_build_b1.py
python3 scripts/patch_v0_7_0_visual_library_reuse.py
python3 scripts/patch_v0_7_0_first_then_horizontal.py
# B.1 wrapper supersedes the direct python3 scripts/patch_v0_7_0_todos_restore.py Home integration.
python3 scripts/patch_v0_7_0_todos_restore_b1.py
python3 scripts/patch_v0_7_0_build_b2.py
python3 scripts/patch_v0_7_0_build_b3_pre.py
python3 scripts/patch_v0_7_0_build_b3.py
python3 scripts/patch_v0_7_0_build_b3_compat.py
python3 scripts/patch_v0_7_0_build_c.py
python3 scripts/patch_v0_7_0_build_c_compile_hotfix.py
# Build D is presentation-only. Temporarily normalize the superseding v0.6.2 timer TimelineView
# spelling so the visual patch can apply, then restore the validated 0.10-second final cadence.
python3 scripts/patch_v0_7_0_build_d_timer_compat_pre.py
python3 scripts/patch_v0_7_0_build_d.py
python3 scripts/patch_v0_7_0_build_d_timer_compat_post.py
python3 scripts/patch_v0_7_0_build_d_compat.py
# Build E is presentation-only and consumes the fully materialized post-D supporting surfaces.
python3 scripts/patch_v0_7_0_build_e.py
# Preserve the reviewed v0.6.3 Core order and v0.6.2 Dynamic/Scenery catalogs in the new browser.
python3 scripts/patch_v0_7_0_build_e_theme_compat.py
# Post-Build-E focused Today enhancement: shared selected-day paging without changing protected domain owners.
python3 scripts/patch_v0_7_0_swipe_day_overview.py

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
  scripts/patch_v0_7_0_build_b3_pre.py \
  scripts/patch_v0_7_0_build_b3.py \
  scripts/patch_v0_7_0_build_b3_compat.py \
  scripts/patch_v0_7_0_build_c.py \
  scripts/patch_v0_7_0_build_c_compile_hotfix.py \
  scripts/patch_v0_7_0_build_d_timer_compat_pre.py \
  scripts/patch_v0_7_0_build_d.py \
  scripts/patch_v0_7_0_build_d_timer_compat_post.py \
  scripts/patch_v0_7_0_build_d_compat.py \
  scripts/patch_v0_7_0_build_e.py \
  scripts/patch_v0_7_0_build_e_theme_compat.py \
  scripts/patch_v0_7_0_swipe_day_overview.py \
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
  scripts/audit_v0_7_0_build_b3.py \
  scripts/audit_v0_7_0_build_c.py \
  scripts/audit_v0_7_0_build_d.py \
  scripts/audit_v0_7_0_build_e.py \
  scripts/audit_v0_7_0_swipe_day_overview.py \
  scripts/audit_v0_7_0_testflight.py

plutil -lint LifeRoute/Info.plist
plutil -lint LifeRouteLiveActivityWidget/Info.plist

# Run all non-superseded regression coverage on the fully materialized post-Build-E tree.
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
python3 scripts/audit_v0_7_0_build_b3.py
python3 scripts/audit_v0_7_0_build_c.py
python3 scripts/audit_v0_7_0_build_d.py
python3 scripts/audit_v0_7_0_build_e.py
python3 scripts/audit_v0_7_0_swipe_day_overview.py
python3 scripts/audit_v0_7_0_testflight.py

echo "LifeRoute v0.7.0 post-Build-E preparation passed: accepted Build A/B/B.1/B.2/B.3/C/D/E behavior remains intact; Today now uses shared CalendarCoreState selected-day paging across the connected calendar horizon; Resources, Clients, Setup, Saved Places, Weekly To-Dos, and Theme Center retain the compact premium supporting-surface hierarchy; native domain/persistence ownership and five-tab routing remain unchanged; the validated timer visual cadence remains 0.10 seconds; and legacy WebView runtime remains quarantined."
