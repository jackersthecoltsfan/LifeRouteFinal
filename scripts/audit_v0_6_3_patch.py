#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.6.3 audit failed: {message}")


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
today = read("LifeRoute/V054TodayView.swift")
planner = read("LifeRoute/DayRoutePlanningView.swift")
live_day = read("LifeRoute/LiveDayActivityCore.swift")
workflow = read(".github/workflows/testflight.yml")
project = read("LifeRoute.xcodeproj/project.pbxproj")

# v0.6.2's selected-client context-window protection is a hard regression requirement.
require_all(
    intelligence,
    [
        "compactSessionNoteClientContext",
        "summary.prefix(720)",
        "SAVED CLIENT CONTEXT — terminology only, compacted to protect the on-device model context window",
        "Saved client information is terminology/context only and never proves an event occurred",
        "sessionNoteNeedsNarrativeRepair",
    ],
    "bounded selected-client ABA note context",
)

# Preserve the requested v0.6.2 cadence/pitch/volume contract while removing clicky buffer endings.
require_all(
    timer,
    [
        "private static let startFrequency = 432.0",
        "private static let endFrequency = 1_728.0",
        "startGainForFiveDecibelCrescendo",
        "@Published private(set) var volume: Double = 0.86",
        "if remaining <= 5 { return 5 }",
        "if remaining <= 10 { return 4 }",
        "if remaining <= 30 { return 3 }",
        "private static let pulseDuration = 0.14",
        "v0.6.3 cosine release reaches silence smoothly",
        "let release = releaseProgress <= 0 ? 1 : 0.5 * (1 + cos",
        "let softSecond = 0.12",
        "let softDetune = 0.025",
        "let releaseStart = 0.12",
        "setCategory(.playback",
    ],
    "gentle click-free timer audio",
)
require("bellThird" not in timer, "sharp third harmonic must be removed from timer ticks")
require_all(timer_view, ["Timer sound", "timer.setVolume", "5 dB digital crescendo", "432 Hz to 1728 Hz"], "timer UI regression")

# Core is exactly the ten requested user-facing polished color systems, in intentional order.
core_order = "[.royal, .cobaltShine, .golden, .sunflare, .noir, .kaleidoscope, .light, .dark, .classic, .accessible]"
require(core_order in theme_center, "Core must expose exactly the requested ten themes in the v0.6.3 order")
require_all(
    theme_model,
    [
        "case sunflare, noir, golden, cobaltShine, light, dark, kaleidoscope, classic, accessible",
        'case .royal: return "Royal"',
        'case .sunflare: return "Sunflare"',
        'case .noir: return "Noir"',
        'case .golden: return "Golden"',
        'case .cobaltShine: return "Cobalt Shine"',
        'case .light: return "Light"',
        'case .dark: return "Dark"',
        'case .kaleidoscope: return "Kaleidoscope"',
        'case .classic: return "Classic"',
        'case .accessible: return "Accessible"',
        ".preferredColorScheme(theme == .light ? .light : .dark)",
        "0x000000, 0x000000, 0x000000, 0x000000, 0xffffff, 0xffffff",
    ],
    "v0.6.3 Core theme model",
)
require("0edf1f4" not in theme_model, "Noir chrome color literal must be valid Swift")
require_all(
    cinematic,
    [
        'case .core: return "Polished Metallic"',
        "v0.6.3 polished Core treatment",
        "theme == .accessible",
        "theme == .kaleidoscope",
        "colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink]",
        "case .mountain:",
        "case .ocean:",
        "case .space:",
        "case .desert:",
        "case .forest:",
        "case .sunshine:",
    ],
    "polished Core and six Scenery treatments",
)

# Scenery must now be the true app-wide chrome, not merely a hero thumbnail/backdrop.
chrome_block = theme_model.split("private struct LifeRouteChromeModifier", 1)[1].split("private struct LifeRouteThemeBackdrop", 1)[0]
require_all(
    chrome_block,
    [
        "LifeRouteCinematicBackdrop(theme: theme, palette: palette)",
        ".ignoresSafeArea()",
        ".scrollContentBackground(.hidden)",
        ".background(Color.clear)",
    ],
    "persistent app-wide cinematic chrome",
)
require("palette.backgroundGradient.ignoresSafeArea()" not in chrome_block, "old procedural chrome must not hide scenery imagery")
require_all(shell, ["LifeRouteCinematicBackdrop(", ".background(Color.clear) // v0.6.3 keep cinematic scenery visible"], "transparent tab shell")

# Main screen can browse any date, generate/launch that date, and route-plan against it.
require_all(
    today,
    [
        "@State private var selectedDay = Calendar.current.startOfDay(for: Date())",
        "private var daySelector: some View",
        'DatePicker("Choose day", selection: $selectedDay, displayedComponents: .date)',
        "shiftSelectedDay(by: -1)",
        "shiftSelectedDay(by: 1)",
        "calendarState.events(on: selectedDay)",
        "DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)",
        'Label("Generate + launch selected day", systemImage: "sparkles")',
        "day: selectedDay",
    ],
    "selected-day main screen",
)
require_all(
    planner,
    [
        "var day: Date = Date()",
        "calendarState.events(on: day)",
        "private var dayEvents: [LifeRouteCalendarEvent]",
    ],
    "selected-day route planner",
)
require_all(
    live_day,
    [
        "day: Date = Date()",
        "dayLabel: day.formatted",
        "Add a timed event on the selected day",
    ],
    "selected-day Live Activity",
)

# Release identity and native isolation.
require_all(
    workflow,
    [
        "RELEASE_MARKETING_VERSION: 0.6.3",
        "Prepare validated v0.6.3 release",
        "Verify v0.6.3 app and Live Activity release contract",
        "Archive LifeRoute v0.6.3",
        "Verify archived v0.6.3 identity",
        "LifeRoute v0.6.3 sent to TestFlight",
        "LifeRoute-v0.6.3-TestFlight-build-",
    ],
    "v0.6.3 TestFlight release guard",
)
require("LifeRouteWebView.swift in Sources" not in project, "legacy WebView source must stay quarantined")
require("Web in Resources" not in project, "legacy Web runtime must stay out of native resources")
require("LifeRouteLiveActivityWidget.appex in Embed App Extensions" in project, "Live Activity extension embedding must remain intact")

print("LifeRoute v0.6.3 native audit passed: persistent scenery across app chrome, ten ordered polished Core themes, selected-day generation/routing/Live Activity launch, gentle click-free timer releases, inherited selected-client context protection, and TestFlight/native isolation guards.")
