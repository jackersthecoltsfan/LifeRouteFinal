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

    func start(itinerary: LifeRouteGeneratedItinerary) async {
        guard #available(iOS 16.2, *) else {
            message = "Live Activities require iOS 16.2 or later."
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            message = "Live Activities are disabled for LifeRoute in iPhone Settings."
            return
        }
        let now = Date()
        guard let projection = LifeRouteLiveDayProjection.make(from: itinerary, at: now) else {
            message = "Generate a route with an upcoming timed appointment before starting Live Day."
            return
        }

        for activity in Activity<LifeRouteLiveDayAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        let attributes = LifeRouteLiveDayAttributes(
            launchedAt: now,
            dayLabel: itinerary.selectedDay.formatted(
                .dateTime.weekday(.wide).month(.abbreviated).day()
            )
        )
        let content = Self.activityContent(projection: projection, now: now)

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

    func update(itinerary: LifeRouteGeneratedItinerary) async {
        guard #available(iOS 16.2, *) else { return }
        let now = Date()
        guard let projection = LifeRouteLiveDayProjection.make(from: itinerary, at: now) else {
            await end()
            message = "Live Day ended because the generated route has no remaining departure."
            return
        }
        guard let activity = matchingActivity() else {
            await start(itinerary: itinerary)
            return
        }

        await activity.update(Self.activityContent(projection: projection, now: now))
        isActive = true
        message = "Lock Screen Live Day updated."
    }

    func end() async {
        guard #available(iOS 16.2, *) else { return }
        for activity in Activity<LifeRouteLiveDayAttributes>.activities {
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
        isActive = fallback != nil
        return fallback
    }

    @available(iOS 16.2, *)
    private static func activityContent(
        projection: LifeRouteLiveDayProjection,
        now: Date
    ) -> ActivityContent<LifeRouteLiveDayAttributes.ContentState> {
        let eventEnd = max(
            projection.appointmentStart,
            projection.appointmentEnd ?? projection.appointmentStart
        )
        let state = LifeRouteLiveDayAttributes.ContentState(
            phaseLabel: projection.phaseLabel,
            primaryTitle: projection.primaryTitle,
            secondaryText: projection.secondaryText ?? "Next route commitment",
            countdownTarget: projection.countdownTarget,
            eventStart: projection.appointmentStart,
            eventEnd: eventEnd,
            routeSummary: projection.routeSummary,
            plannedStopSummary: projection.plannedStopSummary,
            returnHomePlanned: projection.returnHomePlanned
        )
        let staleDate = max(now.addingTimeInterval(60), projection.countdownTarget)
        return ActivityContent(state: state, staleDate: staleDate, relevanceScore: 1)
    }
}
