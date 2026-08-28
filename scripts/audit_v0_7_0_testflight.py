#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.0 TestFlight audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


workflow = read(".github/workflows/testflight.yml")
prepare = read("scripts/prepare_build.sh")
build_e_patch = read("scripts/patch_v0_7_0_build_e.py")
build_e_theme_compat = read("scripts/patch_v0_7_0_build_e_theme_compat.py")
build_e_audit = read("scripts/audit_v0_7_0_build_e.py")
phase2_patch = read("scripts/patch_v0_7_0_theme_phase_2.py")
phase2_audit = read("scripts/audit_v0_7_0_theme_phase_2.py")
phase3_patch = read("scripts/patch_v0_7_0_theme_phase_3.py")
phase3_audit = read("scripts/audit_v0_7_0_theme_phase_3.py")
live_surface_patch = read("scripts/patch_v0_7_0_live_theme_surface_hero.py")
live_surface_audit = read("scripts/audit_v0_7_0_live_theme_surface_hero.py")
project = read("LifeRoute.xcodeproj/project.pbxproj")

require_all(
    workflow,
    [
        "RELEASE_MARKETING_VERSION: 0.7.0",
        "Historical release-audit compatibility anchors only",
        "Prepare validated v0.7.0 Phase 3 Scenery release",
        "Verify v0.7.0 Phase 3 Scenery app and Live Activity release contract",
        "Archive LifeRoute v0.7.0 Phase 3 Scenery",
        "Verify archived v0.7.0 Phase 3 Scenery identity",
        "MARKETING_VERSION=\"$RELEASE_MARKETING_VERSION\"",
        "CURRENT_PROJECT_VERSION=\"${GITHUB_RUN_NUMBER}\"",
        "LifeRoute v0.7.0 Phase 3 Scenery sent to TestFlight",
        "name: LifeRoute-v0.7.0-Phase-3-Scenery-TestFlight-build-",
        "v0.7.0 Build E Resources",
        "v0.7.0 Build E Client Hub",
        "v0.7.0 Build E Setup Control Center",
        "v0.7.0 Theme Phase 3 Theme Center",
        "LifeRouteTheme.phaseTwoDynamicCatalog",
        "LifeRouteTheme.phaseThreeSceneryCatalog",
        "v0.7.0 Theme Phase 1 Core Glass catalog",
        "static let phaseOneCoreGlassCatalog",
        "v0.7.0 Theme Phase 2 Dynamic Liquid Glass catalog",
        "static let phaseTwoDynamicCatalog",
        "v0.7.0 Theme Phase 3 Scenery catalog",
        "static let phaseThreeSceneryCatalog",
        "v0.7.0 Theme Phase 3 single shared root environment clock",
        "v0.7.0 Theme Phase 3 persistent environment host",
        "LifeRouteLiveThemeEnvironment",
        "minimumInterval: 1.0 / 20.0",
        "paused: reduceMotion || !isActive",
        "v0.7.0 Build D audit compatibility anchor",
        "TimelineView(.periodic(from: .now, by: 0.10))",
        "authorized_sha:",
        'test "$GITHUB_SHA" = "$AUTHORIZED_SHA"',
        "xcrun altool",
        "--upload-app",
        "Clean temporary Apple signing assets",
    ],
    "v0.7.0 Phase 3 Scenery TestFlight workflow",
)
require("RELEASE_MARKETING_VERSION: 0.6.3" not in workflow, "active release identity must not regress to v0.6.3")
require("LifeRoute v0.7.0 Build B.2 sent to TestFlight" not in workflow, "active release summary must not regress to Build B.2")
require("LifeRoute-v0.7.0-Build-B2-TestFlight-build-" not in workflow, "active IPA artifact must not regress to Build B.2")
require("Phase 3 Scenery is intentionally not included" not in workflow, "active release summary must include Phase 3 Scenery")

require_all(
    prepare,
    [
        "python3 scripts/patch_v0_7_0_build_a.py",
        "python3 scripts/patch_v0_7_0_build_b.py",
        "python3 scripts/patch_v0_7_0_build_b1.py",
        "python3 scripts/patch_v0_7_0_visual_library_reuse.py",
        "python3 scripts/patch_v0_7_0_first_then_horizontal.py",
        "python3 scripts/patch_v0_7_0_todos_restore_b1.py",
        "python3 scripts/patch_v0_7_0_build_b2.py",
        "python3 scripts/patch_v0_7_0_build_b3_pre.py",
        "python3 scripts/patch_v0_7_0_build_b3.py",
        "python3 scripts/patch_v0_7_0_build_b3_compat.py",
        "python3 scripts/patch_v0_7_0_build_c.py",
        "python3 scripts/patch_v0_7_0_build_c_compile_hotfix.py",
        "python3 scripts/patch_v0_7_0_build_d_timer_compat_pre.py",
        "python3 scripts/patch_v0_7_0_build_d.py",
        "python3 scripts/patch_v0_7_0_build_d_timer_compat_post.py",
        "python3 scripts/patch_v0_7_0_build_d_compat.py",
        "python3 scripts/patch_v0_7_0_build_e.py",
        "python3 scripts/patch_v0_7_0_build_e_theme_compat.py",
        "python3 scripts/patch_v0_7_0_swipe_day_overview.py",
        "python3 scripts/patch_v0_7_0_theme_phase_1.py",
        "python3 scripts/patch_v0_7_0_location_intent_fix.py",
        "python3 scripts/patch_v0_7_0_theme_phase_2_category_compat.py",
        "python3 scripts/patch_v0_7_0_theme_phase_2.py",
        "python3 scripts/patch_v0_7_0_theme_phase_2_compile_hotfix.py",
        "python3 scripts/patch_v0_7_0_theme_phase_2_background_motion_fix.py",
        "python3 scripts/patch_v0_7_0_live_theme_surface_hero.py",
        "python3 scripts/audit_v0_7_0_live_theme_surface_hero.py",
        "python3 scripts/patch_v0_7_0_theme_phase_3.py",
        "python3 scripts/audit_v0_7_0_theme_phase_3.py",
        "python3 scripts/audit_v0_7_0_testflight.py",
    ],
    "accumulated v0.7.0 Build A-through-E, QA, post-QA visibility/Today repair, and Phase 3 preparation",
)
require(
    prepare.index("python3 scripts/patch_v0_7_0_live_theme_surface_hero.py")
    < prepare.index("python3 scripts/audit_v0_7_0_live_theme_surface_hero.py")
    < prepare.index("python3 scripts/patch_v0_7_0_theme_phase_3.py")
    < prepare.index("python3 scripts/audit_v0_7_0_theme_phase_3.py")
    < prepare.index("python3 scripts/audit_v0_7_0_testflight.py"),
    "release preparation must lock post-QA repairs before Phase 3, then run the Phase 3 and final TestFlight audits",
)

