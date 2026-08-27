import SwiftUI

struct V054ScheduleView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var calendarState: CalendarCoreState
    @ObservedObject var providerState: CalendarProviderCore

    @State private var selectedRange: LifeRouteCalendarRange = .day
    @State private var title = ""
    @State private var eventDate = Date()
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(60 * 60)
    @State private var location = ""
    @State private var allDay = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                hero
                rangeCard
                calendarCard
                providersCard
                addAppointmentCard
            }
            .padding(18)
            .padding(.bottom, 28)
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var presentation: LifeRouteCalendarRangePresentation {
        calendarState.presentation(for: selectedRange)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("SCHEDULE", systemImage: "calendar.badge.checkmark")
                .font(.caption.weight(.black))
                .tracking(1.4)
                .foregroundStyle(palette.accent)
            Text(calendarState.periodLabel(for: selectedRange))
                .font(.system(size: 29, weight: .black, design: .rounded))
                .foregroundStyle(palette.textPrimary)
            Text("One view for manual appointments plus your read-only Apple and Google calendars.")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
        }
        .lifeRouteCard()
    }

    private var rangeCard: some View {
        VStack(spacing: 12) {
            Picker("Range", selection: $selectedRange) {
                ForEach(LifeRouteCalendarRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 9) {
                Button {
                    calendarState.shiftSelection(selectedRange, by: -1)
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())

                Button("Today") { calendarState.selectToday() }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())

                Button {
                    calendarState.shiftSelection(selectedRange, by: 1)
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
            }
        }
        .lifeRouteCard()
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(presentation.eventCount) events")
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(presentation.timedMinutes) scheduled min")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accentSecondary)
            }

            if presentation.visibleEvents.isEmpty {
                ContentUnavailableView(
                    "No events here",
                    systemImage: "calendar",
                    description: Text("Refresh a connected calendar or add an appointment below.")
                )
            } else {
                ForEach(presentation.days) { day in
                    if !day.events.isEmpty || selectedRange != .month {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                .font(.caption.weight(.black))
                                .tracking(0.7)
                                .foregroundStyle(palette.accent)

                            ForEach(day.events) { event in
                                eventRow(event)
                            }
                        }
                    }
                }
            }
        }
        .lifeRouteCard()
    }

    private func eventRow(_ event: LifeRouteCalendarEvent) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(sourceAccent(event.source).opacity(0.14))
                Image(systemName: sourceIcon(event.source))
                    .foregroundStyle(sourceAccent(event.source))
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Text(event.isAllDay ? "All day" : "\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                if !event.location.isEmpty {
                    Label(event.location, systemImage: "mappin.and.ellipse")
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 4)

            if event.source == .manual {
                Button(role: .destructive) {
                    calendarState.removeEvent(id: event.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(event.title)")
            }
        }
        .padding(11)
        .background(
            palette.panelElevated.opacity(0.30),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
    }

    private var providersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Connected calendars", systemImage: "arrow.triangle.2.circlepath")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)

            providerRow(
                title: "Apple Calendar",
                status: providerState.appleStatus,
                connected: providerState.appleConnected,
                busy: providerState.appleBusy,
                systemImage: "apple.logo"
            ) {
                providerState.connectOrRefreshApple { events in
                    calendarState.replaceProviderEvents(events, source: .apple)
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
                }
            }

            if providerState.googleConnected {
                Button(role: .destructive) {
                    providerState.disconnectGoogle()
                    calendarState.removeProviderEvents(source: .google)
                } label: {
                    Label("Disconnect Google Calendar", systemImage: "link.badge.minus")
                }
                .font(.caption.weight(.bold))
            }

            Text("Imported calendars are read-only in LifeRoute. Manual LifeRoute appointments remain editable here.")
                .font(.caption2)
                .foregroundStyle(palette.textSecondary)
        }
        .lifeRouteCard()
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
                .foregroundStyle(connected ? palette.accent : palette.textSecondary)
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
            Button(busy ? "Working…" : (connected ? "Refresh" : "Connect"), action: action)
                .font(.caption.weight(.bold))
                .disabled(busy)
        }
        .padding(11)
        .background(palette.panelElevated.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var addAppointmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Add appointment", systemImage: "calendar.badge.plus")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)

            TextField("Appointment title", text: $title)
                .padding(12)
                .background(fieldBackground)

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
        .lifeRouteCard()
    }

    private var fieldBackground: some ShapeStyle {
        palette.panelElevated.opacity(0.30)
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
            LifeRouteHaptics.success()
        } catch {
            message = error.localizedDescription
        }
    }

    private func sourceAccent(_ source: LifeRouteCalendarSource) -> Color {
        switch source {
        case .manual: return palette.accent
        case .apple: return .cyan
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
}
