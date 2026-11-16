import XCTest

final class GestureReleaseTests: XCTestCase {
    func testReleaseMovementTakesPrecedenceOverInferredHold() {
        let geometry = HexGeometry()
        var machine = TouchMachine(geometry: geometry)
        let period = geometry.center(of: HexKey(slot: 27))
        machine.begin(1, at: period, time: 0)
        // A final position still counts if no intermediate movement callback arrives.
        let end = HexPoint(x: period.x - 70, y: period.y)
        XCTAssertEqual(machine.end(1, at: end, time: 1), [.delete])
        XCTAssertTrue(machine.contacts.isEmpty)
    }
}
