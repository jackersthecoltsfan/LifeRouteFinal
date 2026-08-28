#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.0 live-theme surface audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


app = read("LifeRoute/LifeRouteApp.swift")
today = read("LifeRoute/V054TodayView.swift")
prepare = read("scripts/prepare_build.sh")
patch = read("scripts/patch_v0_7_0_live_theme_surface_hero.py")

require_all(
    app,
    [
        "v0.7.0 Theme Phase 2 full-frame background-motion QA fix",
        "v0.7.0 live theme surface visibility repair",
        "struct LifeRouteDynamicGlassFrame: View",
        "struct LifeRouteDynamicGlassEnvironment: View",
        "minimumInterval: 1.0 / 20.0",
        "paused: reduceMotion || !isActive",
        "palette.accent.opacity(0.50)",
        "palette.accent.opacity(0.58)",
        "palette.accentSecondary.opacity(0.50)",
        "palette.accentSecondary.opacity(0.34)",
        "nav.backgroundColor = background.withAlphaComponent(0.54)",
        "tab.backgroundColor = background.withAlphaComponent(0.66)",
        "cell.backgroundColor = panel.withAlphaComponent(0.28)",
        "palette.panelElevated.opacity(0.30)",
        "palette.panel.opacity(0.16)",
    ],
    "live Dynamic surface visibility contract",
)

# Do not solve visibility by multiplying clocks/renderers. The validated Phase 2 architecture remains
# one system-driven root animation timeline, and Reduce Motion/lifecycle pausing remain intact.
dynamic_start = app.index("struct LifeRouteDynamicGlassEnvironment: View {")
dynamic_end = app.index("private struct LifeRouteChromeModifier: ViewModifier {", dynamic_start)
dynamic_environment = app[dynamic_start:dynamic_end]
require(dynamic_environment.count("TimelineView(") == 1, "Dynamic environment must retain exactly one root TimelineView")
require("paused: reduceMotion || !isActive" in dynamic_environment, "Dynamic environment must pause for Reduce Motion or inactive lifecycle")

require_all(
    today,
    [
        "v0.7.0 Today hero preview-parity repair",
        "LifeRouteTodayHeroScene()",
        'Text("Life")',
        'Text("Route")',
        ".foregroundStyle(brandGold)",
        "showingDayPicker = true",
        'Text("Plan your day. Optimize every gap.")',
    ],
    "approved Today hero composition",
)
require("LifeRouteBrandMark(variant: .small)" not in today, "Today hero must not retain the oversized square LR badge from the rejected device composition")
require('Text("LifeRoute")' not in today, "Today hero must use the approved split Life/Route wordmark")

# The official identity remains protected outside the Today wordmark: this repair must not own the
# AppIcon generator, widget, Setup, Theme Center, routing, calendar, timer, persistence, or AppRouter.
require_all(
    app,
    [
        "v0.7.0 official LifeRoute brand mark",
        "struct LifeRouteBrandMark: View",
        "static let phaseOneCoreGlassCatalog",
        "static let phaseTwoDynamicCatalog",
    ],
    "official identity and approved theme catalogs",
)
for forbidden in [
    "DayRoutePlanningCore.swift",
    "CalendarDomain.swift",
    "SessionToolsDomain.swift",
    "PersistenceCore.swift",
    "AppNavigation.swift",
]:
    require(forbidden not in patch, f"presentation repair must not own {forbidden}")

require_all(
    prepare,
    [
        "python3 scripts/audit_v0_7_0_official_branding.py",
        "python3 scripts/patch_v0_7_0_live_theme_surface_hero.py",
        "python3 scripts/audit_v0_7_0_live_theme_surface_hero.py",
        "python3 scripts/audit_v0_7_0_testflight.py",
    ],
    "canonical repair ordering",
)
require(
    prepare.index("python3 scripts/audit_v0_7_0_official_branding.py")
    < prepare.index("python3 scripts/patch_v0_7_0_live_theme_surface_hero.py")
    < prepare.index("python3 scripts/audit_v0_7_0_live_theme_surface_hero.py")
    < prepare.index("python3 scripts/audit_v0_7_0_testflight.py"),
    "historical branding must be audited before Today preview parity supersedes only that surface, then the new repair must be audited before TestFlight contract validation",
)

print(
    "LifeRoute v0.7.0 live-theme surface audit passed: Dynamic themes remain one-clock, Reduce-Motion/lifecycle-aware environments but now expose clearly visible full-frame moving illumination through more translucent app surfaces; Today restores the approved split Life/Route hero composition without changing the official AppIcon/supporting brand identity or protected app behavior."
)
