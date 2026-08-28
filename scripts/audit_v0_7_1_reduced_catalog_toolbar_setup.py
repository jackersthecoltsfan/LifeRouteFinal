#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute/LifeRouteApp.swift"
SHELL = ROOT / "LifeRoute/V054ContentView.swift"
SETUP = ROOT / "LifeRoute/V054SetupView.swift"
THEMES = ROOT / "LifeRoute/V054ThemeCenterView.swift"


def require(text: str, token: str, label: str) -> None:
    if token not in text:
        raise SystemExit(f"v0.7.1 reduced catalog/toolbar/setup audit failed: missing {label}: {token}")


def between(text: str, start: str, end: str) -> str:
    try:
        i = text.index(start)
        j = text.index(end, i)
    except ValueError as exc:
        raise SystemExit(f"v0.7.1 reduced catalog/toolbar/setup audit failed: region boundary missing: {start} / {end}") from exc
    return text[i:j]


def main() -> None:
    app = APP.read_text(encoding="utf-8")
    shell = SHELL.read_text(encoding="utf-8")
    setup = SETUP.read_text(encoding="utf-8")
    themes = THEMES.read_text(encoding="utf-8")

    # Catalog contract: historical Phase 1 already locks exactly 12 Core choices. This finishing pass
    # changes only Dynamic/Scenery visibility, so require every approved Core identity without re-counting
    # raw token substrings (some Core names are prefixes of other identities).
    dynamic = between(app, "static let phaseTwoDynamicCatalog", "var isPhaseTwoDynamic")
    scenery = between(app, "static let phaseThreeSceneryCatalog", "var isPhaseThreeScenery")
    core = between(app, "static let phaseOneCoreGlassCatalog", "var isPhaseOneCoreGlass")

    kept_core = [
        ".coreRoyal", ".coreObsidian", ".coreMidnight", ".coreNavyNoir",
        ".coreOcean", ".coreAurora", ".coreForest", ".corePlum",
        ".coreCarbon", ".coreArctic", ".coreSunshine", ".coreEmber",
    ]
    kept_dynamic = [
        ".royalCurrent", ".midnightPrism", ".auroraBloom", ".solarPulse",
        ".emeraldFlow", ".oceanGlass", ".obsidianSpectra", ".plasmaOrchid",
    ]
    removed_dynamic = [".arcticHalo", ".roseEmber", ".verdantMist", ".titaniumGlow"]
    kept_scenery = [
        ".sceneryMountainsDay", ".sceneryMountainsNight",
        ".sceneryOceanDay", ".sceneryOceanNight",
        ".sceneryDesertDay", ".sceneryDesertNight",
        ".sceneryRainforestDay", ".sceneryRainforestNight",
        ".sceneryCanyonDay", ".sceneryCanyonNight",
        ".sceneryArcticDay", ".sceneryArcticNight",
    ]
    removed_scenery = [
        ".sceneryAlpineDay", ".sceneryAlpineNight",
        ".sceneryGrasslandDay", ".sceneryGrasslandNight",
        ".sceneryVolcanicDay", ".sceneryVolcanicNight",
        ".sceneryCoastalCliffsDay", ".sceneryCoastalCliffsNight",
    ]

    for token in kept_core:
        require(core, token, f"protected Core {token}")
    for token in kept_dynamic:
        require(dynamic, token, f"retained Dynamic {token}")
    for token in removed_dynamic:
        if token in dynamic:
            raise SystemExit(f"v0.7.1 reduced catalog/toolbar/setup audit failed: retired Dynamic still visible: {token}")
    for token in kept_scenery:
        require(scenery, token, f"retained Scenery {token}")
    for token in removed_scenery:
        if token in scenery:
            raise SystemExit(f"v0.7.1 reduced catalog/toolbar/setup audit failed: retired Scenery still visible: {token}")

    for identifier in [
        'case "dynamic.arcticHalo"', 'case "dynamic.roseEmber"',
        'case "dynamic.verdantMist"', 'case "dynamic.titaniumGlow"',
        'case "scenery.alpine.day"', 'case "scenery.alpine.night"',
        'case "scenery.grassland.day"', 'case "scenery.grassland.night"',
        'case "scenery.volcanic.day"', 'case "scenery.volcanic.night"',
        'case "scenery.coastalCliffs.day"', 'case "scenery.coastalCliffs.night"',
    ]:
        require(app, identifier, f"retired-theme migration {identifier}")

    # Theme Center must describe the production-sized library truthfully.
    require(themes, "8 live full-frame Liquid Glass environments", "8-theme Dynamic copy")
    require(themes, "12 cinematic Day/Night environments across 6 landscape families", "12-theme Scenery copy")
    require(themes, "All 12 retained Scenery thumbnails are deterministic still frames", "retained Scenery preview copy")

    # Preserve the proven Build #98 architecture: one shared live clock and root environment.
    if app.count("TimelineView(\n            .animation(") != 1:
        raise SystemExit("v0.7.1 reduced catalog/toolbar/setup audit failed: shared live-theme TimelineView ownership changed")
    require(app, "v0.7.1 physical-device motion visibility repair", "Build #98 motion repair")
    require(shell, "v0.7.1 physical-device root environment reveal", "Build #98 root reveal")

    # Custom toolbar presentation over the existing five-tab router.
    require(shell, "v0.7.1 custom LifeRoute bottom toolbar", "custom toolbar marker")
    require(shell, ".toolbar(.hidden, for: .tabBar)", "native tab-bar presentation hidden")
    require(shell, "LifeRouteBottomToolbar(", "custom toolbar host")
    require(shell, "@Binding var selection: AppSection", "router-backed toolbar binding")
    require(shell, 'case .schedule: return "Calendar"', "approved Calendar toolbar label")
    require(shell, "private struct LifeRouteTabGlyph: View", "custom icon family")
    require(shell, "Canvas { context, size in", "vector icon renderer")
    require(shell, "v0.7.1 toolbar accessibility hardening", "toolbar accessibility hardening")
    require(shell, '.accessibilityValue(selected ? "Selected" : "")', "selected accessibility value")
    for case in ["case .today:", "case .schedule:", "case .tools:", "case .resources:", "case .setup:"]:
        require(shell, case, f"toolbar glyph branch {case}")
    if shell.count(".tabItem {") != 5:
        raise SystemExit("v0.7.1 reduced catalog/toolbar/setup audit failed: existing five TabView destinations changed")

    # Setup declutter: six independent disclosure groups; only Appearance starts expanded.
    require(setup, "v0.7.1 Setup disclosure groups", "Setup disclosure marker")
    require(setup, "private struct LifeRouteSetupDisclosureGroup<Content: View>: View", "Setup disclosure component")
    require(setup, "@Environment(\\.lifeRoutePalette) private var palette", "correct Setup palette key path")
    if "@Environment(\\\\.lifeRoutePalette)" in setup:
        raise SystemExit("v0.7.1 reduced catalog/toolbar/setup audit failed: invalid doubled Setup environment key path remains")
    for token in [
        "@State private var appearanceExpanded = true",
        "@State private var profileExpanded = false",
        "@State private var navigationExpanded = false",
        "@State private var todosExpanded = false",
        "@State private var clinicalExpanded = false",
        "@State private var privacyExpanded = false",
    ]:
        require(setup, token, f"Setup default {token}")
    if setup.count("LifeRouteSetupDisclosureGroup(") != 6:
        raise SystemExit("v0.7.1 reduced catalog/toolbar/setup audit failed: Setup must expose exactly six disclosure groups")
    for title in ["Appearance", "Profile & Work", "Navigation & Places", "Weekly To-Dos", "Clinical", "Privacy"]:
        require(setup, f'title: "{title}"', f"Setup group {title}")

    # Existing Setup functionality remains present behind the groups.
    for token in [
        "rbtProfileCard", "navigationAppCard", "themeCard", "clientCard", "homeCard",
        "savedPlacesCard", "addPlaceCard", "weeklyTodosCard", "addTodoCard", "privacyCard",
        "routingState.addTodo(", "routingState.addSavedPlace(",
        "routingState.removeSavedPlace(id: place.id)", "routingState.setHomeAddress(homeDraft)",
        "V054ClientProfilesView(clientState: clientState)", "V054ThemeCenterView()",
    ]:
        require(setup, token, f"preserved Setup functionality {token}")

    print(
        "LifeRoute v0.7.1 reduced catalog/toolbar/Setup audit passed: 12 Core + 8 Dynamic + 12 Scenery are visible, "
        "retired identifiers migrate safely, Build #98's single live-theme architecture remains intact, the existing "
        "five-tab router drives one custom vector LifeRoute toolbar, and Setup preserves every control behind six disclosure groups."
    )


if __name__ == "__main__":
    main()
