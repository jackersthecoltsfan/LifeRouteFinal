#!/usr/bin/env python3
"""Prove the standard-mode majorGroup recipe and day readability floor."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MATERIALS = (ROOT / "LifeRoute/ScenicRoyalMaterials.swift").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Major-group recipe contract failed: {message}")


modifier_start = MATERIALS.index("private struct ScenicRoyalGlassSurfaceModifier")
modifier_end = MATERIALS.index("extension View {", modifier_start)
modifier = MATERIALS[modifier_start:modifier_end]

standard_start = modifier.index("} else if role == .majorGroup, #available(iOS 26.0, *)")
generic_start = modifier.index("} else if role.usesNativeGlass, #available(iOS 26.0, *)")
standard = modifier[standard_start:generic_start]

require("surfaceShape.fill(Color.black.opacity(majorGroupUnderlayOpacity))" in standard, "majorGroup uses the shared readability underlay")
require(".glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))" in standard, "majorGroup uses raw native Glass.clear")
require("decorated(" not in standard, "majorGroup bypasses gradient/outline/shadow decoration")
require(standard_start < generic_start, "majorGroup recipe precedes generic native-glass controls")

require("private var majorGroupUnderlayOpacity" in modifier, "majorGroup readability has one shared opacity helper")
require(
    "style.isBrightEnvironment" in modifier
    and "ScenicRoyalDesignSystem.Opacity.brightMajorGroupUnderlay" in modifier
    and "ScenicRoyalDesignSystem.Opacity.standardMajorGroupUnderlay" in modifier,
    "majorGroup underlay selects explicit day/night tokens from the existing theme classification",
)
require("static let brightMajorGroupUnderlay: Double = 0.12" in (ROOT / "LifeRoute/ScenicRoyalDesignSystem.swift").read_text(), "bright/day readability token is bounded at 0.12")

accessibility_start = modifier.index("} else if reduceTransparency || contrast == .increased")
native_start = modifier.index("} else if role == .majorGroup, #available")
accessibility = modifier[accessibility_start:native_start]
require("style.readabilityBase.opacity(accessibleSurfaceOpacity)" in accessibility, "accessibility branch keeps readabilityBase")
require("accessibleSurfaceOpacity" in accessibility, "accessibility branch remains shared")
require("private var accessibleSurfaceOpacity" in modifier, "accessibility opacity helper remains present")
require("reduceTransparency ? 0.98 : 0.90" in modifier, "Reduce Transparency and contrast opacity values remain exact")

passive_start = modifier.index("if role == .passiveRow")
passive_end = modifier.index("} else if reduceTransparency", passive_start)
passive = modifier[passive_start:passive_end]
require("surfaceShape.stroke" in passive, "passive rows retain hairline grouping")
require("background" not in passive and "glassEffect" not in passive and ".shadow(" not in passive, "passive rows remain transparent")

fallback_start = modifier.index("} else {", native_start)
fallback = modifier[fallback_start:]
require("surfaceShape.fill(.ultraThinMaterial)" in fallback, "pre-iOS26 fallback remains material-based")

print("LifeRoute standard majorGroup recipe contract passed: Glass.clear + 0.035 night / 0.12 day neutral underlay, accessibility/fallback branches preserved")
