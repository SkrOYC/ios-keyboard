import SwiftUI
import UIKit

/// Renders native glass shapes while UIKit retains every touch and accessible key.
final class HexGlassRendererView: UIView {
    private var content: (UIView & UIContentView)?
    private var items: [HexGlassItem] = []
    private var pressed: Set<Int> = []
    private var obscured: Set<Int> = []
    private var surfaces: [HexGlassSurface] = []
    private let materializes: Bool
    private var renderedSize = CGSize.zero
    private var renderedSlots: Set<Int> = []

    init(materializes: Bool = false) {
        self.materializes = materializes
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("Use init()") }

    func update(geometry: HexGeometry, slots: Set<Int>, labels: [UILabel]) {
        let surfaces = geometry.keys.filter { slots.contains($0.slot) }.map { key in
            HexGlassSurface(id: key.slot, polygon: geometry.polygon(of: key),
                            stroke: geometry.stroke, label: labels[key.slot])
        }
        update(surfaces: surfaces, size: CGSize(width: geometry.width, height: geometry.height))
    }

    func update(surfaces: [HexGlassSurface], size: CGSize) {
        content?.frame = bounds
        guard size != renderedSize || surfaces != self.surfaces else { return }
        renderedSize = size
        renderedSlots = Set(surfaces.map(\.id))
        self.surfaces = surfaces
        items = surfaces.map { surface in
            let polygon = UIBezierPath()
            for (index, point) in surface.polygon.enumerated() {
                let position = CGPoint(x: point.x, y: point.y)
                if index == 0 { polygon.move(to: position) } else { polygon.addLine(to: position) }
            }
            polygon.close()
            let stroke = CGFloat(surface.stroke)
            let frame = polygon.bounds.insetBy(dx: -stroke / 2, dy: -stroke / 2)
            polygon.apply(CGAffineTransform(translationX: -frame.minX, y: -frame.minY))
            let border = polygon.cgPath.copy(strokingWithWidth: stroke, lineCap: .round,
                                             lineJoin: .round, miterLimit: 10)
            return HexGlassItem(id: surface.id, frame: frame,
                                footprint: polygon.cgPath.union(border), label: surface.label)
        }
        for item in items { item.label.isHidden = obscured.contains(item.id) }
        render()
    }

    func setFeedback(pressed slots: Set<Int>, obscured hidden: Set<Int> = []) {
        let visible = slots.intersection(renderedSlots)
        let covered = hidden.intersection(renderedSlots)
        guard visible != pressed || covered != obscured else { return }
        pressed = visible
        obscured = covered
        for item in items { item.label.isHidden = covered.contains(item.id) }
        render()
    }

    private func render() {
        guard renderedSize.width > 0, renderedSize.height > 0 else { return }
        let canvas = HexGlassCanvas(items: items, pressed: pressed, obscured: obscured,
                                    size: renderedSize, materializes: materializes)
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

struct HexGlassSurface: Equatable {
    let id: Int
    let polygon: [HexPoint]
    let stroke: Double
    let label: UILabel

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.polygon == rhs.polygon && lhs.stroke == rhs.stroke && lhs.label === rhs.label
    }
}

private struct HexGlassItem: Identifiable {
    let id: Int
    let frame: CGRect
    let footprint: CGPath
    let label: UILabel
}

private struct HexGlassCanvas: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var effects
    @State private var appeared = false
    let items: [HexGlassItem]
    let pressed: Set<Int>
    let obscured: Set<Int>
    let size: CGSize
    let materializes: Bool

    init(items: [HexGlassItem], pressed: Set<Int>, obscured: Set<Int>, size: CGSize, materializes: Bool) {
        self.items = items
        self.pressed = pressed
        self.obscured = obscured
        self.size = size
        self.materializes = materializes
    }

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            ZStack {
                ForEach(items) { item in
                    let down = pressed.contains(item.id)
                    let material: Glass = appeared || !materializes
                        ? (down ? .regular.tint(.blue.opacity(0.18)) : .regular) : .identity
                    HexGlassLabel(label: item.label)
                        .opacity(obscured.contains(item.id) ? 0 : 1)
                        .frame(width: item.frame.width, height: item.frame.height)
                        .glassEffect(material, in: HexGlassFootprint(outline: item.footprint, size: item.frame.size))
                        .glassEffectID(item.id, in: effects)
                        .scaleEffect(down && !reduceMotion ? 0.975 : 1)
                        .position(x: item.frame.midX, y: item.frame.midY)
                        .animation(reduceMotion ? nil : .easeOut(duration: down ? 0.08 : 0.16), value: down)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .environment(\.layoutDirection, .leftToRight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard materializes else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) { appeared = true }
        }
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
