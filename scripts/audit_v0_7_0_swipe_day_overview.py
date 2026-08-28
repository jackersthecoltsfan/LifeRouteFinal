#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TODAY = ROOT / "LifeRoute/V054TodayView.swift"
SCHEDULE = ROOT / "LifeRoute/V054ScheduleView.swift"
CALENDAR = ROOT / "LifeRoute/CalendarDomain.swift"
CONTENT = ROOT / "LifeRoute/V054ContentView.swift"
PROVIDER = ROOT / "LifeRoute/CalendarProviderCore.swift"


def require(text: str, token: str, label: str) -> None:
    if token not in text:
        raise SystemExit(f"v0.7.0 swipe-day audit failed: missing {label}: {token}")


def forbid(text: str, token: str, label: str) -> None:
    if token in text:
        raise SystemExit(f"v0.7.0 swipe-day audit failed: forbidden {label}: {token}")


def main() -> None:
    today = TODAY.read_text(encoding="utf-8")
    schedule = SCHEDULE.read_text(encoding="utf-8")
    calendar = CALENDAR.read_text(encoding="utf-8")
    content = CONTENT.read_text(encoding="utf-8")
    provider = PROVIDER.read_text(encoding="utf-8")

    require(today, "v0.7.0 swipeable day overview", "feature marker")
    require(today, "private var selectedDay: Date", "shared selected-day projection")
    require(today, "Calendar.current.startOfDay(for: calendarState.selectedDate)", "CalendarCoreState selected-date read")
    require(today, "calendarState.selectedDate = Calendar.current.startOfDay(for: newValue)", "CalendarCoreState selected-date write")
    require(today, "private var selectedDayBinding: Binding<Date>", "shared selected-day binding")
    forbid(today, "@State private var selectedDay", "duplicate Today selected-day state owner")

    require(calendar, "@Published var selectedDate: Date", "calendar selected-date owner")
    require(schedule, "calendarState.selectedDate", "Schedule selected-date integration")

    require(today, "TabView(selection: selectedDayBinding)", "native paging container")
    require(today, ".tabViewStyle(.page(indexDisplayMode: .never))", "iOS-16-compatible page style")
    require(today, "ForEach(pagingDays, id: \\.self)", "stable day pages")
    require(today, "return (-1...45).compactMap", "connected provider planning horizon")
    require(provider, "value: -1, to: now", "provider yesterday horizon")
    require(provider, "value: 45, to: now", "provider future horizon")

    require(today, "if Calendar.current.isDateInToday(date) { return \"Today\" }", "Today page label")
    require(today, "if Calendar.current.isDateInTomorrow(date) { return \"Tomorrow\" }", "Tomorrow page label")
    require(today, ".accessibilityLabel(dayPageAccessibilityLabel", "VoiceOver day label")
    require(today, '.accessibilityValue(isSelected ? "Selected page" : "")', "VoiceOver selected-page state")
    require(today, '.accessibilityHint("Swipe left or right to browse one day at a time.")', "paging accessibility hint")

    require(today, 'DatePicker("Choose day", selection: selectedDayBinding', "date picker shared binding")
    require(today, "selectedDayEvents.count", "selected-day event statistic")
    require(today, 'label: "Events"', "event metric")
    require(today, "DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)", "route-planning selected day")
    require(today, "events: selectedDayEvents", "Live Day selected events")
    require(today, "day: selectedDay", "Live Activity selected-day context")

    # Do not silently switch to newer paging APIs that would raise the iOS deployment requirement.
    for token in [
        ".scrollTargetBehavior(",
        ".scrollPosition(",
        ".containerRelativeFrame(",
        "UIPageViewController",
    ]:
        forbid(today, token, "unguarded newer/custom paging dependency")

    # Root navigation remains the protected five-tab shell.
    for tab in ["Today", "Schedule", "Tools", "Resources", "Setup"]:
        require(content, f'"{tab}"', f"root tab {tab}")
    forbid(content, '"Routes"', "Routes root tab")

    print(
        "LifeRoute v0.7.0 swipe-day audit passed: CalendarCoreState remains the sole selected-day owner; Today uses native iOS-16 page-style browsing across the connected provider horizon; Today/Tomorrow/date VoiceOver labels and selected-page state are present; selected-day events flow into overview, route planning, and Live Day; and the protected five-tab shell remains intact."
    )


if __name__ == "__main__":
    main()
