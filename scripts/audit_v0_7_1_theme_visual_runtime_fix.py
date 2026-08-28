#!/usr/bin/env python3
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.1 theme visual runtime audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


app = read("LifeRoute/LifeRouteApp.swift")
today = read("LifeRoute/V054TodayView.swift")
themes = read("LifeRoute/V054ThemeCenterView.swift")
prepare = read("scripts/prepare_build.sh")
patch = read("scripts/patch_v0_7_1_theme_visual_runtime_fix.py")
workflow = read(".github/workflows/ios-ci.yml")
capture = read("scripts/capture_v0_7_1_visual_fixtures.sh")

core_ids = [
    ".royal", ".obsidian", ".midnight", ".titanium", ".coreOcean", ".coreAurora",
    ".coreSolarFlare", ".coreUltraviolet", ".emerald", ".roseQuartz", ".arctic", ".coreEmber",
]
dynamic_ids = [
    ".royalCurrent", ".midnightPrism", ".auroraBloom", ".solarPulse", ".emeraldFlow", ".arcticHalo",
    ".oceanGlass", ".roseEmber", ".obsidianSpectra", ".plasmaOrchid", ".verdantMist", ".titaniumGlow",
]
scenery_ids = [
    ".sceneryMountainsDay", ".sceneryMountainsNight", ".sceneryOceanDay", ".sceneryOceanNight",
    ".sceneryDesertDay", ".sceneryDesertNight", ".sceneryAlpineDay", ".sceneryAlpineNight",
    ".sceneryRainforestDay", ".sceneryRainforestNight", ".sceneryGrasslandDay", ".sceneryGrasslandNight",
    ".sceneryVolcanicDay", ".sceneryVolcanicNight", ".sceneryCanyonDay", ".sceneryCanyonNight",
    ".sceneryArcticDay", ".sceneryArcticNight", ".sceneryCoastalCliffsDay", ".sceneryCoastalCliffsNight",
]

for catalog_name, expected in [
    ("phaseOneCoreGlassCatalog", core_ids),
    ("phaseTwoDynamicCatalog", dynamic_ids),
    ("phaseThreeSceneryCatalog", scenery_ids),
]:
    start = app.index(f"static let {catalog_name}")
    end = app.index("\n    ]", start)
    catalog = app[start:end]
    require(len(expected) == len(set(expected)), f"{catalog_name} expected IDs must be unique")
    require_all(catalog, expected, catalog_name)

require(app.count("final class LifeRouteThemeStore: ObservableObject") == 1, "one LifeRouteThemeStore owner must remain")
require(app.count('private static let storageKey = "liferoute.selectedTheme"') == 1, "one selected-theme persistence key must remain")

live_start = app.index("struct LifeRouteLiveThemeEnvironment: View")
live_end = app.index("private struct LifeRouteChromeModifier: ViewModifier", live_start)
live_region = app[live_start:live_end]
require(live_region.count("TimelineView(") == 1, "selected live environment must retain exactly one root TimelineView")
require_all(
    live_region,
    ["minimumInterval: 1.0 / 20.0", "paused: reduceMotion || !isActive", "theme.isPhaseTwoDynamic", "theme.isPhaseThreeScenery"],
    "shared live clock contract",
)

core_start = app.index("struct LifeRouteCoreGlassEnvironment: View")
core_end = app.index("struct LifeRouteLiquidRibbon: Shape", core_start)
require("TimelineView(" not in app[core_start:core_end], "Core Glass must remain still")
require("TimelineView(" not in themes, "Theme Center previews must remain deterministic and static")
require("LifeRouteLiveThemeEnvironment(" not in themes, "Theme Center must not mount the root live environment")

asset = ROOT / "LifeRoute/Assets.xcassets/SceneryCanyonDay.imageset/SceneryCanyonDay.png"
contents = read("LifeRoute/Assets.xcassets/SceneryCanyonDay.imageset/Contents.json")
require(asset.is_file(), "bundled Canyon Day scene asset is missing")
require(asset.stat().st_size >= 1_000_000, "Canyon Day scene asset is unexpectedly small")
header = asset.read_bytes()[:26]
require(header[:8] == b"\x89PNG\r\n\x1a\n", "Canyon Day asset must be PNG")
width, height = struct.unpack(">II", header[16:24])
require(width >= 800 and height >= 1600 and height > width, "Canyon Day asset must be a high-detail portrait image")
require_all(contents, ['"filename" : "SceneryCanyonDay.png"', '"idiom" : "universal"'], "Canyon asset catalog")

canyon_start = app.index("// v0.7.1 Canyon Day exemplar")
canyon_end = app.index("struct LifeRouteSceneryFrame: View", canyon_start)
canyon = app[canyon_start:canyon_end]
require_all(
    canyon,
    [
        'Image(decorative: "SceneryCanyonDay")', ".resizable()", ".scaledToFill()",
        "v0.7.1 Canyon Day exemplar", "sin(phase * 6.4)", ".accessibilityHidden(true)",
    ],
    "asset-backed Canyon Day renderer",
)
for forbidden in ["AsyncImage", "URLSession", "Timer.", "TimelineView(", "LifeRouteSceneryRidge", "LifeRouteSceneryDune"]:
    require(forbidden not in canyon, f"Canyon Day renderer must not depend on {forbidden}")

