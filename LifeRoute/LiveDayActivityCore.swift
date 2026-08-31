import Foundation
import Combine
import ActivityKit

@MainActor
final class LiveDayActivityCore: ObservableObject {
    @Published private(set) var run: LifeRouteLiveDayRun?
    @Published private(set) var activityStatus: LifeRouteLiveActivityDeliveryStatus = .idle
    @Published private(set) var message: String?

    private var activeActivityID: String?
    private var operationID = UUID()

    var isRunning: Bool { run != nil }
    var isActive: Bool { isRunning }
    var isLockScreenActive: Bool { activityStatus.isActive }

    init() {
        if #available(iOS 16.2, *) {
            activeActivityID = Activity<LifeRouteLiveDayAttributes>.activities.first?.id
            activityStatus = activeActivityID == nil ? .idle : .active
        }
    }

    func start(itinerary: LifeRouteGeneratedItinerary) async {
        let now = Date()
        switch LifeRouteLiveDayRunPolicy.decision(for: itinerary, at: now) {
        case .reject(let reason):
            message = reason
            return
        case .start(let newRun):
            run = newRun
        }

        let currentOperationID = UUID()
        operationID = currentOperationID
        message = "Live Day is running in LifeRoute."

        guard #available(iOS 16.2, *) else {
            activityStatus = .unavailable
            message = "Live Day is running in LifeRoute. Lock Screen Live Activities require iOS 16.2 or later."
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            activityStatus = .disabled
            message = "Live Day is running in LifeRoute. Lock Screen Live Activities are disabled in Settings."
            return
        }
        guard let projection = LifeRouteLiveDayProjection.make(from: itinerary, at: now) else {
            activityStatus = .noUpcomingDeparture
            message = "Live Day is running in LifeRoute. Lock Screen projection needs an upcoming timed departure."
            return
        }

        activityStatus = .requesting

        for activity in Activity<LifeRouteLiveDayAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        guard operationID == currentOperationID, run?.matches(itinerary) == true else { return }

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
            guard operationID == currentOperationID, run?.matches(itinerary) == true else {
                await activity.end(nil, dismissalPolicy: .immediate)
                return
            }
            activeActivityID = activity.id
            activityStatus = .active
            message = "Live Day is running in LifeRoute and on your Lock Screen."
        } catch {
            guard operationID == currentOperationID, run?.matches(itinerary) == true else { return }
            activeActivityID = nil
            activityStatus = .failed
            message = "Live Day is running in LifeRoute. The Lock Screen Live Activity could not start: \(error.localizedDescription)"
        }
    }

    func update(itinerary: LifeRouteGeneratedItinerary) async {
        guard run?.matches(itinerary) == true else {
            await start(itinerary: itinerary)
            return
        }

        let currentOperationID = UUID()
        operationID = currentOperationID
        let now = Date()
        guard #available(iOS 16.2, *) else {
            activityStatus = .unavailable
            message = "Live Day is running in LifeRoute. Lock Screen Live Activities require iOS 16.2 or later."
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            await endLockScreenActivity()
            guard operationID == currentOperationID, run?.matches(itinerary) == true else { return }
            activityStatus = .disabled
            message = "Live Day is running in LifeRoute. Lock Screen Live Activities are disabled in Settings."
            return
        }
        guard let projection = LifeRouteLiveDayProjection.make(from: itinerary, at: now) else {
            await endLockScreenActivity()
            guard operationID == currentOperationID, run?.matches(itinerary) == true else { return }
            activityStatus = .noUpcomingDeparture
            message = "Live Day is still running in LifeRoute. There is no remaining timed departure for the Lock Screen."
            return
        }
        guard let activity = matchingActivity() else {
            await requestLockScreenActivity(
                itinerary: itinerary,
                projection: projection,
                now: now,
                operationID: currentOperationID
            )
            return
        }

        await activity.update(Self.activityContent(projection: projection, now: now))
        guard operationID == currentOperationID, run?.matches(itinerary) == true else { return }
        activityStatus = .active
        message = "Live Day and its Lock Screen projection are up to date."
    }

    func end() async {
        operationID = UUID()
        run = nil
        await endLockScreenActivity()
        activityStatus = .idle
        message = "Live Day ended."
    }

    private func endLockScreenActivity() async {
        guard #available(iOS 16.2, *) else {
            activeActivityID = nil
            return
        }
        for activity in Activity<LifeRouteLiveDayAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activeActivityID = nil
    }

    @available(iOS 16.2, *)
    private func requestLockScreenActivity(
        itinerary: LifeRouteGeneratedItinerary,
        projection: LifeRouteLiveDayProjection,
        now: Date,
        operationID expectedOperationID: UUID
    ) async {
        activityStatus = .requesting
        let attributes = LifeRouteLiveDayAttributes(
            launchedAt: run?.startedAt ?? now,
            dayLabel: itinerary.selectedDay.formatted(
                .dateTime.weekday(.wide).month(.abbreviated).day()
            )
        )
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: Self.activityContent(projection: projection, now: now),
                pushType: nil
            )
            guard operationID == expectedOperationID, run?.matches(itinerary) == true else {
                await activity.end(nil, dismissalPolicy: .immediate)
                return
            }
            activeActivityID = activity.id
            activityStatus = .active
            message = "Live Day is running in LifeRoute and on your Lock Screen."
        } catch {
            guard operationID == expectedOperationID, run?.matches(itinerary) == true else { return }
            activeActivityID = nil
            activityStatus = .failed
            message = "Live Day is running in LifeRoute. The Lock Screen Live Activity could not start: \(error.localizedDescription)"
        }
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
