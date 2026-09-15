import XCTest

/// Production-route qualification. The runner owns synthetic fixture setup and
/// restoration; these tests never open a physical device or generate images.
@MainActor
final class R2OwnerFollowupUI: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }
    private func launch(_ section: String, theme: String? = "royal") -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(bundleIdentifier: "Com.Brandongood.LifeRoute")
        app.launchArguments = ["-LifeRouteSectionOverride", section,
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
                               "-LifeRouteVisualTimerDiagnostics", "-LifeRouteRootOwnershipTrace", "-LifeRouteLivingDiagnostics"]
        if let theme { app.launchArguments += ["-LifeRouteThemeOverride", theme] }
        app.launch()
        XCTAssertTrue(app.buttons["Tools"].waitForExistence(timeout: 15))
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-hierarchy"
        tree.lifetime = .keepAlways
        add(tree)
    }

    private func button(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            guard let scroll = app.scrollViews.allElementsBoundByIndex.last else { break }
            scroll.swipeUp(velocity: .slow)
        }
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "failed-reveal-hierarchy"
        tree.lifetime = .keepAlways
        add(tree)
        XCTAssertTrue(element.exists && element.isHittable, "Target should be reachable")
    }

    private func back(_ title: String, in app: XCUIApplication) {
        let navigation = title == "Visual Timer" ? app.navigationBars.firstMatch : app.navigationBars[title]
        XCTAssertTrue(navigation.waitForExistence(timeout: 5))
        navigation.buttons.element(boundBy: 0).tap()
    }

    func testTimerEntrySequence() {
        exerciseTimerEntrySequence(launch("tools"))
    }

    func testTimerCancelledReturn() {
        let app = launch("tools")
        defer { app.terminate() }
        app.buttons["tools.visualTimer"].tap()
        let expand = app.buttons["visualTimer.expand"]
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        // A short edge gesture exercises UIKit's cancelled interactive return.
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let partial = app.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: partial, withVelocity: .slow, thenHoldForDuration: 0.5)
        XCTAssertTrue(expand.waitForExistence(timeout: 5), "Cancelled return retains the Timer destination")
        capture(app, "timer-cancelled-return")
        expand.tap()
        let close = app.buttons["visualTimer.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        back("Visual Timer", in: app)
        XCTAssertTrue(app.buttons["tools.visualTimer"].waitForExistence(timeout: 5))
        app.buttons["Today"].tap()
        app.buttons["Tools"].tap()
        XCTAssertTrue(app.buttons["tools.visualTimer"].waitForExistence(timeout: 5))
        capture(app, "timer-root-return")
    }

    func testTimerEntryDiagnostics() {
        let app = XCUIApplication(bundleIdentifier: "Com.Brandongood.LifeRoute")
        app.activate()
        exerciseTimerEntrySequence(app)
    }

    private func exerciseTimerEntrySequence(_ app: XCUIApplication) {
        defer { app.terminate() }
        for entry in 0..<3 {
            let hero = app.buttons["tools.visualTimer"]
            XCTAssertTrue(hero.waitForExistence(timeout: 8))
            capture(app, "timer-entry-\(entry)-before")
            let start = ProcessInfo.processInfo.systemUptime
            hero.tap()
            XCTAssertTrue(app.buttons["visualTimer.expand"].waitForExistence(timeout: 8))
            print("TIMER_ENTRY_XCTEST_SECONDS entry=\(entry) elapsed=\(ProcessInfo.processInfo.systemUptime - start)")
            capture(app, "timer-entry-\(entry)-mounted")
            if entry == 1 {
                let startButton = button("Start ", in: app)
                reveal(startButton, in: app)
                startButton.tap()
                XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5))
            }
            if entry == 2 {
                XCTAssertTrue(app.buttons["Pause"].exists, "Active timer survives back and re-entry")
                let reset = app.buttons["Reset timer"]
                reveal(reset, in: app)
                reset.tap()
            }
            back("Visual Timer", in: app)
        }
    }

    func testThemeSelectionSequence() {
        exerciseThemeSelectionSequence(launch("setup"))
    }

    func testThemeSelectionDiagnostics() {
        let app = XCUIApplication(bundleIdentifier: "Com.Brandongood.LifeRoute")
        app.activate()
        exerciseThemeSelectionSequence(app)
    }

    private func exerciseThemeSelectionSequence(_ app: XCUIApplication) {
        defer { app.terminate() }
        let entry = button("Theme Center", in: app)
        reveal(entry, in: app)
        capture(app, "theme-entry-before")
        entry.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.5)).tap()
        capture(app, "theme-entry-after-tap")
        XCTAssertTrue(app.navigationBars["Themes"].waitForExistence(timeout: 8))
        let living = app.buttons["Living Themes"]
        reveal(living, in: app)
        living.tap()
        for name in ["Ocean Day", "Mountains Night", "Arctic Night", "Ocean Day"] {
            let tile = button(name, in: app)
            // Return toward the top before each bounded catalogue lookup.
            if !tile.exists || !tile.isHittable {
                app.scrollViews.allElementsBoundByIndex.last?.swipeDown()
            }
            reveal(tile, in: app)
            let start = ProcessInfo.processInfo.systemUptime
            tile.tap()
            XCTAssertEqual(tile.value as? String, "Selected")
            print("THEME_SELECTION_XCTEST_SECONDS theme=\(name) elapsed=\(ProcessInfo.processInfo.systemUptime - start)")
            capture(app, "theme-\(name)")
            print("THEME_RENDERER_STATE \(app.staticTexts["livingAudit.state"].value ?? "unavailable")")
        }
        back("Themes", in: app)
        entry.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.5)).tap()
        XCTAssertEqual(button("Ocean Day", in: app).value as? String, "Selected")
        capture(app, "theme-final-reentry")
    }

    func testVisualSupportsHierarchy() {
        exerciseVisualSupportsHierarchy(launch("tools"))
    }

    func testVisualSupportsDiagnostics() {
        let app = XCUIApplication(bundleIdentifier: "Com.Brandongood.LifeRoute")
        app.activate()
        exerciseVisualSupportsHierarchy(app)
    }

    func testVisualImageDestinations() {
        let app = launch("tools")
        defer { app.terminate() }
        let supports = app.buttons["tools.visualSupports"]
        reveal(supports, in: app)
        supports.tap()
        XCTAssertTrue(app.navigationBars["Visual Supports"].waitForExistence(timeout: 5))
        for (id, title, present, absent) in [
            ("visualSupports.generator", "Image Generator", "Create visual", "Saved images"),
            ("visualSupports.images", "Image Library", "Saved images", "Create visual")
        ] {
            app.buttons[id].tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts[present].exists)
            XCTAssertFalse(app.staticTexts[absent].exists)
            capture(app, title)
            back(title, in: app)
        }
    }

    func testFirstThenFreshEntry() {
        let app = launch("tools")
        defer { app.terminate() }
        let supports = app.buttons["tools.visualSupports"]
        reveal(supports, in: app)
        supports.tap()
        app.buttons["visualSupports.boards"].tap()
        XCTAssertTrue(app.navigationBars["Boards"].waitForExistence(timeout: 5))
        let firstThen = button("First / Then", in: app)
        reveal(firstThen, in: app)
        capture(app, "first-then-fresh-before")
        firstThen.tap()
        XCTAssertTrue(app.navigationBars["First / Then"].waitForExistence(timeout: 5))
        capture(app, "first-then-fresh-builder")
        app.buttons["View Library"].tap()
        XCTAssertTrue(app.navigationBars["Boards"].waitForExistence(timeout: 5))
        back("Boards", in: app)
        back("First / Then", in: app)
        XCTAssertTrue(app.navigationBars["Boards"].waitForExistence(timeout: 5))
    }

    func testSavedChoiceBoardRotation() {
        let app = launch("tools")
        defer { XCUIDevice.shared.orientation = .portrait; app.terminate() }
        let supports = app.buttons["tools.visualSupports"]
        reveal(supports, in: app)
        supports.tap()
        app.buttons["visualSupports.boards"].tap()
        let saved = button("Synthetic Choice Board", in: app)
        reveal(saved, in: app)
        saved.tap()
        let close = app.buttons["Close board preview"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        capture(app, "saved-board-portrait")
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(close.isHittable)
        XCTAssertGreaterThan(app.frame.width, app.frame.height)
        capture(app, "saved-board-landscape")
        XCUIDevice.shared.orientation = .portrait
        close.tap()
        XCTAssertTrue(app.navigationBars["Boards"].waitForExistence(timeout: 5))
        capture(app, "saved-board-return")
    }

    func testTimerOrientationReturn() {
        let app = launch("tools")
        defer { XCUIDevice.shared.orientation = .portrait; app.terminate() }
        app.buttons["tools.visualTimer"].tap()
        let expand = app.buttons["visualTimer.expand"]
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        expand.tap()
        let close = app.buttons["visualTimer.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertGreaterThan(app.frame.width, app.frame.height)
        let closeReady = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: close)
        let landscapeCloseReady = XCTWaiter.wait(for: [closeReady], timeout: 5) == .completed
        capture(app, "timer-landscape")
        XCUIDevice.shared.orientation = .portrait
        close.tap()
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        back("Visual Timer", in: app)
        XCTAssertTrue(app.buttons["tools.visualTimer"].waitForExistence(timeout: 5))
        capture(app, "timer-portrait-return")
        XCTAssertTrue(landscapeCloseReady, "Landscape close becomes usable after layout settles")
    }

    private func exerciseVisualSupportsHierarchy(_ app: XCUIApplication) {
        defer { app.terminate() }
        XCTAssertFalse(button("First / Then", in: app).exists, "Redundant Tools entry is removed")
        let supports = app.buttons["tools.visualSupports"]
        reveal(supports, in: app)
        supports.tap()
        XCTAssertTrue(app.navigationBars["Visual Supports"].waitForExistence(timeout: 8))
        for id in ["visualSupports.boards", "visualSupports.generator", "visualSupports.images"] {
            XCTAssertTrue(app.buttons[id].exists)
        }
        capture(app, "visual-supports-primary-destinations")
        app.buttons["visualSupports.boards"].tap()
        XCTAssertTrue(app.navigationBars["Boards"].waitForExistence(timeout: 5))
        XCTAssertFalse(button("Visual Schedule", in: app).exists)
        XCTAssertFalse(button("Token Boards", in: app).exists)
        for title in ["Choice Boards", "First / Then"] {
            for _ in 0..<2 {
                let destination = button(title, in: app)
                reveal(destination, in: app)
                destination.tap()
                XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
                capture(app, "board-\(title)-builder")
                let library = app.buttons["View Library"]
                XCTAssertTrue(library.exists)
                library.tap()
                capture(app, "board-\(title)-contextual-library")
                if title == "First / Then" {
                    back("Boards", in: app)
                    back(title, in: app)
                } else {
                    let outgoing = app.navigationBars["Choice Boards"]
                    XCTAssertTrue(outgoing.waitForNonExistence(timeout: 5), "Previous native pop completes before the next route tap")
                    XCTAssertTrue(app.navigationBars["Boards"].waitForExistence(timeout: 5))
                }
            }
        }
        back("Boards", in: app)
        app.buttons["visualSupports.generator"].tap()
        XCTAssertTrue(app.navigationBars["Image Generator"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Create visual"].exists)
        XCTAssertFalse(app.staticTexts["Saved images"].exists)
        capture(app, "image-generator")
        back("Image Generator", in: app)
        app.buttons["visualSupports.images"].tap()
        XCTAssertTrue(app.navigationBars["Image Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Saved images"].exists)
        XCTAssertFalse(app.staticTexts["Create visual"].exists)
        capture(app, "image-library")
    }

    private func swipeUp(_ scroll: XCUIElement) {
        scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82))
            .press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.20)))
    }

    func testTodayEmpty() { exerciseTodayFixture("empty") }
    func testTodayShort() { exerciseTodayFixture("short") }
    func testTodayLong() { exerciseTodayFixture("long") }
    func testTodayLongDiagnostics() {
        let app = XCUIApplication(bundleIdentifier: "Com.Brandongood.LifeRoute")
        app.activate()
        exerciseTodayFixture("long", app: app)
    }

    func testTodayTwoSwipesDiagnostics() {
        let app = XCUIApplication(bundleIdentifier: "Com.Brandongood.LifeRoute")
        app.activate()
        let itinerary = app.scrollViews["today.itinerary"]
        let first = app.staticTexts["Synthetic Appointment 01"]
        XCTAssertTrue(first.exists)
        itinerary.swipeUp(velocity: .slow)
        var previousY: CGFloat?
        let stable = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let y = first.frame.minY
            defer { previousY = y }
            return previousY == y
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [stable], timeout: 5), .completed)
        let firstY = first.frame.minY
        capture(app, "two-swipe-settled-first")
        itinerary.swipeUp(velocity: .slow)
        capture(app, "two-swipe-second")
        XCTAssertLessThan(first.frame.minY, firstY - 20)
        app.terminate()
    }

    private func exerciseTodayFixture(_ kind: String, app existingApp: XCUIApplication? = nil) {
        let app = existingApp ?? launch("today")
        defer { app.terminate() }
        let page = app.scrollViews["today.page"]
        let itinerary = app.scrollViews["today.itinerary"]
        let generate = app.buttons["today.generate"]
        XCTAssertTrue(page.waitForExistence(timeout: 8))
        XCTAssertTrue(itinerary.exists)
        capture(app, "today-\(kind)-initial")
        XCTAssertEqual(app.buttons.matching(identifier: "today.generate").count, 1)
        if generate.isEnabled { XCTAssertTrue(generate.isHittable) }
        XCTAssertLessThan(generate.frame.maxY, app.buttons["Tools"].frame.minY)
        print("TODAY_GEOMETRY kind=\(kind) itinerary=\(itinerary.frame) generate=\(generate.frame) page=\(page.frame)")
        if kind == "empty" {
            XCTAssertTrue(app.staticTexts["No appointments or saved stops yet"].exists)
            XCTAssertFalse(generate.isEnabled)
            app.buttons["Open Calendar"].tap()
            XCTAssertTrue(app.scrollViews["calendar.scroll"].waitForExistence(timeout: 5))
            return
        }
        let first = app.staticTexts["Synthetic Appointment 01"]
        XCTAssertTrue(first.exists, "Runner must install the requested persisted fixture")
        if kind == "short" {
            XCTAssertLessThan(itinerary.frame.height, 280, "Short content uses its natural height")
        } else {
            let rowY = first.frame.minY
            let actionY = generate.frame.minY
            itinerary.swipeUp(velocity: .slow)
            capture(app, "today-long-inner-scroll")
            XCTAssertLessThan(first.frame.minY, rowY - 20, "Itinerary rows move")
            XCTAssertEqual(generate.frame.minY, actionY, accuracy: 4, "Outer layout stays steady during inner scrolling")
            for _ in 0..<14 {
                if generate.frame.minY < actionY - 20 { break }
                itinerary.swipeUp(velocity: .slow)
            }
            capture(app, "today-long-boundary-handoff")
            XCTAssertLessThan(generate.frame.minY, actionY - 20, "A next swipe at the inner boundary moves the outer page")
        }
        let settings = app.descendants(matching: .any)["today.routeSettings"].firstMatch
        for _ in 0..<6 {
            if settings.exists && settings.isHittable { break }
            swipeUp(page)
        }
        capture(app, "today-\(kind)-lower-content")
        XCTAssertTrue(settings.exists && settings.isHittable, "Lower route controls remain reachable")
        app.buttons["Calendar"].tap()
        XCTAssertTrue(app.scrollViews["calendar.scroll"].waitForExistence(timeout: 5), "Dock taps still act after scroll gestures")
    }

    func testCalendarInteractions() {
        let app = launch("schedule")
        defer { app.terminate() }
        let scroll = app.scrollViews["calendar.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 8))
        let range = app.buttons.matching(identifier: "calendar.range")
        XCTAssertTrue(range.matching(NSPredicate(format: "label == %@", "Today")).firstMatch.exists)
        XCTAssertTrue(range.matching(NSPredicate(format: "label == %@", "Month")).firstMatch.exists)
        XCTAssertFalse(range.matching(NSPredicate(format: "label == %@", "Week")).firstMatch.exists)
        let choose = app.buttons["Choose date"]
        let original = choose.value as? String
        XCTAssertGreaterThan(app.buttons["Add appointment"].frame.midX, app.buttons["Sources"].frame.midX)
        capture(app, "calendar-today-trailing-add")
        app.buttons["Previous period"].tap()
        XCTAssertTrue(range.matching(NSPredicate(format: "label == %@", "Day")).firstMatch.exists)
        XCTAssertNotEqual(choose.value as? String, original)
        let previousDay = choose.value as? String
        range.matching(NSPredicate(format: "label == %@", "Month")).firstMatch.tap()
        XCTAssertTrue(app.otherElements["calendar.monthGrid"].exists)
        let originalMonth = choose.value as? String
        app.buttons["Next period"].tap()
        XCTAssertNotEqual(choose.value as? String, originalMonth)
        app.buttons["Previous period"].tap()
        range.matching(NSPredicate(format: "label == %@", "Day")).firstMatch.tap()
        XCTAssertEqual(choose.value as? String, previousDay, "Mode/month traversal preserves selected day")
        app.buttons["Next period"].tap()
        XCTAssertEqual(choose.value as? String, original)
        app.buttons["Previous period"].tap()
        choose.tap()
        XCTAssertTrue(app.navigationBars["Choose Date"].waitForExistence(timeout: 5))
        app.buttons["calendar.chooser.today"].tap()
        app.navigationBars["Choose Date"].buttons["Done"].tap()
        XCTAssertTrue(range.matching(NSPredicate(format: "label == %@", "Today")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(choose.value as? String, original)
        app.buttons["Sources"].tap()
        XCTAssertTrue(app.navigationBars["Calendar Sources"].waitForExistence(timeout: 5))
        capture(app, "calendar-sources")
        app.navigationBars["Calendar Sources"].buttons["Done"].tap()
        app.buttons["Add appointment"].tap()
        XCTAssertTrue(app.navigationBars["Add Appointment"].waitForExistence(timeout: 5))
        let title = app.textFields["Appointment title"]
        title.tap()
        title.typeText("UI Qualification Appointment\n")
        capture(app, "calendar-add-editor")
        let save = app.buttons["Save appointment"]
        reveal(save, in: app)
        save.tap()
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        let event = button("UI Qualification Appointment", in: app)
        for _ in 0..<6 { if event.exists && event.isHittable { break }; swipeUp(scroll) }
        XCTAssertTrue(event.exists, "Manual event saved through production editor")
        for _ in 0..<6 { if choose.isHittable { break }; scroll.swipeDown() }
        app.buttons["Previous period"].tap()
        let handoffDay = choose.value as? String
        let show = app.buttons["Travel plan"]
        for _ in 0..<6 { if show.isHittable { break }; swipeUp(scroll) }
        show.tap()
        XCTAssertTrue(app.scrollViews["today.page"].waitForExistence(timeout: 5))
        app.buttons["Calendar"].tap()
        for _ in 0..<6 { if choose.isHittable { break }; scroll.swipeDown() }
        XCTAssertEqual(choose.value as? String, handoffDay, "Today handoff retains selected date")
        capture(app, "calendar-handoff-date-preserved")
    }

    func testDockRootTaps() {
        let app = launch("today")
        defer { app.terminate() }
        var previousX: CGFloat = -1
        for name in ["Today", "Calendar", "Tools", "Resources", "Setup"] {
            let control = app.buttons[name]
            XCTAssertTrue(control.isHittable)
            XCTAssertGreaterThan(control.frame.midX, previousX, "Root order is preserved")
            XCTAssertGreaterThanOrEqual(control.frame.width, 44)
            XCTAssertGreaterThanOrEqual(control.frame.height, 44)
            previousX = control.frame.midX
            control.tap()
            XCTAssertEqual(control.value as? String, "Selected")
            capture(app, "dock-\(name)")
        }
        app.buttons["Today"].tap()
        XCTAssertTrue(app.scrollViews["today.page"].waitForExistence(timeout: 5))
    }
}
