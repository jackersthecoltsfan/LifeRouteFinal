#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.0 Build B.1 audit failed: {message}")


def require_all(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    require(not missing, f"{label} missing: {', '.join(missing)}")


def main() -> None:
    today = read("LifeRoute/V054TodayView.swift")
    prepare = read("scripts/prepare_build.sh")
    patch = read("scripts/patch_v0_7_0_build_b1.py")

    require_all(
        today,
        [
            "v0.7.0 Build B.1 Today/Home parity",
            "LifeRouteTodayHeroScene()",
            'Text("Life")',
            'Text("Route")',
            'Text("Plan your day. Optimize every gap.")',
            "if !Calendar.current.isDateInToday(selectedDay)",
            "selectedDayContext",
            "@State private var showingDayPicker = false",
            ".sheet(isPresented: $showingDayPicker)",
            "dayPickerSheet",
            'Button("Done")',
            ".presentationDetents([.height(245)])",
            "private var brandGold: Color",
            "private var routeBlue: Color",
            "private var schedulePurple: Color",
            "accent: brandGold",
            "accent: routeBlue",
            "accent: schedulePurple",
        ],
        "device-tuned target hierarchy",
    )

    # The target screenshot has no always-visible date card. The old selector must
    # remain available only from the hero control so the selected-day feature survives.
    body_block = today.split("var body: some View", 1)[1].split("private var selectedDayEvents", 1)[0]
    require("\n                daySelector\n" not in body_block, "persistent day selector must not remain in the default Home stack")
    require_all(
        today,
        [
            "@State private var selectedDay = Calendar.current.startOfDay(for: Date())",
            "private var daySelector: some View",
            "v0.6.3 responsive day selector layout",
            'DatePicker("Choose day", selection: $selectedDay, displayedComponents: .date)',
            'Label("Choose date", systemImage: "calendar")',
            "shiftSelectedDay(by: -1)",
            "shiftSelectedDay(by: 1)",
            "calendarState.events(on: selectedDay)",
            "DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)",
            'Label("Generate + launch selected day", systemImage: "sparkles")',
            "day: selectedDay",
        ],
        "selected-day functionality retained behind compact presentation",
    )

    require_all(
        today,
        [
            'Image(systemName: "sun.max.fill")',
            '.accessibilityLabel("Choose day")',
            "routingState.stopLiveLocation()",
            "routingState.requestCurrentLocation()",
            "router.select(.schedule)",
            "await liveActivity.start(",
            "await liveActivity.update(",
            "await liveActivity.end()",
            "routingState.savedPlaces.filter(\\.useInGapSuggestions)",
            "routingState.routeEstimates",
        ],
        "protected Home behaviors",
    )

    require_all(
        today,
        [
            "private let brandGold = Color(red: 0.96, green: 0.72, blue: 0.20)",
            "private let brandGoldBright = Color(red: 1.00, green: 0.86, blue: 0.43)",
            "private func mountainBack(_ size: CGSize) -> Path",
            "private func mountainMid(_ size: CGSize) -> Path",
            "private func mountainFront(_ size: CGSize) -> Path",
            "private func routePath(_ size: CGSize) -> Path",
            "style: StrokeStyle(lineWidth: 17",
            "style: StrokeStyle(lineWidth: 3.8",
            "Color.white.opacity(0.50)",
        ],
        "higher-contrast blue/gold mountain-road hero",
    )

    require("LifeRouteWebView" not in today, "Home must remain native SwiftUI")
    require("WKWebView" not in today, "Home must not reactivate WebKit")
    require("localStorage" not in today, "Home must not introduce browser persistence")
    require('PATH = ROOT / "LifeRoute/V054TodayView.swift"' in patch, "B.1 patch must stay scoped to Today/Home")
    require("python3 scripts/patch_v0_7_0_build_b.py" in prepare, "Build B must remain accumulated before B.1")
    require("python3 scripts/patch_v0_7_0_build_b1.py" in prepare, "canonical preparation must materialize B.1")
    require("python3 scripts/audit_v0_7_0_build_b.py" in prepare, "Build B audit must remain accumulated")
    require("python3 scripts/audit_v0_7_0_build_b1.py" in prepare, "canonical preparation must run B.1 audit")

    print(
        "LifeRoute v0.7.0 Build B.1 audit passed: the default Home stack matches the target density without the date card, selected-day behavior remains accessible, blue/gold brand hierarchy is deterministic, the hero is higher-contrast, and all protected native actions remain wired."
    )


if __name__ == "__main__":
    main()
