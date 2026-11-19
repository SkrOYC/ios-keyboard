import Foundation

struct HexLayout {
    let width: Double
    let height: Double
    let originX: Double
    let scale: Double
    let isSplit: Bool

    init(containerWidth: Double, leadingInset: Double = 0, trailingInset: Double = 0,
         shorterSide: Double, tablet: Bool, tuning: KeyboardTuning? = nil) {
        let tuning = tuning ?? KeyboardTuning(tablet: tablet)
        width = max(1, containerWidth - leadingInset - trailingInset)
        originX = leadingInset
        isSplit = tuning.layoutMode == .split || (tuning.layoutMode == .auto && width >= tuning.splitWidthThreshold)
        let reference = HexGeometry()
        let halfWidth = reference.center(of: HexKey(slot: 12)).x + reference.radius
        let desired = isSplit ? max(1, min(shorterSide, 430)) / 1320 * tuning.splitKeyScale : width / 1320
        scale = min(desired, tuning.heightBudget / 883, isSplit ? width / (2 * halfWidth) : width / 1320)
        height = 883 * scale
    }

    var geometry: HexGeometry { HexGeometry(layout: self) }
}
