import Foundation

@main
struct RootNavigationLabContractTests {
    private static var assertionCount = 0

    static func main() {
        testDebugSelector()
        testRootOrder()
        testCompletedSwipeThreshold()
        testDeepPathSuppression()

        precondition(
            assertionCount >= 24,
            "Root navigation lab regression floor requires at least 24 assertions; found \(assertionCount)."
        )
        print("Root navigation lab executable contract fixtures passed (\(assertionCount) assertions).")
    }

    private static func testDebugSelector() {
        expect(LifeRouteRootNavigationLabPrototype.resolve(arguments: []) == .native, "no launch argument retains the native baseline")
        expect(
            LifeRouteRootNavigationLabPrototype.resolve(arguments: ["LifeRoute", "-LifeRouteRootNavigationLab", "native"]) == .native,
            "native selects prototype A"
        )
        expect(
            LifeRouteRootNavigationLabPrototype.resolve(arguments: ["LifeRoute", "-LifeRouteRootNavigationLab", "page"]) == .page,
            "page selects prototype B"
        )
        expect(
            LifeRouteRootNavigationLabPrototype.resolve(arguments: ["LifeRoute", "-LifeRouteRootNavigationLab"]) == .native,
            "a missing launch value falls back to the native baseline"
        )
        expect(
            LifeRouteRootNavigationLabPrototype.resolve(arguments: ["LifeRoute", "-LifeRouteRootNavigationLab", "unknown"]) == .native,
            "an unknown launch value falls back to the native baseline"
        )
        expect(
            LifeRouteRootNavigationLabPrototype.resolve(arguments: ["LifeRoute", "-Other", "page"]) == .native,
            "unrelated arguments cannot activate an experiment"
        )
        expect(
            LifeRouteRootNavigationLabPrototype.resolve(arguments: ["LifeRoute", "-LifeRouteRootNavigationLab", "page", "-LifeRouteRootNavigationLab", "native"]) == .page,
            "the first explicit selector value is deterministic"
        )
    }

    private static func testRootOrder() {
        let expected: [AppSection] = [.today, .schedule, .tools, .resources, .setup]
        expect(AppSection.allCases == expected, "the five roots retain their canonical order")
        for (section, next) in zip(expected, expected.dropFirst()) {
            expect(section.neighboringSection(for: .forward) == next, "forward order remains canonical")
        }
        expect(AppSection.today.neighboringSection(for: .backward) == nil, "the first root never wraps backward")
        expect(AppSection.setup.neighboringSection(for: .forward) == nil, "the last root never wraps forward")
    }

    private static func testCompletedSwipeThreshold() {
        expect(
            destination(horizontal: -55, vertical: 0, predictedHorizontal: -180, velocityHorizontal: -900) == nil,
            "sub-threshold drags cannot select a neighbor"
        )
        expect(
            destination(horizontal: -56, vertical: 20, predictedHorizontal: -56, velocityHorizontal: -610) == .schedule,
            "the minimum completed horizontal drag may use matching velocity"
        )
        expect(
            destination(horizontal: -88, vertical: 4, predictedHorizontal: -88, velocityHorizontal: 0) == .schedule,
            "the committed translation threshold is inclusive"
        )
        expect(
            destination(horizontal: -60, vertical: 4, predictedHorizontal: -128, velocityHorizontal: 0) == .schedule,
            "predicted completion may commit an otherwise short horizontal drag"
        )
        expect(
            destination(horizontal: -88, vertical: 60, predictedHorizontal: -130, velocityHorizontal: -900) == nil,
            "strong horizontal dominance protects vertical scrolling"
        )
        expect(
            destination(horizontal: 88, vertical: 4, predictedHorizontal: 88, velocityHorizontal: 0) == nil,
            "Today cannot wrap backward at the committed threshold"
        )
        expect(
            LifeRouteRootSwipePolicy.minimumHorizontalTranslation == 56,
            "prototype A retains its bounded completed-drag entry threshold"
        )
    }

    private static func testDeepPathSuppression() {
        expect(
            LifeRouteRootSwipePolicy.destination(
                from: .tools,
                isAtRoot: false,
                translation: CGSize(width: -120, height: 0),
                predictedEndTranslation: CGSize(width: -160, height: 0),
                velocity: CGSize(width: -900, height: 0)
            ) == nil,
            "a deep selected path cannot change root selection by swipe"
        )
        expect(
            LifeRouteRootSwipePolicy.destination(
                from: .resources,
                isAtRoot: false,
                translation: CGSize(width: 120, height: 0),
                predictedEndTranslation: CGSize(width: 160, height: 0),
                velocity: CGSize(width: 900, height: 0)
            ) == nil,
            "deep-path suppression applies in both directions"
        )
        expect(
            destination(horizontal: -120, vertical: 0, predictedHorizontal: -160, velocityHorizontal: -900) == .schedule,
            "root-level selection remains available when the path is empty"
        )
    }

    private static func destination(
        horizontal: CGFloat,
        vertical: CGFloat,
        predictedHorizontal: CGFloat,
        velocityHorizontal: CGFloat
    ) -> AppSection? {
        LifeRouteRootSwipePolicy.destination(
            from: .today,
            isAtRoot: true,
            translation: CGSize(width: horizontal, height: vertical),
            predictedEndTranslation: CGSize(width: predictedHorizontal, height: vertical),
            velocity: CGSize(width: velocityHorizontal, height: 0)
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
