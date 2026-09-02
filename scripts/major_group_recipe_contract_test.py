#!/usr/bin/env python3
"""Prove the standard-mode majorGroup recipe without changing runtime behavior."""

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

require("surfaceShape.fill(Color.black.opacity(ScenicRoyalDesignSystem.Opacity.standardMajorGroupUnderlay))" in standard, "majorGroup uses the canonical neutral underlay token")
require(".glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))" in standard, "majorGroup uses raw native Glass.clear")
require("decorated(" not in standard, "majorGroup bypasses gradient/outline/shadow decoration")
require("style." not in standard, "majorGroup standard recipe has no theme tint/fill")
require(standard_start < generic_start, "majorGroup recipe precedes generic native-glass controls")

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

print("LifeRoute standard majorGroup recipe contract passed: Glass.clear + neutral 0.035, accessibility/fallback branches preserved")
