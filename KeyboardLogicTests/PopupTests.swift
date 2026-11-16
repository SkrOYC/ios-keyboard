import XCTest

final class PopupTests: XCTestCase {
    func testEveryPopupChoiceAndOutsideRadius() {
        let geometry = HexGeometry()
        let popup = PopupModel(geometry: geometry, includesGlobe: true)
        for entry in popup.entries {
            XCTAssertEqual(popup.selection(at: entry.center), entry.choice)
            let outside = HexPoint(x: entry.center.x, y: entry.center.y - 1.1 * popup.apothem - 1)
            XCTAssertNil(popup.selection(at: outside))
        }
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
