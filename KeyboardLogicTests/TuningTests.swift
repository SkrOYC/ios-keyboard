import XCTest

final class TuningTests: XCTestCase {
    func testMetadataDefaultsValidationAndStoreRoundTrip() throws {
        let suite = "keyboard.logic.tuning.tests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        for tablet in [false, true] {
            let store = TuningStore(defaults: defaults, tablet: tablet)
            store.reset()
            XCTAssertEqual(store.tuning.splitKeyScale, tablet ? 1 : 0.75)
            for parameter in TuningParameter.allCases {
                XCTAssertFalse(parameter.displayName.isEmpty)
                XCTAssertGreaterThan(parameter.step, 0)
                XCTAssertTrue(parameter.range.contains(parameter.defaultValue(tablet: tablet)))
                for invalid in ["bad" as Any, true as Any, parameter.range.lowerBound - 1,
                                parameter.range.upperBound + 1, Double.nan, Double.infinity] {
                    defaults.set(invalid, forKey: "tuning.\(parameter.rawValue)")
                    XCTAssertEqual(store.tuning[parameter], parameter.defaultValue(tablet: tablet))
                }
            }
            var tuning = KeyboardTuning(tablet: tablet)
            for parameter in TuningParameter.allCases { tuning[parameter] = parameter.range.upperBound }
            store.tuning = tuning
            for parameter in TuningParameter.allCases {
                XCTAssertEqual(store.tuning[parameter], parameter.range.upperBound)
            }
            defaults.set(1.5, forKey: "tuning.layoutMode")
            XCTAssertEqual(store.tuning.layoutMode, .auto)
            store.reset()
            XCTAssertEqual(store.tuning.layoutMode, .auto)
        }
    }
}
