#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

intel = read("LifeRoute/LifeRouteIntelligenceCore.swift")
setup = read("LifeRoute/V054SetupView.swift")
routing = read("LifeRoute/DayRoutePlanningCore.swift")
themes = read("LifeRoute/V054ThemeCenterView.swift")
app = read("LifeRoute/LifeRouteApp.swift")

# Session note output must stay narrative-only and factual.
for token in [
    "Do NOT use Markdown headings",
    "Do NOT output placeholders",
    "Never create a separate data dump",
    "ZERO-DATA RULES",
    "Saved client information is terminology CONTEXT ONLY",
    "Return only a cohesive chronological RBT session-note narrative",
]:
    assert token in intel, f"Missing session-note contract: {token}"

for forbidden in [
    'Text("Session Narrative Note")',
    '[Insert Date]',
    '[Insert Location]',
]:
    assert forbidden not in intel, f"Generic report formatting leaked into generator: {forbidden}"

# RBT profile and navigation selection must remain easy to find in Setup.
for token in [
    'Text("RBT Profile")',
    'Label("Navigation app"',
    'liferoute.rbtProfile.name',
    'liferoute.preferredNavigationApp',
    'Picker("Preferred navigation app"',
]:
    assert token in setup, f"Missing Setup v0.6.1 feature: {token}"

for token in [
    'case appleMaps',
    'case googleMaps',
    'case waze',
    'googleMapsURL',
    'wazeURL',
]:
    assert token in routing, f"Missing preferred navigation routing: {token}"

# Theme Center must keep every visible category at 3+ choices.
expected_groups = {
    "core": [".royal", ".obsidian", ".carbon", ".midnight", ".navyNoir"],
    "scenery": [".forest", ".plum", ".ember"],
    "metallic": [".titanium", ".slate", ".moltenGold", ".phantomSilver"],
    "dynamic": [".solarFlare", ".electricStorm", ".ultraviolet", ".arcticPulse"],
    "fluid": [".ocean", ".aurora", ".sapphireTide"],
}
for category, values in expected_groups.items():
    assert len(values) >= 3
    category_block = f"case .{category}:"
    assert category_block in themes, f"Missing Theme Center group: {category}"
    for value in values:
        assert value in themes, f"Theme {value} missing from visible {category} group"

# Theme propagation must remain rooted above the entire ContentView tree.
for token in [
    'ContentView()',
    '.lifeRouteChrome()',
    '.environmentObject(themeStore)',
    '.environment(\\.lifeRoutePalette, themeStore.palette)',
    '.environment(\\.lifeRouteTheme, themeStore.selectedTheme)',
]:
    assert token in app, f"Global theme propagation contract missing: {token}"

print("LifeRoute v0.6.1 regression audit passed.")
