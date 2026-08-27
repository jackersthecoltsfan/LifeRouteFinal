#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.0 visual library reuse audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


def main() -> None:
    views = read("LifeRoute/SessionToolsViews.swift")
    domain = read("LifeRoute/SessionToolsDomain.swift")
    persistence = read("LifeRoute/PersistenceCore.swift")
    prepare = read("scripts/prepare_build.sh")
    patch = read("scripts/patch_v0_7_0_visual_library_reuse.py")

    require_all(
        domain,
        [
            "@Published private(set) var choiceBoards: [ClientChoiceBoard]",
            "@Published private(set) var schedules: [ClientVisualSchedule]",
            "func choiceBoards(for clientCode: String) -> [ClientChoiceBoard]",
            "func schedules(for clientCode: String) -> [ClientVisualSchedule]",
            "func saveChoiceBoard(clientCode: String, title: String, iconIDs: [UUID], columns: Int)",
            "func saveSchedule(clientCode: String, title: String, steps: [ClientVisualScheduleStep])",
            "persistVisualSupports()",
        ],
        "saved board and schedule domain ownership",
    )

    require_all(
        persistence,
        [
            "loadClientVisualSupports",
            "saveClientVisualSupports",
            "choiceBoards",
            "schedules",
        ],
        "persistent visual support storage",
    )

    require_all(
        views,
        [
            "v0.7.0 saved visual library reuse",
            "private var savedVisualLibrary: some View",
            'Text("Saved visuals")',
            'Text("CHOICE BOARDS")',
            'Text("VISUAL SCHEDULES")',
            "ClientChoiceBoardPreviewView(",
            "ClientVisualSchedulePreviewView(",
            'actionLabel: "Open"',
            'Label("Preview board", systemImage: "rectangle.on.rectangle")',
            'Label("Open schedule", systemImage: "rectangle.on.rectangle")',
            "LazyVGrid(columns: gridColumns",
            "ForEach(board.iconIDs, id: \\.self)",
            "ForEach(Array(schedule.steps.enumerated()), id: \\.element.id)",
        ],
        "discoverable reusable saved visual UI",
    )

    # B.1 used standard NavigationStack titles. B.2 deliberately supersedes those
    # with a true full-screen session surface that hides navigation/tab chrome and
    # owns an explicit Close control. Require one exact reviewed presentation model.
    legacy_navigation_preview = (
        'navigationTitle("Board Preview")' in views
        and 'navigationTitle("Schedule Preview")' in views
    )
    b2_fullscreen_preview = all(
        token in views
        for token in [
            "v0.7.0 B.2 save and fullscreen preview",
            '.accessibilityLabel("Close board preview")',
            '.accessibilityLabel("Close schedule preview")',
            ".toolbar(.hidden, for: .navigationBar)",
            ".toolbar(.hidden, for: .tabBar)",
        ]
    )
    require(
        legacy_navigation_preview or b2_fullscreen_preview,
        "saved visuals must reopen into either the reviewed B.1 navigation preview or the reviewed B.2 full-screen session preview",
    )

    center_block = views.split("struct ClientVisualSupportCenter: View", 1)[1].split("private struct VisualWorkspaceCard", 1)[0]
    require("savedVisualLibrary" in center_block, "Visual Supports landing screen must expose saved boards and schedules")
    require("visualState.choiceBoards(for: selectedClientCode)" in center_block, "library must read saved boards for the selected library")
    require("visualState.schedules(for: selectedClientCode)" in center_block, "library must read saved schedules for the selected library")

    require("LifeRouteWebView" not in views, "saved visual reuse must remain native SwiftUI")
    require("WKWebView" not in views, "saved visual reuse must not activate WebKit")
    require('PATH = ROOT / "LifeRoute/SessionToolsViews.swift"' in patch, "reuse patch must stay scoped to visual-support presentation")
    require("python3 scripts/patch_v0_7_0_visual_library_reuse.py" in prepare, "canonical preparation must materialize saved visual reuse")
    require("python3 scripts/audit_v0_7_0_visual_library_reuse.py" in prepare, "canonical preparation must run saved visual reuse audit")

    print(
        "LifeRoute v0.7.0 visual library reuse audit passed: persisted choice boards and schedules are discoverable from the Visual Supports library, reopen into a reviewed session-ready preview model, remain client/General scoped, and preserve native persistence ownership."
    )


if __name__ == "__main__":
    main()
