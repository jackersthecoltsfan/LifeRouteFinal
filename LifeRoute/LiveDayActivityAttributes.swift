import Foundation
import ActivityKit

struct LifeRouteLiveDayAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phaseLabel: String
        var primaryTitle: String
        var secondaryText: String
        var countdownTarget: Date
        var eventStart: Date
        var eventEnd: Date
        var routeSummary: String
        var returnHomePlanned: Bool
    }

    var launchedAt: Date
    var dayLabel: String
}
