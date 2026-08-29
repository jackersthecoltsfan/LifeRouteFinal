#!/usr/bin/env bash
set -euo pipefail

# LifeRoute v0.7.0 Build E preparation. Never reactivate the v0.4 WebView patch stack.
rm -rf build

validate_png_release_asset() {
python3 - "$1" <<'PY'
import struct
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = path.read_bytes()
if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n":
    raise SystemExit(f"AppIcon release guard failed: {path} is not a PNG.")
length = struct.unpack(">I", data[8:12])[0]
if data[12:16] != b"IHDR" or length != 13:
    raise SystemExit(f"AppIcon release guard failed: {path} is missing a valid IHDR chunk.")
width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack(">IIBBBBB", data[16:29])
if (width, height) != (1024, 1024):
    raise SystemExit(f"AppIcon release guard failed: {path} is {width}×{height}, expected 1024×1024.")
if color_type in {4, 6}:
    raise SystemExit(f"AppIcon release guard failed: {path} contains an alpha channel.")
print(f"Official LifeRoute AppIcon release guard passed: {width}×{height} opaque PNG with no alpha channel.")
PY
}

validate_plist_file() {
python3 - "$1" <<'PY'
import plistlib
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open('rb') as handle:
    plistlib.load(handle)
print(f"Plist validation passed: {path}")
PY
}

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

# Theme Phase 1 intentionally supersedes three historical presentation contracts: the old ten-theme
# Core catalog, Build A's duplicate shell backdrop, and Build E's pre-Phase-1 Theme Center catalog.
# Lock those historical checkpoints on the fully materialized pre-Phase-1 tree before replacing them.
python3 scripts/audit_v0_6_3_patch.py
python3 scripts/audit_v0_7_0_build_a.py
python3 scripts/audit_v0_7_0_build_e.py

# Theme roadmap Phase 1: one persistent app-wide environment + the 12 approved still Core Glass themes.
python3 scripts/patch_v0_7_0_theme_phase_1.py
# Real-device QA repair after Phase 1: reliable autocomplete dismissal + flexible To-Do destination intents.
python3 scripts/patch_v0_7_0_location_intent_fix.py

# Lock the complete validated Phase 1 + real-device QA contract before Phase 2 intentionally replaces
# only the retained legacy Dynamic catalog/renderer. Core Glass and the location repair remain mandatory.
python3 scripts/audit_v0_7_0_theme_phase_1.py
python3 scripts/audit_v0_7_0_location_intent_fix.py

# Theme roadmap Phase 2: normalize the historical Dynamic category grouping, then materialize
# the 12 approved live Dynamic Liquid Glass identities over the same root host.
python3 scripts/patch_v0_7_0_theme_phase_2_category_compat.py
python3 scripts/patch_v0_7_0_theme_phase_2.py
python3 scripts/patch_v0_7_0_theme_phase_2_compile_hotfix.py
# Real-device Phase 2 QA: make the full Dynamic backdrop participate in motion/refraction instead of
# leaving a static near-black field behind the moving liquid ribbons.
python3 scripts/patch_v0_7_0_theme_phase_2_background_motion_fix.py

# Build B's original wordmark requirement is a historical visual checkpoint. Lock the full Build B
# functional/presentation contract immediately before the official identity intentionally supersedes only that mark.
python3 scripts/audit_v0_7_0_build_b.py

# Controlled post-Phase-2/pre-Phase-3 branding checkpoint. The Today compatibility pass replaces only
# the retired split wordmark and deliberately preserves Build B.1's validated day-picker button.
python3 scripts/patch_v0_7_0_official_branding_today_compat.py
python3 scripts/patch_v0_7_0_official_branding.py

# The official refined 1E/1F hybrid AppIcon is generated deterministically from checked-in vector-style
# drawing code so Simulator validation and the signed TestFlight archive ship the same 1024×1024 identity.
ICON="LifeRoute/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
if command -v swift >/dev/null 2>&1; then
  swift scripts/generate_v0_7_0_official_app_icon.swift "$ICON"
else
  echo "Swift toolchain unavailable; validating the checked-in AppIcon asset without regeneration."
fi

