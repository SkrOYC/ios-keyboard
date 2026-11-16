import Foundation
import XCTest

final class PresetStoreTests: XCTestCase {
    func testDefaultPersistenceAndInvalidValueFallback() throws {
        let suite = "keyboard.logic.preset.tests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PresetStore(defaults: defaults)
        XCTAssertEqual(store.order, .familiar)
        for order in LetterOrder.allCases {
            store.order = order
            XCTAssertEqual(PresetStore(defaults: defaults).order, order)
            XCTAssertEqual(defaults.string(forKey: "letterOrder"), order.rawValue)
        }
        defaults.set("unknown", forKey: "letterOrder")
        XCTAssertEqual(PresetStore(defaults: defaults).order, .familiar)
    }
}
