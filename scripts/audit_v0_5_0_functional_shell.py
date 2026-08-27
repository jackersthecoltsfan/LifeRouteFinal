from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "LifeRoute" / "ContentView.swift"
NAVIGATION = ROOT / "LifeRoute" / "AppNavigation.swift"
PROJECT = ROOT / "LifeRoute.xcodeproj" / "project.pbxproj"
PREPARE = ROOT / "scripts" / "prepare_build.sh"

errors: list[str] = []
checks: list[str] = []


def require(condition: bool, message: str) -> None:
    if condition:
        checks.append(message)
    else:
        errors.append(message)


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception as exc:
        errors.append(f"Could not read {path.relative_to(ROOT)}: {exc}")
        return ""


content = read(CONTENT)
navigation = read(NAVIGATION)
project = read(PROJECT)
prepare = read(PREPARE)

# Native-only functional-shell contract. Labels may live in the centralized
# AppSection model; this audit verifies behavior/ownership rather than forcing
# view-local string duplication.
require("TabView(selection:" in content, "One explicit native TabView owns top-level navigation")
for case_name, label in [
    ("today", "Today"),
    ("schedule", "Schedule"),
    ("tools", "Tools"),
    ("resources", "Resources"),
    ("setup", "Setup"),
]:
    require(f"case .{case_name}: return \"{label}\"" in navigation, f"Native top-level destination exists: {label}")
require("NavigationStack" in content, "Navigation uses native NavigationStack")
require("Button(" in content, "Functional shell contains semantic native Button controls")
require("TextField(" in content, "Functional shell contains a semantic native TextField")
require("Toggle(" in content, "Functional shell contains semantic native state controls")
require("LifeRouteWebView()" not in content, "Functional shell does not instantiate legacy WKWebView")
require("WKWebView" not in content and "JavaScript" not in content, "Functional shell has no WebView/JavaScript dependency")
require(
    "No account gate is required to open the app." in content,
    "Setup explicitly documents direct-launch/no-account-gate behavior",
)

# Active Xcode target must compile only the reviewed native core and assets.
require("LifeRouteWebView.swift in Sources" not in project, "Legacy LifeRouteWebView is quarantined from Sources")
require("Web in Resources" not in project, "Legacy Web runtime is quarantined from Resources")
require("LifeRouteApp.swift in Sources" in project, "Native app entry remains in Sources")
require("ContentView.swift in Sources" in project, "Native functional shell remains in Sources")
require("AppNavigation.swift in Sources" in project, "Central native navigation owner remains in Sources")
require("Assets.xcassets in Resources" in project, "App assets remain bundled")

versions = [version.strip() for version in re.findall(r"MARKETING_VERSION = ([^;]+);", project)]
allowed_marketing_versions = {"0.5.0", "0.5.1", "0.5.2", "0.5.3"}
require(bool(versions), "Project contains marketing-version settings")
require(
    bool(versions)
    and len(set(versions)) == 1
    and versions[0] in allowed_marketing_versions,
    "Every active shipping target uses one approved v0.5 marketing version (0.5.0 through 0.5.3)",
)

# Preparation must not resurrect the quarantined v0.4 runtime.
legacy_markers = [
    "patch_global_interaction_reliability_v040.py",
    "patch_stability_v040.py",
    "auth-gate.js",
    "interaction-stability-v3.js",
    "stability-runtime.js",
    "delight-ui-v1.js",
    "CORE_JS=(",
]
for marker in legacy_markers:
    require(marker not in prepare, f"Preparation does not reactivate legacy runtime marker: {marker}")
require("audit_v0_5_0_functional_shell.py" in prepare, "Preparation runs the v0.5.0 functional-shell audit")
require("audit_v0_5_0_core_navigation.py" in prepare, "Preparation runs the v0.5.0 navigation audit")
require("rm -rf build" in prepare, "Preparation clears stale repository-local build output")

if errors:
    print("LifeRoute v0.5 functional-shell audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute v0.5 functional-shell audit passed ({len(checks)} checks).")
for check in checks:
    print(f"- OK: {check}")
