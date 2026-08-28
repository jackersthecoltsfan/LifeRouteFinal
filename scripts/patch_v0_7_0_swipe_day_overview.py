#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TODAY = ROOT / "LifeRoute/V054TodayView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 swipe-day patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    text = TODAY.read_text(encoding="utf-8")
    if "v0.7.0 swipeable day overview" in text:
        return

    required = [
        "v0.7.0 Build B.3 device QA",
        "v0.7.0 restored To-Do gap fillers",
        "private var selectedDayContext: some View",
        "private var dayPickerSheet: some View",
        "private var daySelector: some View",
        "DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)",
        "@State private var selectedDay = Calendar.current.startOfDay(for: Date())",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 swipe-day patch failed: post-B.3 Today baseline missing {missing}")

    text = replace_once(
        text,
        "// v0.7.0 Build B.3 device QA: cinematic hero and one-screen information hierarchy tuned from real-device screenshots.\n",
        "// v0.7.0 Build B.3 device QA: cinematic hero and one-screen information hierarchy tuned from real-device screenshots.\n"
        "// v0.7.0 swipeable day overview: shared CalendarCoreState selection drives native iOS-16 paging.\n",
        "feature marker",
    )

    text = replace_once(
        text,
        "    @State private var selectedDay = Calendar.current.startOfDay(for: Date())\n",
        "    // CalendarCoreState.selectedDate is the sole selected-day owner shared with Schedule.\n"
        "    private var selectedDay: Date {\n"
        "        get { Calendar.current.startOfDay(for: calendarState.selectedDate) }\n"
        "        nonmutating set {\n"
        "            calendarState.selectedDate = Calendar.current.startOfDay(for: newValue)\n"
        "        }\n"
        "    }\n\n"
        "    private var selectedDayBinding: Binding<Date> {\n"
        "        Binding(\n"
        "            get: { selectedDay },\n"
        "            set: { selectedDay = $0 }\n"
        "        )\n"
        "    }\n\n"
        "    // Apple and Google provider refreshes currently materialize yesterday through +45 days.\n"
        "    private var pagingDays: [Date] {\n"
        "        let calendar = Calendar.current\n"
        "        let today = calendar.startOfDay(for: Date())\n"
        "        return (-1...45).compactMap { offset in\n"
        "            calendar.date(byAdding: .day, value: offset, to: today).map(calendar.startOfDay(for:))\n"
        "        }\n"
        "    }\n",
        "shared selected-day owner",
    )

    text = replace_once(
        text,
        "                hero\n                if !Calendar.current.isDateInToday(selectedDay) {\n                    selectedDayContext\n                }\n                quickActions\n",
        "                hero\n                dayOverviewPager\n                quickActions\n",
        "top day pager placement",
    )

    text = replace_once(
        text,
        'DatePicker("Choose day", selection: $selectedDay, displayedComponents: .date)',
        'DatePicker("Choose day", selection: selectedDayBinding, displayedComponents: .date)',
        "DatePicker shared binding",
    )

    quick_columns = '''    private var quickActionColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 4
        return Array(
            repeating: GridItem(.flexible(minimum: 64), spacing: 8, alignment: .top),
            count: count
        )
    }
'''
    metric_columns = quick_columns + '''
    private var overviewMetricColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 3
        return Array(
            repeating: GridItem(.flexible(minimum: 72), spacing: 7, alignment: .top),
            count: count
        )
    }
'''
    text = replace_once(text, quick_columns, metric_columns, "overview metric columns")

    pager = r'''    @ViewBuilder
    private var dayOverviewPager: some View {
        if pagingDays.contains(selectedDay) {
            TabView(selection: selectedDayBinding) {
                ForEach(pagingDays, id: \.self) { date in
                    dayOverviewPage(date)
                        .tag(date)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 128 : 94)
            .accessibilityHint("Swipe left or right to browse one day at a time.")
        } else {
            // Schedule can intentionally select dates beyond the connected-provider horizon.
            // Keep that shared selection truthful instead of snapping Today to an unrelated page.
            selectedDayContext
        }
    }

    private func dayOverviewPage(_ date: Date) -> some View {
        let events = calendarState.events(on: date).sorted { $0.start < $1.start }
        let event = pageSummaryEvent(on: date, events: events)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDay)

        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(dayPageTitle(date))
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(palette.textPrimary)
                    Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(palette.textSecondary)
                }

                Spacer(minLength: 8)

                Text("\(events.count) event\(events.count == 1 ? "" : "s")")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(brandGold)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 28)
                    .background(brandGold.opacity(0.10), in: Capsule())
            }

            HStack(spacing: 7) {
                Image(systemName: event == nil ? "checkmark.circle.fill" : "clock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(event == nil ? routeBlue : brandGold)
                    .accessibilityHidden(true)

                if let event {
                    Text(event.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(pageEventTime(event, on: date))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("Clear day")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.textSecondary)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? brandGold.opacity(0.30) : Color.white.opacity(0.06), lineWidth: LifeRouteDesign.Stroke.subtle)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayPageAccessibilityLabel(date, eventCount: events.count, event: event))
        .accessibilityValue(isSelected ? "Selected page" : "")
    }

    private func pageSummaryEvent(on date: Date, events: [LifeRouteCalendarEvent]) -> LifeRouteCalendarEvent? {
        if Calendar.current.isDateInToday(date) {
            return events.first { $0.end > Date() }
        }
        return events.first
    }

    private func dayPageTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    private func pageEventTime(_ event: LifeRouteCalendarEvent, on date: Date) -> String {
        if event.isAllDay { return "All day" }
        if Calendar.current.isDateInToday(date), event.start <= Date(), event.end > Date() {
            return "Now"
        }
        return event.start.formatted(date: .omitted, time: .shortened)
    }

    private func dayPageAccessibilityLabel(
        _ date: Date,
        eventCount: Int,
        event: LifeRouteCalendarEvent?
    ) -> String {
        let dateLabel: String
        if Calendar.current.isDateInToday(date) {
            dateLabel = "Today"
        } else if Calendar.current.isDateInTomorrow(date) {
            dateLabel = "Tomorrow"
        } else {
            dateLabel = date.formatted(date: .complete, time: .omitted)
        }

        if let event {
            return "\(dateLabel), \(eventCount) events, next event \(event.title), \(pageEventTime(event, on: date))"
        }
        return "\(dateLabel), no events, clear day"
    }

'''
    text = replace_once(
        text,
        "    private var quickActions: some View {\n",
        pager + "    private var quickActions: some View {\n",
        "day pager helpers",
    )

    old_metrics = r'''            HStack(spacing: 10) {
                overviewMetric(
                    value: "\(drivingEstimates.count)",
                    label: "Total Drives",
                    detail: Calendar.current.isDateInToday(selectedDay) ? "Today" : "Calculated",
                    systemImage: "car.fill",
                    accent: brandGold
                )
                overviewMetric(
                    value: totalDrivingDurationLabel,
                    label: "Est. Driving",
                    detail: "Total",
                    systemImage: "clock.fill",
                    accent: routeBlue
                )
            }'''
    new_metrics = r'''            LazyVGrid(columns: overviewMetricColumns, spacing: 7) {
                overviewMetric(
                    value: "\(selectedDayEvents.count)",
                    label: "Events",
                    detail: dayPageTitle(selectedDay),
                    systemImage: "calendar",
                    accent: schedulePurple
                )
                overviewMetric(
                    value: "\(drivingEstimates.count)",
                    label: "Total Drives",
                    detail: "Current route data",
                    systemImage: "car.fill",
                    accent: brandGold
                )
                overviewMetric(
                    value: totalDrivingDurationLabel,
                    label: "Est. Driving",
                    detail: "Current route data",
                    systemImage: "clock.fill",
                    accent: routeBlue
                )
            }'''
    text = replace_once(text, old_metrics, new_metrics, "selected-day event metric")

    TODAY.write_text(text, encoding="utf-8")
    print(
        "LifeRoute v0.7.0 swipeable day overview applied: Today uses CalendarCoreState.selectedDate as the shared day owner, native iOS-16 page-style browsing covers the connected calendar horizon, selected-day events flow through existing Today/route/Live Day surfaces, and route estimate ownership remains unchanged."
    )


if __name__ == "__main__":
    main()
