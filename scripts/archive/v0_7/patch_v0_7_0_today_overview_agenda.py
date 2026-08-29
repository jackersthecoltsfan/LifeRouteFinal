#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TODAY = ROOT / "LifeRoute/V054TodayView.swift"


def main() -> None:
    text = TODAY.read_text(encoding="utf-8")
    marker = "v0.7.0 Today overview full-day agenda"
    if marker in text:
        return

    required = [
        "v0.7.0 Today hero preview-parity repair",
        "private var selectedDayEvents: [LifeRouteCalendarEvent]",
        "private var nextEvent: LifeRouteCalendarEvent?",
        "private var overviewMetricColumns: [GridItem]",
        "private func nextEventCountdownLabel",
        "private func nextEventCountdownValue",
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Today overview agenda patch failed: repaired Today baseline missing {missing}")

    start_token = "    private var overviewCard: some View {"
    end_token = "    private var gapSuggestions: some View {"
    try:
        start = text.index(start_token)
        end = text.index(end_token, start)
    except ValueError as exc:
        raise SystemExit("v0.7.0 Today overview agenda patch failed: overview boundaries missing") from exc

    replacement = r'''    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            LifeRouteSectionLabel(
                title: Calendar.current.isDateInToday(selectedDay) ? "Today’s Overview" : "Day Overview"
            )

            // v0.7.0 Today overview full-day agenda: show every appointment on the selected
            // calendar day instead of reducing the overview to only the next appointment.
            if selectedDayEvents.isEmpty {
                HStack(spacing: 10) {
                    LifeRouteIconBadge(systemImage: "checkmark.circle.fill", prominent: true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Calendar.current.isDateInToday(selectedDay) ? "No timed events today" : "No timed events on this day")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.textPrimary)
                        Text("Your selected day is clear.")
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 7) {
                        ForEach(selectedDayEvents) { event in
                            overviewEventCard(
                                event,
                                now: context.date,
                                isFocus: event.id == nextEvent?.id
                            )
                        }
                    }
                }
            }

            LazyVGrid(columns: overviewMetricColumns, spacing: 7) {
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
            }
        }
        .lifeRouteCard()
    }

    private func overviewEventCard(
        _ event: LifeRouteCalendarEvent,
        now: Date,
        isFocus: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isFocus ? "Next Event" : overviewEventLabel(event, now: now))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(palette.textSecondary)
                Text(event.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isFocus ? brandGold : palette.textPrimary)
                    .lineLimit(2)
                Text(event.isAllDay ? "All day" : "\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(palette.textPrimary.opacity(0.82))
                if !event.location.isEmpty {
                    Label(event.location, systemImage: "mappin")
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(isFocus ? nextEventCountdownLabel(event, now: now) : overviewEventStatusLabel(event, now: now))
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
                Text(isFocus ? nextEventCountdownValue(event, now: now) : overviewEventStatusValue(event, now: now))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(isFocus ? routeBlue : palette.textPrimary.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.panelElevated.opacity(isFocus ? 0.46 : 0.30))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isFocus ? brandGold.opacity(0.28) : Color.white.opacity(0.07), lineWidth: LifeRouteDesign.Stroke.subtle)
        }
        .accessibilityElement(children: .combine)
    }

    private func overviewEventLabel(_ event: LifeRouteCalendarEvent, now: Date) -> String {
        guard Calendar.current.isDateInToday(selectedDay) else { return "Scheduled" }
        if event.end <= now { return "Completed" }
        if event.start <= now { return "In Progress" }
        return "Later Today"
    }

    private func overviewEventStatusLabel(_ event: LifeRouteCalendarEvent, now: Date) -> String {
        if event.isAllDay { return "Time" }
        guard Calendar.current.isDateInToday(selectedDay) else { return "Starts" }
        if event.end <= now { return "Status" }
        if event.start <= now { return "Status" }
        return "Starts"
    }

    private func overviewEventStatusValue(_ event: LifeRouteCalendarEvent, now: Date) -> String {
        if event.isAllDay { return "All day" }
        guard Calendar.current.isDateInToday(selectedDay) else {
            return event.start.formatted(date: .omitted, time: .shortened)
        }
        if event.end <= now { return "Done" }
        if event.start <= now { return "Now" }
        return event.start.formatted(date: .omitted, time: .shortened)
    }

'''

    text = text[:start] + replacement + text[end:]
    TODAY.write_text(text, encoding="utf-8")
    print(
        "LifeRoute v0.7.0 Today overview full-day agenda applied: every appointment for CalendarCoreState.selectedDate now appears in the overview, the current/next event retains countdown emphasis, and the existing selected-day event/route metrics remain intact."
    )


if __name__ == "__main__":
    main()
