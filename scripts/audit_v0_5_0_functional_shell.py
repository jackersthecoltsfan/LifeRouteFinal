from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGACY_CONTENT = ROOT / "LifeRoute" / "ContentView.swift"
V054_CONTENT = ROOT / "LifeRoute" / "V054ContentView.swift"
V054_TODAY = ROOT / "LifeRoute" / "V054TodayView.swift"
V054_SCHEDULE = ROOT / "LifeRoute" / "V054ScheduleView.swift"
V054_SETUP = ROOT / "LifeRoute" / "V054SetupView.swift"
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


legacy_content = read(LEGACY_CONTENT)
v054_content = read(V054_CONTENT) if V054_CONTENT.exists() else ""
v054_today = read(V054_TODAY) if V054_TODAY.exists() else ""
v054_schedule = read(V054_SCHEDULE) if V054_SCHEDULE.exists() else ""
v054_setup = read(V054_SETUP) if V054_SETUP.exists() else ""
navigation = read(NAVIGATION)
project = read(PROJECT)
prepare = read(PREPARE)

active_v054 = "V054ContentView.swift in Sources" in project
shell = v054_content if active_v054 else legacy_content
interaction_surface = "\n".join([shell, v054_today, v054_schedule, v054_setup]) if active_v054 else legacy_content

# Native-only functional-shell contract. v0.5.4 may activate the restored shell
# while the previous ContentView stays in the repository as a regression reference.
require("TabView(selection:" in shell, "One explicit native TabView owns top-level navigation")
for case_name, label in [
    ("today", "Today"),
    ("schedule", "Schedule"),
    ("tools", "Tools"),
    ("resources", "Resources"),
    ("setup", "Setup"),
]:
    require(f"case .{case_name}: return \"{label}\"" in navigation, f"Native top-level destination exists: {label}")
require("NavigationStack" in shell, "Navigation uses native NavigationStack")
require("Button" in interaction_surface, "Functional shell contains semantic native Button controls")
require("TextField(" in interaction_surface, "Functional shell contains semantic native TextField controls")
require("Toggle(" in interaction_surface, "Functional shell contains semantic native state controls")
require("LifeRouteWebView()" not in shell, "Functional shell does not instantiate legacy WKWebView")
require("WKWebView" not in shell and "JavaScript" not in shell, "Functional shell has no WebView/JavaScript dependency")
require(
    (active_v054 and "typealias ContentView = V054ContentView" in v054_content)
    or (not active_v054 and "No account gate is required to open the app." in legacy_content),
    "App launches directly into the reviewed native shell without an account gate",
)

# Active Xcode target must compile only reviewed native surfaces and assets.
require("LifeRouteWebView.swift in Sources" not in project, "Legacy LifeRouteWebView is quarantined from Sources")
require("Web in Resources" not in project, "Legacy Web runtime is quarantined from Resources")
require("LifeRouteApp.swift in Sources" in project, "Native app entry remains in Sources")
require(
    (active_v054 and "V054ContentView.swift in Sources" in project)
    or (not active_v054 and "ContentView.swift in Sources" in project),
    "Reviewed native functional shell remains in Sources",
)
require("AppNavigation.swift in Sources" in project, "Central native navigation owner remains in Sources")
require("Assets.xcassets in Resources" in project, "App assets remain bundled")

versions = [version.strip() for version in re.findall(r"MARKETING_VERSION = ([^;]+);", project)]
allowed_marketing_versions = {"0.5.0", "0.5.1", "0.5.2", "0.5.3", "0.5.4"}
require(bool(versions), "Project contains marketing-version settings")
require(
    bool(versions)
    and len(set(versions)) == 1
    and versions[0] in allowed_marketing_versions,
    "Every shipping target uses one approved v0.5 marketing version (0.5.0 through 0.5.4)",
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
require("audit_v0_5_0_functional_shell.py" in prepare, "Preparation runs the v0.5 functional-shell audit")
require("audit_v0_5_0_core_navigation.py" in prepare, "Preparation runs the native navigation audit")
require("rm -rf build" in prepare, "Preparation clears stale repository-local build output")

if errors:
    print("LifeRoute v0.5 functional-shell audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute v0.5 functional-shell audit passed ({len(checks)} checks).")
for check in checks:
    print(f"- OK: {check}")
