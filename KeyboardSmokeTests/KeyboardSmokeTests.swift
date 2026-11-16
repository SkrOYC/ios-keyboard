import XCTest

final class KeyboardSmokeTests: XCTestCase {
    func testInstallEnableAndTypeWithKeyboardExtension() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.descendants(matching: .any)["keyboard-sample"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        dismissSystemKeyboardIntroduction(in: app)

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        let general = settings.cells.containing(.staticText, identifier: "General").firstMatch
        for _ in 0..<5 where !general.isHittable {
            settings.swipeUp()
        }
        XCTAssertTrue(general.waitForExistence(timeout: 10), settings.debugDescription)
        general.tap()
        settings.cells.containing(.staticText, identifier: "Keyboard").firstMatch.tap()
        settings.cells.containing(.staticText, identifier: "Keyboards").firstMatch.tap()
        let addKeyboard = settings.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Add New Keyboard")).firstMatch
        XCTAssertTrue(addKeyboard.waitForExistence(timeout: 10), settings.debugDescription)
        addKeyboard.tap()
        let keyboard = settings.cells["Keyboard Host"].firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 10), settings.debugDescription)
        keyboard.tap()

        app.activate()
        field.tap()
        dismissSystemKeyboardIntroduction(in: app)
        for _ in 0..<5 {
            dismissSystemKeyboardIntroduction(in: app)
            if key("q", in: app).waitForExistence(timeout: 3) { break }
            let globe = app.buttons["Next keyboard"].firstMatch
            XCTAssertTrue(globe.waitForExistence(timeout: 5), app.debugDescription)
            globe.tap()
        }
        XCTAssertTrue(key("q", in: app).waitForExistence(timeout: 10), app.debugDescription)
        let before = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        before.name = "Keyboard before gestures"
        before.lifetime = .keepAlways
        add(before)
        swipe(key("h", in: app), dx: 0, dy: -1)
        let after = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        after.name = "Keyboard after capitalize gesture"
        after.lifetime = .keepAlways
        add(after)
        XCTAssertEqual(field.value as? String, "H", app.debugDescription)
        tap(key("i", in: app))
        swipe(key("i", in: app), dx: 1, dy: 0)
        tap(key("q", in: app))
        swipe(key("q", in: app), dx: -1, dy: 0)
        swipe(key("h", in: app), dx: 0, dy: 1)
        XCTAssertEqual(field.value as? String, "Hi \n")

        let portrait = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        portrait.name = "Keyboard in portrait"
        portrait.lifetime = .keepAlways
        add(portrait)

        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        wait(for: [rotated], timeout: 15)
        XCTAssertTrue(key("q", in: app).waitForExistence(timeout: 10))
        tap(key("q", in: app))
        XCTAssertEqual(field.value as? String, "Hi \nq")
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Keyboard in landscape"
        landscape.lifetime = .keepAlways
        add(landscape)
        XCUIDevice.shared.orientation = .portrait
    }

    private func swipe(_ key: XCUIElement, dx: CGFloat, dy: CGFloat) {
        let start = key.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // Half a key's width exceeds the scaled 70-unit threshold without repeating delete.
        let travel = key.frame.width * 0.5
        let end = start.withOffset(CGVector(dx: dx * travel, dy: dy * travel))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func dismissSystemKeyboardIntroduction(in app: XCUIApplication) {
        let introduction = app.otherElements["UIContinuousPathIntroductionView"]
        if introduction.exists {
            let button = app.buttons["Continue"].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
        }
    }

    private func tap(_ key: XCUIElement) {
        key.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func key(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["key-\(label)"].firstMatch
    }
}
