from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "LifeRoute" / "ContentView.swift"
NAVIGATION = ROOT / "LifeRoute" / "AppNavigation.swift"
PROJECT = ROOT / "LifeRoute.xcodeproj" / "project.pbxproj"

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

require("@StateObject private var router = AppRouter()" in content, "ContentView owns exactly one root AppRouter")
require("TabView(selection: $router.selectedSection)" in content, "TabView selection is owned by AppRouter")
require(content.count("NavigationStack(path: $router.") == 5, "Each top-level tab has one router-owned NavigationStack")
require(content.count(".navigationDestination(for: AppRoute.self)") == 5, "Each tab resolves one typed AppRoute destination")
require("NavigationLink(" in content, "Context navigation uses semantic NavigationLink")
require("@Environment(\\.dismiss)" in content and "dismiss()" in content, "Native close/back behavior uses SwiftUI dismiss")
require("router.open(.scheduleDetails, in: .schedule)" in content, "Cross-tab contextual navigation is routed centrally")
require("router.select(.today)" in content, "Direct tab selection goes through AppRouter")
require("router.resetPath(for: .setup)" in content, "Navigation paths can be reset deterministically")

require("final class AppRouter: ObservableObject" in navigation, "AppRouter is the single reference owner for navigation state")
require("@Published var selectedSection: AppSection = .today" in navigation, "AppRouter owns selected top-level section")
for path in ["todayPath", "schedulePath", "toolsPath", "resourcesPath", "setupPath"]:
    require(f"@Published var {path} = NavigationPath()" in navigation, f"AppRouter owns {path}")
require("func open(_ route: AppRoute, in section: AppSection)" in navigation, "Cross-tab route opening has one owner")
require("func resetPath(for section: AppSection)" in navigation, "Path reset has one owner")

require("withAnimation" not in content and ".animation(" not in content, "Navigation core has no cosmetic animation dependency")
require("WKWebView" not in content and "LifeRouteWebView" not in content, "Navigation core has no WebView dependency")
require("AppNavigation.swift in Sources" in project, "AppRouter is compiled into the active native target")
require("LifeRouteWebView.swift in Sources" not in project, "Legacy WebView remains quarantined")
require("Web in Resources" not in project, "Legacy Web resources remain quarantined")

if errors:
    print("LifeRoute v0.5.0 core-navigation audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute v0.5.0 core-navigation audit passed ({len(checks)} checks).")
for check in checks:
    print(f"- OK: {check}")
