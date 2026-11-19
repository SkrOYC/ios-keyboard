import Foundation

struct HexPoint: Codable, Equatable {
    var x: Double
    var y: Double

    func distance(to other: HexPoint) -> Double { hypot(x - other.x, y - other.y) }
}

struct HexKey: Equatable {
    let slot: Int
    var column: Int { slot / 4 }
    var row: Int { slot % 4 }
    var isLayer: Bool { slot == 3 }
    var isPeriod: Bool { slot == 27 }
    var letterIndex: Int? {
        guard !isLayer && !isPeriod else { return nil }
        return slot < 3 ? slot : slot - 1
    }
}

/// Coordinates are points when initialized with view dimensions, design units otherwise.
struct HexGeometry {
    static let designWidth = 1320.0
    static let designHeight = 883.0
    static let cosine30 = cos(Double.pi / 6)
    let width: Double
    let height: Double
    let gap: Double
    let apothem: Double
    let distance: Double
    let horizontalScale: Double
    let radius: Double
    let x0: Double
    let y0: Double
    let stroke: Double
    let columnPitch: Double
    let scale: Double
    private var leftOffset = 0.0
    private var rightOffset = 0.0
    private var split = false
    let keys = (0..<28).map { HexKey(slot: $0) }

    struct PlacedKey {
        let key: HexKey
        let center: HexPoint
        let polygon: [HexPoint]
        let isDuplicate: Bool
        var slot: Int { key.slot }
    }

    var placedKeys: [PlacedKey] {
        keys.map { key in
            let point = center(of: key)
            return PlacedKey(key: key, center: point,
                             polygon: polygon(center: point, apothem: apothem - stroke / 2), isDuplicate: false)
        } + (split ? (12..<16).map { slot in
            let key = HexKey(slot: slot)
            var point = center(of: key)
            point.x += rightOffset - leftOffset
            return PlacedKey(key: key, center: point,
                             polygon: polygon(center: point, apothem: apothem - stroke / 2), isDuplicate: true)
        } : [])
    }

    init(layout: HexLayout) {
        self.init(width: layout.width, height: layout.height)
        split = layout.isSplit
        leftOffset = split ? 0 : (layout.width - 1320 * scale) / 2
        rightOffset = split ? layout.width - 1320 * scale : leftOffset
    }

    init(width: Double = HexGeometry.designWidth, height: Double = HexGeometry.designHeight) {
        precondition(width > 0 && height > 0)
        self.width = width
        let scale = min(width / Self.designWidth, height / Self.designHeight)
        self.scale = scale
        self.height = Self.designHeight * scale
        gap = 8 * scale
        stroke = 12 * scale
        let footprintHeight = Self.designHeight * scale - 28 * scale
        let footprintWidth = Self.designWidth * scale - 28 * scale
        apothem = (footprintHeight - 3.5 * gap) / 9
        distance = 2 * apothem + gap
        let pitch = 0.8660254 * distance
        horizontalScale = footprintWidth / (6 * pitch + 2 * apothem / Self.cosine30)
        radius = apothem / Self.cosine30 * horizontalScale
        columnPitch = pitch * horizontalScale
        x0 = (Self.designWidth * scale - (6 * columnPitch + 2 * radius)) / 2 + radius
        y0 = 14 * scale + apothem
        leftOffset = (width - Self.designWidth * scale) / 2
        rightOffset = leftOffset
    }

    func center(of key: HexKey) -> HexPoint {
        HexPoint(x: x0 + Double(key.column) * columnPitch + (key.column <= 3 ? leftOffset : rightOffset),
                 y: y0 + Double(key.row) * distance + (key.column.isMultiple(of: 2) ? 0 : distance / 2))
    }

    func polygon(center: HexPoint, apothem: Double) -> [HexPoint] {
        let r = apothem / Self.cosine30 * horizontalScale
        return [(r, 0.0), (r / 2, apothem), (-r / 2, apothem),
                (-r, 0.0), (-r / 2, -apothem), (r / 2, -apothem)].map {
            HexPoint(x: center.x + $0.0, y: center.y + $0.1)
        }
    }

    func polygon(of key: HexKey) -> [HexPoint] {
        polygon(center: center(of: key), apothem: apothem - stroke / 2)
    }

    /// Match the filled polygon and its round-join stroke; visible gaps stay inert.
    func key(at point: HexPoint) -> HexKey? {
        placedKeys.first { placed in
            let vertices = placed.polygon
            var inside = true
            var edgeDistance = Double.infinity
            for index in vertices.indices {
                let a = vertices[index], b = vertices[(index + 1) % vertices.count]
                let dx = b.x - a.x, dy = b.y - a.y
                if dx * (point.y - a.y) - dy * (point.x - a.x) < 0 { inside = false }
                let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / (dx * dx + dy * dy)))
                edgeDistance = min(edgeDistance, point.distance(to: HexPoint(x: a.x + t * dx, y: a.y + t * dy)))
            }
            return inside || edgeDistance <= stroke / 2
        }?.key
    }
}