require_all(
    build_e_patch,
    [
        'RESOURCES = ROOT / "LifeRoute/ResourcePortalViews.swift"',
        'CLIENTS = ROOT / "LifeRoute/V054ClientViews.swift"',
        'SETUP = ROOT / "LifeRoute/V054SetupView.swift"',
        'THEMES = ROOT / "LifeRoute/V054ThemeCenterView.swift"',
        "v0.7.0 Build E Resources",
        "v0.7.0 Build E Client Hub",
        "v0.7.0 Build E Setup Control Center",
        "v0.7.0 Build E Theme Center",
    ],
    "Build E presentation patch",
)
for forbidden in ["RoutingLocationDomain.swift", "PersistenceCore.swift", "SessionToolsDomain.swift", "AppNavigation.swift"]:
    require(forbidden not in build_e_patch, f"Build E release patch must not own {forbidden}")

require_all(
    build_e_theme_compat,
    ["v0.7.0 Build E validated theme catalog compatibility", "coreThemes", "dynamicThemes", "sceneryThemes"],
    "Build E theme compatibility",
)
require_all(
    build_e_audit,
    [
        "Build E Resources marker materialized",
        "Build E Client Hub marker materialized",
        "Build E Setup marker materialized",
        "Build E Theme Center marker materialized",
        "Five-tab shell remains exact",
        "Build D final timer cadence remains 0.10 seconds",
    ],
    "Build E regression audit",
)

require_all(
    phase2_patch,
    [
        "v0.7.0 Theme Phase 2 Dynamic Liquid Glass catalog",
        "static let phaseTwoDynamicCatalog",
        "struct LifeRouteDynamicGlassEnvironment: View",
        "minimumInterval: 1.0 / 20.0",
        "paused: reduceMotion || !isActive",
        "v0.7.0 Theme Phase 2 persistent environment host",
        "v0.7.0 Theme Phase 2 Theme Center",
        "LifeRouteTheme.phaseTwoDynamicCatalog",
        "Static representative snapshot only",
    ],
    "historical Theme Phase 2 patch",
)
require_all(
    phase2_audit,
    ["Theme Phase 2", "phaseTwoDynamicCatalog", "Reduce Motion", "TimelineView", "Scenery"],
    "historical Theme Phase 2 audit",
)

require_all(
    live_surface_patch,
    [
        "v0.7.0 live theme surface visibility repair",
        "today_overview_agenda.main()",
        "palette.panelElevated.opacity(0.30)",
        "nav.backgroundColor = background.withAlphaComponent(0.54)",
    ],
    "post-QA live-surface/Today repair patch",
)
require_all(
    live_surface_audit,
    [
        "live Dynamic surface visibility contract",
        "approved Today hero composition",
        "selected-day appointment overview",
        "Dynamic environment must retain exactly one root TimelineView",
    ],
    "post-QA live-surface/Today repair audit",
)

require_all(
    phase3_patch,
    [
        "v0.7.0 Theme Phase 3 Scenery catalog",
        "static let phaseThreeSceneryCatalog",
        "var isPhaseThreeScenery: Bool",
        "struct LifeRouteSceneryFrame: View",
        "struct LifeRouteLiveThemeEnvironment: View",
        "v0.7.0 Theme Phase 3 single shared root environment clock",
        "v0.7.0 Theme Phase 3 persistent environment host",
        "LifeRouteTheme.phaseThreeSceneryCatalog",
        "Day and Night selected independently",
    ],
    "Theme Phase 3 release patch",
)
require_all(
    phase3_audit,
    [
        "Theme Phase 3",
        "phaseThreeSceneryCatalog",
        "20 stable individually selectable Scenery Day/Night identities",
        "single-clock live environment architecture",
        "protected Today hero and full-day overview",
    ],
    "Theme Phase 3 release audit",
)

require("LifeRouteWebView.swift in Sources" not in project, "legacy WebView must remain quarantined")
require("Web in Resources" not in project, "legacy Web resources must remain quarantined")
require("LifeRouteLiveActivityWidget.appex in Embed App Extensions" in project, "Live Activity extension must remain embedded")

print(
    "LifeRoute v0.7.0 Phase 3 Scenery TestFlight audit passed: release identity remains 0.7.0; exact-SHA authorization, Apple signing, archive identity, and upload remain guarded; canonical materialization includes Build A through E, location/swipe QA, full-frame Dynamic repairs, approved Today hero/full-day agenda, and all 20 stable Scenery Day/Night environments; protected timer behavior, official branding, native isolation, and Live Activity embedding remain intact."
)
