import Foundation
import SwiftUI
import UIKit

/// Only the itinerary decides whether it can consume a new pan. At an edge,
/// its existing ancestor ScrollView gets the next swipe.
enum LifeRouteItineraryScrollPolicy {
    static func innerOwnsPan(horizontalVelocity: Double, verticalVelocity: Double,
                            offsetY: Double, minimumOffsetY: Double, maximumOffsetY: Double,
                            tolerance: Double = 0.5) -> Bool {
        guard abs(verticalVelocity) > abs(horizontalVelocity),
              maximumOffsetY > minimumOffsetY + tolerance else { return false }
        if verticalVelocity < 0, offsetY >= maximumOffsetY - tolerance { return false }
        if verticalVelocity > 0, offsetY <= minimumOffsetY + tolerance { return false }
        return verticalVelocity != 0
    }
}

private final class LifeRouteItineraryScrollView: UIScrollView {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer {
            let velocity = panGestureRecognizer.velocity(in: self)
            let minimum = -adjustedContentInset.top
            let maximum = max(minimum, contentSize.height - bounds.height + adjustedContentInset.bottom)
            guard LifeRouteItineraryScrollPolicy.innerOwnsPan(
                horizontalVelocity: velocity.x, verticalVelocity: velocity.y,
                offsetY: contentOffset.y, minimumOffsetY: minimum, maximumOffsetY: maximum
            ) else { return false }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

private struct LifeRouteItineraryContent<Content: View>: View {
    let content: Content
    let inheritedEnvironment: EnvironmentValues

    var body: some View {
        content
            .transformEnvironment(\.self) { values in
                // Relay presentation inputs without replacing the new host's
                // accessibility, gesture, focus, and presentation bridges.
                values.lifeRouteTheme = inheritedEnvironment.lifeRouteTheme
                values.lifeRoutePalette = inheritedEnvironment.lifeRoutePalette
                values.scenicRoyalThemeStyle = inheritedEnvironment.scenicRoyalThemeStyle
                values.dynamicTypeSize = inheritedEnvironment.dynamicTypeSize
                values.colorScheme = inheritedEnvironment.colorScheme
                values.legibilityWeight = inheritedEnvironment.legibilityWeight
                values.displayScale = inheritedEnvironment.displayScale
                values.horizontalSizeClass = inheritedEnvironment.horizontalSizeClass
                values.verticalSizeClass = inheritedEnvironment.verticalSizeClass
                values.layoutDirection = inheritedEnvironment.layoutDirection
                values.locale = inheritedEnvironment.locale
                values.calendar = inheritedEnvironment.calendar
                values.timeZone = inheritedEnvironment.timeZone
                values.isEnabled = inheritedEnvironment.isEnabled
            }
            .tint(inheritedEnvironment.scenicRoyalThemeStyle.selectedControlFill)
    }
}

private final class LifeRouteItineraryController<Content: View>: UIViewController {
    let scrollView = LifeRouteItineraryScrollView()
    let host: UIHostingController<LifeRouteItineraryContent<Content>>

    init(content: Content, environment: EnvironmentValues) {
        host = UIHostingController(rootView: LifeRouteItineraryContent(content: content, inheritedEnvironment: environment))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        view = scrollView
        scrollView.backgroundColor = .clear
        scrollView.bounces = false
        scrollView.alwaysBounceVertical = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.accessibilityIdentifier = "today.itinerary"
        addChild(host)
        host.view.backgroundColor = .clear
        host.sizingOptions = .intrinsicContentSize
        host.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            host.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
        host.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let maximumOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        // Keep the native accessibility container enabled even for short content.
        // The pan policy already declines every gesture when nothing overflows.
        if scrollView.contentOffset.y > maximumOffset {
            scrollView.setContentOffset(CGPoint(x: 0, y: maximumOffset), animated: false)
        }
    }
}

/// A leaf content host, with no navigation or action owner. Native fitting keeps
/// short schedules at their natural height without publishing geometry state.
private struct LifeRouteBoundedItinerary<Content: View>: UIViewControllerRepresentable {
    let maximumHeight: CGFloat
    @ViewBuilder let content: Content

    func makeUIViewController(context: Context) -> LifeRouteItineraryController<Content> {
        LifeRouteItineraryController(content: content, environment: context.environment)
    }

