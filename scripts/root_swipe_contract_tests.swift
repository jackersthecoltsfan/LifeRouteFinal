import Foundation

@main
struct RootSwipeContractTests {
    private static var assertionCount = 0

    static func main() {
        testNeighborResolution()
        testGestureDecisionPolicy()

        precondition(
            assertionCount >= 24,
            "Root swipe regression floor requires at least 24 assertions; found \(assertionCount)."
        )
        print("Root swipe executable contract fixtures passed (\(assertionCount) assertions).")
    }

    private static func testNeighborResolution() {
        expect(AppSection.today.neighboringSection(for: .forward) == .schedule, "Today advances to Calendar")
        expect(AppSection.schedule.neighboringSection(for: .forward) == .tools, "Calendar advances to Tools")
        expect(AppSection.tools.neighboringSection(for: .forward) == .resources, "Tools advances to Resources")
        expect(AppSection.resources.neighboringSection(for: .forward) == .setup, "Resources advances to Setup")
        expect(AppSection.setup.neighboringSection(for: .forward) == nil, "Setup does not wrap forward")
        expect(AppSection.setup.neighboringSection(for: .backward) == .resources, "Setup goes back to Resources")
        expect(AppSection.resources.neighboringSection(for: .backward) == .tools, "Resources goes back to Tools")
        expect(AppSection.tools.neighboringSection(for: .backward) == .schedule, "Tools goes back to Calendar")
        expect(AppSection.schedule.neighboringSection(for: .backward) == .today, "Calendar goes back to Today")
        expect(AppSection.today.neighboringSection(for: .backward) == nil, "Today does not wrap backward")
    }

    private static func testGestureDecisionPolicy() {
        expect(
            destination(from: .today, horizontal: -96, vertical: 8, predictedHorizontal: -110) == .schedule,
            "a committed left root swipe advances one tab"
        )
        expect(
            destination(from: .tools, horizontal: 96, vertical: 10, predictedHorizontal: 116) == .schedule,
            "a committed right root swipe goes back one tab"
        )
        expect(
            destination(from: .setup, horizontal: -108, vertical: 0, predictedHorizontal: -130) == nil,
            "the final tab cannot advance past Setup"
        )
        expect(
            destination(from: .today, horizontal: 108, vertical: 0, predictedHorizontal: 130) == nil,
            "the first tab cannot go back before Today"
        )
        expect(
            destination(from: .schedule, horizontal: -55, vertical: 0, predictedHorizontal: -180) == nil,
            "sub-threshold drags never change tabs"
        )
        expect(
            destination(from: .schedule, horizontal: -90, vertical: 70, predictedHorizontal: -140) == nil,
            "diagonal drags fail strong horizontal dominance"
        )
        expect(
            destination(from: .schedule, horizontal: -60, vertical: 8, predictedHorizontal: -125) == .tools,
            "a short but projected left fling commits forward"
        )
        expect(
            destination(from: .schedule, horizontal: 60, vertical: 8, predictedHorizontal: 124) == .today,
            "a short but projected right fling commits backward"
        )
        expect(
            destination(
                from: .schedule,
                horizontal: -60,
                vertical: 8,
                predictedHorizontal: -108,
                velocityHorizontal: -720
            ) == .tools,
            "horizontal velocity can commit before the predicted endpoint threshold"
        )
        expect(
            destination(from: .resources, horizontal: -64, vertical: 0, predictedHorizontal: 128) == nil,
            "a reversed prediction cannot override the completed drag direction"
        )
        expect(
            LifeRouteRootSwipePolicy.destination(
                from: .tools,
                isAtRoot: false,
                translation: CGSize(width: -120, height: 0),
                predictedEndTranslation: CGSize(width: -160, height: 0),
                velocity: CGSize(width: 0, height: 0)
            ) == nil,
            "deep navigation paths disable root swipe selection"
        )
        expect(
            destination(from: .resources, horizontal: -70, vertical: 0, predictedHorizontal: -132) == .setup,
            "predicted translation can commit the current drag direction"
        )
        expect(
            destination(from: .resources, horizontal: 70, vertical: 0, predictedHorizontal: 132) == .tools,
            "predicted velocity can commit a backward drag direction"
        )
        expect(
            destination(from: .resources, horizontal: -70, vertical: 0, predictedHorizontal: -70) == nil,
            "an unprojected drag below the commit distance remains in place"
        )
        expect(
            destination(from: .resources, horizontal: -88, vertical: 4, predictedHorizontal: -88) == .setup,
            "the committed translation boundary is inclusive"
        )
    }

    private static func destination(
        from section: AppSection,
        horizontal: CGFloat,
        vertical: CGFloat,
        predictedHorizontal: CGFloat,
        velocityHorizontal: CGFloat = 0
    ) -> AppSection? {
        LifeRouteRootSwipePolicy.destination(
            from: section,
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
