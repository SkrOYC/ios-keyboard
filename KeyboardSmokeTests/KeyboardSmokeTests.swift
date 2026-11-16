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
        let firstKey = key("h", in: app)
        let inputReady = expectation(for: NSPredicate { _, _ in firstKey.isHittable }, evaluatedWith: firstKey)
        wait(for: [inputReady], timeout: 15)
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

        tap(key("123", in: app))
        XCTAssertTrue(key("1", in: app).waitForExistence(timeout: 5))
        tap(key("1", in: app))
        tap(key("2", in: app))
        tap(key("3", in: app))
        XCTAssertEqual(field.value as? String, "Hi \n123")
        let symbols = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        symbols.name = "Keyboard symbols"
        symbols.lifetime = .keepAlways
        add(symbols)
        tap(key("123", in: app))
        let period = key("period", in: app)
        tap(period)
        XCTAssertEqual(field.value as? String, "Hi \n123.")
        let origin = period.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let rowPitch = period.frame.midY - key("k", in: app).frame.midY
        let comma = origin.withOffset(CGVector(dx: 0, dy: -1.2 * rowPitch))
        NSLog("HEX_POPUP_PORTRAIT")
        origin.press(forDuration: 4, thenDragTo: comma)
        XCTAssertEqual(field.value as? String, "Hi \n123.,")
        origin.press(forDuration: 0.55)
        XCTAssertEqual(field.value as? String, "Hi \n123.,")

        let portrait = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        portrait.name = "Keyboard in portrait"
        portrait.lifetime = .keepAlways
        add(portrait)

        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        wait(for: [rotated], timeout: 15)
        XCTAssertTrue(key("q", in: app).waitForExistence(timeout: 10))
        tap(key("q", in: app))
        XCTAssertEqual(field.value as? String, "Hi \n123.,q")
        NSLog("HEX_POPUP_LANDSCAPE")
        key("period", in: app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 4)
        XCTAssertEqual(field.value as? String, "Hi \n123.,q")
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
