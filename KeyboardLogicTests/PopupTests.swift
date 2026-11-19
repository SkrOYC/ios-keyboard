import XCTest

final class PopupTests: XCTestCase {
    func testEveryPopupChoiceAndClamping() {
        let geometry = HexGeometry()
        let popup = PopupModel(geometry: geometry, includesGlobe: true)
        for entry in popup.entries {
            XCTAssertEqual(popup.selection(at: entry.center), entry.choice)
            let outside = HexPoint(x: entry.center.x, y: entry.center.y - 10000)
            XCTAssertEqual(popup.selection(at: outside), entry.choice)
        }
        XCTAssertEqual(popup.selection(at: HexPoint(x: -10000, y: -10000)), .nextKeyboard)
        XCTAssertEqual(popup.selection(at: HexPoint(x: 10000, y: 10000)), .punctuation(","))
    }

    func testCancelSlopBothAxesAndSmallFlick() {
        let origin = HexPoint(x: 300, y: 200)
        let popup = PopupModel(geometry: HexGeometry(), includesGlobe: false, origin: origin)
        for (dx, dy) in [(0.0, 0.0), (10, 10), (-10, -10), (10, -10)] {
            XCTAssertNil(popup.selectedIndex(at: HexPoint(x: origin.x + dx, y: origin.y + dy)))
        }
        for (dx, dy) in [(11.0, 0.0), (-11, 0), (0, 11), (0, -11)] {
            XCTAssertEqual(popup.selectedIndex(at: HexPoint(x: origin.x + dx, y: origin.y + dy)), 0)
        }
    }

    func testRowsAndIncompleteRowAndEmptyGrid() {
        let origin = HexPoint(x: 0, y: 0)
        let choices = [",", "?", "!", "'", ";"].map { PopupChoice.punctuation($0) }
        let popup = PopupModel(choices: choices, columns: 3, anchor: origin, origin: origin,
                               cellWidth: 100, cellHeight: 80, inwardSign: 1, cancelSlop: 10)
        XCTAssertEqual(popup.rows, 2)
        XCTAssertEqual(popup.selectedIndex(at: HexPoint(x: 100, y: -160)), 4)
        XCTAssertEqual(popup.selectedIndex(at: HexPoint(x: 10000, y: -10000)), 4)
        XCTAssertEqual(popup.selectedIndex(at: HexPoint(x: -10000, y: -10000)), 3)
        XCTAssertEqual(popup.entries[4].rect.width, 100)
        XCTAssertEqual(popup.entries[4].rect.height, 80)
        let empty = PopupModel(choices: [], columns: 1, anchor: origin, origin: origin,
                               cellWidth: 100, cellHeight: 80, inwardSign: 1, cancelSlop: 10)
        XCTAssertNil(empty.selection(at: HexPoint(x: 100, y: -100)))
    }

    func testPopupAndAnotherThumbRemainIndependentAndCancelDoesNotInsert() {
        let geometry = HexGeometry()
        var machine = TouchMachine(geometry: geometry)
        machine.begin(1, at: geometry.center(of: HexKey(slot: 27)), time: 0)
        XCTAssertEqual(machine.advance(1, time: 0.42), [])
        let popupPoint = machine.contacts[1]!.popup!.entries[0].center
        let letter = geometry.center(of: HexKey(slot: 18))
        machine.begin(2, at: letter, time: 0.43)
        XCTAssertEqual(machine.end(2, at: letter, time: 0.5), [.insert("h")])
        XCTAssertNotNil(machine.contacts[1]?.popup)
        machine.cancel(1)
        XCTAssertEqual(machine.end(1, at: popupPoint, time: 0.6), [])
    }
}
