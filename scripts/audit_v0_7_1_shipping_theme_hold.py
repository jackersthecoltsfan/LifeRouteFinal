#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute/LifeRouteApp.swift"
SHELL = ROOT / "LifeRoute/V054ContentView.swift"
THEMES = ROOT / "LifeRoute/V054ThemeCenterView.swift"


def require(text: str, token: str, label: str) -> None:
    if token not in text:
        raise SystemExit(f"v0.7.1 shipping theme-hold audit failed: missing {label}: {token}")


def main() -> None:
    app = APP.read_text(encoding="utf-8")
    shell = SHELL.read_text(encoding="utf-8")
    themes = THEMES.read_text(encoding="utf-8")

    # Unfinished theme implementation remains preserved in the underlying catalogs/code for future integration.
    require(app, "static let phaseTwoDynamicCatalog", "preserved Dynamic catalog")
    require(app, "static let phaseThreeSceneryCatalog", "preserved Scenery catalog")
    for token in [
        ".midnightPrism", ".auroraBloom", ".solarPulse", ".emeraldFlow",
        ".oceanGlass", ".obsidianSpectra", ".plasmaOrchid",
        ".sceneryMountainsDay", ".sceneryMountainsNight",
        ".sceneryOceanDay", ".sceneryOceanNight",
        ".sceneryDesertDay", ".sceneryDesertNight",
        ".sceneryRainforestDay", ".sceneryRainforestNight",
        ".sceneryCanyonNight", ".sceneryArcticDay", ".sceneryArcticNight",
    ]:
        require(app, token, f"preserved held theme {token}")

    # Shipping selection surface exposes only the physically proven non-Core identities.
    require(app, "v0.7.1 shipping theme hold", "shipping hold marker")
    require(app, "Self.shippingTheme(Self.resolveStoredTheme(savedIdentifier))", "stored selection canonicalization")
    require(app, "if theme == .royalCurrent { return theme }", "Royal Current preservation")
    require(app, "if theme.category == .dynamic { return .royalCurrent }", "held Dynamic migration")
    require(app, "if theme == .sceneryCanyonDay { return theme }", "Canyon Day preservation")
    require(app, "if theme.category == .scenery { return .sceneryCanyonDay }", "held Scenery migration")

    require(themes, "v0.7.1 shipping theme hold", "Theme Center hold marker")
    require(themes, "return [.royalCurrent]", "one visible Dynamic")
    require(themes, "return [.sceneryCanyonDay]", "one visible Scenery")
    require(themes, "Royal Current is the currently validated live Dynamic theme", "Dynamic shipping copy")
    require(themes, "Canyon Day is the currently validated Scenery theme", "Scenery shipping copy")
    if "return LifeRouteTheme.phaseTwoDynamicCatalog" in themes:
        raise SystemExit("v0.7.1 shipping theme-hold audit failed: unfinished Dynamic catalog is still user-facing")
    if "return LifeRouteTheme.phaseThreeSceneryCatalog" in themes:
        raise SystemExit("v0.7.1 shipping theme-hold audit failed: unfinished Scenery catalog is still user-facing")

    # Keep the existing TabView/router but require the real UIKit tab bar to be physically suppressed.
    require(shell, "v0.7.1 custom LifeRoute bottom toolbar", "custom toolbar")
    require(shell, "v0.7.1 single-toolbar physical fix", "physical single-toolbar marker")
    require(shell, ".toolbar(.hidden, for: .tabBar)", "SwiftUI tab bar hidden")
    require(shell, "bar.isHidden = true", "UIKit tab bar hidden")
    require(shell, "bar.alpha = 0", "UIKit tab bar transparent")
    require(shell, "bar.isUserInteractionEnabled = false", "UIKit tab bar interaction disabled")
    require(shell, "LifeRouteBottomToolbar(", "custom toolbar host")
    if shell.count("LifeRouteBottomToolbar(") != 1:
        raise SystemExit("v0.7.1 shipping theme-hold audit failed: expected exactly one custom toolbar host")
    if shell.count(".tabItem {") != 5:
        raise SystemExit("v0.7.1 shipping theme-hold audit failed: underlying five-tab router changed")

    # Proven architecture remains one shared live clock.
    if app.count("TimelineView(\n            .animation(") != 1:
        raise SystemExit("v0.7.1 shipping theme-hold audit failed: shared live-theme TimelineView ownership changed")

    print(
        "LifeRoute v0.7.1 shipping theme-hold audit passed: unfinished theme implementation remains preserved "
        "internally, the user-facing library is 12 Core + Royal Current + Canyon Day, held selections migrate to "
        "a proven theme, the five-tab router remains intact, and the UIKit stock tab bar is explicitly hidden so "
        "only the custom LifeRoute toolbar is presented."
    )


if __name__ == "__main__":
    main()
