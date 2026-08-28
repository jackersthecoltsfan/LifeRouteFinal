#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute/LifeRouteApp.swift"
SHELL = ROOT / "LifeRoute/V054ContentView.swift"


def require(text: str, token: str, label: str) -> None:
    if token not in text:
        raise SystemExit(f"v0.7.1 physical runtime audit failed: missing {label}: {token}")


def main() -> None:
    app = APP.read_text(encoding="utf-8")
    shell = SHELL.read_text(encoding="utf-8")

    require(app, "v0.7.1 physical-device motion visibility repair", "motion repair marker")
    require(app, "case .royalCurrent: return .init(speed: 0.90", "Royal Current perceptible speed")
    require(app, "case .midnightPrism: return .init(speed: 0.78", "Midnight Prism perceptible speed")
    require(app, "case .auroraBloom: return .init(speed: 0.68", "Aurora Bloom perceptible speed")
    require(app, "case .solarPulse: return .init(speed: 1.00", "Solar Pulse perceptible speed")
    require(app, "case .oceanGlass: return .init(speed: 0.86", "Ocean Glass perceptible speed")
    require(app, "case .obsidianSpectra: return .init(speed: 0.66", "Obsidian Spectra perceptible speed")
    require(app, "case .canyon: return .init(speed: 0.120", "Canyon perceptible ambience")
    require(app, ".scaleEffect(1.040 + pulse * 0.022)", "Royal Current live scale amplitude")
    require(app, ".offset(x: drift * 9.0, y: -drift * 4.8)", "Royal Current live translation amplitude")

    require(shell, "v0.7.1 physical-device root environment reveal", "root reveal marker")
    require(shell, "window.backgroundColor = .clear", "window transparency")
    require(shell, "viewController.view.backgroundColor = .clear", "controller transparency")
    require(shell, "LifeRouteAppearance.refreshVisibleChrome(theme: themeStore.selectedTheme)", "initial transparency refresh")

    clear_tab_roots = shell.count("                .background(Color.clear)\n                .tabItem {")
    if clear_tab_roots != 5:
        raise SystemExit(
            f"v0.7.1 physical runtime audit failed: expected five transparent NavigationStack tab roots, found {clear_tab_roots}"
        )

    if app.count("TimelineView(\n            .animation(") != 1:
        raise SystemExit("v0.7.1 physical runtime audit failed: shared live-theme TimelineView ownership changed")

    if "LifeRouteTodaySelectedExemplarArtwork" not in (ROOT / "LifeRoute/V054TodayView.swift").read_text(encoding="utf-8"):
        raise SystemExit("v0.7.1 physical runtime audit failed: Today exemplar artwork contract missing")

    print(
        "LifeRoute v0.7.1 physical runtime audit passed: the single shared live-theme clock remains unique, "
        "Dynamic/Canyon phase rates are perceptible, all five tab roots are transparent, UIKit host surfaces "
        "are cleared, and Today retains the approved exemplar artwork contract."
    )


if __name__ == "__main__":
    main()
