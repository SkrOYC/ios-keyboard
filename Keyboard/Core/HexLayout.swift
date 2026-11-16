import Foundation

/// Choose the key area independently of the debug strip and system keyboard controls.
struct HexLayout {
    let width: Double
    let height: Double
    let originX: Double

    init(containerWidth: Double, leadingInset: Double = 0, trailingInset: Double = 0,
         compactHeight: Bool, tablet: Bool) {
        let available = max(1, containerWidth - leadingInset - trailingInset)
        width = tablet ? min(700, available) : available
        height = compactHeight ? 180 : min(320, width * HexGeometry.designHeight / HexGeometry.designWidth)
        originX = leadingInset + (available - width) / 2
    }
}
