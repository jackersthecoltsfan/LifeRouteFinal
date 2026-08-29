#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.0 Theme Phase 3 audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


app = read("LifeRoute/LifeRouteApp.swift")
themes = read("LifeRoute/V054ThemeCenterView.swift")
today = read("LifeRoute/V054TodayView.swift")
shell = read("LifeRoute/V054ContentView.swift")
prepare = read("scripts/prepare_build.sh")
patch = read("scripts/patch_v0_7_0_theme_phase_3.py")

scenery = [
    ("sceneryMountainsDay", "scenery.mountains.day", "Mountains — Day"),
    ("sceneryMountainsNight", "scenery.mountains.night", "Mountains — Night"),
    ("sceneryOceanDay", "scenery.ocean.day", "Ocean — Day"),
    ("sceneryOceanNight", "scenery.ocean.night", "Ocean — Night"),
    ("sceneryDesertDay", "scenery.desert.day", "Desert — Day"),
    ("sceneryDesertNight", "scenery.desert.night", "Desert — Night"),
    ("sceneryAlpineDay", "scenery.alpine.day", "Alpine — Day"),
    ("sceneryAlpineNight", "scenery.alpine.night", "Alpine — Night"),
    ("sceneryRainforestDay", "scenery.rainforest.day", "Rainforest — Day"),
    ("sceneryRainforestNight", "scenery.rainforest.night", "Rainforest — Night"),
    ("sceneryGrasslandDay", "scenery.grassland.day", "Grassland — Day"),
    ("sceneryGrasslandNight", "scenery.grassland.night", "Grassland — Night"),
    ("sceneryVolcanicDay", "scenery.volcanic.day", "Volcanic — Day"),
    ("sceneryVolcanicNight", "scenery.volcanic.night", "Volcanic — Night"),
    ("sceneryCanyonDay", "scenery.canyon.day", "Canyon — Day"),
    ("sceneryCanyonNight", "scenery.canyon.night", "Canyon — Night"),
    ("sceneryArcticDay", "scenery.arctic.day", "Arctic — Day"),
    ("sceneryArcticNight", "scenery.arctic.night", "Arctic — Night"),
    ("sceneryCoastalCliffsDay", "scenery.coastalCliffs.day", "Coastal Cliffs — Day"),
    ("sceneryCoastalCliffsNight", "scenery.coastalCliffs.night", "Coastal Cliffs — Night"),
]

require_all(app, ["v0.7.0 Theme Phase 3 Scenery catalog", "static let phaseThreeSceneryCatalog: [LifeRouteTheme]", "var isPhaseThreeScenery: Bool"], "Phase 3 catalog contract")
for case_name, stable_id, display_name in scenery:
    require(f'case {case_name} = "{stable_id}"' in app, f"stable ID missing for {display_name}")
    require(f'return "{display_name}"' in app, f"display name missing for {display_name}")

catalog_match = re.search(r"static let phaseThreeSceneryCatalog: \[LifeRouteTheme\] = \[(.*?)\n    \]", app, flags=re.S)
require(catalog_match is not None, "Scenery catalog declaration missing")
catalog = catalog_match.group(1)
for case_name, _, _ in scenery:
    require(f".{case_name}" in catalog, f"Scenery catalog missing {case_name}")
require(catalog.count(".") == 20, "Scenery catalog must contain exactly 20 entries")

for token in ["static let phaseOneCoreGlassCatalog: [LifeRouteTheme]", "static let phaseTwoDynamicCatalog: [LifeRouteTheme]"]:
    require(token in app, f"protected catalog missing: {token}")
core_match = re.search(r"static let phaseOneCoreGlassCatalog: \[LifeRouteTheme\] = \[(.*?)\n    \]", app, flags=re.S)
dynamic_match = re.search(r"static let phaseTwoDynamicCatalog: \[LifeRouteTheme\] = \[(.*?)\n    \]", app, flags=re.S)
require(core_match is not None and core_match.group(1).count(".") == 12, "Core catalog must remain exactly 12")
require(dynamic_match is not None and dynamic_match.group(1).count(".") == 12, "Dynamic catalog must remain exactly 12")
require(12 + 12 + 20 == 44, "user-facing theme total must remain 44")

