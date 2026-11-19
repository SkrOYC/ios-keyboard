import XCTest

final class ModeGestureTests: XCTestCase {
    private func flick(_ machine: inout TouchMachine) -> [KeyboardAction] {
        let p = machine.geometry.center(of: HexKey(slot: 3))
        machine.begin(1, at: p, time: 0)
        let end = HexPoint(x: p.x,
                           y: p.y - machine.tuning.swipeThreshold * machine.scale)
        return machine.end(1, at: end, time: 0.1)
    }

    func testModeSwipeOpensCapsAndPresetsAndCanCancel() {
        var m = TouchMachine(geometry: HexGeometry())
        let p = m.geometry.center(of: HexKey(slot: 3))
        m.begin(1, at: p, time: 0)
        XCTAssertEqual(m.move(1, to: HexPoint(x: p.x, y: p.y - 70)), [])
        XCTAssertEqual(m.contacts[1]?.popup?.entries.map(\.choice), [.capsLock, .presets])
        XCTAssertEqual(m.end(1, at: p, time: 0.2), [])
        XCTAssertFalse(m.capsLock)
        // Open vertically before travelling inward so the gesture stays up.
        m.begin(2, at: p, time: 0)
        XCTAssertEqual(m.move(2, to: HexPoint(x: p.x, y: p.y - 70)), [])
        let second = m.contacts[2]!.popup!.entries[1].center
        XCTAssertEqual(m.end(2, at: second, time: 0.2), [.showPicker])
        XCTAssertEqual(m.layer, .letters)
    }

    func testCapsToggleTapSwipeLabelsSymbolsAndReset() {
        var m = TouchMachine(geometry: HexGeometry())
        XCTAssertEqual(flick(&m), [])
        XCTAssertTrue(m.capsLock)
        let key = HexKey(slot: 0)
        let p = m.geometry.center(of: key)
        XCTAssertEqual(keyLabel(key, layer: .letters, order: .familiar, capsLock: m.capsLock), "W")
        m.begin(2, at: p, time: 0)
        XCTAssertEqual(m.end(2, at: p, time: 0.1), [.insert("W")])
        m.begin(2, at: p, time: 0)
        XCTAssertEqual(m.end(2, at: HexPoint(x: p.x, y: p.y - 70), time: 0.1), [.insert("W")])
        m.layer = .symbols
        m.begin(2, at: p, time: 0)
        XCTAssertEqual(m.end(2, at: p, time: 0.1), [.insert("(")])
        XCTAssertEqual(flick(&m), [])
        XCTAssertFalse(m.capsLock)
        XCTAssertEqual(flick(&m), [])
        m.resetCapsLock()
        XCTAssertFalse(m.capsLock)
        m.layer = .letters
        m.begin(2, at: p, time: 0)
        XCTAssertEqual(m.end(2, at: HexPoint(x: p.x, y: p.y - 70), time: 0.1), [.insert("W")])
    }

    func testTrackpadStepsReversalVerticalIgnoredAndCancel() {
        var m = TouchMachine(geometry: HexGeometry())
        let p = m.geometry.center(of: HexKey(slot: 3))
        m.begin(1, at: p, time: 0)
        XCTAssertEqual(m.advance(1, time: 0.42), [])
        XCTAssertTrue(m.isTrackpadActive)
        XCTAssertEqual(m.move(1, to: HexPoint(x: p.x + 10, y: p.y - 200)), [])
        XCTAssertEqual(m.move(1, to: HexPoint(x: p.x + 30, y: p.y)), [.moveCursor(graphemes: 1)])
        XCTAssertEqual(m.move(1, to: HexPoint(x: p.x + 95, y: p.y)), [.moveCursor(graphemes: 2)])
        XCTAssertEqual(m.move(1, to: HexPoint(x: p.x - 31, y: p.y)), [.moveCursor(graphemes: -4)])
        XCTAssertEqual(m.end(1, at: HexPoint(x: p.x - 31, y: p.y), time: 1), [])
        XCTAssertFalse(m.isTrackpadActive)
        m.begin(2, at: p, time: 0)
        XCTAssertEqual(m.advance(2, time: 0.42), [])
        m.cancelAll()
        XCTAssertFalse(m.isTrackpadActive)
        XCTAssertEqual(m.end(2, at: p, time: 1), [])
    }

