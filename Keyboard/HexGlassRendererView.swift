import SwiftUI
import UIKit

/// Renders native glass shapes while UIKit retains every touch and accessible key.
final class HexGlassRendererView: UIView {
    private var content: (UIView & UIContentView)?
    private var items: [HexGlassItem] = []
    private var pressed: Set<Int> = []
    private var obscured: Set<Int> = []
    private var surfaces: [HexGlassSurface] = []
    var highlightExposure = 1.0 {
        didSet { if oldValue != highlightExposure { render() } }
    }
    private var renderedSize = CGSize.zero
    private var renderedSlots: Set<Int> = []

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: HexGlassRendererView, _: UITraitCollection) in
            view.render()
        }
    }

    required init?(coder: NSCoder) { fatalError("Use init()") }

    func update(geometry: HexGeometry, labels: [UILabel]) {
        let surfaces = geometry.placedKeys.enumerated().map { index, placed in
            HexGlassSurface(id: index, polygon: placed.polygon,
                            stroke: geometry.stroke, label: labels[index])
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
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        layer.preferredDynamicRange = lowPower ? .constrainedHigh : .high
        let hdr = !lowPower && (window?.screen.currentEDRHeadroom ?? 1) > 1
            && (window?.screen.potentialEDRHeadroom ?? 1) > 1
        let canvas = HexGlassCanvas(items: items, pressed: pressed, obscured: obscured,
                                    size: renderedSize, accent: Color(uiColor: tintColor),
                                    exposure: highlightExposure, hdr: hdr)
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
        content?.layer.preferredDynamicRange = lowPower ? .constrainedHigh : .high
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        render()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        render()
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
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var effects
    let items: [HexGlassItem]
    let pressed: Set<Int>
    let obscured: Set<Int>
    let size: CGSize
    let accent: Color
    let exposure: Double
    let hdr: Bool

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            ZStack {
                ForEach(items) { item in
                    let down = pressed.contains(item.id)
                    let shape = HexGlassFootprint(outline: item.footprint, size: item.frame.size)
                    HexGlassLabel(label: item.label)
                        .opacity(obscured.contains(item.id) ? 0 : 1)
                        .frame(width: item.frame.width, height: item.frame.height)
                        .glassEffect(.regular, in: shape)
                        .overlay {
                            if down {
                                shape.fill(colorScheme == .dark ? Color.white.opacity(0.24) : Color.black.opacity(0.14))
                                if colorScheme == .dark && hdr {
                                    shape.fill(Color(uiColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.16,
                                                                       linearExposure: CGFloat(pow(2, exposure)))))
                                }
                                shape.stroke(accent.opacity(0.8), lineWidth: 2)
                            }
                        }
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