# App Store Connect rejects large app icons that contain an alpha channel, even when they appear opaque.
test -s "$ICON"
validate_png_release_asset "$ICON"

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
  scripts/patch_v0_7_0_theme_phase_1.py \
  scripts/patch_v0_7_0_location_intent_fix.py \
  scripts/patch_v0_7_0_theme_phase_2_category_compat.py \
  scripts/patch_v0_7_0_theme_phase_2.py \
  scripts/patch_v0_7_0_theme_phase_2_compile_hotfix.py \
  scripts/patch_v0_7_0_theme_phase_2_background_motion_fix.py \
  scripts/patch_v0_7_0_official_branding_today_compat.py \
  scripts/patch_v0_7_0_official_branding.py \
  scripts/patch_v0_7_0_live_theme_surface_hero.py \
  scripts/patch_v0_7_0_theme_phase_3.py \
  scripts/patch_v0_7_1_theme_visual_runtime_fix.py \
  scripts/patch_v0_7_1_physical_runtime_fix.py \
  scripts/patch_v0_7_1_dynamic_library_finish.py \
  scripts/patch_v0_7_1_scenery_library_finish.py \
  scripts/patch_v0_7_1_theme_fixture_matrix.py \
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
  scripts/audit_v0_7_0_theme_phase_1.py \
  scripts/audit_v0_7_0_location_intent_fix.py \
  scripts/audit_v0_7_0_theme_phase_2.py \
  scripts/audit_v0_7_0_theme_phase_2_background_motion_fix.py \
  scripts/audit_v0_7_0_official_branding.py \
  scripts/audit_v0_7_0_live_theme_surface_hero.py \
  scripts/audit_v0_7_0_theme_phase_3.py \
  scripts/audit_v0_7_0_testflight.py \
  scripts/audit_v0_7_1_theme_visual_runtime_fix.py \
  scripts/audit_v0_7_1_protected_regressions.py \
  scripts/audit_v0_7_1_physical_runtime_fix.py \
  scripts/audit_v0_7_1_dynamic_library_finish.py \
  scripts/audit_v0_7_1_scenery_library_finish.py \
  scripts/audit_v0_7_1_theme_fixture_matrix.py \
  scripts/compare_v0_7_1_theme_fixtures.py \
  scripts/audit_v0_8_1_session_note_and_visual_prompt.py \
  scripts/audit_v0_8_1_navigation_toolbar_schedule.py \
  scripts/audit_v0_8_1_release_prep.py

validate_plist_file LifeRoute/Info.plist
validate_plist_file LifeRouteLiveActivityWidget/Info.plist

# Run non-superseded regression coverage on the fully materialized branded Phase 2 tree.
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
python3 scripts/audit_v0_7_0_checkpoint_0.py
python3 scripts/audit_v0_7_0_build_b1.py
python3 scripts/audit_v0_7_0_visual_library_reuse.py
python3 scripts/audit_v0_7_0_first_then_horizontal.py
python3 scripts/audit_v0_7_0_todos_restore.py
python3 scripts/audit_v0_7_0_build_b2.py
python3 scripts/audit_v0_7_0_build_b3.py
python3 scripts/audit_v0_7_0_build_c.py
python3 scripts/audit_v0_7_0_build_d.py
python3 scripts/audit_v0_7_0_swipe_day_overview.py
python3 scripts/audit_v0_7_0_location_intent_fix.py
python3 scripts/audit_v0_7_0_theme_phase_2.py
python3 scripts/audit_v0_7_0_theme_phase_2_background_motion_fix.py
# Lock the full official identity before Today intentionally returns to the approved preview wordmark.
python3 scripts/audit_v0_7_0_official_branding.py
# Real-device visual repair: make Dynamic Liquid Glass visibly fill the app surface and restore the approved Today hero composition.
python3 scripts/patch_v0_7_0_live_theme_surface_hero.py
python3 scripts/audit_v0_7_0_live_theme_surface_hero.py
# Theme roadmap Phase 3 intentionally replaces only the retained legacy Scenery catalog/renderer after the post-QA contract is locked.
python3 scripts/patch_v0_7_0_theme_phase_3.py
python3 scripts/audit_v0_7_0_theme_phase_3.py
python3 scripts/audit_v0_7_0_testflight.py

