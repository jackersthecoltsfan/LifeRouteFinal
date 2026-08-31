import SwiftUI

struct DayRoutePlanningView: View {
    @Environment(\.scenicRoyalThemeStyle) private var scenicStyle
    @ObservedObject var calendarState: CalendarCoreState
    @ObservedObject var routingState: RoutingLocationCore
    @ObservedObject var planState: DayRoutePlanningCore
    var day: Date = Date()

    @StateObject private var stopAutocomplete = LifeRouteAddressAutocomplete()

    @State private var stopTitle = ""
    @State private var stopAddress = ""
    @State private var stopPosition: LifeRouteDayStop.Position = .before
    @State private var stopDurationMinutes = 20
    @State private var message: String?
    @State private var suppressStopAutocompleteQuery = false
    @FocusState private var stopAddressFocused: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
                hero
                destinationCard
                stopsCard
                routeOptionsCard
                buildCard
                if !planState.legs.isEmpty { routeResultsCard }
            }
            .padding(.horizontal, ScenicRoyalDesignSystem.Layout.pageHorizontal)
            .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
            .padding(.bottom, ScenicRoyalDesignSystem.Spacing.spacious * 2)
        }
        .navigationTitle("Day Route")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if routingState.homeAddress.isEmpty {
                planState.returnHome = false
            }
        }
    }

    private var dayEvents: [LifeRouteCalendarEvent] {
        calendarState.events(on: day)
            .sorted { $0.start < $1.start }
    }

    private var routableDayEvents: [LifeRouteCalendarEvent] {
        dayEvents.filter {
            !$0.isAllDay
                && !$0.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var stops: [LifeRouteDayStop] {
        routingState.dayStops(on: day)
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
                .foregroundStyle(scenicStyle.accent)
            Text("Stops belong in the plan.")
                .font(.system(size: 29, weight: .black, design: .rounded))
                .foregroundStyle(scenicStyle.primaryText)
            Text("Add errands before or after an appointment, decide whether you’re returning home, and see each travel leg before you leave.")
                .font(.subheadline)
                .foregroundStyle(scenicStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .scenicRoyalCard(role: .readability)
    }

    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Day appointments", systemImage: "calendar.badge.clock")
                .font(.title3.weight(.bold))
                .foregroundStyle(scenicStyle.primaryText)

            if dayEvents.isEmpty {
                Text("No calendar events are available on \(day.formatted(date: .abbreviated, time: .omitted)). Add an appointment in Calendar or add a saved stop below.")
                    .font(.subheadline)
                    .foregroundStyle(scenicStyle.secondaryText)
            } else {
                ScenicRoyalGlassEffectContainer(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                    VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                        ForEach(dayEvents) { event in
                            ScenicRoyalInsetRow(role: .ambient) {
                                HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(scenicStyle.accent)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                                        Text(event.title)
                                            .font(.headline)
                                            .foregroundStyle(scenicStyle.primaryText)
                                        Text(event.location.isEmpty ? "No route location" : event.location)
                                            .font(.caption)
                                            .foregroundStyle(scenicStyle.secondaryText)
                                        Text(event.start.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(scenicStyle.accentReflection)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
        .scenicRoyalCard(role: .readability)
    }

    private var stopsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("Stops", systemImage: "signpost.right.and.left.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(scenicStyle.primaryText)
                Spacer()
                Text("\(stops.count)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(scenicStyle.accent)
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
                .buttonStyle(ScenicRoyalSecondaryButtonStyle())
            }

            Picker("Position", selection: $stopPosition) {
                ForEach(LifeRouteDayStop.Position.allCases) { position in
                    Text(position.rawValue).tag(position)
                }
            }
            .pickerStyle(.segmented)

            TextField("Stop name", text: $stopTitle)
                .scenicRoyalField()

            TextField("Stop address", text: $stopAddress)
                .textContentType(.fullStreetAddress)
                .focused($stopAddressFocused)
                .onChange(of: stopAddress) { value in
                    if suppressStopAutocompleteQuery {
                        suppressStopAutocompleteQuery = false
                        return
                    }
                    stopAutocomplete.update(query: value)
                }
                .onSubmit {
                    stopAutocomplete.clear()
                    stopAddressFocused = false
                }
                .scenicRoyalField()

            ForEach(stopAutocomplete.suggestions) { suggestion in
                Button {
                    suppressStopAutocompleteQuery = true
                    stopAddress = suggestion.addressText
                    stopAutocomplete.clear()
                    stopAddressFocused = false
                    LifeRouteHaptics.selection()
                } label: {
                    ScenicRoyalInsetRow(role: .ambient) {
                        HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(scenicStyle.accent)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(scenicStyle.primaryText)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(scenicStyle.secondaryText)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Uses this address for the new stop")
            }

            Stepper(
                "Stop duration: \(stopDurationMinutes) min",
                value: $stopDurationMinutes,
                in: 5...240,
                step: 5
            )
            .font(.subheadline.weight(.semibold))
            .scenicRoyalField()

            Button("Add stop") {
                addCustomStop()
            }
            .buttonStyle(ScenicRoyalPrimaryButtonStyle())

            if !stops.isEmpty {
                Divider().overlay(scenicStyle.accent.opacity(0.22))

                if !beforeStops.isEmpty {
                    Text("BEFORE")
                        .font(.caption2.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(scenicStyle.accentReflection)
                    ForEach(beforeStops) { stop in stopRow(stop) }
                }

                if !afterStops.isEmpty {
                    Text("AFTER")
                        .font(.caption2.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(scenicStyle.accentReflection)
                    ForEach(afterStops) { stop in stopRow(stop) }
                }
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(scenicStyle.secondaryText)
            }
        }
        .scenicRoyalCard(role: .readability)
    }

    private var routeOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Route options", systemImage: "slider.horizontal.3")
                .font(.title3.weight(.bold))
                .foregroundStyle(scenicStyle.primaryText)

            Picker("Travel mode", selection: $planState.routeMode) {
                ForEach(LifeRouteTransportMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle(isOn: $planState.returnHome) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Return home after the last stop")
                        .font(.subheadline.weight(.bold))
                    Text(routingState.homeAddress.isEmpty ? "Add a home address in Setup to use this." : routingState.homeAddress)
                        .font(.caption2)
                        .foregroundStyle(scenicStyle.secondaryText)
                }
            }
            .disabled(routingState.homeAddress.isEmpty)

            HStack(spacing: 8) {
                Image(systemName: routingState.currentLocation == nil ? "house.fill" : "location.fill")
                    .foregroundStyle(scenicStyle.accent)
                Text(routingState.currentLocation == nil ? "Route starts from Home fallback" : "Route starts from your live current location")
                    .font(.caption)
                    .foregroundStyle(scenicStyle.secondaryText)
            }
        }
        .scenicRoyalCard(role: .readability)
    }

    private var buildCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                buildRoute()
            } label: {
                Label(planState.isCalculating ? "Generating route…" : "Generate full day route", systemImage: "map.fill")
            }
            .buttonStyle(ScenicRoyalPrimaryButtonStyle())
            .disabled(planState.isCalculating || (routableDayEvents.isEmpty && stops.isEmpty))

            if let routeMessage = planState.message {
                Text(routeMessage)
                    .font(.caption)
                    .foregroundStyle(scenicStyle.secondaryText)
            }
        }
        .scenicRoyalCard(role: .readability)
    }

    private var routeResultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Route sequence")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(scenicStyle.primaryText)
                Spacer()
                Text("\(planState.legs.count) legs")
                    .font(.caption.weight(.black))
                    .foregroundStyle(scenicStyle.accent)
            }

            if let plan = planState.fullRoutePlan {
                Button {
                    if planState.hasStartedSequentialHandoff,
                       planState.nextSequentialLegIndex != nil {
                        planState.continueFullRoute(mode: planState.routeMode)
                    } else {
                        planState.startFullRoute(mode: planState.routeMode)
                    }
                } label: {
                    Label(fullRouteActionTitle(plan), systemImage: fullRouteActionIcon(plan))
                }
                .buttonStyle(ScenicRoyalPrimaryButtonStyle())
                .accessibilityHint(fullRouteAccessibilityHint(plan))

                if let fallbackReason = plan.fallbackReason {
                    Label(fallbackReason, systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(scenicStyle.secondaryText)
                        .accessibilityElement(children: .combine)
                } else {
                    Text("All \(plan.orderedLegs.count) route legs will be handed off together without changing their order.")
                        .font(.caption)
                        .foregroundStyle(scenicStyle.secondaryText)
                }
            }

            ForEach(planState.legs) { leg in
                ScenicRoyalRouteLegRow(leg: leg)
            }
        }
        .scenicRoyalCard(role: .readability)
    }

    private func stopRow(_ stop: LifeRouteDayStop) -> some View {
        ScenicRoyalInsetRow(role: .ambient) {
            HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(scenicStyle.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(scenicStyle.primaryText)
                    Text(stop.address)
                        .font(.caption)
                        .foregroundStyle(scenicStyle.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(stop.durationMinutes) min planned")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(scenicStyle.accentReflection)
                    if let appointmentID = stop.afterAppointmentID,
                       let appointment = dayEvents.first(where: { $0.id == appointmentID }) {
                        Text("After \(appointment.title)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(scenicStyle.accentReflection)
                    }
                }
                Spacer(minLength: ScenicRoyalDesignSystem.Spacing.compact)
                Button(role: .destructive) {
                    routingState.removeDayStop(id: stop.id)
                    message = "Stop removed."
                } label: {
                    Image(systemName: "trash")
                        .frame(
                            width: ScenicRoyalDesignSystem.Layout.minimumTouchTarget,
                            height: ScenicRoyalDesignSystem.Layout.minimumTouchTarget
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(stop.title)")
                .accessibilityHint("Removes this saved stop from the selected day")
            }
        }
    }

    private func addSavedPlace(_ place: LifeRouteSavedPlace, position: LifeRouteDayStop.Position) {
        let inserted = routingState.addDayStop(
            title: place.name,
            address: place.address,
            position: position,
            day: day,
            savedPlaceID: place.id,
            durationMinutes: place.minimumVisitMinutes
        )
        message = inserted ? "Added \(place.name)." : "That stop is already in this day."
    }

    private func addCustomStop() {
        let cleanAddress = stopAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAddress.isEmpty else {
            message = "Enter a stop address."
            return
        }
        let cleanTitle = stopTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let inserted = routingState.addDayStop(
            title: cleanTitle.isEmpty ? "Stop" : cleanTitle,
            address: cleanAddress,
            position: stopPosition,
            day: day,
            durationMinutes: stopDurationMinutes
        )
        stopTitle = ""
        suppressStopAutocompleteQuery = true
        stopAddress = ""
        stopDurationMinutes = 20
        stopAutocomplete.clear()
        stopAddressFocused = false
        message = inserted ? "Stop saved for this day." : "That stop is already in this day."
    }

    private func buildRoute() {
        planState.calculate(
            selectedDay: day,
            appointments: dayEvents.map {
                LifeRouteRouteAppointment(
                    id: $0.id,
                    title: $0.title,
                    address: $0.location,
                    start: $0.start,
                    end: $0.end,
                    isAllDay: $0.isAllDay
                )
            },
            beforeStops: beforeStops,
            afterStops: afterStops,
            routeBufferMinutes: routingState.routeBufferMinutes,
            homeAddress: routingState.homeAddress,
            currentLocation: routingState.currentLocation
        )
    }

    private func fullRouteActionTitle(_ plan: LifeRouteFullRouteHandoffPlan) -> String {
        if plan.requiresSequentialContinuation,
           planState.hasStartedSequentialHandoff,
           let nextIndex = planState.nextSequentialLegIndex {
            return "Continue with leg \(nextIndex + 1) of \(plan.orderedLegs.count) in \(plan.provider.title)"
        }
        if plan.requiresSequentialContinuation, planState.hasStartedSequentialHandoff {
            return "Start full route again in \(plan.provider.title)"
        }
        return "Start full route in \(plan.provider.title)"
    }

    private func fullRouteActionIcon(_ plan: LifeRouteFullRouteHandoffPlan) -> String {
        if plan.requiresSequentialContinuation, planState.hasStartedSequentialHandoff {
            return "arrow.forward.circle.fill"
        }
        return "location.north.line.fill"
    }

    private func fullRouteAccessibilityHint(_ plan: LifeRouteFullRouteHandoffPlan) -> String {
        if plan.requiresSequentialContinuation {
            return "Opens each computed leg in order. Return to LifeRoute after each leg to continue."
        }
        return "Sends the complete ordered route to \(plan.provider.title)."
    }
}
