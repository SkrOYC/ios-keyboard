import XCTest

final class KeyboardSmokeTests: XCTestCase {
    func testInstallEnableAndTypeWithKeyboardExtension() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.descendants(matching: .any)["keyboard-sample"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()

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
        for _ in 0..<5 {
            if app.buttons["key-q"].exists { break }
            let globe = app.buttons["Next keyboard"].firstMatch
            XCTAssertTrue(globe.waitForExistence(timeout: 5), app.debugDescription)
            globe.tap()
        }
        XCTAssertTrue(app.buttons["key-q"].waitForExistence(timeout: 10), app.debugDescription)
        app.buttons["Shift"].tap()
        app.buttons["key-h"].tap()
        app.buttons["key-i"].tap()
        app.buttons["Space"].tap()
        app.buttons["key-q"].tap()
        app.buttons["Delete"].tap()
        app.buttons["Return"].tap()
        XCTAssertEqual(field.value as? String, "Hi \n")

        let portrait = XCTAttachment(screenshot: app.screenshot())
        portrait.name = "Keyboard in portrait"
        portrait.lifetime = .keepAlways
        add(portrait)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["key-q"].waitForExistence(timeout: 10))
        app.buttons["key-q"].tap()
        XCTAssertEqual(field.value as? String, "Hi \nq")
        let landscape = XCTAttachment(screenshot: app.screenshot())
        landscape.name = "Keyboard in landscape"
        landscape.lifetime = .keepAlways
        add(landscape)
        XCUIDevice.shared.orientation = .portrait
    }
}
