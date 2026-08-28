#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute/LifeRouteApp.swift"
PREPARE = ROOT / "scripts/prepare_build.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.0 Theme Phase 2 background-motion audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


app = APP.read_text(encoding="utf-8")
prepare = PREPARE.read_text(encoding="utf-8")

start = app.index("struct LifeRouteDynamicGlassFrame: View {")
end = app.index("struct LifeRouteDynamicGlassEnvironment: View {", start)
dynamic_frame = app[start:end]

require_all(
    dynamic_frame,
    [
        "v0.7.0 Theme Phase 2 full-frame background-motion QA fix",
        "LinearGradient(",
        "AngularGradient(",
        "angle: .degrees(phase * 11.0)",
        ".scaleEffect(1.55)",
        ".blur(radius: 24)",
        "palette.accent.opacity(0.48)",
        "palette.accentSecondary.opacity(0.38)",
        "endRadius: longSide * 0.84",
        "endRadius: longSide * 0.78",
        "LifeRouteLiquidRibbon(",
    ],
    "full-frame live Dynamic renderer",
)
require("palette.backgroundGradient" not in dynamic_frame, "Dynamic frame must not fall back to the static base gradient")

require_all(
    app,
    [
        "static let phaseOneCoreGlassCatalog",
        "static let phaseTwoDynamicCatalog",
        "minimumInterval: 1.0 / 20.0",
        "paused: reduceMotion || !isActive",
        "phase: reduceMotion ? signature.stillPhase : livePhase",
        "if theme.isPhaseOneCoreGlass",
        "else if theme.isPhaseTwoDynamic",
        "Scenery remains the validated legacy renderer until Phase 3.",
    ],
    "protected Phase 2 architecture",
)
require(app.count("minimumInterval: 1.0 / 20.0") == 1, "Dynamic themes must retain one root animation timeline")
require("Timer.publish" not in dynamic_frame, "full-frame motion must not add a Timer publisher")
require("DispatchSourceTimer" not in dynamic_frame, "full-frame motion must not add a dispatch timer")

require_all(
    prepare,
    [
        "python3 scripts/patch_v0_7_0_theme_phase_2_background_motion_fix.py",
        "scripts/patch_v0_7_0_theme_phase_2_background_motion_fix.py",
        "scripts/audit_v0_7_0_theme_phase_2_background_motion_fix.py",
        "python3 scripts/audit_v0_7_0_theme_phase_2_background_motion_fix.py",
    ],
    "canonical preparation wiring",
)

print(
    "LifeRoute v0.7.0 Theme Phase 2 background-motion audit passed: Dynamic themes animate the full-frame color/refraction field rather than a static black base, foreground liquid ribbons remain layered inside that field, one root timeline and Reduce Motion/lifecycle protections remain intact, Core stays static, and Phase 3 Scenery remains excluded."
)
