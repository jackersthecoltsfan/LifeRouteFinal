#!/usr/bin/env python3
"""Static contract checks for the DEBUG-only physical Glass Lab."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MATERIALS = (ROOT / "LifeRoute/ScenicRoyalMaterials.swift").read_text()
APP = (ROOT / "LifeRoute/LifeRouteApp.swift").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Glass Lab contract failed: {message}")


marker = "/// A deliberately isolated, non-persistent Liquid Glass comparison surface."
require(marker in MATERIALS, "isolated lab marker is present")
lab_start = MATERIALS.rfind("#if DEBUG", 0, MATERIALS.index(marker))
require(lab_start >= 0, "lab has a DEBUG guard")
lab = MATERIALS[lab_start:]

require(lab.count("#if DEBUG") == 1 and lab.rstrip().endswith("#endif"), "lab is DEBUG-only")
require("-LifeRouteGlassLab" in lab, "launch argument is explicit")
require("-LifeRouteGlassLabCandidate" in lab, "candidate launch override is explicit")
require("-LifeRouteGlassLabScene" in lab, "scene launch override is explicit")

for candidate in ("case .clear", "case .regular", "case .material"):
    require(candidate in lab, f"candidate {candidate} exists")
for asset in ("SceneryCanyonDay", "SceneryCanyonNight"):
    require(asset in lab, f"real scenery asset {asset} is used")

require(".glassEffect(.clear, in: .rect(cornerRadius: 26))" in lab, "A uses native Glass.clear")
require(".glassEffect(.regular.tint(labAccent.opacity(0.16)), in: .rect(cornerRadius: 26))" in lab, "B uses restrained Glass.regular tint")
require(".background(.ultraThinMaterial, in: shape)" in lab, "C uses the material fallback")
require("shape.fill(Color.black.opacity(0.10))" in lab, "A has only one bounded legibility underlay")
require(".interactive()" in lab, "interactive treatment is present for controls")
require(".accessibilityAddTraits(.isSelected)" in lab, "selected-control semantics are present")
require("reduceTransparency || increasedContrast" in lab, "accessibility fallback disables transparent controls")
require(".shadow(" not in lab, "lab introduces no independent shadows")

passive_start = lab.index("private func passiveRow")
passive_end = lab.index("private var focalButton")
passive = lab[passive_start:passive_end]
require("glassEffect" not in passive, "passive rows do not own glass")
require("Material" not in passive and "material" not in passive, "passive rows do not own material")
require("shadow" not in passive, "passive rows do not own shadows")

debug_hook_start = APP.rindex("#if DEBUG")
release_hook_start = APP.index("#else\n            appContent", debug_hook_start)
hook = APP[debug_hook_start:release_hook_start]
require("LifeRouteGlassLabLaunch.current" in hook, "release-guarded app hook exists")
require("LifeRouteGlassLabView" in hook, "lab route renders the comparison view")
require("LifeRouteGlassLabLaunch.current" not in APP[release_hook_start:], "release branch does not reference lab")

print("LifeRoute DEBUG Glass Lab contract passed: 3 candidates, 2 real scenery states")
