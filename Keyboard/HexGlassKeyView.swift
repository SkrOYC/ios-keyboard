import UIKit

/// A native material surface whose mask follows the same footprint as Core hit-testing.
final class HexGlassKeyView: UIView {
    let label = UILabel()
    private let glass = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
    private let footprintMask = HexMaterialMaskView()
    private let rim = CAGradientLayer()
    private let rimMask = CAShapeLayer()
    private let restingEffect = UIGlassEffect(style: .regular)
    private let pressedEffect = UIGlassEffect(style: .regular)
    private var pressed = false

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        glass.isUserInteractionEnabled = false
        glass.cornerConfiguration = .corners(radius: .fixed(0))
        addSubview(glass)
        label.textAlignment = .center
        label.textColor = .label
        label.isUserInteractionEnabled = false
        label.isAccessibilityElement = false
        glass.contentView.addSubview(label)
        pressedEffect.tintColor = UIColor.systemBlue.withAlphaComponent(0.18)
        rim.startPoint = CGPoint(x: 0.15, y: 0)
        rim.endPoint = CGPoint(x: 0.85, y: 1)
        rimMask.fillColor = UIColor.clear.cgColor
        rimMask.strokeColor = UIColor.white.cgColor
        rimMask.lineJoin = .round
        rim.mask = rimMask
        layer.addSublayer(rim)
    }

    required init?(coder: NSCoder) { fatalError("Use init()") }

    func update(polygon: [HexPoint], stroke: Double) {
        let global = UIBezierPath()
        for (index, point) in polygon.enumerated() {
            let position = CGPoint(x: point.x, y: point.y)
            if index == 0 { global.move(to: position) } else { global.addLine(to: position) }
        }
        global.close()
        let width = CGFloat(stroke)
        let footprint = global.bounds.insetBy(dx: -width / 2, dy: -width / 2)
        frame = footprint
        let local = UIBezierPath(cgPath: global.cgPath)
        local.apply(CGAffineTransform(translationX: -footprint.minX, y: -footprint.minY))
        glass.frame = bounds
        label.frame = glass.bounds
        footprintMask.frame = glass.bounds
        footprintMask.shape.path = local.cgPath
        footprintMask.shape.lineWidth = width
        // UIVisualEffectView copies its mask; reassign after every geometry change.
        glass.mask = footprintMask
        rim.frame = bounds
        rimMask.frame = bounds
        rimMask.path = local.cgPath
        rimMask.lineWidth = max(0.75, width * 0.18)
        rim.colors = [
            UIColor.white.withAlphaComponent(0.8).cgColor,
            UIColor.white.withAlphaComponent(0.06).cgColor,
            UIColor.white.withAlphaComponent(0.35).cgColor
        ]
    }

    func setPressed(_ value: Bool) {
        guard value != pressed else { return }
        pressed = value
        glass.effect = value ? pressedEffect : restingEffect
    }
}

private final class HexMaterialMaskView: UIView {
    override class var layerClass: AnyClass { CAShapeLayer.self }
    var shape: CAShapeLayer { layer as! CAShapeLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        shape.fillColor = UIColor.white.cgColor
        shape.strokeColor = UIColor.white.cgColor
        shape.lineJoin = .round
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }
}
