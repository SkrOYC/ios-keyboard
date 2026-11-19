import XCTest

final class HexLayoutTests: XCTestCase {
    func testPortraitMatchesDesignScale() {
        let layout = HexLayout(containerWidth: 390, shorterSide: 390, tablet: false)
        XCTAssertEqual(layout.width, 390)
        XCTAssertEqual(layout.height, 260.886363636, accuracy: 1e-6)
        XCTAssertEqual(layout.originX, 0)
    }

    func testLandscapeUsesSafeWidthAndReferenceScale() {
        let layout = HexLayout(containerWidth: 844, leadingInset: 44, trailingInset: 44,
                               shorterSide: 390, tablet: false)
        XCTAssertEqual(layout.width, 756)
        XCTAssertEqual(layout.height, 883 * 390 / 1320 * 0.75, accuracy: 1e-8)
        XCTAssertEqual(layout.originX, 44)
        XCTAssertTrue(layout.isSplit)
    }

    func testTabletReferenceCapAndNarrowWindowsStillFit() {
        let wide = HexLayout(containerWidth: 1024, shorterSide: 768, tablet: true)
        XCTAssertEqual(wide.width, 1024)
        XCTAssertEqual(wide.height, 430 * 883 / 1320, accuracy: 1e-8)
        XCTAssertEqual(wide.originX, 0)
        let narrow = HexLayout(containerWidth: 375, shorterSide: 768, tablet: true)
        XCTAssertEqual(narrow.width, 375)
        XCTAssertEqual(narrow.originX, 0)
        XCTAssertEqual(narrow.height, 375 * 883 / 1320, accuracy: 1e-6)
    }

    func testModeChoiceUsesAvailableWidthThresholdAndOverride() {
        var tuning = KeyboardTuning()
        XCTAssertFalse(HexLayout(containerWidth: 650, leadingInset: 30, trailingInset: 30,
                                 shorterSide: 390, tablet: false).isSplit)
        XCTAssertTrue(HexLayout(containerWidth: 600, shorterSide: 390, tablet: false).isSplit)
        tuning[.splitWidthThreshold] = 800
        XCTAssertFalse(HexLayout(containerWidth: 700, shorterSide: 390, tablet: false, tuning: tuning).isSplit)
        tuning.layoutMode = .split
        XCTAssertTrue(HexLayout(containerWidth: 390, shorterSide: 390, tablet: false, tuning: tuning).isSplit)
        tuning.layoutMode = .unified
        XCTAssertFalse(HexLayout(containerWidth: 1000, shorterSide: 390, tablet: false, tuning: tuning).isSplit)
    }

    func testUniformScaleMirrorsDuplicateSlotsInsetsAndInertGap() throws {
        let layout = HexLayout(containerWidth: 900, leadingInset: 20, trailingInset: 40,
                               shorterSide: 390, tablet: false)
        let g = layout.geometry
        let reference = HexGeometry()
        XCTAssertEqual(g.placedKeys.count, 32)
        XCTAssertEqual(g.horizontalScale, reference.horizontalScale, accuracy: 1e-8)
        XCTAssertEqual(g.apothem, reference.apothem * layout.scale, accuracy: 1e-8)
        XCTAssertEqual(g.radius, reference.radius * layout.scale, accuracy: 1e-8)
        XCTAssertEqual(g.height, 883 * g.scale, accuracy: 1e-8)
        XCTAssertEqual(layout.originX + g.center(of: HexKey(slot: 0)).x - g.radius,
                       20 + 14 * g.scale, accuracy: 1e-8)
        XCTAssertEqual(layout.originX + g.center(of: HexKey(slot: 24)).x + g.radius,
                       900 - 40 - 14 * g.scale, accuracy: 1e-8)
        for placed in g.placedKeys {
            let mirror = try XCTUnwrap(g.placedKeys.first {
                abs($0.center.x + placed.center.x - g.width) < 1e-8 && abs($0.center.y - placed.center.y) < 1e-8
            })
            XCTAssertEqual(mirror.key.row, placed.key.row)
            XCTAssertEqual(g.key(at: placed.center), placed.key)
            if placed.isDuplicate {
                XCTAssertEqual(placed.key.column, 3)
                XCTAssertEqual(placed.center.y, g.center(of: placed.key).y)
            }
        }
        XCTAssertNil(g.key(at: HexPoint(x: g.width / 2, y: g.height / 2)))
    }

    func testHeightBudgetAndOverlapClamp() {
        var tuning = KeyboardTuning(tablet: true)
        tuning[.heightBudget] = 120
        for mode in [LayoutMode.unified, .split] {
            tuning.layoutMode = mode
            let layout = HexLayout(containerWidth: 1000, shorterSide: 768, tablet: true, tuning: tuning)
            XCTAssertEqual(layout.height, 120, accuracy: 1e-8)
            XCTAssertEqual(layout.geometry.scale, 120 / 883, accuracy: 1e-8)
        }
        tuning[.heightBudget] = 600
        tuning[.splitKeyScale] = 1.5
        tuning.layoutMode = .split
        let layout = HexLayout(containerWidth: 320, shorterSide: 768, tablet: true, tuning: tuning)
        let g = layout.geometry
        let left = g.center(of: HexKey(slot: 12)).x + g.radius
        let right = g.placedKeys.first { $0.isDuplicate }!.center.x - g.radius
        XCTAssertLessThanOrEqual(left, right + 1e-8)
    }
}
