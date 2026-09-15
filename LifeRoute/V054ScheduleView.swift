import SwiftUI

// v0.7.0 Build C Schedule: premium agenda/calendar surface; provider, manual-event,
// v0.7.0 Build C compile hotfix: explicit shape fills and deployment-target-safe date strip.
// selected-day, and routing behaviors stay owned by their existing native domains.
struct V054ScheduleView: View {
    @LifeRoutePresentation private var visibility
    @State private var lastCenteredDate: Date?
    private enum PresentedCalendarSheet: Identifiable {
        case addAppointment
        case editAppointment(LifeRouteCalendarEvent)
        case providerDetails(LifeRouteCalendarEvent)

        var id: String {
            switch self {
            case .addAppointment:
                return "add-appointment"
            case .editAppointment(let event):
                return "edit-\(event.id)"
            case .providerDetails(let event):
                return "details-\(event.source.rawValue)-\(event.id)"
            }
        }
    }

    @Environment(\.scenicRoyalThemeStyle) private var scenicStyle
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var router: AppRouter
    @ObservedObject var calendarState: CalendarCoreState
    @ObservedObject var providerState: CalendarProviderCore

    @State private var selectedRange: LifeRouteCalendarRange = .day
    @State private var showingDatePicker = false
    @State private var showingProviders = false
    @State private var presentedCalendarSheet: PresentedCalendarSheet?
    @State private var eventPendingRowDeletion: LifeRouteCalendarEvent?
    @State private var showingEditDeleteConfirmation = false

    @State private var title = ""
    @State private var eventDate = Date()
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(60 * 60)
    @State private var location = ""
    @State private var allDay = false
    @State private var message: String?

    var body: some View {
        GeometryReader { geometry in
        // Use the actual retained root viewport; its relayed size class can
        // remain regular during rotation even after its bounds become wide.
        let compactLandscape = geometry.size.width > geometry.size.height && !dynamicTypeSize.isAccessibilitySize
        ScrollView {
            LazyVStack(spacing: compactLandscape ? ScenicRoyalDesignSystem.Spacing.compact : ScenicRoyalDesignSystem.Spacing.standard) {
                if compactLandscape {
                    HStack(spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
                        compactScheduleHeader
                            .frame(maxWidth: 310)
                        rangeControl
                    }
                } else {
                    scheduleHeader
                    rangeControl
                }

                if selectedRange == .month {
                    monthGrid(compact: compactLandscape)
                } else {
                    compactDateStrip(compact: compactLandscape)
                }

                if selectedRange != .week { selectedDayDivider }

                TimelineView(LifeRoutePresentationClock(interval: 60, active: visibility.active)) { context in
                    if selectedRange == .week {
                        weekAgenda(now: context.date)
                    } else {
                        dayAgenda(now: context.date)
                    }
                }

                travelCard
                calendarConnectionsBar
            }
            .padding(.horizontal, ScenicRoyalDesignSystem.Layout.pageHorizontal)
            .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
            .padding(.bottom, ScenicRoyalDesignSystem.Spacing.spacious * 2)
        }
        .accessibilityIdentifier("calendar.scroll")
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: selectedRange) { _ in if visibility.active { LifeRouteHaptics.selection() } }
        .sheet(isPresented: $showingDatePicker) { datePickerSheet.lifeRouteModalScope() }
        .sheet(isPresented: $showingProviders) { LifeRouteModalContent { scope in providerSheet(scope: scope) } }
        .sheet(item: $presentedCalendarSheet) { sheet in
            switch sheet {
            case .addAppointment, .editAppointment:
                appointmentSheet(sheet).lifeRouteModalScope()
            case .providerDetails(let event):
                providerEventDetailsSheet(event).lifeRouteModalScope()
            }
        }
        .lifeRouteSystemModal(isPresented: eventPendingRowDeletion != nil)
        .confirmationDialog(
            "Delete this appointment?",
            isPresented: Binding(
                get: { eventPendingRowDeletion != nil },
                set: { if !$0 { eventPendingRowDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete appointment", role: .destructive) {
                guard let event = eventPendingRowDeletion else { return }
                deleteManualEvent(event)
                eventPendingRowDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                eventPendingRowDeletion = nil
            }
        } message: {
            Text("Only this LifeRoute appointment will be removed.")
        }
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

    private var scheduleHeader: some View { calendarHeader(compact: false) }
    private var compactScheduleHeader: some View { calendarHeader(compact: true) }

    private func calendarHeader(compact: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                calendarTitle(compact: compact)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 8)
                calendarHeaderActions
                    .fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: 12) {
                calendarTitle(compact: compact)
                calendarHeaderActions
            }
        }
    }

