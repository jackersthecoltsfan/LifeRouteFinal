import Foundation

@main
struct RuntimeFeedbackContractTests {
    private static var assertionCount = 0

    static func main() {
        testNavigationChromePolicy()
        testRuntimeChromeTraversalPolicy()
        testHapticGeneratorPolicy()
        testOrdinaryGlassTransparencyPolicy()

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

    private static func testRuntimeChromeTraversalPolicy() {
        expect(
            LifeRouteRuntimeFeedbackPolicy.allowsRuntimeUIKitChromeRefresh(majorVersion: 16),
            "iOS 16 retains the legacy UIKit chrome fallback"
        )
        expect(
            LifeRouteRuntimeFeedbackPolicy.allowsRuntimeUIKitChromeRefresh(majorVersion: 25),
            "iOS 25 retains the legacy UIKit chrome fallback"
        )
        expect(
            !LifeRouteRuntimeFeedbackPolicy.allowsRuntimeUIKitChromeRefresh(majorVersion: 26),
            "iOS 26 forbids runtime UIKit controller-tree chrome mutation"
        )
        expect(
            !LifeRouteRuntimeFeedbackPolicy.allowsRuntimeUIKitChromeRefresh(majorVersion: 27),
            "later systems cannot restore runtime UIKit chrome mutation"
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
        expect(
            LifeRouteRuntimeFeedbackPolicy.rootNavigationIntensity == 1,
            "root navigation uses the strongest retained medium impact"
        )
        expect(
            LifeRouteRuntimeFeedbackPolicy.primaryActionIntensity == 1,
            "primary actions use the strongest retained medium impact"
        )
        expect(
            LifeRouteRuntimeFeedbackPolicy.timerCompletionIntensity == 1,
            "timer completion uses the strongest retained completion impact"
        )
    }

    private static func testOrdinaryGlassTransparencyPolicy() {
        let roles = LifeRouteOrdinaryGlassRole.allCases
        let opacities = roles.map(LifeRouteOrdinaryGlassPolicy.layerOpacity)
        expect(roles == [.ambient, .card, .readability, .toolbar], "ordinary glass policy covers only the four non-emphasized roles")
        expect(opacities.allSatisfy { $0 > 0 && $0 <= 0.50 }, "ordinary native glass is substantially attenuated while retaining depth")
        expect(
            LifeRouteOrdinaryGlassPolicy.layerOpacity(for: .ambient)
                < LifeRouteOrdinaryGlassPolicy.layerOpacity(for: .card),
            "ambient glass remains more transparent than a standard card"
        )
        expect(
            LifeRouteOrdinaryGlassPolicy.layerOpacity(for: .card)
                < LifeRouteOrdinaryGlassPolicy.layerOpacity(for: .readability),
            "readability glass retains the strongest ordinary depth"
        )
        expect(
            LifeRouteOrdinaryGlassPolicy.layerOpacity(for: .toolbar)
                <= LifeRouteOrdinaryGlassPolicy.layerOpacity(for: .readability),
            "toolbar glass never exceeds the ordinary readability floor"
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
