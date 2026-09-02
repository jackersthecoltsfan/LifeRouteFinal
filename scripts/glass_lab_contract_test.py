#!/usr/bin/env python3
"""Static contract checks for the DEBUG-only physical Glass Lab."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MATERIALS = (ROOT / "LifeRoute/ScenicRoyalMaterials.swift").read_text()
APP = (ROOT / "LifeRoute/LifeRouteApp.swift").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Glass Lab contract failed: {message}")


marker = "/// A deliberately isolated, non-persistent raw-material comparison surface."
require(marker in MATERIALS, "isolated lab marker is present")
lab_start = MATERIALS.rfind("#if DEBUG", 0, MATERIALS.index(marker))
require(lab_start >= 0, "lab has a DEBUG guard")
lab = MATERIALS[lab_start:]

require(lab.count("#if DEBUG") == 1 and lab.rstrip().endswith("#endif"), "lab is DEBUG-only")
require("-LifeRouteGlassLab" in lab, "launch argument is explicit")
require("-LifeRouteGlassLabScene" in lab, "scene launch override is explicit")
require("-LifeRouteGlassLabCandidate" not in lab, "V1 one-at-a-time candidate override is removed")

for candidate in ("case .baseline", "case .clear", "case .regular", "case .material", "case .production"):
    require(candidate in lab, f"candidate {candidate} exists")
for asset in ("SceneryCanyonDay", "SceneryCanyonNight"):
    require(asset in lab, f"real scenery asset {asset} is used")

require("ForEach(LifeRouteGlassLabCandidate.allCases)" in lab, "all five candidates render together")
require("candidatePicker" not in lab, "candidate memory-switching picker is absent")
require(".glassEffect(.clear, in: .rect(cornerRadius: 22))" in lab, "A uses raw native Glass.clear")
require(".glassEffect(.regular, in: .rect(cornerRadius: 22))" in lab, "B uses raw native Glass.regular")
require(".background(.ultraThinMaterial, in: shape)" in lab, "C uses the material fallback")
require(".scenicRoyalSurface(role: .majorGroup, cornerRadius: 22)" in lab, "D uses exact production major-group surface")
require("accessibilityStatus" in lab, "system adaptation flags are visible")
require("Reduce Transparency:" in lab and "Increase Contrast:" in lab, "both accessibility flags are named")
require("reduceTransparency ||" not in lab, "raw candidates do not collapse into a custom accessibility fallback")

surface_start = lab.index("private func candidateSurface")
surface = lab[surface_start:]
clear = surface[surface.index("case .clear:"):surface.index("case .regular:")]
regular = surface[surface.index("case .regular:"):surface.index("case .material:")]
material = surface[surface.index("case .material:"):surface.index("case .production:")]
require(".background" not in clear and ".tint" not in clear and ".shadow" not in clear, "A has no custom underlay, tint, or shadow")
require(".background" not in regular and ".tint" not in regular and ".shadow" not in regular, "B has no custom underlay, tint, or shadow")
require(".tint" not in material and ".shadow" not in material, "C has no custom tint or shadow")

content_start = lab.index("private var identicalContent")
content_end = lab.index("private func candidateSurface")
identical_content = lab[content_start:content_end]
require("Passive row · identical content" in identical_content, "identical passive rows are present")
require("Button {}" in identical_content, "identical focal control is present")
require("glassEffect" not in identical_content and "ultraThinMaterial" not in identical_content, "content has no nested material")

debug_hook_start = APP.rindex("#if DEBUG")
release_hook_start = APP.index("#else\n            appContent", debug_hook_start)
hook = APP[debug_hook_start:release_hook_start]
require("LifeRouteGlassLabLaunch.current" in hook, "release-guarded app hook exists")
require("LifeRouteGlassLabView" in hook, "lab route renders the comparison view")
require("LifeRouteGlassLabLaunch.current" not in APP[release_hook_start:], "release branch does not reference lab")

print("LifeRoute DEBUG Glass Lab V2 contract passed: 5 simultaneous raw/production candidates, 2 real scenery states")
