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
        key("h", in: app).tap()
        key("i", in: app).tap()
        XCTAssertEqual(field.value as? String, "hi")

        let portrait = XCTAttachment(screenshot: app.screenshot())
        portrait.name = "Keyboard in portrait"
        portrait.lifetime = .keepAlways
        add(portrait)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(key("q", in: app).waitForExistence(timeout: 10))
        key("q", in: app).tap()
        XCTAssertEqual(field.value as? String, "hiq")
        let landscape = XCTAttachment(screenshot: app.screenshot())
        landscape.name = "Keyboard in landscape"
        landscape.lifetime = .keepAlways
        add(landscape)
        XCUIDevice.shared.orientation = .portrait
    }

    private func dismissSystemKeyboardIntroduction(in app: XCUIApplication) {
        let introduction = app.otherElements["UIContinuousPathIntroductionView"]
        if introduction.exists {
            let button = app.buttons["Continue"].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
        }
    }

    private func key(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["key-\(label)"].firstMatch
    }
}
