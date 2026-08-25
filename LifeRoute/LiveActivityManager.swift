import ActivityKit
import Foundation

@available(iOS 16.1, *)
enum LifeRouteLiveActivityManager {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackFormatter = ISO8601DateFormatter()

    static func start(from body: [String: Any]) async -> [String: Any] {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return [
                "supported": true,
                "started": false,
                "message": "Live Activities are disabled for LifeRoute."
            ]
        }

        let checkpoints = parseCheckpoints(body["checkpoints"] as? [[String: Any]] ?? [])
        guard !checkpoints.isEmpty else {
            return [
                "supported": true,
                "started": false,
                "message": "Generate a day with at least one scheduled stop first."
            ]
        }

        let dayLabel = clean(body["dayLabel"] as? String, fallback: "LifeRoute Day")
        await endAll(dismissImmediately: true)

        do {
            let attributes = LifeRouteActivityAttributes(
                dayLabel: dayLabel,
                checkpoints: Array(checkpoints.prefix(12))
            )
            let state = LifeRouteActivityAttributes.ContentState(
                updatedAt: Date(),
                status: "live"
            )
            let activity = try Activity<LifeRouteActivityAttributes>.request(
                attributes: attributes,
                contentState: state,
                pushType: nil
            )
            return [
                "supported": true,
                "started": true,
                "activityID": activity.id,
                "checkpointCount": attributes.checkpoints.count
            ]
        } catch {
            return [
                "supported": true,
                "started": false,
                "message": error.localizedDescription
            ]
        }
    }

    static func update(status: String = "live") async -> [String: Any] {
        let activities = Activity<LifeRouteActivityAttributes>.activities
        guard !activities.isEmpty else {
            return ["supported": true, "updated": false, "message": "No active LifeRoute Live Activity."]
        }
        let state = LifeRouteActivityAttributes.ContentState(updatedAt: Date(), status: status)
        for activity in activities {
            await activity.update(using: state)
        }
        return ["supported": true, "updated": true, "activityCount": activities.count]
    }

    static func endAll(dismissImmediately: Bool) async {
        let state = LifeRouteActivityAttributes.ContentState(updatedAt: Date(), status: "ended")
        let policy: ActivityUIDismissalPolicy = dismissImmediately ? .immediate : .after(Date().addingTimeInterval(60))
        for activity in Activity<LifeRouteActivityAttributes>.activities {
            await activity.end(using: state, dismissalPolicy: policy)
        }
    }

    static func status() -> [String: Any] {
        [
            "supported": true,
            "enabled": ActivityAuthorizationInfo().areActivitiesEnabled,
            "activeCount": Activity<LifeRouteActivityAttributes>.activities.count
        ]
    }

    private static func parseCheckpoints(_ raw: [[String: Any]]) -> [LifeRouteActivityAttributes.Checkpoint] {
        raw.compactMap { item in
            guard let start = parseDate(item["startISO"] as? String),
                  let end = parseDate(item["endISO"] as? String) else { return nil }
            return LifeRouteActivityAttributes.Checkpoint(
                title: clean(item["title"] as? String, fallback: "Next stop", max: 72),
                address: clean(item["address"] as? String, fallback: "", max: 120),
                kind: clean(item["kind"] as? String, fallback: "stop", max: 20),
                start: start,
                end: max(end, start.addingTimeInterval(60)),
                leaveAt: parseDate(item["leaveAtISO"] as? String)
            )
        }
        .sorted { $0.start < $1.start }
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return formatter.date(from: value) ?? fallbackFormatter.date(from: value)
    }

    private static func clean(_ value: String?, fallback: String, max: Int = 96) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty ? fallback : trimmed
        return String(resolved.prefix(max))
    }
}
