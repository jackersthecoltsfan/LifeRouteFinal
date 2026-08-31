import Foundation

/// The lightweight in-app run identity for Live Day. The generated itinerary
/// remains authoritative; this type deliberately does not copy route nodes,
/// legs, departure math, or a second itinerary.
struct LifeRouteLiveDayRun: Equatable, Sendable {
    let itineraryID: String
    let itineraryFingerprint: String
    let startedAt: Date

    func matches(_ itinerary: LifeRouteGeneratedItinerary) -> Bool {
        itineraryID == itinerary.id
            && itineraryFingerprint == itinerary.fingerprint
    }
}

enum LifeRouteLiveDayStartDecision: Equatable, Sendable {
    case start(LifeRouteLiveDayRun)
    case reject(String)
}

enum LifeRouteLiveDayRunPolicy {
    static func decision(
        for itinerary: LifeRouteGeneratedItinerary,
        at now: Date
    ) -> LifeRouteLiveDayStartDecision {
        guard !itinerary.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !itinerary.fingerprint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !itinerary.nodes.isEmpty else {
            return .reject("Generate a valid day route before starting Live Day.")
        }

        return .start(
            LifeRouteLiveDayRun(
                itineraryID: itinerary.id,
                itineraryFingerprint: itinerary.fingerprint,
                startedAt: now
            )
        )
    }
}

/// ActivityKit is an optional system projection of an in-app Live Day. These
/// states keep a projection failure from being mistaken for a failed run.
enum LifeRouteLiveActivityDeliveryStatus: String, Equatable, Sendable {
    case idle
    case requesting
    case active
    case unavailable
    case disabled
    case noUpcomingDeparture
    case failed

    var isActive: Bool { self == .active }

    var userFacingDetail: String {
        switch self {
        case .idle:
            return "Lock Screen Live Activity has not been requested."
        case .requesting:
            return "Requesting the Lock Screen Live Activity…"
        case .active:
            return "Lock Screen Live Activity is active."
        case .unavailable:
            return "Lock Screen Live Activities are unavailable on this iPhone."
        case .disabled:
            return "Lock Screen Live Activities are disabled for LifeRoute in Settings."
        case .noUpcomingDeparture:
            return "Lock Screen projection needs an upcoming timed departure."
        case .failed:
            return "Lock Screen Live Activity could not start."
        }
    }
}
