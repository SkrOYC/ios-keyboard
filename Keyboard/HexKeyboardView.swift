import UIKit

/// Draw keycaps over the system's Liquid Glass platter without an opaque tray.
final class HexKeyboardView: UIView {
    private enum Glass {
        static let keyFill = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.16) : .white
        }
        static let keyPressedFill = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.28)
                : UIColor(red: 0.847, green: 0.863, blue: 0.894, alpha: 1)
        }
    }

    var onAction: ((KeyboardAction) -> Void)?
    private var machine = TouchMachine(geometry: HexGeometry())
    private var shapes: [CAShapeLayer] = []
    private var labels: [UILabel] = []
    private var keyElements: [KeyAccessibilityElement] = []
    private var touchIDs: [ObjectIdentifier: Int] = [:]
    private var nextID = 0

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = true
        isAccessibilityElement = false
        for key in machine.geometry.keys {
            let shape = CAShapeLayer()
            shape.lineJoin = .round
            layer.addSublayer(shape)
            shapes.append(shape)
            let label = UILabel()
            label.textAlignment = .center
            label.textColor = .label
            label.isUserInteractionEnabled = false
            label.isAccessibilityElement = false
            addSubview(label)
            labels.append(label)
            let element = KeyAccessibilityElement(accessibilityContainer: self)
            element.isAccessibilityElement = true
            element.accessibilityTraits = .keyboardKey
            element.activate = { [weak self] in self?.activate(key) }
            keyElements.append(element)
        }
        accessibilityElements = keyElements
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: HexKeyboardView, _: UITraitCollection) in
            view.refresh()
        }
    }

    required init?(coder: NSCoder) { fatalError("Use init()") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        if machine.geometry.width != Double(bounds.width) || machine.geometry.height != Double(bounds.height) {
            cancelTouches()
            machine.geometry = HexGeometry(width: Double(bounds.width), height: Double(bounds.height))
        }
        let g = machine.geometry
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for key in g.keys {
            let center = g.center(of: key)
            shapes[key.slot].path = path(g.polygon(of: key)).cgPath
            shapes[key.slot].lineWidth = CGFloat(g.stroke)
            let radius = CGFloat(g.radius)
            let apothem = CGFloat(g.apothem)
            let rect = CGRect(x: CGFloat(center.x) - radius, y: CGFloat(center.y) - apothem,
                              width: 2 * radius, height: 2 * apothem)
            labels[key.slot].frame = rect
            labels[key.slot].font = .systemFont(ofSize: min(26, apothem * (key.letterIndex == nil ? 0.48 : 0.65)), weight: .medium)
            keyElements[key.slot].accessibilityFrameInContainerSpace = rect
        }
        refresh()
        CATransaction.commit()
    }

    private func path(_ points: [HexPoint]) -> UIBezierPath {
        let path = UIBezierPath()
        for (index, point) in points.enumerated() {
            let p = CGPoint(x: point.x, y: point.y)
            if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.close()
        return path
    }

    private func refresh() {
        let pressed = Set(machine.contacts.values.compactMap { $0.direction == nil ? $0.startKey?.slot : nil })
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for key in machine.geometry.keys {
            let title = keyLabel(key, layer: machine.layer, order: machine.order)
            labels[key.slot].text = title
            let fill = pressed.contains(key.slot) ? Glass.keyPressedFill : Glass.keyFill
            shapes[key.slot].fillColor = fill.resolvedColor(with: traitCollection).cgColor
            shapes[key.slot].strokeColor = fill.resolvedColor(with: traitCollection).cgColor
            let element = keyElements[key.slot]
            element.accessibilityIdentifier = key.isLayer ? "key-123" : key.isPeriod ? "key-period" : "key-\(title)"
            element.accessibilityLabel = key.isLayer ? (machine.layer == .letters ? "Symbols" : "Letters") : key.isPeriod ? "Period" : title
        }
        CATransaction.commit()
    }

    private func activate(_ key: HexKey) {
        if key.isLayer { machine.layer = machine.layer == .letters ? .symbols : .letters }
        else { onAction?(.insert(keyLabel(key, layer: machine.layer, order: machine.order))) }
        refresh()
    }

    private func point(_ touch: UITouch) -> HexPoint {
        let p = touch.location(in: self)
        return HexPoint(x: Double(p.x), y: Double(p.y))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            nextID += 1
            touchIDs[ObjectIdentifier(touch)] = nextID
            machine.begin(nextID, at: point(touch), time: touch.timestamp)
        }
        refresh()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let id = touchIDs.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            machine.cancel(id)
            if let key = machine.geometry.key(at: point(touch)) { activate(key) }
        }
        refresh()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let id = touchIDs.removeValue(forKey: ObjectIdentifier(touch)) { machine.cancel(id) }
        }
        refresh()
    }

    func cancelTouches() {
        machine.cancelAll()
        touchIDs.removeAll()
        refresh()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { cancelTouches() }
    }
}

private final class KeyAccessibilityElement: UIAccessibilityElement {
    var activate: (() -> Void)?
    override func accessibilityActivate() -> Bool {
        guard let activate else { return false }
        activate()
        return true
    }
}
