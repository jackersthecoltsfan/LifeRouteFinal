import SwiftUI
import UIKit

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
                TodayCoreView(router: router, routingState: routingState)
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
            guard phase != .active else { return }
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
                    .fill(palette.accent.opacity(0.14))
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 48, height: 48)

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
    @ObservedObject var routingState: RoutingLocationCore
    @State private var routeMode: LifeRouteTransportMode = .driving

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                dashboardHero
                quickActions
                routePlanner
                savedPlaces
                dailyFlowCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dashboardHero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.panelElevated.opacity(0.92),
                            palette.panel.opacity(0.78),
                            palette.backgroundBottom.opacity(0.84)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(palette.accent.opacity(0.19))
                .frame(width: 220, height: 220)
                .blur(radius: 4)
                .offset(x: 155, y: -85)

            VStack(alignment: .leading, spacing: 14) {
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
                    .background(.black.opacity(0.18), in: Capsule())
                }

                Text("Own your day.")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text("Routes, schedule, session tools, and the places that fit between them.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Label(routingState.locationRequestInFlight ? "Locating…" : routingState.locationMessage, systemImage: "location.fill")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(palette.textPrimary.opacity(0.88))
                    Spacer()
                }
            }
            .padding(22)
        }
        .frame(minHeight: 218)
        .overlay {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [palette.accent.opacity(0.44), Color.white.opacity(0.08), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: palette.accent.opacity(0.12), radius: 28, y: 12)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("Quick actions", subtitle: "Jump into the things you use most.")

            HStack(spacing: 10) {
                DashboardActionButton(title: "Locate", subtitle: "Use GPS", systemImage: "location.fill", prominent: true) {
                    routingState.requestCurrentLocation()
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
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .foregroundStyle(palette.accent)
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
                    Text("Add favorites like home, the gym, stores, or client locations in Setup.")
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

    private var dailyFlowCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(palette.accent.opacity(0.14))
                Image(systemName: "sparkles")
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("Daily flow")
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                Text("Gap suggestions and smarter day planning will live here as the routing layer expands.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer()
        }
        .lifeRouteCard()
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

    private func auditCrossTabRouteOwnership() {
        router.open(.scheduleDetails, in: .schedule)
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
                CoreHeader(
                    title: "Schedule",
                    subtitle: "One place for your manual appointments and read-only calendar connections.",
                    systemImage: "calendar.badge.clock"
                )
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
                    .foregroundStyle(.secondary)
            }

            Section("View") {
                Picker("Schedule range", selection: $selectedRange) {
                    ForEach(LifeRouteCalendarRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Period") {
                HStack {
                    Button { calendarState.shiftSelection(selectedRange, by: -1) } label: {
                        Label("Previous", systemImage: "chevron.left")
                    }
                    .labelStyle(.iconOnly)

                    Spacer()

                    Text(calendarState.periodLabel(for: selectedRange))
                        .font(.headline)

                    Spacer()

                    Button { calendarState.shiftSelection(selectedRange, by: 1) } label: {
                        Label("Next", systemImage: "chevron.right")
                    }
                    .labelStyle(.iconOnly)
                }

                DatePicker("Selected date", selection: $calendarState.selectedDate, displayedComponents: .date)
                Button("Jump to today") { calendarState.selectToday() }
                Label("\(presentation.eventCount) events · \(presentation.timedMinutes) timed minutes", systemImage: "clock")
                    .foregroundStyle(.secondary)
            }

            Section("Events") {
                CalendarEventsView(presentation: presentation) { eventID in
                    calendarState.removeEvent(id: eventID)
                }
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

                if let formMessage {
                    Text(formMessage).foregroundStyle(.secondary)
                }

                Text("Manual LifeRoute appointments are saved locally. Apple and Google events remain provider-refreshed data and are not copied into LifeRoute’s local data file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Schedule")
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

    private func auditDirectTabSelection() {
        router.select(.today)
    }
}

private struct CalendarEventsView: View {
    let presentation: LifeRouteCalendarRangePresentation
    let onDeleteManualEvent: (LifeRouteCalendarEvent.ID) -> Void

    var body: some View {
        switch presentation.range {
        case .day:
            eventRows(presentation.days.first?.events ?? [])
        case .week:
            ForEach(presentation.days) { day in
                VStack(alignment: .leading, spacing: 6) {
                    Text(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.headline)
                    if day.events.isEmpty {
                        Text("No events").foregroundStyle(.secondary)
                    } else {
                        ForEach(day.events) { event in
                            eventRow(event)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        case .month:
            if presentation.days.isEmpty {
                Text("No events this month").foregroundStyle(.secondary)
            } else {
                ForEach(presentation.days) { day in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.headline)
                        ForEach(day.events) { event in
                            eventRow(event)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func eventRows(_ events: [LifeRouteCalendarEvent]) -> some View {
        if events.isEmpty {
            Text("No events on this day").foregroundStyle(.secondary)
        } else {
            ForEach(events) { event in
                eventRow(event)
            }
        }
    }

    private func eventRow(_ event: LifeRouteCalendarEvent) -> some View {
        CalendarEventRow(event: event, onDeleteManualEvent: onDeleteManualEvent)
    }
}

private struct CalendarEventRow: View {
    let event: LifeRouteCalendarEvent
    let onDeleteManualEvent: (LifeRouteCalendarEvent.ID) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title).font(.body.weight(.semibold))
                Text(timeLabel).font(.caption).foregroundStyle(.secondary)

                if !event.location.isEmpty {
                    Label(event.location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if event.source == .manual {
                Button(role: .destructive) {
                    onDeleteManualEvent(event.id)
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete \(event.title)")
            }
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
    @ObservedObject var router: AppRouter
    @ObservedObject var routingState: RoutingLocationCore
    @ObservedObject var clientState: ClientProfileCore

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
                CoreHeader(
                    title: "Setup",
                    subtitle: "Personalize LifeRoute, manage clients, and teach it the places in your routine.",
                    systemImage: "slider.horizontal.3"
                )
            }

            Section("Appearance") {
                NavigationLink("Theme Center", destination: ThemeCenterView())
                Text("Choose from core, metallic, scenery, dynamic, and fluid themes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Location") {
                Text(routingState.locationMessage).foregroundStyle(.secondary)
                Button("Request current location") { routingState.requestCurrentLocation() }
                    .disabled(routingState.locationRequestInFlight)
            }

            Section("Home") {
                TextField("Home address", text: $homeDraft)
                    .textContentType(.fullStreetAddress)

                Button("Use this home address") {
                    do {
                        try routingState.setHomeAddress(homeDraft)
                        placeMessage = "Home address saved locally on this iPhone."
                    } catch {
                        placeMessage = error.localizedDescription
                    }
                }

                if !routingState.homeAddress.isEmpty {
                    Text(routingState.homeAddress).foregroundStyle(.secondary)
                }
            }

            Section("Clients") {
                NavigationLink {
                    ClientProfilesView(clientState: clientState)
                } label: {
                    Label("Manage clients", systemImage: "person.2")
                }

                Text("\(clientState.clients.count) client profiles · ABA-style initials only")
                    .foregroundStyle(.secondary)
            }

            Section("Saved places") {
                TextField("Place name", text: $placeName)
                TextField("Address or place", text: $placeAddress)
                    .textContentType(.fullStreetAddress)
                Picker("Type", selection: $placeKind) {
                    ForEach(LifeRoutePlaceKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                Stepper("Useful visit: \(placeMinutes) min", value: $placeMinutes, in: 15...240, step: 15)
                Toggle("Use in gap suggestions", isOn: $placeSuggestions)
                Button("Add saved place") { addPlace() }

                if routingState.savedPlaces.isEmpty {
                    Text("No saved places yet").foregroundStyle(.secondary)
                } else {
                    ForEach(routingState.savedPlaces) { place in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.name).font(.headline)
                            Text("\(place.kind.rawValue) · \(place.minimumVisitMinutes) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(place.address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Remove \(place.name)", role: .destructive) {
                                routingState.removeSavedPlace(id: place.id)
                            }
                        }
                    }
                }

                if let placeMessage {
                    Text(placeMessage).foregroundStyle(.secondary)
                }

                Text("Home and saved places are stored locally in protected LifeRoute app data. Current GPS coordinates and route estimates are not persisted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy & app behavior") {
                Label("Direct launch", systemImage: "checkmark.shield.fill")
                Label("Protected local LifeRoute data", systemImage: "lock.fill")
                Text("No account gate is required to open the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Setup")
        .onAppear {
            if homeDraft.isEmpty {
                homeDraft = routingState.homeAddress
            }
        }
    }

    // No PIN or password gate: setup remains direct-launch.
    private func auditNavigationReset() {
        router.resetPath(for: .setup)
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
        } catch {
            placeMessage = error.localizedDescription
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Theme Center")
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                    Text("Give LifeRoute a completely different atmosphere without changing how the app works.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
                .lifeRouteCard()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LifeRouteThemeCategory.allCases) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Text(category.rawValue)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(selectedCategory == category ? Color.black.opacity(0.78) : palette.textSecondary)
                                    .padding(.horizontal, 14)
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

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(themesForCategory) { theme in
                        ThemeChoiceCard(
                            theme: theme,
                            isSelected: themeStore.selectedTheme == theme
                        ) {
                            themeStore.selectedTheme = theme
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Live theme", systemImage: themeStore.selectedTheme.symbol)
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text("\(themeStore.selectedTheme.name) is applied across the background, cards, accents, controls, and navigation tint.")
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

    private var themesForCategory: [LifeRouteTheme] {
        LifeRouteTheme.allCases.filter { $0.category == selectedCategory }
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
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(themePalette.backgroundGradient)
                        .frame(height: 88)

                    Circle()
                        .fill(themePalette.accent.opacity(0.32))
                        .frame(width: 72, height: 72)
                        .blur(radius: 2)
                        .offset(x: 14, y: 12)

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
                    Circle().fill(themePalette.accent).frame(width: 11, height: 11)
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
}
