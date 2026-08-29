from pathlib import Path


APP = Path("LifeRoute/LifeRouteApp.swift").read_text(encoding="utf-8")
PREPARE = Path("scripts/prepare_build.sh").read_text(encoding="utf-8")
START = APP.find("// v0.8.0 follow-up Scenery ambient motion:")
END = APP.find("private struct LifeRouteBundledSceneryAssetFrame", START)
FOLLOWUP = APP[START:END] if START >= 0 and END > START else ""
ROOT_START = APP.find("struct LifeRouteLiveThemeEnvironment: View")
ROOT_END = APP.find("#if DEBUG", ROOT_START)
ROOT_ENVIRONMENT = APP[ROOT_START:ROOT_END] if ROOT_START >= 0 and ROOT_END > ROOT_START else ""

checks: list[tuple[str, bool]] = []


def check(label: str, condition: bool) -> None:
    checks.append((label, condition))


check("follow-up marker materialized", START >= 0)
check("one deterministic Canvas field", FOLLOWUP.count("Canvas {") == 1)
check("no extra animation clock", "TimelineView" not in FOLLOWUP and "Timer." not in FOLLOWUP)
check("no random particle identity", "random" not in FOLLOWUP.lower() and "UUID" not in FOLLOWUP)
check("bounded rainforest leaves", "case .rainforestLeaves" in FOLLOWUP and "0..<9" in FOLLOWUP)
check("leaf sway uses root phase", "sin(phase * 6.2" in FOLLOWUP and "cos(phase * 4.6" in FOLLOWUP)
check("bounded Arctic snow", "case .arcticSnow" in FOLLOWUP and "0..<18" in FOLLOWUP)
check("snow drift uses root phase", "phase * 2.6" in FOLLOWUP and "phase * 7.0" in FOLLOWUP)
check("particles ignore touch", ".allowsHitTesting(false)" in FOLLOWUP)
check("particles hidden from accessibility", ".accessibilityHidden(true)" in FOLLOWUP)
check("rainforest installs leaf field", "kind: .rainforestLeaves" in APP)
check("Arctic installs snow field", "kind: .arcticSnow" in APP)

check("single persistent root environment remains", APP.count("struct LifeRouteLiveThemeEnvironment: View") == 1)
check("one protected root timeline remains", ROOT_ENVIRONMENT.count("TimelineView(") == 1)
check("20 fps clock remains", "minimumInterval: 1.0 / 20.0" in APP)
check("lifecycle pausing remains", "paused: reduceMotion || !isActive" in APP)
check("Reduce Motion still phase remains", "phase: reduceMotion ? signature.stillPhase : livePhase" in APP)
check("static Theme Center previews remain", "sceneryPreviewPhase" in APP)
check("existing Ocean ambience remains", "phase: phase * 8.4" in APP)
check("existing Desert ambience remains", "case .desert:" in APP)
check("existing Mountains ambience remains", "case .mountains:" in APP)
check("existing Canyon ambience remains", "case .canyon:" in APP)

check("follow-up patch prepared", "patch_v0_8_0_scenery_motion_followup.py" in PREPARE)
check("follow-up audit prepared", "audit_v0_8_0_scenery_motion_followup.py" in PREPARE)

failed = [label for label, condition in checks if not condition]
if failed:
    for label in failed:
        print(f"FAIL: {label}")
    raise SystemExit(f"LifeRoute v0.8.0 Scenery motion follow-up audit failed: {len(failed)} checks")

print(f"LifeRoute v0.8.0 Scenery motion follow-up audit passed: {len(checks)}/{len(checks)} checks")