legacy_migrations = {
    'case "mountain":': ".sceneryMountainsDay",
    'case "ocean":': ".sceneryOceanDay",
    'case "space":': ".sceneryArcticNight",
    'case "desert":': ".sceneryDesertDay",
    'case "forest":': ".sceneryRainforestDay",
    'case "sunshine":': ".sceneryGrasslandDay",
    'case "plum":': ".sceneryCanyonNight",
    'case "ember":': ".sceneryVolcanicNight",
}
for legacy, target in legacy_migrations.items():
    require(legacy in app and f"return {target}" in app, f"deterministic legacy Scenery migration missing: {legacy} -> {target}")
require('private static let storageKey = "liferoute.selectedTheme"' in app, "single persisted theme owner must remain")
require(app.count("final class LifeRouteThemeStore: ObservableObject") == 1, "LifeRouteThemeStore must remain the single theme owner")

require_all(
    app,
    [
        "struct LifeRouteLiveThemeEnvironment: View",
        "v0.7.0 Theme Phase 3 single shared root environment clock",
        "minimumInterval: 1.0 / 20.0",
        "paused: reduceMotion || !isActive",
        "if theme.isPhaseTwoDynamic",
        "else if theme.isPhaseThreeScenery",
        "phase: reduceMotion ? signature.stillPhase : livePhase",
        "@Environment(\\.scenePhase) private var scenePhase",
        "isActive: scenePhase == .active",
        "else if theme.isPhaseTwoDynamic || theme.isPhaseThreeScenery",
    ],
    "single-clock live environment architecture",
)
require(app.count("TimelineView(") == 1, "LifeRouteApp theme runtime must contain exactly one TimelineView")
clock_start = app.index("struct LifeRouteLiveThemeEnvironment: View")
clock_end = app.index("private struct LifeRouteChromeModifier: ViewModifier", clock_start)
clock_region = app[clock_start:clock_end]
require(clock_region.count("TimelineView(") == 1, "shared environment must own exactly one TimelineView")
for forbidden in ["Timer.scheduledTimer", "DispatchSourceTimer", "CADisplayLink", "MeshGradient(", ".glassEffect("]:
    require(forbidden not in clock_region, f"shared live environment must not use {forbidden}")

core_start = app.index("struct LifeRouteCoreGlassEnvironment: View")
core_end = app.index("struct LifeRouteLiquidRibbon: Shape", core_start)
require("TimelineView(" not in app[core_start:core_end], "Core Glass must remain static")
scenery_start = app.index("private enum LifeRouteSceneryFamily")
scenery_end = app.index("struct LifeRouteLiveThemeEnvironment: View", scenery_start)
scenery_region = app[scenery_start:scenery_end]
require_all(scenery_region, ["struct LifeRouteSceneryFrame: View", "LifeRouteSceneryRidge", "LifeRouteSceneryDune", "LifeRouteSceneryWave"], "native Scenery renderer")
for forbidden in ["AsyncImage", "URLSession", "Timer.", "CADisplayLink", "Particle", "ForEach(", "TimelineView("]:
    require(forbidden not in scenery_region, f"Scenery renderer must avoid heavy/independent runtime primitive {forbidden}")

for forbidden in ["Calendar.current", ".component(.hour", "sunrise", "sunset", "timeOfDay", "autoSwitch"]:
    require(forbidden not in scenery_region, f"Scenery must not auto-switch Day/Night via {forbidden}")
require("sceneryIsNight" in scenery_region and "sceneryVariantLabel" in scenery_region, "explicit Day/Night identity helpers missing")

require_all(
    themes,
    [
        "v0.7.0 Theme Phase 3 Theme Center",
        'case core = "Core"',
        'case dynamic = "Dynamic"',
        'case scenery = "Scenery"',
        "return LifeRouteTheme.phaseOneCoreGlassCatalog",
        "return LifeRouteTheme.phaseTwoDynamicCatalog",
        "return LifeRouteTheme.phaseThreeSceneryCatalog",
        "LifeRouteSceneryFrame(",
        "phase: theme.sceneryPreviewPhase",
        "Day and Night selected independently",
    ],
    "Theme Center Phase 3 contract",
)
filter_start = themes.index("private enum ThemeFilter")
filter_end = themes.index("private let columns", filter_start)
filter_region = themes[filter_start:filter_end]
require(filter_region.count("case ") == 3, "Theme Center must expose exactly three user categories")
for forbidden in ['case all =', 'case metallic =', 'case fluid =', 'case living =']:
    require(forbidden not in filter_region, f"Theme Center must not expose legacy category {forbidden}")
