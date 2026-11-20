import XCTest

final class GestureReleaseTests: XCTestCase {
    func testRepeatNeedsTravelAfterTheFirstDeliveredDelete() {
        for (width, height) in [(820.0, 180.0), (700.0, 300.0)] {
            let geometry = HexGeometry(width: width, height: height)
            let start = geometry.center(of: HexKey(slot: 18))
            let travel = 2.2 * 2 * geometry.radius
            let end = HexPoint(x: start.x - travel, y: start.y)
            for duration in [0.05, 1.0] {
                var machine = TouchMachine(geometry: geometry)
                XCTAssertGreaterThan(travel, (TouchMachine.threshold + TouchMachine.repeatDistance) * machine.scale)
                machine.begin(1, at: start, time: 0)
                XCTAssertEqual(machine.advance(1, time: duration), [])
                XCTAssertEqual(machine.end(1, at: end, time: duration), [.delete])
            }
        }
    }

    func testRepeatProcessesFurtherDeliveredTravelWithoutAHold() {
        var machine = TouchMachine(geometry: HexGeometry())
        let start = machine.geometry.center(of: HexKey(slot: 18))
        machine.begin(1, at: start, time: 0)
        let first = HexPoint(x: start.x - TouchMachine.threshold, y: start.y)
        XCTAssertEqual(machine.move(1, to: first), [.delete])
        let end = HexPoint(x: first.x - 2 * TouchMachine.repeatDistance, y: first.y)
        XCTAssertEqual(machine.end(1, at: end, time: 0.05), [.delete, .delete])
        XCTAssertTrue(machine.contacts.isEmpty)
    }

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
