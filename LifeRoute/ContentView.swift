import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var lifecycleState = AppLifecycleCore()
    @StateObject private var router = AppRouter()
    @StateObject private var calendarState = CalendarCoreState()
    @StateObject private var providerState = CalendarProviderCore()
    @StateObject private var routingState = RoutingLocationCore()
    @StateObject private var clientState = ClientProfileCore()
    @StateObject private var toolsState = SessionToolsCore()

    var body: some View {
        TabView(selection: $router.selectedSection) {
            NavigationStack(path: $router.todayPath) {
                TodayCoreView(router: router, calendarState: calendarState, routingState: routingState)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDetailView(route: route, router: router)
                    }
            }
            .tabItem { Label(AppSection.today.title, systemImage: AppSection.today.systemImage) }
            .tag(AppSection.today)

            NavigationStack(path: $router.schedulePath) {
                ScheduleCoreView(router: router, calendarState: calendarState, providerState: providerState)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDetailView(route: route, router: router)
                    }
            }
            .tabItem { Label(AppSection.schedule.title, systemImage: AppSection.schedule.systemImage) }
            .tag(AppSection.schedule)

            NavigationStack(path: $router.toolsPath) {
                SessionToolsNativeView(router: router, toolsState: toolsState, clientState: clientState)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDetailView(route: route, router: router)
                    }
            }
            .tabItem { Label(AppSection.tools.title, systemImage: AppSection.tools.systemImage) }
            .tag(AppSection.tools)

            NavigationStack(path: $router.resourcesPath) {
                ResourcesCoreView(router: router)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDetailView(route: route, router: router)
                    }
            }
            .tabItem { Label(AppSection.resources.title, systemImage: AppSection.resources.systemImage) }
            .tag(AppSection.resources)

            NavigationStack(path: $router.setupPath) {
                SetupCoreView(router: router, routingState: routingState, clientState: clientState)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDetailView(route: route, router: router)
                    }
            }
            .tabItem { Label(AppSection.setup.title, systemImage: AppSection.setup.systemImage) }
            .tag(AppSection.setup)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                routingState.resumeForegroundLocationIfNeeded()
                return
            }

            lifecycleState.flushPersistenceForSceneTransition()
            if phase == .background {
                routingState.cancelPendingOperations()
            }
        }
    }
}

private struct CoreHeader: View {
    @Environment(\.lifeRoutePalette) private var palette

    let title: String
    let subtitle: String
    var systemImage: String = "sparkles"

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [palette.accent.opacity(0.20), palette.accentSecondary.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 48, height: 48)
            .shadow(color: palette.accent.opacity(0.12), radius: 12)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct TodayCoreView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @EnvironmentObject private var themeStore: LifeRouteThemeStore

    @ObservedObject var router: AppRouter
    @ObservedObject var calendarState: CalendarCoreState
    @ObservedObject var routingState: RoutingLocationCore

    @State private var routeMode: LifeRouteTransportMode = .driving
    @State private var liveDayEnabled = false
    @State private var generatedAt: Date?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                dashboardHero
                quickActions
                todaySnapshot
                liveDayCard
                routePlanner
                savedPlaces
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var todayEvents: [LifeRouteCalendarEvent] {
        calendarState.events(on: Date()).sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private var dashboardHero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.panelElevated.opacity(0.96),
                            palette.panel.opacity(0.78),
                            palette.backgroundBottom.opacity(0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            LifeRouteThemeArtwork(theme: themeStore.selectedTheme, palette: themeStore.selectedTheme.palette)
                .clipShape(RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous))

            LinearGradient(
                colors: [.clear, palette.backgroundBottom.opacity(0.70)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous))

            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("LIFEROUTE")
                        .font(.caption.weight(.black))
                        .tracking(2.3)
                        .foregroundStyle(palette.accent)

                    Spacer()

                    HStack(spacing: 6) {
                        Circle()
                            .fill(palette.accent)
                            .frame(width: 7, height: 7)
                        Text(themeStore.selectedTheme.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.20), in: Capsule())
                }

