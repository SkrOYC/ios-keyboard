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
        let general = settings.cells["General"]
        for _ in 0..<5 where !general.isHittable {
            settings.swipeUp()
        }
        XCTAssertTrue(general.waitForExistence(timeout: 10), settings.debugDescription)
        general.tap()
        settings.cells["Keyboard"].firstMatch.tap()
        settings.cells["Keyboards"].firstMatch.tap()
        settings.cells["Add New Keyboard…"].firstMatch.tap()
        let keyboard = settings.cells.containing(.staticText, identifier: "Keyboard").firstMatch
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
