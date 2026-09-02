#!/usr/bin/env python3
"""Static contract checks for the DEBUG-only physical Glass Lab."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MATERIALS = (ROOT / "LifeRoute/ScenicRoyalMaterials.swift").read_text()
APP = (ROOT / "LifeRoute/LifeRouteApp.swift").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Glass Lab contract failed: {message}")


marker = "/// A deliberately isolated, non-persistent legibility comparison surface."
require(marker in MATERIALS, "isolated lab marker is present")
lab_start = MATERIALS.rfind("#if DEBUG", 0, MATERIALS.index(marker))
require(lab_start >= 0, "lab has a DEBUG guard")
lab = MATERIALS[lab_start:]

require(lab.count("#if DEBUG") == 1 and lab.rstrip().endswith("#endif"), "lab is DEBUG-only")
require("-LifeRouteGlassLab" in lab, "launch argument is explicit")
require("-LifeRouteGlassLabScene" in lab, "scene launch override is explicit")
require("-LifeRouteGlassLabCandidate" not in lab, "V1 one-at-a-time candidate override is removed")

for candidate in ("case .l0", "case .l1", "case .l2"):
    require(candidate in lab, f"candidate {candidate} exists")
for asset in ("SceneryCanyonDay", "SceneryCanyonNight"):
    require(asset in lab, f"real scenery asset {asset} is used")

require("ForEach(LifeRouteGlassLabCandidate.allCases)" in lab, "all three legibility candidates render together")
require("candidatePicker" not in lab, "candidate memory-switching picker is absent")
require("A — Glass.clear" in lab, "bright-scene material winner is explicit")
require("0 — No material" in lab, "dark-scene material winner is explicit")
require("scene == .bright" in lab, "selected material policy is scene-dependent")
require(".glassEffect(.clear, in: .rect(cornerRadius: 22))" in lab, "bright comparison keeps native Glass.clear fixed")
require(".regular" not in lab and ".ultraThinMaterial" not in lab, "unselected raw materials are absent")
require(".scenicRoyalSurface" not in lab, "production surface modifier is absent")
require("case .l0: return 0" in lab, "L0 has no neutral dimming")
require("case .l1: return 0.035" in lab, "L1 has extremely light neutral dimming")
require("case .l2: return 0.07" in lab, "L2 has slightly stronger neutral dimming")
require("accessibilityStatus" in lab, "system adaptation flags are visible")
require("Reduce Transparency:" in lab and "Increase Contrast:" in lab, "both accessibility flags are named")
require("reduceTransparency ||" not in lab, "raw candidates do not collapse into a custom accessibility fallback")

surface_start = lab.index("private func candidateSurface")
surface = lab[surface_start:]
require("Color.black.opacity(candidate.dimmingOpacity)" in surface, "one neutral underlay variable drives L1/L2")
require(".tint" not in surface and ".shadow" not in surface, "legibility samples add no tint or shadow")

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

print("LifeRoute DEBUG Glass Lab V2 legibility contract passed: A-bright/0-dark with L0/L1/L2 neutral dimming")
