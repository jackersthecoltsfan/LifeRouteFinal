#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
APP = (ROOT / "LifeRoute/LifeRouteApp.swift").read_text(encoding="utf-8")
THEMES = (ROOT / "LifeRoute/V054ThemeCenterView.swift").read_text(encoding="utf-8")
SHELL = (ROOT / "LifeRoute/V054ContentView.swift").read_text(encoding="utf-8")
PREPARE = (ROOT / "scripts/prepare_build.sh").read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.0 Theme Phase 2 audit failed: {message}")


def require_token(text: str, token: str, label: str) -> None:
    require(token in text, f"missing {label}: {token}")


def forbid(text: str, token: str, label: str) -> None:
    require(token not in text, f"forbidden {label}: {token}")


# Phase 1 remains the exact 12-theme still Core catalog.
core_names = [
    "Royal", "Obsidian", "Midnight", "Titanium", "Ocean", "Aurora",
    "Solar Flare", "Ultraviolet", "Emerald", "Rose Quartz", "Arctic", "Ember",
]
require_token(APP, "static let phaseOneCoreGlassCatalog: [LifeRouteTheme]", "Phase 1 Core catalog")
for name in core_names:
    require(name in APP, f"Core theme {name} remains available")
core_region = APP.split("struct LifeRouteCoreGlassEnvironment: View", 1)[1].split("struct LifeRouteLiquidRibbon: Shape", 1)[0]
forbid(core_region, "TimelineView(", "continuous animation inside Core Glass")
forbid(core_region, "Timer.", "timer inside Core Glass")

# Phase 2 owns exactly the 12 approved Dynamic identities and stable IDs.
dynamic_pairs = [
    ("royalCurrent", "dynamic.royalCurrent", "Royal Current"),
    ("midnightPrism", "dynamic.midnightPrism", "Midnight Prism"),
    ("auroraBloom", "dynamic.auroraBloom", "Aurora Bloom"),
    ("solarPulse", "dynamic.solarPulse", "Solar Pulse"),
    ("emeraldFlow", "dynamic.emeraldFlow", "Emerald Flow"),
    ("arcticHalo", "dynamic.arcticHalo", "Arctic Halo"),
    ("oceanGlass", "dynamic.oceanGlass", "Ocean Glass"),
    ("roseEmber", "dynamic.roseEmber", "Rose Ember"),
    ("obsidianSpectra", "dynamic.obsidianSpectra", "Obsidian Spectra"),
    ("plasmaOrchid", "dynamic.plasmaOrchid", "Plasma Orchid"),
    ("verdantMist", "dynamic.verdantMist", "Verdant Mist"),
    ("titaniumGlow", "dynamic.titaniumGlow", "Titanium Glow"),
]
for case_name, stable_id, display_name in dynamic_pairs:
    require_token(APP, f'case {case_name} = "{stable_id}"', f"stable ID for {display_name}")
    require_token(APP, f'return "{display_name}"', f"display name for {display_name}")

catalog_match = re.search(
    r"static let phaseTwoDynamicCatalog: \[LifeRouteTheme\] = \[(.*?)\n    \]",
    APP,
    flags=re.S,
)
require(catalog_match is not None, "Phase 2 Dynamic catalog declaration missing")
catalog = catalog_match.group(1)
for case_name, _, _ in dynamic_pairs:
    require(f".{case_name}" in catalog, f"Dynamic catalog missing {case_name}")
require(catalog.count(".") == 12, "Dynamic catalog must contain exactly 12 entries")
require_token(APP, "var isPhaseTwoDynamic: Bool", "Dynamic membership helper")

# Old Dynamic selections migrate intentionally instead of silently resetting users to Royal.
legacy_migrations = {
    'case "solarFlare":': ".solarPulse",
    'case "electricStorm":': ".midnightPrism",
    'case "ultraviolet":': ".plasmaOrchid",
    'case "arcticPulse":': ".arcticHalo",
    'case "aurora":': ".auroraBloom",
    'case "sapphireTide":': ".oceanGlass",
}
for legacy, replacement in legacy_migrations.items():
    require_token(APP, legacy, f"legacy migration {legacy}")
    require_token(APP, f"return {replacement}", f"legacy migration target {replacement}")
