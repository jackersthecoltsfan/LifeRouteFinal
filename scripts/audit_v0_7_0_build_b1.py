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


def selected_day_owner_is_valid(today: str) -> bool:
    legacy = all(
        token in today
        for token in [
            "@State private var selectedDay = Calendar.current.startOfDay(for: Date())",
            'DatePicker("Choose day", selection: $selectedDay, displayedComponents: .date)',
        ]
    )
    shared = all(
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
    if shared:
        require("@State private var selectedDay" not in today, "shared selected-day owner must not coexist with duplicate Today state")
    return legacy or shared


def brand_identity_is_valid(today: str) -> bool:
    legacy = all(token in today for token in ['Text("Life")', 'Text("Route")'])
    official = all(
        token in today
        for token in [
            "v0.7.0 official branding Today hero",
            "LifeRouteBrandMark(variant: .small)",
            'Text("LifeRoute")',
        ]
    )
    if official:
        require('Text("Life")' not in today, "official branding must remove the retired split Life wordmark")
        require('Text("Route")' not in today, "official branding must remove the retired split Route wordmark")
    return legacy or official


def main() -> None:
    today = read("LifeRoute/V054TodayView.swift")
    prepare = read("scripts/prepare_build.sh")
    patch = read("scripts/patch_v0_7_0_build_b1.py")

    require_all(
        today,
        [
            "v0.7.0 Build B.1 Today/Home parity",
            "LifeRouteTodayHeroScene()",
            'Text("Plan your day. Optimize every gap.")',
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
    require(
        brand_identity_is_valid(today),
        "Today brand identity must retain the reviewed B.1 split wordmark or the complete official LifeRoute brand supersession",
    )

    # B.1 removed the old always-visible day selector from Home. The focused swipe enhancement
    # later adds a compact native pager in that same top-day role; accept that deliberate superseding
    # presentation while keeping the old selector itself out of the default stack.
    legacy_compact_presentation = "if !Calendar.current.isDateInToday(selectedDay)" in today
    swipe_compact_presentation = all(
        token in today
        for token in [
            "v0.7.0 swipeable day overview",
            "dayOverviewPager",
            "TabView(selection: selectedDayBinding)",
        ]
    )
    require(legacy_compact_presentation or swipe_compact_presentation, "selected-day presentation must remain compact or use the reviewed swipe pager")

    body_block = today.split("var body: some View", 1)[1].split("private var selectedDayEvents", 1)[0]
    require("\n                daySelector\n" not in body_block, "old persistent day selector must not return to the default Home stack")
    require(selected_day_owner_is_valid(today), "selected-day owner must be the reviewed local owner or the stricter shared CalendarCoreState owner")
    require_all(
        today,
        [
            "private var daySelector: some View",
            "v0.6.3 responsive day selector layout",
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
        "LifeRoute v0.7.0 Build B.1 audit passed: the old date selector stays out of the default Home stack, selected-day behavior remains accessible through the reviewed compact or superseding swipe presentation, the B.1 visual contract retains either its reviewed wordmark or the complete official brand supersession, the hero remains higher-contrast, and all protected native actions remain wired."
    )


if __name__ == "__main__":
    main()
