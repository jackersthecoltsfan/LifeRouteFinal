import SwiftUI

struct ContentView: View {
    @StateObject private var router = AppRouter()
    @StateObject private var calendarState = CalendarCoreState()
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
                ScheduleCoreView(router: router, calendarState: calendarState)
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
    }
}

private struct CoreHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TodayCoreView: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var routingState: RoutingLocationCore
    @State private var tapCount = 0
    @State private var routeMode: LifeRouteTransportMode = .driving

    var body: some View {
        List {
            Section {
                CoreHeader(title: "LifeRoute", subtitle: "v0.5.0 native functional core")
            }

            Section("Interaction test") {
                Button("Test primary action") { tapCount += 1 }
                Text("Successful taps: \(tapCount)").foregroundStyle(.secondary)
            }

            Section("Location & routes") {
                Text(routingState.locationMessage).foregroundStyle(.secondary)
                Button("Use current location") { routingState.requestCurrentLocation() }
                Picker("Travel mode", selection: $routeMode) {
                    ForEach(LifeRouteTransportMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }
                if routingState.savedPlaces.isEmpty {
                    Text("Add saved places in Setup to test route estimates.").foregroundStyle(.secondary)
                } else {
                    ForEach(routingState.savedPlaces) { place in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(place.name).font(.headline)
                            Text(place.address).font(.caption).foregroundStyle(.secondary)
                            if let estimate = routingState.routeEstimates[place.id] {
                                Text("\(estimate.durationLabel) · \(estimate.distanceLabel) · \(estimate.mode.rawValue)")
                                    .font(.subheadline)
                            }
                            HStack {
                                Button("Estimate") { Task { await routingState.calculateRoute(to: place, mode: routeMode) } }
                                Button("Open in Maps") { Task { await routingState.openInAppleMaps(place, mode: routeMode) } }
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
                if let routeMessage = routingState.routeMessage {
                    Text(routeMessage).foregroundStyle(.secondary)
                }
            }

            Section("Navigation ownership") {
                NavigationLink("Open Today detail", value: AppRoute.todayDetails)
                Button("Open Schedule detail") { router.open(.scheduleDetails, in: .schedule) }
                Button("Open Setup detail") { router.open(.setupDetails, in: .setup) }
            }

            Section("Current rebuild state") {
                Label("Direct launch", systemImage: "checkmark.circle")
                Label("One native router", systemImage: "checkmark.circle")
                Label("No login gate", systemImage: "checkmark.circle")
                Label("Legacy WebView runtime quarantined", systemImage: "checkmark.circle")
            }
        }
        .navigationTitle("Today")
    }
}

private struct ScheduleCoreView: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var calendarState: CalendarCoreState
    @State private var selectedRange: LifeRouteCalendarRange = .day
    @State private var draftTitle = ""
    @State private var draftDate = Date()
    @State private var draftStart = Date()
    @State private var draftEnd = Date().addingTimeInterval(3_600)
    @State private var draftLocation = ""
    @State private var draftAllDay = false
    @State private var formMessage: String?

    var body: some View {
        Form {
            Section { CoreHeader(title: "Schedule", subtitle: "Native calendar core. Provider connections and persistence return in later checkpoints.") }
            Section("Range") {
                Picker("Schedule range", selection: $selectedRange) {
                    ForEach(LifeRouteCalendarRange.allCases) { range in Text(range.rawValue).tag(range) }
                }.pickerStyle(.segmented)
            }
            Section("Period") {
                HStack {
                    Button { calendarState.shiftSelection(selectedRange, by: -1) } label: { Label("Previous", systemImage: "chevron.left") }.labelStyle(.iconOnly)
                    Spacer()
                    Text(calendarState.periodLabel(for: selectedRange)).font(.headline)
                    Spacer()
                    Button { calendarState.shiftSelection(selectedRange, by: 1) } label: { Label("Next", systemImage: "chevron.right") }.labelStyle(.iconOnly)
                }
                DatePicker("Selected date", selection: $calendarState.selectedDate, displayedComponents: .date)
                Button("Today") { calendarState.selectToday() }
                Text("\(calendarState.visibleEvents(in: selectedRange).count) events · \(calendarState.timedMinutes(in: selectedRange)) timed minutes").foregroundStyle(.secondary)
            }
            Section("Events") { CalendarEventsView(range: selectedRange, calendarState: calendarState) }
            Section("Add manual appointment") {
                TextField("Appointment title", text: $draftTitle).textInputAutocapitalization(.sentences).submitLabel(.done)
                TextField("Location (optional)", text: $draftLocation).textContentType(.fullStreetAddress)
                DatePicker("Date", selection: $draftDate, displayedComponents: .date)
                Toggle("All day", isOn: $draftAllDay)
                if !draftAllDay {
                    DatePicker("Starts", selection: $draftStart, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $draftEnd, displayedComponents: .hourAndMinute)
                }
                Button("Add appointment") { addAppointment() }
                if let formMessage { Text(formMessage).foregroundStyle(.secondary) }
            }
            Section("Stack test") {
                NavigationLink("Open Schedule detail", value: AppRoute.scheduleDetails)
                Button("Return to Today tab") { router.select(.today) }
            }
        }
        .navigationTitle("Schedule")
    }

    private func addAppointment() {
        do {
            try calendarState.addManualEvent(title: draftTitle, date: draftDate, startTime: draftStart, endTime: draftEnd, location: draftLocation, isAllDay: draftAllDay)
            formMessage = "Appointment added for this app session."
            draftTitle = ""
            draftLocation = ""
        } catch { formMessage = error.localizedDescription }
    }
}

private struct CalendarEventsView: View {
    let range: LifeRouteCalendarRange
    @ObservedObject var calendarState: CalendarCoreState

    var body: some View {
        switch range {
        case .day:
            eventRows(calendarState.events(on: calendarState.selectedDate))
        case .week:
            ForEach(calendarState.weekDates(), id: \.self) { date in
                let events = calendarState.events(on: date)
                VStack(alignment: .leading, spacing: 6) {
                    Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).font(.headline)
                    if events.isEmpty { Text("No events").foregroundStyle(.secondary) }
                    else { ForEach(events) { event in CalendarEventRow(event: event) } }
                }.padding(.vertical, 4)
            }
        case .month:
            let activeDays = calendarState.activeDaysInSelectedMonth()
            if activeDays.isEmpty { Text("No events this month").foregroundStyle(.secondary) }
            else {
                ForEach(activeDays, id: \.self) { date in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())).font(.headline)
                        ForEach(calendarState.events(on: date)) { event in CalendarEventRow(event: event) }
                    }.padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder private func eventRows(_ events: [LifeRouteCalendarEvent]) -> some View {
        if events.isEmpty { Text("No events on this day").foregroundStyle(.secondary) }
        else { ForEach(events) { event in CalendarEventRow(event: event) } }
    }
}

private struct CalendarEventRow: View {
    let event: LifeRouteCalendarEvent
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(event.title).font(.body.weight(.semibold))
            Text(timeLabel).font(.caption).foregroundStyle(.secondary)
            if !event.location.isEmpty { Label(event.location, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var timeLabel: String {
        if event.isAllDay { return "All day · \(event.source.rawValue)" }
        return "\(event.start.formatted(date: .omitted, time: .shortened))–\(event.end.formatted(date: .omitted, time: .shortened)) · \(event.source.rawValue)"
    }
}

private struct ResourcesCoreView: View {
    @ObservedObject var router: AppRouter
    @State private var acknowledged = false
    var body: some View {
        List {
            Section { CoreHeader(title: "Resources", subtitle: "Resource links return after their native ownership is reviewed.") }
            Section("Button test") { Button(acknowledged ? "Action received" : "Test resource action") { acknowledged = true } }
            Section("Stack test") {
                NavigationLink("Open Resources detail", value: AppRoute.resourcesDetails)
                Button("Open Session Tools") { router.select(.tools) }
            }
        }.navigationTitle("Resources")
    }
}

private struct SetupCoreView: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var routingState: RoutingLocationCore
    @ObservedObject var clientState: ClientProfileCore
    @State private var displayName = ""
    @State private var locationEnabled = false
    @State private var savedSummary = "Not saved yet"
    @State private var homeDraft = ""
    @State private var placeName = ""
    @State private var placeAddress = ""
    @State private var placeKind: LifeRoutePlaceKind = .other
    @State private var placeMinutes = 60
    @State private var placeSuggestions = true
    @State private var placeMessage: String?

    var body: some View {
        Form {
            Section { CoreHeader(title: "Setup", subtitle: "Native fields only. No PIN or password gate.") }
            Section("Location") {
                Text(routingState.locationMessage).foregroundStyle(.secondary)
                Button("Request current location") { routingState.requestCurrentLocation() }
            }
            Section("Home") {
                TextField("Home address", text: $homeDraft).textContentType(.fullStreetAddress)
                Button("Use this home address") {
                    do { try routingState.setHomeAddress(homeDraft); placeMessage = "Home address saved for this app session." }
                    catch { placeMessage = error.localizedDescription }
                }
                if !routingState.homeAddress.isEmpty { Text(routingState.homeAddress).foregroundStyle(.secondary) }
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
                TextField("Address or place", text: $placeAddress).textContentType(.fullStreetAddress)
                Picker("Type", selection: $placeKind) { ForEach(LifeRoutePlaceKind.allCases) { kind in Text(kind.rawValue).tag(kind) } }
                Stepper("Useful visit: \(placeMinutes) min", value: $placeMinutes, in: 15...240, step: 15)
                Toggle("Use in gap suggestions", isOn: $placeSuggestions)
                Button("Add saved place") { addPlace() }
                if routingState.savedPlaces.isEmpty { Text("No saved places yet").foregroundStyle(.secondary) }
                else {
                    ForEach(routingState.savedPlaces) { place in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.name).font(.headline)
                            Text("\(place.kind.rawValue) · \(place.minimumVisitMinutes) min").font(.caption).foregroundStyle(.secondary)
                            Text(place.address).font(.caption).foregroundStyle(.secondary)
                            Button("Remove \(place.name)", role: .destructive) { routingState.removeSavedPlace(id: place.id) }
                        }
                    }
                }
                if let placeMessage { Text(placeMessage).foregroundStyle(.secondary) }
                Text("Home and saved places are session-only until the persistence checkpoint.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Form and state test") {
                TextField("Name", text: $displayName).textContentType(.name)
                Toggle("Use location when available", isOn: $locationEnabled)
                Button("Save test setup") {
                    let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    savedSummary = "\(name.isEmpty ? "No name" : name) · location \(locationEnabled ? "on" : "off")"
                }
                Text(savedSummary).foregroundStyle(.secondary)
            }
            Section("Stack test") {
                NavigationLink("Open Setup detail", value: AppRoute.setupDetails)
                Button("Reset Setup navigation path") { router.resetPath(for: .setup) }
            }
        }.navigationTitle("Setup")
    }

    private func addPlace() {
        do {
            try routingState.addSavedPlace(name: placeName, address: placeAddress, kind: placeKind, minimumVisitMinutes: placeMinutes, useInGapSuggestions: placeSuggestions)
            placeMessage = "Saved place added for this app session."
            placeName = ""
            placeAddress = ""
        } catch { placeMessage = error.localizedDescription }
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
            Section("Native navigation test") {
                Button("Close") { dismiss() }
                Button("Go to Today") { router.select(.today) }
            }
        }
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview { ContentView() }
