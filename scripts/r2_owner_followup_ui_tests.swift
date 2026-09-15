import XCTest

/// Production-route qualification. The runner owns synthetic fixture setup and
/// restoration; these tests never open a physical device or generate images.
@MainActor
final class R2OwnerFollowupUI: XCTestCase {
    private func launch(_ section: String, theme: String? = "royal") -> XCUIApplication {
        continueAfterFailure = false
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
    }

    private func button(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            let scroll = app.scrollViews.allElementsBoundByIndex.last!
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.76))
                .press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.20)))
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
        let app = launch("setup")
        defer { app.terminate() }
        let entry = button("Theme Center", in: app)
        reveal(entry, in: app)
        entry.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.5)).tap()
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
        let app = launch("tools")
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
}