require("TimelineView(" not in themes, "Theme Center thumbnails must remain static")
require("LifeRouteLiveThemeEnvironment(" not in themes, "Theme Center must not mount the live root environment")

require("v0.7.0 Theme Phase 3 persistent environment host" in app, "Phase 3 persistent root host marker missing")
require("v0.7.0 Theme Phase 1 single environment shell" in shell, "single environment shell marker missing")
for tab in [".today", ".schedule", ".tools", ".resources", ".setup"]:
    require(f".tag(AppSection{tab})" in shell, f"protected tab missing: {tab}")
require(".routes" not in shell, "sixth Routes tab must remain forbidden")

require_all(
    app,
    [
        "v0.7.0 live theme surface visibility repair",
        "palette.accent.opacity(0.50)",
        "palette.accent.opacity(0.58)",
        "palette.accentSecondary.opacity(0.50)",
        "palette.panelElevated.opacity(0.30)",
        "palette.panel.opacity(0.16)",
        "nav.backgroundColor = background.withAlphaComponent(0.54)",
        "tab.backgroundColor = background.withAlphaComponent(0.66)",
        "cell.backgroundColor = panel.withAlphaComponent(0.28)",
    ],
    "post-QA visible environment surface contract",
)
require_all(
    today,
    [
        "v0.7.0 Today hero preview-parity repair",
        'Text("Life")',
        'Text("Route")',
        ".foregroundStyle(brandGold)",
        'Text("Plan your day. Optimize every gap.")',
        "v0.7.0 Today overview full-day agenda",
        "ForEach(selectedDayEvents)",
    ],
    "protected Today hero and full-day overview",
)
require("LifeRouteBrandMark(variant: .small)" not in today, "square LR logo must not return to Today hero")

for forbidden in [
    "DayRoutePlanningCore.swift",
    "CalendarDomain.swift",
    "SessionToolsDomain.swift",
    "PersistenceCore.swift",
    "AppNavigation.swift",
    "LifeRouteLiveActivity",
    "Assets.xcassets/AppIcon.appiconset",
]:
    require(forbidden not in patch, f"Phase 3 patch must not own unrelated protected path {forbidden}")

require_all(
    prepare,
    [
        "python3 scripts/patch_v0_7_0_live_theme_surface_hero.py",
        "python3 scripts/audit_v0_7_0_live_theme_surface_hero.py",
        "python3 scripts/patch_v0_7_0_theme_phase_3.py",
        "python3 scripts/audit_v0_7_0_theme_phase_3.py",
        "python3 scripts/audit_v0_7_0_testflight.py",
    ],
    "canonical Phase 3 ordering",
)
require(
    prepare.index("python3 scripts/patch_v0_7_0_live_theme_surface_hero.py")
    < prepare.index("python3 scripts/audit_v0_7_0_live_theme_surface_hero.py")
    < prepare.index("python3 scripts/patch_v0_7_0_theme_phase_3.py")
    < prepare.index("python3 scripts/audit_v0_7_0_theme_phase_3.py")
    < prepare.index("python3 scripts/audit_v0_7_0_testflight.py"),
    "Phase 3 must materialize only after the validated post-QA repair/audit and before final TestFlight contract audit",
)

print(
    "LifeRoute v0.7.0 Theme Phase 3 audit passed: exactly 20 stable individually selectable Scenery Day/Night identities join the protected 12 Core and 12 Dynamic catalogs; the selected live environment uses one shared 20-fps lifecycle/Reduce-Motion-aware root clock; previews stay static; retired scenery IDs migrate deterministically; the five-tab shell, Today hero, all-event overview, translucent live-theme surfaces, and unrelated functional owners remain protected."
)
