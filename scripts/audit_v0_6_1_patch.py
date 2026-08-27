#!/usr/bin/env python3
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.6.1 audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


def png_dimensions(path: str) -> tuple[int, int]:
    data = (ROOT / path).read_bytes()
    require(data[:8] == b"\x89PNG\r\n\x1a\n", f"{path} is not a PNG")
    require(len(data) >= 24 and data[12:16] == b"IHDR", f"{path} has no valid IHDR")
    return struct.unpack(">II", data[16:24])


intelligence = read("LifeRoute/LifeRouteIntelligenceCore.swift")
setup = read("LifeRoute/V054SetupView.swift")
routing = read("LifeRoute/DayRoutePlanningCore.swift")
themes = read("LifeRoute/V054ThemeCenterView.swift")
app = read("LifeRoute/LifeRouteApp.swift")

require_all(
    intelligence,
    [
        "PROHIBITED OUTPUT SHAPES AND CONTENT:",
        "Use \"the client\" rather than treating the ABA-style client code as the client's name",
        "A behavior-reduction metric of 0.00% is never evidence that treatment failed",
        "sessionNoteNeedsNarrativeRepair",
        "FORMAT CORRECTION — the prior generation shape was rejected",
        "LifeRoute could not produce a clean narrative-only ABA note",
    ],
    "strict ABA narrative-note contract",
)
require_all(
    intelligence,
    [
        "static func generateSessionPlan(",
        'instructions: "You are LifeRoute\'s session-planning assistant for an RBT. Organize only supervisor-approved information and never invent treatment procedures."',
        'End with one short "Flex:" line',
    ],
    "unchanged Session Plan contract",
)

require_all(
    setup,
    [
        'Text("RBT Profile")',
        'liferoute.rbtProfile.name',
        'liferoute.rbtProfile.organization',
        'liferoute.rbtProfile.credential',
        'Label("Navigation app"',
        'liferoute.preferredNavigationApp',
        'Picker("Preferred navigation app"',
    ],
    "RBT profile and navigation Setup controls",
)

require_all(
    routing,
    [
        "enum LifeRouteNavigationApp",
        "case appleMaps",
        "case googleMaps",
        "case waze",
        "googleMapsURL",
        "wazeURL",
        "LifeRouteNavigationApp.preferred",
    ],
    "preferred navigation routing",
)

visible_theme_groups = {
    "core": [".royal", ".obsidian", ".carbon", ".midnight", ".navyNoir"],
    "scenery": [".forest", ".plum", ".ember"],
    "metallic": [".titanium", ".slate", ".moltenGold", ".phantomSilver"],
    "dynamic": [".solarFlare", ".electricStorm", ".ultraviolet", ".arcticPulse"],
    "fluid": [".ocean", ".aurora", ".sapphireTide"],
}
for category, values in visible_theme_groups.items():
    require(len(values) >= 3, f"{category} theme category has fewer than three choices")
    require(f"case .{category}:" in themes, f"Theme Center missing {category} group")
    for value in values:
        require(value in themes, f"Theme {value} missing from visible {category} group")

require_all(
    app,
    [
        "ContentView()",
        ".lifeRouteChrome()",
        ".environmentObject(themeStore)",
        ".environment(\\.lifeRoutePalette, themeStore.palette)",
        ".environment(\\.lifeRouteTheme, themeStore.selectedTheme)",
    ],
    "app-wide theme propagation",
)

icon_generator = read("scripts/generate_v0_6_1_app_icon.swift")
require_all(
    icon_generator,
    [
        '"LR" as NSString',
        "Subtle premium map/street texture",
        "Cool-blue route layer",
        "Gold inner rim",
        "Gold route ribbon",
        "navigation pin",
        "hasAlpha: false",
    ],
    "premium LR icon generator",
)

prepare = read("scripts/prepare_build.sh")
require_all(
    prepare,
    [
        "swift scripts/generate_v0_6_1_app_icon.swift",
        "scripts/audit_v0_6_1_patch.py",
        "LifeRoute v0.6.1 preparation passed",
    ],
    "v0.6.1 deterministic preparation",
)

workflow = read(".github/workflows/testflight.yml")
require_all(
    workflow,
    [
        "RELEASE_MARKETING_VERSION: 0.6.1",
        "Verify v0.6.1 app and Live Activity release contract",
        "Archive LifeRoute v0.6.1",
        "Verify archived v0.6.1 identity",
        "LifeRoute v0.6.1 sent to TestFlight",
    ],
    "v0.6.1 TestFlight release guard",
)

app_icon = png_dimensions("LifeRoute/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
require(app_icon == (1024, 1024), f"generated AppIcon must be 1024×1024, got {app_icon}")

print("LifeRoute v0.6.1 regression audit passed: master-style ABA notes, RBT profile, navigation selection, balanced themes with app-wide propagation, premium LR icon generation, and release guards.")
