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
project = read("LifeRoute.xcodeproj/project.pbxproj")

# The historical Phase 2 release contract remains auditable, while later validated release
# workflows may supersede its UI-marker greps. Common signing/exact-SHA guards must never regress.
require_all(
    workflow,
    [
        "RELEASE_MARKETING_VERSION: 0.7.0",
        "Historical release-audit compatibility anchors only",
        "Prepare validated v0.7.0 Theme Phase 2 release",
        "Verify v0.7.0 Theme Phase 2 app and Live Activity release contract",
        "Archive LifeRoute v0.7.0 Theme Phase 2",
        "Verify archived v0.7.0 Theme Phase 2 identity",
        "LifeRoute v0.7.0 Theme Phase 2 sent to TestFlight",
        "name: LifeRoute-v0.7.0-Theme-Phase-2-TestFlight-build-",
        "v0.7.0 Theme Phase 2 Theme Center",
        "v0.7.0 Theme Phase 2 persistent environment host",
        "MARKETING_VERSION=\"$RELEASE_MARKETING_VERSION\"",
        "CURRENT_PROJECT_VERSION=\"${GITHUB_RUN_NUMBER}\"",
        "authorized_sha:",
        'test "$GITHUB_SHA" = "$AUTHORIZED_SHA"',
        "xcrun altool",
        "--upload-app",
        "Clean temporary Apple signing assets",
    ],
    "guarded TestFlight workflow",
)

legacy_phase2_release = all(
    token in workflow
    for token in [
        "v0.7.0 Build E Resources",
        "v0.7.0 Build E Client Hub",
        "v0.7.0 Build E Setup Control Center",
        "LifeRouteTheme.phaseTwoDynamicCatalog",
        "v0.7.0 Theme Phase 1 Core Glass catalog",
        "static let phaseOneCoreGlassCatalog",
        "v0.7.0 Theme Phase 2 Dynamic Liquid Glass catalog",
        "static let phaseTwoDynamicCatalog",
        "minimumInterval: 1.0 / 20.0",
        "paused: reduceMotion || !isActive",
        "v0.7.0 Build D audit compatibility anchor",
        "TimelineView(.periodic(from: .now, by: 0.10))",
    ]
)

v071_finishing_release = all(
    token in workflow
    for token in [
        "Prepare validated v0.7.1 finishing release",
        "Verify v0.7.1 finishing app and Live Activity release contract",
        "python3 scripts/audit_v0_7_1_physical_runtime_fix.py",
        "v0.7.1 physical-device motion visibility repair",
        "v0.7.1 physical-device root environment reveal",
        "v0.7.1 custom LifeRoute bottom toolbar",
        "v0.7.1 Setup disclosure groups",
        "static let phaseOneCoreGlassCatalog",
        "static let phaseTwoDynamicCatalog",
        "static let phaseThreeSceneryCatalog",
        "LifeRouteLiveThemeEnvironment",
        "minimumInterval: 1.0 / 20.0",
        "paused: reduceMotion || !isActive",
        "TimelineView(.periodic(from: .now, by: 0.10))",
        "12 Core + 8 Dynamic + 12 Scenery",
        "Archive LifeRoute v0.7.1 finishing candidate",
        "Verify archived v0.7.1 finishing identity",
        "LifeRoute-v0.7.1-Finishing-TestFlight-build-",
    ]
)
require(
    legacy_phase2_release or v071_finishing_release,
    "workflow must retain either the historical Phase 2 release assertions or the validated v0.7.1 finishing supersession",
)

require("RELEASE_MARKETING_VERSION: 0.6.3" not in workflow, "active release identity must not regress to v0.6.3")
require("LifeRoute v0.7.0 Build B.2 sent to TestFlight" not in workflow, "active release summary must not regress to Build B.2")
require("LifeRoute-v0.7.0-Build-B2-TestFlight-build-" not in workflow, "active IPA artifact must not regress to Build B.2")

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
        "python3 scripts/patch_v0_7_0_theme_phase_3.py",
        "python3 scripts/patch_v0_7_1_theme_visual_runtime_fix.py",
        "python3 scripts/patch_v0_7_1_physical_runtime_fix.py",
        "python3 scripts/audit_v0_7_1_physical_runtime_fix.py",
        "python3 scripts/audit_v0_7_1_protected_regressions.py",
    ],
    "accumulated v0.7.0 through v0.7.1 canonical preparation",
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
require("RoutingLocationDomain.swift" not in build_e_patch, "Build E release patch must not own routing domain")
require("PersistenceCore.swift" not in build_e_patch, "Build E release patch must not own persistence domain")
require("SessionToolsDomain.swift" not in build_e_patch, "Build E release patch must not own timer domain")
require("AppNavigation.swift" not in build_e_patch, "Build E release patch must not own AppRouter")

require_all(
    build_e_theme_compat,
    [
        "v0.7.0 Build E validated theme catalog compatibility",
        "coreThemes",
        "dynamicThemes",
        "sceneryThemes",
    ],
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
    "Theme Phase 2 release patch",
)
require_all(
    phase2_audit,
    [
        "Theme Phase 2",
        "phaseTwoDynamicCatalog",
        "Reduce Motion",
        "TimelineView",
        "Scenery",
    ],
    "Theme Phase 2 release audit",
)

require("LifeRouteWebView.swift in Sources" not in project, "legacy WebView must remain quarantined")
require("Web in Resources" not in project, "legacy Web resources must remain quarantined")
require("LifeRouteLiveActivityWidget.appex in Embed App Extensions" in project, "Live Activity extension must remain embedded")

print(
    "LifeRoute TestFlight audit passed: historical Phase 2 release safeguards remain auditable, the current v0.7.1 finishing workflow may supersede obsolete UI-marker greps, exact-SHA authorization and Apple upload remain guarded, canonical materialization remains cumulative, native isolation and Live Activity embedding remain protected."
)
