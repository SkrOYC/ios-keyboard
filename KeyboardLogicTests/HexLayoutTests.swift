import XCTest

final class HexLayoutTests: XCTestCase {
    func testPortraitMatchesDesignScale() {
        let layout = HexLayout(containerWidth: 390, compactHeight: false, tablet: false)
        XCTAssertEqual(layout.width, 390)
        XCTAssertEqual(layout.height, 260.886363636, accuracy: 1e-6)
        XCTAssertEqual(layout.originX, 0)
    }

    func testLandscapeUsesSafeWidthAndCompactHeight() {
        let layout = HexLayout(containerWidth: 844, leadingInset: 44, trailingInset: 44,
                               compactHeight: true, tablet: false)
        XCTAssertEqual(layout.width, 756)
        XCTAssertEqual(layout.height, 180)
        XCTAssertEqual(layout.originX, 44)
    }

    func testTabletCapCentersAndNarrowWindowsStillFit() {
        let wide = HexLayout(containerWidth: 1024, compactHeight: false, tablet: true)
        XCTAssertEqual(wide.width, 700)
        XCTAssertEqual(wide.height, 320)
        XCTAssertEqual(wide.originX, 162)
        let narrow = HexLayout(containerWidth: 375, compactHeight: false, tablet: true)
        XCTAssertEqual(narrow.width, 375)
        XCTAssertEqual(narrow.originX, 0)
        XCTAssertEqual(narrow.height, 375 * 883 / 1320, accuracy: 1e-6)
    }
}
