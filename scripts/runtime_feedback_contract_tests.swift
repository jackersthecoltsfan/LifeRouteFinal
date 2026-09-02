import Foundation

@main
struct RuntimeFeedbackContractTests {
    private static var assertionCount = 0

    static func main() {
        testNavigationChromePolicy()
        testRuntimeChromeTraversalPolicy()
        testHapticGeneratorPolicy()
        testSemanticSurfaceRolePolicy()

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

    private static func testSemanticSurfaceRolePolicy() {
        let roles = LifeRouteSurfaceRoleContract.allCases
        expect(
            roles == [.majorGroup, .passiveRow, .control, .selectedControl, .focalControl],
            "semantic surface policy has one explicit role for each hierarchy level"
        )
        expect(!LifeRouteSurfaceRoleContract.passiveRow.usesNativeGlass, "passive rows never create adaptive glass")
        expect(LifeRouteSurfaceRoleContract.majorGroup.usesNativeGlass, "major groups use native clear glass")
        expect(LifeRouteSurfaceRoleContract.control.usesNativeGlass, "meaningful controls retain native glass")
        expect(LifeRouteSurfaceRoleContract.selectedControl.usesNativeGlass, "selected controls retain native glass")
        expect(LifeRouteSurfaceRoleContract.focalControl.usesNativeGlass, "focal controls retain native glass")
        expect(!LifeRouteSurfaceRoleContract.majorGroup.drawsIndependentShadow, "major groups avoid independent shadows")
        expect(!LifeRouteSurfaceRoleContract.passiveRow.drawsIndependentShadow, "passive rows do not cast independent shadows")
        expect(!LifeRouteSurfaceRoleContract.control.drawsIndependentShadow, "ordinary controls avoid unnecessary shadows")
        expect(!LifeRouteSurfaceRoleContract.selectedControl.drawsIndependentShadow, "selected controls use emphasis instead of a shadow")
        expect(LifeRouteSurfaceRoleContract.focalControl.drawsIndependentShadow, "focal controls may own a bounded shadow")
        expect(
            roles.filter(\.usesNativeGlass).count == 4,
            "native glass includes the clear major-group owner and controls"
        )
        expect(
            roles.filter(\.drawsIndependentShadow).count == 1,
            "only focal interaction owns a shadow"
        )
        expect(
            !roles.contains { $0 == .passiveRow && $0.drawsIndependentShadow },
            "repeating content rows remain lightweight"
        )
        expect(
            roles.contains(.majorGroup) && roles.contains(.passiveRow),
            "content hierarchy distinguishes owner from repeating row"
        )
        expect(
            roles.contains(.control) && roles.contains(.selectedControl) && roles.contains(.focalControl),
            "interaction hierarchy distinguishes control emphasis levels"
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