                Text("Own your day.")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text("Plan your day. Optimize every gap.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textPrimary.opacity(0.88))

                HStack(spacing: 8) {
                    Image(systemName: routingState.liveLocationEnabled ? "location.fill.viewfinder" : "location.fill")
                        .foregroundStyle(palette.accent)
                    Text(routingState.locationRequestInFlight ? "Locating…" : routingState.locationMessage)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .foregroundStyle(palette.textSecondary)
                    Spacer()
                }
            }
            .padding(22)
        }
        .frame(minHeight: 226)
        .overlay {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [palette.accent.opacity(0.48), Color.white.opacity(0.08), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: palette.accent.opacity(0.14), radius: 30, y: 13)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("Quick actions", subtitle: "Jump into the things you use most.")

            HStack(spacing: 10) {
                DashboardActionButton(
                    title: routingState.liveLocationEnabled ? "Live GPS" : "Locate",
                    subtitle: routingState.liveLocationEnabled ? "Tracking" : "Use GPS",
                    systemImage: routingState.liveLocationEnabled ? "location.fill.viewfinder" : "location.fill",
                    prominent: true
                ) {
                    if routingState.liveLocationEnabled {
                        routingState.stopLiveLocation()
                    } else {
                        routingState.requestCurrentLocation()
                    }
                }
                .disabled(routingState.locationRequestInFlight)

                DashboardActionButton(title: "Schedule", subtitle: "See the day", systemImage: "calendar") {
                    router.select(.schedule)
                }
            }

            HStack(spacing: 10) {
                DashboardActionButton(title: "Session", subtitle: "Open tools", systemImage: "wrench.and.screwdriver.fill") {
                    router.select(.tools)
                }

                DashboardActionButton(title: "Setup", subtitle: "Places & clients", systemImage: "slider.horizontal.3") {
                    router.select(.setup)
                }
            }
        }
    }

    private var todaySnapshot: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("Today’s overview", subtitle: "Calendar and routing state at a glance.")

            HStack(spacing: 9) {
                TodayMetricTile(
                    value: "\(todayEvents.count)",
                    label: "Events",
                    systemImage: "calendar",
                    accent: palette.accent
                )
                TodayMetricTile(
                    value: "\(routingState.savedPlaces.filter(\.useInGapSuggestions).count)",
                    label: "Gap-ready",
                    systemImage: "sparkles",
                    accent: palette.accentSecondary
                )
                TodayMetricTile(
                    value: routingState.liveLocationEnabled ? "LIVE" : (routingState.homeAddress.isEmpty ? "—" : "HOME"),
                    label: "Origin",
                    systemImage: routingState.liveLocationEnabled ? "location.fill" : "house.fill",
                    accent: palette.accent
                )
            }
        }
    }

    private var liveDayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(palette.accent.opacity(0.15))
                    Image(systemName: liveDayEnabled ? "bolt.horizontal.circle.fill" : "sparkles")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(palette.accent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(liveDayEnabled ? "Live Day" : "Generate your day")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text(liveDayEnabled ? "Your calendar is now a live, time-aware sequence." : "Turn today’s calendar into a live sequence with countdowns and known route timing.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if liveDayEnabled {
                    Text("LIVE")
                        .font(.caption2.weight(.black))
                        .tracking(1.1)
                        .foregroundStyle(Color.black.opacity(0.78))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(palette.accent, in: Capsule())
                }
            }

            if liveDayEnabled {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    LiveDayTimeline(
                        now: context.date,
                        events: todayEvents,
                        routingState: routingState
                    )
                }

                HStack(spacing: 9) {
                    Button {
                        generatedAt = Date()
                        LifeRouteHaptics.selection()
                    } label: {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())

                    Button {
                        liveDayEnabled = false
                        generatedAt = nil
                    } label: {
                        Label("End Live Day", systemImage: "stop.fill")
                    }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())
                }

                if let generatedAt {
                    Text("Generated \(generatedAt.formatted(date: .omitted, time: .shortened)). Route-aware leave times appear when a saved-place route estimate is available.")
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                }
            } else {
                Button {
                    liveDayEnabled = true
                    generatedAt = Date()
                    LifeRouteHaptics.primaryAction()
                } label: {
                    Label("Generate day", systemImage: "sparkles")
                }
                .buttonStyle(LifeRoutePrimaryButtonStyle())
            }
        }
        .lifeRouteCard()
    }

    private var routePlanner: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Route mode")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text("Used for estimates and Maps handoff.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle().fill(palette.accent.opacity(0.14))
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .foregroundStyle(palette.accent)
                }
                .frame(width: 38, height: 38)
            }

            Picker("Travel mode", selection: $routeMode) {
                ForEach(LifeRouteTransportMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if let routeMessage = routingState.routeMessage {
                Label(routeMessage, systemImage: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .lifeRouteCard()
    }

    private var savedPlaces: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Saved places", subtitle: "Estimate a route or hand it off to Apple Maps.")

            if routingState.savedPlaces.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(palette.accent)
                    Text("No saved places yet")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text("Add favorites like home, the gym, stores, or service locations in Setup.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.textSecondary)
                    Button {
                        router.select(.setup)
                    } label: {
                        Label("Add a place", systemImage: "plus")
                    }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .lifeRouteCard()
            } else {
                ForEach(routingState.savedPlaces) { place in
                    SavedPlaceDashboardCard(
                        place: place,
                        estimate: routingState.routeEstimates[place.id],
                        routeBusy: routingState.routeRequestsInFlight.contains(place.id),
                        mapsBusy: routingState.mapsOpenInFlight,
                        onEstimate: { routingState.calculateRoute(to: place, mode: routeMode) },
                        onMaps: { routingState.openInAppleMaps(place, mode: routeMode) }
                    )
                }
            }
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LiveDayTimeline: View {
    @Environment(\.lifeRoutePalette) private var palette

    let now: Date
    let events: [LifeRouteCalendarEvent]
    @ObservedObject var routingState: RoutingLocationCore

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            if let next = nextRelevantEvent {
                VStack(alignment: .leading, spacing: 5) {
                    Text(countdownKicker(for: next))
                        .font(.caption2.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(palette.accent)
                    Text(countdownText(for: next))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(palette.textPrimary)
                    Text(next.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(13)
                .background(palette.panelElevated.opacity(0.38), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            } else if events.isEmpty {
                Text("No calendar events today. Your Live Day is open for saved-place and gap planning.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            } else {
                Label("Today’s scheduled events are complete", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.accentSecondary)
            }

            if !events.isEmpty {
                ForEach(events) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(event.end <= now ? palette.textSecondary.opacity(0.30) : palette.accent)
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(event.end <= now ? palette.textSecondary : palette.textPrimary)
                            Text(eventTimeLabel(event))
                                .font(.caption2)
                                .foregroundStyle(palette.textSecondary)
                            if !event.location.isEmpty {
                                Text(event.location)
                                    .font(.caption2)
                                    .foregroundStyle(palette.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var nextRelevantEvent: LifeRouteCalendarEvent? {
        events.first { $0.end > now }
    }

    private func matchingEstimate(for event: LifeRouteCalendarEvent) -> LifeRouteRouteEstimate? {
        guard !event.location.isEmpty else { return nil }
        let normalized = event.location.lowercased()
        guard let place = routingState.savedPlaces.first(where: {
            normalized.contains($0.address.lowercased()) ||
            $0.address.lowercased().contains(normalized) ||
            normalized.contains($0.name.lowercased())
        }) else { return nil }
        return routingState.routeEstimates[place.id]
    }

    private func leaveDate(for event: LifeRouteCalendarEvent) -> Date? {
        guard event.start > now, let estimate = matchingEstimate(for: event) else { return nil }
        return event.start.addingTimeInterval(-(estimate.travelTimeSeconds + 10 * 60))
    }

    private func countdownKicker(for event: LifeRouteCalendarEvent) -> String {
        if event.start <= now && event.end > now { return "CURRENT EVENT" }
        if let leave = leaveDate(for: event), leave > now { return "LEAVE IN" }
        return "NEXT EVENT IN"
    }

    private func countdownText(for event: LifeRouteCalendarEvent) -> String {
        if event.start <= now && event.end > now {
            return timeRemaining(until: event.end)
        }
        if let leave = leaveDate(for: event), leave > now {
            return timeRemaining(until: leave)
        }
        return timeRemaining(until: event.start)
    }

    private func timeRemaining(until target: Date) -> String {
        let seconds = max(0, Int(ceil(target.timeIntervalSince(now))))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes >= 10 { return "\(minutes)m" }
        return "\(minutes)m \(remainingSeconds)s"
    }

    private func eventTimeLabel(_ event: LifeRouteCalendarEvent) -> String {
        if event.isAllDay { return "All day" }
        return "\(event.start.formatted(date: .omitted, time: .shortened))–\(event.end.formatted(date: .omitted, time: .shortened))"
    }
}

private struct DashboardActionButton: View {
    @Environment(\.lifeRoutePalette) private var palette

    let title: String
    let subtitle: String
    let systemImage: String
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(prominent ? palette.accent.opacity(0.20) : Color.white.opacity(0.06))
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(prominent ? palette.accent : palette.textPrimary)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                }

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(LifeRouteSecondaryButtonStyle())
    }
}

private struct TodayMetricTile: View {
    @Environment(\.lifeRoutePalette) private var palette

    let value: String
    let label: String
    let systemImage: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                Spacer()
            }
            Text(value)
                .font(.title2.weight(.black))
                .foregroundStyle(palette.textPrimary)
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .lineLimit(1)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(12)
        .background(palette.panelGradient, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(accent.opacity(0.20), lineWidth: 1)
        }
    }
}

private struct SavedPlaceDashboardCard: View {
    @Environment(\.lifeRoutePalette) private var palette

    let place: LifeRouteSavedPlace
    let estimate: LifeRouteRouteEstimate?
    let routeBusy: Bool
    let mapsBusy: Bool
    let onEstimate: () -> Void
    let onMaps: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(palette.accent.opacity(0.15))
                    Image(systemName: placeSymbol)
                        .foregroundStyle(palette.accent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text(place.address)
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                if place.useInGapSuggestions {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.accentSecondary)
                        .padding(7)
                        .background(palette.accentSecondary.opacity(0.10), in: Circle())
                }
            }

            if let estimate {
                HStack(spacing: 7) {
                    Label(estimate.durationLabel, systemImage: "clock.fill")
                    Text("•")
                    Text(estimate.distanceLabel)
                    Text("•")
                    Text(estimate.mode.rawValue)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.accentSecondary)
            } else {
                Text("Useful visit: \(place.minimumVisitMinutes) min")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
            }

            HStack(spacing: 9) {
                Button(action: onEstimate) {
                    Label(routeBusy ? "Estimating…" : "Estimate", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
                .disabled(routeBusy)

                Button(action: onMaps) {
                    Label(mapsBusy ? "Opening…" : "Maps", systemImage: "map.fill")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
                .disabled(mapsBusy)
            }
        }
        .lifeRouteCard()
    }

    private var placeSymbol: String {
        switch place.kind {
        case .gym: return "figure.strengthtraining.traditional"
        case .work: return "briefcase.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .grocery: return "cart.fill"
        case .park: return "leaf.fill"
        case .library: return "books.vertical.fill"
        case .errand: return "checklist"
        case .other: return "mappin.circle.fill"
        }
    }
}

private struct ScheduleCoreView: View {
    @Environment(\.lifeRoutePalette) private var palette

    @ObservedObject var router: AppRouter
    @ObservedObject var calendarState: CalendarCoreState
    @ObservedObject var providerState: CalendarProviderCore
    @State private var selectedRange: LifeRouteCalendarRange = .day
    @State private var draftTitle = ""
    @State private var draftDate = Date()
    @State private var draftStart = Date()
    @State private var draftEnd = Date().addingTimeInterval(3_600)
    @State private var draftLocation = ""
    @State private var draftAllDay = false
    @State private var formMessage: String?

    var body: some View {
        let presentation = calendarState.presentation(for: selectedRange)

        Form {
            Section {
                VStack(spacing: 14) {
                    CoreHeader(
                        title: "Schedule",
                        subtitle: "Your day, connected calendars, and manual LifeRoute appointments in one place.",
                        systemImage: "calendar.badge.clock"
                    )

                    HStack(spacing: 9) {
                        ScheduleMetricTile(
                            value: "\(presentation.eventCount)",
                            label: "Events",
                            systemImage: "calendar",
                            accent: palette.accent
                        )
                        ScheduleMetricTile(
                            value: timedHoursLabel(presentation.timedMinutes),
                            label: "Timed",
                            systemImage: "clock.fill",
                            accent: palette.accentSecondary
                        )
                        ScheduleMetricTile(
                            value: "\(connectedProviderCount)",
                            label: "Connected",
                            systemImage: "link",
                            accent: palette.accent
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)

            Section("View") {
                Picker("Schedule range", selection: $selectedRange) {
                    ForEach(LifeRouteCalendarRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Period") {
                HStack(spacing: 14) {
                    Button { calendarState.shiftSelection(selectedRange, by: -1) } label: {
                        Label("Previous", systemImage: "chevron.left")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)

                    Spacer()

                    VStack(spacing: 2) {
                        Text(calendarState.periodLabel(for: selectedRange))
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text("\(presentation.eventCount) events")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(palette.textSecondary)
                    }

                    Spacer()

                    Button { calendarState.shiftSelection(selectedRange, by: 1) } label: {
                        Label("Next", systemImage: "chevron.right")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                }

                DatePicker("Selected date", selection: $calendarState.selectedDate, displayedComponents: .date)
                Button("Jump to today") { calendarState.selectToday() }
                Label("\(presentation.eventCount) events · \(presentation.timedMinutes) timed minutes", systemImage: "clock")
                    .foregroundStyle(palette.textSecondary)
                    .font(.caption)
            }

            Section("Events") {
                CalendarEventsView(presentation: presentation) { eventID in
                    calendarState.removeEvent(id: eventID)
                }
            }

            Section("Calendar connections") {
                LabeledContent("Apple Calendar", value: providerState.appleStatus)
                Button(providerState.appleConnected ? "Refresh Apple Calendar" : "Connect Apple Calendar") {
                    providerState.connectOrRefreshApple { events in
                        calendarState.replaceProviderEvents(events, source: .apple)
                    }
                }
                .disabled(providerState.appleBusy)

                LabeledContent("Google Calendar", value: providerState.googleStatus)
                Button(providerState.googleConnected ? "Refresh Google Calendar" : "Connect Google Calendar") {
                    providerState.connectOrRefreshGoogle { events in
                        calendarState.replaceProviderEvents(events, source: .google)
                    }
                }
                .disabled(providerState.googleBusy)

                if providerState.googleConnected {
                    Button("Disconnect Google Calendar", role: .destructive) {
                        providerState.disconnectGoogle()
                        calendarState.removeProviderEvents(source: .google)
                    }
                }

                Text("Providers refresh only when you request it. Google access is read-only and its refresh token is stored in Keychain.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Section("Add appointment") {
                TextField("Appointment title", text: $draftTitle)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                TextField("Location (optional)", text: $draftLocation)
                    .textContentType(.fullStreetAddress)
                DatePicker("Date", selection: $draftDate, displayedComponents: .date)
                Toggle("All day", isOn: $draftAllDay)

                if !draftAllDay {
                    DatePicker("Starts", selection: $draftStart, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $draftEnd, displayedComponents: .hourAndMinute)
                }

                Button("Add appointment") { addAppointment() }
                    .buttonStyle(LifeRoutePrimaryButtonStyle())

                if let formMessage {
                    Text(formMessage)
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }

                Text("Manual LifeRoute appointments are saved locally. Apple and Google events remain provider-refreshed data and are not copied into LifeRoute’s local data file.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var connectedProviderCount: Int {
        (providerState.appleConnected ? 1 : 0) + (providerState.googleConnected ? 1 : 0)
    }

    private func timedHoursLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining == 0 ? "\(hours)h" : "\(hours)h \(remaining)m"
    }

    private func addAppointment() {
        do {
            try calendarState.addManualEvent(
                title: draftTitle,
                date: draftDate,
                startTime: draftStart,
                endTime: draftEnd,
                location: draftLocation,
                isAllDay: draftAllDay
            )
            formMessage = "Appointment saved locally on this iPhone."
            draftTitle = ""
            draftLocation = ""
        } catch {
            formMessage = error.localizedDescription
        }
    }
}

private struct ScheduleMetricTile: View {
    @Environment(\.lifeRoutePalette) private var palette

    let value: String
    let label: String
    let systemImage: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .padding(10)
        .background(palette.panelGradient, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(accent.opacity(0.20), lineWidth: 1)
        }
    }
}

private struct CalendarEventsView: View {
    @Environment(\.lifeRoutePalette) private var palette

    let presentation: LifeRouteCalendarRangePresentation
    let onDeleteManualEvent: (LifeRouteCalendarEvent.ID) -> Void

    var body: some View {
        switch presentation.range {
        case .day:
            eventRows(presentation.days.first?.events ?? [])
        case .week:
            ForEach(presentation.days) { day in
                VStack(alignment: .leading, spacing: 9) {
                    dayHeader(day.date)
                    if day.events.isEmpty {
                        Text("No events")
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(day.events) { event in
                            eventRow(event)
                        }
                    }
                }
                .padding(.vertical, 5)
            }
        case .month:
            if presentation.days.isEmpty {
                Text("No events this month").foregroundStyle(palette.textSecondary)
            } else {
                ForEach(presentation.days) { day in
                    VStack(alignment: .leading, spacing: 9) {
                        dayHeader(day.date)
                        ForEach(day.events) { event in
                            eventRow(event)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }

    @ViewBuilder
    private func eventRows(_ events: [LifeRouteCalendarEvent]) -> some View {
        if events.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(palette.accent)
                Text("No events on this day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        } else {
            ForEach(events) { event in
                eventRow(event)
            }
        }
    }

    private func dayHeader(_ date: Date) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(palette.accent)
                .frame(width: 7, height: 7)
            Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.textPrimary)
        }
    }

    private func eventRow(_ event: LifeRouteCalendarEvent) -> some View {
        CalendarEventRow(event: event, onDeleteManualEvent: onDeleteManualEvent)
    }
}

private struct CalendarEventRow: View {
    @Environment(\.lifeRoutePalette) private var palette

    let event: LifeRouteCalendarEvent
    let onDeleteManualEvent: (LifeRouteCalendarEvent.ID) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(sourceColor)
                .frame(width: 4, height: 62)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(event.title)
                        .font(.body.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                    Spacer(minLength: 8)
                    Text(sourceLabel)
                        .font(.caption2.weight(.black))
                        .tracking(0.5)
                        .foregroundStyle(sourceColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(sourceColor.opacity(0.10), in: Capsule())
                }

                Text(timeLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)

                if !event.location.isEmpty {
                    Label(event.location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if event.source == .manual {
                Button(role: .destructive) {
                    onDeleteManualEvent(event.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.bold))
                }
                .accessibilityLabel("Delete \(event.title)")
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
        }
    }

    private var sourceColor: Color {
        switch event.source {
        case .manual: return palette.accent
        case .apple: return .blue
        case .google: return .green
        case .calendarLink: return palette.accentSecondary
        }
    }

    private var sourceLabel: String {
        switch event.source {
        case .manual: return "LIFEROUTE"
        case .apple: return "APPLE"
        case .google: return "GOOGLE"
        case .calendarLink: return "LINK"
        }
    }

    private var timeLabel: String {
        if event.isAllDay {
            return "All day · \(event.source.rawValue)"
        }
        return "\(event.start.formatted(date: .omitted, time: .shortened))–\(event.end.formatted(date: .omitted, time: .shortened)) · \(event.source.rawValue)"
    }
}

private struct ResourcesCoreView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var router: AppRouter

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                CoreHeader(
                    title: "Resources",
                    subtitle: "Fast access to the parts of LifeRoute you need during a workday.",
                    systemImage: "books.vertical.fill"
                )
                .lifeRouteCard()

                ResourceMenuCard(
                    title: "Session tools",
                    subtitle: "Visual timer, quick notes, First / Then, and session planning.",
                    systemImage: "wrench.and.screwdriver.fill"
                ) {
                    router.select(.tools)
                }

                ResourceMenuCard(
                    title: "Setup & clients",
                    subtitle: "Manage client profiles, saved places, and app appearance.",
                    systemImage: "person.2.fill"
                ) {
                    router.select(.setup)
                }

                ResourceMenuCard(
                    title: "Schedule",
                    subtitle: "Review your day and connected calendar events.",
                    systemImage: "calendar"
                ) {
                    router.select(.schedule)
                }

                Text("More curated RBT references can be added here without changing LifeRoute’s core navigation.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .padding(.top, 6)
            }
            .padding(18)
        }
        .navigationTitle("Resources")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ResourceMenuCard: View {
    @Environment(\.lifeRoutePalette) private var palette

    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.accent.opacity(0.14))
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(palette.accent)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .lifeRouteCard()
    }
}

private struct SetupCoreView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @EnvironmentObject private var themeStore: LifeRouteThemeStore

    @ObservedObject var router: AppRouter
    @ObservedObject var routingState: RoutingLocationCore
    @ObservedObject var clientState: ClientProfileCore

    @StateObject private var homeAutocomplete = LifeRouteAddressAutocomplete()
    @StateObject private var placeAutocomplete = LifeRouteAddressAutocomplete()

    @State private var homeDraft = ""
    @State private var placeName = ""
    @State private var placeAddress = ""
    @State private var placeKind: LifeRoutePlaceKind = .other
    @State private var placeMinutes = 60
    @State private var placeSuggestions = true
    @State private var placeMessage: String?

    var body: some View {
        Form {
            Section {
                VStack(spacing: 14) {
                    CoreHeader(
                        title: "Setup",
                        subtitle: "Personalize LifeRoute, manage clients, and teach it the places in your routine.",
                        systemImage: "slider.horizontal.3"
                    )

                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(themeStore.selectedTheme.palette.backgroundGradient)
                            LifeRouteThemeArtwork(
                                theme: themeStore.selectedTheme,
                                palette: themeStore.selectedTheme.palette,
                                compact: true
                            )
                        }
                        .frame(width: 62, height: 62)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current look")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.textSecondary)
                            Text(themeStore.selectedTheme.name)
                                .font(.title3.weight(.black))
                                .foregroundStyle(palette.textPrimary)
                            Text(themeStore.selectedTheme.category.rawValue)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(palette.accent)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(palette.panelGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)

            Section("Appearance") {
                NavigationLink("Theme Center", destination: ThemeCenterView())
                    .font(.headline)
                Text("Each theme now carries its own artwork as well as its own palette.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Section("Location") {
                Label(routingState.locationMessage, systemImage: routingState.liveLocationEnabled ? "location.fill.viewfinder" : "location.fill")
                    .foregroundStyle(palette.textSecondary)

                Button(routingState.liveLocationEnabled ? "Stop live location" : "Start live current location") {
                    if routingState.liveLocationEnabled {
                        routingState.stopLiveLocation()
                    } else {
                        routingState.requestCurrentLocation()
                    }
                }
                .disabled(routingState.locationRequestInFlight)

                Text("LifeRoute uses standard When In Use location updates while the app is in the foreground. Background location is not enabled.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Section("Home") {
                TextField("Home address", text: $homeDraft)
                    .textContentType(.fullStreetAddress)
                    .onChange(of: homeDraft) { value in
                        homeAutocomplete.update(query: value)
                    }

                AddressSuggestionList(suggestions: homeAutocomplete.suggestions) { suggestion in
                    homeDraft = suggestion.addressText
                    homeAutocomplete.clear()
                }

                if let message = homeAutocomplete.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }

                Button("Use this home address") {
                    do {
                        try routingState.setHomeAddress(homeDraft)
                        placeMessage = "Home address saved locally on this iPhone."
                        homeAutocomplete.clear()
                    } catch {
                        placeMessage = error.localizedDescription
                    }
                }

                if !routingState.homeAddress.isEmpty {
                    Label(routingState.homeAddress, systemImage: "house.fill")
                        .foregroundStyle(palette.textSecondary)
                }
            }

            Section("Clients") {
                NavigationLink {
                    ClientProfilesView(clientState: clientState)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(palette.accent.opacity(0.13))
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(palette.accent)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manage clients")
                                .font(.headline)
                            Text("\(clientState.clients.count) profiles · ABA-style initials")
                                .font(.caption)
                                .foregroundStyle(palette.textSecondary)
                        }
                    }
                }

                Text("Client profiles are optional. General session and visual tools remain available without one.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Section("Saved places") {
                TextField("Place name", text: $placeName)
                TextField("Address or place", text: $placeAddress)
                    .textContentType(.fullStreetAddress)
                    .onChange(of: placeAddress) { value in
                        placeAutocomplete.update(query: value)
                    }

                AddressSuggestionList(suggestions: placeAutocomplete.suggestions) { suggestion in
                    placeAddress = suggestion.addressText
                    placeAutocomplete.clear()
                }

                if let message = placeAutocomplete.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }

                Picker("Type", selection: $placeKind) {
                    ForEach(LifeRoutePlaceKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                Stepper("Useful visit: \(placeMinutes) min", value: $placeMinutes, in: 15...240, step: 15)
                Toggle("Use in gap suggestions", isOn: $placeSuggestions)
                Button("Add saved place") { addPlace() }

                if routingState.savedPlaces.isEmpty {
                    Text("No saved places yet").foregroundStyle(palette.textSecondary)
                } else {
                    ForEach(routingState.savedPlaces) { place in
                        HStack(alignment: .top, spacing: 11) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(palette.accent.opacity(0.12))
                                Image(systemName: setupPlaceSymbol(place.kind))
                                    .foregroundStyle(palette.accent)
                            }
                            .frame(width: 38, height: 38)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(place.name).font(.headline)
                                Text("\(place.kind.rawValue) · \(place.minimumVisitMinutes) min")
                                    .font(.caption)
                                    .foregroundStyle(palette.textSecondary)
                                Text(place.address)
                                    .font(.caption)
                                    .foregroundStyle(palette.textSecondary)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                routingState.removeSavedPlace(id: place.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel("Remove \(place.name)")
                        }
                    }
                }

                if let placeMessage {
                    Text(placeMessage)
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }

                Text("Home and saved places are stored locally in protected LifeRoute app data. Current GPS coordinates and route estimates are not persisted.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Section("Privacy & app behavior") {
                Label("Direct launch", systemImage: "checkmark.shield.fill")
                Label("Protected local LifeRoute data", systemImage: "lock.fill")
                Text("No account gate is required to open the app.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if homeDraft.isEmpty {
                homeDraft = routingState.homeAddress
            }
        }
    }

    private func setupPlaceSymbol(_ kind: LifeRoutePlaceKind) -> String {
        switch kind {
        case .gym: return "figure.strengthtraining.traditional"
        case .work: return "briefcase.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .grocery: return "cart.fill"
        case .park: return "leaf.fill"
        case .library: return "books.vertical.fill"
        case .errand: return "checklist"
        case .other: return "mappin.circle.fill"
        }
    }

    private func addPlace() {
        do {
            try routingState.addSavedPlace(
                name: placeName,
                address: placeAddress,
                kind: placeKind,
                minimumVisitMinutes: placeMinutes,
                useInGapSuggestions: placeSuggestions
            )
            placeMessage = "Saved place stored locally on this iPhone."
            placeName = ""
            placeAddress = ""
            placeAutocomplete.clear()
        } catch {
            placeMessage = error.localizedDescription
        }
    }
}

private struct AddressSuggestionList: View {
    @Environment(\.lifeRoutePalette) private var palette

    let suggestions: [LifeRouteAddressSuggestion]
    let onSelect: (LifeRouteAddressSuggestion) -> Void

    var body: some View {
        ForEach(suggestions) { suggestion in
            Button {
                onSelect(suggestion)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.textPrimary)
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle)
                                .font(.caption2)
                                .foregroundStyle(palette.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ThemeCenterView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @EnvironmentObject private var themeStore: LifeRouteThemeStore
    @State private var selectedCategory: LifeRouteThemeCategory = .core

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                featuredTheme

                VStack(alignment: .leading, spacing: 10) {
                    Text("Explore themes")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.textPrimary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LifeRouteThemeCategory.allCases) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: categorySymbol(category))
                                        Text(category.rawValue)
                                    }
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(selectedCategory == category ? Color.black.opacity(0.78) : palette.textSecondary)
                                    .padding(.horizontal, 13)
                                    .frame(height: 38)
                                    .background(
                                        Capsule()
                                            .fill(selectedCategory == category ? palette.accent : palette.panelElevated.opacity(0.72))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(themesForCategory) { theme in
                        ThemeChoiceCard(
                            theme: theme,
                            isSelected: themeStore.selectedTheme == theme
                        ) {
                            themeStore.selectedTheme = theme
                            LifeRouteHaptics.selection()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Live theme", systemImage: themeStore.selectedTheme.symbol)
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text("\(themeStore.selectedTheme.name) is applied across the background, cards, accents, controls, navigation tint, and theme-specific artwork.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                .lifeRouteCard()
            }
            .padding(18)
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var featuredTheme: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .fill(themeStore.selectedTheme.palette.backgroundGradient)

            LifeRouteThemeArtwork(
                theme: themeStore.selectedTheme,
                palette: themeStore.selectedTheme.palette
            )
            .clipShape(RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous))

            VStack(alignment: .leading, spacing: 9) {
                Text("THEME CENTER")
                    .font(.caption.weight(.black))
                    .tracking(2)
                    .foregroundStyle(themeStore.selectedTheme.palette.accent)
                Text(themeStore.selectedTheme.name)
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Change the atmosphere. Keep the workflow.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                Label(themeStore.selectedTheme.category.rawValue, systemImage: themeStore.selectedTheme.artworkSymbols.primary)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(themeStore.selectedTheme.palette.accentSecondary)
            }
            .padding(21)
        }
        .frame(minHeight: 220)
        .overlay {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .stroke(themeStore.selectedTheme.palette.accent.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: themeStore.selectedTheme.palette.accent.opacity(0.15), radius: 26, y: 12)
    }

    private var themesForCategory: [LifeRouteTheme] {
        LifeRouteTheme.allCases.filter { $0.category == selectedCategory }
    }

    private func categorySymbol(_ category: LifeRouteThemeCategory) -> String {
        switch category {
        case .core: return "sparkles"
        case .metallic: return "hexagon.fill"
        case .scenery: return "mountain.2.fill"
        case .dynamic: return "bolt.fill"
        case .fluid: return "drop.fill"
        }
    }
}

private struct ThemeChoiceCard: View {
    let theme: LifeRouteTheme
    let isSelected: Bool
    let action: () -> Void

    private var themePalette: LifeRouteThemePalette { theme.palette }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(themePalette.backgroundGradient)
                    LifeRouteThemeArtwork(theme: theme, palette: themePalette, compact: true)
                }
                .frame(height: 102)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(themePalette.accentSecondary)
                            .padding(9)
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(theme.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.white)
                        Text(theme.category.rawValue)
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.58))
                    }
                    Spacer()
                    Image(systemName: theme.artworkSymbols.primary)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(themePalette.accent)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.10 : 0.055))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(isSelected ? themePalette.accent.opacity(0.72) : Color.white.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: isSelected ? themePalette.accent.opacity(0.12) : .clear, radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct RouteDetailView: View {
    let route: AppRoute
    @ObservedObject var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Label(route.title, systemImage: route.systemImage).font(.headline)
                Text(route.subtitle).foregroundStyle(.secondary)
            }

            Section {
                Button("Close") { dismiss() }
                Button("Go to Today") { router.select(.today) }
            }
        }
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
        .environmentObject(LifeRouteThemeStore())
        .environment(\.lifeRoutePalette, LifeRouteTheme.royal.palette)
        .environment(\.lifeRouteTheme, LifeRouteTheme.royal)
}
