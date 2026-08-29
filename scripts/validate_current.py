#!/usr/bin/env python3
"""Semantic validation for the canonical LifeRoute v0.8.0 source tree."""

from __future__ import annotations

import argparse
import plistlib
import re
import struct
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LifeRoute"
PROJECT = ROOT / "LifeRoute.xcodeproj" / "project.pbxproj"
EXTENSION = ROOT / "LifeRouteLiveActivityWidget"
WORKFLOWS = ROOT / ".github" / "workflows"
EXPECTED_MARKETING_VERSION = "0.8.0"
EXPECTED_APP_BUNDLE_ID = "Com.Brandongood.LifeRoute"
EXPECTED_EXTENSION_BUNDLE_ID = "Com.Brandongood.LifeRoute.LiveDay"


class ValidationFailure(RuntimeError):
    pass


def read(path: Path) -> str:
    if not path.is_file():
        raise ValidationFailure(f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationFailure(message)


def require_all(text: str, tokens: list[str], owner: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{owner} is missing semantic contract(s): {missing}")


def require_count(text: str, token: str, count: int, owner: str) -> None:
    actual = text.count(token)
    require(actual == count, f"{owner} must contain {token!r} exactly {count} time(s), found {actual}")


def swift_sources() -> dict[str, str]:
    paths = sorted(APP.glob("*.swift")) + sorted(EXTENSION.glob("*.swift"))
    return {path.name: read(path) for path in paths}


def validate_plists() -> None:
    for relative in ["LifeRoute/Info.plist", "LifeRouteLiveActivityWidget/Info.plist"]:
        path = ROOT / relative
        with path.open("rb") as handle:
            values = plistlib.load(handle)
        require(values.get("CFBundleShortVersionString") == "$(MARKETING_VERSION)", f"{relative} must inherit MARKETING_VERSION")
        require(values.get("CFBundleVersion") == "$(CURRENT_PROJECT_VERSION)", f"{relative} must inherit CURRENT_PROJECT_VERSION")


def validate_app_icon() -> None:
    path = APP / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon-1024.png"
    data = path.read_bytes()
    require(data[:8] == b"\x89PNG\r\n\x1a\n", "AppIcon must be a PNG")
    require(len(data) >= 33 and data[12:16] == b"IHDR", "AppIcon must contain a valid IHDR chunk")
    width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack(">IIBBBBB", data[16:29])
    require((width, height) == (1024, 1024), f"AppIcon must be 1024 x 1024, found {width} x {height}")
    require(color_type not in {4, 6}, "AppIcon must not contain an alpha channel")
    require(b"tRNS" not in data, "AppIcon must not contain PNG transparency metadata")
    require(bit_depth in {8, 16}, f"AppIcon uses unsupported PNG bit depth {bit_depth}")
    require((compression, filter_method, interlace) == (0, 0, 0), "AppIcon PNG encoding is not the approved non-interlaced form")


def validate_project_and_version() -> None:
    project = read(PROJECT)
    marketing_versions = re.findall(r"MARKETING_VERSION = ([^;]+);", project)
    build_numbers = re.findall(r"CURRENT_PROJECT_VERSION = ([^;]+);", project)
    require(marketing_versions == [EXPECTED_MARKETING_VERSION] * 4, f"app/extension Debug/Release marketing versions must all be {EXPECTED_MARKETING_VERSION}: {marketing_versions}")
    require(len(build_numbers) == 4 and len(set(build_numbers)) == 1, f"app/extension Debug/Release build numbers must share one source value: {build_numbers}")
    require(project.count(f"PRODUCT_BUNDLE_IDENTIFIER = {EXPECTED_APP_BUNDLE_ID};") == 2, "app bundle identity must be synchronized in Debug and Release")
    require(project.count(f"PRODUCT_BUNDLE_IDENTIFIER = {EXPECTED_EXTENSION_BUNDLE_ID};") == 2, "Live Day extension bundle identity must be synchronized in Debug and Release")
    require_all(
        project,
        [
            "LifeRouteLiveActivityWidget.appex in Embed App Extensions",
            "target = W50000000000000000000001 /* LifeRouteLiveActivityWidget */",
            "LiveDayLiveActivityWidget.swift in Sources",
            "LiveDayActivityAttributes.swift in Sources",
            "Assets.xcassets in Resources",
        ],
        "Xcode app/extension structure",
    )
    require("LifeRouteWebView.swift in Sources" not in project, "legacy LifeRouteWebView must remain outside shipping Sources")
    require("Web in Resources" not in project, "legacy Web runtime must remain outside shipping Resources")


def validate_active_build_path() -> None:
    prepare = read(ROOT / "scripts" / "prepare_build.sh")
    fast = read(ROOT / "scripts" / "validate_fast.sh")
    full = read(ROOT / "scripts" / "validate_full.sh")
    require_all(prepare, ["validate_fast.sh", "canonical LifeRoute v0.8.0"], "current prepare_build")
    forbidden = ["patch_v0_", "audit_v0_", "scripts/archive/", "generate_v0_", "materialize"]
    present = [token for token in forbidden if token in prepare]
    require(not present, f"prepare_build must not reconstruct historical releases: {present}")
    require("validate_current.py fast" in fast, "validate_fast must invoke the current semantic validator")
    require("validate_current.py full" in full, "validate_full must invoke the current full semantic validator")
    active_historical = sorted(
        path.name
        for pattern in ("patch_*.py", "audit_v*.py")
        for path in (ROOT / "scripts").glob(pattern)
    )
    require(not active_historical, f"historical patch/audit scripts remain in the active scripts root: {active_historical}")


def validate_navigation_and_ownership(sources: dict[str, str]) -> None:
    navigation = sources["AppNavigation.swift"]
    root = sources["V054ContentView.swift"]
    corpus = "\n".join(sources.values())
    require_count(corpus, "final class AppRouter: ObservableObject", 1, "shipping Swift")
    require_all(navigation, ["case today", "case schedule", "case tools", "case resources", "case setup"], "five-section AppSection")
    require_all(navigation, ["todayPath = NavigationPath()", "schedulePath = NavigationPath()", "toolsPath = NavigationPath()", "resourcesPath = NavigationPath()", "setupPath = NavigationPath()"], "independent router paths")
    require_count(root, "@StateObject private var router = AppRouter()", 1, "root router ownership")
    require_count(root, "NavigationStack(path: $router.", 5, "five independent navigation stacks")
    require_count(root, ".tag(AppSection.", 5, "five section tags")
    require_count(root, "private struct LifeRouteBottomToolbar: View", 1, "custom toolbar ownership")
    require_all(root, ["selection: $router.selectedSection", ".toolbar(.hidden, for: .tabBar)", "bar.isHidden = true"], "toolbar/router synchronization and UIKit suppression")
    require("LifeRouteWebView(" not in root, "shipping root must not activate the quarantined WebView")


def extract_catalog(text: str, declaration: str) -> list[str]:
    start = text.find(declaration)
    require(start >= 0, f"missing theme catalog declaration: {declaration}")
    assignment = text.find("= [", start + len(declaration))
    open_bracket = assignment + 2 if assignment >= 0 else -1
    close_bracket = text.find("]", open_bracket)
    require(open_bracket >= 0 and close_bracket > open_bracket, f"malformed theme catalog: {declaration}")
    return re.findall(r"\.([A-Za-z][A-Za-z0-9_]*)", text[open_bracket + 1 : close_bracket])


def validate_theme_architecture(sources: dict[str, str]) -> None:
    app = sources["LifeRouteApp.swift"]
    center = sources["V054ThemeCenterView.swift"]
    corpus = "\n".join(sources.values())
    require_count(corpus, "struct LifeRouteLiveThemeEnvironment: View", 1, "live theme environment ownership")
    require_count(app, "TimelineView(\n            .animation(", 1, "authoritative root animation clock")
    require_all(app, ["minimumInterval: 1.0 / 20.0", "paused: reduceMotion || !isActive", "isActive: scenePhase == .active"], "lifecycle and Reduce Motion clock pausing")
    require("Timer.scheduledTimer" not in app, "theme architecture must not introduce a competing Timer owner")
    core = extract_catalog(app, "static let phaseOneCoreGlassCatalog")
    dynamic = extract_catalog(app, "static let v071RetainedDynamicCatalog")
    scenery = extract_catalog(app, "static let v071RetainedSceneryCatalog")
    require((len(core), len(dynamic), len(scenery)) == (12, 8, 12), f"current user-facing theme catalog counts changed: core={len(core)}, dynamic={len(dynamic)}, scenery={len(scenery)}")
    require(len(set(core + dynamic + scenery)) == 32, "current user-facing theme catalogs must not overlap")
    require_all(center, ["return LifeRouteTheme.phaseOneCoreGlassCatalog", "return LifeRouteTheme.v071RetainedDynamicCatalog", "return LifeRouteTheme.v071RetainedSceneryCatalog"], "Theme Center current catalogs")
    require("TimelineView" not in center, "Theme Center previews must remain static")


def validate_clinical_and_aba(sources: dict[str, str]) -> None:
    tools_domain = sources["SessionToolsDomain.swift"]
    tools_views = sources["SessionToolsViews.swift"]
    dashboard = sources["V054ToolsDashboard.swift"]
    clinical = sources["AIClinicalToolsViews.swift"]
    intelligence = sources["LifeRouteIntelligenceCore.swift"]
    require_all(tools_domain, ["struct ClientChoiceBoard", "struct ClientVisualSchedule", "final class ClientVisualSupportCore", "General visual library"], "ABA visual domain")
    require_all(sources["PersistenceCore.swift"], ["generalVisualLibraryID", "generalVisualLibraryCode", "codeByClientID[Self.generalVisualLibraryID]"], "protected General visual library persistence")
    require_all(tools_views, ["ClientVisualSupportCenter", "ClientVisualIconLibraryView", "ClientChoiceBoardBuilderView", "ClientFirstThenVisualView", "ClientVisualScheduleBuilderView", "VisualTimerView", "QuickSessionNotesView", "SessionPlanOrganizerView"], "Build 106 ABA/session surfaces")
    require_all(dashboard, ["AISessionNoteGeneratorView", "AISessionPlanBuilderView", 'title: "Session Note"', 'title: "Session Plan"'], "Tools clinical entry points")
    require_all(clinical, ["SessionNoteGenerationState", "SessionNoteGenerating", "AISessionNoteRuntimeModel", "generatedNote", "TextEditor(text: $runtime.generatedNote)"], "reviewable on-device Session Note flow")
    require_all(intelligence, ["using ONLY the session facts supplied below", 'Refer to the clinician only as "the RBT"', "Never use a personal clinician", "Do not fabricate", "VNRecognizeTextRequest", "FoundationModels"], "supplied-facts-only on-device clinical boundary")
    forbidden_network = ["URLSession.shared", "api.openai.com", "anthropic.com"]
    present = [token for token in forbidden_network if token in clinical + intelligence]
    require(not present, f"clinical generation must not add a cloud fallback: {present}")


def validate_calendar_routing_and_persistence(sources: dict[str, str]) -> None:
    calendar = sources["CalendarDomain.swift"]
    providers = sources["CalendarProviderCore.swift"]
    routing = sources["RoutingLocationDomain.swift"]
    day_route = sources["DayRoutePlanningCore.swift"]
    setup = sources["V054SetupView.swift"]
    today = sources["V054TodayView.swift"]
    persistence = sources["PersistenceCore.swift"]
    migration = sources["LegacyMigrationCore.swift"]
    require_all(calendar, ["case day", "case week", "case month", "loadManualCalendarEvents", "addManualEvent", "removeEvent", "persistManualEvents"], "calendar range/manual appointment behavior")
    require_all(providers, ["EKEventStore", "https://www.googleapis.com/auth/calendar.readonly", "ASWebAuthenticationSession", "kSecClassGenericPassword"], "Apple/Google read-only calendar providers")
    require_all(routing, ["CLLocationManager", "requestWhenInUseAuthorization", "allowsBackgroundLocationUpdates = false", "savedPlaces", "todos", "MKDirections", "openInMaps"], "foreground routing and saved-place ownership")
    require_all(day_route, ["case appleMaps", "case googleMaps", "case waze", "returnHome", "MKMapItem.openMaps"], "day-route handoff behavior")
    require_all(setup + today, ["Weekly To-Dos", "gap suggestions"], "weekly To-Dos and gap suggestions")
    require_all(persistence, ["schemaVersion", "PersistedVisualIcon", "PersistedChoiceBoard", "PersistedVisualSchedule", "manualCalendarEvents", "providerCalendarEvents", "FileProtectionType.completeUntilFirstUserAuthentication", "options: [.atomic]", "private actor SnapshotWriter"], "native persistence and protected visual storage")
    require_all(migration, ["LegacyMigrationPayload", "clients", "manualCalendarEvents", "places", "homeAddress"], "installed-version migration boundary")


def validate_timer_and_live_activity(sources: dict[str, str]) -> None:
    timer = sources["SessionToolsDomain.swift"]
    timer_view = sources["SessionToolsViews.swift"]
    live = sources["LiveDayActivityCore.swift"]
    attributes = sources["LiveDayActivityAttributes.swift"]
    widget = sources["LiveDayLiveActivityWidget.swift"]
    require_all(timer, ["private static let startFrequency = 432.0", "private static let endFrequency = 864.0", "func start(minutes:", "func pause(", "func resume(", "func addMinute(", "func reset()"], "Visual Timer domain")
    require_all(timer_view, ["TimelineView(.periodic(from: .now, by: 0.10))", "timer.start", "timer.pause", "timer.resume", "timer.addMinute", "timer.reset"], "Visual Timer presentation")
    require_all(live + attributes + widget, ["ActivityKit", "LifeRouteLiveDayAttributes", "returnHomePlanned", "Activity.request", "DynamicIsland", "ActivityConfiguration"], "Live Day app/extension contract")


def validate_release_and_web_policy() -> None:
    ios = read(WORKFLOWS / "ios-ci.yml")
    policy = read(WORKFLOWS / "policy-check.yml")
    pages = read(WORKFLOWS / "pages.yml")
    bridge = read(WORKFLOWS / "chatgpt-testflight-request.yml")
    testflight = read(WORKFLOWS / "testflight.yml")
    workflows = {path.name: read(path) for path in sorted(WORKFLOWS.glob("*.yml"))}
    require_all(ios, ["validate_fast.sh", "validate_full.sh", "configuration Debug", "configuration Release", "iphonesimulator"], "current native CI")
    require_all(policy, ["validate_fast.sh", "release policy"], "lightweight policy validation")
    require_all(pages, ["build_web_preview.py", "validate_fast.sh"], "decoupled web preview")
    require("scripts/**" not in pages, "Pages must not trigger for arbitrary scripts changes")
    require_all(bridge, ["AUTHORIZED_TESTFLIGHT_RELEASE=YES", "Require completed release-equivalent iOS validation", "Reconfirm main before TestFlight", "authorized_sha"], "exact-SHA assistant release bridge")
    require_all(testflight, ["workflow_dispatch", "authorized_sha", "Verify authorized release source", EXPECTED_APP_BUNDLE_ID, EXPECTED_EXTENSION_BUNDLE_ID, "validate_full.sh", "archive", "Verify archived LifeRoute v0.8.0 identity", "Upload to TestFlight", "Clean temporary Apple signing assets", "AppIcon"], "current v0.8.0 TestFlight contract")
    require(testflight.count("RELEASE_MARKETING_VERSION: 0.8.0") == 1, "TestFlight must expose one active v0.8.0 release contract")
    for name, text in workflows.items():
        if name == "testflight.yml":
            continue
        forbidden = ["APP_STORE_CONNECT_PRIVATE_KEY", "xcrun altool", "-exportArchive", "Upload to TestFlight"]
        present = [token for token in forbidden if token in text]
        require(not present, f"{name} violates sole TestFlight signing/upload ownership: {present}")


def run_fast() -> None:
    sources = swift_sources()
    validate_plists()
    validate_app_icon()
    validate_project_and_version()
    validate_active_build_path()
    validate_navigation_and_ownership(sources)
    validate_theme_architecture(sources)
    validate_clinical_and_aba(sources)


def run_full() -> None:
    sources = swift_sources()
    run_fast()
    validate_calendar_routing_and_persistence(sources)
    validate_timer_and_live_activity(sources)
    validate_release_and_web_policy()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("level", choices=["fast", "full"])
    args = parser.parse_args()
    try:
        run_fast() if args.level == "fast" else run_full()
    except (OSError, plistlib.InvalidFileException, ValidationFailure) as error:
        print(f"LifeRoute {args.level} validation failed: {error}", file=sys.stderr)
        return 1
    print(f"LifeRoute canonical v0.8.0 {args.level} validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
