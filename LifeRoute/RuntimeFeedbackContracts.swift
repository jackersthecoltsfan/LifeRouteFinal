import Foundation

/// Small, executable policy boundary for UIKit behavior that differs across
/// supported OS generations. Keeping these decisions pure lets validation
/// prove the iOS 26 path without constructing UIKit objects.
enum LifeRouteRuntimeFeedbackPolicy {
    static let rootNavigationIntensity = 1.0
    static let primaryActionIntensity = 1.0
    static let timerCompletionIntensity = 1.0

    static func usesCustomNavigationBarAppearance(majorVersion: Int) -> Bool {
        majorVersion < 26
    }

    /// Live UIKit controller-tree mutation is a legacy fallback only. On iOS
    /// 26 and later SwiftUI owns navigation and tab-bar layout throughout
    /// transitions, foreground restoration, and theme changes.
    static func allowsRuntimeUIKitChromeRefresh(majorVersion: Int) -> Bool {
        majorVersion < 26
    }

    static func usesViewAssociatedHaptics(majorVersion: Int, minorVersion: Int) -> Bool {
        majorVersion > 17 || (majorVersion == 17 && minorVersion >= 5)
    }

    static func usesCustomNavigationBarAppearance(_ version: OperatingSystemVersion) -> Bool {
        usesCustomNavigationBarAppearance(majorVersion: version.majorVersion)
    }

    static func allowsRuntimeUIKitChromeRefresh(_ version: OperatingSystemVersion) -> Bool {
        allowsRuntimeUIKitChromeRefresh(majorVersion: version.majorVersion)
    }

    static func usesViewAssociatedHaptics(_ version: OperatingSystemVersion) -> Bool {
        usesViewAssociatedHaptics(
            majorVersion: version.majorVersion,
            minorVersion: version.minorVersion
        )
    }
}

/// Pure contract for the semantic surface vocabulary used by the SwiftUI
/// material implementation. Keeping this boundary Foundation-only makes the
/// role hierarchy executable in the fast contract runner.
enum LifeRouteSurfaceRoleContract: CaseIterable, Hashable, Sendable {
    case majorGroup
    case passiveRow
    case control
    case selectedControl
    case focalControl

    var usesNativeGlass: Bool {
        switch self {
        case .majorGroup, .control, .selectedControl, .focalControl: return true
        case .passiveRow: return false
        }
    }

    var drawsIndependentShadow: Bool {
        self == .focalControl
    }
}
