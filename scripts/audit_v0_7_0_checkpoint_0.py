#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.0 Checkpoint 0 audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


def main() -> None:
    contract = read("LIFEROUTE_V0_7_0_VISUAL_CONTRACT.md")
    navigation = read("LifeRoute/AppNavigation.swift")
    shell = read("LifeRoute/V054ContentView.swift")
    prepare = read("scripts/prepare_build.sh")

    require_all(
        contract,
        [
            "9471190b41c073a39c100cd2482f0b7b665d714b",
            "Build A",
            "Build F",
            "Today, Schedule, Tools, Resources, Setup",
            "Core themes remain **color schemes only**",
            "AppRouter",
            "iOS 16 compatibility",
            "actual iOS Simulator compile",
        ],
        "visual contract",
    )

    require_all(
        navigation,
        [
            "case today",
            "case schedule",
            "case tools",
            "case resources",
            "case setup",
            "final class AppRouter: ObservableObject",
            "@Published var selectedSection: AppSection = .today",
            "@Published var todayPath = NavigationPath()",
            "@Published var schedulePath = NavigationPath()",
            "@Published var toolsPath = NavigationPath()",
            "@Published var resourcesPath = NavigationPath()",
            "@Published var setupPath = NavigationPath()",
        ],
        "protected navigation architecture",
    )

    require_all(
        shell,
        [
            "TabView(selection: $router.selectedSection)",
            "V054TodayView(",
            "V054ScheduleView(",
            "V054ToolsDashboard(",
            "ResourcePortalHubView()",
            "V054SetupView(",
            ".tag(AppSection.today)",
            ".tag(AppSection.schedule)",
            ".tag(AppSection.tools)",
            ".tag(AppSection.resources)",
            ".tag(AppSection.setup)",
        ],
        "five-destination native shell",
    )
    require("LifeRouteWebView" not in shell, "legacy WebView must remain outside the active native shell")

    require(
        "python3 scripts/audit_v0_7_0_checkpoint_0.py" in prepare,
        "canonical preparation must run the Checkpoint 0 audit",
    )

    print(
        "LifeRoute v0.7.0 Checkpoint 0 audit passed: visual contract locked, five-tab AppRouter architecture preserved, native shell intact, Core/Scenery scope separated, and Build A guardrails ready."
    )


if __name__ == "__main__":
    main()
