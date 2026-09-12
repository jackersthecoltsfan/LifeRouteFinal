import XCTest
final class NativeUI: XCTestCase {
 @MainActor func testLivingNativeIntegration() throws {
  continueAfterFailure = false
  XCUIDevice.shared.orientation = .portrait
  let app = XCUIApplication(bundleIdentifier: "Com.Brandongood.LifeRoute")
  app.launchArguments = ["-LifeRouteSectionOverride", "today", "-LifeRouteThemeOverride", "scenery.rainforest.day", "-LifeRouteLivingDiagnostics"]
  app.launch()
  XCTAssertTrue(app.buttons["Setup"].waitForExistence(timeout: 15))
  for cycle in 0..<2 {
   for root in ["Today","Calendar","Tools","Resources","Setup"] {
    let button=app.buttons[root].firstMatch
    XCTAssertTrue(button.isHittable, root); button.tap()
    XCTAssertEqual(button.value as? String, "Selected", root)
    let capture=XCTAttachment(screenshot:app.screenshot());capture.name="root-\(cycle)-\(root)";capture.lifetime = .keepAlways;add(capture)
   }
  }
  print("NATIVE_UI_ROOTS_PASS")
  let buildIdentity = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Source commit SOURCE_COMMIT_FROM_RUNNER")).firstMatch
  XCTAssertTrue(buildIdentity.exists, "Visible Setup source identity matches the supplied app")
  print("NATIVE_UI_BUILD_IDENTITY_PASS")
  print("NATIVE_UI_SETUP_TREE \(app.debugDescription)")
  let theme=app.buttons.matching(NSPredicate(format:"label CONTAINS %@", "Theme Center")).firstMatch
  for _ in 0..<5 { if theme.isHittable { break }; app.swipeUp() }
  XCTAssertTrue(theme.isHittable); theme.tap()
  XCTAssertTrue(app.navigationBars["Themes"].waitForExistence(timeout:5))
  print("NATIVE_UI_THEMES_TREE \(app.debugDescription)")
  let shot=XCTAttachment(screenshot:app.screenshot());shot.name="theme-center";shot.lifetime = .keepAlways;add(shot)
  XCTAssertFalse(app.buttons.matching(NSPredicate(format:"label CONTAINS %@", "DYNAMIC")).firstMatch.exists)
  XCTAssertTrue(app.staticTexts["12 themes"].exists)
  let names=["Rainforest Day","Rainforest Night","Ocean Day","Ocean Night","Arctic Day","Arctic Night","Mountains Day","Mountains Night","Canyon Day","Canyon Night","Desert Day","Desert Night"]
  for name in names {
   let card=app.buttons[name+", Living motion"].firstMatch
   for _ in 0..<8 {
    if card.isHittable && card.frame.minY > 130 && card.frame.maxY < 830 { break }
    if card.exists && card.frame.minY < 130 { app.swipeDown() } else { app.swipeUp() }
   }
   XCTAssertTrue(card.isHittable,name);card.tap()
   XCTAssertEqual(card.value as? String,"Selected",name)
   app.navigationBars["Themes"].buttons["Setup"].tap()
   XCTAssertTrue(app.buttons["Today"].waitForExistence(timeout:5))
   let scene=XCTAttachment(screenshot:app.screenshot());scene.name="selected-"+name;scene.lifetime = .keepAlways;add(scene)
   print("NATIVE_UI_SCENE_SELECTED \(name)")
   let opener=app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Theme Center")).firstMatch
   XCTAssertTrue(opener.isHittable);opener.tap()
   XCTAssertTrue(app.navigationBars["Themes"].waitForExistence(timeout:5))
  }
  XCTAssertFalse(app.debugDescription.contains("Motion pending"))
  app.navigationBars["Themes"].buttons["Setup"].tap()
  XCUIDevice.shared.press(.home);app.activate()
  XCTAssertTrue(app.buttons["Setup"].waitForExistence(timeout:5))
  print("NATIVE_UI_BACKGROUND_FOREGROUND_PASS")
  app.terminate()
  app.launchArguments = ["-LifeRouteSectionOverride", "setup"]
  app.launch()
  XCTAssertTrue(app.buttons["Setup"].waitForExistence(timeout: 10))
  let reopenedTheme = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Theme Center")).firstMatch
  for _ in 0..<6 { if reopenedTheme.isHittable { break }; app.swipeUp() }
  XCTAssertTrue(reopenedTheme.isHittable); reopenedTheme.tap()
  XCTAssertTrue(app.navigationBars["Themes"].waitForExistence(timeout: 5))
  let restoredTheme = app.buttons["Desert Night, Living motion"].firstMatch
  for _ in 0..<8 { if restoredTheme.isHittable { break }; app.swipeUp() }
  XCTAssertEqual(restoredTheme.value as? String, "Selected", "Selected theme persists across process relaunch without a theme override")
  print("NATIVE_UI_THEME_RELAUNCH_PASS")
  app.terminate()
  app.launchArguments=["-LifeRouteSectionOverride","tools","-LifeRouteToolsDestinationOverride","visualTimer","-LifeRouteThemeOverride","scenery.ocean.night","-LifeRouteVisualTimerAutoStart","-LifeRouteLivingDiagnostics"]
  app.launch()
  let expand=app.buttons["visualTimer.expand"].firstMatch
  XCTAssertTrue(expand.waitForExistence(timeout:10))
  if !app.buttons["visualTimer.close"].isHittable { expand.tap() }
  let close=app.buttons["visualTimer.close"].firstMatch
  XCTAssertTrue(close.waitForExistence(timeout:5));XCTAssertTrue(close.isHittable)
  let full=XCTAttachment(screenshot:app.screenshot());full.name="timer-fullscreen";full.lifetime = .keepAlways;add(full)
  close.tap()
  let settled=XCTNSPredicateExpectation(predicate:NSPredicate(format:"hittable == true"),object:expand)
  XCTAssertEqual(XCTWaiter.wait(for:[settled],timeout:5),.completed)
  let embedded=XCTAttachment(screenshot:app.screenshot());embedded.name="timer-resumed";embedded.lifetime = .keepAlways;add(embedded)
  print("NATIVE_UI_TIMER_COVER_RESUME_PASS")
  print("NATIVE_UI_COMPLETE_PASS")

 }
}
