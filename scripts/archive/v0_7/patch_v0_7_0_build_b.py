#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/V054TodayView.swift"

TODAY_VIEW = r'''import SwiftUI

// v0.7.0 Build B Today/Home: the reference implementation for the v0.7 screen language.
struct V054TodayView: View {
    @Environment(\.lifeRoutePalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var themeStore: LifeRouteThemeStore

    @ObservedObject var router: AppRouter
    @ObservedObject var calendarState: CalendarCoreState
    @ObservedObject var routingState: RoutingLocationCore

    @StateObject private var liveActivity = LiveDayActivityCore()
    @State private var liveDayEnabled = false
    @State private var returnHomeOnLiveDay = true
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())

    var body: some View {
        ScrollView {
            LazyVStack(spacing: LifeRouteDesign.Layout.cardGap) {
                hero
                daySelector
                quickActions
                overviewCard
                gapSuggestions
                liveDayCard
            }
            .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: selectedDay) { _ in
            liveDayEnabled = false
        }
    }

    private var selectedDayEvents: [LifeRouteCalendarEvent] {
        calendarState.events(on: selectedDay).sorted { $0.start < $1.start }
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

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            LifeRouteTodayHeroScene()

            LinearGradient(
                colors: [Color.black.opacity(0.04), Color.black.opacity(0.10), Color.black.opacity(0.60)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: 0) {
                    Text("Life")
                        .foregroundStyle(.white)
                    Text("Route")
                        .foregroundStyle(palette.accentSecondary)
                    Spacer(minLength: 12)
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.accentSecondary)
                        .frame(width: 42, height: 42)
                        .background(Color.black.opacity(0.30), in: Circle())
                        .overlay {
                            Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)
                        }
                        .accessibilityHidden(true)
                }
                .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 27 : 30, weight: .black, design: .rounded))

                Text("Plan your day. Optimize every gap.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))

                Spacer(minLength: 42)

                if routingState.liveLocationEnabled {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                        Text("Live location active")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.90))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.30), in: Capsule())
                }
            }
            .padding(16)
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 238 : 205)
        .clipShape(RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeRouteDesign.Radius.hero, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [palette.accent.opacity(0.46), Color.white.opacity(0.08), palette.accentSecondary.opacity(0.26)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: LifeRouteDesign.Stroke.subtle
                )
        }
        .shadow(color: Color.black.opacity(0.34), radius: 18, y: 9)
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
                DatePicker("Choose day", selection: $selectedDay, displayedComponents: .date)
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

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 9) {
            LifeRouteSectionLabel(title: "Quick Actions")

            LazyVGrid(columns: quickActionColumns, spacing: 10) {
                NavigationLink {
                    DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)
                } label: {
                    quickActionLabel(
                        "Plan Route",
                        "arrow.triangle.turn.up.right.diamond.fill",
                        accent: palette.accentSecondary
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
                        accent: palette.accent,
                        isActive: routingState.liveLocationEnabled
                    )
                }
                .buttonStyle(.plain)
                .disabled(routingState.locationRequestInFlight)

                Button {
                    LifeRouteHaptics.selection()
                    router.select(.schedule)
                } label: {
                    quickActionLabel("Open Schedule", "calendar", accent: palette.accentSecondary)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)
                } label: {
                    quickActionLabel("Add Stop", "plus", accent: palette.accentSecondary)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })
            }
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            LifeRouteSectionLabel(
                title: Calendar.current.isDateInToday(selectedDay) ? "Today’s Overview" : "Day Overview"
            )

            if let event = nextEvent {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    nextEventCard(event, now: context.date)
                }
            } else {
                HStack(spacing: 10) {
                    LifeRouteIconBadge(systemImage: "checkmark.circle.fill", prominent: true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Calendar.current.isDateInToday(selectedDay) ? "No more timed events today" : "No timed events on this day")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.textPrimary)
                        Text("Your selected day is clear.")
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(palette.panelElevated.opacity(0.34), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }

            HStack(spacing: 10) {
                overviewMetric(
                    value: "\(drivingEstimates.count)",
                    label: "Total Drives",
                    detail: Calendar.current.isDateInToday(selectedDay) ? "Today" : "Calculated",
                    systemImage: "car.fill"
                )
                overviewMetric(
                    value: totalDrivingDurationLabel,
                    label: "Est. Driving",
                    detail: "Total",
                    systemImage: "clock.fill"
                )
            }
        }
        .lifeRouteCard()
    }

    private func nextEventCard(_ event: LifeRouteCalendarEvent, now: Date) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Next Event")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(palette.textSecondary)
                Text(event.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.accentSecondary)
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
                Text(nextEventCountdownLabel(event, now: now))
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
                Text(nextEventCountdownValue(event, now: now))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.panelElevated.opacity(0.46))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.accent.opacity(0.28), lineWidth: LifeRouteDesign.Stroke.subtle)
        }
    }

    private var gapSuggestions: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                LifeRouteSectionLabel(title: "Suggested Gap Fillers")
                Spacer()
                NavigationLink {
                    DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)
                } label: {
                    Text("See all")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(palette.accent)
                }
                .simultaneousGesture(TapGesture().onEnded { LifeRouteHaptics.selection() })
            }

            let suggestions = routingState.savedPlaces.filter(\.useInGapSuggestions)
            if suggestions.isEmpty {
                HStack(spacing: 10) {
                    LifeRouteIconBadge(systemImage: "sparkles", prominent: true)
                    Text("Mark saved places as gap suggestions in Setup and they’ll surface here.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .lifeRouteCard()
            } else {
                ForEach(suggestions.prefix(4)) { place in
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
                Image(systemName: placeIcon(place.kind))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.accentSecondary)
            }
            .frame(width: 46, height: 46)

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
        .padding(10)
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
                LifeRouteIconBadge(systemImage: "bolt.horizontal.circle.fill", prominent: true)
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

                HStack(spacing: 9) {
                    Button {
                        LifeRouteHaptics.primaryAction()
                        Task {
                            await liveActivity.update(
                                events: selectedDayEvents,
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
                        LifeRouteHaptics.selection()
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
                            events: selectedDayEvents,
                            savedPlaces: routingState.savedPlaces,
                            routeEstimates: routingState.routeEstimates,
                            returnHomePlanned: returnHomeOnLiveDay,
                            day: selectedDay
                        )
                    }
                } label: {
                    Label("Generate + launch selected day", systemImage: "sparkles")
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
            .frame(width: 46, height: 46)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accent.opacity(isActive ? 0.48 : 0.26), lineWidth: LifeRouteDesign.Stroke.subtle)
            }
            .shadow(color: accent.opacity(isActive ? 0.18 : 0.08), radius: 8, y: 3)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .top)
        .contentShape(Rectangle())
    }

    private func overviewMetric(
        value: String,
        label: String,
        detail: String,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(palette.accent)
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(10)
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

private struct LifeRouteTodayHeroScene: View {
    @Environment(\.lifeRoutePalette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: [
                        palette.backgroundTop,
                        palette.backgroundBottom,
                        palette.panel.opacity(0.96),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [palette.accent.opacity(0.24), Color.clear],
                    center: .topTrailing,
                    startRadius: 4,
                    endRadius: max(size.width, size.height) * 0.70
                )

                mountainBack(size)
                    .fill(palette.accent.opacity(0.12))
                    .offset(y: size.height * 0.18)

                mountainMid(size)
                    .fill(palette.panelElevated.opacity(0.90))
                    .offset(y: size.height * 0.26)

                mountainFront(size)
                    .fill(Color.black.opacity(0.52))
                    .offset(y: size.height * 0.36)

                routePath(size)
                    .stroke(
                        palette.accent.opacity(0.20),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 6)

                routePath(size)
                    .stroke(
                        palette.accentGradient,
                        style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
                    )
            }
            .clipped()
        }
        .accessibilityHidden(true)
    }

    private func mountainBack(_ size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height * 0.54))
            path.addLine(to: CGPoint(x: size.width * 0.17, y: size.height * 0.25))
            path.addLine(to: CGPoint(x: size.width * 0.30, y: size.height * 0.48))
            path.addLine(to: CGPoint(x: size.width * 0.50, y: size.height * 0.16))
            path.addLine(to: CGPoint(x: size.width * 0.68, y: size.height * 0.46))
            path.addLine(to: CGPoint(x: size.width * 0.84, y: size.height * 0.29))
            path.addLine(to: CGPoint(x: size.width, y: size.height * 0.50))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
    }

    private func mountainMid(_ size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height * 0.55))
            path.addLine(to: CGPoint(x: size.width * 0.19, y: size.height * 0.34))
            path.addLine(to: CGPoint(x: size.width * 0.38, y: size.height * 0.57))
            path.addLine(to: CGPoint(x: size.width * 0.58, y: size.height * 0.30))
            path.addLine(to: CGPoint(x: size.width * 0.77, y: size.height * 0.55))
            path.addLine(to: CGPoint(x: size.width, y: size.height * 0.41))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
    }

    private func mountainFront(_ size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height * 0.60))
            path.addLine(to: CGPoint(x: size.width * 0.18, y: size.height * 0.47))
            path.addLine(to: CGPoint(x: size.width * 0.36, y: size.height * 0.64))
            path.addLine(to: CGPoint(x: size.width * 0.55, y: size.height * 0.45))
            path.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.64))
            path.addLine(to: CGPoint(x: size.width, y: size.height * 0.49))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
    }

    private func routePath(_ size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: size.width * 0.49, y: size.height * 1.04))
            path.addCurve(
                to: CGPoint(x: size.width * 0.55, y: size.height * 0.69),
                control1: CGPoint(x: size.width * 0.37, y: size.height * 0.90),
                control2: CGPoint(x: size.width * 0.72, y: size.height * 0.81)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.79, y: size.height * 0.47),
                control1: CGPoint(x: size.width * 0.43, y: size.height * 0.59),
                control2: CGPoint(x: size.width * 0.72, y: size.height * 0.55)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.92, y: size.height * 0.34),
                control1: CGPoint(x: size.width * 0.84, y: size.height * 0.43),
                control2: CGPoint(x: size.width * 0.87, y: size.height * 0.38)
            )
        }
    }
}
'''


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    if "v0.7.0 Build B Today/Home" in text:
        return

    required = [
        "private var daySelector: some View",
        "v0.6.3 responsive day selector layout",
        "DayRoutePlanningView(calendarState: calendarState, routingState: routingState, day: selectedDay)",
        'Label("Generate + launch selected day", systemImage: "sparkles")',
    ]
    missing = [token for token in required if token not in text]
    if missing:
        raise SystemExit(f"v0.7.0 Build B patch failed: expected materialized v0.6.3 Today baseline missing {missing}")

    PATH.write_text(TODAY_VIEW, encoding="utf-8")
    print(
        "LifeRoute v0.7.0 Build B patch applied: Today/Home rebuilt around the approved hero, compact selected-day control, premium quick actions, overview metrics, gap fillers, and preserved Live Day behavior."
    )


if __name__ == "__main__":
    main()
