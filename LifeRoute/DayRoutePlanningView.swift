import SwiftUI

struct DayRoutePlanningView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @ObservedObject var calendarState: CalendarCoreState
    @ObservedObject var routingState: RoutingLocationCore

    @StateObject private var planState = DayRoutePlanningCore()
    @StateObject private var stopAutocomplete = LifeRouteAddressAutocomplete()

    @State private var selectedEventID = ""
    @State private var routeMode: LifeRouteTransportMode = .driving
    @State private var returnHome = true
    @State private var stops: [LifeRouteDayStop] = []
    @State private var stopTitle = ""
    @State private var stopAddress = ""
    @State private var stopPosition: LifeRouteDayStop.Position = .before
    @State private var message: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                hero
                destinationCard
                stopsCard
                routeOptionsCard
                buildCard
                if !planState.legs.isEmpty { routeResultsCard }
            }
            .padding(18)
            .padding(.bottom, 28)
        }
        .navigationTitle("Day Route")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedEventID.isEmpty {
                selectedEventID = todayEvents.first?.id ?? ""
            }
        }
    }

    private var todayEvents: [LifeRouteCalendarEvent] {
        calendarState.events(on: Date())
            .filter { !$0.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.start < $1.start }
    }

    private var selectedEvent: LifeRouteCalendarEvent? {
        todayEvents.first { $0.id == selectedEventID }
    }

    private var beforeStops: [LifeRouteDayStop] {
        stops.filter { $0.position == .before }
    }

    private var afterStops: [LifeRouteDayStop] {
        stops.filter { $0.position == .after }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("ROUTE THE WHOLE DAY", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.caption.weight(.black))
                .tracking(1.2)
                .foregroundStyle(palette.accent)
            Text("Stops belong in the plan.")
                .font(.system(size: 29, weight: .black, design: .rounded))
                .foregroundStyle(palette.textPrimary)
            Text("Add errands before or after an appointment, decide whether you’re returning home, and see each travel leg before you leave.")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
        }
        .lifeRouteCard()
    }

    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Primary appointment", systemImage: "calendar.badge.clock")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)

            if todayEvents.isEmpty {
                Text("No calendar events with locations are available today. Add or refresh an event location in Schedule first.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            } else {
                Picker("Appointment", selection: $selectedEventID) {
                    ForEach(todayEvents) { event in
                        Text("\(event.start.formatted(date: .omitted, time: .shortened)) · \(event.title)")
                            .tag(event.id)
                    }
                }
                .pickerStyle(.menu)

                if let event = selectedEvent {
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(palette.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title)
                                .font(.headline)
                                .foregroundStyle(palette.textPrimary)
                            Text(event.location)
                                .font(.caption)
                                .foregroundStyle(palette.textSecondary)
                            Text(event.start.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(palette.accentSecondary)
                        }
                    }
                }
            }
        }
        .lifeRouteCard()
    }

    private var stopsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("Stops", systemImage: "signpost.right.and.left.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(stops.count)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(palette.accent)
            }

            if !routingState.savedPlaces.isEmpty {
                Menu {
                    ForEach(routingState.savedPlaces) { place in
                        Button("Before · \(place.name)") {
                            addSavedPlace(place, position: .before)
                        }
                        Button("After · \(place.name)") {
                            addSavedPlace(place, position: .after)
                        }
                    }
                } label: {
                    Label("Add from saved places", systemImage: "bookmark.fill")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
            }

            Picker("Position", selection: $stopPosition) {
                ForEach(LifeRouteDayStop.Position.allCases) { position in
                    Text(position.rawValue).tag(position)
                }
            }
            .pickerStyle(.segmented)

            TextField("Stop name", text: $stopTitle)
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            TextField("Stop address", text: $stopAddress)
                .textContentType(.fullStreetAddress)
                .onChange(of: stopAddress) { value in
                    stopAutocomplete.update(query: value)
                }
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            ForEach(stopAutocomplete.suggestions) { suggestion in
                Button {
                    stopAddress = suggestion.addressText
                    stopAutocomplete.clear()
                } label: {
                    HStack(spacing: 9) {
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
                            }
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }

            Button("Add stop") {
                addCustomStop()
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())

            if !stops.isEmpty {
                Divider().overlay(Color.white.opacity(0.08))

                if !beforeStops.isEmpty {
                    Text("BEFORE")
                        .font(.caption2.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(palette.accentSecondary)
                    ForEach(beforeStops) { stop in stopRow(stop) }
                }

                if !afterStops.isEmpty {
                    Text("AFTER")
                        .font(.caption2.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(palette.accentSecondary)
                    ForEach(afterStops) { stop in stopRow(stop) }
                }
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .lifeRouteCard()
    }

    private var routeOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Route options", systemImage: "slider.horizontal.3")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)

            Picker("Travel mode", selection: $routeMode) {
                ForEach(LifeRouteTransportMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle(isOn: $returnHome) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Return home after the last stop")
                        .font(.subheadline.weight(.bold))
                    Text(routingState.homeAddress.isEmpty ? "Add a home address in Setup to use this." : routingState.homeAddress)
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .disabled(routingState.homeAddress.isEmpty)

            HStack(spacing: 8) {
                Image(systemName: routingState.currentLocation == nil ? "house.fill" : "location.fill")
                    .foregroundStyle(palette.accent)
                Text(routingState.currentLocation == nil ? "Route starts from Home fallback" : "Route starts from your live current location")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .lifeRouteCard()
    }

    private var buildCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                buildRoute()
            } label: {
                Label(planState.isCalculating ? "Building route…" : "Build full day route", systemImage: "map.fill")
            }
            .buttonStyle(LifeRoutePrimaryButtonStyle())
            .disabled(planState.isCalculating || selectedEvent == nil)

            if let routeMessage = planState.message {
                Text(routeMessage)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .lifeRouteCard()
    }

    private var routeResultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Route sequence")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(planState.legs.count) legs")
                    .font(.caption.weight(.black))
                    .foregroundStyle(palette.accent)
            }

            ForEach(planState.legs) { leg in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(leg.sequence)")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(Color.black.opacity(0.8))
                            .frame(width: 28, height: 28)
                            .background(palette.accent, in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(leg.fromTitle) → \(leg.toTitle)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.textPrimary)
                            Text("\(leg.durationLabel) · \(leg.distanceLabel)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.accentSecondary)
                        }
                        Spacer()
                    }

                    Button {
                        planState.openLegInAppleMaps(leg, mode: routeMode)
                    } label: {
                        Label("Open this leg in Apple Maps", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())
                }
                .padding(12)
                .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .lifeRouteCard()
    }

    private func stopRow(_ stop: LifeRouteDayStop) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Text(stop.address)
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Button(role: .destructive) {
                stops.removeAll { $0.id == stop.id }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(stop.title)")
        }
        .padding(10)
        .background(palette.panelElevated.opacity(0.26), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func addSavedPlace(_ place: LifeRouteSavedPlace, position: LifeRouteDayStop.Position) {
        stops.append(
            LifeRouteDayStop(
                title: place.name,
                address: place.address,
                position: position
            )
        )
        message = "Added \(place.name)."
    }

    private func addCustomStop() {
        let cleanAddress = stopAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAddress.isEmpty else {
            message = "Enter a stop address."
            return
        }
        let cleanTitle = stopTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        stops.append(
            LifeRouteDayStop(
                title: cleanTitle.isEmpty ? "Stop" : cleanTitle,
                address: cleanAddress,
                position: stopPosition
            )
        )
        stopTitle = ""
        stopAddress = ""
        stopAutocomplete.clear()
        message = "Stop added."
    }

    private func buildRoute() {
        guard let event = selectedEvent else { return }
        planState.calculate(
            eventTitle: event.title,
            eventAddress: event.location,
            beforeStops: beforeStops,
            afterStops: afterStops,
            returnHome: returnHome,
            homeAddress: routingState.homeAddress,
            currentLocation: routingState.currentLocation,
            mode: routeMode
        )
    }
}
