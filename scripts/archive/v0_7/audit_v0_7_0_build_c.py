#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

schedule = (ROOT / "LifeRoute/V054ScheduleView.swift").read_text(encoding="utf-8")
shell = (ROOT / "LifeRoute/V054ContentView.swift").read_text(encoding="utf-8")
prepare = (ROOT / "scripts/prepare_build.sh").read_text(encoding="utf-8")
patch = (ROOT / "scripts/patch_v0_7_0_build_c.py").read_text(encoding="utf-8")

checks = {
    "Build C marker is materialized": "v0.7.0 Build C Schedule" in schedule,
    "Schedule keeps CalendarCoreState ownership": "@ObservedObject var calendarState: CalendarCoreState" in schedule,
    "Schedule keeps provider ownership": "@ObservedObject var providerState: CalendarProviderCore" in schedule,
    "Schedule receives shared routing ownership": "@ObservedObject var routingState: RoutingLocationCore" in schedule,
    "Schedule has compact premium header": 'Text("Schedule")' in schedule and "scheduleHeader" in schedule,
    "Schedule retains native range state": "@State private var selectedRange: LifeRouteCalendarRange = .day" in schedule,
    "Schedule exposes Agenda Week Month segmented control": 'Picker("Range", selection: $selectedRange)' in schedule and "LifeRouteCalendarRange.allCases" in schedule and 'range == .day ? "Agenda" : range.rawValue' in schedule,
    "Schedule preserves previous period navigation": "calendarState.shiftSelection(selectedRange, by: -1)" in schedule,
    "Schedule preserves next period navigation": "calendarState.shiftSelection(selectedRange, by: 1)" in schedule,
    "Schedule has compact horizontal date strip": "private var compactDateStrip: some View" in schedule and "ScrollView(.horizontal, showsIndicators: false)" in schedule,
    "Schedule has native month grid": "private var monthGrid: some View" in schedule and "monthGridDates" in schedule and "LazyVGrid" in schedule,
    "Schedule allows direct date picking": 'DatePicker("Selected date", selection: $calendarState.selectedDate, displayedComponents: .date)' in schedule,
    "Schedule retains Today jump": 'Button("Today")' in schedule and "calendarState.selectToday()" in schedule,
    "Schedule has Today event-count divider": "selectedDayDivider" in schedule and 'return "Today"' in schedule,
    "Schedule has time-left timeline rows": "private func timelineEventRow" in schedule and ".frame(width: 62, alignment: .trailing)" in schedule,
    "Schedule preserves all-day rendering": 'event.isAllDay ? "ALL"' in schedule,
    "Schedule preserves event locations": 'Label(event.location, systemImage: "mappin.and.ellipse")' in schedule,
    "Schedule preserves manual delete flow": "calendarState.removeEvent(id: event.id)" in schedule and 'if event.source == .manual' in schedule,
    "Schedule preserves delete accessibility": '.accessibilityLabel("Delete \\(event.title)")' in schedule,
    "Schedule provides selected-day route planning": "DayRoutePlanningView(" in schedule and "day: calendarState.selectedDate" in schedule,
    "Schedule route planning uses shared routing state": "routingState: routingState" in schedule,
    "Schedule exposes travel-plan surface": 'Text("Travel plan")' in schedule and 'Text("PLAN ROUTE")' in schedule,
    "Schedule keeps manual appointment creation": "calendarState.addManualEvent(" in schedule and 'TextField("Appointment title", text: $title)' in schedule,
    "Schedule keeps native location autocomplete": 'V054AddressField("Appointment location", text: $location)' in schedule,
    "Schedule keeps all-day toggle": 'Toggle("All day", isOn: $allDay)' in schedule,
    "Schedule keeps Apple provider refresh": "providerState.connectOrRefreshApple" in schedule and "calendarState.replaceProviderEvents(events, source: .apple)" in schedule,
    "Schedule keeps Google provider refresh": "providerState.connectOrRefreshGoogle" in schedule and "calendarState.replaceProviderEvents(events, source: .google)" in schedule,
    "Schedule keeps Google disconnect": "providerState.disconnectGoogle()" in schedule and "calendarState.removeProviderEvents(source: .google)" in schedule,
    "Schedule describes provider read-only boundary": "connected calendars stay read-only in LifeRoute" in schedule,
    "Shell injects routing state into Schedule": "V054ScheduleView(\n                        calendarState: calendarState,\n                        providerState: providerState,\n                        routingState: routingState\n                    )" in shell,
    "Five-tab shell remains intact": shell.count("NavigationStack(path: $router.") == 5,
    "Schedule remains native-only": "WKWebView" not in schedule and "WebKit" not in schedule and "localStorage" not in schedule,
    "Build C patch stays scoped to Schedule plus dependency injection": 'SCHEDULE_PATH = ROOT / "LifeRoute/V054ScheduleView.swift"' in patch and 'SHELL_PATH = ROOT / "LifeRoute/V054ContentView.swift"' in patch,
    "Preparation materializes B.3 before C": prepare.find("python3 scripts/patch_v0_7_0_build_b3_compat.py") < prepare.find("python3 scripts/patch_v0_7_0_build_c.py") if "python3 scripts/patch_v0_7_0_build_c.py" in prepare else False,
    "Preparation runs Build C audit": "python3 scripts/audit_v0_7_0_build_c.py" in prepare,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    print("LifeRoute v0.7.0 Build C audit FAILED:")
    for name in failed:
        print(f"- {name}")
    raise SystemExit(1)

print(
    "LifeRoute v0.7.0 Build C audit passed: Schedule is a compact premium Agenda/Week/Month surface with native date navigation, timeline events, selected-day route handoff, modal provider/manual-event workflows, preserved domain ownership, five-tab routing, and no WebView regression."
)