    private func calendarTitle(compact: Bool) -> some View {
        ScenicRoyalScreenHeader(title: "Calendar", subtitle: "", compact: compact) {
            EmptyView()
        }
    }

    private var calendarHeaderActions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
                Button {
                    showingProviders = true
                    LifeRouteHaptics.selection()
                } label: {
                    Label("Sources", systemImage: "calendar.badge.checkmark")
                }
                .buttonStyle(UI01SecondaryButtonStyle())
                .accessibilityHint("Opens Calendar Sources")

                Button { openAppointmentSheet() } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(UI01GoldButtonStyle(compact: true))
                .accessibilityLabel("Add appointment")
        }
    }

    private var rangeControl: some View {
        VStack(spacing: 12) {
            ScenicRoyalSegmentedControl(
                selection: $selectedRange,
                options: LifeRouteCalendarRange.allCases
            ) { range in
                Text(rangeTitle(range))
            }
            .padding(4)
            .modifier(UI01CompactControlSurface())
            .accessibilityIdentifier("calendar.range")

            HStack(spacing: 8) {
                ScenicRoyalCompactIconButton(systemImage: "chevron.left", accessibilityLabel: "Previous period") {
                    LifeRouteHaptics.selection()
                    calendarState.shiftSelection(selectedRange, by: -1)
                }

                Button {
                    showingDatePicker = true
                    LifeRouteHaptics.selection()
                } label: {
                    HStack(spacing: 8) {
                        Text(calendarState.periodLabel(for: selectedRange))
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose date")
                .accessibilityValue(calendarState.periodLabel(for: selectedRange))

                ScenicRoyalCompactIconButton(systemImage: "chevron.right", accessibilityLabel: "Next period") {
                    LifeRouteHaptics.selection()
                    calendarState.shiftSelection(selectedRange, by: 1)
                }
            }
        }
    }

    private func compactDateStrip(compact: Bool) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                ScenicRoyalGlassEffectContainer(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                    HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                        ForEach(calendarState.weekDates(containing: calendarState.selectedDate), id: \.self) { date in
                            dateChip(date, compact: compact)
                                .id(Calendar.current.startOfDay(for: date))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .onAppear { centerSelectedDate(in: proxy) }
            .onChange(of: calendarState.selectedDate) { _ in centerSelectedDate(in: proxy) }
            .onChange(of: visibility.active) { active in if active { centerSelectedDate(in: proxy) } }
        }
        // Deployment-target-safe: horizontal date browsing remains clipped by the ScrollView.
    }

    private func dateChip(_ date: Date, compact: Bool) -> some View {
        let selected = Calendar.current.isDate(date, inSameDayAs: calendarState.selectedDate)
        let today = Calendar.current.isDateInToday(date)
        let count = calendarState.events(on: date).count

        return ScenicRoyalCalendarDateChip(
            date: date,
            eventCount: count,
            isSelected: selected,
            isToday: today,
            compact: compact
        ) {
            calendarState.selectedDate = date
            LifeRouteHaptics.selection()
        }
    }

    private func monthGrid(compact: Bool) -> some View {
        VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            HStack(spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                ForEach(calendarState.weekDates(containing: calendarState.selectedDate), id: \.self) { date in
                    Text(date.formatted(.dateTime.weekday(.narrow)))
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
        .scenicRoyalCard(role: .majorGroup, padding: compact ? ScenicRoyalDesignSystem.Spacing.compact : ScenicRoyalDesignSystem.Spacing.standard)
        .accessibilityIdentifier("calendar.monthGrid")
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var monthGridDates: [Date?] {
        let dates = calendarState.monthDates(containing: calendarState.selectedDate)
        guard let first = dates.first else { return [] }
        // Derive the leading cells from the source-owned week, including its
        // configured first weekday; the board's Monday labels are not data.
        guard let weekStart = calendarState.weekDates(containing: first).first else { return [] }
        let leadingDays = Calendar.current.dateComponents([.day], from: weekStart, to: first).day ?? 0
        return Array(repeating: nil, count: leadingDays) + dates.map(Optional.some)
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
    private func dayAgenda(now: Date) -> some View {
        if selectedDayEvents.isEmpty {
            emptyAgendaCard
        } else {
            VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                eventGroup(selectedDayEvents, day: calendarState.selectedDate, now: now)
            }
            .padding(ScenicRoyalDesignSystem.Spacing.standard)
            .ui01ScenicText()
        }
    }

    @ViewBuilder
    private func weekAgenda(now: Date) -> some View {
        let days = presentation.days.filter { !$0.events.isEmpty }
        if days.isEmpty {
            emptyAgendaCard
        } else {
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

                        eventGroup(day.events, day: day.date, now: now)
                    }
                }
            }
            .padding(ScenicRoyalDesignSystem.Spacing.standard)
            .ui01ScenicText()
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
        .scenicRoyalCard(role: .majorGroup)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func eventGroup(_ events: [LifeRouteCalendarEvent], day: Date, now: Date) -> some View {
        let allDayEvents = events.filter(\.isAllDay)
        if !allDayEvents.isEmpty {
            Text("All day")
                .font(.caption.weight(.semibold))
                .foregroundStyle(UI01Material.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            ForEach(allDayEvents) { event in
                timelineEventRow(event, active: false)
            }
        }
        ForEach(events.filter { !$0.isAllDay }) { event in
            timelineEventRow(event, active: Calendar.current.isDateInToday(day) && event.start <= now && now < event.end)
        }
    }

    private func timelineEventRow(_ event: LifeRouteCalendarEvent, active: Bool) -> some View {
        ScenicRoyalScheduleEventRow(
            event: event,
            sourceLabel: sourceLabel(event.source),
            sourceIcon: sourceIcon(event.source),
            sourceAccent: sourceAccent(event.source),
            isActive: active,
            onOpen: {
                openEvent(event)
            },
            onDelete: event.source == .manual ? {
                LifeRouteHaptics.selection()
                eventPendingRowDeletion = event
            } : nil
        )
    }

    private var travelCard: some View {
        Button {
            LifeRouteHaptics.selection()
            router.select(.today)
        } label: {
            ScenicRoyalTravelPlanLabel(
                detail: travelDetail,
                summary: "",
                actionTitle: "Show in Today",
                accessibilityHint: "Opens the selected day in the Today command center"
            )
        }
        .buttonStyle(.plain)
    }

    private var travelDetail: String {
        let count = selectedDayLocatedEvents.count
        if count == 0 {
            return "Plan this selected day in Today. Add locations before generating its route."
        }
        return "\(count) located appointment\(count == 1 ? "" : "s"). Continue planning this day in Today."
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
        range.rawValue
    }

    private func centerSelectedDate(in proxy: ScrollViewProxy) {
        let selectedDay = Calendar.current.startOfDay(for: calendarState.selectedDate)
        guard visibility.active, lastCenteredDate != selectedDay else { return }
        lastCenteredDate = selectedDay
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
                    .tint(scenicStyle.selectedControlFill)

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
        .background(UI01Material.navy.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .presentationDetents([.medium, .large])
    }

    private func providerSheet(scope: LifeRoutePresentationScope) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your connected calendars stay read-only in LifeRoute. Manual LifeRoute appointments can be added or removed here.")
                        .font(.subheadline)
                        .foregroundStyle(scenicStyle.secondaryText)
                        .scenicRoyalCard(role: .majorGroup)

                    providerRow(
                        title: "Apple Calendar",
                        status: providerState.appleStatus,
                        connected: providerState.appleConnected,
                        busy: providerState.appleBusy,
                        systemImage: "apple.logo"
                    ) {
                        let feedbackTicket = scope.feedbackTicket()
                        providerState.connectOrRefreshApple { events in
                            calendarState.replaceProviderEvents(events, source: .apple)
                            if feedbackTicket?.isEligible == true { LifeRouteHaptics.success() }
                        }
                    }

                    providerRow(
                        title: "Google Calendar",
                        status: providerState.googleStatus,
                        connected: providerState.googleConnected,
                        busy: providerState.googleBusy,
                        systemImage: "g.circle.fill"
                    ) {
                        let feedbackTicket = scope.feedbackTicket()
                        providerState.connectOrRefreshGoogle { events in
                            calendarState.replaceProviderEvents(events, source: .google)
                            if feedbackTicket?.isEligible == true { LifeRouteHaptics.success() }
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
            .navigationTitle("Calendar Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingProviders = false }
                }
            }
        }
        .background(UI01Material.navy.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
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
        ScenicRoyalInsetRow(role: .majorGroup) {
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
                .buttonStyle(UI01GoldButtonStyle(compact: true))
                .disabled(busy)
                .accessibilityHint(connected ? "Refreshes read-only calendar events" : "Connects read-only calendar access")
            }
        }
    }

    private func appointmentSheet(_ sheet: PresentedCalendarSheet) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Appointment title", text: $title, prompt: Text("Appointment title").foregroundColor(UI01Material.secondary))
                        .scenicRoyalField()

                    VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        DatePicker("Date", selection: $eventDate, displayedComponents: .date)
                        Toggle("All day", isOn: $allDay)

                        if !allDay {
                            DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                            DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                        }
                    }
                .scenicRoyalCard(role: .majorGroup)

                    V054AddressField("Appointment location", text: $location)

                    Button {
                        saveAppointment(for: sheet)
                    } label: {
                        Label(
                            isEditing(sheet) ? "Save changes" : "Save appointment",
                            systemImage: "checkmark.circle.fill"
                        )
                    }
                    .buttonStyle(ScenicRoyalPrimaryButtonStyle())

                    if case .editAppointment(let event) = sheet {
                        Button(role: .destructive) {
                            LifeRouteHaptics.selection()
                            showingEditDeleteConfirmation = true
                        } label: {
                            Label("Delete appointment", systemImage: "trash")
                        }
                        .buttonStyle(ScenicRoyalSecondaryButtonStyle())
                        .confirmationDialog(
                            "Delete \(event.displayTitle)?",
                            isPresented: $showingEditDeleteConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Delete appointment", role: .destructive) {
                                deleteManualEvent(event)
                                presentedCalendarSheet = nil
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Only this LifeRoute appointment will be removed.")
                        }
                    }

                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(scenicStyle.secondaryText)
                    }
                }
                .padding(16)
            }
            .navigationTitle(isEditing(sheet) ? "Edit Appointment" : "Add Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentedCalendarSheet = nil }
                }
            }
        }
        .background(UI01Material.navy.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .presentationDetents([.large])
    }

    private func openAppointmentSheet() {
        title = ""
        eventDate = calendarState.selectedDate
        startTime = Date()
        endTime = Date().addingTimeInterval(60 * 60)
        location = ""
        allDay = false
        message = nil
        presentedCalendarSheet = .addAppointment
        LifeRouteHaptics.primaryAction()
    }

    private func openEvent(_ event: LifeRouteCalendarEvent) {
        LifeRouteHaptics.selection()
        message = nil
        guard event.source == .manual else {
            presentedCalendarSheet = .providerDetails(event)
            return
        }
        title = event.title
        eventDate = event.start
        startTime = event.start
        endTime = event.end
        location = event.location
        allDay = event.isAllDay
        presentedCalendarSheet = .editAppointment(event)
    }

    private func saveAppointment(for sheet: PresentedCalendarSheet) {
        do {
            switch sheet {
            case .addAppointment:
                try calendarState.addManualEvent(
                    title: title,
                    date: eventDate,
                    startTime: startTime,
                    endTime: endTime,
                    location: location,
                    isAllDay: allDay
                )
            case .editAppointment(let event):
                try calendarState.updateManualEvent(
                    id: event.id,
                    title: title,
                    date: eventDate,
                    startTime: startTime,
                    endTime: endTime,
                    location: location,
                    isAllDay: allDay
                )
            case .providerDetails:
                return
            }
            title = ""
            location = ""
            message = nil
            presentedCalendarSheet = nil
            LifeRouteHaptics.success()
        } catch {
            message = error.localizedDescription
        }
    }

    private func deleteManualEvent(_ event: LifeRouteCalendarEvent) {
        guard calendarState.removeEvent(id: event.id) else { return }
        LifeRouteHaptics.success()
    }

    private func isEditing(_ sheet: PresentedCalendarSheet) -> Bool {
        if case .editAppointment = sheet { return true }
        return false
    }

    private func providerEventDetailsSheet(_ event: LifeRouteCalendarEvent) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                    Text(event.displayTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(scenicStyle.primaryText)

                    Label(eventTimeDescription(event), systemImage: "clock")
                    if !event.location.isEmpty {
                        Label(event.location, systemImage: "mappin.and.ellipse")
                    }
                    Label(sourceLabel(event.source), systemImage: sourceIcon(event.source))

                    Text("This appointment is managed by its calendar source and is read-only in LifeRoute.")
                        .font(.subheadline)
                        .foregroundStyle(scenicStyle.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                    .scenicRoyalCard(role: .majorGroup)
                .padding(16)
            }
            .navigationTitle("Appointment Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { presentedCalendarSheet = nil }
                }
            }
        }
        .background(UI01Material.navy.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .presentationDetents([.medium, .large])
    }

    private func eventTimeDescription(_ event: LifeRouteCalendarEvent) -> String {
        if event.isAllDay {
            return "All day · \(event.start.formatted(date: .abbreviated, time: .omitted))"
        }
        return "\(event.start.formatted(date: .abbreviated, time: .shortened))–\(event.end.formatted(date: .omitted, time: .shortened))"
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
