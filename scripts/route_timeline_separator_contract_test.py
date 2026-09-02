#!/usr/bin/env python3
"""Prove Today route rows use one canonical transparent-row separator."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DESIGN = (ROOT / "LifeRoute/ScenicRoyalDesignSystem.swift").read_text()
COMPONENTS = (ROOT / "LifeRoute/ScenicRoyalComponents.swift").read_text()
TODAY = (ROOT / "LifeRoute/V054TodayView.swift").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Route-timeline separator contract failed: {message}")


require(
    "static let passiveRowSeparator: Double = 0.28" in DESIGN,
    "canonical restrained opacity is exact",
)

start = COMPONENTS.index("struct ScenicRoyalPassiveRowSeparator")
end = COMPONENTS.index("struct ScenicRoyalPrimaryButtonStyle", start)
separator = COMPONENTS[start:end]
require("style.accent.opacity(ScenicRoyalDesignSystem.Opacity.passiveRowSeparator)" in separator, "separator uses the canonical theme-accent token")
require("ScenicRoyalDesignSystem.Stroke.subtle" in separator, "separator remains a subtle hairline")
require("accessibilityHidden(true)" in separator, "decorative separator is hidden from accessibility")
require(not any(term in separator for term in ("glassEffect", "scenicRoyalSurface", ".shadow(", "Material")), "separator adds no glass, material, surface, or shadow")

require(TODAY.count("ScenicRoyalPassiveRowSeparator()") == 2, "generated and preview Today timelines both use the canonical separator")
require("ForEach(timelineItems.dropLast())" in TODAY and "if let finalItem = timelineItems.last" in TODAY, "generated timeline omits a trailing separator with stable row identity")
require("ForEach(waypoints.dropLast())" in TODAY and "if let finalWaypoint = waypoints.last" in TODAY, "preview timeline omits a trailing separator with stable row identity")

print("LifeRoute Today route-timeline separator contract passed: transparent rows, one canonical accent hairline")
