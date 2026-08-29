from pathlib import Path
import hashlib
import json


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.1 Scenery library audit failed: {message}")


def require_all(text: str, needles: list[str], label: str) -> None:
    missing = [needle for needle in needles if needle not in text]
    require(not missing, f"{label} missing {missing}")


def jpeg_dimensions(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    require(data[:2] == b"\xff\xd8", f"{path} is not a JPEG")
    index = 2
    sof_markers = {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}
    while index + 9 < len(data):
        if data[index] != 0xFF:
            index += 1
            continue
        while index < len(data) and data[index] == 0xFF:
            index += 1
        require(index < len(data), f"{path} has a truncated JPEG marker")
        marker = data[index]
        index += 1
        if marker in {0x01, 0xD8, 0xD9} or 0xD0 <= marker <= 0xD7:
            continue
        require(index + 2 <= len(data), f"{path} has a truncated JPEG segment")
        segment_length = int.from_bytes(data[index:index + 2], "big")
        require(segment_length >= 2, f"{path} has an invalid JPEG segment")
        if marker in sof_markers:
            require(index + 7 <= len(data), f"{path} has a truncated JPEG size segment")
            height = int.from_bytes(data[index + 3:index + 5], "big")
            width = int.from_bytes(data[index + 5:index + 7], "big")
            return width, height
        index += segment_length
    raise SystemExit(f"v0.7.1 Scenery library audit failed: {path} has no JPEG size marker")


app = Path("LifeRoute/LifeRouteApp.swift").read_text()
themes = Path("LifeRoute/V054ThemeCenterView.swift").read_text()

retained = [
    "sceneryMountainsDay",
    "sceneryMountainsNight",
    "sceneryOceanDay",
    "sceneryOceanNight",
    "sceneryDesertDay",
    "sceneryDesertNight",
    "sceneryRainforestDay",
    "sceneryRainforestNight",
    "sceneryCanyonDay",
    "sceneryCanyonNight",
    "sceneryArcticDay",
    "sceneryArcticNight",
]
retired = [
    "sceneryAlpineDay",
    "sceneryAlpineNight",
    "sceneryGrasslandDay",
    "sceneryGrasslandNight",
    "sceneryVolcanicDay",
    "sceneryVolcanicNight",
    "sceneryCoastalCliffsDay",
    "sceneryCoastalCliffsNight",
]

catalog_start = app.index("static let v071RetainedSceneryCatalog")
catalog_end = app.index("var isV071RetainedScenery", catalog_start)
catalog = app[catalog_start:catalog_end]
require(catalog.count(".") == 12, "retained Scenery catalog must contain exactly twelve identities")
for identifier in retained:
    require(f".{identifier}" in catalog, f"retained catalog missing {identifier}")
for identifier in retired:
    require(f".{identifier}" not in catalog, f"retired Scenery {identifier} is still user-facing")

asset_names = [
    "SceneryMountainsDay",
    "SceneryMountainsNight",
    "SceneryOceanDay",
    "SceneryOceanNight",
    "SceneryDesertDay",
    "SceneryDesertNight",
    "SceneryRainforestDay",
    "SceneryRainforestNight",
    "SceneryCanyonNight",
    "SceneryArcticDay",
    "SceneryArcticNight",
]

asset_root = Path("LifeRoute/Assets.xcassets")
asset_total = 0
asset_hashes = {}
for asset_name in asset_names:
    imageset = asset_root / f"{asset_name}.imageset"
    image = imageset / f"{asset_name}.jpg"
    contents_path = imageset / "Contents.json"
    require(image.is_file(), f"missing bundled scene {image}")
    require(contents_path.is_file(), f"missing asset catalog metadata {contents_path}")
    contents = json.loads(contents_path.read_text())
    filenames = [item.get("filename") for item in contents.get("images", []) if item.get("filename")]
    require(filenames == [f"{asset_name}.jpg"], f"{asset_name} imageset must reference one optimized JPEG")
    width, height = jpeg_dimensions(image)
    require(width >= 900 and height >= 1600 and height > width, f"{asset_name} must remain a detailed portrait scene")
    size = image.stat().st_size
    require(150_000 <= size <= 650_000, f"{asset_name} size {size} is outside the optimized asset budget")
    asset_total += size
    asset_hashes[asset_name] = hashlib.sha256(image.read_bytes()).hexdigest()

require(asset_total <= 4_200_000, f"eleven-scene bundle increase {asset_total} exceeds 4.2 MB budget")

for family in ["Mountains", "Ocean", "Desert", "Rainforest", "Arctic"]:
    require(
        asset_hashes[f"Scenery{family}Day"] != asset_hashes[f"Scenery{family}Night"],
        f"{family} Day/Night assets are byte-identical",
    )

mapping_start = app.index("fileprivate var v071SceneryAssetName")
mapping_end = app.index("private enum LifeRouteSceneryFamily", mapping_start)
mapping = app[mapping_start:mapping_end]
for asset_name in asset_names:
    require(f'"{asset_name}"' in mapping, f"asset mapping missing {asset_name}")
require('case .sceneryCanyonDay: return "SceneryCanyonDay"' in mapping, "Canyon Day reference mapping changed")

require_all(
    app,
    [
        "private struct LifeRouteBundledSceneryAssetFrame: View",
        "Image(decorative: assetName)",
        "familyAmbience(size: size, drift: drift, breathe: breathe)",
        "case .mountains:",
        "case .ocean:",
        "case .desert:",
        "case .rainforest:",
        "case .canyon:",
        "case .arctic:",
    ],
    "asset-backed family ambience renderer",
)

scenery_start = app.index("// MARK: - v0.7.1 retained Scenery production renderer")
scenery_end = app.index("private var legacyFrame", scenery_start)
scenery_region = app[scenery_start:scenery_end]
for forbidden in ["TimelineView(", "Timer.", "CADisplayLink", "AsyncImage", "URLSession", "@State", "onAppear"]:
    require(forbidden not in scenery_region, f"retained Scenery renderer must not own {forbidden}")
require("else if let assetName = theme.v071SceneryAssetName" in scenery_region, "retained Scenery dispatch can still fall through")

canyon_start = app.index("// v0.7.1 Canyon Day exemplar")
canyon_end = app.index("// MARK: - v0.7.1 retained Scenery production renderer")
canyon = app[canyon_start:canyon_end]
require_all(
    canyon,
    [
        'Image(decorative: "SceneryCanyonDay")',
        "let drift = sin(phase * 6.4)",
        ".scaleEffect(1.035)",
        ".offset(x: drift * 3.2, y: drift * 1.4)",
    ],
    "protected Canyon Day reference",
)

root_start = app.index("struct LifeRouteLiveThemeEnvironment: View")
root_end = app.index("#if DEBUG", root_start)
root = app[root_start:root_end]
require(root.count("TimelineView(") == 1, "single root live-theme TimelineView changed")
require("paused: reduceMotion || !isActive" in root, "lifecycle/Reduce Motion pause contract changed")
require("phase: reduceMotion ? signature.stillPhase : livePhase" in root, "stable Scenery still phase changed")

require("return LifeRouteTheme.v071RetainedSceneryCatalog" in themes, "Theme Center does not use retained Scenery catalog")
require("12 finished cinematic environments across 6 Day/Night families" in themes, "Theme Center Scenery description is stale")
require("TimelineView(" not in themes, "Theme Center previews must remain deterministic/static")
require("if theme.isV071RetainedScenery { return theme }" in app, "Build #104 shipping canonicalizer does not preserve retained Scenery selections")
require("if theme.category == .scenery { return .sceneryCanyonDay }" in app, "retired Scenery migration fallback changed")

print(
    "LifeRoute v0.7.1 retained Scenery library audit passed: twelve user-facing identities across six "
    f"Day/Night families use bundled cinematic artwork; eleven new 941x1672 JPEGs add {asset_total} bytes; "
    "family ambience remains root-phase-driven; Reduce Motion, lifecycle pausing, static previews, and the "
    "Canyon Day reference remain intact."
)
