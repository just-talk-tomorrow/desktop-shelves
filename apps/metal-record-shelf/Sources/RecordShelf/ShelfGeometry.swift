import Foundation

enum ShelfGeometry {
    // Match the large photo widget in the user's reference: two 164pt
    // widgets plus a 16pt gutter, with a 16pt visible desktop inset.
    static let cabinetWidth: CGFloat = 344
    static let scale: CGFloat = cabinetWidth / 360
    static let cabinetHeight: CGFloat = 436 * scale
    static let padding: CGFloat = 20
    static let panelWidth: CGFloat = cabinetWidth + padding * 2
    static let panelHeight: CGFloat = cabinetHeight + padding * 2
    static func visibleCabinet(in panel: CGRect) -> CGRect {
        CGRect(x: panel.minX + padding, y: panel.minY + padding, width: cabinetWidth, height: cabinetHeight)
    }
    static func alignedFrame(in area: CGRect, previous: CGRect? = nil) -> CGRect {
        let previousTop = previous?.maxY ?? (area.minY + 18 + 476)
        let y = min(max(previousTop - panelHeight, area.minY - padding), area.maxY - panelHeight + padding)
        return CGRect(x: area.minX + 16 - padding, y: y, width: panelWidth, height: panelHeight)
    }
}
