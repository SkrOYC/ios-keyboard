import UIKit
import XCTest

final class KeyboardViewTests: XCTestCase {
    @MainActor
    private func keyboard() -> HexKeyboardView {
        let view = HexKeyboardView()
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 883 * 390 / 1320)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        return view
    }

    @MainActor
    func testEveryKeyHasAUniqueAccessibleElementAndEditingActions() throws {
        let view = keyboard()
        let elements = try XCTUnwrap(view.accessibilityElements as? [UIAccessibilityElement])
        XCTAssertEqual(elements.count, 28)
        XCTAssertEqual(Set(elements.compactMap(\.accessibilityIdentifier)).count, 28)
        XCTAssertTrue(view.isMultipleTouchEnabled)
        for element in elements {
            XCTAssertTrue(element.isAccessibilityElement)
            XCTAssertTrue(element.accessibilityTraits.contains(.keyboardKey))
            XCTAssertGreaterThan(element.accessibilityFrameInContainerSpace.width, 0)
            XCTAssertEqual(Array((element.accessibilityCustomActions ?? []).prefix(3)).map(\.name), ["Delete", "Space", "Return"])
        }
        var received: [KeyboardAction] = []
        view.onAction = { received.append($0) }
        let h = try XCTUnwrap(elements.first { $0.accessibilityIdentifier == "key-h" })
        let capitalize = try XCTUnwrap(h.accessibilityCustomActions?.first { $0.name == "Capitalize" })
        XCTAssertEqual(capitalize.actionHandler?(capitalize), true)
        XCTAssertEqual(received, [.insert("H")])
    }

    @MainActor
    func testAccessibleLayerToggleAndConditionalGlobe() throws {
        let view = keyboard()
        let elements = try XCTUnwrap(view.accessibilityElements as? [UIAccessibilityElement])
        let toggle = try XCTUnwrap(elements.first { $0.accessibilityIdentifier == "key-123" })
        let period = try XCTUnwrap(elements.first { $0.accessibilityIdentifier == "key-period" })
        XCTAssertFalse(period.accessibilityCustomActions!.contains { $0.name == "Next keyboard" })
        view.needsGlobe = true
        XCTAssertTrue(period.accessibilityCustomActions!.contains { $0.name == "Next keyboard" })
        XCTAssertTrue(toggle.accessibilityActivate())
        XCTAssertEqual(toggle.accessibilityLabel, "Letters")
        let one = try XCTUnwrap(elements.first { $0.accessibilityIdentifier == "key-1" })
        XCTAssertFalse(one.accessibilityCustomActions!.contains { $0.name == "Capitalize" })
        var received: [KeyboardAction] = []
        view.onAction = { received.append($0) }
        XCTAssertTrue(one.accessibilityActivate())
        XCTAssertEqual(received, [.insert("1")])
        XCTAssertTrue(toggle.accessibilityActivate())
        XCTAssertTrue(elements.contains { $0.accessibilityIdentifier == "key-h" })
    }

    @MainActor
    func testDecorativeSurfacesLeaveTouchesWithKeyboardAfterResize() {
        let view = keyboard()
        for size in [CGSize(width: 390, height: 883 * 390 / 1320), CGSize(width: 844, height: 180)] {
            view.frame.size = size
            view.setNeedsLayout()
            view.layoutIfNeeded()
            let geometry = HexGeometry(width: Double(size.width), height: Double(size.height))
            for key in geometry.keys {
                let center = geometry.center(of: key)
                XCTAssertTrue(view.hitTest(CGPoint(x: center.x, y: center.y), with: nil) === view)
            }
            let first = geometry.center(of: HexKey(slot: 0))
            let second = geometry.center(of: HexKey(slot: 1))
            XCTAssertTrue(view.hitTest(CGPoint(x: first.x, y: (first.y + second.y) / 2), with: nil) === view)
        }
    }
}
