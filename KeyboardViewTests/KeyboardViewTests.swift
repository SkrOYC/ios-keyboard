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
        for width in [390.0, 844.0, 390.0] {
            let tuning = KeyboardTuning()
            let layout = HexLayout(containerWidth: width, shorterSide: 390, tablet: false, tuning: tuning)
            view.frame.size = CGSize(width: layout.width, height: layout.height)
            view.configure(layout: layout, tuning: tuning)
            view.layoutIfNeeded()
            let geometry = layout.geometry
            XCTAssertEqual(view.geometry.placedKeys.count, layout.isSplit ? 32 : 28)
            for placed in geometry.placedKeys {
                let center = placed.center
                XCTAssertTrue(view.hitTest(CGPoint(x: center.x, y: center.y), with: nil) === view)
                XCTAssertEqual(view.geometry.key(at: center), placed.key)
            }
            let first = geometry.center(of: HexKey(slot: 0))
            let second = geometry.center(of: HexKey(slot: 1))
            XCTAssertTrue(view.hitTest(CGPoint(x: first.x, y: (first.y + second.y) / 2), with: nil) === view)
            if layout.isSplit {
                XCTAssertNil(view.geometry.key(at: HexPoint(x: width / 2, y: layout.height / 2)))
            }
            XCTAssertEqual(view.backgroundColor?.cgColor.alpha, 0)
            XCTAssertFalse(view.isOpaque)
            XCTAssertTrue(view.subviews.allSatisfy { !$0.isUserInteractionEnabled && $0.accessibilityElementsHidden })
        }
    }

    @MainActor
    func testSplitCopiesHaveOnlyPrimaryAccessibleElements() throws {
        let view = keyboard()
        let layout = HexLayout(containerWidth: 844, shorterSide: 390, tablet: false)
        view.frame.size = CGSize(width: layout.width, height: layout.height)
        view.configure(layout: layout, tuning: KeyboardTuning())
        view.layoutIfNeeded()
        let elements = try XCTUnwrap(view.accessibilityElements as? [UIAccessibilityElement])
        XCTAssertEqual(elements.count, 28)
        XCTAssertEqual(Set(elements.compactMap(\.accessibilityIdentifier)).count, 28)
        XCTAssertEqual(view.geometry.placedKeys.filter(\.isDuplicate).count, 4)
        for (slot, element) in elements.enumerated() {
            let primary = view.geometry.center(of: HexKey(slot: slot))
            XCTAssertEqual(element.accessibilityFrameInContainerSpace.midX, primary.x, accuracy: 0.001)
            XCTAssertEqual(element.accessibilityFrameInContainerSpace.midY, primary.y, accuracy: 0.001)
        }
    }

    @MainActor
    func testAccessibleCapsLockAndReset() throws {
        let view = keyboard()
        let elements = try XCTUnwrap(view.accessibilityElements as? [UIAccessibilityElement])
        let toggle = try XCTUnwrap(elements.first { $0.accessibilityIdentifier == "key-123" })
        XCTAssertTrue(toggle.accessibilityHint!.contains("hold to move the cursor"))
        XCTAssertTrue(toggle.accessibilityHint!.contains("swipe up for caps lock and letter order"))
        var received: [KeyboardAction] = []
        view.onAction = { received.append($0) }
        let picker = try XCTUnwrap(toggle.accessibilityCustomActions?.first { $0.name == "Choose letter order" })
        XCTAssertEqual(picker.actionHandler?(picker), true)
        XCTAssertEqual(received, [.showPicker])
        let caps = try XCTUnwrap(toggle.accessibilityCustomActions?.first { $0.name == "Toggle caps lock" })
        XCTAssertEqual(caps.actionHandler?(caps), true)
        XCTAssertEqual(toggle.accessibilityValue, "Caps lock on")
        let h = try XCTUnwrap(elements.first { $0.accessibilityIdentifier == "key-h" })
        XCTAssertEqual(h.accessibilityLabel, "H")
        XCTAssertTrue(h.accessibilityActivate())
        XCTAssertEqual(received.last, .insert("H"))
        view.resetCapsLock()
        XCTAssertEqual(toggle.accessibilityValue, "Caps lock off")
        XCTAssertEqual(h.accessibilityLabel, "h")
        XCTAssertTrue(h.accessibilityActivate())
        XCTAssertEqual(received.last, .insert("h"))
    }

    @MainActor
    func testPopupPlateIsDecorativeAndSelectionHasAnOutline() {
        let view = PopupPlateView()
        let popup = PopupModel(geometry: HexGeometry(width: 390, height: 260), includesGlobe: true)
        view.update(popup: popup, selected: nil)
        XCTAssertFalse(view.isUserInteractionEnabled)
        XCTAssertTrue(view.accessibilityElementsHidden)
        let labels = view.subviews.compactMap { $0 as? UILabel }
        XCTAssertEqual(labels.map(\.text), [",", "?", "!", "'", "🌐"])
        XCTAssertTrue(labels.allSatisfy { $0.layer.borderWidth == 0 })
        view.update(popup: popup, selected: 1)
        XCTAssertEqual(labels[1].layer.borderWidth, 2)
        XCTAssertTrue(labels.enumerated().allSatisfy { $0.offset == 1 || $0.element.layer.borderWidth == 0 })
        XCTAssertEqual(view.plateBounds.width, popup.cellWidth * 5, accuracy: 0.001)
        view.update(popup: popup, selected: 99)
        XCTAssertTrue(labels.allSatisfy { $0.layer.borderWidth == 0 })
        let empty = PopupModel(choices: [], columns: 1, anchor: HexPoint(x: 0, y: 0),
                               origin: HexPoint(x: 0, y: 0), cellWidth: 40, cellHeight: 40,
                               inwardSign: 1, cancelSlop: 2)
        view.update(popup: empty, selected: nil)
        XCTAssertTrue(view.subviews.isEmpty)
        XCTAssertTrue(view.plateBounds.isNull)
    }

    #if DEVTOOLS
    @MainActor
    func testTuningControlsPersistClampCycleAndReset() throws {
        let suite = "TuningStripTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = TuningStore(defaults: defaults)
        let view = TuningStripView(store: store)
        let controls = try XCTUnwrap(view.accessibilityElements as? [UIButton])
        XCTAssertEqual(controls.compactMap(\.accessibilityIdentifier), ["tuning-param", "tuning-minus", "tuning-plus", "tuning-reset"])
        var applied: KeyboardTuning?
        view.onChange = { applied = $0 }
        controls[2].sendActions(for: .touchUpInside)
        XCTAssertEqual(store.tuning.splitKeyScale, KeyboardTuning().splitKeyScale + TuningParameter.splitKeyScale.step, accuracy: 0.0001)
        XCTAssertEqual(applied?.splitKeyScale, store.tuning.splitKeyScale)
        for _ in 0..<100 { controls[1].sendActions(for: .touchUpInside) }
        XCTAssertEqual(store.tuning.splitKeyScale, TuningParameter.splitKeyScale.range.lowerBound)
        for _ in 0..<7 { controls[0].sendActions(for: .touchUpInside) }
        XCTAssertEqual(controls[0].accessibilityLabel, TuningParameter.layoutMode.displayName)
        for expected in [LayoutMode.unified, .split, .auto] {
            controls[2].sendActions(for: .touchUpInside)
            XCTAssertEqual(store.tuning.layoutMode, expected)
        }
        controls[3].sendActions(for: .touchUpInside)
        for parameter in TuningParameter.allCases { XCTAssertEqual(store.tuning[parameter], KeyboardTuning()[parameter]) }
        XCTAssertEqual(applied?.splitKeyScale, KeyboardTuning().splitKeyScale)
    }
    #endif
}
