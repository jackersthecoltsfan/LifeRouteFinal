import Foundation

@main
struct RuntimeFeedbackContractTests {
    private static var assertionCount = 0

    static func main() {
        testNavigationChromePolicy()
        testRuntimeChromeTraversalPolicy()
        testHapticGeneratorPolicy()
        testOrdinaryGlassTransparencyPolicy()

        precondition(
            assertionCount >= 25,
            "Runtime Feedback regression floor requires at least 25 assertions; found \(assertionCount)."
        )
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
        let darkSceneOpacities = roles.map {
            LifeRouteOrdinaryGlassPolicy.surfaceFillOpacity(
                for: $0,
                isBrightEnvironment: false
            )
        }
        let brightSceneOpacities = roles.map {
            LifeRouteOrdinaryGlassPolicy.surfaceFillOpacity(
                for: $0,
                isBrightEnvironment: true
            )
        }
        expect(roles == [.ambient, .card, .readability, .toolbar], "ordinary glass policy covers only the four non-emphasized roles")
        expect(
            roles.allSatisfy { !LifeRouteOrdinaryGlassPolicy.usesNativeAdaptiveGlass(for: $0) },
            "ordinary surfaces do not compound native adaptive glass inside shared containers"
        )
        expect(
            darkSceneOpacities.allSatisfy { $0 > 0 && $0 <= 0.08 },
            "ordinary dark-scene surfaces use only a very light custom readability fill"
        )
        expect(
            brightSceneOpacities.allSatisfy { $0 > 0 && $0 <= 0.11 },
            "ordinary bright-scene surfaces remain transparent while retaining readability"
        )
        expect(
            zip(darkSceneOpacities, brightSceneOpacities).allSatisfy { $0 <= $1 },
            "bright scenery receives only the bounded additional readability fill"
        )
        expect(
            LifeRouteOrdinaryGlassPolicy.surfaceFillOpacity(for: .ambient, isBrightEnvironment: false)
                < LifeRouteOrdinaryGlassPolicy.surfaceFillOpacity(for: .card, isBrightEnvironment: false),
            "ambient boundaries remain more transparent than a standard card"
        )
        expect(
            LifeRouteOrdinaryGlassPolicy.surfaceFillOpacity(for: .card, isBrightEnvironment: false)
                < LifeRouteOrdinaryGlassPolicy.surfaceFillOpacity(for: .readability, isBrightEnvironment: false),
            "readability surfaces retain the strongest ordinary custom fill"
        )
        expect(
            LifeRouteOrdinaryGlassPolicy.surfaceFillOpacity(for: .toolbar, isBrightEnvironment: false)
                < LifeRouteOrdinaryGlassPolicy.surfaceFillOpacity(for: .readability, isBrightEnvironment: false),
            "toolbar surfaces never exceed the ordinary readability fill"
        )
        expect(
            LifeRouteOrdinaryGlassPolicy.highlightOpacity > 0
                && LifeRouteOrdinaryGlassPolicy.highlightOpacity <= 0.04,
            "ordinary surfaces retain only a subtle neutral reflection highlight"
        )
        expect(
            LifeRouteOrdinaryGlassPolicy.participation(atNestingDepth: 0) == .container,
            "a root ordinary surface owns the shared container recipe"
        )
        expect(
            LifeRouteOrdinaryGlassPolicy.participation(atNestingDepth: 1) == .nestedContent,
            "a child ordinary surface participates as content instead of stacking another recipe"
        )
        expect(
            LifeRouteOrdinaryGlassPolicy.participation(atNestingDepth: 4) == .nestedContent,
            "all deeper ordinary descendants remain content participants"
        )
        expect(
            LifeRouteOrdinaryGlassPolicy.drawsIndependentFill(for: .container),
            "the root ordinary container retains one bounded readability fill"
        )
        expect(
            !LifeRouteOrdinaryGlassPolicy.drawsIndependentFill(for: .nestedContent),
            "nested ordinary content does not compound fills"
        )
        expect(
            !LifeRouteOrdinaryGlassPolicy.drawsIndependentShadow(for: .nestedContent),
            "nested ordinary content does not compound shadows"
        )
        expect(
            LifeRouteOrdinaryGlassPolicy.nestedOutlineOpacity > 0
                && LifeRouteOrdinaryGlassPolicy.nestedOutlineOpacity <= 0.08,
            "nested content retains only a subtle boundary cue"
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
