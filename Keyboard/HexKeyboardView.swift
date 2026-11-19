import UIKit

/// Draw keycaps over the system's Liquid Glass platter without an opaque tray.
final class HexKeyboardView: UIView {
    var onAction: ((KeyboardAction) -> Void)?
    var onDiagnostic: ((String) -> Void)?
    private var machine = TouchMachine(geometry: HexGeometry())
    private var labels: [UILabel] = []
    private let glassRenderer = HexGlassRendererView()
    private let glassSlots = Set(0..<28)
    private var keyElements: [KeyAccessibilityElement] = []
    private var touchIDs: [ObjectIdentifier: Int] = [:]
    private let presetStore = PresetStore()
    private var pickerPanel: UIStackView?
    private var pickerChoices: UIStackView?
    private var nextID = 0
    private var holdTimers: [Int: Timer] = [:]
    private var popupRenderers: [Int: HexGlassRendererView] = [:]
    private var popupLabels: [Int: [UILabel]] = [:]

    var needsGlobe: Bool {
        get { machine.needsGlobe }
        set {
            guard newValue != machine.needsGlobe else { return }
            machine.needsGlobe = newValue
            cancelTouches()
        }
    }

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = true
        isAccessibilityElement = false
        machine.order = presetStore.order
        addSubview(glassRenderer)
        for key in machine.geometry.keys {
            let label = UILabel()
            label.backgroundColor = .clear
            label.isOpaque = false
            label.textAlignment = .center
            label.textColor = .label
            label.isUserInteractionEnabled = false
            label.isAccessibilityElement = false
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
            let radius = CGFloat(g.radius)
            let apothem = CGFloat(g.apothem)
            let rect = CGRect(x: CGFloat(center.x) - radius, y: CGFloat(center.y) - apothem,
                              width: 2 * radius, height: 2 * apothem)
            keyElements[key.slot].accessibilityFrameInContainerSpace = rect
        }
        glassRenderer.frame = bounds
        glassRenderer.update(geometry: g, slots: glassSlots, labels: labels)
        refresh()
        layoutPicker()
        CATransaction.commit()
    }

    private func refresh() {
        let pressed = Set(machine.contacts.values.compactMap { $0.direction == nil ? $0.startKey?.slot : nil })
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for key in machine.geometry.keys {
            let title = keyLabel(key, layer: machine.layer, order: machine.order)
            labels[key.slot].text = title
            let number = machine.layer == .symbols && "0123456789*#".contains(title)
            let units: CGFloat = key.letterIndex == nil ? 44 : number ? 64 : 58
            let verticalLimit: CGFloat = key.letterIndex == nil ? 0.85 : 1.1
            let size = min(26, units * CGFloat(machine.scale), CGFloat(machine.geometry.apothem) * verticalLimit)
            labels[key.slot].font = .systemFont(ofSize: size, weight: number ? .semibold : .medium)
            let element = keyElements[key.slot]
            element.accessibilityIdentifier = key.isLayer ? "key-123" : key.isPeriod ? "key-period" : "key-\(title)"
            element.accessibilityLabel = key.isLayer ? (machine.layer == .letters ? "Symbols" : "Letters") : key.isPeriod ? "Period" : title
            element.accessibilityHint = key.isLayer ? "Hold to choose a letter order" : key.isPeriod ? (machine.needsGlobe ? "Hold for punctuation and the next keyboard" : "Hold for punctuation") : "Swipe left to delete, right for space, down for return, or up on a letter to capitalize"
            element.accessibilityCustomActions = customActions(for: key)
        }
        let obscured = refreshPopups()
        glassRenderer.setFeedback(pressed: pressed, obscured: obscured)
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
        guard pickerPanel == nil else { return }
        for touch in touches {
            nextID += 1
            touchIDs[ObjectIdentifier(touch)] = nextID
            let location = point(touch)
            machine.begin(nextID, at: location, time: touch.timestamp)
            scheduleHold(nextID)
        }
        refresh()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let id = touchIDs[ObjectIdentifier(touch)] else { continue }
            let location = point(touch)
            let contact = machine.contacts[id]
            let actions = machine.move(id, to: location)
            reportDeleteMotion(actions, contact: contact, at: location, phase: "move")
            send(actions)
            if machine.contacts[id]?.holdAllowed == false { holdTimers.removeValue(forKey: id)?.invalidate() }
        }
        refresh()
    }

    private func send(_ actions: [KeyboardAction]) {
        for action in actions { onAction?(action) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let id = touchIDs.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            holdTimers.removeValue(forKey: id)?.invalidate()
            let location = point(touch)
            let contact = machine.contacts[id]
            let actions = machine.end(id, at: location, time: touch.timestamp)
            reportDeleteMotion(actions, contact: contact, at: location, phase: "end")
            send(actions)
        }
        refresh()
    }

    private func reportDeleteMotion(_ actions: [KeyboardAction], contact: TouchMachine.Contact?,
                                    at location: HexPoint, phase: String) {
        let count = actions.filter { $0 == .delete }.count
        guard count > 0, let contact else { return }
        let travel = String(format: "%.1f", (location.x - contact.start.x) / machine.scale)
        onDiagnostic?("delete motion phase=\(phase) first=\(contact.direction == nil) travel=\(travel) count=\(count)")
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let id = touchIDs.removeValue(forKey: ObjectIdentifier(touch)) {
                holdTimers.removeValue(forKey: id)?.invalidate()
                machine.cancel(id)
            }
        }
        refresh()
    }

    func cancelTouches() {
        for timer in holdTimers.values { timer.invalidate() }
        holdTimers.removeAll()
        machine.cancelAll()
        touchIDs.removeAll()
        refresh()
    }

    private func scheduleHold(_ id: Int) {
        guard let key = machine.contacts[id]?.startKey, key.isPeriod || key.isLayer else { return }
        let timer = Timer(timeInterval: machine.tuning.holdMilliseconds / 1000, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.holdTimers.removeValue(forKey: id)
            self.send(self.machine.advance(id, time: ProcessInfo.processInfo.systemUptime))
            self.refresh()
        }
        holdTimers[id] = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func refreshPopups() -> Set<Int> {
        let active = Set(machine.contacts.compactMap { $0.value.popup == nil ? nil : $0.key })
        for id in Array(popupRenderers.keys) where !active.contains(id) {
            popupRenderers.removeValue(forKey: id)?.removeFromSuperview()
            popupLabels.removeValue(forKey: id)
        }
        var coverage: [CGRect] = []
        for id in active.sorted() {
            guard let contact = machine.contacts[id], let popup = contact.popup else { continue }
            let opened = popupRenderers[id] == nil
            if popupRenderers[id] == nil {
                let renderer = HexGlassRendererView(materializes: true)
                popupRenderers[id] = renderer
                addSubview(renderer)
                popupLabels[id] = popup.entries.map { _ in
                    let label = UILabel()
                    label.textAlignment = .center
                    label.backgroundColor = .clear
                    label.isOpaque = false
                    label.isUserInteractionEnabled = false
                    label.isAccessibilityElement = false
                    return label
                }
            }
            let selected = popup.selection(at: contact.location)
            let surfaces = popup.entries.enumerated().map { index, entry in
                let label = popupLabels[id]![index]
                label.text = entry.choice.label
                label.textColor = .label
                let a = CGFloat(popup.cellHeight / 2)
                let radius = CGFloat(popup.cellWidth / 2)
                label.font = .systemFont(ofSize: min(24, a * 1.05))
                coverage.append(CGRect(x: CGFloat(entry.center.x) - radius, y: CGFloat(entry.center.y) - a,
                                       width: 2 * radius, height: 2 * a))
                return HexGlassSurface(id: index, polygon: entry.rect.polygon,
                                       stroke: machine.geometry.stroke, label: label)
            }
            let renderer = popupRenderers[id]!
            renderer.frame = bounds
            renderer.update(surfaces: surfaces, size: bounds.size)
            renderer.setFeedback(pressed: Set(popup.entries.indices.filter { popup.entries[$0].choice == selected }))
            if opened { onDiagnostic?("punctuation") }
        }
        // Obscure only glyphs covered by the floating punctuation surfaces.
        guard !coverage.isEmpty else { return [] }
        return Set(machine.geometry.keys.compactMap { key in
            let center = machine.geometry.center(of: key)
            let size = labels[key.slot].sizeThatFits(CGSize(width: machine.geometry.radius * 2,
                                                          height: machine.geometry.apothem * 2))
            let glyph = CGRect(x: CGFloat(center.x) - size.width / 2, y: CGFloat(center.y) - size.height / 2,
                               width: size.width, height: size.height)
            return coverage.contains { $0.intersects(glyph) } ? key.slot : nil
        })
    }

    private func customActions(for key: HexKey) -> [UIAccessibilityCustomAction] {
        var actions = [
            accessibilityAction("Delete", action: .delete),
            accessibilityAction("Space", action: .insert(" ")),
            accessibilityAction("Return", action: .insert("\n"))
        ]
        if let index = key.letterIndex, machine.layer == .letters {
            actions.append(accessibilityAction("Capitalize", action: .insert(machine.order.letter(at: index).uppercased())))
        }
        if key.isLayer {
            actions.append(accessibilityAction("Choose letter order", action: .showPicker))
        }
        if key.isPeriod {
            for (name, value) in [("Comma", ","), ("Question mark", "?"), ("Exclamation mark", "!"), ("Apostrophe", "'")] {
                actions.append(accessibilityAction(name, action: .insert(value)))
            }
            if machine.needsGlobe { actions.append(accessibilityAction("Next keyboard", action: .nextKeyboard)) }
        }
        return actions
    }

    private func accessibilityAction(_ title: String, action: KeyboardAction) -> UIAccessibilityCustomAction {
        UIAccessibilityCustomAction(name: title) { [weak self] _ in
            guard let self else { return false }
            self.onAction?(action)
            return true
        }
    }

    func showPicker() {
        cancelTouches()
        guard pickerPanel == nil else { return }
        let panel = UIStackView()
        panel.axis = .vertical
        panel.spacing = 8
        panel.accessibilityViewIsModal = true
        let title = UILabel()
        title.text = "Letter order"
        title.textAlignment = .center
        title.font = .preferredFont(forTextStyle: .headline)
        title.accessibilityTraits.insert(.header)
        title.heightAnchor.constraint(equalToConstant: 24).isActive = true
        panel.addArrangedSubview(title)
        let choices = UIStackView()
        choices.spacing = 6
        choices.distribution = .fillEqually
        for order in LetterOrder.allCases {
            let button = pickerButton(order.title + (order == machine.order ? " ✓" : ""))
            button.accessibilityIdentifier = "preset-\(order.rawValue)"
            button.accessibilityLabel = order.title
            button.isSelected = order == machine.order
            button.accessibilityTraits = order == machine.order ? [.button, .selected] : .button
            button.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.presetStore.order = order
                self.machine.order = order
                self.hidePicker()
            }, for: .touchUpInside)
            choices.addArrangedSubview(button)
        }
        panel.addArrangedSubview(choices)
        let close = pickerButton("Done")
        close.accessibilityIdentifier = "preset-done"
        close.heightAnchor.constraint(equalToConstant: 44).isActive = true
        close.addAction(UIAction { [weak self] _ in self?.hidePicker() }, for: .touchUpInside)
        panel.addArrangedSubview(close)
        pickerChoices = choices
        pickerPanel = panel
        addSubview(panel)
        glassRenderer.isHidden = true
        labels.forEach { $0.isHidden = true }
        accessibilityElements = [panel]
        layoutPicker()
        UIAccessibility.post(notification: .layoutChanged, argument: title)
    }

    private func pickerButton(_ title: String) -> UIButton {
        var configuration = UIButton.Configuration.glass()
        configuration.title = title
        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        return button
    }

    private func layoutPicker() {
        guard let panel = pickerPanel else { return }
        let compact = bounds.height < 220
        pickerChoices?.axis = compact ? .horizontal : .vertical
        let height: CGFloat = compact ? 128 : 228
        panel.frame = CGRect(x: 16, y: max(0, (bounds.height - height) / 2), width: bounds.width - 32, height: height)
    }

    private func hidePicker() {
        pickerPanel?.removeFromSuperview()
        pickerPanel = nil
        pickerChoices = nil
        glassRenderer.isHidden = false
        labels.forEach { $0.isHidden = false }
        accessibilityElements = keyElements
        refresh()
        UIAccessibility.post(notification: .layoutChanged, argument: keyElements[3])
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
