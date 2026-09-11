import XCTest

final class NativeUI: XCTestCase {
    private let bundle = "Com.Brandongood.LifeRoute"
    private let roots = ["Today", "Calendar", "Tools", "Resources", "Setup"]
    private let scenes = ["rainforest.day", "rainforest.night", "ocean.day", "ocean.night", "arctic.day", "arctic.night",
                          "mountains.day", "mountains.night", "canyon.day", "canyon.night", "desert.day", "desert.night"].map { "scenery." + $0 }

    @MainActor private func launchQA() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchArguments = ["-LifeRouteLivingThemeQAViewer", "-LifeRouteLivingThemeQAScene", scenes[0], "-LifeRouteLivingDiagnostics"]
        app.launch()
        XCTAssertTrue(app.buttons["livingQA.toggleControls"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor private func attachTree(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor private func assertIsolated(_ app: XCUIApplication, controlsVisible: Bool) {
        attachTree(app, controlsVisible ? "QA controls visible accessibility" : "QA controls hidden accessibility")
        let expected: Set<String> = controlsVisible
            ? ["livingQA.toggleControls", "livingQA.previous", "livingQA.next", "livingQA.pause", "livingQA.reduceMotion", "livingQA.session"]
            : ["livingQA.toggleControls"]
        // Enumerate all actual buttons, never filter by identifier or visibility.
        let buttons = app.buttons.allElementsBoundByIndex
        XCTAssertEqual(Set(buttons.map(\.identifier)), expected)
        XCTAssertEqual(buttons.count, expected.count, "No unnamed or duplicate interactive controls")
        for button in buttons { XCTAssertTrue(button.isHittable, button.identifier) }
        for type: XCUIElement.ElementType in [.switch, .navigationBar, .tabBar, .toolbar, .textField, .secureTextField,
            .textView, .searchField, .slider, .stepper, .picker, .pickerWheel, .segmentedControl, .link,
            .checkBox, .radioButton, .popUpButton, .comboBox, .menuItem] {
            XCTAssertEqual(app.descendants(matching: type).count, 0, "Unexpected interactive type: \(type)")
        }
        for name in roots { XCTAssertFalse(app.buttons[name].exists) }
        XCTAssertFalse(app.buttons["livingQA.open"].exists)
        if !controlsVisible { XCTAssertEqual(app.staticTexts.count, 0) }
    }

    @MainActor private func snapshot(_ app: XCUIApplication) -> [String: Any] {
        guard let value = app.staticTexts["livingQA.hud"].value as? String,
              let data = value.data(using: .utf8),
              let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return state
    }

    @MainActor @discardableResult private func settled(_ app: XCUIApplication, scene: String? = nil,
                                                       owners: Int = 1, running: Int? = nil, fps: Int? = nil) -> [String: Any] {
        var latest: [String: Any] = [:]
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            latest = snapshot(app)
            if latest["renderers"] as? Int == owners, latest["resources"] as? Int == owners,
               latest["surfaces"] as? Int == owners, latest["productRoots"] as? Int == 0,
               latest["preferencesUnchanged"] as? Bool == true,
               scene == nil || latest["scene"] as? String == scene,
               running == nil || latest["running"] as? Int == running,
               fps == nil || latest["fps"] as? Int == fps,
               owners == 0 || (latest["frames"] as? Int ?? 0) > 1 {
                return latest
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTFail("Renderer/ownership/preference contract did not settle: \(latest)")
        return latest
    }

    @MainActor func testLivingQAIsolation() throws {
        continueAfterFailure = false
        let app = launchQA()
        assertIsolated(app, controlsVisible: false)
        app.buttons["livingQA.toggleControls"].tap()
        assertIsolated(app, controlsVisible: true)
        settled(app, scene: scenes[0], running: 1, fps: 30)
        attachTree(app, "Direct harness one production renderer and zero product roots")
        app.buttons["livingQA.toggleControls"].tap()
        assertIsolated(app, controlsVisible: false)
        app.terminate()
        print("LIVING_QA_ISOLATION_PASS: direct launch only; exact primitive controls; one production authority; zero product roots")
    }

    @MainActor func testLivingQARuntime() throws {
        continueAfterFailure = false
        let app = launchQA()
        let reveal = app.buttons["livingQA.toggleControls"]
        reveal.tap()
        for scene in scenes {
            settled(app, scene: scene, running: 1, fps: 30)
            app.buttons["livingQA.next"].tap()
        }
        settled(app, scene: scenes[0])
        app.buttons["livingQA.previous"].tap(); settled(app, scene: scenes.last!)
        app.buttons["livingQA.next"].tap(); settled(app, scene: scenes[0])
        app.buttons["livingQA.pause"].tap(); settled(app, running: 0)
        Thread.sleep(forTimeInterval: 0.7)
        let frozen = snapshot(app)
        Thread.sleep(forTimeInterval: 1.2)
        let stillFrozen = snapshot(app)
        XCTAssertEqual(frozen["frames"] as? Int, stillFrozen["frames"] as? Int)
        XCTAssertEqual(frozen["elapsed"] as? Double, stillFrozen["elapsed"] as? Double)
        app.buttons["livingQA.pause"].tap()
        let resumed = settled(app, running: 1)
        Thread.sleep(forTimeInterval: 1.2)
        XCTAssertGreaterThan(snapshot(app)["frames"] as? Int ?? 0, resumed["frames"] as? Int ?? 0)
        app.buttons["livingQA.reduceMotion"].tap(); settled(app, running: 1, fps: 15)
        XCTAssertEqual(app.buttons["livingQA.reduceMotion"].label, "Reduce Motion: On")
        XCTAssertEqual(app.buttons["livingQA.reduceMotion"].value as? String, "On")
        app.buttons["livingQA.reduceMotion"].tap(); settled(app, running: 1, fps: 30)
        XCTAssertEqual(app.buttons["livingQA.reduceMotion"].value as? String, "Off")
        for _ in 0..<3 {
            app.buttons["livingQA.session"].tap()
            settled(app, owners: 0, running: 0)
            XCTAssertEqual(app.buttons["livingQA.session"].label, "Restart QA")
            attachTree(app, "Ended QA releases all production rendering resources")
            app.buttons["livingQA.session"].tap(); settled(app, scene: scenes[0], running: 1, fps: 30)
        }
        reveal.tap()
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1)
        app.activate()
        XCTAssertTrue(reveal.waitForExistence(timeout: 10))
        reveal.tap(); settled(app, scene: scenes[0], running: 1, fps: 30)
        assertIsolated(app, controlsVisible: true)
        app.buttons["livingQA.session"].tap(); settled(app, owners: 0)
        app.terminate()
        print("LIVING_QA_RUNTIME_PASS: twelve scenes, wrapping, pause frozen clock/frames, reduced policy, transient preferences, restart release baseline, background resume")
    }

    @MainActor private func assertNormalProduct(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Today"].waitForExistence(timeout: 15))
        for root in roots {
            XCTAssertTrue(app.buttons[root].exists)
            app.buttons[root].tap()
            XCTAssertEqual(app.buttons[root].value as? String, "Selected")
        }
        for button in app.buttons.allElementsBoundByIndex {
            XCTAssertFalse(button.identifier.hasPrefix("livingQA."), "QA is unreachable from normal navigation")
        }
        let appearance = app.buttons["Appearance"]
        XCTAssertTrue(appearance.exists)
        XCTAssertEqual(appearance.value as? String, "Expanded")
        appearance.tap(); XCTAssertEqual(appearance.value as? String, "Collapsed")
        app.buttons["Today"].tap(); app.buttons["Setup"].tap()
        XCTAssertEqual(appearance.value as? String, "Collapsed", "Ordinary product root navigation retains existing UI state")
        appearance.tap()
        attachTree(app, "Normal five-root product with no QA entry")
    }

    @MainActor func testLivingQANormal() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchArguments = ["-LifeRouteThemeOverride", "scenery.rainforest.day", "-LifeRouteLivingDiagnostics"]
        app.launch(); assertNormalProduct(app); app.terminate()
        print("LIVING_QA_NORMAL_PASS: ordinary launch, all five roots, Setup state preserved, no QA entry")
    }

    @MainActor func testLivingQARelease() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchArguments = ["-LifeRouteLivingThemeQAViewer", "-LifeRouteLivingThemeQAScene", "scenery.ocean.night"]
        app.launch(); assertNormalProduct(app); app.terminate()
        print("LIVING_QA_RELEASE_PASS: QA launch flags ignored, normal product and five roots, no QA surface")
    }
}