    func testTrackpadProbeTravelAcrossUnifiedAndSplitScales() {
        for width in [390.0, 1032, 1376] {
            for splitScale in [0.25, 0.75, 1.0] {
                var tuning = KeyboardTuning(tablet: width >= 600)
                tuning[.splitKeyScale] = splitScale
                let layout = HexLayout(containerWidth: width, shorterSide: min(width, 1032),
                                       tablet: width >= 600, tuning: tuning)
                let g = layout.geometry
                let p = g.center(of: HexKey(slot: 3))
                let travel = 2 * g.apothem * 0.36
                let step = tuning.trackpadUnitsPerCharacter * g.scale
                XCTAssertGreaterThan(travel, 2 * step)
                XCTAssertLessThan(travel, 3 * step)
                XCTAssertLessThan(travel, tuning.swipeThreshold * g.scale)
                XCTAssertGreaterThan(p.x - travel, 0)
                for direction in [-1.0, 1] {
                    var m = TouchMachine(geometry: g)
                    m.tuning = tuning
                    m.begin(1, at: p, time: 0)
                    XCTAssertEqual(m.advance(1, time: tuning.holdMilliseconds / 1000), [])
                    let end = HexPoint(x: p.x + direction * travel, y: p.y)
                    XCTAssertEqual(m.move(1, to: end), [.moveCursor(graphemes: Int(direction) * 2)])
                    XCTAssertEqual(m.end(1, at: end, time: 1), [])
                    XCTAssertFalse(m.isTrackpadActive)
                }

                var pendingHold = TouchMachine(geometry: g)
                pendingHold.tuning = tuning
                pendingHold.begin(1, at: p, time: 0)
                XCTAssertEqual(pendingHold.move(1, to: HexPoint(x: p.x - 2 * g.apothem * 0.4, y: p.y)), [.delete])
            }
        }
    }

    func testTuningScalesHoldSlopSwipeAndTrackpad() {
        let g = HexGeometry(width: 660, height: 441.5)
        var m = TouchMachine(geometry: g)
        m.tuning[.holdMilliseconds] = 600
        m.tuning[.cancelSlop] = 20
        m.tuning[.trackpadUnitsPerCharacter] = 40
        m.tuning[.swipeThreshold] = 100
        let p = g.center(of: HexKey(slot: 3))
        m.begin(1, at: p, time: 0)
        XCTAssertEqual(m.move(1, to: HexPoint(x: p.x + 9, y: p.y + 9)), [])
        XCTAssertEqual(m.advance(1, time: 0.599), [])
        XCTAssertFalse(m.isTrackpadActive)
        XCTAssertEqual(m.advance(1, time: 0.6), [])
        XCTAssertTrue(m.isTrackpadActive)
        XCTAssertEqual(m.move(1, to: HexPoint(x: p.x + 29, y: p.y)), [.moveCursor(graphemes: 1)])
        m.cancelAll()
        m.begin(2, at: p, time: 0)
        XCTAssertEqual(m.move(2, to: HexPoint(x: p.x, y: p.y - 49)), [])
        XCTAssertNil(m.contacts[2]?.popup)
        XCTAssertEqual(m.move(2, to: HexPoint(x: p.x, y: p.y - 50)), [])
        XCTAssertNotNil(m.contacts[2]?.popup)
    }

    func testUTF16OffsetsPreserveEmojiZWJFlagsAndFallback() {
        let samples = ["a", "😀", "👩🏽‍💻", "🇫🇷", "e\u{301}"]
        let text = samples.joined()
        for count in 1...samples.count {
            XCTAssertEqual(cursorUTF16Offset(graphemes: count, before: nil, after: text),
                           samples.prefix(count).joined().utf16.count)
            XCTAssertEqual(cursorUTF16Offset(graphemes: -count, before: text, after: nil),
                           -samples.suffix(count).joined().utf16.count)
        }
        XCTAssertEqual(cursorUTF16Offset(graphemes: 0, before: nil, after: nil), 0)
        XCTAssertEqual(cursorUTF16Offset(graphemes: -3, before: nil, after: nil), -3)
        XCTAssertEqual(cursorUTF16Offset(graphemes: 2, before: nil, after: ""), 2)
        XCTAssertEqual(cursorUTF16Offset(graphemes: -2, before: "😀", after: nil), -3)
    }
}
