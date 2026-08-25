import ActivityKit
import Foundation

struct LifeRouteActivityAttributes: ActivityAttributes, Hashable {
    struct Checkpoint: Codable, Hashable {
        let title: String
        let address: String
        let kind: String
        let start: Date
        let end: Date
        let leaveAt: Date?
    }

    struct ContentState: Codable, Hashable {
        let updatedAt: Date
        let status: String
    }

    let dayLabel: String
    let checkpoints: [Checkpoint]
}
