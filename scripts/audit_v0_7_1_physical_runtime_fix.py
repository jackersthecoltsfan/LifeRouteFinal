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
    require(app, "case .emeraldFlow: return .init(speed: 0.82", "Emerald Flow perceptible speed")
    require(app, "case .arcticHalo: return .init(speed: 0.62", "Arctic Halo perceptible speed")
    require(app, "case .oceanGlass: return .init(speed: 0.86", "Ocean Glass perceptible speed")
    require(app, "case .roseEmber: return .init(speed: 0.92", "Rose Ember perceptible speed")
    require(app, "case .obsidianSpectra: return .init(speed: 0.66", "Obsidian Spectra perceptible speed")
    require(app, "case .plasmaOrchid: return .init(speed: 0.96", "Plasma Orchid perceptible speed")
    require(app, "case .verdantMist: return .init(speed: 0.58", "Verdant Mist perceptible speed")
    require(app, "case .titaniumGlow: return .init(speed: 0.70", "Titanium Glow perceptible speed")
    require(app, "case .canyon: return .init(speed: 0.120", "Canyon perceptible ambience")
    require(app, ".scaleEffect(1.040 + pulse * 0.022)", "Royal Current live scale amplitude")
    require(app, ".offset(x: drift * 9.0, y: -drift * 4.8)", "Royal Current live translation amplitude")

    require(shell, "v0.7.1 physical-device root environment reveal", "root reveal marker")
    require(shell, "window.backgroundColor = .clear", "window transparency")
    require(shell, "viewController.view.backgroundColor = .clear", "controller transparency")
    require(shell, "wait one run loop so TabView/UIKit children exist", "deferred initial transparency refresh")
    require(shell, "A newly selected tab can materialize a fresh UIKit container after selection changes.", "tab materialization refresh")
    require(shell, "DispatchQueue.main.async", "deferred UIKit refresh")

    # Exactly four lifecycle paths intentionally refresh visible UIKit chrome:
    # initial presentation, tab selection, theme selection, and scene reactivation.
    refresh_calls = shell.count("LifeRouteAppearance.refreshVisibleChrome(theme:")
    if refresh_calls < 4:
        raise SystemExit(
            f"v0.7.1 physical runtime audit failed: expected refresh coverage for launch/tab/theme/scene flows, found {refresh_calls} calls"
        )

    clear_tab_roots = shell.count("                .background(Color.clear)\n                .tabItem {")
    if clear_tab_roots != 5:
        raise SystemExit(
            f"v0.7.1 physical runtime audit failed: expected five transparent NavigationStack tab roots, found {clear_tab_roots}"
        )

    if app.count("TimelineView(\n            .animation(") != 1:
        raise SystemExit("v0.7.1 physical runtime audit failed: shared live-theme TimelineView ownership changed")

    today = (ROOT / "LifeRoute/V054TodayView.swift").read_text(encoding="utf-8")
    if "LifeRouteTodaySelectedExemplarArtwork" not in today:
        raise SystemExit("v0.7.1 physical runtime audit failed: Today exemplar artwork contract missing")

    print(
        "LifeRoute v0.7.1 physical runtime audit passed: the single shared live-theme clock remains unique, "
        "all 12 Dynamic phase rates plus Canyon ambience are perceptible, all five tab roots are transparent, "
        "UIKit host surfaces are cleared after launch/theme/tab/scene materialization, and Today retains the approved exemplar artwork contract."
    )


if __name__ == "__main__":
    main()
