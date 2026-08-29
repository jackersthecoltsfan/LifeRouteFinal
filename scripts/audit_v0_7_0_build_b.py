#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.7.0 Build B audit failed: {message}")


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


def main() -> None:
    today = read("LifeRoute/V054TodayView.swift")
    prepare = read("scripts/prepare_build.sh")
    patch = read("scripts/patch_v0_7_0_build_b.py")

    build_b_hero = all(
        token in today
        for token in [
            "v0.7.0 Build B Today/Home",
            "LifeRouteTodayHeroScene()",
            'Text("Life")',
            'Text("Route")',
            'Text("Plan your day. Optimize every gap.")',
        ]
    )
    official_branding_hero = all(
        token in today
        for token in [
            "v0.7.0 official branding Today hero",
            "LifeRouteTodayHeroScene()",
            "LifeRouteBrandMark(variant: .small)",
            'Text("LifeRoute")',
            'Text("Plan your day. Optimize every gap.")',
        ]
    )
    require(build_b_hero or official_branding_hero, "approved Today/Home visual hierarchy")
    require_all(
        today,
        [
            "LifeRouteSectionLabel(title: \"Quick Actions\")",
            "LazyVGrid(columns: quickActionColumns",
            '"Plan Route"',
            '"Current Location"',
            '"Open Schedule"',
            '"Add Stop"',
            "LifeRouteSectionLabel(\n                title: Calendar.current.isDateInToday(selectedDay) ? \"Today’s Overview\" : \"Day Overview\"",
            'Text("Next Event")',
            'label: "Total Drives"',
            'label: "Est. Driving"',
            "LifeRouteSectionLabel(title: \"Suggested Gap Fillers\")",
            'Text("See all")',
            'Text(liveDayEnabled ? "Live Day" : "Live Day + Lock Screen")',
            ".toolbar(.hidden, for: .navigationBar)",
        ],
        "approved Today/Home secondary hierarchy",
    )

    # Build B must retain the selected-day behavior introduced in v0.6.3. A later focused
    # swipe enhancement may supersede only the local-owner spelling with CalendarCoreState.
    require(selected_day_owner_is_valid(today), "selected-day owner must be the reviewed local owner or the stricter shared CalendarCoreState owner")
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
        "selected-day regression contract",
    )

    # Protected Today actions remain wired to the same domain owners.
    require_all(
        today,
        [
            "routingState.stopLiveLocation()",
            "routingState.requestCurrentLocation()",
            "router.select(.schedule)",
            "await liveActivity.start(",
            "await liveActivity.update(",
            "await liveActivity.end()",
            "routingState.savedPlaces.filter(\\.useInGapSuggestions)",
            "routingState.routeEstimates",
        ],
        "protected Today actions",
    )

    # The hero artwork is local SwiftUI presentation only; it does not mutate the Core-theme architecture.
    # Build B.1 explicitly supersedes Build B's palette.accentGradient treatment with a deterministic
    # blue/gold mountain-road treatment. Require the shared geometry plus one exact reviewed style.
    require_all(
        today,
        [
            "private struct LifeRouteTodayHeroScene: View",
            "private func mountainBack(_ size: CGSize) -> Path",
            "private func mountainMid(_ size: CGSize) -> Path",
            "private func mountainFront(_ size: CGSize) -> Path",
            "private func routePath(_ size: CGSize) -> Path",
        ],
        "Today hero artwork geometry",
    )
    build_b1_hero = all(
        token in today
        for token in [
            "v0.7.0 Build B.1 Today/Home parity",
            "private let brandGold = Color(red: 0.96, green: 0.72, blue: 0.20)",
            "private let brandGoldBright = Color(red: 1.00, green: 0.86, blue: 0.43)",
            "style: StrokeStyle(lineWidth: 17",
            "style: StrokeStyle(lineWidth: 3.8",
            "Color.white.opacity(0.50)",
        ]
    )
    require(build_b_hero or build_b1_hero, "Today hero must match the reviewed Build B gradient or its explicit Build B.1 blue/gold superseding treatment")

    require("LifeRouteWebView" not in today, "Today must remain native SwiftUI")
    require("WKWebView" not in today, "Today must not reactivate WebKit")
    require("localStorage" not in today, "Today must not introduce browser persistence")
    require("TODAY_VIEW" in patch and 'PATH = ROOT / "LifeRoute/V054TodayView.swift"' in patch, "Build B patch must stay scoped to Today/Home")
    require("python3 scripts/patch_v0_7_0_build_a.py" in prepare, "Build A must remain accumulated before Build B")
    require("python3 scripts/patch_v0_7_0_build_b.py" in prepare, "canonical preparation must materialize Build B")
    require("python3 scripts/audit_v0_7_0_build_a.py" in prepare, "Build A audit must remain accumulated")
    require("python3 scripts/audit_v0_7_0_build_b.py" in prepare, "canonical preparation must run Build B audit")

    print(
        "LifeRoute v0.7.0 Build B audit passed: Today/Home matches the approved hierarchy, selected-day routing remains protected under the reviewed or superseding shared owner, quick actions and Live Day stay wired, responsive grid/date controls are present, and the redesign remains native-only."
    )


if __name__ == "__main__":
    main()
