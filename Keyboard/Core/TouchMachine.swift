import Foundation

enum KeyboardAction: Equatable {
    case insert(String)
    case delete
    case nextKeyboard
    case showPicker
}

struct TouchMachine {
    static let threshold = 70.0
    static let holdMilliseconds = 420.0
    static let holdSlop = 10.0
    static let repeatDistance = max(40.0, 0.9 * threshold)

    enum Direction: Equatable { case left, right, up, down }
    struct Contact {
        let start: HexPoint
        var location: HexPoint
        let startKey: HexKey?
        let layer: KeyboardLayer
        let order: LetterOrder
        let began: Double
        var holdAllowed = true
        var direction: Direction?
        var nextDeleteX = 0.0
        var popup: PopupModel?
        var consumed = false
    }

    var geometry: HexGeometry
    var layer = KeyboardLayer.letters
    var order = LetterOrder.familiar
    var needsGlobe = false
    var pickerEnabled = false
    private(set) var contacts: [Int: Contact] = [:]
    var scale: Double { geometry.width / HexGeometry.designWidth }

    mutating func begin(_ id: Int, at point: HexPoint, time: Double) {
        contacts[id] = Contact(start: point, location: point, startKey: geometry.key(at: point),
                               layer: layer, order: order, began: time)
    }

    mutating func advance(_ id: Int, time: Double) -> [KeyboardAction] {
        guard var contact = contacts[id], !contact.consumed, contact.direction == nil,
              contact.holdAllowed, time - contact.began >= Self.holdMilliseconds / 1000 else { return [] }
        if contact.startKey?.isPeriod == true {
            contact.popup = PopupModel(geometry: geometry, includesGlobe: needsGlobe)
            contact.consumed = true
        } else if contact.startKey?.isLayer == true && pickerEnabled {
            contact.consumed = true
            contacts[id] = contact
            return [.showPicker]
        }
        contacts[id] = contact
        return []
    }

    mutating func move(_ id: Int, to point: HexPoint) -> [KeyboardAction] {
        guard var contact = contacts[id] else { return [] }
        contact.location = point
        defer { contacts[id] = contact }
        guard !contact.consumed else { return [] }
        let dx = point.x - contact.start.x, dy = point.y - contact.start.y
        let travel = hypot(dx, dy)
        if travel > Self.holdSlop * scale { contact.holdAllowed = false }
        if let direction = contact.direction {
            guard direction == .left else { return [] }
            var result: [KeyboardAction] = []
            while dx <= contact.nextDeleteX - Self.repeatDistance * scale {
                contact.nextDeleteX -= Self.repeatDistance * scale
                result.append(.delete)
            }
            return result
        }
        guard travel >= Self.threshold * scale else { return [] }
        let direction: Direction = abs(dx) >= abs(dy) ? (dx < 0 ? .left : .right) : (dy < 0 ? .up : .down)
        contact.direction = direction
        contact.nextDeleteX = dx
        switch direction {
        case .left: return [.delete]
        case .right: return [.insert(" ")]
        case .down: return [.insert("\n")]
        case .up:
            guard contact.layer == .letters, let index = contact.startKey?.letterIndex else { return [] }
            return [.insert(contact.order.letter(at: index).uppercased())]
        }
    }

    mutating func end(_ id: Int, at point: HexPoint, time: Double) -> [KeyboardAction] {
        var actions = move(id, to: point)
        actions += advance(id, time: time)
        guard let contact = contacts.removeValue(forKey: id) else { return actions }
        if let popup = contact.popup {
            switch popup.selection(at: point) {
            case .punctuation(let value): actions.append(.insert(value))
            case .nextKeyboard: actions.append(.nextKeyboard)
            case nil: break
            }
        } else if !contact.consumed && contact.direction == nil, let key = geometry.key(at: point) {
            if key.isLayer { layer = layer == .letters ? .symbols : .letters }
            else { actions.append(.insert(keyLabel(key, layer: contact.layer, order: contact.order))) }
        }
        return actions
    }

    mutating func cancel(_ id: Int) { contacts.removeValue(forKey: id) }
    mutating func cancelAll() { contacts.removeAll() }
}
