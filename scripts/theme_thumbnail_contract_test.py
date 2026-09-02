#!/usr/bin/env python3
"""Verify the Theme Center catalog is backed by committed raster identities."""

from __future__ import annotations

import json
import re
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
THEMES = ROOT / "LifeRoute" / "ScenicRoyalThemeComponents.swift"
ASSETS = ROOT / "LifeRoute" / "Assets.xcassets"
MATERIALS = ROOT / "LifeRoute" / "ScenicRoyalMaterials.swift"
ROLE_CONTRACT = ROOT / "LifeRoute" / "RuntimeFeedbackContracts.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Theme thumbnail contract failed: {message}")


source = THEMES.read_text(encoding="utf-8")
materials = MATERIALS.read_text(encoding="utf-8")
roles = ROLE_CONTRACT.read_text(encoding="utf-8")
mapping = source.split("var thumbnailAssetName: String", 1)[1].split(
    "var sceneryThumbnailAssetName", 1
)[0]
names = re.findall(r'return "(ThemePreview(?:Core|Dynamic)[A-Za-z0-9]+)"', mapping)
require(len(names) == 20, f"expected 20 core/dynamic mappings, found {len(names)}")
require(len(set(names)) == 20, "core/dynamic mappings must have stable unique assets")
scenery_mapping = source.split("var sceneryThumbnailAssetName: String?", 1)[1]
scenery_names = re.findall(
    r'case \.scenery[A-Za-z0-9]+: return "([A-Za-z0-9]+)"', scenery_mapping
)
require(len(scenery_names) == 12, f"expected 12 scenery mappings, found {len(scenery_names)}")
require(len(set(scenery_names)) == 12, "scenery mappings must have stable unique assets")
all_names = names + scenery_names
require(len(all_names) == 32, f"expected 32 production thumbnail identities, found {len(all_names)}")
require(len(set(all_names)) == 32, "production thumbnail assets must not overlap")
require("coreArtwork" not in source and "dynamicArtwork" not in source, "procedural catalog art remains")
require("Image(decorative: theme.thumbnailAssetName)" in source, "catalog is not image-backed")
forbidden_renderers = ["TimelineView", "Canvas(", "LifeRouteDynamicGlassFrame", "LifeRouteSceneryFrame", "LifeRouteLiveThemeEnvironment"]
present_renderers = [token for token in forbidden_renderers if token in source]
require(not present_renderers, f"catalog contains a live renderer path: {present_renderers}")
require("case .majorGroup, .control, .selectedControl, .focalControl: return true" in roles, "major groups do not own native glass")
require("self == .focalControl" in roles, "major groups still draw independent shadows")
require("let base: Glass = role == .majorGroup ? .clear : .regular" in materials, "major groups are not clear glass")
require("surfaceShape.fill(style.readabilityBase.opacity(fallbackUnderlayOpacity))" in materials, "major group legibility underlay is unbounded or missing")

for name in names:
    image_set = ASSETS / f"{name}.imageset"
    contents_path = image_set / "Contents.json"
    require(contents_path.is_file(), f"missing asset catalog entry for {name}")
    contents = json.loads(contents_path.read_text(encoding="utf-8"))
    image = next((item for item in contents["images"] if "filename" in item), None)
    require(image is not None and image.get("scale") == "3x", f"{name} is not a 3x raster")
    raster_path = image_set / image["filename"]
    require(raster_path.is_file(), f"missing raster for {name}")
    with raster_path.open("rb") as raster:
        header = raster.read(24)
    require(header[:8] == b"\x89PNG\r\n\x1a\n", f"{name} is not a PNG raster")
    width, height = struct.unpack(">II", header[16:24])
    require((width, height) == (540, 300), f"{name} has unexpected dimensions {width}x{height}")

for name in scenery_names:
    image_set = ASSETS / f"{name}.imageset"
    contents_path = image_set / "Contents.json"
    require(contents_path.is_file(), f"missing canonical scenery asset catalog entry for {name}")
    contents = json.loads(contents_path.read_text(encoding="utf-8"))
    filenames = [item["filename"] for item in contents["images"] if "filename" in item]
    require(filenames, f"canonical scenery asset {name} has no raster")
    require(all((image_set / filename).is_file() for filename in filenames), f"canonical scenery raster missing for {name}")

print("LifeRoute Theme Center thumbnail contract passed: 32 production identities, including 20 committed fixed-phase Core/Dynamic rasters")
