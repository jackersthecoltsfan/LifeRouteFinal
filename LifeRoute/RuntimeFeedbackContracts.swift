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

enum LifeRouteOrdinaryGlassRole: CaseIterable, Hashable, Sendable {
    case ambient
    case card
    case readability
    case toolbar
}

/// Large ordinary surfaces are intentionally not native adaptive glass. They
/// frequently contain more ordinary rows and sit inside GlassEffectContainer;
/// making every level native glass compounds blur and adaptive darkening on a
/// physical display. Emphasized controls stay outside this policy and retain
/// native Regular glass where its depth communicates interaction or selection.
enum LifeRouteOrdinaryGlassPolicy {
    static let highlightOpacity = 0.028

    static func usesNativeAdaptiveGlass(for role: LifeRouteOrdinaryGlassRole) -> Bool {
        false
    }

    static func surfaceFillOpacity(
        for role: LifeRouteOrdinaryGlassRole,
        isBrightEnvironment: Bool
    ) -> Double {
        let base: Double
        switch role {
        case .ambient: base = 0.025
        case .card: base = 0.040
        case .readability: base = 0.075
        case .toolbar: base = 0.055
        }

        guard isBrightEnvironment else { return base }
        switch role {
        case .ambient: return base + 0.015
        case .card: return base + 0.020
        case .readability: return base + 0.030
        case .toolbar: return base + 0.025
        }
    }
}
