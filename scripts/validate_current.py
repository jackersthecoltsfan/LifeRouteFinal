#!/usr/bin/env python3
"""Semantic validation for the canonical LifeRoute v0.8.3 source tree."""

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
EXPECTED_MARKETING_VERSION = "0.8.3"
EXPECTED_RELEASE_MARKETING_VERSION = "0.8.3"
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
            "SessionNoteContracts.swift in Sources",
            "DayRouteContracts.swift in Sources",
            "FullRouteHandoffContracts.swift in Sources",
            "ScenicRoyalDesignSystem.swift in Sources",
            "ScenicRoyalMaterials.swift in Sources",
            "ScenicRoyalEnvironment.swift in Sources",
            "ScenicRoyalThemeBridge.swift in Sources",
            "ScenicRoyalComponents.swift in Sources",
            "ScenicRoyalToolbar.swift in Sources",
        ],
        "Xcode app/extension structure",
    )
    require("LifeRouteWebView.swift in Sources" not in project, "legacy LifeRouteWebView must remain outside shipping Sources")
    require("Web in Resources" not in project, "legacy Web runtime must remain outside shipping Resources")
    require_count(project, 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";', 1, "app-target Debug fixture configuration")


def validate_active_build_path() -> None:
    prepare = read(ROOT / "scripts" / "prepare_build.sh")
    fast = read(ROOT / "scripts" / "validate_fast.sh")
    full = read(ROOT / "scripts" / "validate_full.sh")
    warning_assessor = read(ROOT / "scripts" / "assess_xcode_warnings.py")
    require_all(prepare, ["validate_fast.sh", "canonical LifeRoute v0.8.3"], "current prepare_build")
    forbidden = ["patch_v0_", "audit_v0_", "scripts/archive/", "generate_v0_", "materialize"]
    present = [token for token in forbidden if token in prepare]
    require(not present, f"prepare_build must not reconstruct historical releases: {present}")
    require("validate_current.py fast" in fast, "validate_fast must invoke the current semantic validator")
    require("validate_current.py full" in full, "validate_full must invoke the current full semantic validator")
    require("run_session_note_contract_tests.sh" in full, "validate_full must run executable Session Note contracts")
    require("run_day_route_contract_tests.sh" in full, "validate_full must run executable Day Route contracts")
    fixture_runner = read(ROOT / "scripts" / "run_session_note_contract_tests.sh")
    fixture_source = read(ROOT / "scripts" / "session_note_contract_tests.swift")
    simulator_smoke = read(ROOT / "scripts" / "run_simulator_smoke.sh")
    day_route_fixture_runner = read(ROOT / "scripts" / "run_day_route_contract_tests.sh")
    day_route_fixture_source = read(ROOT / "scripts" / "day_route_contract_tests.swift")
    require_all(fixture_runner, ["swiftc", "SessionNoteContracts.swift", "session_note_contract_tests.swift"], "Session Note fixture runner")
    require_all(
        fixture_source,
        [
            "ambiguous normal-English net stays lowercase",
            "invented numeric value is rejected",
            "trial data cannot silently become percentage data",
            "the legacy split-line physical OCR shape retains its target/value association",
            "administrative dates, times, and provider identifiers never become clinical measurements",
            "the physical before/after quality case returns professional reconstructed prose",
            "omitting a clear structured screenshot measurement triggers the existing bounded repair path",
            "context retry occurs exactly once",
            "two context failures stop after the compact retry",
            "catch is CancellationError",
            "timeout fixture reaches the safe terminal timeout",
            "failed request preserves the previous generated draft",
            "stale request output is rejected",
        ],
        "Session Note executable fixtures",
    )
    require("run_session_note_contract_tests.sh" in simulator_smoke, "native simulator smoke must execute Session Note contracts")
    require("run_day_route_contract_tests.sh" in simulator_smoke, "native simulator smoke must execute Day Route contracts")
    require_all(day_route_fixture_runner, ["swiftc", "DayRouteContracts.swift", "FullRouteHandoffContracts.swift", "day_route_contract_tests.swift"], "Day Route fixture runner")
    require_all(
        day_route_fixture_source,
        [
            "semantic duplicate is rejected",
            "same-day stops restore",
            "stops remain scoped to their day",
            "full-day sequence preserves boundary-stop and appointment order",
            "each intended stop appears once",
            "all appointments remain in the generated day",
            "events without a route address are not silently removed",
            "a saved stop can generate a stop-only day",
            "Google full-route planning preserves the exact leg order",
            "Google never truncates a route beyond three mobile waypoints",
            "Apple multi-leg routes use LifeRoute sequential continuation",
            "Waze fallback retains every ordered leg",
            "fallback never silently sorts or rewrites malformed input",
            "persisted stops round-trip with stable identity",
            "removal prevents a deleted stop from returning",
        ],
        "Day Route executable fixtures",
    )
    require_all(
        warning_assessor,
        [
            "Metadata extraction skipped. No AppIntents.framework dependency found.",
            "Unexpected compiler warning lines",
            "return 1",
        ],
        "current Xcode warning assessor",
    )
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
    require_all(
        navigation,
        [
            "case today",
            "case schedule",
            "case tools",
            "case resources",
            "case setup",
            'case .schedule: return "Calendar"',
            'case .tools: return "wrench.and.screwdriver.fill"',
            "isBottomToolbarSuppressed",
            "func setBottomToolbarSuppressed(_ suppressed: Bool)",
            "var shouldShowBottomToolbar: Bool",
            "return todayPath.isEmpty",
            "return schedulePath.isEmpty",
            "return toolsPath.isEmpty",
            "return resourcesPath.isEmpty",
            "return setupPath.isEmpty",
        ],
        "five-section AppSection and deep-route toolbar policy",
    )
    require_all(navigation, ["todayPath = NavigationPath()", "schedulePath = NavigationPath()", "toolsPath = NavigationPath()", "resourcesPath = NavigationPath()", "setupPath = NavigationPath()"], "independent router paths")
    require_count(root, "@StateObject private var router = AppRouter()", 1, "root router ownership")
    require_count(root, "NavigationStack(path: $router.", 5, "five independent navigation stacks")
    require_count(root, ".tag(AppSection.", 5, "five section tags")
    toolbar = sources["ScenicRoyalToolbar.swift"]
    require_count(toolbar, "struct ScenicRoyalToolbar: View", 1, "Scenic Royal toolbar ownership")
    require_all(
        root,
        [
            "selection: $router.selectedSection",
            "ScenicRoyalToolbar(selection: $router.selectedSection)",
            ".tabViewStyle(.page(indexDisplayMode: .never))",
            "if router.shouldShowBottomToolbar",
            ".environmentObject(router)",
            ".toolbar(.hidden, for: .tabBar)",
            "bar.isHidden = true",
        ],
        "paged toolbar/router synchronization and UIKit suppression",
    )
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
    environment = sources["ScenicRoyalEnvironment.swift"]
    center = sources["V054ThemeCenterView.swift"]
    corpus = "\n".join(sources.values())
    require_count(corpus, "struct LifeRouteLiveThemeEnvironment: View", 1, "live theme environment ownership")
    require_count(app, "TimelineView(\n            .animation(", 1, "authoritative root animation clock")
    require_all(app, ["minimumInterval: 1.0 / 20.0", "paused: reduceMotion || !isActive"], "lifecycle and Reduce Motion clock pausing")
    require_all(environment, ["struct ScenicRoyalEnvironmentHost", "isActive: scenePhase == .active", "reduceMotion || reduceMotionOverride"], "persistent Scenic Royal environment host")
    require("Timer.scheduledTimer" not in app, "theme architecture must not introduce a competing Timer owner")
    core = extract_catalog(app, "static let phaseOneCoreGlassCatalog")
    dynamic = extract_catalog(app, "static let v071RetainedDynamicCatalog")
    scenery = extract_catalog(app, "static let v071RetainedSceneryCatalog")
    require((len(core), len(dynamic), len(scenery)) == (12, 8, 12), f"current user-facing theme catalog counts changed: core={len(core)}, dynamic={len(dynamic)}, scenery={len(scenery)}")
    require(len(set(core + dynamic + scenery)) == 32, "current user-facing theme catalogs must not overlap")
    require_all(center, ["return LifeRouteTheme.phaseOneCoreGlassCatalog", "return LifeRouteTheme.v071RetainedDynamicCatalog", "return LifeRouteTheme.v071RetainedSceneryCatalog"], "Theme Center current catalogs")
    require("TimelineView" not in center, "Theme Center previews must remain static")


def validate_scenic_royal_foundation(sources: dict[str, str]) -> None:
    design = sources["ScenicRoyalDesignSystem.swift"]
    materials = sources["ScenicRoyalMaterials.swift"]
    environment = sources["ScenicRoyalEnvironment.swift"]
    bridge = sources["ScenicRoyalThemeBridge.swift"]
    components = sources["ScenicRoyalComponents.swift"]
    toolbar = sources["ScenicRoyalToolbar.swift"]
    today = sources["V054TodayView.swift"]
    require_all(design, ["enum ScenicRoyalDesignSystem", "minimumTouchTarget", "standardToolbarHeight", "accessibilityToolbarHeight"], "Scenic Royal design tokens")
    require_all(
        materials,
        [
            "if #available(iOS 26.0, *)",
            "GlassEffectContainer",
            ".glassEffect(",
            ".ultraThinMaterial",
            "accessibilityReduceTransparency",
            "colorSchemeContrast",
        ],
        "native Liquid Glass and fallback material boundary",
    )
    require_all(environment, ["ScenicRoyalEnvironmentHost", "accessibilityReduceMotion", "accessibilityReduceTransparency", "scenePhase == .active"], "persistent environment accessibility boundary")
    require_all(bridge, ["sceneryCanyonDay", "sceneryArcticDay", "sceneryRainforestDay", "royalCurrent", "scenicRoyalThemeStyle"], "theme-to-material bridge")
    require_all(components, ["ScenicRoyalCard", "ScenicRoyalSectionHeader", "ScenicRoyalIconBadge", "ScenicRoyalPrimaryButtonStyle", "ScenicRoyalSecondaryButtonStyle"], "shared Scenic Royal components")
    require_count(toolbar, "ForEach(AppSection.allCases)", 1, "five-root Scenic Royal toolbar")
    require_all(toolbar, ["accessibilityReduceMotion", "dynamicTypeSize", 'accessibilityLabel("Main navigation")', 'accessibilityValue(isSelected ? "Selected" : "")'], "toolbar accessibility contract")
    require_all(today, ["ScenicRoyalSectionHeader", "ScenicRoyalGlassEffectContainer", ".scenicRoyalCard(", ".scenicRoyalInteractiveSurface("], "Today Scenic Royal migration")
    require("LifeRouteTodaySelectedExemplarArtwork" not in today, "Today must use the persistent root scenery instead of a screen-local exemplar background")


def validate_clinical_and_aba(sources: dict[str, str]) -> None:
    tools_domain = sources["SessionToolsDomain.swift"]
    tools_views = sources["SessionToolsViews.swift"]
    dashboard = sources["V054ToolsDashboard.swift"]
    clinical = sources["AIClinicalToolsViews.swift"]
    intelligence = sources["LifeRouteIntelligenceCore.swift"]
    contracts = sources["SessionNoteContracts.swift"]
    app = sources["LifeRouteApp.swift"]
    require_all(tools_domain, ["struct ClientChoiceBoard", "struct ClientVisualSchedule", "final class ClientVisualSupportCore", "General visual library"], "ABA visual domain")
    require_all(sources["PersistenceCore.swift"], ["generalVisualLibraryID", "generalVisualLibraryCode", "codeByClientID[Self.generalVisualLibraryID]"], "protected General visual library persistence")
    require_all(tools_views, ["ClientVisualSupportCenter", "ClientVisualIconLibraryView", "ClientChoiceBoardBuilderView", "ClientFirstThenVisualView", "ClientVisualScheduleBuilderView", "VisualTimerView", "QuickSessionNotesView", "SessionPlanOrganizerView"], "Build 106 ABA/session surfaces")
    require_all(dashboard, ["AISessionNoteGeneratorView", "AISessionPlanBuilderView", 'title: "Session Note"', 'title: "Session Plan"'], "Tools clinical entry points")
    require_all(
        clinical,
        [
            "SessionNoteGenerationState",
            "case completed(SessionNoteFinalOutcome)",
            "SessionNoteGenerating",
            "AISessionNoteRuntimeModel",
            "SessionNoteGenerationResult",
            "generatedNote",
            "diagnosticReceipt",
            "result.diagnostics.shareableText",
            'Label("Copy troubleshooting details", systemImage: "doc.on.doc")',
            "TextEditor(text: $runtime.generatedNote)",
            "outcome.userFacingStatusTitle",
            ".lifeRouteReadableTextSurface()",
            "SessionNoteReadabilityFixtureView",
            "maxSelectionCount: 6",
            "@FocusState private var focusedField",
            ".scrollDismissesKeyboard(.interactively)",
            "ToolbarItemGroup(placement: .keyboard)",
            "ABATerminologyNormalizer.normalize(narrative)",
            'case contextRetrySuccess = "context-retry-success"',
            'case contextRetryFailure = "context-retry-failure"',
            ".toolbar(.hidden, for: .tabBar)",
            'Text("Experimental AI Tool")',
            "Do not rely on this tool as final clinical documentation.",
        ],
        "reviewable on-device Session Note flow",
    )
    require_all(
        intelligence,
        [
            "SessionNoteEvidencePacket",
            "SessionNoteGenerationPipeline.generate",
            "maximumResponseTokens: 900",
            "LanguageModelSession.GenerationError.exceededContextWindowSize",
            "case contextWindowExceeded",
            "VNRecognizeTextRequest",
            "FoundationModels",
            "SessionNoteOCRMeasurementExtractor.extract",
            'category: "SessionNotePipeline"',
            "event.privacySafeDescription",
            "Reconstruct one editable professional ABA session note",
            "Do not copy the source clause structure",
            "Preserve the original chronology instead of regrouping events by target",
            "never append a detached data section",
        ],
        "compact on-device clinical generation and bounded context recovery",
    )
    require_all(
        contracts,
        [
            "SessionNoteEvidencePacket",
            "SessionNoteEvidenceNormalizer",
            "SessionNoteIdentifierScrubber",
            "ABATerminologyNormalizer",
            "SessionNoteOutputSanitizer",
            "SessionNoteOutputValidator",
            "SessionNoteValidationSeverity",
            "SessionNoteValidationIssue",
            "SessionNoteDeterministicRepairer",
            "SessionNoteConservativeFallback",
            "SessionNoteGenerationResult",
            "SessionNoteFinalOutcome",
            "SessionNotePipelineDiagnosticEvent",
            "SessionNoteCandidateDiagnostics",
            "SessionNoteDiagnosticReceipt",
            '"SN-DIAG-1',
            "case candidateAssessment",
            "case repairAttempted",
            "SessionNoteNumericClaim",
            "SessionNoteMeasurementEvidence",
            "SessionNoteOCRMeasurementExtractor",
            "structuredMeasurements",
            "PROFESSIONAL RECONSTRUCTION REQUIREMENTS",
            "Do not copy conversational transitions or preserve the source clause structure",
            "generic work only as instructional activities or a work period",
            "isProfessionallyReady",
            "boundedModelRepairIssues",
            '"SN-QUALITY-004"',
            '"SN-QUALITY-005"',
            'case professionalPresentation',
            '"Professional rewrite could not be completed"',
            '"SN-EVIDENCE-006"',
            "SessionNoteRequestRace",
            "SessionNoteDraftLedger",
            "case compactRetry",
            "case repair",
            "case hardBlocker",
            "case repairable",
            "case warning",
            '"behaviors of concern"',
            '"BCBA-D"',
            '"VB-MAPP"',
            '"ABLLS-R"',
        ],
        "deterministic Session Note evidence, identity, terminology, data, and output contracts",
    )
    require_all(
        app,
        [
            "LifeRouteReadableTextSurfaceModifier",
            "accessibilityReduceTransparency",
            "colorSchemeContrast",
            "AnyShapeStyle(.regularMaterial)",
            "lifeRouteReadableTextSurface",
        ],
        "accessible dense-text readability floor inside retained glass cards",
    )
    require_all(
        tools_domain,
        [
            "enum ABAVisualSupportConceptInterpreter",
            "water play",
            "outside",
            "break",
            "help",
            "more",
            "bathroom",
            "eat",
            "sleep",
        ],
        "functional ABA visual-concept interpretation",
    )
    require_all(
        tools_views + dashboard,
        [
            "ABAVisualSupportConceptInterpreter.describe",
            "Functional concept:",
            "Do not render letters, words, captions, labels",
        ],
        "interpreted visual-support prompt contract",
    )
    require('VisualWorkspaceCard(title: "Schedules"' not in tools_views, "Visual Schedule must remain hidden from the visual workspace")
    require(dashboard.count("scheduleAICard") == 1, "Visual Schedule AI card must remain dormant rather than exposed")
    require("ClientVisualScheduleBuilderView(" not in dashboard, "Tools dashboard must not expose the dormant Visual Schedule builder")
    require_all(
        dashboard,
        [
            "ClientVisualIconLibraryView(",
            "embedded: true",
            'visualBuilderLinkLabel("Choice Boards"',
            'visualBuilderLinkLabel("First / Then"',
            ".scrollDismissesKeyboard(.interactively)",
        ],
        "one-screen Visual AI Studio",
    )
    require("Open Illustrated Icon Generator" not in dashboard, "Visual AI Studio must not retain the redundant generator subpage action")
    require_all(
        tools_views,
        [
            '"Text only"',
            '"Take photo"',
            '"Photo Library"',
            "PhotosPicker",
            "VisualSupportCameraPicker",
            "AVCaptureDevice.authorizationStatus",
            "referencePhotoData",
            "isGeneratedArtwork",
        ],
        "explicit text, camera, and photo-library Visual AI input",
    )
    require_count(dashboard, ".lifeRouteDeepDestination()", 6, "deep Tools destination toolbar suppression")
    forbidden_network = ["URLSession.shared", "api.openai.com", "anthropic.com"]
    present = [token for token in forbidden_network if token in clinical + intelligence]
    require(not present, f"clinical generation must not add a cloud fallback: {present}")


def validate_calendar_routing_and_persistence(sources: dict[str, str]) -> None:
    calendar = sources["CalendarDomain.swift"]
    providers = sources["CalendarProviderCore.swift"]
    routing = sources["RoutingLocationDomain.swift"]
    day_route = sources["DayRoutePlanningCore.swift"]
    day_route_contracts = sources["DayRouteContracts.swift"]
    full_route_contracts = sources["FullRouteHandoffContracts.swift"]
    day_route_view = sources["DayRoutePlanningView.swift"]
    setup = sources["V054SetupView.swift"]
    today = sources["V054TodayView.swift"]
    persistence = sources["PersistenceCore.swift"]
    migration = sources["LegacyMigrationCore.swift"]
    require_all(calendar, ["case day", "case week", "case month", "loadManualCalendarEvents", "addManualEvent", "removeEvent", "persistManualEvents"], "calendar range/manual appointment behavior")
    require_all(providers, ["EKEventStore", "https://www.googleapis.com/auth/calendar.readonly", "ASWebAuthenticationSession", "kSecClassGenericPassword"], "Apple/Google read-only calendar providers")
    require_all(routing, ["CLLocationManager", "requestWhenInUseAuthorization", "allowsBackgroundLocationUpdates = false", "savedPlaces", "todos", "dayStops", "addDayStop", "removeDayStop", "MKDirections", "openInMaps"], "foreground routing and saved-place ownership")
    require_all(day_route, ["startFullRoute", "continueFullRoute", "nextSequentialLegIndex", "returnHome", "LifeRouteDaySequenceBuilder.waypoints", "MKMapItem.openMaps"], "day-route handoff behavior")
    require_all(day_route_contracts, ["LifeRouteDayStop: Identifiable, Codable", "LifeRouteDayStopCollection", "LifeRouteDaySequenceBuilder", "before + events + after"], "persistent per-day stop and full-day sequence contract")
    require_all(full_route_contracts, ["completeGoogleMaps", "completeAppleMaps", "maximumGoogleMobileWaypoints = 3", "maximumURLLength = 2_048", "hasVerifiedSequence", "sequentialPlan"], "bounded provider full-route contract")
    require_all(day_route_view, ["routingState.dayStops(on: day)", "routingState.addDayStop", "routingState.removeDayStop", '"Generate full day route"', '"Start full route in \\(plan.provider.title)"'], "Day Route persisted-stop and one-action presentation")
    require("Open this leg" not in day_route_view, "Day Route must not expose separate normal-flow launch actions for each leg")
    require_all(setup + today, ["Weekly To-Dos", "gap suggestions"], "weekly To-Dos and gap suggestions")
    require_all(persistence, ["schemaVersion", "PersistedVisualIcon", "PersistedChoiceBoard", "PersistedVisualSchedule", "dayStops", "manualCalendarEvents", "providerCalendarEvents", "FileProtectionType.completeUntilFirstUserAuthentication", "options: [.atomic]", "private actor SnapshotWriter"], "native persistence and protected visual storage")
    require_all(today, ["selectedDayStops", "selectedDayPlanWaypoints", "liveDaySequence", "dayStops: selectedDayStops"], "generated Live Day includes persisted stops")
    require_all(migration, ["LegacyMigrationPayload", "clients", "manualCalendarEvents", "places", "homeAddress"], "installed-version migration boundary")


def validate_timer_and_live_activity(sources: dict[str, str]) -> None:
    timer = sources["SessionToolsDomain.swift"]
    timer_view = sources["SessionToolsViews.swift"]
    live = sources["LiveDayActivityCore.swift"]
    attributes = sources["LiveDayActivityAttributes.swift"]
    widget = sources["LiveDayLiveActivityWidget.swift"]
    require_all(timer, ["private static let startFrequency = 432.0", "private static let endFrequency = 864.0", "func start(minutes:", "func pause(", "func resume(", "func addMinute(", "func reset()"], "Visual Timer domain")
    require_all(timer_view, ["TimelineView(.periodic(from: .now, by: 0.10))", "timer.start", "timer.pause", "timer.resume", "timer.addMinute", "timer.reset"], "Visual Timer presentation")
    require_all(live + attributes + widget, ["ActivityKit", "LifeRouteLiveDayAttributes", "plannedStopSummary", "returnHomePlanned", "Activity.request", "DynamicIsland", "ActivityConfiguration"], "Live Day app/extension contract")


def validate_release_and_web_policy() -> None:
    ios = read(WORKFLOWS / "ios-ci.yml")
    policy = read(WORKFLOWS / "policy-check.yml")
    pages = read(WORKFLOWS / "pages.yml")
    bridge = read(WORKFLOWS / "chatgpt-testflight-request.yml")
    testflight = read(WORKFLOWS / "testflight.yml")
    workflows = {path.name: read(path) for path in sorted(WORKFLOWS.glob("*.yml"))}
    require_all(
        ios,
        [
            "validate_fast.sh",
            "validate_full.sh",
            "configuration Debug",
            "configuration Release",
            "iphonesimulator",
            "assess_xcode_warnings.py",
            "Enforce compiler warning budget",
        ],
        "current native CI",
    )
    require_all(policy, ["validate_fast.sh", "release policy"], "lightweight policy validation")
    require_all(pages, ["build_web_preview.py", "validate_fast.sh"], "decoupled web preview")
    require("scripts/**" not in pages, "Pages must not trigger for arbitrary scripts changes")
    require_all(bridge, ["AUTHORIZED_TESTFLIGHT_RELEASE=YES", "Require completed release-equivalent iOS validation", "Reconfirm main before TestFlight", "authorized_sha"], "exact-SHA assistant release bridge")
    require_all(testflight, ["workflow_dispatch", "authorized_sha", "Verify authorized release source", EXPECTED_APP_BUNDLE_ID, EXPECTED_EXTENSION_BUNDLE_ID, "validate_full.sh", "archive", "Verify archived LifeRoute v0.8.3 identity", "Upload to TestFlight", "Clean temporary Apple signing assets", "AppIcon"], "current v0.8.3 TestFlight contract")
    require(testflight.count(f"RELEASE_MARKETING_VERSION: {EXPECTED_RELEASE_MARKETING_VERSION}") == 1, "release workflow must match current v0.8.3 product")
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
    validate_scenic_royal_foundation(sources)
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
    print(f"LifeRoute canonical v0.8.3 {args.level} validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
