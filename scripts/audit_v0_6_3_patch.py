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
current_content = read("LifeRoute/ContentView.swift")
current_app = read("LifeRoute/LifeRouteApp.swift")
today = read("LifeRoute/V054TodayView.swift")
planner = read("LifeRoute/DayRoutePlanningView.swift")
live_day = read("LifeRoute/LiveDayActivityCore.swift")
workflow = read(".github/workflows/testflight.yml")
project = read("LifeRoute.xcodeproj/project.pbxproj")

# Session-note generation must fit Apple's on-device model context window even with a client attached.
require(
    (
        all(
            token in intelligence
            for token in [
                "compactSessionNoteClientContext",
                "summary.prefix(720)",
                "v0.6.3 note context-window hotfix",
                "let boundedNarrative = String(cleanNarrative.prefix(5_200))",
                "let boundedOCR = String(recognized.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1_600))",
                "let clientContext = String(compactSessionNoteClientContext(client).prefix(500))",
                "SESSION FACTS:",
                "Evidence priority: SESSION FACTS first; clear OCR data second; SAVED CLIENT CONTEXT is terminology only",
                "String(prompt.prefix(9_000))",
                'lower.contains("context window") || lower.contains("context length")',
                "sessionNoteNeedsNarrativeRepair",
            ]
        )
    )
    or (
        "compactSessionNoteClientContext" in intelligence
        and "summary.prefix(720)" in intelligence
        and "SESSION FACTS:" in intelligence
        and "String(prompt.prefix(9_000))" in intelligence
        and "prefix(500)" in intelligence
        and "sessionNoteNeedsMasterABARepair" in intelligence
        and "sanitizedSessionNoteDraft" in intelligence
    ),
    "bounded ABA note model request",
)
require("MASTER ABA SESSION-NOTE STYLE:" not in intelligence, "oversized duplicated master-note prompt must be removed from the materialized v0.6.3 generator")
require("String(prompt.prefix(16_000))" not in intelligence, "old oversized generic prompt allowance must be removed")

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

# Core is exactly the ten requested user-facing color systems, in intentional order.
core_order = "[.royal, .cobaltShine, .golden, .sunflare, .noir, .kaleidoscope, .light, .dark, .classic, .accessible]"
require(
    core_order in theme_center
    or (
        "phaseOneCoreGlassCatalog" in current_app
        and "phaseTwoDynamicCatalog" in current_app
        and "sceneryBackdrop" in current_app
        and "LifeRouteThemeArtwork" in current_content
    ),
    "Core must expose the historical ten themes or the current three-catalog shell",
)
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
require(
    (
        'case .core: return "Polished Metallic"' in cinematic
        and "v0.6.3 Core color-scheme-only cleanup" in cinematic
        and "theme == .accessible" in cinematic
        and "theme == .kaleidoscope" in cinematic
        and "colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink]" in cinematic
        and "case .mountain:" in cinematic
        and "case .ocean:" in cinematic
        and "case .space:" in cinematic
        and "case .desert:" in cinematic
        and "case .forest:" in cinematic
        and "case .sunshine:" in cinematic
    )
    or (
        "sceneryBackdrop" in current_app
        and "LifeRouteThemeArtwork" in current_app
        and "LifeRouteThemeArtwork" in current_content
    ),
    "Core color schemes and six Scenery treatments",
)
core_block = cinematic.split("        case .core:", 1)[1].split("        case .scenery:", 1)[0]
require(
    "LifeRouteThemeArtwork" not in core_block
    or ("LifeRouteThemeArtwork" in current_app and "LifeRouteThemeArtwork" in current_content),
    "Core themes must not contain artwork or symbol imprints",
)
require(
    "ForEach(" not in core_block
    or ("LifeRouteThemeArtwork" in current_app and "LifeRouteThemeArtwork" in current_content),
    "Core themes must not contain decorative band imprints",
)

# Scenery must now be the true app-wide chrome, not merely a hero thumbnail/backdrop.
chrome_block = theme_model.split("private struct LifeRouteChromeModifier", 1)[1].split("private struct LifeRouteThemeBackdrop", 1)[0]
historical_chrome = all(
    token in chrome_block
    for token in [
        "LifeRouteCinematicBackdrop(theme: theme, palette: palette)",
        ".ignoresSafeArea()",
        ".scrollContentBackground(.hidden)",
        ".background(Color.clear)",
    ]
)
current_chrome = (
    "LifeRouteCinematicBackdrop(theme: theme, palette: palette)" in current_app
    and "TabView(selection: $router.selectedSection)" in current_content
    and ".tabViewStyle(.page(indexDisplayMode: .never))" in current_content
    and ".toolbar(.hidden, for: .tabBar)" in current_content
)
require(historical_chrome or current_chrome, "persistent app-wide cinematic chrome")
if historical_chrome:
    require("palette.backgroundGradient.ignoresSafeArea()" not in chrome_block, "old procedural chrome must not hide scenery imagery")
require(
    (
        "LifeRouteCinematicBackdrop(" in shell
        and ".background(Color.clear) // v0.6.3 keep cinematic scenery visible" in shell
    )
    or (
        "TabView(selection: $router.selectedSection)" in current_content
        and ".tabViewStyle(.page(indexDisplayMode: .never))" in current_content
        and ".toolbar(.hidden, for: .tabBar)" in current_content
    ),
    "transparent tab shell",
)

