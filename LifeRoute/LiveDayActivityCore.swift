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
    private var delivering = false
    private var lastContent: LifeRouteLiveDayAttributes.ContentState?
    private var lastStaleDate: Date?

    /// Root-scene task only: cancellation stops work while the app is inactive.
    /// The bounded sanity wake also reconciles wall-clock jumps. No background loop.
    func followWhileActive(itinerary: LifeRouteGeneratedItinerary) async {
        while !Task.isCancelled, run?.matches(itinerary) == true {
            let now = Date()
            let projection = LifeRouteLiveDayProjection.make(from: itinerary, at: now)
            if #available(iOS 16.2, *), let projection, matchingActivity() != nil {
                let content = Self.activityContent(projection: projection, now: now)
                if content.state != lastContent || content.staleDate != lastStaleDate {
                    await update(itinerary: itinerary)
                }
            }
            let delay = max(0.1, min(30, projection?.nextTransition?.timeIntervalSinceNow ?? 30))
            do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            catch { return }
        }
    }


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
        guard !delivering, !Task.isCancelled else { return }
        delivering = true
        defer { delivering = false }
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
            message = "Live Day is running in LifeRoute. Lock Screen projection needs a generated day schedule."
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
            let delivered = Self.activityContent(projection: projection, now: now)
            lastContent = delivered.state
            lastStaleDate = delivered.staleDate
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

        guard !delivering, !Task.isCancelled else { return }
        delivering = true
        defer { delivering = false }
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
            message = "Live Day is still running in LifeRoute. No generated day schedule is available for the Lock Screen."
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

        let content = Self.activityContent(projection: projection, now: now)
        await activity.update(content)
        guard operationID == currentOperationID, run?.matches(itinerary) == true else { return }
        lastContent = content.state
        lastStaleDate = content.staleDate
        activityStatus = .active
        message = "Live Day and its Lock Screen projection are up to date."
    }

    func end() async {
        let currentOperationID = UUID()
        operationID = currentOperationID
        run = nil
        lastContent = nil
        lastStaleDate = nil
        await endLockScreenActivity()
        guard operationID == currentOperationID, run == nil else { return }
        activityStatus = .idle
        message = "Live Day ended."
    }

    private func endLockScreenActivity() async {
        let expectedOperationID = operationID
        guard #available(iOS 16.2, *) else {
            activeActivityID = nil
            return
        }
        for activity in Activity<LifeRouteLiveDayAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        guard operationID == expectedOperationID else { return }
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
            let delivered = Self.activityContent(projection: projection, now: now)
            lastContent = delivered.state
            lastStaleDate = delivered.staleDate
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
        let state = LifeRouteLiveDayAttributes.ContentState(
            phaseLabel: projection.phaseLabel,
            primaryTitle: LifeRouteCalendarDisplay.title(projection.primaryTitle),
            secondaryText: projection.secondaryText ?? "Generated day schedule",
            countdownTarget: projection.countdownTarget,
            eventStart: projection.appointmentStart,
            eventEnd: projection.appointmentEnd,
            routeSummary: projection.routeSummary,
            plannedStopSummary: projection.plannedStopSummary,
            returnHomePlanned: projection.returnHomePlanned
        )
        let staleDate = projection.nextTransition
        return ActivityContent(state: state, staleDate: staleDate, relevanceScore: 1)
    }
}
