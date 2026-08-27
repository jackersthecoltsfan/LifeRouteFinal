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
today_patch = read("scripts/patch_v0_7_0_build_b.py")
today_parity_patch = read("scripts/patch_v0_7_0_build_b1.py")
today_b2_patch = read("scripts/patch_v0_7_0_build_b2.py")
today_audit = read("scripts/audit_v0_7_0_build_b.py")
today_parity_audit = read("scripts/audit_v0_7_0_build_b1.py")
today_b2_audit = read("scripts/audit_v0_7_0_build_b2.py")
project = read("LifeRoute.xcodeproj/project.pbxproj")

require_all(
    workflow,
    [
        "RELEASE_MARKETING_VERSION: 0.7.0",
        "Prepare validated v0.7.0 Build B.2 release",
        "Verify v0.7.0 Build B.2 app and Live Activity release contract",
        "Archive LifeRoute v0.7.0 Build B.2",
        "Verify archived v0.7.0 Build B.2 identity",
        "MARKETING_VERSION=\"$RELEASE_MARKETING_VERSION\"",
        "CURRENT_PROJECT_VERSION=\"${GITHUB_RUN_NUMBER}\"",
        "LifeRoute v0.7.0 Build B.2 sent to TestFlight",
        "LifeRoute-v0.7.0-Build-B2-TestFlight-build-",
        "v0.7.0 Build B.2 device QA",
        "v0.7.0 B.2 save and fullscreen preview",
        "authorized_sha:",
        'test "$GITHUB_SHA" = "$AUTHORIZED_SHA"',
        "xcrun altool",
        "--upload-app",
        "Clean temporary Apple signing assets",
    ],
    "v0.7.0 Build B.2 TestFlight workflow",
)
require("RELEASE_MARKETING_VERSION: 0.6.3" not in workflow, "active release identity must not remain v0.6.3")
require("Build B.1 sent to TestFlight" not in workflow, "active release summary must identify Build B.2")
require("Build-B1-TestFlight-build-" not in workflow, "active IPA artifact must identify Build B.2")

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
        "python3 scripts/audit_v0_7_0_build_a.py",
        "python3 scripts/audit_v0_7_0_build_b.py",
        "python3 scripts/audit_v0_7_0_build_b1.py",
        "python3 scripts/audit_v0_7_0_visual_library_reuse.py",
        "python3 scripts/audit_v0_7_0_first_then_horizontal.py",
        "python3 scripts/audit_v0_7_0_todos_restore.py",
        "python3 scripts/audit_v0_7_0_build_b2.py",
    ],
    "accumulated Build A + B + B.1 + B.2 preparation",
)

require("v0.7.0 Build B Today/Home" in today_patch, "Build B Today/Home patch must be present")
require("v0.7.0 Build B.1 Today/Home parity" in today_parity_patch, "Build B.1 parity patch must be present")
require("v0.7.0 Build B.2 device QA" in today_b2_patch, "Build B.2 device-QA patch must be present")
require("v0.7.0 B.2 save and fullscreen preview" in today_b2_patch, "Build B.2 visual save/full-screen patch must be present")
require("selected-day regression contract" in today_audit, "Build B selected-day acceptance gate must be present")
require("persistent day selector must not remain" in today_parity_audit, "Build B.1 target-density gate must be present")
require("persistent Save & Preview actions" in today_b2_audit, "Build B.2 visual-save gate must be present")
require("real-device Home density pass" in today_b2_audit, "Build B.2 Home-density gate must be present")

require("LifeRouteWebView.swift in Sources" not in project, "legacy WebView must remain quarantined")
require("Web in Resources" not in project, "legacy Web resources must remain quarantined")
require("LifeRouteLiveActivityWidget.appex in Embed App Extensions" in project, "Live Activity extension must remain embedded")

print("LifeRoute v0.7.0 Build B.2 TestFlight audit passed: release identity remains 0.7.0, exact-SHA guard remains available, Build A/B/B.1/B.2 preparation is accumulated, real-device Home and full-screen visual-save corrections are guarded, native isolation is intact, and upload/archive identity is protected.")
