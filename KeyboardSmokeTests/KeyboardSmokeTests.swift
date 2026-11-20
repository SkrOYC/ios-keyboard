import XCTest
import UIKit

final class KeyboardSmokeTests: XCTestCase {
    private var probeTuning: KeyboardTuning { KeyboardTuning(tablet: UIDevice.current.userInterfaceIdiom == .pad) }
    private var heldGestureDuration: TimeInterval { max(1, 2 * probeTuning.holdMilliseconds / 1000) }

    func testInstallEnableAndTypeWithKeyboardExtension() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        let field = app.descendants(matching: .any)["keyboard-sample"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        dismissSystemKeyboardIntroduction(in: app)

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        while settings.navigationBars.buttons.firstMatch.exists
            && !settings.cells.containing(.staticText, identifier: "General").firstMatch.exists {
            settings.navigationBars.buttons.firstMatch.tap()
        }
        let general = settings.cells.containing(.staticText, identifier: "General").firstMatch
        for _ in 0..<5 where !isOnScreen(general, in: settings) {
            settings.swipeUp()
        }
        XCTAssertTrue(general.waitForExistence(timeout: 10), settings.debugDescription)
        tapSetting(general, in: settings)
        tapSetting(settings.cells.containing(.staticText, identifier: "Keyboard").firstMatch, in: settings)
        tapSetting(settings.cells.containing(.staticText, identifier: "Keyboards").firstMatch, in: settings)
        let installedKeyboard = settings.cells["com.skroyc.keyboard.Keyboard"]
        if !installedKeyboard.exists {
            let addKeyboard = settings.buttons["AddNewKeyboard"].firstMatch
            XCTAssertTrue(addKeyboard.waitForExistence(timeout: 10), settings.debugDescription)
            tapSetting(addKeyboard, in: settings)
            let keyboard = settings.cells["Keyboard Host"].firstMatch
            XCTAssertTrue(keyboard.waitForExistence(timeout: 10), settings.debugDescription)
            tapSetting(keyboard, in: settings)
        }
        XCTAssertTrue(installedKeyboard.waitForExistence(timeout: 10), settings.debugDescription)

        app.activate()
        let keyboardRestored = app.keyboards.firstMatch.waitForExistence(timeout: 5)
        print("KEYBOARD_SELECTION activated keyboardExists=\(keyboardRestored)")
        if !keyboardRestored { field.tap() }
        dismissSystemKeyboardIntroduction(in: app)
        selectKeyboardExtension(in: app)
        dismissEditingMenu(in: app)
        XCTAssertTrue(key("q", in: app).waitForExistence(timeout: 10), app.debugDescription)
        app.buttons["tuning-reset"].tap()
        openPicker(in: app)
        app.buttons["preset-familiar"].tap()
        pasteEmoji(into: field, in: app)
        tap(key("q", in: app))
        assertText("👩‍💻q", in: field)
        try moveCursorFromLayerKey(direction: -1, in: app)
        tap(key("h", in: app))
        assertText("h👩‍💻q", in: field)
        let emoji = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        emoji.name = "Trackpad preserves emoji grapheme"
        emoji.lifetime = .keepAlways
        add(emoji)
        try moveCursorFromLayerKey(direction: 1, in: app)
        for expected in ["h👩‍💻", "h", ""] {
            swipe(key("q", in: app), dx: -1, dy: 0)
            assertText(expected, in: field)
        }
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
        origin.press(forDuration: heldGestureDuration)
        assertText("Hi \n123.,", in: field)
        let columnPitch = key("e", in: app).frame.midX - key("q", in: app).frame.midX
        origin.press(forDuration: heldGestureDuration, thenDragTo: origin.withOffset(CGVector(dx: -columnPitch, dy: -rowPitch)))
        assertText("Hi \n123.,?", in: field)

        swipe(key("123", in: app), dx: 0, dy: -1)
        XCTAssertEqual(key("123", in: app).value as? String, "Caps lock on")
        for letter in "abcdefghijklmnopqrstuvwxyz" {
            XCTAssertEqual(key(String(letter), in: app).label, String(letter).uppercased())
        }
        tap(key("h", in: app))
        assertText("Hi \n123.,?H", in: field)
        swipe(key("123", in: app), dx: 0, dy: -1)
        XCTAssertEqual(key("123", in: app).value as? String, "Caps lock off")
        XCTAssertEqual(key("h", in: app).label, "h")

        let trackpad = key("123", in: app)
        coordinate(trackpad, in: app).press(forDuration: heldGestureDuration)
        assertText("Hi \n123.,?H", in: field)
        try moveCursorFromLayerKey(direction: -1, in: app)
        tap(key("q", in: app))
        assertText("Hi \n123.,q?H", in: field)
        try moveCursorFromLayerKey(direction: 1, in: app)

        let familiarE = key("e", in: app).frame
        openPicker(in: app)
        XCTAssertTrue(app.buttons["preset-familiar"].isSelected)
        app.buttons["preset-done"].tap()
        assertText("Hi \n123.,q?H", in: field)
        XCTAssertEqual(key("e", in: app).frame, familiarE)
        openPicker(in: app)
        XCTAssertTrue(app.buttons["preset-thumbSplit"].waitForExistence(timeout: 5))
        let picker = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        picker.name = "Letter order picker"
        picker.lifetime = .keepAlways
        add(picker)
        app.buttons["preset-thumbSplit"].tap()
        XCTAssertNotEqual(key("e", in: app).frame, familiarE)
        openPicker(in: app)
        app.buttons["preset-keepEA"].tap()
        XCTAssertTrue(key("e", in: app).exists)
        openPicker(in: app)
        app.buttons["preset-familiar"].tap()
        XCTAssertEqual(key("e", in: app).frame, familiarE)
        assertText("Hi \n123.,q?H", in: field)

        let portrait = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        portrait.name = "Keyboard in portrait"
        portrait.lifetime = .keepAlways
        add(portrait)

        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        wait(for: [rotated], timeout: 15)
        XCTAssertTrue(key("q", in: app).waitForExistence(timeout: 10))
        var splitSample = "not evaluated"
        var splitSamples = 0
        let splitStarted = Date()
        let splitReady = expectation(for: NSPredicate { _, _ in
            let left = self.key("g", in: app).frame
            let leftApp = app.frame
            var right = CGRect.zero
            var rightApp = CGRect.zero
            let ready = left.midX < leftApp.midX && {
                right = self.key("h", in: app).frame
                rightApp = app.frame
                return right.midX > rightApp.midX
            }()
            splitSamples += 1
            splitSample = "left=\(left) leftApp=\(leftApp) right=\(right) rightApp=\(rightApp) ready=\(ready)"
            return ready
        }, evaluatedWith: app)
        let splitResult = XCTWaiter.wait(for: [splitReady], timeout: 10)
        print("SPLIT_LAYOUT result=\(splitResult.rawValue) samples=\(splitSamples) elapsed=\(Date().timeIntervalSince(splitStarted)) \(splitSample)")
        XCTAssertEqual(splitResult, .completed)
        for letter in ["g", "f", "n", "v"] {
            XCTAssertTrue(key(letter, in: app).isHittable)
            XCTAssertLessThan(key(letter, in: app).frame.midX, app.frame.midX)
        }
        for letter in ["y", "h", "o", "period"] {
            XCTAssertTrue(key(letter, in: app).isHittable)
            XCTAssertGreaterThan(key(letter, in: app).frame.midX, app.frame.midX)
        }
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: app.frame.width / 2, dy: key("h", in: app).frame.midY - app.frame.minY)).tap()
        assertText("Hi \n123.,q?H", in: field)
        tap(key("g", in: app))
        let rightCopy = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: key("h", in: app).frame.midX - (key("e", in: app).frame.midX - key("q", in: app).frame.midX) - app.frame.minX,
            dy: key("g", in: app).frame.midY - app.frame.minY))
        rightCopy.tap()
        assertText("Hi \n123.,q?Hgg", in: field)
        tap(key("q", in: app))
        assertText("Hi \n123.,q?Hggq", in: field)
        NSLog("HEX_POPUP_LANDSCAPE")
        coordinate(key("period", in: app), in: app).press(forDuration: 8)
        assertText("Hi \n123.,q?Hggq", in: field)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Keyboard in landscape"
        landscape.lifetime = .keepAlways
        add(landscape)
        let landscapeText = field.value as? String ?? ""
        let landscapeE = key("e", in: app).frame
        openPicker(in: app)
        let done = app.buttons["preset-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["preset-familiar"].isSelected)
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
        let repeatFrame = repeatKey.frame
        let motion = try XCTUnwrap(repeatDeleteMotion(keyHeight: Double(repeatFrame.height), tuning: probeTuning))
        let repeatAppFrame = app.frame
        let distance = CGFloat(motion.distance)
        XCTAssertTrue(repeatAppFrame.contains(CGPoint(x: repeatFrame.midX - distance, y: repeatFrame.midY)))
        let repeatStart = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: repeatFrame.midX - repeatAppFrame.minX, dy: repeatFrame.midY - repeatAppFrame.minY
        ))
        let repeatEnd = repeatStart.withOffset(CGVector(dx: -distance, dy: 0))
        print("REPEAT_DELETE startScreen=\(repeatStart.screenPoint) endScreen=\(repeatEnd.screenPoint) keyAXFrame=\(repeatFrame) distance=\(motion.distance) velocity=\(motion.velocity)")
        repeatStart.press(forDuration: 0.05, thenDragTo: repeatEnd,
                          withVelocity: XCUIGestureVelocity(rawValue: CGFloat(motion.velocity)), thenHoldForDuration: 0)
        let repeated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (field.value as? String ?? "").count <= beforeDelete - 2
        }, object: field)
        let repeatResult = XCTWaiter.wait(for: [repeated], timeout: 5)
        let afterDelete = (field.value as? String ?? "").count
        print("REPEAT_DELETE result=\(repeatResult.rawValue) beforeCount=\(beforeDelete) afterCount=\(afterDelete) deletedCount=\(beforeDelete - afterDelete)")
        XCTAssertEqual(repeatResult, .completed)
        XCUIDevice.shared.orientation = .portrait
    }

    private func gestureScale(keyHeight: Double) -> Double? {
        guard keyHeight.isFinite, keyHeight > 0 else { return nil }
        return keyHeight / (2 * HexGeometry().apothem)
    }

    private func repeatDeleteMotion(keyHeight: Double, tuning: KeyboardTuning) -> (distance: Double, velocity: Double)? {
        guard let scale = gestureScale(keyHeight: keyHeight) else { return nil }
        var machine = TouchMachine(geometry: HexGeometry())
        machine.tuning = tuning
        return ((tuning.swipeThreshold + 4 * machine.repeatDistance) * scale,
                machine.repeatDistance * scale)
    }

    private func trackpadMotion(keyHeight: Double, tuning: KeyboardTuning) -> (distance: Double, hold: TimeInterval)? {
        guard let scale = gestureScale(keyHeight: keyHeight) else { return nil }
        return (2.2 * tuning.trackpadUnitsPerCharacter * scale, max(1, 2 * tuning.holdMilliseconds / 1000))
    }

    func testRepeatDeleteMotionUsesScaledRepeatIntervals() throws {
        for (geometry, tuning) in gestureProbeConfigurations() {
            var machine = TouchMachine(geometry: geometry)
            machine.tuning = tuning
            let motion = try XCTUnwrap(repeatDeleteMotion(keyHeight: 2 * geometry.apothem, tuning: tuning))
            XCTAssertEqual(motion.distance, (tuning.swipeThreshold + 4 * machine.repeatDistance) * geometry.scale, accuracy: 1e-8)
            XCTAssertEqual(motion.velocity, machine.repeatDistance * geometry.scale, accuracy: 1e-8)
            let start = geometry.center(of: HexKey(slot: 18))
            XCTAssertGreaterThan(start.x - motion.distance, 0)
            machine.begin(1, at: start, time: 0)
            var actions: [KeyboardAction] = []
            for sample in 1...24 {
                actions += machine.move(1, to: HexPoint(x: start.x - motion.distance * Double(sample) / 24, y: start.y))
            }
            XCTAssertGreaterThanOrEqual(actions.filter { $0 == .delete }.count, 2)
        }
        for height in [0.0, -1.0, .infinity, .nan] {
            XCTAssertNil(repeatDeleteMotion(keyHeight: height, tuning: probeTuning))
        }
    }

    func testTrackpadMotionUsesScaledTuning() throws {
        for (geometry, tuning) in gestureProbeConfigurations() {
            let motion = try XCTUnwrap(trackpadMotion(keyHeight: 2 * geometry.apothem, tuning: tuning))
            XCTAssertEqual(motion.distance, 2.2 * tuning.trackpadUnitsPerCharacter * geometry.scale, accuracy: 1e-8)
            XCTAssertLessThan(motion.distance, tuning.swipeThreshold * geometry.scale)
            XCTAssertGreaterThan(motion.hold, tuning.holdMilliseconds / 1000)
            let start = geometry.center(of: HexKey(slot: 3))
            XCTAssertGreaterThan(start.x - motion.distance, 0)
            for direction in [-1.0, 1.0] {
                var machine = TouchMachine(geometry: geometry)
                machine.tuning = tuning
                machine.begin(1, at: start, time: 0)
                XCTAssertEqual(machine.advance(1, time: motion.hold), [])
                let end = HexPoint(x: start.x + direction * motion.distance, y: start.y)
                XCTAssertEqual(machine.move(1, to: end), [.moveCursor(graphemes: Int(direction) * 2)])
                XCTAssertEqual(machine.end(1, at: end, time: motion.hold), [])
                XCTAssertFalse(machine.isTrackpadActive)
            }
        }
        for height in [0.0, -1.0, .infinity, .nan] {
            XCTAssertNil(trackpadMotion(keyHeight: height, tuning: probeTuning))
        }
    }

    private func gestureProbeConfigurations() -> [(HexGeometry, KeyboardTuning)] {
        var configurations: [(HexGeometry, KeyboardTuning)] = []
        for (width, shorterSide, tablet) in [(390.0, 390.0, false), (844.0, 390.0, false),
                                            (1032.0, 1032.0, true), (1376.0, 1032.0, true)] {
            for splitScale in [0.25, 0.75, 1.0] {
                for customized in [false, true] {
                    var tuning = KeyboardTuning(tablet: tablet)
                    tuning[.splitKeyScale] = splitScale
                    if customized {
                        tuning[.swipeThreshold] = 120
                        tuning[.trackpadUnitsPerCharacter] = 50
                        tuning[.holdMilliseconds] = 600
                    }
                    let layout = HexLayout(containerWidth: width, shorterSide: shorterSide, tablet: tablet, tuning: tuning)
                    configurations.append((layout.geometry, tuning))
                }
            }
        }
        return configurations
    }

    private func openPicker(in app: XCUIApplication) {
        let layer = key("123", in: app)
        let start = coordinate(layer, in: app)
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(
            CGVector(dx: layer.frame.width * 0.8, dy: -layer.frame.height * 1.6)
        ))
        XCTAssertTrue(app.buttons["preset-done"].waitForExistence(timeout: 5), app.debugDescription)
    }

    private func pasteEmoji(into field: XCUIElement, in app: XCUIApplication) {
        UIPasteboard.general.string = "👩‍💻"
        field.press(forDuration: 1)
        let paste = app.descendants(matching: .any)["Paste"].firstMatch
        XCTAssertTrue(paste.waitForExistence(timeout: 5), app.debugDescription)
        coordinate(paste, in: app).tap()
        let allow = app.alerts.buttons["Allow Paste"].firstMatch
        let ready = expectation(for: NSPredicate { _, _ in
            field.value as? String == "👩‍💻" || allow.exists
        }, evaluatedWith: field)
        wait(for: [ready], timeout: 5)
        if allow.exists { allow.tap() }
        assertText("👩‍💻", in: field)
    }

    private func moveCursorFromLayerKey(direction: CGFloat, in app: XCUIApplication) throws {
        let layer = key("123", in: app)
        let frame = layer.frame
        let motion = try XCTUnwrap(trackpadMotion(keyHeight: Double(frame.height), tuning: probeTuning))
        let appFrame = app.frame
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: frame.midX - appFrame.minX, dy: frame.midY - appFrame.minY
        ))
        start.press(forDuration: motion.hold, thenDragTo: start.withOffset(
            CGVector(dx: direction * CGFloat(motion.distance), dy: 0)
        ))
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
            print("KEYBOARD_SELECTION introduction visible")
            let button = app.buttons["Continue"].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
            print("KEYBOARD_SELECTION introduction dismissed")
        }
    }

    private func nativeKeyboardSwitcherPredicate() -> NSPredicate {
        NSPredicate(format: "label IN %@", ["Next keyboard", "Emoji"])
    }

    private func keyboardInputIsReady(native: @autoclosure () -> Bool, custom: @autoclosure () -> Bool) -> Bool {
        native() || custom()
    }

    func testKeyboardInputReadinessChecksNativeFirstAndShortCircuits() {
        for native in [false, true] {
            for custom in [false, true] {
                var queries: [String] = []
                func query(_ name: String, ready: Bool) -> Bool {
                    queries.append(name)
                    return ready
                }
                XCTAssertEqual(keyboardInputIsReady(native: query("native", ready: native),
                                                    custom: query("custom", ready: custom)), native || custom)
                XCTAssertEqual(queries, native ? ["native"] : ["native", "custom"])
            }
        }
    }

    func testNativeKeyboardSwitcherLabelsIgnorePresentationValue() {
        let predicate = nativeKeyboardSwitcherPredicate()
        for value in ["Keyboard", "Emoji", "0"] {
            XCTAssertTrue(predicate.evaluate(with: ["label": "Emoji", "value": value]))
        }
        XCTAssertTrue(predicate.evaluate(with: ["label": "Emoji"]))
        XCTAssertTrue(predicate.evaluate(with: ["label": "Next keyboard"]))
        XCTAssertFalse(predicate.evaluate(with: ["label": "Continue", "value": "Keyboard"]))
        XCTAssertFalse(predicate.evaluate(with: ["label": ""]))
        XCTAssertFalse(predicate.evaluate(with: [:] as [String: String]))
    }

    private func selectKeyboardExtension(in app: XCUIApplication) {
        for cycle in 0..<5 {
            print("KEYBOARD_SELECTION cycle=\(cycle)")
            dismissSystemKeyboardIntroduction(in: app)
            let first = key("q", in: app)
            let keysReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.isOnScreen(first, in: app)
            }, object: first)
            if XCTWaiter.wait(for: [keysReady], timeout: 15) == .completed {
                print("KEYBOARD_SELECTION extension ready")
                return
            }
            print("KEYBOARD_SELECTION extension unavailable")
            let globe = app.buttons.matching(nativeKeyboardSwitcherPredicate()).firstMatch
            let inputReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.keyboardInputIsReady(native: self.isOnScreen(globe, in: app),
                                          custom: self.isOnScreen(first, in: app))
            }, object: app)
            let result = XCTWaiter.wait(for: [inputReady], timeout: 15)
            if result != .completed {
                print("KEYBOARD_SELECTION failed appState=\(app.state.rawValue) appFrame=\(app.frame) globeExists=\(globe.exists)")
                if globe.exists { print("KEYBOARD_SELECTION matched globeFrame=\(globe.frame)") }
                let nativeButtons = app.buttons.matching(NSPredicate(format: "label IN %@", ["Next keyboard", "Emoji", "ABC"]))
                for button in nativeButtons.allElementsBoundByIndex.prefix(8) {
                    let value = button.value as? String
                    let valueClass = value == "Keyboard" ? "Keyboard" : value == nil ? "nil" : value == "" ? "empty" : "other"
                    print("KEYBOARD_SELECTION native label=\(button.label) valueClass=\(valueClass) frame=\(button.frame) onScreen=\(isOnScreen(button, in: app))")
                }
                for (name, application) in [("host", app), ("springboard", XCUIApplication(bundleIdentifier: "com.apple.springboard"))] {
                    print("KEYBOARD_SELECTION \(name) BEGIN")
                    for line in selectionHierarchy(application.debugDescription).components(separatedBy: .newlines) {
                        print("KEYBOARD_SELECTION \(line)")
                    }
                    print("KEYBOARD_SELECTION \(name) END")
                }
            }
            XCTAssertEqual(result, .completed, "Keyboard selection state is in KEYBOARD_SELECTION diagnostics")
            if isOnScreen(first, in: app) { return }
            // Native iPad keyboard elements can have valid frames but invalid AX hit points.
            coordinate(globe, in: app).tap()
            print("KEYBOARD_SELECTION globe tapped")
        }
    }

    private func selectionHierarchy(_ description: String) -> String {
        let node = try! NSRegularExpression(pattern: "^([ \\t]*)(?:→\\s*)?([A-Za-z]+), 0x[0-9a-fA-F]+")
        let frame = try! NSRegularExpression(pattern: "\\{\\{[-+0-9.eEinfNa, ]+\\}, \\{[-+0-9.eEinfNa, ]+\\}\\}")
        let attribute = try! NSRegularExpression(pattern: ", (identifier|label): '([^'\\n]*)'")
        let labels: Set<String> = ["Keyboard Host", "Next keyboard", "Emoji", "Keyboard", "English", "English (US)",
                                   "Quickly Change Keyboards", "Continue", "Not Now", "Done", "Cancel", "Dictation",
                                   "Show Keyboard", "Hide Keyboard", "123", "ABC", "q", "AutoFill", "Paste",
                                   "Keyboard Settings…", "Keyboard Settings..."]
        let identifiers: Set<String> = ["keyboard-sample", "key-q", "UIContinuousPathIntroductionView"]
        var output = ""
        var count = 0
        var truncated = false
        var relevant: [String] = []
        for rawLine in description.components(separatedBy: .newlines) {
            let line = rawLine.components(separatedBy: ", value:")[0]
            let range = NSRange(line.startIndex..., in: line)
            guard let match = node.firstMatch(in: line, range: range),
                  let indentation = Range(match.range(at: 1), in: line),
                  let type = Range(match.range(at: 2), in: line) else { continue }
            var summary = String(repeating: " ", count: min(line[indentation].count, 20)) + line[type]
            var isRelevant = false
            if let match = frame.firstMatch(in: line, range: range), let bounds = Range(match.range, in: line) {
                summary += " " + line[bounds]
            }
            for match in attribute.matches(in: line, range: range) {
                guard let kind = Range(match.range(at: 1), in: line),
                      let value = Range(match.range(at: 2), in: line) else { continue }
                let allowed = line[kind] == "label" ? labels : identifiers
                if allowed.contains(String(line[value])) {
                    summary += " \(line[kind])=\(line[value])"
                    isRelevant = true
                }
            }
            if isRelevant {
                relevant.append(summary)
                if relevant.count > 30 { relevant.removeFirst() }
            }
            guard count < 160, output.count + summary.count + 1 < 16_000 else {
                truncated = true
                continue
            }
            output += summary + "\n"
            count += 1
        }
        if truncated {
            output += "[truncated]\nRelevant controls:\n"
            for summary in relevant {
                guard output.count + summary.count + 1 < 19_980 else { break }
                output += summary + "\n"
            }
        }
        return output.isEmpty ? "[no accessible nodes]" : output
    }

    func testSelectionHierarchyRedactsInputAndBoundsOutput() {
        let hierarchy = """
        Element subtree:
         →Application, 0xabc, pid: 123, label: 'Keyboard Host'
            TextView, 0xdef, {{1.0, 2.0}, {100.0, 50.0}}, identifier: 'keyboard-sample', value: 'private-input-fixture
        private-input-continuation'
            Button, 0x123, {{4.0, 5.0}, {20.0, 30.0}}, label: 'Next keyboard', value: 'private-button-value'
            StaticText, 0x456, label: 'private-suggestion'
        """
        let summary = selectionHierarchy(hierarchy)
        XCTAssertTrue(summary.contains("label=Next keyboard"))
        XCTAssertTrue(summary.contains("identifier=keyboard-sample"))
        XCTAssertTrue(summary.contains("{{1.0, 2.0}, {100.0, 50.0}}"))
        XCTAssertFalse(summary.contains("private-"))
        XCTAssertFalse(summary.contains("value"))
        let valueWithAttributes = selectionHierarchy("TextView, 0xabc, value: '{{98765.0, 2.0}, {3.0, 4.0}}, label: 'Continue''")
        XCTAssertFalse(valueWithAttributes.contains("98765"))
        XCTAssertFalse(valueWithAttributes.contains("Continue"))
        XCTAssertEqual(selectionHierarchy(""), "[no accessible nodes]")
        XCTAssertEqual(selectionHierarchy("malformed input"), "[no accessible nodes]")
        let bounded = selectionHierarchy(String(repeating: hierarchy, count: 500))
        XCTAssertTrue(bounded.contains("[truncated]"))
        XCTAssertLessThanOrEqual(bounded.count, 20_000)
        XCTAssertLessThanOrEqual(bounded.components(separatedBy: .newlines).count, 202)
        let lateControl = selectionHierarchy(String(repeating: " Other, 0xabc\n", count: 500)
                                            + " Button, 0xdef, label: 'Continue'")
        XCTAssertTrue(lateControl.contains("label=Continue"))
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
