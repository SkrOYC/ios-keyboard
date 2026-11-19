import UIKit

final class PopupPlateView: UIView {
    private var cells: [UILabel] = []
    private var plate = UIBezierPath()
    private(set) var plateBounds = CGRect.zero

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: PopupPlateView, _: UITraitCollection) in
            view.setNeedsDisplay()
        }
    }

    required init?(coder: NSCoder) { fatalError("Use init()") }

    func update(popup: PopupModel, selected: Int?) {
        while cells.count > popup.entries.count { cells.removeLast().removeFromSuperview() }
        while cells.count < popup.entries.count {
            let label = UILabel()
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.45
            label.isAccessibilityElement = false
            label.layer.masksToBounds = true
            addSubview(label)
            cells.append(label)
        }
        plateBounds = popup.entries.reduce(CGRect.null) { result, entry in
            result.union(CGRect(x: entry.rect.x, y: entry.rect.y, width: entry.rect.width, height: entry.rect.height))
        }
        guard !plateBounds.isNull else { plate = UIBezierPath(); setNeedsDisplay(); return }
        let radius = min(12, popup.cellWidth * 0.12)
        plate = UIBezierPath(roundedRect: plateBounds, cornerRadius: radius)
        if let nearest = popup.entries.first {
            let stem = UIBezierPath()
            stem.move(to: CGPoint(x: nearest.center.x - radius, y: plateBounds.maxY - 1))
            stem.addLine(to: CGPoint(x: popup.stemAnchor.x, y: popup.stemAnchor.y))
            stem.addLine(to: CGPoint(x: nearest.center.x + radius, y: plateBounds.maxY - 1))
            stem.close()
            plate.append(stem)
        }
        for (index, entry) in popup.entries.enumerated() {
            let label = cells[index]
            label.transform = .identity
            label.frame = CGRect(x: entry.rect.x, y: entry.rect.y, width: entry.rect.width, height: entry.rect.height).insetBy(dx: 2, dy: 2)
            label.text = entry.choice == .capsLock ? "⇪" : entry.choice.label
            label.accessibilityLabel = entry.choice.label
            label.font = .systemFont(ofSize: min(26, popup.cellHeight * 0.45), weight: .medium)
            label.textColor = .label
            label.backgroundColor = selected == index ? tintColor.withAlphaComponent(0.25) : .clear
            label.layer.cornerRadius = radius
            label.layer.borderWidth = selected == index ? 2 : 0
            label.layer.borderColor = tintColor.cgColor
            label.transform = selected == index && !UIAccessibility.isReduceMotionEnabled
                ? CGAffineTransform(scaleX: 1.025, y: 1.025) : .identity
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        UIColor.secondarySystemBackground.setFill()
        plate.fill()
        UIColor.separator.setStroke()
        plate.lineWidth = 1
        plate.stroke()
    }
}