require_token(APP, 'private static let storageKey = "liferoute.selectedTheme"', "single persisted theme owner")
require(APP.count("final class LifeRouteThemeStore: ObservableObject") == 1, "LifeRouteThemeStore must remain the single selection owner")

# One lightweight, system-driven root timeline powers all live Dynamic themes.
require_token(APP, "struct LifeRouteLiquidRibbon: Shape", "liquid deformation shape")
require_token(APP, "struct LifeRouteDynamicGlassFrame: View", "shared dynamic frame")
require_token(APP, "struct LifeRouteDynamicGlassEnvironment: View", "root dynamic environment")
require(APP.count("TimelineView(") == 1, "exactly one TimelineView may exist in the app-level theme runtime")
require_token(APP, ".animation(\n                minimumInterval: 1.0 / 20.0,\n                paused: reduceMotion || !isActive", "20 fps paused system schedule")
require_token(APP, "@Environment(\\.scenePhase) private var scenePhase", "scene lifecycle observation")
require_token(APP, "isActive: scenePhase == .active", "active-scene animation gate")
require_token(APP, "phase: reduceMotion ? signature.stillPhase : livePhase", "Reduce Motion still equivalent")
require_token(APP, "else if theme.isPhaseTwoDynamic", "root Dynamic renderer selection")
require_token(APP, "LifeRouteDynamicGlassEnvironment(", "root Dynamic renderer")

for forbidden in ["Timer.scheduledTimer", "DispatchSourceTimer", "CADisplayLink", ".glassEffect(", "MeshGradient("]:
    forbid(APP, forbidden, f"unsupported/heavy Dynamic runtime primitive {forbidden}")

# Theme Center can advertise motion without spawning twelve timelines in its lazy grid.
require_token(THEMES, "v0.7.0 Theme Phase 2 Theme Center", "Phase 2 Theme Center")
require_token(THEMES, "return LifeRouteTheme.phaseTwoDynamicCatalog", "exact Dynamic catalog source")
require_token(THEMES, 'Text(dynamicGlass ? "LIVE" : "STILL")', "motion badge")
require_token(THEMES, "LifeRouteDynamicGlassFrame(", "static Dynamic preview frame")
require_token(THEMES, "phase: theme.dynamicPreviewPhase", "deterministic preview phase")
forbid(THEMES, "TimelineView(", "animated grid preview")
forbid(THEMES, "LifeRouteDynamicGlassEnvironment(", "root animation engine inside Theme Center")

# Phase 3 remains isolated: the validated scenery catalog is unchanged here.
require_token(THEMES, "private let sceneryThemes: [LifeRouteTheme] = [.mountain, .ocean, .space, .desert, .forest, .sunshine]", "pre-Phase-3 scenery catalog")
require_token(APP, "// Scenery remains the validated legacy renderer until Phase 3.", "Phase 3 isolation marker")

# The environment remains mounted exactly once above the native five-tab shell.
require_token(SHELL, "v0.7.0 Theme Phase 1 single environment shell", "single environment shell")
require(SHELL.count("LifeRouteCinematicBackdrop(") == 0, "tab shell must not mount a second cinematic environment")
for tab in [".today", ".schedule", ".tools", ".resources", ".setup"]:
    require_token(SHELL, f".tag(AppSection{tab})", f"protected tab {tab}")
forbid(SHELL, ".routes", "sixth Routes tab")

# Canonical preparation must materialize and audit Phase 2 after the repaired Phase 1 checkpoint.
require_token(PREPARE, "python3 scripts/patch_v0_7_0_theme_phase_2.py", "Phase 2 materialization")
require_token(PREPARE, "python3 scripts/patch_v0_7_0_theme_phase_2_compile_hotfix.py", "Phase 2 compile compatibility")
require_token(PREPARE, "python3 scripts/audit_v0_7_0_theme_phase_2.py", "Phase 2 audit")

print("LifeRoute v0.7.0 Theme Phase 2 audit passed: the 12 approved Dynamic Liquid Glass identities use stable persisted IDs, one paused system-driven root timeline, low-layer liquid deformation, Reduce Motion still equivalents, lifecycle pausing, static grid previews, protected 12-theme Core Glass, isolated pre-Phase-3 Scenery, and the unchanged five-tab native shell.")
