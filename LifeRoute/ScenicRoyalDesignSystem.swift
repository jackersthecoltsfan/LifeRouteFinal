import SwiftUI

/// Scenic Royal is the stable presentation language layered over LifeRoute's existing themes.
/// Feature screens should consume these tokens instead of creating one-off glass geometry.
enum ScenicRoyalDesignSystem {
    enum ColorToken {
        static let brandNavy = Color(red: 11 / 255, green: 26 / 255, blue: 46 / 255)
        static let brandNavyDeep = Color(red: 0.008, green: 0.026, blue: 0.065)
        static let brandGold = Color(red: 197 / 255, green: 160 / 255, blue: 40 / 255)
        static let brandGoldBright = Color(red: 212 / 255, green: 175 / 255, blue: 55 / 255)

        static let contentDayPrimary = Color(red: 0.020, green: 0.055, blue: 0.115)
        static let contentDaySecondary = Color(red: 0.095, green: 0.155, blue: 0.230)
        static let contentNightPrimary = Color.white.opacity(0.98)
        static let contentNightSecondary = Color.white.opacity(0.76)

        static let selectedControlDayFill = Color.white.opacity(0.94)
        static let selectedControlDayForeground = brandNavyDeep
        static let selectedControlDayIndicator = brandNavy
        /// Functional tint for dark selected controls. The reusable material
        /// adds the illuminated-glass grade; this remains the stable Color
        /// token for native control tint APIs.
        static let selectedControlNightFill = Color(red: 0.018, green: 0.066, blue: 0.205)
        static let selectedControlNightInnerGlow = Color(red: 0.090, green: 0.255, blue: 0.560)
        static let selectedControlNightEdge = Color(red: 0.006, green: 0.026, blue: 0.105)
        static let selectedControlNightForeground = Color.white.opacity(0.98)
        static let selectedControlNightIndicator = Color.white.opacity(0.92)
    }

    enum Spacing {
        static let hairline: CGFloat = 4
        static let compact: CGFloat = 8
        static let standard: CGFloat = 12
        static let comfortable: CGFloat = 16
        static let spacious: CGFloat = 24
    }

    enum Radius {
        static let compactControl: CGFloat = 12
        static let control: CGFloat = 15
        static let card: CGFloat = 20
        static let hero: CGFloat = 28
        static let toolbar: CGFloat = 24
    }

    enum Layout {
        static let pageHorizontal: CGFloat = 16
        static let minimumTouchTarget: CGFloat = 44
        static let standardToolbarHeight: CGFloat = 49
        static let accessibilityToolbarHeight: CGFloat = 66
        static let bottomToolbarClearance: CGFloat = 10
    }

    enum Stroke {
        static let subtle: CGFloat = 0.8
        static let selected: CGFloat = 1.0
    }

    enum Opacity {
        /// The locked L1 major-group recipe: Glass.clear plus neutral black.
        static let standardMajorGroupUnderlay: Double = 0.044
        /// Bright/day scenery needs a bounded contrast floor while retaining
        /// the accepted thin-glass treatment.
        static let brightMajorGroupUnderlay: Double = 0.20
        static let passiveRowSeparator: Double = 0.28
    }

    enum Shadow {
        static let cardRadius: CGFloat = 14
        static let cardY: CGFloat = 5
        static let toolbarRadius: CGFloat = 18
        static let toolbarY: CGFloat = 7
    }

    enum Motion {
        static let selection = Animation.spring(response: 0.30, dampingFraction: 0.84)
        static let environmentChange = Animation.easeInOut(duration: 0.24)
    }
}
