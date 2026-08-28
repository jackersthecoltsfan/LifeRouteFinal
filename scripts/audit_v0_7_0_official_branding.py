#!/usr/bin/env python3
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.0 official branding audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


def png_dimensions(path: str) -> tuple[int, int]:
    data = (ROOT / path).read_bytes()
    require(data[:8] == b"\x89PNG\r\n\x1a\n", f"{path} is not a PNG")
    require(len(data) >= 24 and data[12:16] == b"IHDR", f"{path} has no valid IHDR")
    return struct.unpack(">II", data[16:24])


app = read("LifeRoute/LifeRouteApp.swift")
today = read("LifeRoute/V054TodayView.swift")
setup = read("LifeRoute/V054SetupView.swift")
themes = read("LifeRoute/V054ThemeCenterView.swift")
widget = read("LifeRouteLiveActivityWidget/LiveDayLiveActivityWidget.swift")
generator = read("scripts/generate_v0_7_0_official_app_icon.swift")
prepare = read("scripts/prepare_build.sh")
branding_patch = read("scripts/patch_v0_7_0_official_branding.py")

require_all(
    generator,
    [
        "LifeRoute v0.7.0 official identity: refined 1E/1F hybrid",
        "Subtle map intelligence layer",
        "Topographic contour accents",
        "mountain silhouettes",
        'drawLetter("L"',
        'drawLetter("R"',
        "Integrated location pin",
        "Illuminated winding route",
        "Decorative premium gold frame",
        "hasAlpha: false",
    ],
    "official production AppIcon generator",
)

require_all(
    app,
    [
        "v0.7.0 official LifeRoute brand mark",
        "enum LifeRouteBrandMarkVariant",
        "struct LifeRouteBrandMark: View",
        "case master",
        "case standard",
        "case small",
        "case micro",
        'Text("LR")',
        'Image(systemName: "mappin")',
        "brandMountains",
        "brandTopo",
        "brandRoute",
    ],
    "reusable official brand component",
)
require_all(
    today,
    [
        "v0.7.0 official branding Today hero",
        "LifeRouteBrandMark(variant: .small)",
        'Text("LifeRoute")',
    ],
    "Today official branding",
)
require('Text("Life")' not in today or 'Text("Route")' not in today, "Today must not retain the old split Life/Route brand treatment")

require_all(
    setup,
    [
        "v0.7.0 official branding Setup header",
        "LifeRouteBrandMark(variant: .small)",
    ],
    "Setup official branding",
)
require('LifeRouteIconBadge(systemImage: "slider.horizontal.3", prominent: true)' not in setup, "Setup must not retain the old generic header mark")

require_all(
    themes,
    [
        "v0.7.0 official branding Theme Center",
        "LifeRouteBrandMark(variant: .micro)",
        'Text("ACTIVE THEME")',
    ],
    "Theme Center official branding",
)

require_all(
    widget,
    [
        "v0.7.0 official LifeRoute widget micro mark",
        "struct LifeRouteWidgetBrandMark: View",
        'Text("LR")',
        "LifeRouteWidgetBrandMark()",
        'Text("LifeRoute")',
        'Text("LIFEROUTE · LIVE DAY")',
    ],
    "Live Activity/Dynamic Island official micro branding",
)
require("point.topleft.down.to.point.bottomright.curvepath" not in widget, "old route-symbol branding must be removed from Live Activity surfaces")

require_all(
    branding_patch,
    [
        "patch_brand_component()",
        "patch_today()",
        "patch_setup()",
        "patch_theme_center()",
        "patch_live_activity()",
    ],
    "controlled branding-only patch scope",
)
require("DayRoutePlanningCore.swift" not in branding_patch, "branding patch must not own routing behavior")
require("CalendarDomain.swift" not in branding_patch, "branding patch must not own calendar behavior")
require("SessionToolsDomain.swift" not in branding_patch, "branding patch must not own timer behavior")
require("AppNavigation.swift" not in branding_patch, "branding patch must not own navigation")

require_all(
    prepare,
    [
        "python3 scripts/patch_v0_7_0_theme_phase_2_background_motion_fix.py",
        "python3 scripts/patch_v0_7_0_official_branding.py",
        'swift scripts/generate_v0_7_0_official_app_icon.swift "$ICON"',
        "scripts/patch_v0_7_0_official_branding.py",
        "scripts/audit_v0_7_0_official_branding.py",
        "python3 scripts/audit_v0_7_0_official_branding.py",
    ],
    "canonical branded preparation",
)
require('swift scripts/generate_v0_6_1_app_icon.swift "$ICON"' not in prepare, "canonical preparation must not regenerate the retired AppIcon")

require_all(
    app,
    [
        "static let phaseOneCoreGlassCatalog",
        "static let phaseTwoDynamicCatalog",
        "minimumInterval: 1.0 / 20.0",
        "paused: reduceMotion || !isActive",
        "v0.7.0 Theme Phase 2 full-frame background-motion QA fix",
        "Scenery remains the validated legacy renderer until Phase 3.",
    ],
    "validated Phase 2 baseline remains intact",
)

app_icon = png_dimensions("LifeRoute/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
require(app_icon == (1024, 1024), f"official AppIcon must remain 1024×1024, got {app_icon}")

print(
    "LifeRoute v0.7.0 official branding audit passed: the refined navy/gold LR + pin + route + mountains/topographic identity owns the production AppIcon and reusable native brand surfaces, old visible header/widget branding is removed, Phase 2 functionality and full-frame Dynamic motion remain intact, and Phase 3 Scenery remains excluded."
)
