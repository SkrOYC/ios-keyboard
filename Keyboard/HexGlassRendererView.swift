import SwiftUI
import UIKit

/// Renders native glass shapes while UIKit retains every touch and accessible key.
final class HexGlassRendererView: UIView {
    private var content: (UIView & UIContentView)?
    private var items: [HexGlassItem] = []
    private var pressed: Set<Int> = []
    private var renderedSize = CGSize.zero
    private var renderedSlots: Set<Int> = []

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("Use init()") }

    func update(geometry: HexGeometry, slots: Set<Int>, labels: [UILabel]) {
        let size = CGSize(width: geometry.width, height: geometry.height)
        content?.frame = bounds
        guard size != renderedSize || slots != renderedSlots else { return }
        renderedSize = size
        renderedSlots = slots
        items = geometry.keys.filter { slots.contains($0.slot) }.map { key in
            let polygon = UIBezierPath()
            for (index, point) in geometry.polygon(of: key).enumerated() {
                let position = CGPoint(x: point.x, y: point.y)
                if index == 0 { polygon.move(to: position) } else { polygon.addLine(to: position) }
            }
            polygon.close()
            let stroke = CGFloat(geometry.stroke)
            let frame = polygon.bounds.insetBy(dx: -stroke / 2, dy: -stroke / 2)
            polygon.apply(CGAffineTransform(translationX: -frame.minX, y: -frame.minY))
            let border = polygon.cgPath.copy(strokingWithWidth: stroke, lineCap: .round,
                                             lineJoin: .round, miterLimit: 10)
            return HexGlassItem(id: key.slot, frame: frame,
                                footprint: polygon.cgPath.union(border), label: labels[key.slot])
        }
        render()
    }

    func setPressed(_ slots: Set<Int>) {
        let visible = slots.intersection(renderedSlots)
        guard visible != pressed else { return }
        pressed = visible
        render()
    }

    private func render() {
        guard renderedSize.width > 0, renderedSize.height > 0 else { return }
        let canvas = HexGlassCanvas(items: items, pressed: pressed, size: renderedSize)
        let configuration = UIHostingConfiguration { canvas }
            .margins(.all, 0).minSize(width: 0, height: 0)
        if let content {
            content.configuration = configuration
        } else {
            let view = configuration.makeContentView()
            view.backgroundColor = .clear
            view.isOpaque = false
            view.isUserInteractionEnabled = false
            view.accessibilityElementsHidden = true
            addSubview(view)
            content = view
        }
        content?.frame = bounds
    }
}

private struct HexGlassItem: Identifiable {
    let id: Int
    let frame: CGRect
    let footprint: CGPath
    let label: UILabel
}

private struct HexGlassCanvas: View {
    let items: [HexGlassItem]
    let pressed: Set<Int>
    let size: CGSize

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            ZStack {
                ForEach(items) { item in
                    HexGlassLabel(label: item.label)
                        .frame(width: item.frame.width, height: item.frame.height)
                        .glassEffect(pressed.contains(item.id) ? .regular.tint(.blue.opacity(0.18)) : .regular,
                                     in: HexGlassFootprint(outline: item.footprint, size: item.frame.size))
                        .position(x: item.frame.midX, y: item.frame.midY)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .environment(\.layoutDirection, .leftToRight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct HexGlassFootprint: Shape {
    let outline: CGPath
    let size: CGSize

    func path(in rect: CGRect) -> Path {
        let transform = CGAffineTransform(a: rect.width / size.width, b: 0, c: 0,
                                          d: rect.height / size.height, tx: rect.minX, ty: rect.minY)
        return Path(outline).applying(transform)
    }
}

private struct HexGlassLabel: UIViewRepresentable {
    let label: UILabel

    func makeUIView(context: Context) -> UILabel { label }
    func updateUIView(_ view: UILabel, context: Context) {}
}