# v0.7.1 visual-runtime correction is intentionally last: all historical Build #96 contracts are
# locked first, then the scoped Canyon Day / Royal Current / Today exemplar architecture supersedes
# only the failed renderer and foreground-surface behavior.
python3 scripts/patch_v0_7_1_theme_visual_runtime_fix.py
python3 scripts/audit_v0_7_1_theme_visual_runtime_fix.py
python3 scripts/audit_v0_7_1_protected_regressions.py

# Build #97 physical-iPhone recording exposed two runtime defects after the exemplar artwork passed:
# live motion was below the perceptual threshold, and UIKit tab/navigation host fills obscured the
# existing single root environment outside the Today hero. Repair only those runtime failures here.
python3 scripts/patch_v0_7_1_physical_runtime_fix.py
python3 scripts/audit_v0_7_1_physical_runtime_fix.py
python3 scripts/audit_v0_7_1_protected_regressions.py

echo "LifeRoute v0.7.1 physical-runtime preparation passed: the complete v0.7.0 Build #96 regression chain remains locked; Canyon Day and Royal Current retain their approved exemplar artwork, live motion is perceptible within a few seconds, UIKit tab/navigation backing surfaces are transparent so the single persistent environment can remain visible app-wide, Today keeps the approved glass/exemplar composition, and protected navigation, calendar, routing, ABA, timer, Live Activity, identity, persistence, and legacy-runtime contracts remain intact."

# Build #98 is the physically validated architecture baseline. Finish the retained Dynamic
# library only after that checkpoint is fully materialized and audited so Royal Current, the
# single root clock, lifecycle pausing, and Reduce Motion ownership stay protected.
python3 scripts/patch_v0_7_1_dynamic_library_finish.py
python3 scripts/audit_v0_7_1_dynamic_library_finish.py
python3 scripts/audit_v0_7_1_protected_regressions.py

echo "LifeRoute v0.7.1 retained Dynamic preparation passed: the complete Build #98 architecture remains locked; Royal Current retains its approved artwork and motion, seven additional retained Dynamic identities now use distinct root-driven full-screen compositions, Theme Center exposes only the eight finished Dynamic identities, and protected navigation, calendar, routing, ABA, timer, Live Activity, identity, persistence, and legacy-runtime contracts remain intact."

# Finish only the approved six retained Scenery families. Canyon Day remains the Build #98
# exemplar; the other eleven identities use optimized bundled artwork and the same root phase.
python3 scripts/patch_v0_7_1_scenery_library_finish.py
python3 scripts/audit_v0_7_1_scenery_library_finish.py
python3 scripts/audit_v0_7_1_dynamic_library_finish.py
python3 scripts/audit_v0_7_1_protected_regressions.py

echo "LifeRoute v0.7.1 retained theme-library preparation passed: the complete Build #98 architecture remains locked; eight finished Dynamic identities use distinct root-driven full-screen compositions; twelve Scenery identities across six Day/Night families use bundled cinematic artwork and restrained shared-phase ambience; Theme Center hides retired placeholders; and protected navigation, calendar, routing, ABA, timer, Live Activity, identity, persistence, and legacy-runtime contracts remain intact."

# Terminal DEBUG-only validation hooks accept all retained identifiers, force a deterministic
# Reduce Motion phase, and use a process signal to move between real tabs in one process. Production theme ownership,
# clocks, navigation, and release behavior remain unchanged.
python3 scripts/patch_v0_7_1_theme_fixture_matrix.py
python3 scripts/audit_v0_7_1_theme_fixture_matrix.py
python3 scripts/audit_v0_7_1_scenery_library_finish.py
python3 scripts/audit_v0_7_1_dynamic_library_finish.py
python3 scripts/audit_v0_7_1_protected_regressions.py

echo "LifeRoute v0.7.1 retained theme fixture preparation passed: the DEBUG-only twenty-theme Simulator matrix validates in-process tab persistence, motion, scene distinction, Reduce Motion, image health, and readable shell text without changing production theme ownership, clocks, navigation, or release behavior."

