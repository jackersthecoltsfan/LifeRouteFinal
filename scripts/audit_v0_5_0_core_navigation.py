from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGACY_CONTENT = ROOT / "LifeRoute" / "ContentView.swift"
V054_CONTENT = ROOT / "LifeRoute" / "V054ContentView.swift"
TODAY = ROOT / "LifeRoute" / "V054TodayView.swift"
TOOLS = ROOT / "LifeRoute" / "V054ToolsDashboard.swift"
SETUP = ROOT / "LifeRoute" / "V054SetupView.swift"
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


project = read(PROJECT)
active_v054 = "V054ContentView.swift in Sources" in project
content = read(V054_CONTENT) if active_v054 else read(LEGACY_CONTENT)
children = "\n".join(read(path) for path in [TODAY, TOOLS, SETUP] if path.exists()) if active_v054 else content
navigation = read(NAVIGATION)

require("@StateObject private var router = AppRouter()" in content, "Active shell owns exactly one root AppRouter")
require("TabView(selection: $router.selectedSection)" in content, "TabView selection is owned by AppRouter")
require(content.count("NavigationStack(path: $router.") == 5, "Each top-level tab has one router-owned NavigationStack")
require("NavigationLink" in children, "Context navigation uses semantic NavigationLink")
require("router.select(" in (content + children), "Direct tab selection goes through AppRouter")

require("final class AppRouter: ObservableObject" in navigation, "AppRouter is the single reference owner for navigation state")
require("@Published var selectedSection: AppSection = .today" in navigation, "AppRouter owns selected top-level section")
for path in ["todayPath", "schedulePath", "toolsPath", "resourcesPath", "setupPath"]:
    require(f"@Published var {path} = NavigationPath()" in navigation, f"AppRouter owns {path}")
require("func open(_ route: AppRoute, in section: AppSection)" in navigation, "Cross-tab route opening remains centrally owned for compatibility")
require("selectedSection = section" in navigation and ".append(route)" in navigation, "Cross-tab contextual navigation remains routed centrally")
require("func resetPath(for section: AppSection)" in navigation, "Path reset has one owner")
require(navigation.count("= NavigationPath()") >= 10, "Navigation paths can be reset deterministically")

require("WKWebView" not in content and "LifeRouteWebView" not in content, "Navigation core has no WebView dependency")
require("AppNavigation.swift in Sources" in project, "AppRouter is compiled into the active native target")
require("LifeRouteWebView.swift in Sources" not in project, "Legacy WebView remains quarantined")
require("Web in Resources" not in project, "Legacy Web resources remain quarantined")
require(
    (active_v054 and "ContentView.swift in Sources" not in project and "typealias ContentView = V054ContentView" in content)
    or (not active_v054 and "ContentView.swift in Sources" in project),
    "Exactly one reviewed app shell owns runtime navigation",
)

if errors:
    print("LifeRoute v0.5 core-navigation audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute v0.5 core-navigation audit passed ({len(checks)} checks).")
for check in checks:
    print(f"- OK: {check}")