    func updateUIViewController(_ controller: LifeRouteItineraryController<Content>, context: Context) {
        controller.host.rootView = LifeRouteItineraryContent(content: content, inheritedEnvironment: context.environment)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController controller: LifeRouteItineraryController<Content>, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0, width.isFinite else { return nil }
        controller.loadViewIfNeeded()
        let natural = controller.host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        let height = min(maximumHeight, ceil(natural.height))
        return CGSize(width: width, height: height)
    }
}

/// UI-01 native Today proof. Calendar owns schedule browsing; Today owns
/// the selected day's route generation, canonical itinerary, departure guidance,
/// gap-fit suggestions, and Live Day projection.
struct V054TodayView: View {
    @LifeRoutePresentation private var visibility
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
            currentLocation: routingState.routeOriginLocation
        )
    }

    private var authoritativeItinerary: LifeRouteGeneratedItinerary? {
        itineraryIsCurrent ? selectedItinerary : nil
    }

    private var canGenerate: Bool {
        let hasDestination = routeAppointments.contains {
            $0.isRoutable
        } || !selectedDayStops.isEmpty
        let hasOrigin = routingState.routeOriginStatus.mode != .unavailable
        let canReturnHome = !planState.returnHome || !routingState.homeAddress.isEmpty
        return hasDestination && hasOrigin && canReturnHome
    }