scenery_start = app.index("struct LifeRouteSceneryFrame: View")
scenery_end = app.index("struct LifeRouteDynamicGlassEnvironment: View", scenery_start)
scenery = app[scenery_start:scenery_end]
require_all(
    scenery,
    ["if theme == .sceneryCanyonDay", "LifeRouteCanyonDayAssetFrame(palette: palette, phase: phase)", "legacyFrame"],
    "Canyon exemplar dispatch",
)

royal_start = app.index("// v0.7.1 Royal Current exemplar")
royal_end = app.index("struct LifeRouteDynamicGlassFrame: View", royal_start)
royal = app[royal_start:royal_end]
require_all(
    royal,
    [
        "v0.7.1 Royal Current exemplar", "private struct LifeRouteRoyalCurrentBand: Shape",
        "let samples = 36", "stride(from: samples, through: 0, by: -1)",
        "thickness: max(142, size.height * 0.22)", "thickness: max(126, size.height * 0.19)",
        ".blendMode(.screen)", "AngularGradient(", ".compositingGroup()",
    ],
    "broad layered Royal Current renderer",
)
require(royal.count("LifeRouteRoyalCurrentBand(") >= 4, "Royal Current must layer broad bodies and luminous edges")
for forbidden in ["LifeRouteLiquidRibbon", "TimelineView(", "Timer.", "CADisplayLink", "[CGPoint]", "reserveCapacity"]:
    require(forbidden not in royal, f"Royal Current exemplar must not depend on {forbidden}")

dynamic_start = app.index("struct LifeRouteDynamicGlassFrame: View")
dynamic_end = app.index("private enum LifeRouteSceneryFamily", dynamic_start)
dynamic = app[dynamic_start:dynamic_end]
require_all(
    dynamic,
    ["if theme == .royalCurrent", "LifeRouteRoyalCurrentFrame(palette: palette, phase: phase)", "legacyFrame"],
    "Royal Current exemplar dispatch",
)

require("LifeRouteCinematicBackdrop" not in today, "Today must not mount a competing cinematic backdrop")
require("LifeRouteTodayHeroScene" not in today, "Today must not retain a competing local hero scene")
require_all(
    today,
    [
        "v0.7.1 Today uses the persistent root environment as its only hero artwork",
        'Text("Life")', 'Text("Route")', ".foregroundStyle(brandGold)",
        "ForEach(selectedDayEvents)", "LifeRouteTodayGlassCardModifier",
        "if #available(iOS 26.0, *)", "GlassEffectContainer(spacing: 8)",
        ".regular.tint(accent.opacity(0.12)).interactive()", ".background(.ultraThinMaterial",
    ],
    "environment-transparent Today exemplar",
)
require("LifeRouteBrandMark(variant: .small)" not in today, "square LR mark must remain absent from Today")

require_all(
    app,
    [
        "case canyonDay = \"canyon-day\"", "case royalCurrent = \"royal-current\"",
        "-LifeRouteVisualFixture", "-LifeRouteThemeOverride", "LifeRouteVisualFixture.themeOverride?.rawValue",
        "LifeRouteVisualFixtureView", "#if DEBUG",
    ],
    "debug-only visual fixtures",
)
require_all(
    capture,
    [
        "xcrun simctl bootstatus", "xcrun simctl install", "xcrun simctl launch",
        "xcrun simctl io", "canyon-day.png", "royal-current.png",
        "today-canyon-day.png", "today-royal-current.png",
        "--terminate-running-process", "kill -0", "wc -c", "-LifeRouteThemeOverride",
    ],
    "Simulator screenshot capture",
)
require_all(
    workflow,
    [
        "Capture v0.7.1 visual fixtures", "Upload v0.7.1 visual fixtures",
        "scripts/capture_v0_7_1_visual_fixtures.sh", "actions/upload-artifact@v6",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG",
    ],
    "iOS validation workflow visual gate",
)

for forbidden_path in [
    "CalendarDomain.swift", "RoutingLocationDomain.swift", "PersistenceCore.swift", "SessionToolsDomain.swift",
    "AppNavigation.swift", "LifeRouteLiveActivity", "AppIcon.appiconset",
]:
    require(forbidden_path not in patch, f"v0.7.1 patch must not own protected path {forbidden_path}")

require_all(
    prepare,
    [
        "python3 scripts/audit_v0_7_0_testflight.py",
        "python3 scripts/patch_v0_7_1_theme_visual_runtime_fix.py",
        "python3 scripts/audit_v0_7_1_theme_visual_runtime_fix.py",
        "python3 scripts/audit_v0_7_1_protected_regressions.py",
    ],
    "canonical v0.7.1 patch/audit chain",
)
require(
    prepare.index("python3 scripts/audit_v0_7_0_testflight.py")
    < prepare.index("python3 scripts/patch_v0_7_1_theme_visual_runtime_fix.py")
    < prepare.index("python3 scripts/audit_v0_7_1_theme_visual_runtime_fix.py"),
    "v0.7.1 must materialize only after the complete historical v0.7.0 audit chain",
)
require(
    prepare.index("python3 scripts/audit_v0_7_1_theme_visual_runtime_fix.py")
    < prepare.index("python3 scripts/audit_v0_7_1_protected_regressions.py"),
    "protected-regression audit must run after focused exemplar validation",
)

print(
    f"LifeRoute v0.7.1 exemplar audit passed: Canyon Day is a {width}x{height} bundled cinematic asset; "
    "Royal Current uses broad layered glass bodies from the one root phase; Today exposes the selected root environment "
    "with iOS 26 Liquid Glass and fallback materials; all 12 Core, 12 Dynamic, and 20 Scenery identities remain protected."
)
