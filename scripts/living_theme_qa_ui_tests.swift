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

    @MainActor func testLivingQACalendar() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchArguments = ["-LifeRouteSectionOverride", "schedule", "-LifeRouteThemeOverride", "royal"]
        app.launch()
        XCTAssertTrue(app.buttons["Add appointment"].waitForExistence(timeout: 15))
        let existing = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "QA landscape appointment")).firstMatch
        if !existing.exists {
        app.buttons["Add appointment"].tap()
        let title = app.textFields["Appointment title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("QA landscape appointment")
        let save = app.buttons["Save appointment"]
        for _ in 0..<3 { if save.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(save.isHittable); save.tap()
        }
        XCTAssertTrue(app.scrollViews["calendar.scroll"].waitForExistence(timeout: 5))
        for (label, orientation) in [("portrait", UIDeviceOrientation.portrait),
                                     ("landscape-left", .landscapeLeft), ("landscape-right", .landscapeRight)] {
            XCUIDevice.shared.orientation = orientation
            Thread.sleep(forTimeInterval: 1)
            let viewport = app.scrollViews["calendar.scroll"].frame
            print("CALENDAR_VIEWPORT " + label + " " + String(describing: viewport))
            if orientation != .portrait { XCTAssertGreaterThan(viewport.width, viewport.height) }
            attachTree(app, "Calendar geometry " + label)
            for range in ["Agenda", "Week", "Month"] {
                let button = app.buttons[range].firstMatch
                for _ in 0..<5 { if button.isHittable { break }; app.scrollViews["calendar.scroll"].swipeDown() }
                XCTAssertTrue(button.isHittable, "Range reachable after rotation: " + range)
                button.tap()
                if orientation != .portrait {
                    XCTAssertLessThan(abs(app.buttons["Choose date"].frame.midY - app.buttons["Previous period"].frame.midY), 12,
                                      "Compact header and range share one row in landscape")
                }
                let event = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "QA landscape appointment")).firstMatch
                let scroll = app.scrollViews["calendar.scroll"]
                for _ in 0..<6 {
                    if event.isHittable && event.frame.minY >= scroll.frame.minY && event.frame.maxY <= scroll.frame.maxY { break }
                    scroll.swipeUp()
                }
                XCTAssertTrue(event.isHittable, "Event reachable below chrome: " + label + " " + range)
                XCTAssertGreaterThanOrEqual(event.frame.minY, scroll.frame.minY)
                XCTAssertLessThanOrEqual(event.frame.maxY, scroll.frame.maxY, "Full event stays above the root toolbar")
                XCTAssertTrue(app.buttons["Calendar"].exists)
                let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                screenshot.name = "Calendar " + label + " " + range
                screenshot.lifetime = .keepAlways; add(screenshot)
            }
        }
        app.terminate()
        print("LIVING_QA_CALENDAR_PASS: synthetic manual appointment reachable in all3 ranges across portrait and both landscapes")
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

    @MainActor private func audit(_ app: XCUIApplication, scene: String? = nil, fps: Int = 30) -> [String: Any] {
        var latest: [String: Any] = [:]
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if let raw = app.staticTexts["livingAudit.state"].value as? String,
               let data = raw.data(using: .utf8),
               let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                latest = state
                if state["renderers"] as? Int == 1, state["resources"] as? Int == 1,
                   state["surfaces"] as? Int == 1, state["running"] as? Int == 1,
                   state["fallbacks"] as? Int == 0, state["fps"] as? Int == fps,
                   (state["elapsed"] as? Double ?? 0) >= 2,
                   scene == nil || (state["scene"] as? String == scene && state["completedScene"] as? String == scene) { return state }
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        attachTree(app, "Continuity audit failed")
        XCTFail("Actual production renderer did not satisfy foreground contract: \(latest)")
        return latest
    }

    @MainActor private func continued(_ app: XCUIApplication, from before: [String: Any], label: String,
                                      scene: String? = nil) -> [String: Any] {
        Thread.sleep(forTimeInterval: 1.0)
        let after = audit(app, scene: scene)
        XCTAssertEqual(after["rendererIdentity"] as? String, before["rendererIdentity"] as? String, label)
        XCTAssertGreaterThan(after["elapsed"] as? Double ?? 0, (before["elapsed"] as? Double ?? 0) + 0.6, label)
        XCTAssertGreaterThan(after["frames"] as? Int ?? 0, (before["frames"] as? Int ?? 0) + 15, label)
        let data = try! JSONSerialization.data(withJSONObject: ["label": label, "before": before, "after": after], options: [.sortedKeys])
        let json = String(data: data, encoding: .utf8)!
        let attachment = XCTAttachment(string: json); attachment.name = label; attachment.lifetime = .keepAlways; add(attachment)
        print("LIVING_CONTINUITY_SAMPLE " + json)
        return after
    }

    @MainActor private func openThemeCenter(_ app: XCUIApplication) {
        app.buttons["Setup"].tap()
        let entry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Theme Center")).firstMatch
        for _ in 0..<6 { if entry.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(entry.isHittable); entry.tap()
        XCTAssertTrue(app.navigationBars["Themes"].waitForExistence(timeout: 5))
    }

    @MainActor func testLivingQAContinuity() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchArguments = ["-LifeRouteSectionOverride", "today", "-LifeRouteThemeOverride", "scenery.ocean.day", "-LifeRouteLivingDiagnostics"]
        app.launch()
        var prior = audit(app, scene: "scenery.ocean.day")
        openThemeCenter(app)
        prior = continued(app, from: prior, label: "Theme Center remains open and alive")
        let card = app.buttons["Ocean Night, Living motion"].firstMatch
        for _ in 0..<8 {
            if card.isHittable && card.frame.minY > 130 && card.frame.maxY < 830 { break }
            if card.exists && card.frame.minY < 130 { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(card.isHittable); card.tap()
        prior = continued(app, from: prior, label: "Selected Ocean Night lives before selector dismissal", scene: "scenery.ocean.night")
        XCTAssertTrue(app.navigationBars["Themes"].exists)
        Thread.sleep(forTimeInterval: 3)
        app.navigationBars["Themes"].buttons["Setup"].tap()
        prior = continued(app, from: prior, label: "Selector dismissal retains the same clock")
        for root in ["Today", "Calendar", "Tools"] {
            app.buttons[root].tap()
            XCTAssertEqual(app.buttons[root].value as? String, "Selected")
            prior = continued(app, from: prior, label: "Root switch to " + root)
        }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.55))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.55))
        print("LIVING_ACTION swipe.begin uptime=\(ProcessInfo.processInfo.systemUptime)")
        start.press(forDuration: 0.2, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertEqual(app.buttons["Calendar"].value as? String, "Selected")
        prior = continued(app, from: prior, label: "Slow root swipe retains live clock")
        let shortEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.26, dy: 0.55))
        start.press(forDuration: 0.2, thenDragTo: shortEnd, withVelocity: .slow, thenHoldForDuration: 0.4)
        XCTAssertEqual(app.buttons["Calendar"].value as? String, "Selected")
        prior = continued(app, from: prior, label: "Cancelled root swipe retains live clock")
        print("LIVING_ACTION sheet.begin uptime=\(ProcessInfo.processInfo.systemUptime)")
        app.buttons["Choose date"].tap()
        XCTAssertTrue(app.navigationBars["Choose Date"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 3)
        app.navigationBars["Choose Date"].buttons["Done"].tap()
        prior = continued(app, from: prior, label: "Ordinary foreground date sheet retains renderer and clock")
        Thread.sleep(forTimeInterval: 3)
        print("LIVING_QA_CONTINUITY_PASS: selector selection while open, dismissal and three normal root switches; one renderer, continuing nonzero clock; continuous video required")
        app.terminate()
    }

    @MainActor func testLivingQASystemmotion() throws {
        continueAfterFailure = false
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        let accessibility = settings.staticTexts["Accessibility"].firstMatch
        for _ in 0..<8 { if accessibility.isHittable { break }; settings.swipeUp() }
        attachTree(settings, "Actual Simulator Accessibility settings")
        XCTAssertTrue(accessibility.isHittable); accessibility.tap()
        let motion = settings.staticTexts["Motion"].firstMatch
        for _ in 0..<6 { if motion.isHittable { break }; settings.swipeUp() }
        XCTAssertTrue(motion.isHittable); motion.tap()
        let reduce = settings.switches["Reduce Motion"].firstMatch
        XCTAssertTrue(reduce.waitForExistence(timeout: 5))
        let initial = reduce.value as? String
        if initial != "1" { reduce.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        let toggled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: reduce)
        XCTAssertEqual(XCTWaiter.wait(for: [toggled], timeout: 3), .completed)
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchArguments = ["-LifeRouteThemeOverride", "scenery.ocean.night", "-LifeRouteLivingDiagnostics"]
        app.launch()
        let reduced = audit(app, scene: "scenery.ocean.night", fps: 15)
        attachTree(app, "Actual system Reduce Motion selects calm production policy")
        settings.activate()
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 5))
        if reduce.value as? String == "1" { reduce.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "0"), object: reduce)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 3), .completed)
        app.activate()
        _ = audit(app, scene: "scenery.ocean.night", fps: 30)
        settings.activate()
        if initial == "1" { reduce.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        print("LIVING_QA_SYSTEMMOTION_PASS: actual Settings Reduce Motion feeds production environment and is restored; reduced frames \(reduced["frames"] ?? 0)")
        app.terminate()
    }

}
