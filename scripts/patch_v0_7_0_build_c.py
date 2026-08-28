#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCHEDULE_PATH = ROOT / "LifeRoute/V054ScheduleView.swift"
SHELL_PATH = ROOT / "LifeRoute/V054ContentView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 Build C patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


SCHEDULE = r'''import SwiftUI

// v0.7.0 Build C Schedule: premium agenda/calendar surface; provider, manual-event,
// selected-day, and routing behaviors stay owned by their existing native domains.
struct V054ScheduleView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var calendarState: CalendarCoreState
    @ObservedObject var providerState: CalendarProviderCore
    @ObservedObject var routingState: RoutingLocationCore

    @State private var selectedRange: LifeRouteCalendarRange = .day
    @State private var showingDatePicker = false
    @State private var showingProviders = false
    @State private var showingAddAppointment = false

    @State private var title = ""
    @State private var eventDate = Date()
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(60 * 60)
    @State private var location = ""
    @State private var allDay = false
    @State private var message: String?

    private let gold = Color(red: 0.96, green: 0.72, blue: 0.20)
    private let routeBlue = Color(red: 0.30, green: 0.74, blue: 1.00)

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                scheduleHeader
                rangeControl

                if selectedRange == .month {
                    monthGrid
                } else {
                    compactDateStrip
                }

                selectedDayDivider

                if selectedRange == .week {
                    weekAgenda
                } else {
                    dayAgenda
                }

                travelCard
                calendarConnectionsBar
            }
            .padding(.horizontal, 12)
            .padding(.top, 7)
            .padding(.bottom, 30)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: selectedRange) { _ in LifeRouteHaptics.selection() }
        .sheet(isPresented: $showingDatePicker) { datePickerSheet }
        .sheet(isPresented: $showingProviders) { providerSheet }
        .sheet(isPresented: $showingAddAppointment) { appointmentSheet }
    }

    private var presentation: LifeRouteCalendarRangePresentation {
        calendarState.presentation(for: selectedRange)
    }

    private var selectedDayEvents: [LifeRouteCalendarEvent] {
        calendarState.events(on: calendarState.selectedDate).sorted { $0.start < $1.start }
    }

    private var selectedDayLocatedEvents: [LifeRouteCalendarEvent] {
        selectedDayEvents.filter { !$0.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var scheduleHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Schedule")
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text(calendarState.periodLabel(for: selectedRange))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            headerCircleButton(systemImage: "calendar") {
                showingDatePicker = true
                LifeRouteHaptics.selection()
            }
            .accessibilityLabel("Choose date")

            headerCircleButton(systemImage: "plus") {
                openAppointmentSheet()
            }
            .accessibilityLabel("Add appointment")
        }
        .padding(.horizontal, 3)
    }

    private var rangeControl: some View {
        HStack(spacing: 8) {
            Button {
                LifeRouteHaptics.selection()
                calendarState.shiftSelection(selectedRange, by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.black))
                    .frame(width: 38, height: 38)
                    .background(palette.panelElevated.opacity(0.44), in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.textPrimary)
            .accessibilityLabel("Previous period")

            Picker("Range", selection: $selectedRange) {
                ForEach(LifeRouteCalendarRange.allCases) { range in
                    Text(range == .day ? "Agenda" : range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            Button {
                LifeRouteHaptics.selection()
                calendarState.shiftSelection(selectedRange, by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.black))
                    .frame(width: 38, height: 38)
                    .background(palette.panelElevated.opacity(0.44), in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.textPrimary)
            .accessibilityLabel("Next period")
        }
    }

    private var compactDateStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(calendarState.weekDates(containing: calendarState.selectedDate), id: \.self) { date in
                    dateChip(date)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private func dateChip(_ date: Date) -> some View {
        let selected = Calendar.current.isDate(date, inSameDayAs: calendarState.selectedDate)
        let today = Calendar.current.isDateInToday(date)
        let count = calendarState.events(on: date).count

        return Button {
            calendarState.selectedDate = date
            LifeRouteHaptics.selection()
        } label: {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(selected ? Color.black.opacity(0.72) : palette.textSecondary)

                Text(date.formatted(.dateTime.day()))
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(selected ? Color.black.opacity(0.80) : palette.textPrimary)

                Circle()
                    .fill(count > 0 ? (selected ? Color.black.opacity(0.60) : routeBlue) : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 43, height: 60)
            .background(
                selected ? AnyShapeStyle(gold) : AnyShapeStyle(palette.panelElevated.opacity(today ? 0.56 : 0.34)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(today && !selected ? gold.opacity(0.45) : Color.white.opacity(0.05), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue("\(count) events")
    }

    private var monthGrid: some View {
        VStack(spacing: 7) {
            HStack(spacing: 4) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { label in
                    Text(label)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 5) {
                ForEach(Array(monthGridDates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        monthDay(date)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
        }
        .padding(10)
        .background(palette.panel.opacity(0.60), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    private var monthGridDates: [Date?] {
        let dates = calendarState.monthDates(containing: calendarState.selectedDate)
        guard let first = dates.first else { return [] }
        let weekday = Calendar.current.component(.weekday, from: first)
        let mondayOffset = (weekday + 5) % 7
        return Array(repeating: nil, count: mondayOffset) + dates.map(Optional.some)
    }

    private func monthDay(_ date: Date) -> some View {
        let selected = Calendar.current.isDate(date, inSameDayAs: calendarState.selectedDate)
        let today = Calendar.current.isDateInToday(date)
        let hasEvents = !calendarState.events(on: date).isEmpty

        return Button {
            calendarState.selectedDate = date
            LifeRouteHaptics.selection()
        } label: {
            ZStack(alignment: .bottom) {
                Text(date.formatted(.dateTime.day()))
                    .font(.caption.weight(selected ? .black : .semibold))
                    .foregroundStyle(selected ? Color.black.opacity(0.80) : palette.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Circle()
                    .fill(hasEvents ? (selected ? Color.black.opacity(0.55) : routeBlue) : .clear)
                    .frame(width: 4, height: 4)
                    .padding(.bottom, 3)
            }
            .frame(height: 38)
            .background(
                selected ? AnyShapeStyle(gold) : AnyShapeStyle(today ? gold.opacity(0.12) : Color.clear),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
    }

    private var selectedDayDivider: some View {
        HStack(spacing: 8) {
            Text(selectedDayLabel)
                .font(.caption.weight(.black))
                .tracking(0.6)
                .foregroundStyle(palette.textPrimary)

            Text("· \(selectedDayEvents.count) event\(selectedDayEvents.count == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.textSecondary)

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)
        }
        .padding(.top, 1)
    }

    private var selectedDayLabel: String {
        if Calendar.current.isDateInToday(calendarState.selectedDate) { return "Today" }
        return calendarState.selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    @ViewBuilder
    private var dayAgenda: some View {
        if selectedDayEvents.isEmpty {
            emptyAgendaCard
        } else {
            VStack(spacing: 8) {
                ForEach(selectedDayEvents) { event in
                    timelineEventRow(event)
                }
            }
        }
    }

    @ViewBuilder
    private var weekAgenda: some View {
        let days = presentation.days.filter { !$0.events.isEmpty }
        if days.isEmpty {
            emptyAgendaCard
        } else {
            VStack(spacing: 12) {
                ForEach(days) { day in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(.caption.weight(.black))
                            .foregroundStyle(Calendar.current.isDateInToday(day.date) ? gold : palette.textSecondary)

                        ForEach(day.events) { event in
                            timelineEventRow(event)
                        }
                    }
                }
            }
        }
    }

    private var emptyAgendaCard: some View {
        HStack(spacing: 11) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title3.weight(.bold))
                .foregroundStyle(routeBlue)
                .frame(width: 40, height: 40)
                .background(routeBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("No events scheduled")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Text("This day is open for routes, errands, or a new appointment.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer()
        }
        .padding(11)
        .background(palette.panel.opacity(0.60), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func timelineEventRow(_ event: LifeRouteCalendarEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(event.isAllDay ? "ALL" : event.start.formatted(date: .omitted, time: .shortened))
                    .font(.caption.weight(.black))
                    .foregroundStyle(event.isAllDay ? sourceAccent(event.source) : palette.textPrimary)
                    .lineLimit(1)
                if !event.isAllDay {
                    Text(event.end.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .frame(width: 62, alignment: .trailing)
            .padding(.top, 4)

            HStack(alignment: .top, spacing: 9) {
                Capsule()
                    .fill(sourceAccent(event.source))
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(2)

                    if !event.location.isEmpty {
                        Label(event.location, systemImage: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 5) {
                        Image(systemName: sourceIcon(event.source))
                        Text(sourceLabel(event.source))
                        if !event.calendarTitle.isEmpty {
                            Text("· \(event.calendarTitle)")
                                .lineLimit(1)
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(sourceAccent(event.source).opacity(0.92))
                }

                Spacer(minLength: 4)

                if event.source == .manual {
                    Button(role: .destructive) {
                        LifeRouteHaptics.selection()
                        calendarState.removeEvent(id: event.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.bold))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red.opacity(0.88))
                    .accessibilityLabel("Delete \(event.title)")
                }
            }
            .padding(10)
            .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(sourceAccent(event.source).opacity(0.14), lineWidth: 1)
            }
        }
    }

    private var travelCard: some View {
        NavigationLink {
            DayRoutePlanningView(
                calendarState: calendarState,
                routingState: routingState,
                day: calendarState.selectedDate
            )
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "car.side.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(gold)
                    .frame(width: 42, height: 42)
                    .background(gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Travel plan")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        if !knownDrivingSummary.isEmpty {
                            Text(knownDrivingSummary)
                                .font(.caption2.weight(.black))
                                .foregroundStyle(routeBlue)
                        }
                    }

                    Text(travelDetail)
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 5)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("PLAN ROUTE")
                        .font(.caption2.weight(.black))
                        .tracking(0.7)
                        .foregroundStyle(gold)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.black))
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .padding(11)
            .background(palette.panel.opacity(0.64), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(gold.opacity(0.17), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })
    }

    private var travelDetail: String {
        let count = selectedDayLocatedEvents.count
        if count == 0 {
            return "Add locations to appointments to build the selected day’s route."
        }
        return "\(count) located appointment\(count == 1 ? "" : "s") ready for appointment-to-appointment routing."
    }

    private var knownDrivingSummary: String {
        let seconds = routingState.routeEstimates.values
            .filter { $0.mode == .driving }
            .reduce(0.0) { $0 + $1.travelTimeSeconds }
        guard seconds > 0 else { return "" }
        let minutes = max(1, Int((seconds / 60).rounded()))
        return "· \(minutes)m known"
    }

    private var calendarConnectionsBar: some View {
        Button {
            showingProviders = true
            LifeRouteHaptics.selection()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(routeBlue)
                Text("Connected calendars")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text(connectionSummary)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(.horizontal, 11)
            .frame(minHeight: 44)
            .background(palette.panel.opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var connectionSummary: String {
        let count = (providerState.appleConnected ? 1 : 0) + (providerState.googleConnected ? 1 : 0)
        return count == 0 ? "Manage" : "\(count) active"
    }

    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                DatePicker("Selected date", selection: $calendarState.selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(gold)

                Button("Today") {
                    calendarState.selectToday()
                    LifeRouteHaptics.selection()
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
            }
            .padding(16)
            .navigationTitle("Choose Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingDatePicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var providerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your connected calendars stay read-only in LifeRoute. Manual LifeRoute appointments remain editable and removable here.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)

                    providerRow(
                        title: "Apple Calendar",
                        status: providerState.appleStatus,
                        connected: providerState.appleConnected,
                        busy: providerState.appleBusy,
                        systemImage: "apple.logo"
                    ) {
                        providerState.connectOrRefreshApple { events in
                            calendarState.replaceProviderEvents(events, source: .apple)
                            LifeRouteHaptics.success()
                        }
                    }

                    providerRow(
                        title: "Google Calendar",
                        status: providerState.googleStatus,
                        connected: providerState.googleConnected,
                        busy: providerState.googleBusy,
                        systemImage: "g.circle.fill"
                    ) {
                        providerState.connectOrRefreshGoogle { events in
                            calendarState.replaceProviderEvents(events, source: .google)
                            LifeRouteHaptics.success()
                        }
                    }

                    if providerState.googleConnected {
                        Button(role: .destructive) {
                            LifeRouteHaptics.selection()
                            providerState.disconnectGoogle()
                            calendarState.removeProviderEvents(source: .google)
                        } label: {
                            Label("Disconnect Google Calendar", systemImage: "link.badge.minus")
                        }
                        .font(.caption.weight(.bold))
                        .padding(.top, 3)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingProviders = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func providerRow(
        title: String,
        status: String,
        connected: Bool,
        busy: Bool,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(connected ? gold : palette.textSecondary)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer()

            Button(busy ? "Working…" : (connected ? "Refresh" : "Connect")) {
                LifeRouteHaptics.primaryAction()
                action()
            }
            .font(.caption.weight(.bold))
            .disabled(busy)
        }
        .padding(11)
        .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var appointmentSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Appointment title", text: $title)
                        .padding(12)
                        .background(fieldBackground, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    DatePicker("Date", selection: $eventDate, displayedComponents: .date)
                    Toggle("All day", isOn: $allDay)

                    if !allDay {
                        DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                    }

                    V054AddressField("Appointment location", text: $location)

                    Button {
                        saveAppointment()
                    } label: {
                        Label("Save appointment", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(LifeRoutePrimaryButtonStyle())

                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Add Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddAppointment = false }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var fieldBackground: Color {
        palette.panelElevated.opacity(0.30)
    }

    private func openAppointmentSheet() {
        eventDate = calendarState.selectedDate
        message = nil
        showingAddAppointment = true
        LifeRouteHaptics.primaryAction()
    }

    private func saveAppointment() {
        do {
            try calendarState.addManualEvent(
                title: title,
                date: eventDate,
                startTime: startTime,
                endTime: endTime,
                location: location,
                isAllDay: allDay
            )
            title = ""
            location = ""
            message = "Appointment saved."
            showingAddAppointment = false
            LifeRouteHaptics.success()
        } catch {
            message = error.localizedDescription
        }
    }

    private func headerCircleButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.black))
                .foregroundStyle(gold)
                .frame(width: 42, height: 42)
                .background(palette.panelElevated.opacity(0.46), in: Circle())
                .overlay { Circle().stroke(gold.opacity(0.20), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private func sourceAccent(_ source: LifeRouteCalendarSource) -> Color {
        switch source {
        case .manual: return gold
        case .apple: return routeBlue
        case .google: return .red
        case .calendarLink: return .purple
        }
    }

    private func sourceIcon(_ source: LifeRouteCalendarSource) -> String {
        switch source {
        case .manual: return "calendar.badge.plus"
        case .apple: return "apple.logo"
        case .google: return "g.circle.fill"
        case .calendarLink: return "link"
        }
    }

    private func sourceLabel(_ source: LifeRouteCalendarSource) -> String {
        switch source {
        case .manual: return "LifeRoute"
        case .apple: return "Apple"
        case .google: return "Google"
        case .calendarLink: return "Calendar Link"
        }
    }
}
'''


