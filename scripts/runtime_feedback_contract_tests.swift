import Foundation

@main
struct RuntimeFeedbackContractTests {
    private static var assertionCount = 0

    static func main() {
        testNavigationChromePolicy()
        testHapticGeneratorPolicy()

        print("Runtime feedback executable contract fixtures passed (\(assertionCount) assertions).")
    }

    private static func testNavigationChromePolicy() {
        expect(
            LifeRouteRuntimeFeedbackPolicy.usesCustomNavigationBarAppearance(majorVersion: 16),
            "iOS 16 retains the established navigation appearance fallback"
        )
        expect(
            LifeRouteRuntimeFeedbackPolicy.usesCustomNavigationBarAppearance(majorVersion: 25),
            "iOS 25 retains the established navigation appearance fallback"
        )
        expect(
            !LifeRouteRuntimeFeedbackPolicy.usesCustomNavigationBarAppearance(majorVersion: 26),
            "iOS 26 leaves navigation-bar material ownership to UIKit and SwiftUI"
        )
        expect(
            !LifeRouteRuntimeFeedbackPolicy.usesCustomNavigationBarAppearance(majorVersion: 27),
            "later systems do not restore live custom navigation-bar mutation"
        )
    }

    private static func testHapticGeneratorPolicy() {
        expect(
            !LifeRouteRuntimeFeedbackPolicy.usesViewAssociatedHaptics(majorVersion: 16, minorVersion: 0),
            "iOS 16 retains the compatible feedback-generator initializer"
        )
        expect(
            !LifeRouteRuntimeFeedbackPolicy.usesViewAssociatedHaptics(majorVersion: 17, minorVersion: 4),
            "iOS 17.4 retains the compatible feedback-generator initializer"
        )
        expect(
            LifeRouteRuntimeFeedbackPolicy.usesViewAssociatedHaptics(majorVersion: 17, minorVersion: 5),
            "iOS 17.5 begins view-associated feedback-generator delivery"
        )
        expect(
            LifeRouteRuntimeFeedbackPolicy.usesViewAssociatedHaptics(majorVersion: 18, minorVersion: 0),
            "iOS 18 keeps view-associated feedback-generator delivery"
        )
        expect(
            LifeRouteRuntimeFeedbackPolicy.usesViewAssociatedHaptics(majorVersion: 26, minorVersion: 6),
            "iOS 26 physical builds use view-associated feedback-generator delivery"
        )
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertionCount += 1
        guard condition() else {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