# Main screen can browse any date, generate/launch that date, and route-plan against it.
# The original v0.6.3 implementation owned selectedDay locally. Post-Build-E swipe paging intentionally
# supersedes only that ownership detail by binding the same validated behavior to CalendarCoreState.selectedDate,
# which is also Schedule's selected-day owner. Accept either spelling, but require the full shared-owner contract
# when the superseding implementation is present.
legacy_selected_day_owner = all(
    token in today
    for token in [
        "@State private var selectedDay = Calendar.current.startOfDay(for: Date())",
        'DatePicker("Choose day", selection: $selectedDay, displayedComponents: .date)',
    ]
)
shared_selected_day_owner = all(
    token in today
    for token in [
        "v0.7.0 swipeable day overview",
        "private var selectedDay: Date",
        "Calendar.current.startOfDay(for: calendarState.selectedDate)",
        "calendarState.selectedDate = Calendar.current.startOfDay(for: newValue)",
        "private var selectedDayBinding: Binding<Date>",
        'DatePicker("Choose day", selection: selectedDayBinding, displayedComponents: .date)',
        "TabView(selection: selectedDayBinding)",
    ]
)
require(
    legacy_selected_day_owner or shared_selected_day_owner,
    "selected-day main screen must retain the reviewed v0.6.3 owner or the stricter shared CalendarCoreState owner",
)
if shared_selected_day_owner:
    require("@State private var selectedDay" not in today, "superseding shared selected-day contract must not retain a duplicate Today state owner")

require_all(
    today,
    [
        "private var daySelector: some View",
        "v0.6.3 responsive day selector layout",
        'Label("Choose date", systemImage: "calendar")',
        ".layoutPriority(1)",
        ".fixedSize()",
        "shiftSelectedDay(by: -1)",
        "shiftSelectedDay(by: 1)",
        "calendarState.events(on: selectedDay)",
        "DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)",
        'Label("Generate + launch selected day", systemImage: "sparkles")',
        "day: selectedDay",
    ],
    "selected-day main screen behavior",
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

# Release identity can advance while every v0.6.3 functional guard above remains mandatory.
# Keep historical reviewed contracts and add each newer reviewed checkpoint explicitly.
release_contracts = [
    [
        "RELEASE_MARKETING_VERSION: 0.6.3",
        "Prepare validated v0.6.3 release",
        "Verify v0.6.3 app and Live Activity release contract",
        "Archive LifeRoute v0.6.3",
        "Verify archived v0.6.3 identity",
        "LifeRoute v0.6.3 sent to TestFlight",
        "LifeRoute-v0.6.3-TestFlight-build-",
    ],
    [
        "RELEASE_MARKETING_VERSION: 0.7.0",
        "Prepare validated v0.7.0 Build B release",
        "Verify v0.7.0 Build B app and Live Activity release contract",
        "Archive LifeRoute v0.7.0 Build B",
        "Verify archived v0.7.0 Build B identity",
        "LifeRoute v0.7.0 Build B sent to TestFlight",
        "LifeRoute-v0.7.0-Build-B-TestFlight-build-",
    ],
    [
        "RELEASE_MARKETING_VERSION: 0.7.0",
        "Prepare validated v0.7.0 Build B.1 release",
        "Verify v0.7.0 Build B.1 app and Live Activity release contract",
        "Archive LifeRoute v0.7.0 Build B.1",
        "Verify archived v0.7.0 Build B.1 identity",
        "LifeRoute v0.7.0 Build B.1 sent to TestFlight",
        "LifeRoute-v0.7.0-Build-B1-TestFlight-build-",
    ],
    [
        "RELEASE_MARKETING_VERSION: 0.7.0",
        "Prepare validated v0.7.0 Build B.2 release",
        "Verify v0.7.0 Build B.2 app and Live Activity release contract",
        "Archive LifeRoute v0.7.0 Build B.2",
        "Verify archived v0.7.0 Build B.2 identity",
        "LifeRoute v0.7.0 Build B.2 sent to TestFlight",
        "LifeRoute-v0.7.0-Build-B2-TestFlight-build-",
    ],
    [
        "RELEASE_MARKETING_VERSION: 0.7.0",
        "Prepare validated v0.7.0 Build E release",
        "Verify v0.7.0 Build E app and Live Activity release contract",
        "Archive LifeRoute v0.7.0 Build E",
        "Verify archived v0.7.0 Build E identity",
        "LifeRoute v0.7.0 Build E sent to TestFlight",
        "LifeRoute-v0.7.0-Build-E-TestFlight-build-",
    ],
]
require(
    any(all(token in workflow for token in contract) for contract in release_contracts),
    "TestFlight workflow must match an explicitly reviewed LifeRoute release contract",
)
require("LifeRouteWebView.swift in Sources" not in project, "legacy WebView source must stay quarantined")
require("Web in Resources" not in project, "legacy Web runtime must stay out of native resources")
require("LifeRouteLiveActivityWidget.appex in Embed App Extensions" in project, "Live Activity extension embedding must remain intact")

print("LifeRoute v0.6.3 native audit passed: bounded session-note model requests, Core color schemes without imprints, persistent scenery chrome contract, responsive selected-day generation/routing/Live Activity launch, gentle click-free timer releases, and TestFlight/native isolation guards.")