def patch_schedule() -> None:
    text = SCHEDULE_PATH.read_text(encoding="utf-8")
    if "v0.7.0 Build C Schedule" in text:
        return
    required = [
        "struct V054ScheduleView: View",
        "@ObservedObject var calendarState: CalendarCoreState",
        "@ObservedObject var providerState: CalendarProviderCore",
        'V054AddressField("Appointment location"',
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Build C patch failed: Schedule baseline missing {missing}")
    SCHEDULE_PATH.write_text(SCHEDULE, encoding="utf-8")


def patch_shell() -> None:
    text = SHELL_PATH.read_text(encoding="utf-8")
    if "V054ScheduleView(\n                        calendarState: calendarState,\n                        providerState: providerState,\n                        routingState: routingState\n                    )" in text:
        return

    old = '''                    V054ScheduleView(
                        calendarState: calendarState,
                        providerState: providerState
                    )'''
    new = '''                    V054ScheduleView(
                        calendarState: calendarState,
                        providerState: providerState,
                        routingState: routingState
                    )'''
    text = replace_once(text, old, new, "Schedule routing-state injection")
    SHELL_PATH.write_text(text, encoding="utf-8")


def main() -> None:
    patch_schedule()
    patch_shell()
    print(
        "LifeRoute v0.7.0 Build C patch applied: Schedule is rebuilt as a compact Agenda/Week/Month timeline with native date browsing, month grid, travel-plan handoff, compact calendar connections, and modal appointment/provider workflows while preserving existing domain ownership."
    )


if __name__ == "__main__":
    main()
