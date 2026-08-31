import Foundation
import SwiftUI

/// Build 119 Today command center. Calendar owns schedule browsing; Today owns
/// the selected day's route generation, canonical itinerary, departure guidance,
/// gap-fit suggestions, and Live Day projection.
struct V054TodayView: View {
    @Environment(\.scenicRoyalThemeStyle) private var scenicStyle
    @ObservedObject var router: AppRouter
    @ObservedObject var calendarState: CalendarCoreState
    @ObservedObject var routingState: RoutingLocationCore
    @ObservedObject var planState: DayRoutePlanningCore
    @ObservedObject var liveActivity: LiveDayActivityCore

    @State private var showingDayPicker = false
    @State private var routeSettingsExpanded = false
    @State private var gapFillersExpanded = false

    private var selectedDay: Date {
        get { Calendar.current.startOfDay(for: calendarState.selectedDate) }
        nonmutating set {
            calendarState.selectedDate = Calendar.current.startOfDay(for: newValue)
        }
    }

    private var selectedDayEvents: [LifeRouteCalendarEvent] {
        calendarState.events(on: selectedDay).sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.id < $1.id
        }
    }

    private var selectedDayStops: [LifeRouteDayStop] {
        routingState.dayStops(on: selectedDay)
    }

    private var routeAppointments: [LifeRouteRouteAppointment] {
        selectedDayEvents.map {
            LifeRouteRouteAppointment(
                id: $0.id,
                title: $0.title,
                address: $0.location,
                start: $0.start,
                end: $0.end,
                isAllDay: $0.isAllDay
            )
        }
    }

    private var beforeStops: [LifeRouteDayStop] {
        selectedDayStops.filter { $0.position == .before }
    }

    private var afterStops: [LifeRouteDayStop] {
        selectedDayStops.filter { $0.position == .after }
    }

    private var selectedItinerary: LifeRouteGeneratedItinerary? {
        guard let itinerary = planState.generatedItinerary,
              Calendar.current.isDate(itinerary.selectedDay, inSameDayAs: selectedDay) else {
            return nil
        }
        return itinerary
    }

    private var itineraryIsCurrent: Bool {
        planState.matchesGeneratedItinerary(
            selectedDay: selectedDay,
            appointments: routeAppointments,
            beforeStops: beforeStops,
            afterStops: afterStops,
            routeBufferMinutes: routingState.routeBufferMinutes,
            homeAddress: routingState.homeAddress,
            currentLocation: routingState.currentLocation
        )
    }

    private var authoritativeItinerary: LifeRouteGeneratedItinerary? {
        itineraryIsCurrent ? selectedItinerary : nil
    }

    private var canGenerate: Bool {
        let hasDestination = routeAppointments.contains {
            !$0.isAllDay && !$0.address.isEmpty
        } || !selectedDayStops.isEmpty
        let hasOrigin = routingState.currentLocation != nil || !routingState.homeAddress.isEmpty
        let canReturnHome = !planState.returnHome || !routingState.homeAddress.isEmpty
        return hasDestination && hasOrigin && canReturnHome
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
                commandHeader
                dayControls
                commandStatus
                itineraryCard
                if let itinerary = authoritativeItinerary,
                   !itinerary.usableGaps.isEmpty {
                    gapFillersCard(itinerary)
                }
                if let itinerary = authoritativeItinerary {
                    liveDayCard(itinerary)
                }
            }
            .padding(.horizontal, ScenicRoyalDesignSystem.Layout.pageHorizontal)
            .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
            .padding(.bottom, ScenicRoyalDesignSystem.Spacing.spacious * 2)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingDayPicker) {
            dayPickerSheet
        }
        .onAppear {
            if routingState.homeAddress.isEmpty {
                planState.returnHome = false
            }
        }
        .onChange(of: selectedDay) { _ in
            endLiveDayForChangedInputs()
        }
        .onChange(of: selectedDayEvents) { _ in
            endLiveDayForChangedInputs()
        }
        .onChange(of: selectedDayStops) { _ in
            endLiveDayForChangedInputs()
        }
        .onChange(of: routingState.routeBufferMinutes) { _ in
            endLiveDayForChangedInputs()
        }
        .onChange(of: planState.routeMode) { _ in
            endLiveDayForChangedInputs()
        }
        .onChange(of: planState.returnHome) { _ in
            endLiveDayForChangedInputs()
        }
    }

    // Phase C replaces this compact structural header with the approved mark
    // and exact Build 119 motto without changing command-center ownership.
    private var commandHeader: some View {
        ScenicRoyalScreenHeader(
            title: "Today",
            subtitle: selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day())
        ) {
            ScenicRoyalCompactIconButton(
                systemImage: "calendar.badge.clock",
                accessibilityLabel: "Choose day"
            ) {
                showingDayPicker = true
                LifeRouteHaptics.selection()
            }
        }
    }

    private var dayControls: some View {
        HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            dayShiftButton(-1, systemImage: "chevron.left", label: "Previous day")

            Button {
                selectedDay = Date()
                LifeRouteHaptics.selection()
            } label: {
                VStack(spacing: 2) {
                    Text(dayContextTitle)
                        .font(.subheadline.weight(.bold))
                    Text(selectedDay.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption2)
                        .foregroundStyle(scenicStyle.secondaryText)
                }
                .frame(maxWidth: .infinity, minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Returns the command center to today")

            dayShiftButton(1, systemImage: "chevron.right", label: "Next day")
        }
        .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.compact)
        .scenicRoyalInteractiveSurface(
            role: .ambient,
            cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl
        )
    }

    private var commandStatus: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            commandStatusContent(now: context.date)
        }
    }

    private func commandStatusContent(now: Date) -> some View {
        let current = currentEvent(at: now)
        let next = nextEvent(at: now)
        let guidance = authoritativeItinerary?.departureGuidance(
            at: Calendar.current.isDateInToday(selectedDay) ? now : selectedDay
        )

        return VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
            HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                Image(systemName: routingState.currentLocation == nil ? "house.fill" : "location.fill")
                    .foregroundStyle(scenicStyle.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("STARTING FROM")
                        .font(.caption2.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(scenicStyle.secondaryText)
                    Text(startingPointLabel)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(scenicStyle.primaryText)
                }
            }

            Divider().overlay(scenicStyle.accent.opacity(0.18))

            HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(current == nil ? "NEXT" : "RIGHT NOW")
                        .font(.caption2.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(scenicStyle.accent)
                    Text((current ?? next)?.title ?? emptyDayStatus)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(scenicStyle.primaryText)
                        .lineLimit(2)
                    if let event = current ?? next {
                        Text(eventStatusLine(event, now: now))
                            .font(.caption)
                            .foregroundStyle(scenicStyle.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(departureEyebrow(guidance))
                        .font(.caption2.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(scenicStyle.secondaryText)
                    Text(departureHeadline(guidance))
                        .font(.title3.weight(.black))
                        .foregroundStyle(guidance == nil ? scenicStyle.secondaryText : scenicStyle.accentReflection)
                        .multilineTextAlignment(.trailing)
                    if let guidance {
                        Text("Leave by \(guidance.leaveBy.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(scenicStyle.secondaryText)
                    }
                }
            }

            if let guidance {
                HStack(spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
                    Label("Drive \(durationLabel(guidance.rawTravelSeconds))", systemImage: "car.fill")
                    Label(
                        guidance.bufferSeconds > 0
                            ? "Buffer +\(durationLabel(guidance.bufferSeconds))"
                            : "No buffer",
                        systemImage: "clock.badge.plus"
                    )
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(scenicStyle.secondaryText)
            }
        }
        .scenicRoyalCard(role: .readability)
    }

    private var itineraryCard: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
            HStack(alignment: .firstTextBaseline) {
                Label("Day timeline", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(scenicStyle.primaryText)
                Spacer()
                if let itinerary = selectedItinerary {
                    Text("\(durationLabel(itinerary.totalRawTravelSeconds)) driving")
                        .font(.caption.weight(.black))
                        .foregroundStyle(scenicStyle.accent)
                }
            }

            if let itinerary = selectedItinerary {
                if !itineraryIsCurrent {
                    Label(
                        "Appointments, stops, location, or route settings changed. Regenerate before using departure guidance.",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(scenicStyle.accentReflection)
                }
                timeline(itinerary)
            } else {
                ungeneratedTimeline
            }

            if let blocker = generationBlocker {
                Text(blocker)
                    .font(.caption)
                    .foregroundStyle(scenicStyle.secondaryText)
            }

            Button {
                generateFullDay()
            } label: {
                Label(
                    planState.isCalculating
                        ? "Generating full day…"
                        : (selectedItinerary == nil ? "Generate Full Day" : "Regenerate Full Day"),
                    systemImage: "map.fill"
                )
            }
            .buttonStyle(ScenicRoyalPrimaryButtonStyle())
            .disabled(planState.isCalculating || !canGenerate)

            NavigationLink {
                DayRoutePlanningView(
                    calendarState: calendarState,
                    routingState: routingState,
                    planState: planState,
                    day: selectedDay
                )
                .lifeRouteDeepDestination()
            } label: {
                Label("Edit stops & route options", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(ScenicRoyalSecondaryButtonStyle())
            .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })

            DisclosureGroup(isExpanded: $routeSettingsExpanded) {
                VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                    Picker("Travel mode", selection: $planState.routeMode) {
                        ForEach(LifeRouteTransportMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Return Home", isOn: $planState.returnHome)
                        .disabled(routingState.homeAddress.isEmpty)

                    HStack {
                        Label("Route Buffer", systemImage: "clock.badge.plus")
                        Spacer()
                        Text(routingState.routeBufferMinutes == 0
                            ? "None"
                            : "+\(routingState.routeBufferMinutes) min")
                            .foregroundStyle(scenicStyle.accentReflection)
                    }
                    .font(.subheadline.weight(.semibold))

                    Button("Change Route Buffer in Setup") {
                        router.select(.setup)
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
            } label: {
                Label("Route settings", systemImage: "gearshape.2.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(scenicStyle.primaryText)
            }

            if let message = planState.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(scenicStyle.secondaryText)
            }
        }
        .scenicRoyalCard(role: .readability)
    }

    @ViewBuilder
    private func timeline(_ itinerary: LifeRouteGeneratedItinerary) -> some View {
        let nodes = itinerary.nodes.reduce(into: [String: LifeRouteItineraryNode]()) {
            result,
            node in
            if result[node.id] == nil {
                result[node.id] = node
            }
        }
        ScenicRoyalGlassEffectContainer(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                ForEach(itinerary.timeline) { item in
                    timelineRow(item, nodes: nodes)
                }
            }
        }
    }

    private func timelineRow(
        _ item: LifeRouteItineraryTimelineItem,
        nodes: [String: LifeRouteItineraryNode]
    ) -> some View {
        ScenicRoyalInsetRow(role: item.kind == .usableGap ? .selectedControl : .ambient) {
            HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                Image(systemName: timelineIcon(item.kind))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(item.kind == .usableGap ? scenicStyle.accentReflection : scenicStyle.accent)
                    .frame(width: 22)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    switch item.kind {
                    case .drive:
                        if let leg = item.leg {
                            Text("\(durationLabel(leg.rawTravelSeconds)) drive")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(scenicStyle.primaryText)
                            let destination = nodes[leg.toNodeID]?.title ?? "next stop"
                            Text("To \(destination) · \(distanceLabel(leg.rawDistanceMeters))")
                                .font(.caption)
                                .foregroundStyle(scenicStyle.secondaryText)
                        }
                    case .usableGap:
                        if let gap = item.gap {
                            Text(gap.usableSeconds.map { "\(durationLabel($0)) usable" } ?? "Route data needed")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(scenicStyle.primaryText)
                            Text("Calendar gap \(durationLabel(gap.rawCalendarGapSeconds)) · travel, planned stops, and buffer already deducted")
                                .font(.caption)
                                .foregroundStyle(scenicStyle.secondaryText)
                        }
                    case .origin, .appointment, .stop, .home:
                        if let node = item.node {
                            Text(node.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(scenicStyle.primaryText)
                            Text(nodeDetail(node))
                                .font(.caption)
                                .foregroundStyle(scenicStyle.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(timelineKindLabel(item.kind))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(scenicStyle.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var ungeneratedTimeline: some View {
        let waypoints = LifeRouteDaySequenceBuilder.waypoints(
            appointments: routeAppointments,
            beforeStops: beforeStops,
            afterStops: afterStops
        )
        return Group {
            if waypoints.isEmpty {
                VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundStyle(scenicStyle.accent)
                    Text("No appointments or saved stops yet")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(scenicStyle.primaryText)
                    Button("Open Calendar") {
                        router.select(.schedule)
                    }
                    .font(.caption.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ScenicRoyalDesignSystem.Spacing.comfortable)
            } else {
                ScenicRoyalGlassEffectContainer(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                    VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                        ForEach(waypoints) { waypoint in
                            previewRow(waypoint)
                        }
                    }
                }
            }
        }
    }

    private func previewRow(_ waypoint: LifeRouteDayWaypoint) -> some View {
        ScenicRoyalInsetRow(role: .ambient) {
            HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                Image(systemName: waypoint.kind == .stop ? "mappin.and.ellipse" : "calendar")
                    .foregroundStyle(scenicStyle.accent)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(waypoint.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(scenicStyle.primaryText)
                    Text(previewDetail(waypoint))
                        .font(.caption)
                        .foregroundStyle(scenicStyle.secondaryText)
                }
                Spacer()
                Text(waypoint.kind == .stop ? "STOP" : "EVENT")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(scenicStyle.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func gapFillersCard(_ itinerary: LifeRouteGeneratedItinerary) -> some View {
        DisclosureGroup(isExpanded: $gapFillersExpanded) {
            VStack(spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
                ForEach(itinerary.usableGaps) { gap in
                    gapBlock(gap, itinerary: itinerary)
                }
            }
            .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Label("Gap Fillers", systemImage: "sparkles")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(scenicStyle.primaryText)
                Text("Only activities that fit after route time and buffer are eligible.")
                    .font(.caption)
                    .foregroundStyle(scenicStyle.secondaryText)
            }
        }
        .scenicRoyalCard(role: .readability)
    }

    private func gapBlock(
        _ gap: LifeRouteUsableGap,
        itinerary: LifeRouteGeneratedItinerary
    ) -> some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calendar gap: \(durationLabel(gap.rawCalendarGapSeconds))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(scenicStyle.secondaryText)
                    Text(gap.usableSeconds.map { "Actual usable gap: \(durationLabel($0))" } ?? "Actual usable gap: route unavailable")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(scenicStyle.accentReflection)
                }
                Spacer()
                if planState.gapEvaluationInFlight.contains(gap.id) {
                    ProgressView().tint(scenicStyle.accent)
                }
            }

            if let recommendations = planState.gapRecommendationsByGapID[gap.id] {
                if recommendations.isEmpty {
                    Text("No saved place or To-Do currently fits this route-safe gap.")
                        .font(.caption)
                        .foregroundStyle(scenicStyle.secondaryText)
                } else {
                    ForEach(recommendations) { recommendation in
                        recommendationRow(recommendation, gap: gap)
                    }
                }
            } else {
                Button("Find Gap Fillers") {
                    LifeRouteHaptics.selection()
                    planState.evaluateGapFillers(
                        for: gap,
                        itinerary: itinerary,
                        savedPlaces: routingState.savedPlaces,
                        todos: routingState.todos
                    )
                }
                .buttonStyle(ScenicRoyalSecondaryButtonStyle())
                .disabled(!gap.isRouteSafe)
            }
        }
        .padding(ScenicRoyalDesignSystem.Spacing.compact)
        .scenicRoyalInteractiveSurface(
            role: .ambient,
            cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl
        )
    }

    private func recommendationRow(
        _ recommendation: LifeRouteGapFillerRecommendation,
        gap: LifeRouteUsableGap
    ) -> some View {
        HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(scenicStyle.primaryText)
                Text("Fits · \(recommendation.durationMinutes) min")
                    .font(.caption)
                    .foregroundStyle(scenicStyle.secondaryText)
            }
            Spacer()
            if !recommendation.address.isEmpty {
                Button {
                    addRecommendation(recommendation, after: gap.previousAppointmentNodeID)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(scenicStyle.accent)
                        .frame(
                            width: ScenicRoyalDesignSystem.Layout.minimumTouchTarget,
                            height: ScenicRoyalDesignSystem.Layout.minimumTouchTarget
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add \(recommendation.title) to this gap")
            }
        }
    }

    private func liveDayCard(_ itinerary: LifeRouteGeneratedItinerary) -> some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
            HStack {
                Label("Live Day", systemImage: "figure.walk.motion")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(scenicStyle.primaryText)
                Spacer()
                if liveActivity.isActive {
                    Text("LIVE")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color.black.opacity(0.78))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(scenicStyle.accent, in: Capsule())
                }
            }

            Text("The in-app status and Lock Screen use this generated itinerary and the same route-aware departure deadline.")
                .font(.caption)
                .foregroundStyle(scenicStyle.secondaryText)

            if let projection = LifeRouteLiveDayProjection.make(from: itinerary, at: Date()) {
                HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(projection.phaseLabel)
                            .font(.caption2.weight(.black))
                            .foregroundStyle(scenicStyle.accent)
                        Text(projection.primaryTitle)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(scenicStyle.primaryText)
                    }
                    Spacer()
                    Text(projection.countdownTarget.formatted(date: .omitted, time: .shortened))
                        .font(.headline.weight(.black))
                        .foregroundStyle(scenicStyle.accentReflection)
                }
            }

            if liveActivity.isActive {
                HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                    Button("Refresh") {
                        LifeRouteHaptics.primaryAction()
                        Task { await liveActivity.update(itinerary: itinerary) }
                    }
                    .buttonStyle(ScenicRoyalSecondaryButtonStyle())

                    Button("End") {
                        LifeRouteHaptics.selection()
                        Task { await liveActivity.end() }
                    }
                    .buttonStyle(ScenicRoyalSecondaryButtonStyle())
                }
            } else {
                Button {
                    LifeRouteHaptics.primaryAction()
                    Task { await liveActivity.start(itinerary: itinerary) }
                } label: {
                    Label("Start Live Day", systemImage: "lock.iphone")
                }
                .buttonStyle(ScenicRoyalPrimaryButtonStyle())
                .disabled(LifeRouteLiveDayProjection.make(from: itinerary, at: Date()) == nil)
            }

            if let message = liveActivity.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(scenicStyle.secondaryText)
            }
        }
        .scenicRoyalCard(role: .readability)
    }

    private var dayPickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Selected day",
                selection: Binding(
                    get: { selectedDay },
                    set: { selectedDay = $0 }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Choose Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingDayPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func generateFullDay() {
        guard canGenerate else { return }
        if liveActivity.isActive {
            Task { await liveActivity.end() }
        }
        LifeRouteHaptics.primaryAction()
        planState.calculate(
            selectedDay: selectedDay,
            appointments: routeAppointments,
            beforeStops: beforeStops,
            afterStops: afterStops,
            routeBufferMinutes: routingState.routeBufferMinutes,
            homeAddress: routingState.homeAddress,
            currentLocation: routingState.currentLocation
        )
    }

    private func addRecommendation(
        _ recommendation: LifeRouteGapFillerRecommendation,
        after previousNodeID: String
    ) {
        let appointmentID = previousNodeID.hasPrefix("event:")
            ? String(previousNodeID.dropFirst("event:".count))
            : previousNodeID
        let savedPlaceID: UUID?
        switch recommendation.source {
        case .savedPlace(let id): savedPlaceID = id
        case .todo: savedPlaceID = nil
        }
        let inserted = routingState.addDayStop(
            title: recommendation.title,
            address: recommendation.address,
            position: .after,
            day: selectedDay,
            savedPlaceID: savedPlaceID,
            durationMinutes: recommendation.durationMinutes,
            afterAppointmentID: appointmentID
        )
        guard inserted else { return }
        LifeRouteHaptics.success()
        generateFullDay()
    }

    private func endLiveDayForChangedInputs() {
        guard liveActivity.isActive else { return }
        Task { await liveActivity.end() }
    }

    private func dayShiftButton(
        _ offset: Int,
        systemImage: String,
        label: String
    ) -> some View {
        Button {
            guard let shifted = Calendar.current.date(byAdding: .day, value: offset, to: selectedDay) else { return }
            selectedDay = shifted
            LifeRouteHaptics.selection()
        } label: {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .frame(
                    width: ScenicRoyalDesignSystem.Layout.minimumTouchTarget,
                    height: ScenicRoyalDesignSystem.Layout.minimumTouchTarget
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var dayContextTitle: String {
        if Calendar.current.isDateInToday(selectedDay) { return "Today" }
        if Calendar.current.isDateInTomorrow(selectedDay) { return "Tomorrow" }
        if Calendar.current.isDateInYesterday(selectedDay) { return "Yesterday" }
        return selectedDay.formatted(.dateTime.weekday(.wide))
    }

    private var startingPointLabel: String {
        if routingState.currentLocation != nil { return "Current Location" }
        if !routingState.homeAddress.isEmpty { return "Home" }
        return "Add Home in Setup"
    }

    private var emptyDayStatus: String {
        selectedDayEvents.isEmpty ? "No appointments scheduled" : "No remaining timed appointment"
    }

    private var generationBlocker: String? {
        let hasDestination = routeAppointments.contains {
            !$0.isAllDay && !$0.address.isEmpty
        } || !selectedDayStops.isEmpty
        if !hasDestination {
            return "Add a located appointment in Calendar or a saved stop to generate this day."
        }
        if routingState.currentLocation == nil && routingState.homeAddress.isEmpty {
            return "Start live location or add Home in Setup before generating."
        }
        if planState.returnHome && routingState.homeAddress.isEmpty {
            return "Add Home in Setup or turn off Return Home."
        }
        return nil
    }

    private func currentEvent(at now: Date) -> LifeRouteCalendarEvent? {
        guard Calendar.current.isDateInToday(selectedDay) else { return nil }
        return selectedDayEvents.first {
            !$0.isAllDay && $0.start <= now && $0.end > now
        }
    }

    private func nextEvent(at now: Date) -> LifeRouteCalendarEvent? {
        if Calendar.current.isDateInToday(selectedDay) {
            return selectedDayEvents.first { !$0.isAllDay && $0.start > now }
        }
        return selectedDayEvents.first { !$0.isAllDay }
    }

    private func eventStatusLine(_ event: LifeRouteCalendarEvent, now: Date) -> String {
        if event.isAllDay { return "All day" }
        if event.start <= now && event.end > now {
            return "Until \(event.end.formatted(date: .omitted, time: .shortened))"
        }
        let time = event.start.formatted(date: .omitted, time: .shortened)
        return event.location.isEmpty ? time : "\(time) · \(event.location)"
    }

    private func departureEyebrow(_ guidance: LifeRouteDepartureGuidance?) -> String {
        guard guidance != nil else { return "DEPARTURE" }
        return Calendar.current.isDateInToday(selectedDay) ? "ROUTE-AWARE" : "LEAVE BY"
    }

    private func departureHeadline(_ guidance: LifeRouteDepartureGuidance?) -> String {
        guard let guidance else {
            return selectedItinerary == nil ? "Generate route" : "Regenerate"
        }
        guard Calendar.current.isDateInToday(selectedDay) else {
            return guidance.leaveBy.formatted(date: .omitted, time: .shortened)
        }
        switch guidance.state {
        case .leaveIn:
            return "Leave in \(countdownLabel(guidance.secondsUntilDeparture))"
        case .leaveNow, .overdue:
            return "Leave now"
        }
    }

    private func nodeDetail(_ node: LifeRouteItineraryNode) -> String {
        switch node.kind {
        case .origin, .home:
            return node.address
        case .stop:
            return "\(durationLabel(node.stopDurationSeconds)) stop · \(node.address)"
        case .appointment:
            if node.isAllDay { return "All day · not used for route timing" }
            let time: String
            if let start = node.start, let end = node.end {
                time = "\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
            } else {
                time = "Time unavailable"
            }
            return node.address.isEmpty ? "\(time) · No route location" : "\(time) · \(node.address)"
        }
    }

    private func previewDetail(_ waypoint: LifeRouteDayWaypoint) -> String {
        switch waypoint.kind {
        case .appointment:
            let eventID = String(waypoint.id.dropFirst("event:".count))
            guard let event = selectedDayEvents.first(where: { $0.id == eventID }) else {
                return waypoint.address.isEmpty ? "No route location" : waypoint.address
            }
            return eventStatusLine(event, now: Date())
        case .stop:
            let stopID = String(waypoint.id.dropFirst("stop:".count))
            guard let stop = selectedDayStops.first(where: { $0.id.uuidString == stopID }) else {
                return waypoint.address
            }
            return "\(stop.durationMinutes) min · \(stop.address)"
        }
    }

    private func timelineIcon(_ kind: LifeRouteItineraryTimelineItem.Kind) -> String {
        switch kind {
        case .origin: return "location.fill"
        case .drive: return "car.fill"
        case .stop: return "mappin.and.ellipse"
        case .appointment: return "calendar"
        case .usableGap: return "hourglass.bottomhalf.filled"
        case .home: return "house.fill"
        }
    }

    private func timelineKindLabel(_ kind: LifeRouteItineraryTimelineItem.Kind) -> String {
        switch kind {
        case .origin: return "START"
        case .drive: return "DRIVE"
        case .stop: return "STOP"
        case .appointment: return "EVENT"
        case .usableGap: return "GAP"
        case .home: return "HOME"
        }
    }

    private func durationLabel(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(ceil(seconds / 60)))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }

    private func countdownLabel(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remaining = total % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes >= 10 { return "\(minutes)m" }
        return "\(minutes)m \(remaining)s"
    }

    private func distanceLabel(_ meters: Double) -> String {
        let miles = meters / 1609.344
        return miles < 0.1 ? "<0.1 mi" : String(format: "%.1f mi", miles)
    }
}
