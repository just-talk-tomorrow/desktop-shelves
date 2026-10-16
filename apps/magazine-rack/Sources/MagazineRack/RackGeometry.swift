import Foundation

/// Match macOS's two 164pt tiles and a 16pt gutter. Shadows never define alignment.
enum RackGeometry {
    static let standard:CGFloat=344
    static let shadowInset:CGFloat=44
    static let gutter:CGFloat=16
    static func panelSize(for width:CGFloat)->CGSize { CGSize(width:width+shadowInset*2,height:width+shadowInset*2) }
    static func visibleFrame(in panel:CGRect)->CGRect {panel.insetBy(dx:shadowInset,dy:shadowInset)}
    static func panelFrame(for visible:CGRect)->CGRect {visible.insetBy(dx:-shadowInset,dy:-shadowInset)}
    static func alignedFrame(in area:CGRect,height:CGFloat=standard,width:CGFloat=standard)->CGRect {
        let secondColumn=area.width >= standard*2+gutter*3
        let x=area.minX+gutter+(secondColumn ? standard+gutter:0)
        let visible=CGRect(x:x,y:area.maxY-gutter-height,width:width,height:height)
        return panelFrame(for:visible)
    }
    static func fittedFrame(_ frame:CGRect,in area:CGRect,width:CGFloat,height:CGFloat?=nil)->CGRect {
        let height=height ?? width
        let old=visibleFrame(in:frame)
        let x=min(max(old.minX,area.minX),max(area.minX,area.maxX-width))
        let top=min(max(old.maxY,area.minY+height),area.maxY)
        return panelFrame(for:CGRect(x:x,y:top-height,width:width,height:height))
    }
}