# v0.8.0 functionality pass 1: Master ABA Session Note parity. Keep this as a new cumulative layer
# after the protected v0.7.x materialization rather than weakening historical note/runtime checkpoints.
python3 -m py_compile scripts/patch_v0_8_0_master_aba_note.py scripts/audit_v0_8_0_master_aba_note.py
python3 scripts/patch_v0_8_0_master_aba_note.py
python3 scripts/audit_v0_8_0_master_aba_note.py

# Re-run non-superseded protected architecture after the note generator changes. These audits are
# intentionally post-v0.8.0 so a note-only patch cannot silently regress navigation/state/persistence.
python3 scripts/audit_v0_5_0_functional_shell.py
python3 scripts/audit_v0_5_0_core_navigation.py
python3 scripts/audit_v0_5_0_calendar_core.py
python3 scripts/audit_v0_5_0_routing_location_core.py
python3 scripts/audit_v0_5_0_clients_core.py
python3 scripts/audit_v0_5_0_stability_architecture.py
python3 scripts/audit_v0_7_1_protected_regressions.py

echo "LifeRoute v0.8.0 functionality pass 1 preparation passed: Master ABA session-note behavior is materialized and regression-audited on top of the protected v0.7.1 candidate state."

# v0.8.0 functionality pass 2 foundation: approved ABA visual-support image workflow. This adds
# one reviewed photo/text-to-illustrated-icon path while preserving the existing library/builders.
python3 -m py_compile \
  scripts/patch_v0_8_0_aba_visual_generator_foundation.py \
  scripts/patch_v0_8_0_aba_visual_generator_performance_hotfix.py \
  scripts/audit_v0_8_0_aba_visual_generator_foundation.py
python3 scripts/patch_v0_8_0_aba_visual_generator_foundation.py
python3 scripts/patch_v0_8_0_aba_visual_generator_performance_hotfix.py
python3 scripts/audit_v0_8_0_aba_visual_generator_foundation.py

# Re-run the note contract and visual/persistence/performance ownership after the image foundation.
python3 scripts/audit_v0_8_0_master_aba_note.py
python3 scripts/audit_v0_5_0_client_visual_supports.py
python3 scripts/audit_v0_5_0_client_visual_persistence.py
python3 scripts/audit_v0_5_0_performance_architecture.py
python3 scripts/audit_v0_5_0_stability_architecture.py
python3 scripts/audit_v0_5_0_second_functionality_pass.py
python3 scripts/audit_v0_7_1_protected_regressions.py

echo "LifeRoute v0.8.0 ABA visual-support foundation preparation passed: the canonical Master Image Prompt, exact native labels, supported Image Playground review, square icon normalization, existing protected visual libraries, and all retained regression contracts are locked."

# v0.8.0 shipped-runtime repair: keep this cumulative layer last among current note-owned changes.
# It replaces the unbounded loose UI flags with a cancellable state machine, exposes actual model
# availability reasons, bounds both the initial and repair pass, and supplies DEBUG-only fixtures.
python3 -m py_compile \
  scripts/patch_v0_8_0_session_note_runtime_fix.py \
  scripts/audit_v0_8_0_session_note_runtime_fix.py
python3 scripts/patch_v0_8_0_session_note_runtime_fix.py
python3 scripts/audit_v0_8_0_session_note_runtime_fix.py

# Re-lock clinical, visual, protected-theme, stability, and performance contracts after the runtime fix.
python3 scripts/audit_v0_8_0_master_aba_note.py
python3 scripts/audit_v0_8_0_aba_visual_generator_foundation.py
python3 scripts/audit_v0_7_1_protected_regressions.py
python3 scripts/audit_v0_5_0_performance_architecture.py
python3 scripts/audit_v0_5_0_stability_architecture.py

echo "LifeRoute v0.8.0 session-note runtime preparation passed: every generation resolves to a visible success, unavailable, failed, timed-out, or cancelled state; session facts, screenshot input, and prior drafts survive failures; the Master ABA repair pass is visible and bounded; and the complete inherited clinical/theme/stability contracts remain locked."

