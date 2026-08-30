import Foundation

enum LifeRouteNavigationApp: String, CaseIterable, Identifiable {
    case appleMaps = "appleMaps"
    case googleMaps = "googleMaps"
    case waze = "waze"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleMaps: return "Apple Maps"
        case .googleMaps: return "Google Maps"
        case .waze: return "Waze"
        }
    }

    var systemImage: String {
        switch self {
        case .appleMaps: return "map.fill"
        case .googleMaps: return "location.fill"
        case .waze: return "car.fill"
        }
    }

    var detail: String {
        switch self {
        case .appleMaps: return "Native turn-by-turn directions on iPhone."
        case .googleMaps: return "Open LifeRoute destinations in Google Maps."
        case .waze: return "Open destinations in Waze for driving navigation."
        }
    }

    static var preferred: LifeRouteNavigationApp {
        let raw = UserDefaults.standard.string(forKey: "liferoute.preferredNavigationApp")
        return LifeRouteNavigationApp(rawValue: raw ?? "") ?? .appleMaps
    }
}

struct LifeRouteFullRouteLegDescriptor: Equatable, Hashable {
    let sequence: Int
    let fromTitle: String
    let fromAddress: String
    let toTitle: String
    let toAddress: String
}

enum LifeRouteFullRouteHandoffStrategy: Equatable {
    case completeGoogleMaps(URL)
    case completeAppleMaps
    case sequential
}

struct LifeRouteFullRouteHandoffPlan: Equatable {
    let provider: LifeRouteNavigationApp
    let orderedLegs: [LifeRouteFullRouteLegDescriptor]
    let strategy: LifeRouteFullRouteHandoffStrategy
    let fallbackReason: String?

    var requiresSequentialContinuation: Bool {
        strategy == .sequential
    }
}

enum LifeRouteFullRouteHandoffPlanner {
    /// Google documents up to three intermediate waypoints when a Maps URL opens in a mobile browser.
    static let maximumGoogleMobileWaypoints = 3
    static let maximumURLLength = 2_048

    static func plan(
        provider: LifeRouteNavigationApp,
        legs: [LifeRouteFullRouteLegDescriptor],
        travelMode: String
    ) -> LifeRouteFullRouteHandoffPlan? {
        guard !legs.isEmpty else { return nil }

        guard hasVerifiedSequence(legs) else {
            return sequentialPlan(
                provider: provider,
                legs: legs,
                reason: "LifeRoute could not verify a contiguous provider sequence, so it will keep the computed legs and open them one at a time."
            )
        }

        switch provider {
        case .appleMaps:
            if legs.count == 1 {
                return LifeRouteFullRouteHandoffPlan(
                    provider: provider,
                    orderedLegs: legs,
                    strategy: .completeAppleMaps,
                    fallbackReason: nil
                )
            }
            return sequentialPlan(
                provider: provider,
                legs: legs,
                reason: "Apple Maps will open one leg at a time. Return to LifeRoute after each leg to continue the complete ordered route."
            )

        case .googleMaps:
            let intermediateWaypointCount = max(0, legs.count - 1)
            guard intermediateWaypointCount <= maximumGoogleMobileWaypoints else {
                return sequentialPlan(
                    provider: provider,
                    legs: legs,
                    reason: "This route has \(intermediateWaypointCount) intermediate stops; Google Maps mobile URLs support up to \(maximumGoogleMobileWaypoints). LifeRoute will open every leg in order instead of truncating stops."
                )
            }
            guard let url = googleMapsURL(for: legs, travelMode: travelMode),
                  url.absoluteString.count <= maximumURLLength else {
                return sequentialPlan(
                    provider: provider,
                    legs: legs,
                    reason: "The complete Google Maps link exceeds the documented URL limit. LifeRoute will open every leg in order instead of shortening the route."
                )
            }
            return LifeRouteFullRouteHandoffPlan(
                provider: provider,
                orderedLegs: legs,
                strategy: .completeGoogleMaps(url),
                fallbackReason: nil
            )

        case .waze:
            return sequentialPlan(
                provider: provider,
                legs: legs,
                reason: "Waze documents one navigation destination per deep link. Return to LifeRoute after each leg to continue the complete ordered route."
            )
        }
    }

    private static func hasVerifiedSequence(_ legs: [LifeRouteFullRouteLegDescriptor]) -> Bool {
        for (index, leg) in legs.enumerated() {
            guard leg.sequence == index + 1,
                  !leg.toAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return false
            }
            if index > 0 {
                let previousDestination = normalized(legs[index - 1].toAddress)
                guard previousDestination == normalized(leg.fromAddress) else { return false }
            }
        }
        return true
    }

    private static func sequentialPlan(
        provider: LifeRouteNavigationApp,
        legs: [LifeRouteFullRouteLegDescriptor],
        reason: String
    ) -> LifeRouteFullRouteHandoffPlan {
        LifeRouteFullRouteHandoffPlan(
            provider: provider,
            orderedLegs: legs,
            strategy: .sequential,
            fallbackReason: reason
        )
    }

    private static func googleMapsURL(
        for legs: [LifeRouteFullRouteLegDescriptor],
        travelMode: String
    ) -> URL? {
        guard let first = legs.first, let last = legs.last else { return nil }
        var components = URLComponents(string: "https://www.google.com/maps/dir/")
        var queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "destination", value: last.toAddress),
            URLQueryItem(name: "travelmode", value: travelMode.lowercased()),
        ]

        if normalized(first.fromAddress) != normalized("Current Location") {
            queryItems.append(URLQueryItem(name: "origin", value: first.fromAddress))
        }

        let intermediateWaypoints = legs.dropLast().map(\.toAddress)
        if !intermediateWaypoints.isEmpty {
            queryItems.append(
                URLQueryItem(name: "waypoints", value: intermediateWaypoints.joined(separator: "|"))
            )
        }

        components?.queryItems = queryItems
        return components?.url
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
    }
}
