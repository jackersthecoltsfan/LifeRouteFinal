#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.6.2 audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


intelligence = read("LifeRoute/LifeRouteIntelligenceCore.swift")
timer = read("LifeRoute/SessionToolsDomain.swift")
timer_view = read("LifeRoute/SessionToolsViews.swift")
theme_model = read("LifeRoute/LifeRouteApp.swift")
theme_center = read("LifeRoute/V054ThemeCenterView.swift")
cinematic = read("LifeRoute/CinematicThemeViews.swift")
shell = read("LifeRoute/V054ContentView.swift")
icon_generator = read("scripts/generate_v0_6_1_app_icon.swift")
workflow = read(".github/workflows/testflight.yml")
project = read("LifeRoute.xcodeproj/project.pbxproj")

# Preserve the shipped v0.6.1 note-quality contract while preventing client-profile context overflow.
require_all(
    intelligence,
    [
        "PROHIBITED OUTPUT SHAPES AND CONTENT:",
        'Use "the client" rather than treating the ABA-style client code as the client\'s name',
        "A behavior-reduction metric of 0.00% is never evidence that treatment failed",
        "sessionNoteNeedsNarrativeRepair",
        "FORMAT CORRECTION — the prior generation shape was rejected",
        "Saved client information is terminology/context only and never proves an event occurred",
        "compactSessionNoteClientContext",
        "summary.prefix(720)",
        "SAVED CLIENT CONTEXT — terminology only, compacted to protect the on-device model context window",
    ],
    "ABA note contract and bounded selected-client context",
)
require("client?.currentTargets.joined(separator:" not in intelligence, "session note must not inject every saved target verbatim")
require("client?.behaviorsOfConcern.joined(separator:" not in intelligence.split("static func generateVisualScheduleDraft", 1)[0], "session note must not inject every saved behavior verbatim")

# Visual timer: requested pitch, tempo acceleration, volume control, and 5 dB digital crescendo.
require_all(
    timer,
    [
        "private static let startFrequency = 432.0",
        "private static let endFrequency = 1_728.0",
        "startGainForFiveDecibelCrescendo",
        "@Published private(set) var volume: Double = 0.86",
        "func setVolume(_ value: Double)",
        "func pulsesPerSecond(forRemaining remaining: TimeInterval) -> Double",
        "if remaining <= 5 { return 5 }",
        "if remaining <= 10 { return 4 }",
        "if remaining <= 30 { return 3 }",
        "return 2",
        "setCategory(.playback",
        "bellSecond",
        "bellThird",
        "signalGain(forRemaining:",
    ],
    "visual timer audio behavior",
)
require_all(
    timer_view,
    [
        "TimelineView(.periodic(from: .now, by: 0.10))",
        "Timer sound",
        "Slider(",
        "timer.setVolume",
        "5 dB digital crescendo",
        "2 ticks/sec normally",
        "432 Hz to 1728 Hz",
    ],
    "visual timer UI",
)

# User-facing theme catalog is now exactly Core, Dynamic, Scenery.
require_all(
    theme_center,
    [
        'case core = "Core"',
        'case dynamic = "Dynamic"',
        'case scenery = "Scenery"',
        "[.royal, .obsidian, .carbon, .midnight, .navyNoir, .titanium, .slate, .moltenGold, .phantomSilver]",
        "[.solarFlare, .electricStorm, .ultraviolet, .arcticPulse, .aurora, .sapphireTide]",
        "[.mountain, .ocean, .space, .desert, .forest, .sunshine]",
    ],
    "three-category Theme Center",
)
require('case all = "All"' not in theme_center, "Theme Center must not expose the old All category")
require('case metallic = "Metallic"' not in theme_center, "Theme Center must not expose Metallic as a separate category")
require('case fluid = "Fluid"' not in theme_center, "Theme Center must not expose Fluid as a separate category")
require_all(
    theme_model,
    [
        "case mountain, space, desert, sunshine",
        'case .mountain: return "Mountain"',
        'case .space: return "Space"',
        'case .desert: return "Desert"',
        'case .sunshine: return "Sunshine"',
    ],
    "six-scenery theme model",
)
require_all(
    cinematic,
    [
        "case .mountain:",
        "case .ocean:",
        "case .space:",
        "case .desert:",
        "case .forest:",
        "case .sunshine:",
        "struct LifeRouteDynamicWaveBackdrop",
        "TimelineView(.periodic(from: .now",
        "case .dynamic, .fluid:",
        ".saturation(1.12)",
        ".contrast(1.18)",
    ],
    "persistent cinematic scenery and animated dynamic waves",
)
require_all(
    shell,
    [
        "LifeRouteCinematicBackdrop(",
        "theme: themeStore.selectedTheme",
        "TabView(selection: $router.selectedSection)",
    ],
    "app-wide theme backdrop",
)

# Icon remains deterministic, opaque, and now has a safer centered inset inside iOS masking.
require_all(
    icon_generator,
    [
        "v0.6.2 safe-area refinement",
        "full.insetBy(dx: 58, dy: 58)",
        "full.insetBy(dx: 72, dy: 72)",
        'drawLetter("L", rect: NSRect(x: 130',
        'drawLetter("R", rect: NSRect(x: 512',
        "samplesPerPixel: 3",
        "hasAlpha: false",
    ],
    "refined opaque LR icon generator",
)

# Release identity and v0.6.1 native isolation protections remain intact.
require_all(
    workflow,
    [
        "RELEASE_MARKETING_VERSION: 0.6.2",
        "Prepare validated v0.6.2 release",
        "Verify v0.6.2 app and Live Activity release contract",
        "Archive LifeRoute v0.6.2",
        "Verify archived v0.6.2 identity",
        "LifeRoute v0.6.2 sent to TestFlight",
    ],
    "v0.6.2 TestFlight release guard",
)
require("LifeRouteWebView.swift in Sources" not in project, "legacy WebView source must stay quarantined")
require("Web in Resources" not in project, "legacy Web runtime must stay out of native resources")
require("LifeRouteLiveActivityWidget.appex in Embed App Extensions" in project, "Live Activity extension embedding must remain intact")

print("LifeRoute v0.6.2 native audit passed: bounded client note context, accelerating 432–1728 Hz visual timer with volume/crescendo, three-category themes with animated dynamic waves and six scenery environments, refined icon safe area, and TestFlight/native isolation guards.")