# v0.8.0 post-Build #104 targeted refinement pass. Keep each feature as a separate cumulative
# materialization layer so the shipped runtime remains the auditable base and generated Swift is
# never edited by hand. The follow-up audits own the intentionally superseded screenshot, timer,
# visual-generator entry, and scenery-detail contracts.
python3 -m py_compile \
  scripts/patch_v0_8_0_session_note_followup.py \
  scripts/audit_v0_8_0_session_note_followup.py \
  scripts/patch_v0_8_0_visual_generator_followup.py \
  scripts/audit_v0_8_0_visual_generator_followup.py \
  scripts/patch_v0_8_0_scenery_motion_followup.py \
  scripts/audit_v0_8_0_scenery_motion_followup.py \
  scripts/patch_v0_8_0_visual_timer_audio_followup.py \
  scripts/audit_v0_8_0_visual_timer_audio_followup.py

# Clinical-note refinement: RBT-only narrative language, stronger grounded clinical synthesis,
# ordered multi-screenshot OCR, and measurement-type-aware evidence handling.
python3 scripts/patch_v0_8_0_session_note_followup.py
python3 scripts/audit_v0_8_0_session_note_followup.py

# Visual-support refinement: expose the existing illustrated workflow from the primary dashboard,
# clarify reference-versus-generated review, and retain the protected library persistence path.
python3 scripts/patch_v0_8_0_visual_generator_followup.py
python3 scripts/audit_v0_8_0_visual_generator_followup.py

# Scenery refinement: add only bounded, deterministic Rainforest leaves and Arctic snow to the
# existing single root clock; no new timers, random state, or independent animation ownership.
python3 scripts/patch_v0_8_0_scenery_motion_followup.py
python3 scripts/audit_v0_8_0_scenery_motion_followup.py

# Visual-timer refinement: a gentle deterministic pulse maps normalized elapsed progress from
# 432 to 864 Hz and from one to six ticks per second while preserving mute and timer controls.
python3 scripts/patch_v0_8_0_visual_timer_audio_followup.py
python3 scripts/audit_v0_8_0_visual_timer_audio_followup.py

# Re-run only non-superseded broad contracts on the final tree. The earlier historical audits lock
# their own checkpoints before the intentional follow-up replacements; the focused audits above
# own the new behavior while these checks protect navigation, persistence, stability, and performance.
python3 scripts/audit_v0_5_0_functional_shell.py
python3 scripts/audit_v0_5_0_core_navigation.py
python3 scripts/audit_v0_5_0_client_visual_supports.py
python3 scripts/audit_v0_5_0_client_visual_persistence.py
python3 scripts/audit_v0_5_0_performance_architecture.py
python3 scripts/audit_v0_5_0_stability_architecture.py
python3 scripts/audit_v0_5_0_second_functionality_pass.py

echo "LifeRoute v0.8.0 post-Build #104 follow-up preparation passed: session notes use RBT-only grounded clinical prose with ordered multi-screenshot and typed-measurement evidence; the illustrated visual-support generator is visibly reachable and preserves library persistence; Rainforest and Arctic scenery gain bounded root-driven ambient detail; the Visual Timer advances gently from 432 to 864 Hz and one to six ticks per second; and retained navigation, visual-support, persistence, performance, and stability contracts remain locked."

# v0.8.1 physical-regression and performance checkpoint: repair the known Build #106 failure paths,
# remove the exposed Visual Schedule entry, and introduce horizontal paging plus toolbar policy on
# top of the same authoritative router and theme root.
python3 -m py_compile \
  scripts/audit_v0_8_1_session_note_and_visual_prompt.py \
  scripts/audit_v0_8_1_navigation_toolbar_schedule.py \
  scripts/audit_v0_8_1_release_prep.py
python3 scripts/audit_v0_8_1_session_note_and_visual_prompt.py
python3 scripts/audit_v0_8_1_navigation_toolbar_schedule.py
python3 scripts/audit_v0_8_1_release_prep.py

# Re-run inherited regression coverage on the final tree after the v0.8.1 follow-up.
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
python3 scripts/audit_v0_7_1_protected_regressions.py

echo "LifeRoute v0.8.1 physical-regression preparation passed: the Build #106 session-note failure path is bounded and recoverable, the ABA visual-support generator interprets concepts before prompt formation, Visual Schedule is removed from the exposed UI, main sections page horizontally with synchronized toolbar selection, the toolbar hides on deep routes, and inherited navigation, persistence, performance, and stability contracts remain locked."
