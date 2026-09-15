import XCTest

/// Actual shipping routes. The runner supplies and restores synthetic local
/// data; no device, image-generation provider, or private client is exercised.
@MainActor
final class BoardProductionUI: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "Com.Brandongood.LifeRoute")
        app.launchArguments = ["-LifeRouteSectionOverride", "tools", "-LifeRouteThemeOverride", "royal"]
        app.launch()
        XCTAssertTrue(app.buttons["Tools"].waitForExistence(timeout: 15))
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<4 {
            if element.exists && element.isHittable { return }
            // The passive UIKit witness proved that iOS 27 XCTest can omit
            // contacts beginning in empty scenery. Anchor the gesture in
            // visible content, then let the actual native ScrollView handle it.
            let height = app.frame.height
            let anchors = app.staticTexts.allElementsBoundByIndex.filter {
                $0.frame.minY > height * 0.3 && $0.frame.maxY < height * 0.78 && $0.isHittable
            }
            guard let anchor = anchors.last else { break }
            let start = anchor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = start.withOffset(CGVector(dx: 0, dy: -min(300, anchor.frame.midY - 150)))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        if !element.isHittable { capture(app, "failed-reveal") }
        XCTAssertTrue(element.isHittable, "Required production control must be tappable")
    }

    private func openBoards(_ app: XCUIApplication) {
        let supports = app.buttons["tools.visualSupports"]
        reveal(supports, in: app); supports.tap()
        XCTAssertTrue(app.navigationBars["Visual Supports"].waitForExistence(timeout: 6))
        app.buttons["visualSupports.boards"].tap()
        XCTAssertTrue(app.navigationBars["Boards"].waitForExistence(timeout: 6))
    }

    private func create(_ kind: String, app: XCUIApplication) {
        let control = app.buttons["boards.create." + kind]
        reveal(control, in: app)
        capture(app, "before-create-" + kind)
        // iOS 27 XCTest can omit delivery in an empty label gap. Native
        // window hit testing and the passive witness are preserved in QA
        // evidence; exercise the actual link at its visible title region.
        control.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.3)).tap()
        XCTAssertTrue(app.textFields["Board title"].waitForExistence(timeout: 6))
    }

    private func fill(_ field: XCUIElement, _ text: String) {
        field.tap()
        if let old = field.value as? String, !old.isEmpty, old != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
        }
        field.typeText(text)
    }

    private func saveAndInspect(_ app: XCUIApplication, title: String, kind: String) {
        app.buttons["Save & Preview"].tap()
        XCTAssertTrue(app.buttons["Close board preview"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts[title].exists)
        XCTAssertTrue(app.buttons["Export"].isEnabled)
        capture(app, title + "-portrait")
        app.buttons["Close board preview"].tap()
        XCTAssertTrue(app.textFields["Board title"].waitForExistence(timeout: 5))
        // One native back returns to the owning Boards library.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Boards"].waitForExistence(timeout: 5))
        let open = app.buttons["Open " + kind + " " + title]
        reveal(open, in: app); open.tap()
        XCTAssertTrue(app.buttons["Close board preview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[title].exists)
        capture(app, title + "-reopened")
        app.buttons["Close board preview"].tap()
        let edit = app.buttons["Edit " + kind + " " + title]
        reveal(edit, in: app); edit.tap()
        XCTAssertTrue(app.textFields["Board title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Board title"].value as? String, title)
        fill(app.textFields["Board title"], title + " Edited")
        app.buttons["Save & Preview"].tap()
        XCTAssertTrue(app.buttons["Close board preview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[title + " Edited"].exists)
        capture(app, title + "-edited")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
        let tree = XCTAttachment(string: app.debugDescription); tree.name = name + "-tree"; tree.lifetime = .keepAlways; add(tree)
    }

    func testCreateFirstThen() {
        let app = launch(); defer { app.terminate() }
        openBoards(app); create("FirstThen", app: app)
        fill(app.textFields["Board title"], "QA First Then")
        fill(app.textFields["First activity"], "Read")
        fill(app.textFields["Then activity"], "Break")
        saveAndInspect(app, title: "QA First Then", kind: "First / Then")
    }

    func testCreateChoiceBoard() {
        let app = launch(); defer { app.terminate() }
        openBoards(app); create("ChoiceBoard", app: app)
        fill(app.textFields["Board title"], "QA Choices")
        for label in ["Apple", "Book", "Break"] {
            let image = app.buttons[label]; reveal(image, in: app); image.tap()
        }
        let reorder = app.buttons["Move item 3 earlier"]
        reveal(reorder, in: app); reorder.tap()
        saveAndInspect(app, title: "QA Choices", kind: "Choice Board")
    }

    func testCreateSchedule() {
        let app = launch(); defer { app.terminate() }
        openBoards(app); create("VisualSchedule", app: app)
        fill(app.textFields["Board title"], "QA Schedule")
        app.buttons["Add step"].tap()
        fill(app.textFields["Step 1 label"], "Read")
        app.buttons["Add step"].tap()
        fill(app.textFields["Step 2 label"], "Break")
        app.buttons["Move item 2 earlier"].tap()
        saveAndInspect(app, title: "QA Schedule", kind: "Visual Schedule")
    }

    func testCreateTokenBoard() {
        let app = launch(); defer { app.terminate() }
        openBoards(app); create("TokenBoard", app: app)
        fill(app.textFields["Board title"], "QA Tokens")
        fill(app.textFields["Reward label"], "Break")
        app.buttons["Choose reward image"].tap()
        XCTAssertTrue(app.navigationBars["Choose saved image"].waitForExistence(timeout: 5))
        app.buttons["Break"].tap()
        saveAndInspect(app, title: "QA Tokens", kind: "Token Board")
    }
    func testExportActions() {
        let app = launch(); defer { XCUIDevice.shared.orientation = .portrait; app.terminate() }
        openBoards(app); create("FirstThen", app: app)
        fill(app.textFields["Board title"], "QA Image Export")
        for (index, name) in [(1, "Book"), (2, "Break")] {
            let pick = app.buttons["Choose image for step \(index)"]
            reveal(pick, in: app); pick.tap()
            XCTAssertTrue(app.navigationBars["Choose saved image"].waitForExistence(timeout: 5))
            app.buttons[name].tap()
        }
        app.buttons["Save & Preview"].tap()
        XCTAssertTrue(app.buttons["Close board preview"].waitForExistence(timeout: 8))
        capture(app, "image-backed-first-then")
        for action in ["Share Image", "Share PDF / Save to Files"] {
            app.buttons["Export"].tap()
            app.buttons[action].tap()
            XCTAssertTrue(app.cells["Copy"].waitForExistence(timeout: 10), "System sharing must receive the finished artifact")
            XCTAssertTrue(app.cells["Save to Files"].exists)
            capture(app, action)
            XCTAssertTrue(app.buttons["Close"].isHittable)
            app.buttons["Close"].tap()
            XCTAssertTrue(app.buttons["Close board preview"].waitForExistence(timeout: 5))
        }
        XCUIDevice.shared.orientation = .landscapeRight
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["Close board preview"].isHittable)
        capture(app, "image-backed-first-then-landscape")
    }

    func testDockAndThemeReentry() {
        let app = launch(); defer { app.terminate() }
        let names = ["Today", "Calendar", "Tools", "Resources", "Setup"]
        func dock(_ name: String) -> XCUIElement {
            // Calendar also has a Today range button. The permanent dock is
            // the lowest matching control, regardless of retained root history.
            app.buttons.matching(NSPredicate(format: "label == %@", name))
                .allElementsBoundByIndex.max(by: { $0.frame.midY < $1.frame.midY })!
        }
        var previousX: CGFloat = -1
        for name in names {
            let control = dock(name)
            XCTAssertTrue(control.isHittable)
            XCTAssertGreaterThan(control.frame.midX, previousX)
            XCTAssertGreaterThanOrEqual(control.frame.width, 44)
            XCTAssertGreaterThanOrEqual(control.frame.height, 44)
            previousX = control.frame.midX
            control.tap()
            XCTAssertEqual(control.value as? String, "Selected")
        }
        for name in names.reversed() { dock(name).tap() }
        dock("Setup").tap()
        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Theme Center")).firstMatch
        reveal(entry, in: app)
        app.staticTexts["Theme Center"].tap()
        XCTAssertTrue(app.navigationBars["Themes"].waitForExistence(timeout: 6))
        let living = app.buttons["Living Themes"]
        reveal(living, in: app); living.tap()
        let ocean = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ocean Day")).firstMatch
        reveal(ocean, in: app); ocean.tap()
        XCTAssertEqual(ocean.value as? String, "Selected")
        ocean.tap()
        XCTAssertEqual(ocean.value as? String, "Selected")
        capture(app, "theme-same-selection")
        app.navigationBars["Themes"].buttons.element(boundBy: 0).tap()
        reveal(entry, in: app)
        app.staticTexts["Theme Center"].tap()
        XCTAssertTrue(app.navigationBars["Themes"].waitForExistence(timeout: 6))
        XCTAssertEqual(ocean.value as? String, "Selected")
        capture(app, "theme-return-selected-living")
        app.terminate()
        app.launchArguments = ["-LifeRouteSectionOverride", "setup"]
        app.launch()
        reveal(entry, in: app)
        app.staticTexts["Theme Center"].tap()
        XCTAssertTrue(app.navigationBars["Themes"].waitForExistence(timeout: 6))
        XCTAssertEqual(ocean.value as? String, "Selected")
        capture(app, "theme-relaunch-selected-living")
    }
}
