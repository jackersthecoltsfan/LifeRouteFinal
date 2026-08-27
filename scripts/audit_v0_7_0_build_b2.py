#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.0 Build B.2 audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


def main() -> None:
    today = read("LifeRoute/V054TodayView.swift")
    tools = read("LifeRoute/SessionToolsViews.swift")
    prepare = read("scripts/prepare_build.sh")
    patch = read("scripts/patch_v0_7_0_build_b2.py")

    require_all(
        today,
        [
            "v0.7.0 Build B.2 device QA",
            "LazyVStack(spacing: 9)",
            ".padding(.horizontal, 12)",
            ".frame(height: dynamicTypeSize.isAccessibilitySize ? 222 : 182)",
            ".frame(maxWidth: .infinity, minHeight: 68, alignment: .top)",
            ".frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)",
            ".buttonStyle(.plain)",
            "v0.7.0 restored To-Do gap fillers",
            "ForEach(suggestions.prefix(openTodos.isEmpty ? 4 : 2))",
        ],
        "real-device Home density pass",
    )

    require_all(
        today,
        [
            "@State private var selectedDay = Calendar.current.startOfDay(for: Date())",
            "selectedDayContext",
            "dayPickerSheet",
            "routingState.requestCurrentLocation()",
            "routingState.stopLiveLocation()",
            "router.select(.schedule)",
            "DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)",
            "await liveActivity.start(",
            "await liveActivity.update(",
            "await liveActivity.end()",
        ],
        "protected Home behavior after density pass",
    )

    require_all(
        tools,
        [
            "v0.7.0 B.2 save and fullscreen preview",
            "@State private var previewBoard: ClientChoiceBoard?",
            "@State private var previewSchedule: ClientVisualSchedule?",
            'Label("Save & Preview", systemImage: "rectangle.on.rectangle.angled")',
            ".safeAreaInset(edge: .bottom)",
            ".fullScreenCover(item: $previewBoard)",
            ".fullScreenCover(item: $previewSchedule)",
            "let saved = try visualState.saveChoiceBoard",
            "previewBoard = saved",
            "let saved = try visualState.saveSchedule",
            "previewSchedule = saved",
            "struct ClientChoiceBoardPreviewView: View",
            "struct ClientVisualSchedulePreviewView: View",
            '@Environment(\\.dismiss) private var dismiss',
            '.accessibilityLabel("Close board preview")',
            '.accessibilityLabel("Close schedule preview")',
            ".toolbar(.hidden, for: .navigationBar)",
            ".toolbar(.hidden, for: .tabBar)",
        ],
        "persistent save and true full-screen visual previews",
    )

    require_all(
        tools,
        [
            "v0.7.0 saved visual library reuse",
            "savedVisualLibrary",
            "ClientChoiceBoardPreviewView(",
            "ClientVisualSchedulePreviewView(",
            "v0.7.0 horizontal First Then preview",
            'label: "FIRST"',
            'label: "THEN"',
            'Image(systemName: "arrow.right.circle.fill")',
        ],
        "accepted visual-library and First/Then behavior retained",
    )

    require("WKWebView" not in today, "Home must remain native")
    require("WKWebView" not in tools, "Visual Supports must remain native")
    require("localStorage" not in tools, "Visual Supports must not use browser persistence")

    require("python3 scripts/patch_v0_7_0_build_b1.py" in prepare, "B.1 must remain accumulated before B.2")
    require("python3 scripts/patch_v0_7_0_visual_library_reuse.py" in prepare, "saved visual library patch must remain accumulated")
    require("python3 scripts/patch_v0_7_0_first_then_horizontal.py" in prepare, "horizontal First/Then patch must remain accumulated")
    require("python3 scripts/patch_v0_7_0_todos_restore_b1.py" in prepare, "To-Dos restoration must remain accumulated")
    require("python3 scripts/patch_v0_7_0_build_b2.py" in prepare, "canonical preparation must materialize B.2 last")
    require("python3 scripts/audit_v0_7_0_build_b2.py" in prepare, "canonical preparation must run B.2 audit")

    require('TODAY = ROOT / "LifeRoute/V054TodayView.swift"' in patch, "B.2 patch must explicitly scope Home changes")
    require('TOOLS = ROOT / "LifeRoute/SessionToolsViews.swift"' in patch, "B.2 patch must explicitly scope Visual Supports changes")

    print(
        "LifeRoute v0.7.0 Build B.2 audit passed: Home is tightened to the real-device reference rhythm, Choice Boards and Visual Schedules expose persistent Save & Preview actions, previews are true full-screen session surfaces, and accepted B.1 behavior remains intact."
    )


if __name__ == "__main__":
    main()
