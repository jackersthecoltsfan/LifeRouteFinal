import Foundation

/// Small, executable policy boundary for UIKit behavior that differs across
/// supported OS generations. Keeping these decisions pure lets validation
/// prove the iOS 26 path without constructing UIKit objects.
enum LifeRouteRuntimeFeedbackPolicy {
    static let rootNavigationIntensity = 0.90
    static let primaryActionIntensity = 0.94
    static let timerCompletionIntensity = 1.0

    static func usesCustomNavigationBarAppearance(majorVersion: Int) -> Bool {
        majorVersion < 26
    }

    static func usesViewAssociatedHaptics(majorVersion: Int, minorVersion: Int) -> Bool {
        majorVersion > 17 || (majorVersion == 17 && minorVersion >= 5)
    }

    static func usesCustomNavigationBarAppearance(_ version: OperatingSystemVersion) -> Bool {
        usesCustomNavigationBarAppearance(majorVersion: version.majorVersion)
    }

    static func usesViewAssociatedHaptics(_ version: OperatingSystemVersion) -> Bool {
        usesViewAssociatedHaptics(
            majorVersion: version.majorVersion,
            minorVersion: version.minorVersion
        )
    }
}
