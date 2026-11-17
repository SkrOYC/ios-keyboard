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
        for _ in 0..<5 where !isOnScreen(general, in: settings) {
            settings.swipeUp()
        }
        XCTAssertTrue(general.waitForExistence(timeout: 10), settings.debugDescription)
        tapSetting(general, in: settings)
        tapSetting(settings.cells.containing(.staticText, identifier: "Keyboard").firstMatch, in: settings)
        tapSetting(settings.cells.containing(.staticText, identifier: "Keyboards").firstMatch, in: settings)
        let addKeyboard = settings.buttons["AddNewKeyboard"].firstMatch
        XCTAssertTrue(addKeyboard.waitForExistence(timeout: 10), settings.debugDescription)
        tapSetting(addKeyboard, in: settings)
        let keyboard = settings.cells["Keyboard Host"].firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 10), settings.debugDescription)
        tapSetting(keyboard, in: settings)

        app.activate()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 5) { field.tap() }
        dismissSystemKeyboardIntroduction(in: app)
        selectKeyboardExtension(in: app)
        dismissEditingMenu(in: app)
        XCTAssertTrue(key("q", in: app).waitForExistence(timeout: 10), app.debugDescription)
        let before = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        before.name = "Keyboard before gestures"
        before.lifetime = .keepAlways
        add(before)
        let firstKey = key("h", in: app)
        waitForOnScreen(firstKey, in: app)
        let inputReady = expectation(for: NSPredicate { _, _ in firstKey.isHittable }, evaluatedWith: firstKey)
        wait(for: [inputReady], timeout: 15)
        swipe(key("h", in: app), dx: 0, dy: -1)
        let after = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        after.name = "Keyboard after capitalize gesture"
        after.lifetime = .keepAlways
        add(after)
        assertText("H", in: field)
        tap(key("i", in: app))
        swipe(key("i", in: app), dx: 1, dy: 0)
        tap(key("q", in: app))
        swipe(key("q", in: app), dx: -1, dy: 0)
        swipe(key("h", in: app), dx: 0, dy: 1)
        assertText("Hi \n", in: field)

        let wFrame = key("w", in: app).frame
        let qFrame = key("q", in: app).frame
        let appFrame = app.frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: wFrame.midX - appFrame.minX,
            dy: (wFrame.midY + qFrame.midY) / 2 - appFrame.minY
        )).tap()
        assertText("Hi \n", in: field)

        tap(key("123", in: app))
        XCTAssertTrue(key("1", in: app).waitForExistence(timeout: 5))
        tap(key("1", in: app))
        tap(key("2", in: app))
        tap(key("3", in: app))
        assertText("Hi \n123", in: field)
        let symbols = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        symbols.name = "Keyboard symbols"
        symbols.lifetime = .keepAlways
        add(symbols)
        tap(key("123", in: app))
        let period = key("period", in: app)
        tap(period)
        assertText("Hi \n123.", in: field)
        let origin = coordinate(period, in: app)
        let rowPitch = period.frame.midY - key("k", in: app).frame.midY
        let comma = origin.withOffset(CGVector(dx: 0, dy: -1.2 * rowPitch))
        NSLog("HEX_POPUP_PORTRAIT")
        origin.press(forDuration: 8, thenDragTo: comma)
        assertText("Hi \n123.,", in: field)
        origin.press(forDuration: 0.55)
        assertText("Hi \n123.,", in: field)

        let familiarE = key("e", in: app).frame
        coordinate(key("123", in: app), in: app).press(forDuration: 0.55)
        XCTAssertTrue(app.buttons["preset-thumbSplit"].waitForExistence(timeout: 5))
        let picker = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        picker.name = "Letter order picker"
        picker.lifetime = .keepAlways
        add(picker)
        app.buttons["preset-thumbSplit"].tap()
        XCTAssertNotEqual(key("e", in: app).frame, familiarE)
        coordinate(key("123", in: app), in: app).press(forDuration: 0.55)
        app.buttons["preset-keepEA"].tap()
        XCTAssertTrue(key("e", in: app).exists)
        coordinate(key("123", in: app), in: app).press(forDuration: 0.55)
        app.buttons["preset-familiar"].tap()
        XCTAssertEqual(key("e", in: app).frame, familiarE)

        let portrait = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        portrait.name = "Keyboard in portrait"
        portrait.lifetime = .keepAlways
        add(portrait)

        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        wait(for: [rotated], timeout: 15)
        XCTAssertTrue(key("q", in: app).waitForExistence(timeout: 10))
        tap(key("q", in: app))
        assertText("Hi \n123.,q", in: field)
        NSLog("HEX_POPUP_LANDSCAPE")
        coordinate(key("period", in: app), in: app).press(forDuration: 8)
        assertText("Hi \n123.,q", in: field)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Keyboard in landscape"
        landscape.lifetime = .keepAlways
        add(landscape)
        let landscapeText = field.value as? String ?? ""
        let landscapeE = key("e", in: app).frame
        coordinate(key("123", in: app), in: app).press(forDuration: 0.55)
        let done = app.buttons["preset-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        let compactPicker = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        compactPicker.name = "Letter order picker in landscape"
        compactPicker.lifetime = .keepAlways
        add(compactPicker)
        done.tap()
        assertText(landscapeText, in: field)
        XCTAssertEqual(key("e", in: app).frame, landscapeE)
        let previous = field.value as? String ?? ""
        for _ in 0..<6 { tap(key("q", in: app)) }
        assertText(previous + String(repeating: "q", count: 6), in: field)
        let beforeDelete = (field.value as? String ?? "").count
        let repeatKey = key("h", in: app)
        let repeatStart = coordinate(repeatKey, in: app)
        repeatStart.press(forDuration: 0.05, thenDragTo: repeatStart.withOffset(
            CGVector(dx: -repeatKey.frame.width * 2.2, dy: 0)
        ))
        let repeated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (field.value as? String ?? "").count <= beforeDelete - 2
        }, object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [repeated], timeout: 5), .completed)
        XCUIDevice.shared.orientation = .portrait
    }

    private func swipe(_ key: XCUIElement, dx: CGFloat, dy: CGFloat) {
        let start = coordinate(key, in: XCUIApplication())
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

    private func selectKeyboardExtension(in app: XCUIApplication) {
        for _ in 0..<5 {
            dismissSystemKeyboardIntroduction(in: app)
            let first = key("q", in: app)
            let keysReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.isOnScreen(first, in: app)
            }, object: first)
            if XCTWaiter.wait(for: [keysReady], timeout: 15) == .completed { return }
            let globe = app.buttons.matching(NSPredicate(
                format: "label == %@ OR label == %@", "Next keyboard", "Emoji"
            )).firstMatch
            let inputReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.isOnScreen(first, in: app) || self.isOnScreen(globe, in: app)
            }, object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [inputReady], timeout: 15), .completed, app.debugDescription)
            if isOnScreen(first, in: app) { return }
            // Native iPad keyboard elements can have valid frames but invalid AX hit points.
            coordinate(globe, in: app).tap()
        }
    }

    private func dismissEditingMenu(in app: XCUIApplication) {
        let menu = app.descendants(matching: .any)["AutoFill"].firstMatch
        guard isOnScreen(menu, in: app) else { return }
        let navigation = app.navigationBars.firstMatch
        waitForOnScreen(navigation, in: app)
        coordinate(navigation, in: app).tap()
        let dismissed = expectation(for: NSPredicate { _, _ in
            !self.isOnScreen(menu, in: app)
        }, evaluatedWith: menu)
        wait(for: [dismissed], timeout: 5)
    }

    private func isOnScreen(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        return frame.minX.isFinite && frame.minY.isFinite && frame.width.isFinite && frame.height.isFinite
            && frame.width > 0 && frame.height > 0
            && app.frame.contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    private func waitForOnScreen(_ element: XCUIElement, in app: XCUIApplication) {
        let ready = expectation(for: NSPredicate { _, _ in
            self.isOnScreen(element, in: app)
        }, evaluatedWith: element)
        wait(for: [ready], timeout: 30)
    }

    private func tapSetting(_ element: XCUIElement, in app: XCUIApplication) {
        waitForOnScreen(element, in: app)
        coordinate(element, in: app).tap()
    }

    private func tap(_ key: XCUIElement) {
        coordinate(key, in: XCUIApplication()).tap()
    }

    private func coordinate(_ key: XCUIElement, in app: XCUIApplication) -> XCUICoordinate {
        let frame = key.frame
        let appFrame = app.frame
        return app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: frame.midX - appFrame.minX, dy: frame.midY - appFrame.minY)
        )
    }

    private func assertText(_ expected: String, in field: XCUIElement) {
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            field.value as? String == expected
        }, object: field)
        _ = XCTWaiter.wait(for: [updated], timeout: 5)
        XCTAssertEqual(field.value as? String, expected)
    }

    private func key(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["key-\(label)"].firstMatch
    }
}
