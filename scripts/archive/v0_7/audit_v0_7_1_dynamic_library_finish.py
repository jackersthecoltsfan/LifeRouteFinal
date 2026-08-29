from pathlib import Path
import re


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.1 Dynamic library audit failed: {message}")


def require_all(text: str, needles: list[str], label: str) -> None:
    missing = [needle for needle in needles if needle not in text]
    require(not missing, f"{label} missing {missing}")


app = Path("LifeRoute/LifeRouteApp.swift").read_text()
themes = Path("LifeRoute/V054ThemeCenterView.swift").read_text()

retained = [
    "royalCurrent",
    "midnightPrism",
    "auroraBloom",
    "solarPulse",
    "emeraldFlow",
    "oceanGlass",
    "obsidianSpectra",
    "plasmaOrchid",
]
retired = ["arcticHalo", "roseEmber", "verdantMist", "titaniumGlow"]

catalog_start = app.index("static let v071RetainedDynamicCatalog")
catalog_end = app.index("var isV071RetainedDynamic", catalog_start)
catalog = app[catalog_start:catalog_end]
require(catalog.count(".") == 8, "retained Dynamic catalog must contain exactly eight identities")
for identifier in retained:
    require(f".{identifier}" in catalog, f"retained catalog missing {identifier}")
for identifier in retired:
    require(f".{identifier}" not in catalog, f"retired Dynamic {identifier} is still user-facing")

require_all(
    app,
    [
        "private struct LifeRouteMidnightPrismFrame: View",
        "private struct LifeRouteAuroraBloomFrame: View",
        "private struct LifeRouteSolarPulseFrame: View",
        "private struct LifeRouteEmeraldFlowFrame: View",
        "private struct LifeRouteOceanGlassFrame: View",
        "private struct LifeRouteObsidianSpectraFrame: View",
        "private struct LifeRoutePlasmaOrchidFrame: View",
        "LifeRoutePrismFacet",
        "LifeRouteAuroraVeil",
        "LifeRouteOceanGlassLens",
        "LifeRoutePlasmaPetal",
    ],
    "distinct retained Dynamic renderer types",
)

dispatch_start = app.index("struct LifeRouteDynamicGlassFrame: View")
dispatch_end = app.index("private var legacyFrame", dispatch_start)
dispatch = app[dispatch_start:dispatch_end]
for identifier in retained:
    require(f"case .{identifier}:" in dispatch, f"production dispatch missing {identifier}")
require(dispatch.count("legacyFrame") == 1, "legacy renderer fallback must remain migration-only")

dynamic_start = app.index("// MARK: - v0.7.1 retained Dynamic production renderers")
dynamic_end = app.index("private var legacyFrame", dynamic_start)
dynamic_region = app[dynamic_start:dynamic_end]
for forbidden in [
    "TimelineView(",
    "Timer.",
    "CADisplayLink",
    "AsyncImage",
    "URLSession",
    "@State",
    "onAppear",
    "Task.sleep",
]:
    require(forbidden not in dynamic_region, f"retained Dynamic renderers must not own {forbidden}")

require_all(
    dynamic_region,
    [
        "ForEach(0..<5",  # faceted Midnight Prism
        "LifeRouteAuroraVeil(phase: phase * 0.72",  # layered Aurora Bloom
        "ForEach(0..<12",  # radial Solar Pulse rays
        "rotationEffect(.degrees(84",  # vertical Emerald Flow
        "LifeRouteOceanGlassLens(phase: phase * 0.84",  # wave-lens Ocean Glass
        "Color(hex: 0x67e8ff)",  # sharp Obsidian Spectra edge light
        "ForEach(0..<7",  # seven-petal Plasma Orchid bloom
    ],
    "theme-specific Dynamic compositions",
)

root_start = app.index("struct LifeRouteLiveThemeEnvironment: View")
root_end = app.index("#if DEBUG", root_start)
root = app[root_start:root_end]
require(root.count("TimelineView(") == 1, "single root live-theme TimelineView changed")
require("minimumInterval: 1.0 / 20.0" in root, "20 fps shared root cadence changed")
require("paused: reduceMotion || !isActive" in root, "lifecycle/Reduce Motion pause contract changed")
require("phase: reduceMotion ? signature.stillPhase : livePhase" in root, "stable Dynamic still phase changed")

signature_start = app.index("fileprivate var dynamicMotionSignature")
signature_end = app.index("// v0.7.1 Royal Current exemplar", signature_start)
signature = app[signature_start:signature_end]
speeds = {}
still_phases = {}
for identifier in retained:
    match = re.search(
        rf"case \.{identifier}: return \.init\(speed: ([0-9.]+), amplitude: [^,]+, ribbonAngle: [^,]+, stillPhase: ([0-9.]+)\)",
        signature,
    )
    require(match is not None, f"motion signature missing {identifier}")
    speeds[identifier] = float(match.group(1))
    still_phases[identifier] = float(match.group(2))
require(min(speeds.values()) >= 0.66, "a retained Dynamic still moves below the perceptual speed floor")
require(len(set(still_phases.values())) == 8, "retained Dynamics must use distinct attractive still phases")

royal_start = app.index("// v0.7.1 Royal Current exemplar")
royal_end = app.index("// MARK: - v0.7.1 retained Dynamic production renderers")
royal = app[royal_start:royal_end]
require_all(
    royal,
    [
        'Image(decorative: "DynamicRoyalCurrent")',
        ".scaleEffect(1.040 + pulse * 0.022)",
        ".offset(x: drift * 9.0, y: -drift * 4.8)",
        "LifeRouteRoyalCurrentBand(",
    ],
    "protected Royal Current reference",
)

require("return LifeRouteTheme.v071RetainedDynamicCatalog" in themes, "Theme Center does not use retained Dynamic catalog")
require("8 distinct full-frame Liquid Glass environments" in themes, "Theme Center Dynamic description is stale")
require("TimelineView(" not in themes, "Theme Center previews must remain deterministic/static")
require("if theme.isV071RetainedDynamic { return theme }" in app, "Build #104 shipping canonicalizer does not preserve retained Dynamic selections")
require("if theme.category == .dynamic { return .royalCurrent }" in app, "retired Dynamic migration fallback changed")

print(
    "LifeRoute v0.7.1 retained Dynamic library audit passed: eight user-facing identities have explicit "
    "production dispatch, seven distinct renderer compositions, perceptible root-driven motion, unique Reduce "
    "Motion still phases, static Theme Center previews, and the Royal Current reference remains intact."
)
