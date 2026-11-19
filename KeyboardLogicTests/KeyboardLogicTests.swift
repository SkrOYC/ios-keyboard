import XCTest

final class KeyboardLogicTests: XCTestCase {
    let geometry = HexGeometry()

    private struct Fixture: Decodable {
        struct Key: Decodable {
            let slot: Int
            let center: HexPoint
            let polygon: [HexPoint]
            let isDuplicate: Bool?
        }
        let keys: [Key]
        struct SplitCase: Decodable {
            let containerWidth: Double
            let leadingInset: Double
            let trailingInset: Double
            let shorterSide: Double
            let tablet: Bool
            let splitKeyScale: Double
            let heightBudget: Double
            let width: Double
            let height: Double
            let scale: Double
            let keys: [Key]
        }
        let splitCases: [SplitCase]
    }

    func testSplitPlacementsMatchIndependentFixture() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "geometry", withExtension: "json"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        XCTAssertEqual(fixture.splitCases.count, 4)
        for sample in fixture.splitCases {
            var tuning = KeyboardTuning(tablet: sample.tablet)
            tuning.layoutMode = .split
            tuning[.splitKeyScale] = sample.splitKeyScale
            tuning[.heightBudget] = sample.heightBudget
            let layout = HexLayout(containerWidth: sample.containerWidth, leadingInset: sample.leadingInset,
                                   trailingInset: sample.trailingInset, shorterSide: sample.shorterSide,
                                   tablet: sample.tablet, tuning: tuning)
            let g = layout.geometry
            XCTAssertEqual(g.scale, sample.scale, accuracy: 1e-8)
            XCTAssertEqual(g.width, sample.width, accuracy: 1e-8)
            XCTAssertEqual(g.height, sample.height, accuracy: 1e-8)
            XCTAssertEqual(g.placedKeys.count, sample.keys.count)
            for (actual, expected) in zip(g.placedKeys, sample.keys) {
                XCTAssertEqual(actual.slot, expected.slot)
                XCTAssertEqual(actual.isDuplicate, expected.isDuplicate)
                XCTAssertEqual(actual.center.x, expected.center.x, accuracy: 1e-8)
                XCTAssertEqual(actual.center.y, expected.center.y, accuracy: 1e-8)
                XCTAssertEqual(g.key(at: actual.center), actual.key)
                for (point, expected) in zip(actual.polygon, expected.polygon) {
                    XCTAssertEqual(point.x, expected.x, accuracy: 1e-8)
                    XCTAssertEqual(point.y, expected.y, accuracy: 1e-8)
                }
            }
        }
    }

    func testEveryCenterAndPolygonMatchesIndependentFixture() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "geometry", withExtension: "json"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        XCTAssertEqual(fixture.keys.count, 28)
        for expected in fixture.keys {
            let key = HexKey(slot: expected.slot)
            let actual = geometry.center(of: key)
            XCTAssertEqual(actual.x, expected.center.x, accuracy: 1e-8)
            XCTAssertEqual(actual.y, expected.center.y, accuracy: 1e-8)
            let polygon = geometry.polygon(of: key)
            XCTAssertEqual(polygon.count, 6)
            XCTAssertEqual(polygon.count, expected.polygon.count)
            for (actual, expected) in zip(polygon, expected.polygon) {
                XCTAssertEqual(actual.x, expected.x, accuracy: 1e-8)
                XCTAssertEqual(actual.y, expected.y, accuracy: 1e-8)
            }
        }
    }

    func testCentersHitTheirOwnKeysAndGapsStayDead() {
        for key in geometry.keys { XCTAssertEqual(geometry.key(at: geometry.center(of: key)), key) }
        let a = geometry.center(of: HexKey(slot: 0))
        let b = geometry.center(of: HexKey(slot: 1))
        XCTAssertNil(geometry.key(at: HexPoint(x: a.x, y: (a.y + b.y) / 2)))
        XCTAssertNil(geometry.key(at: HexPoint(x: 0, y: 0)))
        XCTAssertNil(geometry.key(at: HexPoint(x: -1, y: -1)))
    }

    func testResponsiveGeometryRemainsInsideBounds() {
        for (width, height) in [(390.0, 883.0 * 390 / 1320), (820, 180), (700, 300)] {
            let g = HexGeometry(width: width, height: height)
            for key in g.keys {
                XCTAssertEqual(g.key(at: g.center(of: key)), key)
                for p in g.polygon(of: key) {
                    XCTAssertGreaterThanOrEqual(p.x, 0)
                    XCTAssertLessThanOrEqual(p.x, width)
                    XCTAssertGreaterThanOrEqual(p.y, 0)
                    XCTAssertLessThanOrEqual(p.y, height)
                }
            }
        }
    }

    func testOrdersAndSymbolPhoneKeypad() {
        for order in LetterOrder.allCases {
            XCTAssertEqual(Set(order.letters), Set("abcdefghijklmnopqrstuvwxyz"))
            XCTAssertEqual(order.letters.count, 26)
        }
        XCTAssertEqual([8, 12, 16].map { keyLabel(HexKey(slot: $0), layer: .symbols, order: .familiar) }, ["1", "2", "3"])
        XCTAssertEqual([9, 13, 17].map { keyLabel(HexKey(slot: $0), layer: .symbols, order: .familiar) }, ["4", "5", "6"])
        XCTAssertEqual([10, 14, 18].map { keyLabel(HexKey(slot: $0), layer: .symbols, order: .familiar) }, ["7", "8", "9"])
        XCTAssertEqual([11, 15, 19].map { keyLabel(HexKey(slot: $0), layer: .symbols, order: .familiar) }, ["*", "0", "#"])
    }

    func testTapUsesReleaseKeyAndGapReleaseDoesNothing() {
        var machine = TouchMachine(geometry: geometry)
        let start = geometry.center(of: HexKey(slot: 0))
        machine.begin(1, at: start, time: 0)
        XCTAssertEqual(machine.end(1, at: start, time: 0.1), [.insert("w")])
        let gap = HexPoint(x: start.x, y: start.y + geometry.apothem + 4)
        machine.begin(2, at: gap, time: 0)
        XCTAssertEqual(machine.end(2, at: gap, time: 0.1), [])
        // A short slide from the gap onto a key taps the key under the finger.
        machine.begin(3, at: gap, time: 0)
        let edge = HexPoint(x: start.x, y: start.y + geometry.apothem - 4)
        XCTAssertEqual(machine.end(3, at: edge, time: 0.1), [.insert("w")])
    }

    func testSwipeThresholdDominantAxisAndCancellationOfTap() {
        for (dx, dy, expected) in [(70.0, 0.0, [KeyboardAction.insert(" ")]),
                                    (0, 70, [.insert("\n")]), (-70, 0, [.delete]), (0, -70, [.insert("W")]),
                                    (70, -70, [.insert(" ")])] {
            var m = TouchMachine(geometry: geometry)
            let p = geometry.center(of: HexKey(slot: 0))
            m.begin(1, at: p, time: 0)
            let end = HexPoint(x: p.x + dx, y: p.y + dy)
            XCTAssertEqual(m.move(1, to: end), expected)
            XCTAssertEqual(m.end(1, at: end, time: 0.2), [])
        }
    }

    func testSubthresholdMovementStillTapsAndThresholdScalesToPoints() {
        let g = HexGeometry(width: 390, height: 883 * 390 / 1320)
        var m = TouchMachine(geometry: g)
        let p = g.center(of: HexKey(slot: 0))
        m.begin(1, at: p, time: 0)
        XCTAssertEqual(m.move(1, to: HexPoint(x: p.x + 20, y: p.y)), [])
        XCTAssertEqual(m.move(1, to: HexPoint(x: p.x + 21, y: p.y)), [.insert(" ")])
    }

    func testCapitalizeUsesStartLetterAndIgnoresUtilitiesSymbolsAndGaps() {
        for slot in [27] {
            var m = TouchMachine(geometry: geometry)
            let p = geometry.center(of: HexKey(slot: slot))
            m.begin(1, at: p, time: 0)
            XCTAssertEqual(m.end(1, at: HexPoint(x: p.x, y: p.y - 80), time: 0.1), [])
        }
        var m = TouchMachine(geometry: geometry)
        m.layer = .symbols
        let p = geometry.center(of: HexKey(slot: 0))
        m.begin(1, at: p, time: 0)
        XCTAssertEqual(m.end(1, at: HexPoint(x: p.x, y: p.y - 80), time: 0.1), [])
        m.begin(2, at: HexPoint(x: 0, y: 0), time: 0)
        XCTAssertEqual(m.end(2, at: HexPoint(x: 0, y: -80), time: 0.1), [])
    }

    func testDeleteRepeatsForTravelAndDoesNotRepeatOnReversal() {
        var m = TouchMachine(geometry: geometry)
        let p = geometry.center(of: HexKey(slot: 16))
        m.begin(1, at: p, time: 0)
        XCTAssertEqual(m.move(1, to: HexPoint(x: p.x - 70, y: p.y)), [.delete])
        XCTAssertEqual(m.move(1, to: HexPoint(x: p.x - 196, y: p.y)), [.delete, .delete])
        XCTAssertEqual(m.move(1, to: HexPoint(x: p.x - 100, y: p.y)), [])
        XCTAssertEqual(m.move(1, to: HexPoint(x: p.x - 196, y: p.y)), [])
        XCTAssertEqual(m.move(1, to: HexPoint(x: p.x - 259, y: p.y)), [.delete])
    }

    func testOverlappingTouchesStayIndependentAndCancellationDoesNotType() {
        var m = TouchMachine(geometry: geometry)
        let left = geometry.center(of: HexKey(slot: 0))
        let right = geometry.center(of: HexKey(slot: 26))
        m.begin(1, at: left, time: 0)
        m.begin(2, at: right, time: 0.01)
        XCTAssertEqual(m.move(1, to: HexPoint(x: left.x, y: left.y - 70)), [.insert("W")])
        XCTAssertEqual(m.end(2, at: right, time: 0.1), [.insert("k")])
        m.cancel(1)
        XCTAssertTrue(m.contacts.isEmpty)
        XCTAssertEqual(m.end(1, at: left, time: 1), [])
    }

    func testLayerToggleAndPeriodOnBothLayers() {
        var m = TouchMachine(geometry: geometry)
        for expected in [KeyboardLayer.symbols, .letters] {
            let p = geometry.center(of: HexKey(slot: 3))
            m.begin(1, at: p, time: 0)
            XCTAssertEqual(m.end(1, at: p, time: 0.1), [])
            XCTAssertEqual(m.layer, expected)
            let period = geometry.center(of: HexKey(slot: 27))
            m.begin(2, at: period, time: 0)
            XCTAssertEqual(m.end(2, at: period, time: 0.1), [.insert(".")])
        }
    }

    func testPopupTimingSelectionGlobeAndCancellation() {
        for globe in [false, true] {
            var m = TouchMachine(geometry: geometry)
            m.needsGlobe = globe
            let p = geometry.center(of: HexKey(slot: 27))
            m.begin(1, at: p, time: 0)
            XCTAssertEqual(m.advance(1, time: 0.419), [])
            XCTAssertNil(m.contacts[1]?.popup)
            XCTAssertEqual(m.advance(1, time: 0.420), [])
            let popup = m.contacts[1]!.popup!
            XCTAssertEqual(popup.entries.count, globe ? 5 : 4)
            let last = popup.entries.last!
            XCTAssertEqual(m.end(1, at: last.center, time: 0.5), globe ? [.nextKeyboard] : [.insert("'")])
            m.begin(2, at: p, time: 1)
            XCTAssertEqual(m.end(2, at: p, time: 1.5), [])
        }
    }

    func testHoldMovementAndTouchCancellationSuppressPopup() {
        var m = TouchMachine(geometry: geometry)
        let p = geometry.center(of: HexKey(slot: 27))
        m.begin(1, at: p, time: 0)
        XCTAssertEqual(m.move(1, to: HexPoint(x: p.x - 11, y: p.y)), [])
        XCTAssertEqual(m.advance(1, time: 1), [])
        XCTAssertNil(m.contacts[1]?.popup)
        m.cancel(1)
        XCTAssertEqual(m.end(1, at: p, time: 2), [])
    }

    func testTrackpadHoldConsumesTapWithoutChangingLayer() {
        var m = TouchMachine(geometry: geometry)
        let p = geometry.center(of: HexKey(slot: 3))
        m.begin(1, at: p, time: 0)
        XCTAssertEqual(m.advance(1, time: 0.42), [])
        XCTAssertTrue(m.isTrackpadActive)
        XCTAssertEqual(m.end(1, at: p, time: 0.5), [])
        XCTAssertEqual(m.layer, .letters)
        XCTAssertFalse(m.isTrackpadActive)
    }
}
