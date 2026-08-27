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


def main() -> None:
    today = read("LifeRoute/V054TodayView.swift")
    prepare = read("scripts/prepare_build.sh")
    patch = read("scripts/patch_v0_7_0_build_b.py")

    require_all(
        today,
        [
            "v0.7.0 Build B Today/Home",
            "LifeRouteTodayHeroScene()",
            'Text("Life")',
            'Text("Route")',
            'Text("Plan your day. Optimize every gap.")',
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
        "approved Today/Home visual hierarchy",
    )

    # Build B must retain the exact selected-day safeguards introduced in v0.6.3.
    require_all(
        today,
        [
            "@State private var selectedDay = Calendar.current.startOfDay(for: Date())",
            "private var daySelector: some View",
            "v0.6.3 responsive day selector layout",
            'DatePicker("Choose day", selection: $selectedDay, displayedComponents: .date)',
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
    require_all(
        today,
        [
            "private struct LifeRouteTodayHeroScene: View",
            "private func mountainBack(_ size: CGSize) -> Path",
            "private func mountainMid(_ size: CGSize) -> Path",
            "private func mountainFront(_ size: CGSize) -> Path",
            "private func routePath(_ size: CGSize) -> Path",
            "palette.accentGradient",
        ],
        "Today hero artwork",
    )

    require("LifeRouteWebView" not in today, "Today must remain native SwiftUI")
    require("WKWebView" not in today, "Today must not reactivate WebKit")
    require("localStorage" not in today, "Today must not introduce browser persistence")
    require("TODAY_VIEW" in patch and 'PATH = ROOT / "LifeRoute/V054TodayView.swift"' in patch, "Build B patch must stay scoped to Today/Home")
    require("python3 scripts/patch_v0_7_0_build_a.py" in prepare, "Build A must remain accumulated before Build B")
    require("python3 scripts/patch_v0_7_0_build_b.py" in prepare, "canonical preparation must materialize Build B")
    require("python3 scripts/audit_v0_7_0_build_a.py" in prepare, "Build A audit must remain accumulated")
    require("python3 scripts/audit_v0_7_0_build_b.py" in prepare, "canonical preparation must run Build B audit")

    print(
        "LifeRoute v0.7.0 Build B audit passed: Today/Home matches the approved hierarchy, selected-day routing remains protected, quick actions and Live Day stay wired, responsive grid/date controls are present, and the redesign remains native-only."
    )


if __name__ == "__main__":
    main()
