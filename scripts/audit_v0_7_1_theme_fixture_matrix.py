from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.1 theme fixture matrix audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


app = read("LifeRoute/LifeRouteApp.swift")
content = read("LifeRoute/V054ContentView.swift")
capture = read("scripts/capture_v0_7_1_visual_fixtures.sh")
compare = read("scripts/compare_v0_7_1_theme_fixtures.py")
workflow = read(".github/workflows/ios-ci.yml")
prepare = read("scripts/prepare_build.sh")

dynamic_ids = [
    "dynamic.royalCurrent", "dynamic.midnightPrism", "dynamic.auroraBloom",
    "dynamic.solarPulse", "dynamic.emeraldFlow", "dynamic.oceanGlass",
    "dynamic.obsidianSpectra", "dynamic.plasmaOrchid",
]
scenery_ids = [
    "scenery.mountains.day", "scenery.mountains.night", "scenery.ocean.day",
    "scenery.ocean.night", "scenery.desert.day", "scenery.desert.night",
    "scenery.rainforest.day", "scenery.rainforest.night", "scenery.canyon.day",
    "scenery.canyon.night", "scenery.arctic.day", "scenery.arctic.night",
]

require_all(
    app,
    [
        "private struct LifeRouteVisualFixtureSelection", "case canyonDay = \"canyon-day\"",
        "case royalCurrent = \"royal-current\"", "theme.isV071RetainedDynamic",
        "theme.isV071RetainedScenery", "-LifeRouteFixtureReduceMotion",
        "reduceMotion: fixture.reduceMotion", "reduceMotion || fixtureReduceMotion",
    ],
    "DEBUG fixture selection",
)
require_all(
    content,
    [
        "import Darwin", "-LifeRouteSectionOverride", "LifeRouteDebugSectionSignal",
        "DispatchSource.makeSignalSource", "SIGUSR1", "SIG_IGN",
        "source.setEventHandler", "router.select(.schedule)",
    ],
    "in-process tab persistence fixture",
)
require(content.count("TimelineView(") == 0, "tab fixture must not introduce an animation clock")
require("Task.sleep" not in content, "tab fixture must not race Simulator launch with a timer")
require("sectionOverride(from url:" not in content, "tab fixture must not invoke an iOS URL confirmation")
require(app.count("TimelineView(") == 1, "the fully materialized app must keep one TimelineView")
require(app.count("final class LifeRouteThemeStore: ObservableObject") == 1, "one theme store must remain")

require_all(capture, dynamic_ids + scenery_ids, "twenty-theme capture catalog")
require_all(
    capture,
    [
        "today-", "schedule-", "reduce-motion-", "motion-frame-a-", "motion-frame-b-",
        'kill -USR1 "$app_pid"', "-LifeRouteFixtureReduceMotion", "validate-motion",
        "validate-identity", "validate-distinct", "validate-coverage", "validate-health", "bundle-size.txt",
    ],
    "capture matrix gates",
)
require_all(
    compare,
    [
        "def decode_png", "def analysis_png", 'shutil.which("sips")',
        "validate-motion", "validate-identity", "validate-distinct", "validate-coverage", "validate-health",
    ],
    "pixel validation helper",
)
require_all(
    workflow,
    [
        "feature/v0.7.1-theme-library-finish-codex", "liferoute-v0.7.1-theme-matrix",
        "liferoute-visual-validation/**", "timeout-minutes: 35",
    ],
    "isolated GitHub Simulator matrix",
)
require_all(
    prepare,
    [
        "patch_v0_7_1_theme_fixture_matrix.py", "audit_v0_7_1_theme_fixture_matrix.py",
        "audit_v0_7_1_scenery_library_finish.py", "audit_v0_7_1_dynamic_library_finish.py",
    ],
    "canonical fixture materialization",
)

print(
    "LifeRoute v0.7.1 theme fixture matrix audit passed: all twenty retained identities have "
    "full-shell Today/Schedule capture, deterministic Reduce Motion coverage, quantitative "
    "health/distinction gates, and eight Dynamic motion comparisons without adding a live clock."
)
