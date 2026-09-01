import SwiftUI

/// Scenic Royal is the stable presentation language layered over LifeRoute's existing themes.
/// Feature screens should consume these tokens instead of creating one-off glass geometry.
enum ScenicRoyalDesignSystem {
    enum ColorToken {
        static let brandNavy = Color(red: 0.025, green: 0.070, blue: 0.145)
        static let brandNavyDeep = Color(red: 0.008, green: 0.026, blue: 0.065)
        static let brandGold = Color(red: 0.93, green: 0.70, blue: 0.31)
        static let brandGoldBright = Color(red: 1.00, green: 0.83, blue: 0.49)
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
