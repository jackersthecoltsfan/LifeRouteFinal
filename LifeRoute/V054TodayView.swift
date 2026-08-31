import SwiftUI

// v0.7.0 Build B Today/Home: the reference implementation for the v0.7 screen language.
// v0.7.0 Build B.1 Today/Home parity: device-tuned against the approved target screenshot.
// v0.7.0 Build B.2 device QA: real-iPhone density pass against the approved reference.
// v0.7.0 Build B.3 device QA: cinematic hero and one-screen information hierarchy tuned from real-device screenshots.
// v0.7.0 swipeable day overview: shared CalendarCoreState selection drives native iOS-16 paging.
struct V054TodayView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.scenicRoyalThemeStyle) private var scenicStyle
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ObservedObject var router: AppRouter
    @ObservedObject var calendarState: CalendarCoreState
    @ObservedObject var routingState: RoutingLocationCore

    @StateObject private var liveActivity = LiveDayActivityCore()
    @State private var liveDayEnabled = false
    @State private var returnHomeOnLiveDay = true
    // CalendarCoreState.selectedDate is the sole selected-day owner shared with Schedule.
    private var selectedDay: Date {
        get { Calendar.current.startOfDay(for: calendarState.selectedDate) }
        nonmutating set {
            calendarState.selectedDate = Calendar.current.startOfDay(for: newValue)
        }
    }

    private var selectedDayBinding: Binding<Date> {
        Binding(
            get: { selectedDay },
            set: { selectedDay = $0 }
        )
    }

    // Apple and Google provider refreshes currently materialize yesterday through +45 days.
    private var pagingDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (-1...45).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today).map(calendar.startOfDay(for:))
        }
    }
    @State private var showingDayPicker = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                hero
                dayOverviewPager
                quickActions
                overviewCard
                gapSuggestions
                liveDayCard
            }
            .padding(.horizontal, 12)
            .padding(.top, 7)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: selectedDay) { _ in
            liveDayEnabled = false
        }
        .sheet(isPresented: $showingDayPicker) {
            dayPickerSheet
        }
    }

    private var selectedDayEvents: [LifeRouteCalendarEvent] {
        calendarState.events(on: selectedDay).sorted { $0.start < $1.start }
    }

    private var selectedDayStops: [LifeRouteDayStop] {
        routingState.dayStops(on: selectedDay)
    }

    private var selectedDayPlanWaypoints: [LifeRouteDayWaypoint] {
        LifeRouteDaySequenceBuilder.waypoints(
            appointments: selectedDayEvents.map {
                LifeRouteRouteAppointment(
                    id: $0.id,
                    title: $0.title,
                    address: $0.location,
                    start: $0.start
                )
            },
            beforeStops: selectedDayStops.filter { $0.position == .before },
            afterStops: selectedDayStops.filter { $0.position == .after }
        )
    }

    private var nextEvent: LifeRouteCalendarEvent? {
        Calendar.current.isDateInToday(selectedDay)
            ? selectedDayEvents.first { $0.end > Date() }
            : selectedDayEvents.first
    }

    private var drivingEstimates: [LifeRouteRouteEstimate] {
        routingState.routeEstimates.values.filter { $0.mode == .driving }
    }

    private var quickActionColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 4
        return Array(
            repeating: GridItem(.flexible(minimum: 64), spacing: 8, alignment: .top),
            count: count
        )
    }

    private var overviewMetricColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 3
        return Array(
            repeating: GridItem(.flexible(minimum: 72), spacing: 7, alignment: .top),
            count: count
        )
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            HStack(alignment: .center, spacing: 0) {
                Text("Life")
                    .foregroundStyle(scenicStyle.primaryText)
                Text("Route")
                    .foregroundStyle(brandGold)
                Spacer(minLength: 12)
                Button {
                    showingDayPicker = true
                    LifeRouteHaptics.selection()
                } label: {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(scenicStyle.accent)
                        .frame(
                            width: ScenicRoyalDesignSystem.Layout.minimumTouchTarget,
                            height: ScenicRoyalDesignSystem.Layout.minimumTouchTarget
                        )
                        .scenicRoyalInteractiveSurface(
                            role: .selectedControl,
                            cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose day")
                .accessibilityHint("Opens the calendar date picker.")
            }
            .font(.system(.largeTitle, design: .rounded, weight: .black))

            Text("Plan your day. Optimize every gap.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(scenicStyle.secondaryText)

            Spacer(minLength: dynamicTypeSize.isAccessibilitySize ? 12 : 30)

            HStack(alignment: .bottom, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(dayPageTitle(selectedDay))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(scenicStyle.primaryText)
                    Text(selectedDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.caption)
                        .foregroundStyle(scenicStyle.secondaryText)
                }
                Spacer(minLength: 8)
                if routingState.liveLocationEnabled {
                    Label("Location active", systemImage: "location.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(scenicStyle.primaryText)
                        .accessibilityLabel("Live location active")
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 210 : 168, alignment: .topLeading)
        .scenicRoyalCard(
            role: dynamicTypeSize.isAccessibilitySize ? .readability : .ambient,
            cornerRadius: ScenicRoyalDesignSystem.Radius.hero
        )
        .accessibilityElement(children: .contain)
    }

    private var brandGold: Color {
        Color(red: 0.96, green: 0.72, blue: 0.20)
    }

    private var routeBlue: Color {
        Color(red: 0.28, green: 0.72, blue: 0.96)
    }

    private var schedulePurple: Color {
        Color(red: 0.68, green: 0.40, blue: 0.96)
    }

    private var selectedDayContext: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundStyle(brandGold)
            Text(selectedDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: 8)
            Button("Back to Today") {
                selectedDay = Calendar.current.startOfDay(for: Date())
                LifeRouteHaptics.selection()
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(brandGold)
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 36)
        .background(palette.panel.opacity(0.52), in: Capsule())
        .overlay {
            Capsule().stroke(Color.white.opacity(0.07), lineWidth: LifeRouteDesign.Stroke.subtle)
        }
    }

    private var dayPickerSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                LifeRouteScreenHeader(
                    title: "Choose Day",
                    subtitle: "Home stays compact; date browsing remains available here.",
                    systemImage: "calendar"
                )
                daySelector
                Spacer(minLength: 0)
            }
            .padding(16)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingDayPicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(245)])
        .lifeRouteModalChrome()
    }

    private var daySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            // v0.6.3 responsive day selector layout remains protected in the v0.7 compact treatment.
            HStack(spacing: 10) {
                Button {
                    shiftSelectedDay(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .frame(width: LifeRouteDesign.Layout.minimumTouchTarget, height: LifeRouteDesign.Layout.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.textSecondary)
                .accessibilityLabel("Previous day")

                VStack(spacing: 2) {
                    Text(Calendar.current.isDateInToday(selectedDay) ? "Today" : selectedDay.formatted(.dateTime.weekday(.wide)))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(selectedDay.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

                Button {
                    shiftSelectedDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .frame(width: LifeRouteDesign.Layout.minimumTouchTarget, height: LifeRouteDesign.Layout.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.textSecondary)
                .accessibilityLabel("Next day")
            }

            HStack(spacing: 8) {
                Label("Choose date", systemImage: "calendar")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                Spacer(minLength: 6)
                DatePicker("Choose day", selection: selectedDayBinding, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .fixedSize()
                    .tint(palette.accent)

                if !Calendar.current.isDateInToday(selectedDay) {
                    Button {
                        selectedDay = Calendar.current.startOfDay(for: Date())
                        LifeRouteHaptics.selection()
                    } label: {
                        Text("Today")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 8)
                            .frame(minHeight: 30)
                            .background(palette.accent.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Jump to Today")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.panel.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: LifeRouteDesign.Stroke.subtle)
        }
    }

    @ViewBuilder
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

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 7) {
            ScenicRoyalSectionHeader("Quick Actions", subtitle: "Plan, locate, schedule, or add a stop.")

            ScenicRoyalGlassEffectContainer(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                LazyVGrid(columns: quickActionColumns, spacing: 8) {
                    NavigationLink {
                        DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)
                    } label: {
                        quickActionLabel(
                            "Plan Route",
                            "arrow.triangle.turn.up.right.diamond.fill",
                            accent: brandGold
                        )
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })

                    Button {
                        LifeRouteHaptics.primaryAction()
                        if routingState.liveLocationEnabled {
                            routingState.stopLiveLocation()
                        } else {
                            routingState.requestCurrentLocation()
                        }
                    } label: {
                        quickActionLabel(
                            "Current Location",
                            routingState.liveLocationEnabled ? "location.fill.viewfinder" : "location.fill",
                            accent: routeBlue,
                            isActive: routingState.liveLocationEnabled
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(routingState.locationRequestInFlight)

                    Button {
                        LifeRouteHaptics.selection()
                        router.select(.schedule)
                    } label: {
                        quickActionLabel("Open Schedule", "calendar", accent: schedulePurple)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)
                    } label: {
                        quickActionLabel("Add Stop", "plus", accent: brandGold)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })
                }
            }
        }
        .scenicRoyalCard(role: .ambient, padding: ScenicRoyalDesignSystem.Spacing.standard)
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScenicRoyalSectionHeader(
                Calendar.current.isDateInToday(selectedDay) ? "Today’s Overview" : "Day Overview",
                subtitle: "Events and current route estimates.",
                systemImage: "calendar.day.timeline.left"
            )

            // v0.7.0 Today overview full-day agenda: show every appointment on the selected
            // calendar day instead of reducing the overview to only the next appointment.
            if selectedDayEvents.isEmpty {
                HStack(spacing: 10) {
                    ScenicRoyalIconBadge(systemImage: "checkmark.circle.fill")
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
        .scenicRoyalCard(role: .readability)
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

    private var gapSuggestions: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                ScenicRoyalSectionHeader(
                    "Suggested Gap Fillers",
                    subtitle: "Useful options for open time.",
                    systemImage: "sparkles"
                )
                Spacer()
                NavigationLink {
                    DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)
                } label: {
                    Text("See all")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(palette.accent)
                }
                .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })
                .buttonStyle(.plain)
            }

            // v0.7.0 restored To-Do gap fillers: flexible weekly tasks surface before saved-place ideas.
            let openTodos = routingState.todos.filter { !$0.completed }
            let suggestions = routingState.savedPlaces.filter(\.useInGapSuggestions)
            if openTodos.isEmpty && suggestions.isEmpty {
                HStack(spacing: 10) {
                    ScenicRoyalIconBadge(systemImage: "sparkles")
                    Text("Add a weekly to-do or mark saved places as gap suggestions in Setup and they’ll surface here.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .scenicRoyalCard(role: .readability)
            } else {
                ForEach(openTodos.prefix(1)) { todo in
                    HStack(spacing: 11) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(palette.accent.opacity(0.15))
                            Image(systemName: todo.category.systemImage)
                                .foregroundStyle(palette.accentSecondary)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(todo.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.textPrimary)
                            Text("\(todo.durationMinutes) min · due \(todo.dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundStyle(palette.textSecondary)
                            if !todo.address.isEmpty {
                                Text(todo.address)
                                    .font(.caption2)
                                    .foregroundStyle(palette.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Button {
                            routingState.setTodoCompleted(id: todo.id, completed: true)
                            LifeRouteHaptics.success()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(palette.accentSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Complete \(todo.title)")
                    }
                    .padding(8)
                    .background(palette.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: LifeRouteDesign.Stroke.subtle)
                    }
                }

                ForEach(suggestions.prefix(openTodos.isEmpty ? 1 : 0)) { place in
                    NavigationLink {
                        DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)
                    } label: {
                        gapSuggestionRow(place)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })
                }
            }
        }
        .scenicRoyalCard(role: .ambient, padding: ScenicRoyalDesignSystem.Spacing.standard)
    }

    private func gapSuggestionRow(_ place: LifeRouteSavedPlace) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [palette.accent.opacity(0.25), palette.panelElevated.opacity(0.64)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: place.kind.scenicRoyalSystemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.accentSecondary)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                Text(gapSuggestionDetail(place))
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.textSecondary.opacity(0.82))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.panel.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: LifeRouteDesign.Stroke.subtle)
        }
    }

    private var liveDayCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                ScenicRoyalIconBadge(systemImage: "bolt.horizontal.circle.fill")
                VStack(alignment: .leading, spacing: 2) {
                    Text(liveDayEnabled ? "Live Day" : "Live Day + Lock Screen")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                    Text("Keep the selected day’s next-event timing available at a glance.")
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer(minLength: 6)
                if liveActivity.isActive {
                    Text("LIVE")
                        .font(.caption2.weight(.black))
                        .tracking(0.6)
                        .foregroundStyle(Color.black.opacity(0.78))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(palette.accent, in: Capsule())
                }
            }

            Toggle("Return home after the day", isOn: $returnHomeOnLiveDay)
                .font(.caption.weight(.semibold))
                .disabled(routingState.homeAddress.isEmpty)

            if liveDayEnabled {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    liveSummary(now: context.date)
                }

                liveDaySequence

                HStack(spacing: 9) {
                    Button {
                        LifeRouteHaptics.primaryAction()
                        Task {
                            await liveActivity.update(
                                events: selectedDayEvents,
                                dayStops: selectedDayStops,
                                savedPlaces: routingState.savedPlaces,
                                routeEstimates: routingState.routeEstimates,
                                returnHomePlanned: returnHomeOnLiveDay
                            )
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(ScenicRoyalSecondaryButtonStyle())

                    Button {
                        LifeRouteHaptics.selection()
                        liveDayEnabled = false
                        Task { await liveActivity.end() }
                    } label: {
                        Label("End", systemImage: "stop.fill")
                    }
                    .buttonStyle(ScenicRoyalSecondaryButtonStyle())
                }
            } else {
                Button {
                    liveDayEnabled = true
                    LifeRouteHaptics.primaryAction()
                    Task {
                        await liveActivity.start(
                            events: selectedDayEvents,
                            dayStops: selectedDayStops,
                            savedPlaces: routingState.savedPlaces,
                            routeEstimates: routingState.routeEstimates,
                            returnHomePlanned: returnHomeOnLiveDay,
                            day: selectedDay
                        )
                    }
                } label: {
                    Label("Generate + launch selected day", systemImage: "sparkles")
                }
                .buttonStyle(ScenicRoyalPrimaryButtonStyle())
            }

            if let message = liveActivity.message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .scenicRoyalCard(role: .readability)
    }

    private var liveDaySequence: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("GENERATED DAY")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(palette.accent)
                Spacer()
                if !selectedDayStops.isEmpty {
                    Text("\(selectedDayStops.count) SAVED STOP\(selectedDayStops.count == 1 ? "" : "S")")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(palette.accentSecondary)
                }
            }

            ForEach(selectedDayPlanWaypoints) { waypoint in
                HStack(spacing: 9) {
                    Image(systemName: waypoint.kind == .stop ? "mappin.and.ellipse" : "calendar")
                        .foregroundStyle(waypoint.kind == .stop ? palette.accentSecondary : palette.accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(waypoint.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Text(waypoint.address.isEmpty ? "No location" : waypoint.address)
                            .font(.caption2)
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(waypoint.kind == .stop ? "STOP" : "EVENT")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(palette.panelElevated.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private func liveSummary(now: Date) -> some View {
        if let event = selectedDayEvents.first(where: { $0.end > now }) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.start <= now ? "CURRENT EVENT" : "NEXT EVENT")
                        .font(.caption2.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(palette.accent)
                    Text(event.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(timeRemaining(to: event.start <= now ? event.end : event.start, now: now))
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(palette.accentSecondary)
            }
            .padding(11)
            .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            Text("The selected day’s timed events are complete.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func quickActionLabel(
        _ title: String,
        _ systemImage: String,
        accent: Color,
        isActive: Bool = false
    ) -> some View {
        VStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(isActive ? 0.34 : 0.22), palette.panelElevated.opacity(0.70)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(accent)
            }
            .frame(width: 42, height: 42)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accent.opacity(isActive ? 0.48 : 0.26), lineWidth: LifeRouteDesign.Stroke.subtle)
            }
            .shadow(color: accent.opacity(isActive ? 0.18 : 0.08), radius: 8, y: 3)

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .top)
        .contentShape(Rectangle())
        .padding(.horizontal, 3)
        .padding(.vertical, 5)
        .scenicRoyalInteractiveSurface(
            role: isActive ? .selectedControl : .ambient,
            cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl
        )
    }

    private func overviewMetric(
        value: String,
        label: String,
        detail: String,
        systemImage: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent)
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(8)
        .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: LifeRouteDesign.Stroke.subtle)
        }
    }

    private var totalDrivingDurationLabel: String {
        let seconds = drivingEstimates.reduce(0) { $0 + $1.travelTimeSeconds }
        let minutes = max(0, Int((seconds / 60).rounded()))
        guard minutes > 0 else { return "0m" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining == 0 ? "\(hours)h" : "\(hours)h \(remaining)m"
    }

    private func nextEventCountdownLabel(_ event: LifeRouteCalendarEvent, now: Date) -> String {
        guard Calendar.current.isDateInToday(selectedDay) else { return "Starts at" }
        return event.start <= now ? "Ends in" : "Starts in"
    }

    private func nextEventCountdownValue(_ event: LifeRouteCalendarEvent, now: Date) -> String {
        guard Calendar.current.isDateInToday(selectedDay) else {
            return event.start.formatted(date: .omitted, time: .shortened)
        }
        return timeRemaining(to: event.start <= now ? event.end : event.start, now: now)
    }

    private func gapSuggestionDetail(_ place: LifeRouteSavedPlace) -> String {
        if let estimate = routingState.routeEstimates[place.id] {
            return "\(estimate.durationLabel) away · \(place.minimumVisitMinutes) min visit"
        }
        return "\(place.minimumVisitMinutes) min visit · route when ready"
    }

    private func shiftSelectedDay(by days: Int) {
        guard let shifted = Calendar.current.date(byAdding: .day, value: days, to: selectedDay) else { return }
        selectedDay = Calendar.current.startOfDay(for: shifted)
        LifeRouteHaptics.selection()
    }

    private func timeRemaining(to target: Date, now: Date) -> String {
        let seconds = max(0, Int(target.timeIntervalSince(now)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remaining = seconds % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes >= 10 { return "\(minutes)m" }
        return "\(minutes)m \(remaining)s"
    }

}
