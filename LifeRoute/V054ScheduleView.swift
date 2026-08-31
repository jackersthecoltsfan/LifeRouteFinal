import SwiftUI

// v0.7.0 Build C Schedule: premium agenda/calendar surface; provider, manual-event,
// v0.7.0 Build C compile hotfix: explicit shape fills and deployment-target-safe date strip.
// selected-day, and routing behaviors stay owned by their existing native domains.
struct V054ScheduleView: View {
    @Environment(\.scenicRoyalThemeStyle) private var scenicStyle
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
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
            .padding(.horizontal, ScenicRoyalDesignSystem.Layout.pageHorizontal)
            .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
            .padding(.bottom, ScenicRoyalDesignSystem.Spacing.spacious * 2)
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
        ScenicRoyalScreenHeader(
            title: "Schedule",
            subtitle: calendarState.periodLabel(for: selectedRange)
        ) {
            ScenicRoyalCompactIconButton(
                systemImage: "calendar",
                accessibilityLabel: "Choose date"
            ) {
                showingDatePicker = true
                LifeRouteHaptics.selection()
            }

            ScenicRoyalCompactIconButton(
                systemImage: "plus",
                accessibilityLabel: "Add appointment"
            ) {
                openAppointmentSheet()
            }
        }
    }

    private var rangeControl: some View {
        ScenicRoyalGlassEffectContainer(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                ScenicRoyalCompactIconButton(
                    systemImage: "chevron.left",
                    accessibilityLabel: "Previous period"
                ) {
                    LifeRouteHaptics.selection()
                    calendarState.shiftSelection(selectedRange, by: -1)
                }

                if dynamicTypeSize.isAccessibilitySize {
                    Menu {
                        ForEach(LifeRouteCalendarRange.allCases) { range in
                            Button {
                                selectedRange = range
                            } label: {
                                if selectedRange == range {
                                    Label(rangeTitle(range), systemImage: "checkmark")
                                } else {
                                    Text(rangeTitle(range))
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(rangeTitle(selectedRange))
                                .font(.headline.weight(.semibold))
                            Spacer(minLength: ScenicRoyalDesignSystem.Spacing.compact)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.bold))
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(scenicStyle.primaryText)
                        .frame(maxWidth: .infinity, minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
                        .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.standard)
                        .contentShape(RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.control, style: .continuous))
                        .scenicRoyalInteractiveSurface(
                            role: .ambient,
                            cornerRadius: ScenicRoyalDesignSystem.Radius.control
                        )
                    }
                    .accessibilityLabel("Calendar range")
                    .accessibilityValue(rangeTitle(selectedRange))
                } else {
                    Picker("Range", selection: $selectedRange) {
                        ForEach(LifeRouteCalendarRange.allCases) { range in
                            Text(rangeTitle(range)).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(3)
                    .scenicRoyalSurface(
                        role: .ambient,
                        cornerRadius: ScenicRoyalDesignSystem.Radius.control
                    )
                }

                ScenicRoyalCompactIconButton(
                    systemImage: "chevron.right",
                    accessibilityLabel: "Next period"
                ) {
                    LifeRouteHaptics.selection()
                    calendarState.shiftSelection(selectedRange, by: 1)
                }
            }
        }
    }

    private var compactDateStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                ScenicRoyalGlassEffectContainer(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                    HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                        ForEach(calendarState.weekDates(containing: calendarState.selectedDate), id: \.self) { date in
                            dateChip(date)
                                .id(Calendar.current.startOfDay(for: date))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .onAppear { centerSelectedDate(in: proxy) }
            .onChange(of: calendarState.selectedDate) { _ in centerSelectedDate(in: proxy) }
        }
        // Deployment-target-safe: horizontal date browsing remains clipped by the ScrollView.
    }

    private func dateChip(_ date: Date) -> some View {
        let selected = Calendar.current.isDate(date, inSameDayAs: calendarState.selectedDate)
        let today = Calendar.current.isDateInToday(date)
        let count = calendarState.events(on: date).count

        return ScenicRoyalCalendarDateChip(
            date: date,
            eventCount: count,
            isSelected: selected,
            isToday: today
        ) {
            calendarState.selectedDate = date
            LifeRouteHaptics.selection()
        }
    }

    private var monthGrid: some View {
        VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            HStack(spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { label in
                    Text(label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(scenicStyle.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: ScenicRoyalDesignSystem.Spacing.hairline), count: 7),
                spacing: ScenicRoyalDesignSystem.Spacing.hairline
            ) {
                ForEach(Array(monthGridDates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        monthDay(date)
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
        .scenicRoyalCard(role: .readability, padding: ScenicRoyalDesignSystem.Spacing.standard)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
        let count = calendarState.events(on: date).count

        return ScenicRoyalCalendarMonthDay(
            date: date,
            eventCount: count,
            isSelected: selected,
            isToday: today
        ) {
            calendarState.selectedDate = date
            LifeRouteHaptics.selection()
        }
    }

    private var selectedDayDivider: some View {
        HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            Text(selectedDayLabel)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(scenicStyle.primaryText)

            Text("\(selectedDayEvents.count) event\(selectedDayEvents.count == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(scenicStyle.secondaryText)

            Rectangle()
                .fill(scenicStyle.accent.opacity(0.34))
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
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
            ScenicRoyalGlassEffectContainer(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                    ForEach(selectedDayEvents) { event in
                        timelineEventRow(event)
                    }
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
            ScenicRoyalGlassEffectContainer(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                VStack(spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
                    ForEach(days) { day in
                        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                            Text(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(
                                    Calendar.current.isDateInToday(day.date)
                                        ? scenicStyle.accent
                                        : scenicStyle.secondaryText
                                )

                            ForEach(day.events) { event in
                                timelineEventRow(event)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyAgendaCard: some View {
        HStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            ScenicRoyalIconBadge(systemImage: "calendar.badge.checkmark")

            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                Text("No events scheduled")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(scenicStyle.primaryText)
                Text("This day is open for routes, errands, or a new appointment.")
                    .font(.subheadline)
                    .foregroundStyle(scenicStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .scenicRoyalCard(role: .readability)
        .accessibilityElement(children: .combine)
    }

    private func timelineEventRow(_ event: LifeRouteCalendarEvent) -> some View {
        ScenicRoyalScheduleEventRow(
            event: event,
            sourceLabel: sourceLabel(event.source),
            sourceIcon: sourceIcon(event.source),
            sourceAccent: sourceAccent(event.source),
            onDelete: event.source == .manual ? {
                LifeRouteHaptics.selection()
                calendarState.removeEvent(id: event.id)
            } : nil
        )
    }

    private var travelCard: some View {
        NavigationLink {
            DayRoutePlanningView(
                calendarState: calendarState,
                routingState: routingState,
                day: calendarState.selectedDate
            )
        } label: {
            ScenicRoyalTravelPlanLabel(
                detail: travelDetail,
                summary: knownDrivingSummary
            )
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
            ScenicRoyalCalendarConnectionLabel(summary: connectionSummary)
        }
        .buttonStyle(.plain)
    }

    private var connectionSummary: String {
        let count = (providerState.appleConnected ? 1 : 0) + (providerState.googleConnected ? 1 : 0)
        return count == 0 ? "Manage" : "\(count) active"
    }

    private func rangeTitle(_ range: LifeRouteCalendarRange) -> String {
        range == .day ? "Agenda" : range.rawValue
    }

    private func centerSelectedDate(in proxy: ScrollViewProxy) {
        let selectedDay = Calendar.current.startOfDay(for: calendarState.selectedDate)
        if reduceMotion {
            proxy.scrollTo(selectedDay, anchor: .center)
        } else {
            withAnimation(ScenicRoyalDesignSystem.Motion.selection) {
                proxy.scrollTo(selectedDay, anchor: .center)
            }
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                DatePicker("Selected date", selection: $calendarState.selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(scenicStyle.accent)

                Button("Today") {
                    calendarState.selectToday()
                    LifeRouteHaptics.selection()
                }
                .buttonStyle(ScenicRoyalSecondaryButtonStyle())
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
                        .font(.subheadline)
                        .foregroundStyle(scenicStyle.secondaryText)
                        .scenicRoyalCard(role: .readability)

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
        ScenicRoyalInsetRow(role: .readability) {
            HStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(connected ? scenicStyle.accent : scenicStyle.secondaryText)
                    .frame(width: 34)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(scenicStyle.primaryText)
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(scenicStyle.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)

                Spacer(minLength: ScenicRoyalDesignSystem.Spacing.compact)

                Button(busy ? "Working…" : (connected ? "Refresh" : "Connect")) {
                    LifeRouteHaptics.primaryAction()
                    action()
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(scenicStyle.primaryText)
                .frame(minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
                .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.compact)
                .contentShape(Capsule())
                .scenicRoyalInteractiveSurface(
                    role: .selectedControl,
                    cornerRadius: ScenicRoyalDesignSystem.Layout.minimumTouchTarget / 2
                )
                .disabled(busy)
                .accessibilityHint(connected ? "Refreshes read-only calendar events" : "Connects read-only calendar access")
            }
        }
    }

    private var appointmentSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Appointment title", text: $title)
                        .scenicRoyalField()

                    VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        DatePicker("Date", selection: $eventDate, displayedComponents: .date)
                        Toggle("All day", isOn: $allDay)

                        if !allDay {
                            DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                            DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                        }
                    }
                    .scenicRoyalCard(role: .readability)

                    V054AddressField("Appointment location", text: $location)

                    Button {
                        saveAppointment()
                    } label: {
                        Label("Save appointment", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(ScenicRoyalPrimaryButtonStyle())

                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(scenicStyle.secondaryText)
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

    private func sourceAccent(_ source: LifeRouteCalendarSource) -> Color {
        switch source {
        case .manual: return scenicStyle.accent
        case .apple: return .blue
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
