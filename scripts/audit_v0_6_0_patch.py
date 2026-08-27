#!/usr/bin/env python3
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.6.0 audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


def png_dimensions(path: str) -> tuple[int, int]:
    data = (ROOT / path).read_bytes()
    require(data[:8] == b"\x89PNG\r\n\x1a\n", f"{path} is not a PNG")
    require(len(data) >= 24 and data[12:16] == b"IHDR", f"{path} has no valid IHDR")
    return struct.unpack(">II", data[16:24])


resource = read("LifeRoute/ResourcePortalDomain.swift")
builtins = resource.split("let builtInPortals: [LifeRoutePortalLink] = [", 1)[1].split("\n    ]", 1)[0]
require(builtins.count("LifeRoutePortalLink(") == 27, "Resource Hub must retain all 27 additive built-in portals")
require_all(
    builtins,
    [
        'title: "CentralReach"',
        'title: "Motivity"',
        'title: "Rethink Behavioral Health"',
        'title: "Ensora Data Collection (Catalyst)"',
        'title: "Theralytics"',
        'title: "Hi Rasmus"',
        'title: "AlohaABA"',
        'title: "ADP Workforce Now"',
        'title: "ADP / MyADP"',
        'title: "BambooHR"',
        'title: "Gusto"',
        'title: "Paycom"',
        'title: "Paylocity"',
        'title: "UKG"',
        'title: "Rippling"',
        'title: "Workday"',
        'title: "QuickBooks Workforce"',
        'title: "Viventium"',
        'title: "BACB Portal"',
        'title: "Relias"',
        'title: "Therap"',
        'title: "HHAeXchange"',
        'title: "Sandata"',
        'title: "Microsoft 365"',
        'title: "Google Workspace"',
        'title: "Slack"',
        'title: "Microsoft Teams"',
    ],
    "Resource Hub regression catalog",
)

calendar = read("LifeRoute/CalendarDomain.swift")
require_all(
    calendar,
    [
        'providerSnapshotKey = "liferoute.calendar.providerSnapshot.v1"',
        "let providerEvents = Self.loadProviderSnapshot()",
        "persistProviderEvents()",
        "private static func loadProviderSnapshot()",
        "events.filter { $0.source != .manual }",
    ],
    "calendar provider relaunch persistence",
)
require(calendar.count("persistProviderEvents()") >= 3, "provider snapshots must persist after replace and removal")

ai_views = read("LifeRoute/AIClinicalToolsViews.swift")
require_all(
    ai_views,
    [
        'Text("Pull from Scratch Notes")',
        "matchingScratchNotes",
        "appendToNarrative",
        "appends without overwriting",
    ],
    "Scratch Notes → AI Session Note",
)

intelligence = read("LifeRoute/LifeRouteIntelligenceCore.swift")
require_all(
    intelligence,
    [
        "REQUIRED WRITING STYLE:",
        "natural chronological narrative",
        "Weave clearly supplied quantitative data",
        "generateVisualScheduleDraft",
        "Return ONLY one step per line",
        "Do not add treatment targets, prompting procedures, behavior protocols",
    ],
    "AI note narrative and visual schedule contracts",
)
require_all(
    intelligence,
    [
        "static func generateSessionPlan(",
        'instructions: "You are LifeRoute\'s session-planning assistant for an RBT. Organize only supervisor-approved information and never invent treatment procedures."',
        'End with one short "Flex:" line',
    ],
    "locked AI Session Plan contract",
)

tools = read("LifeRoute/V054ToolsDashboard.swift")
require_all(
    tools,
    [
        "VisualAIAssistedStudioView",
        "Draft steps with AI",
        "imagePlaygroundSheet",
        "ImagePlaygroundViewController.isAvailable",
        "Save generated icon",
        "Open Manual Workspace",
        "ClientVisualSupportCenter(visualState: visualState, clientState: clientState)",
    ],
    "AI visual tools with manual fallback",
)

root = read("LifeRoute/V054ContentView.swift")
require_all(
    root,
    [
        ".tint(themeStore.palette.accent)",
        "LifeRouteAppearance.refreshVisibleChrome(theme: theme)",
        "LifeRouteThemeFeedbackSound.shared.play()",
        "AVAudioSession.sharedInstance()",
        ".ambient",
    ],
    "live theme + feedback propagation",
)

app_icon = png_dimensions("LifeRoute/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
logo_source = png_dimensions("LifeRoute/Web/liferoute-logo-source.png")
require(app_icon == (1024, 1024), f"AppIcon must be 1024×1024, got {app_icon}")
require(logo_source == (128, 128), f"LR source asset changed unexpectedly, got {logo_source}")

project = read("LifeRoute.xcodeproj/project.pbxproj")
require("LifeRouteWebView.swift in Sources" not in project, "legacy WebView runtime was reactivated")
require("Web in Resources" not in project, "legacy Web bundle was reactivated")

print("LifeRoute v0.6.0 regression audit passed: resources, persistence, narrative notes, AI visuals, themes, feedback, icon contract, and native runtime isolation.")
