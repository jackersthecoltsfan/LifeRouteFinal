import Foundation
import Combine
import ActivityKit

@MainActor
final class LiveDayActivityCore: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var message: String?

    private var activeActivityID: String?

    init() {
        if #available(iOS 16.2, *) {
            activeActivityID = Activity<LifeRouteLiveDayAttributes>.activities.first?.id
            isActive = activeActivityID != nil
        }
    }

    func start(
        events: [LifeRouteCalendarEvent],
        dayStops: [LifeRouteDayStop],
        savedPlaces: [LifeRouteSavedPlace],
        routeEstimates: [UUID: LifeRouteRouteEstimate],
        returnHomePlanned: Bool,
        day: Date = Date()
    ) async {
        guard #available(iOS 16.2, *) else {
            message = "Live Activities require iOS 16.2 or later."
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            message = "Live Activities are disabled for LifeRoute in iPhone Settings."
            return
        }
        guard let state = Self.contentState(
            events: events,
            dayStops: dayStops,
            savedPlaces: savedPlaces,
            routeEstimates: routeEstimates,
            returnHomePlanned: returnHomePlanned,
            now: Date()
        ) else {
            message = "Add a timed event on the selected day before starting Live Day on the Lock Screen."
            return
        }

        for activity in Activity<LifeRouteLiveDayAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        let attributes = LifeRouteLiveDayAttributes(
            launchedAt: Date(),
            dayLabel: day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        )
        let content = ActivityContent(
            state: state,
            staleDate: state.eventEnd.addingTimeInterval(30 * 60),
            relevanceScore: 1
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            activeActivityID = activity.id
            isActive = true
            message = "Live Day is on your Lock Screen."
        } catch {
            activeActivityID = nil
            isActive = false
            message = "Live Day could not start: \(error.localizedDescription)"
        }
    }

    func update(
        events: [LifeRouteCalendarEvent],
        dayStops: [LifeRouteDayStop],
        savedPlaces: [LifeRouteSavedPlace],
        routeEstimates: [UUID: LifeRouteRouteEstimate],
        returnHomePlanned: Bool
    ) async {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = matchingActivity(),
              let state = Self.contentState(
                events: events,
                dayStops: dayStops,
                savedPlaces: savedPlaces,
                routeEstimates: routeEstimates,
                returnHomePlanned: returnHomePlanned,
                now: Date()
              ) else { return }

        let content = ActivityContent(
            state: state,
            staleDate: state.eventEnd.addingTimeInterval(30 * 60),
            relevanceScore: 1
        )
        await activity.update(content)
        isActive = true
        message = "Lock Screen Live Day updated."
    }

    func end() async {
        guard #available(iOS 16.2, *) else { return }
        let activities = Activity<LifeRouteLiveDayAttributes>.activities
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activeActivityID = nil
        isActive = false
        message = "Live Day ended."
    }

    @available(iOS 16.2, *)
    private func matchingActivity() -> Activity<LifeRouteLiveDayAttributes>? {
        if let activeActivityID,
           let matching = Activity<LifeRouteLiveDayAttributes>.activities.first(where: { $0.id == activeActivityID }) {
            return matching
        }
        let fallback = Activity<LifeRouteLiveDayAttributes>.activities.first
        activeActivityID = fallback?.id
        return fallback
    }

    private static func contentState(
        events: [LifeRouteCalendarEvent],
        dayStops: [LifeRouteDayStop],
        savedPlaces: [LifeRouteSavedPlace],
        routeEstimates: [UUID: LifeRouteRouteEstimate],
        returnHomePlanned: Bool,
        now: Date
    ) -> LifeRouteLiveDayAttributes.ContentState? {
        let timed = events
            .filter { !$0.isAllDay && $0.end > now }
            .sorted { $0.start < $1.start }
        guard let event = timed.first else { return nil }

        let estimate = matchingEstimate(
            for: event,
            savedPlaces: savedPlaces,
            routeEstimates: routeEstimates
        )
        let leaveDate = estimate.map { event.start.addingTimeInterval(-($0.travelTimeSeconds + 10 * 60)) }

        let phaseLabel: String
        let target: Date
        let secondary: String
        if event.start <= now && event.end > now {
            phaseLabel = "CURRENT EVENT"
            target = event.end
            secondary = "Ends in"
        } else if let leaveDate, leaveDate > now {
            phaseLabel = "LEAVE IN"
            target = leaveDate
            secondary = event.location.isEmpty ? "Next: \(event.title)" : event.location
        } else {
            phaseLabel = "NEXT EVENT IN"
            target = event.start
            secondary = event.location.isEmpty ? "Up next" : event.location
        }

        let routeSummary: String
        if let estimate {
            routeSummary = "\(estimate.durationLabel) · \(estimate.distanceLabel)"
        } else {
            routeSummary = "Route estimate not loaded"
        }

        return LifeRouteLiveDayAttributes.ContentState(
            phaseLabel: phaseLabel,
            primaryTitle: event.title,
            secondaryText: secondary,
            countdownTarget: target,
            eventStart: event.start,
            eventEnd: event.end,
            routeSummary: routeSummary,
            plannedStopSummary: plannedStopSummary(for: dayStops),
            returnHomePlanned: returnHomePlanned
        )
    }

    private static func plannedStopSummary(for dayStops: [LifeRouteDayStop]) -> String? {
        let stops = LifeRouteDayStopCollection.sanitized(dayStops)
        guard !stops.isEmpty else { return nil }
        let names = stops.prefix(2).map(\.title).joined(separator: " · ")
        let remaining = stops.count - min(stops.count, 2)
        return remaining > 0 ? "Stops: \(names) +\(remaining)" : "Stops: \(names)"
    }

    private static func matchingEstimate(
        for event: LifeRouteCalendarEvent,
        savedPlaces: [LifeRouteSavedPlace],
        routeEstimates: [UUID: LifeRouteRouteEstimate]
    ) -> LifeRouteRouteEstimate? {
        let eventLocation = event.location.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !eventLocation.isEmpty else { return nil }
        guard let place = savedPlaces.first(where: {
            let address = $0.address.lowercased()
            let name = $0.name.lowercased()
            return eventLocation.contains(address) || address.contains(eventLocation) || eventLocation.contains(name)
        }) else { return nil }
        return routeEstimates[place.id]
    }
}
