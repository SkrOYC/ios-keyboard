import Foundation

enum PopupChoice: Equatable {
    case punctuation(String)
    case nextKeyboard
    case capsLock
    case presets

    var label: String {
        switch self {
        case .punctuation(let value): return value
        case .nextKeyboard: return "🌐"
        case .capsLock: return "Caps lock"
        case .presets: return "Presets"
        }
    }
}

struct PopupModel {
    struct CellRect: Equatable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        var polygon: [HexPoint] {
            [HexPoint(x: x, y: y), HexPoint(x: x + width, y: y),
             HexPoint(x: x + width, y: y + height), HexPoint(x: x, y: y + height)]
        }
    }
    struct Entry {
        let choice: PopupChoice
        let center: HexPoint
        let rect: CellRect
    }
    let entries: [Entry]
    let stemAnchor: HexPoint
    let origin: HexPoint
    let columns: Int
    let rows: Int
    let cellWidth: Double
    let cellHeight: Double
    let cancelSlop: Double
    let inwardSign: Double

    init(geometry: HexGeometry, includesGlobe: Bool, origin: HexPoint? = nil,
         tuning: KeyboardTuning = KeyboardTuning()) {
        var choices = [",", "?", "!", "'"].map { PopupChoice.punctuation($0) }
        if includesGlobe { choices.append(.nextKeyboard) }
        let anchor = geometry.center(of: HexKey(slot: 27))
        self.init(choices: choices, columns: choices.count, anchor: anchor, origin: origin ?? anchor,
                  cellWidth: geometry.columnPitch, cellHeight: geometry.distance,
                  inwardSign: -1, cancelSlop: tuning.cancelSlop * geometry.scale)
    }

    init(choices: [PopupChoice], columns: Int, anchor: HexPoint, origin: HexPoint,
         cellWidth: Double, cellHeight: Double, inwardSign: Double, cancelSlop: Double) {
        precondition(columns > 0 && cellWidth > 0 && cellHeight > 0)
        precondition(inwardSign == -1 || inwardSign == 1)
        self.columns = columns
        rows = (choices.count + columns - 1) / columns
        self.stemAnchor = anchor
        self.origin = origin
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight
        self.inwardSign = inwardSign
        self.cancelSlop = cancelSlop
        entries = choices.enumerated().map { index, choice in
            let center = HexPoint(x: anchor.x + inwardSign * Double(index % columns) * cellWidth,
                                  y: anchor.y - Double(index / columns + 1) * cellHeight)
            return Entry(choice: choice, center: center,
                         rect: CellRect(x: center.x - cellWidth / 2, y: center.y - cellHeight / 2,
                                        width: cellWidth, height: cellHeight))
        }
    }

    func selectedIndex(at point: HexPoint) -> Int? {
        let dx = point.x - origin.x, dy = point.y - origin.y
        guard !entries.isEmpty, abs(dx) > cancelSlop || abs(dy) > cancelSlop else { return nil }
        let column = Int(max(0, min(Double(columns - 1), (inwardSign * dx / cellWidth).rounded())))
        let row = Int(max(0, min(Double(rows - 1), (-dy / cellHeight - 1).rounded())))
        return min(entries.count - 1, row * columns + column)
    }

    func selection(at point: HexPoint) -> PopupChoice? {
        selectedIndex(at: point).map { entries[$0].choice }
    }
}
