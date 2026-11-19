import Foundation

enum KeyboardAction: Equatable {
    case insert(String)
    case delete
    case nextKeyboard
    case showPicker
    case moveCursor(graphemes: Int)
}

struct TouchMachine {
    var tuning = KeyboardTuning()
    var repeatDistance: Double { max(40.0, 0.9 * tuning.swipeThreshold) }

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
        var trackpadOrigin: HexPoint?
        var cursorSteps = 0
    }

    var geometry: HexGeometry
    var layer = KeyboardLayer.letters
    var order = LetterOrder.familiar
    var needsGlobe = false
    private(set) var capsLock = false
    private(set) var contacts: [Int: Contact] = [:]
    var scale: Double { geometry.scale }
    var isTrackpadActive: Bool { contacts.values.contains { $0.trackpadOrigin != nil } }

    mutating func begin(_ id: Int, at point: HexPoint, time: Double) {
        contacts[id] = Contact(start: point, location: point, startKey: geometry.key(at: point),
                               layer: layer, order: order, began: time)
    }

    mutating func advance(_ id: Int, time: Double) -> [KeyboardAction] {
        guard var contact = contacts[id], !contact.consumed, contact.direction == nil,
              contact.holdAllowed, time - contact.began >= tuning.holdMilliseconds / 1000 else { return [] }
        if contact.startKey?.isPeriod == true {
            contact.popup = PopupModel(geometry: geometry, includesGlobe: needsGlobe, origin: contact.start, tuning: tuning)
            contact.consumed = true
        } else if contact.startKey?.isLayer == true {
            contact.consumed = true
            contact.trackpadOrigin = contact.location
        }
        contacts[id] = contact
        return []
    }

    mutating func move(_ id: Int, to point: HexPoint) -> [KeyboardAction] {
        guard var contact = contacts[id] else { return [] }
        contact.location = point
        defer { contacts[id] = contact }
        if let origin = contact.trackpadOrigin {
            let dx = point.x - origin.x
            let steps = abs(dx) <= tuning.cancelSlop * scale ? 0 : Int(dx / (tuning.trackpadUnitsPerCharacter * scale))
            let delta = steps - contact.cursorSteps
            contact.cursorSteps = steps
            return delta == 0 ? [] : [.moveCursor(graphemes: delta)]
        }
        guard !contact.consumed else { return [] }
        let dx = point.x - contact.start.x, dy = point.y - contact.start.y
        let travel = hypot(dx, dy)
        if abs(dx) > tuning.cancelSlop * scale || abs(dy) > tuning.cancelSlop * scale { contact.holdAllowed = false }
        if let direction = contact.direction {
            guard direction == .left else { return [] }
            var result: [KeyboardAction] = []
            while dx <= contact.nextDeleteX - repeatDistance * scale {
                contact.nextDeleteX -= repeatDistance * scale
                result.append(.delete)
            }
            return result
        }
        guard travel >= tuning.swipeThreshold * scale else { return [] }
        let direction: Direction = abs(dx) >= abs(dy) ? (dx < 0 ? .left : .right) : (dy < 0 ? .up : .down)
        contact.direction = direction
        contact.nextDeleteX = dx
        switch direction {
        case .left: return [.delete]
        case .right: return [.insert(" ")]
        case .down: return [.insert("\n")]
        case .up:
            if contact.startKey?.isLayer == true {
                contact.popup = PopupModel(choices: [.capsLock, .presets], columns: 2,
                    anchor: geometry.center(of: HexKey(slot: 3)), origin: contact.start,
                    cellWidth: geometry.columnPitch, cellHeight: geometry.distance,
                    inwardSign: 1, cancelSlop: tuning.cancelSlop * scale)
                contact.consumed = true
                return []
            }
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
            case .capsLock: capsLock.toggle()
            case .presets: actions.append(.showPicker)
            case nil: break
            }
        } else if !contact.consumed && contact.direction == nil, let key = geometry.key(at: point) {
            if key.isLayer { layer = layer == .letters ? .symbols : .letters }
            else { actions.append(.insert(keyLabel(key, layer: contact.layer, order: contact.order, capsLock: capsLock))) }
        }
        return actions
    }

    mutating func cancel(_ id: Int) { contacts.removeValue(forKey: id) }
    mutating func cancelAll() { contacts.removeAll() }
    mutating func resetCapsLock() { capsLock = false }
    mutating func toggleCapsLock() { capsLock.toggle() }
}
