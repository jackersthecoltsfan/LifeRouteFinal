import Foundation

@main
struct VisualActivityContractTests {
    private static var assertionCount = 0

    @MainActor
    static func main() {
        testRenderProfiles()
        testReferenceCountedSuspension()
        testThemeCenterVisibilityBridge()

        precondition(
            assertionCount >= 27,
            "Visual activity regression floor requires at least 27 assertions; found \(assertionCount)."
        )
        print("Visual activity executable contract fixtures passed (\(assertionCount) assertions).")
    }

    private static func testRenderProfiles() {
        expect(LifeRouteAmbientRenderMode.allCases == [.full, .frozen, .sceneryOnly, .dynamicOnly, .noEffects], "the five deterministic ambient render modes remain available")
        expect(LifeRouteAmbientRenderMode.full.plan.usesLiveClock, "full mode retains the shared ambient clock")
        expect(LifeRouteAmbientRenderMode.full.plan.showsSceneryEffects, "full mode retains scenery effects")
        expect(LifeRouteAmbientRenderMode.full.plan.showsDynamicEffect, "full mode retains Dynamic effects")
        expect(!LifeRouteAmbientRenderMode.frozen.plan.usesLiveClock, "frozen mode stops the shared ambient clock")
        expect(LifeRouteAmbientRenderMode.frozen.plan.showsStaticEffects, "frozen mode preserves a deterministic static environment")
        expect(LifeRouteAmbientRenderMode.sceneryOnly.plan.usesLiveClock, "scenery-only mode retains the shared clock")
        expect(LifeRouteAmbientRenderMode.sceneryOnly.plan.showsSceneryEffects, "scenery-only mode includes scenery effects")
        expect(!LifeRouteAmbientRenderMode.sceneryOnly.plan.showsDynamicEffect, "scenery-only mode excludes Dynamic effects")
        expect(LifeRouteAmbientRenderMode.dynamicOnly.plan.usesLiveClock, "dynamic-only mode retains the shared clock")
        expect(!LifeRouteAmbientRenderMode.dynamicOnly.plan.showsSceneryEffects, "dynamic-only mode excludes scenery effects")
        expect(LifeRouteAmbientRenderMode.dynamicOnly.plan.showsDynamicEffect, "dynamic-only mode includes Dynamic effects")
        expect(!LifeRouteAmbientRenderMode.noEffects.plan.usesLiveClock, "no-effects mode stops the shared ambient clock")
        expect(!LifeRouteAmbientRenderMode.noEffects.plan.showsStaticEffects, "no-effects mode removes both effect layers")
    }

    @MainActor
    private static func testReferenceCountedSuspension() {
        let coordinator = LifeRouteVisualActivityCoordinator()
        expect(coordinator.ambientRenderingIsActive, "ambient rendering starts active")
        expect(coordinator.ambientSuspensionCount == 0, "ambient rendering starts with no suspension requests")

        let first = coordinator.acquireAmbientSuspension()
        expect(!coordinator.ambientRenderingIsActive, "the first foreground requester freezes ambient rendering")
        expect(coordinator.ambientSuspensionCount == 1, "the first foreground requester is counted")

        let second = coordinator.acquireAmbientSuspension()
        expect(coordinator.ambientSuspensionCount == 2, "independent foreground requesters are reference counted")
        coordinator.releaseAmbientSuspension(first)
        expect(!coordinator.ambientRenderingIsActive, "releasing one requester leaves ambient rendering frozen")
        expect(coordinator.ambientSuspensionCount == 1, "releasing one requester retains the other request")
        coordinator.releaseAmbientSuspension(UUID())
        expect(coordinator.ambientSuspensionCount == 1, "an unknown release cannot underflow the suspension count")
        coordinator.releaseAmbientSuspension(second)
        expect(coordinator.ambientRenderingIsActive, "releasing the last requester resumes ambient rendering")
        expect(coordinator.ambientSuspensionCount == 0, "the last release returns the count to zero")
    }

    @MainActor
    private static func testThemeCenterVisibilityBridge() {
        let coordinator = LifeRouteVisualActivityCoordinator()
        coordinator.setThemeCenterVisible(true)
        expect(!coordinator.ambientRenderingIsActive, "Theme Center visibility suspends ambient rendering")
        expect(coordinator.ambientSuspensionCount == 1, "Theme Center acquires one suspension token")
        coordinator.setThemeCenterVisible(true)
        expect(coordinator.ambientSuspensionCount == 1, "repeated Theme Center appearance is idempotent")
        coordinator.setThemeCenterVisible(false)
        expect(coordinator.ambientRenderingIsActive, "Theme Center dismissal resumes ambient rendering")
        expect(coordinator.ambientSuspensionCount == 0, "Theme Center dismissal releases its token")
        coordinator.setThemeCenterVisible(false)
        expect(coordinator.ambientSuspensionCount == 0, "repeated Theme Center disappearance cannot underflow")
        coordinator.setThemeCenterVisible(true)
        coordinator.setThemeCenterVisible(false)
        expect(coordinator.ambientRenderingIsActive, "repeated Theme Center open-close cycles do not leak a token")
        expect(coordinator.ambientSuspensionCount == 0, "repeated Theme Center cycles return the count to zero")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertionCount += 1
        guard condition() else {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
