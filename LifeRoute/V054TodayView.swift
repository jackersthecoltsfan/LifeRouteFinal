import SwiftUI

struct V054TodayView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @EnvironmentObject private var themeStore: LifeRouteThemeStore

    @ObservedObject var router: AppRouter
    @ObservedObject var calendarState: CalendarCoreState
    @ObservedObject var routingState: RoutingLocationCore

    @StateObject private var liveActivity = LiveDayActivityCore()
    @State private var liveDayEnabled = false
    @State private var returnHomeOnLiveDay = true

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                hero
                quickActions
                overviewCard
                liveDayCard
                gapSuggestions
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var todayEvents: [LifeRouteCalendarEvent] {
        calendarState.events(on: Date()).sorted { $0.start < $1.start }
    }

    private var nextEvent: LifeRouteCalendarEvent? {
        todayEvents.first { $0.end > Date() }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LifeRouteCinematicBackdrop(
                theme: themeStore.selectedTheme,
                palette: palette
            )

            LinearGradient(
                colors: [Color.black.opacity(0.04), Color.black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("LifeRoute")
                        .font(.system(size: 29, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: themeStore.selectedTheme.artworkSymbols.primary)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(palette.accentSecondary)
                        .padding(10)
                        .background(.black.opacity(0.30), in: Circle())
                }

                Text("Plan your day. Optimize every gap.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))

                Spacer(minLength: 80)

                HStack(spacing: 7) {
                    Image(systemName: routingState.liveLocationEnabled ? "location.fill.viewfinder" : "location.fill")
                        .foregroundStyle(palette.accentSecondary)
                    Text(routingState.locationMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }
            }
            .padding(18)
        }
        .frame(height: 235)
        .clipShape(RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .stroke(palette.accent.opacity(0.34), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.38), radius: 24, y: 12)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("QUICK ACTIONS")
            HStack(spacing: 9) {
                NavigationLink {
                    DayRoutePlanningView(calendarState: calendarState, routingState: routingState)
                } label: {
                    quickAction("Plan Route", "arrow.triangle.turn.up.right.diamond.fill", palette.accentSecondary)
                }
                .buttonStyle(.plain)

                Button {
                    if routingState.liveLocationEnabled {
                        routingState.stopLiveLocation()
                    } else {
                        routingState.requestCurrentLocation()
                    }
                } label: {
                    quickAction("Current Location", "location.fill", .blue)
                }
                .buttonStyle(.plain)
                .disabled(routingState.locationRequestInFlight)

                Button {
                    router.select(.schedule)
                } label: {
                    quickAction("Open Schedule", "calendar", .purple)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    DayRoutePlanningView(calendarState: calendarState, routingState: routingState)
                } label: {
                    quickAction("Add Stop", "plus", palette.accentSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("TODAY’S OVERVIEW")

            if let event = nextEvent {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next Event")
                                .font(.caption)
                                .foregroundStyle(palette.textSecondary)
                            Text(event.title)
                                .font(.headline.weight(.black))
                                .foregroundStyle(palette.accentSecondary)
                                .lineLimit(1)
                            Text(event.isAllDay ? "All day" : "\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(palette.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(event.start <= context.date ? "Ends in" : "Starts in")
                                .font(.caption2)
                                .foregroundStyle(palette.textSecondary)
                            Text(timeRemaining(to: event.start <= context.date ? event.end : event.start, now: context.date))
                                .font(.title3.weight(.black))
                                .monospacedDigit()
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(12)
                    .background(palette.panelElevated.opacity(0.38), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
            } else {
                Text("No more timed events today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 9) {
                metric("\(todayEvents.count)", "Events", "calendar")
                metric("\(routingState.routeEstimates.count)", "Routes", "car.fill")
                metric("\(routingState.savedPlaces.filter(\.useInGapSuggestions).count)", "Gap-ready", "sparkles")
            }
        }
        .lifeRouteCard()
    }

    private var liveDayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(liveDayEnabled ? "Live Day" : "Generate Live Day", systemImage: "bolt.horizontal.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                if liveActivity.isActive {
                    Text("LOCK SCREEN LIVE")
                        .font(.caption2.weight(.black))
                        .tracking(0.7)
                        .foregroundStyle(Color.black.opacity(0.78))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(palette.accent, in: Capsule())
                }
            }

            Text("Generate a time-aware day and keep the next event / leave countdown visible on the iPhone Lock Screen and Dynamic Island.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)

            Toggle("Return home after the day", isOn: $returnHomeOnLiveDay)
                .font(.subheadline.weight(.semibold))
                .disabled(routingState.homeAddress.isEmpty)

            if liveDayEnabled {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    liveSummary(now: context.date)
                }

                HStack(spacing: 9) {
                    Button {
                        Task {
                            await liveActivity.update(
                                events: todayEvents,
                                savedPlaces: routingState.savedPlaces,
                                routeEstimates: routingState.routeEstimates,
                                returnHomePlanned: returnHomeOnLiveDay
                            )
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())

                    Button {
                        liveDayEnabled = false
                        Task { await liveActivity.end() }
                    } label: {
                        Label("End", systemImage: "stop.fill")
                    }
                    .buttonStyle(LifeRouteSecondaryButtonStyle())
                }
            } else {
                Button {
                    liveDayEnabled = true
                    LifeRouteHaptics.primaryAction()
                    Task {
                        await liveActivity.start(
                            events: todayEvents,
                            savedPlaces: routingState.savedPlaces,
                            routeEstimates: routingState.routeEstimates,
                            returnHomePlanned: returnHomeOnLiveDay
                        )
                    }
                } label: {
                    Label("Generate day + start Live Activity", systemImage: "sparkles")
                }
                .buttonStyle(LifeRoutePrimaryButtonStyle())
            }

            if let message = liveActivity.message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .lifeRouteCard()
    }

    private var gapSuggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("SUGGESTED GAP FILLERS")
                Spacer()
                NavigationLink {
                    DayRoutePlanningView(calendarState: calendarState, routingState: routingState)
                } label: {
                    Text("Plan")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.blue)
                }
            }

            let suggestions = routingState.savedPlaces.filter(\.useInGapSuggestions)
            if suggestions.isEmpty {
                Text("Mark saved places as gap suggestions in Setup and they’ll surface here.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .lifeRouteCard()
            } else {
                ForEach(suggestions.prefix(4)) { place in
                    NavigationLink {
                        DayRoutePlanningView(calendarState: calendarState, routingState: routingState)
                    } label: {
                        HStack(spacing: 11) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(palette.accent.opacity(0.15))
                                Image(systemName: placeIcon(place.kind))
                                    .foregroundStyle(palette.accentSecondary)
                            }
                            .frame(width: 46, height: 46)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(place.name)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(palette.textPrimary)
                                Text("Useful visit: \(place.minimumVisitMinutes) min")
                                    .font(.caption2)
                                    .foregroundStyle(palette.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(palette.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .lifeRouteCard()
                }
            }
        }
    }

    @ViewBuilder
    private func liveSummary(now: Date) -> some View {
        if let event = todayEvents.first(where: { $0.end > now }) {
            VStack(alignment: .leading, spacing: 5) {
                Text(event.start <= now ? "CURRENT EVENT" : "NEXT EVENT")
                    .font(.caption2.weight(.black))
                    .tracking(1)
                    .foregroundStyle(palette.accent)
                Text(event.title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(palette.textPrimary)
                Text(timeRemaining(to: event.start <= now ? event.end : event.start, now: now))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(palette.accentSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(palette.panelElevated.opacity(0.32), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        } else {
            Text("Today’s timed events are complete.")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func quickAction(_ title: String, _ systemImage: String, _ accent: Color) -> some View {
        VStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.15))
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(accent)
            }
            .frame(width: 44, height: 44)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .padding(.vertical, 8)
        .background(palette.panelGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.22), lineWidth: 1)
        }
    }

    private func metric(_ value: String, _ label: String, _ systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(palette.accent)
            Text(value)
                .font(.title3.weight(.black))
                .foregroundStyle(palette.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .padding(10)
        .background(palette.panelElevated.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sectionLabel(_ value: String) -> some View {
        Text(value)
            .font(.caption2.weight(.black))
            .tracking(1.2)
            .foregroundStyle(palette.textSecondary)
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

    private func placeIcon(_ kind: LifeRoutePlaceKind) -> String {
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
}
