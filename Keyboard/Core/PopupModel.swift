import Foundation

enum PopupChoice: Equatable {
    case punctuation(String)
    case nextKeyboard

    var label: String {
        switch self {
        case .punctuation(let value): return value
        case .nextKeyboard: return "🌐"
        }
    }
}

struct PopupModel {
    struct Entry {
        let choice: PopupChoice
        let center: HexPoint
    }
    let entries: [Entry]
    let apothem: Double
    let horizontalScale: Double

    init(geometry: HexGeometry, includesGlobe: Bool) {
        apothem = geometry.apothem * 0.62
        horizontalScale = geometry.horizontalScale
        let period = geometry.center(of: HexKey(slot: 27))
        let step = 2 * (apothem / HexGeometry.cosine30 * horizontalScale) + 14 * geometry.width / HexGeometry.designWidth
        var choices = [",", "?", "!", "'"].map { PopupChoice.punctuation($0) }
        if includesGlobe { choices.append(.nextKeyboard) }
        entries = choices.enumerated().map { index, choice in
            Entry(choice: choice, center: HexPoint(x: period.x - Double(index) * step,
                                                   y: period.y - 1.2 * geometry.distance))
        }
    }

    func selection(at point: HexPoint) -> PopupChoice? {
        entries.map { entry in
            (entry.choice, hypot((point.x - entry.center.x) / horizontalScale, point.y - entry.center.y))
        }.filter { $0.1 < 1.1 * apothem }.min { $0.1 < $1.1 }?.0
    }
}