    var body: some View {
        GeometryReader { geometry in
        ScrollView {
            LazyVStack(spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
                commandHeader
                TimelineView(LifeRoutePresentationClock(interval: 1, active: visibility.active)) { context in
                    itineraryCard(now: context.date, viewportHeight: geometry.size.height)
                    commandStatusContent(now: context.date)
                }
                if let itinerary = authoritativeItinerary,
                   !itinerary.usableGaps.isEmpty {
                    gapFillersCard(itinerary)
                }
                if let itinerary = authoritativeItinerary {
                    liveDayCard(itinerary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, ScenicRoyalDesignSystem.Spacing.spacious * 2)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("today.page")
        }
        .background(Color.clear)
        .foregroundStyle(UI01Material.silver)
        .tint(UI01Material.goldLight)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingDayPicker) {
            dayPickerSheet.lifeRouteModalScope()
        }
        .onAppear {
            if routingState.homeAddress.isEmpty {
                planState.returnHome = false
            }
        }
        .onChange(of: selectedDay) { _ in
            invalidateRouteForChangedInputs()
        }
        .onChange(of: selectedDayEvents) { _ in
            invalidateRouteForChangedInputs()
        }
        .onChange(of: selectedDayStops) { _ in
            invalidateRouteForChangedInputs()
        }
        .onChange(of: routingState.routeBufferMinutes) { _ in
            invalidateRouteForChangedInputs()
        }
        .onChange(of: planState.routeMode) { _ in
            invalidateRouteForChangedInputs()
        }
        .onChange(of: planState.returnHome) { _ in
            invalidateRouteForChangedInputs()
        }
        .onChange(of: routingState.routeOriginStatus.mode) { _ in
            invalidateRouteForChangedInputs()
        }
    }

    private var commandHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top) {
                    UI01BrandWordmark(showsLogo: true)
                        .modifier(UI01ReadingZone())
                    Spacer(minLength: 16)
                    liveLocationAction
                }
                VStack(alignment: .leading, spacing: 12) {
                    UI01BrandWordmark(showsLogo: true)
                        .modifier(UI01ReadingZone())
                    liveLocationAction
                }
            }
            UI01BrandFilament()
            dayControls.modifier(UI01ReadingZone())
            UI01MarbleText(title: "Today", size: 58, relativeTo: .largeTitle, branded: true)
                .modifier(UI01ReadingZone())
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 8)
            UI01Hairline().padding(.top, 8)
        }
    }

    private var liveLocationAction: some View {
        Button {
            if routingState.liveLocationEnabled {
                routingState.stopLiveLocation()
            } else {
                routingState.requestCurrentLocation()
            }
            LifeRouteHaptics.selection()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: routingState.liveLocationEnabled ? "location.slash" : "location.fill")
                    .font(.system(size: 14))
                VStack(spacing: 0) {
                    Text(routingState.liveLocationEnabled ? "Stop Live" : "Use Live")
                    Text("Location")
                }
                .font(.caption)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(routingState.liveLocationEnabled ? "Stop Live Location" : "Use Live Location")
        }
        .buttonStyle(UI01GoldButtonStyle(compact: true))
        .accessibilityHint(
            routingState.liveLocationEnabled
                ? "Stops location updates and returns routing to Home when available"
                : "Uses this iPhone's current location as the route origin"
        )
    }

    private var dayControls: some View {
        HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            dayShiftButton(-1, systemImage: "chevron.left", label: "Previous day")

            Button {
                selectedDay = Date()
                LifeRouteHaptics.selection()
            } label: {
                Text("\(dayContextTitle.uppercased()) · \(selectedDay.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased())")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                    .modifier(UI01CaptionReadingSurface())
                .frame(maxWidth: .infinity, minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Returns the command center to today")

            dayShiftButton(1, systemImage: "chevron.right", label: "Next day")
        }
        .foregroundStyle(UI01Material.secondary)
    }

    private var statusLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
    }

    private func commandStatusContent(now: Date) -> some View {
        let current = currentEvent(at: now)
        let next = nextEvent(at: now)
        let projection = authoritativeItinerary.flatMap { LifeRouteLiveDayProjection.make(from: $0, at: now) }
        let guidance = authoritativeItinerary?.departureGuidance(
            at: Calendar.current.isDateInToday(selectedDay) ? now : selectedDay
        )

        return VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
            Text(routingState.locationMessage)
                .font(.caption)
                .foregroundStyle(UI01Material.secondary)
                .fixedSize(horizontal: false, vertical: true)
            UI01Hairline()

            statusLayout {
                VStack(alignment: .leading, spacing: 3) {
                    Text(projection?.phaseLabel ?? (current == nil ? "NEXT" : "RIGHT NOW"))
                        .font(.caption2.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(UI01Material.gold)
                    Text(LifeRouteCalendarDisplay.title(projection?.primaryTitle ?? (current ?? next)?.title ?? emptyDayStatus))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(UI01Material.silver)
                        .fixedSize(horizontal: false, vertical: true)
                    if projection == nil, let event = current ?? next {
                        Text(eventStatusLine(event, now: now))
                            .font(.caption)
                            .foregroundStyle(UI01Material.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let guidance {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(departureEyebrow(guidance))
                        .font(.caption2.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(UI01Material.secondary)
                    Text(departureHeadline(guidance))
                        .font(.title3.weight(.black))
                        .foregroundStyle(UI01Material.goldLight)
                        .multilineTextAlignment(.trailing)
                    if Calendar.current.isDateInToday(selectedDay) {
                        Text("Leave by \(guidance.leaveBy.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(UI01Material.secondary)
                    }
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
                .foregroundStyle(UI01Material.secondary)
            }
        }
        .modifier(UI01ReadingZone())
    }

    private var generationAction: some View {
            Button {
                generateFullDay()
            } label: {
                HStack {
                if planState.isCalculating { ProgressView() }
                Text(planState.isCalculating
                    ? "Generating day route…"
                    : (selectedItinerary == nil ? "Generate Full Day" : "Regenerate Full Day"))
                }
            }
            .buttonStyle(UI01GoldButtonStyle())
            .disabled(planState.isCalculating || !canGenerate)
            .accessibilityIdentifier("today.generate")
    }

    private func itineraryCard(now: Date, viewportHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
            if let itinerary = selectedItinerary {
                Text("\(durationLabel(itinerary.totalRawTravelSeconds)) driving")
                    .font(.caption)
                    .foregroundStyle(UI01Material.secondary)
            }

            if selectedItinerary != nil {
                if !itineraryIsCurrent {
                    Label(
                        "Appointments, stops, location, or route settings changed. Regenerate before using departure guidance.",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(UI01Material.goldLight)
                }
            }

            LifeRouteBoundedItinerary(maximumHeight: min(280, max(132, viewportHeight * (dynamicTypeSize.isAccessibilitySize ? 0.25 : 0.38)))) {
                if let itinerary = selectedItinerary {
                    timeline(itinerary, now: now)
                } else {
                    ungeneratedTimeline(now: now)
                }
            }
            .frame(maxWidth: .infinity)
            .id(selectedDay)

            generationAction

            if let itinerary = selectedItinerary {
                startRouteControl(itinerary, now: now)
            }

            if let blocker = generationBlocker {
                Text(blocker)
                    .font(.caption)
                    .foregroundStyle(UI01Material.secondary)
                    .modifier(UI01ReadingZone())
            }

            NavigationLink {
                DayRoutePlanningView(
                    calendarState: calendarState,
                    routingState: routingState,
                    planState: planState,
                    day: selectedDay
                )
                .ui01ContentStyle()
                .lifeRouteDeepDestination()
            } label: {
                Label("Edit stops & route options", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(UI01GoldButtonStyle(compact: true))
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
                            .foregroundStyle(UI01Material.goldLight)
                    }
                    .font(.subheadline.weight(.semibold))

                    Button("Change Route Buffer in Setup") {
                        router.select(.setup)
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
            } label: {
                Label("Route settings", systemImage: "gearshape.2")
                    .font(.headline)
                    .foregroundStyle(UI01Material.silver)
            }

            .modifier(UI01ReadingZone())
            .accessibilityIdentifier("today.routeSettings")

            if !planState.isCalculating, let message = planState.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(UI01Material.secondary)
                    .modifier(UI01ReadingZone())
            }
        }
    }

    @ViewBuilder
    private func startRouteControl(_ itinerary: LifeRouteGeneratedItinerary, now: Date) -> some View {
        let decision = itinerary.startRouteDecision(
            selectedDay: selectedDay,
            itineraryIsCurrent: itineraryIsCurrent,
            now: now
        )
        switch decision {
        case .ready:
            if let plan = planState.fullRoutePlan {
                ScenicRoyalFullRouteActionButton(
                    planState: planState,
                    plan: plan,
                    triggersPrimaryHaptic: true,
                    showsLaunchingState: true,
                    disablesWhileLaunching: true
                )
            } else {
                Label(
                    "The complete route is unavailable. Regenerate this day before starting navigation.",
                    systemImage: "arrow.triangle.2.circlepath"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(UI01Material.secondary)
            }

        case .stale:
            Label("Regenerate this day before starting navigation.", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption.weight(.semibold))
                .foregroundStyle(UI01Material.secondary)

        case .wrongDay:
            Label("Generate a route for the selected day before navigating.", systemImage: "calendar.badge.exclamationmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(UI01Material.secondary)

        case .noPhysicalDestination:
            Label("No physical route destination remains for this generated day.", systemImage: "location.slash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(UI01Material.secondary)
        }
    }

    @ViewBuilder
    private func timeline(_ itinerary: LifeRouteGeneratedItinerary, now: Date) -> some View {
        let timelineItems = itinerary.timeline
        let nodes = itinerary.nodes.reduce(into: [String: LifeRouteItineraryNode]()) {
            result,
            node in
            if result[node.id] == nil {
                result[node.id] = node
            }
        }
        let projection = LifeRouteLiveDayProjection.make(from: itinerary, at: now)
        Group {
            VStack(spacing: 0) {
                ForEach(timelineItems) { item in
                    timelineRow(item, nodes: nodes, projection: projection)
                }
            }
        }
    }

    private func timelineRow(
        _ item: LifeRouteItineraryTimelineItem,
        nodes: [String: LifeRouteItineraryNode],
        projection: LifeRouteLiveDayProjection?
    ) -> some View {
        UI01TrailRow(
            active: item.node.map { projection?.currentNodeID == $0.id } ?? false,
            symbol: item.kind == .origin ? (item.node?.id == "origin:home" ? "house.fill" : "location.fill") : (item.kind == .drive ? "car" : item.kind == .home ? "house" : nil),
            spacious: item.kind == .appointment || item.kind == .stop
        ) {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 3) {
                    switch item.kind {
                    case .drive:
                        if let leg = item.leg {
                            Text("\(durationLabel(leg.rawTravelSeconds)) drive")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(UI01Material.silver)
                            let destination = LifeRouteCalendarDisplay.title(nodes[leg.toNodeID]?.title ?? "next stop")
                            Text("To \(destination) · \(distanceLabel(leg.rawDistanceMeters))")
                                .font(.caption)
                                .foregroundStyle(UI01Material.secondary)
                        }
                    case .usableGap:
                        if let gap = item.gap {
                            Text(gap.usableSeconds.map { "\(durationLabel($0)) usable" } ?? "Route data needed")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(UI01Material.silver)
                            Text("Calendar gap \(durationLabel(gap.rawCalendarGapSeconds)) · travel, planned stops, and buffer already deducted")
                                .font(.caption)
                                .foregroundStyle(UI01Material.secondary)
                        }
                    case .origin, .appointment, .stop, .home:
                        if let node = item.node {
                            UI01MarbleText(title: LifeRouteCalendarDisplay.title(node.title), size: 24, relativeTo: .title2)
                            if projection?.completedNodeIDs.contains(node.id) == true {
                                Text("Scheduled complete").font(.caption2.weight(.semibold))
                            } else if projection?.currentNodeID == node.id {
                                Text(projection?.phase == .eventActive ? "Active now" : "Current in plan")
                                    .font(.caption2.weight(.semibold))
                            }
                            Text(nodeDetail(node))
                                .font(.caption)
                                .foregroundStyle(UI01Material.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(timelineKindLabel(item.kind))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(UI01Material.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func ungeneratedTimeline(now: Date) -> some View {
        let waypoints = LifeRouteDaySequenceBuilder.waypoints(
            appointments: routeAppointments,
            beforeStops: beforeStops,
            afterStops: afterStops
        )
        return VStack(spacing: 0) {
            UI01TrailRow(symbol: startingPointIcon, spacious: false) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Starting from").font(.caption)
                        .foregroundStyle(UI01Material.secondary)
                    Text(startingPointLabel)
                        .font(.body)
                        .foregroundStyle(UI01Material.silver)
                }
            }
            if waypoints.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    UI01MarbleText(title: "No appointments or saved stops yet", size: 27)
                        .modifier(UI01ReadingZone())
                    Button("Open Calendar") {
                        router.select(.schedule)
                    }
                    .buttonStyle(UI01GoldButtonStyle(compact: true))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(waypoints) { waypoint in
                        previewRow(waypoint, now: now)
                    }
                }
            }
        }
    }

    private func previewRow(_ waypoint: LifeRouteDayWaypoint, now: Date) -> some View {
        let appointment = routeAppointments.first { "event:\($0.id)" == waypoint.id }
        let active = appointment.map { $0.id == currentEvent(at: now)?.id } ?? false
        return UI01TrailRow(active: active) {
            VStack(alignment: .leading, spacing: 3) {
                if let appointment {
                    Text(appointment.isAllDay ? "All day" : "\(appointment.start.formatted(date: .omitted, time: .shortened)) – \(appointment.end.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(active ? UI01Material.goldLight : UI01Material.silver)
                }
                UI01MarbleText(title: LifeRouteCalendarDisplay.title(waypoint.title), size: 26, relativeTo: .title2)
                if appointment != nil {
                    Text(waypoint.address.isEmpty ? "No physical location" : waypoint.address)
                        .font(.body)
                        .foregroundStyle(UI01Material.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(previewDetail(waypoint, now: now))
                        .font(.body)
                        .foregroundStyle(UI01Material.secondary)
                }
                Text(active ? "Event · Active now" : waypoint.kind == .stop ? "Stop" : "Event")
                    .font(.caption2)
                    .foregroundStyle(active ? UI01Material.goldLight : UI01Material.secondary)
            }
        }
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
                UI01MarbleText(title: "Gap Fillers", size: 26)
                    .accessibilityAddTraits(.isHeader)
                Text("Only activities that fit after route time and buffer are eligible.")
                    .font(.caption)
                    .foregroundStyle(UI01Material.secondary)
            }
        }
        .modifier(UI01ReadingZone())
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
                        .foregroundStyle(UI01Material.secondary)
                    Text(gap.usableSeconds.map { "Actual usable gap: \(durationLabel($0))" } ?? "Actual usable gap: route unavailable")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(UI01Material.goldLight)
                }
                Spacer()
                if planState.gapEvaluationInFlight.contains(gap.id) {
                    ProgressView().tint(UI01Material.gold)
                }
            }

            if let recommendations = planState.gapRecommendationsByGapID[gap.id] {
                if recommendations.isEmpty {
                    Text("No saved place or To-Do currently fits this route-safe gap.")
                        .font(.caption)
                        .foregroundStyle(UI01Material.secondary)
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
                .buttonStyle(UI01GoldButtonStyle(compact: true))
                .disabled(!gap.isRouteSafe)
            }
        }
        .padding(ScenicRoyalDesignSystem.Spacing.compact)
        .modifier(UI01ReadingZone())
    }

    private func recommendationRow(
        _ recommendation: LifeRouteGapFillerRecommendation,
        gap: LifeRouteUsableGap
    ) -> some View {
        HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(UI01Material.silver)
                Text("Fits · \(recommendation.durationMinutes) min")
                    .font(.caption)
                    .foregroundStyle(UI01Material.secondary)
            }
            Spacer()
            if !recommendation.address.isEmpty {
                Button {
                    addRecommendation(recommendation, after: gap.previousAppointmentNodeID)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(UI01Material.gold)
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
                UI01MarbleText(title: "Live Day", size: 26)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if liveActivity.isRunning {
                    Text("IN APP")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color.black.opacity(0.78))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(UI01Material.gold, in: Capsule())
                }
            }

            Text("Follows the generated schedule. The Lock Screen shows when a phase needs an update.")
                .font(.caption)
                .foregroundStyle(UI01Material.secondary)

            TimelineView(LifeRoutePresentationClock(interval: 1, active: visibility.active)) { context in
                if let projection = LifeRouteLiveDayProjection.make(from: itinerary, at: context.date) {
                HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(projection.phaseLabel)
                            .font(.caption2.weight(.black))
                            .foregroundStyle(UI01Material.gold)
                        Text(LifeRouteCalendarDisplay.title(projection.primaryTitle))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(UI01Material.silver)
                    }
                    Spacer()
                    if let deadline = projection.countdownTarget {
                        Text(deadline.formatted(date: .omitted, time: .shortened))
                            .font(.headline.weight(.black))
                            .foregroundStyle(UI01Material.goldLight)
                    }
                }
                }
            }

            if liveActivity.isRunning {
                HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                    Button("Refresh") {
                        LifeRouteHaptics.primaryAction()
                        Task { await liveActivity.update(itinerary: itinerary) }
                    }
                    .buttonStyle(UI01GoldButtonStyle(compact: true))

                    Button("End") {
                        LifeRouteHaptics.selection()
                        Task { await liveActivity.end() }
                    }
                    .buttonStyle(UI01GoldButtonStyle(compact: true))
                }
            } else {
                Button {
                    LifeRouteHaptics.primaryAction()
                    Task { await liveActivity.start(itinerary: itinerary) }
                } label: {
                    Label("Start Live Day", systemImage: "figure.walk.motion")
                }
                .buttonStyle(UI01GoldButtonStyle())
            }

            Label(
                liveActivity.activityStatus.userFacingDetail,
                systemImage: liveActivity.isLockScreenActive ? "lock.iphone" : "iphone.slash"
            )
            .font(.caption)
            .foregroundStyle(liveActivity.isLockScreenActive ? UI01Material.gold : UI01Material.secondary)

            if !liveActivity.isLockScreenActive, let message = liveActivity.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(UI01Material.secondary)
            }
        }
        .modifier(UI01ReadingZone())
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
        if liveActivity.isRunning {
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
            currentLocation: routingState.routeOriginLocation
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

    private func invalidateRouteForChangedInputs() {
        planState.cancel()
        endLiveDayForChangedInputs()
    }

    private func endLiveDayForChangedInputs() {
        guard liveActivity.isRunning else { return }
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
        let status = routingState.routeOriginStatus
        switch status.mode {
        case .liveCurrentLocation:
            return "Live / Current Location"
        case .home:
            return status.isLocating ? "Home · locating" : "Home"
        case .unavailable:
            return status.isLocating ? "Current Location · locating" : "Unavailable"
        }
    }

    private var startingPointIcon: String {
        switch routingState.routeOriginStatus.mode {
        case .liveCurrentLocation: return "location.fill"
        case .home: return "house.fill"
        case .unavailable: return "location.slash.fill"
        }
    }

    private var emptyDayStatus: String {
        selectedDayEvents.isEmpty ? "No appointments scheduled" : "No remaining timed appointment"
    }

    private var generationBlocker: String? {
        let hasDestination = routeAppointments.contains {
            $0.isRoutable
        } || !selectedDayStops.isEmpty
        if !hasDestination {
            return "Add a located appointment in Calendar or a saved stop to generate this day."
        }
        if routingState.routeOriginStatus.mode == .unavailable {
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

    private func departureEyebrow(_ guidance: LifeRouteDepartureGuidance) -> String {
        return Calendar.current.isDateInToday(selectedDay) ? "ROUTE-AWARE" : "LEAVE BY"
    }

    private func departureHeadline(_ guidance: LifeRouteDepartureGuidance) -> String {
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

    private func previewDetail(_ waypoint: LifeRouteDayWaypoint, now: Date) -> String {
        switch waypoint.kind {
        case .appointment:
            let eventID = String(waypoint.id.dropFirst("event:".count))
            guard let event = selectedDayEvents.first(where: { $0.id == eventID }) else {
                return waypoint.address.isEmpty ? "No route location" : waypoint.address
            }
            return eventStatusLine(event, now: now)
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
