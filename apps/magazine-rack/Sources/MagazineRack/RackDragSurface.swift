import AppKit
import SwiftUI

/// Explicit AppKit dragging survives SwiftUI's hosting-view background hit testing.
struct RackDragSurface:NSViewRepresentable {
    func makeNSView(context:Context)->NSView { DragView() }
    func updateNSView(_ view:NSView,context:Context) {}
    private final class DragView:NSView {
        override var acceptsFirstResponder:Bool {false}
        override var mouseDownCanMoveWindow:Bool {false}
        override func acceptsFirstMouse(for event:NSEvent?)->Bool {true}
        override func resetCursorRects(){addCursorRect(bounds,cursor:.openHand)}
        override func mouseDown(with event:NSEvent){
            guard event.type == .leftMouseDown,let window else{return}
            NSCursor.closedHand.push();defer{NSCursor.pop()}
            window.performDrag(with:event)
        }
        override func accessibilityLabel()->String? {"拖动杂志架"}
        override func isAccessibilityElement()->Bool {true}
        override func accessibilityRole()->NSAccessibility.Role? {.group}
    }
}

/// A small, consistent set of drawn tool marks rather than mismatched font symbols.
struct EngravedControl:View {
    let symbol:String
    let ink:Color
    @State private var hovering=false
    var body:some View {
        Image(nsImage:markImage).renderingMode(.original)
            .opacity(hovering ? 1:0.9)
            .frame(width:28,height:28)
            .contentShape(Rectangle()).onHover{hovering=$0}
            .accessibilityHidden(true)
    }
    private var markImage:NSImage {
        NSImage(size:CGSize(width:12,height:12),flipped:true){rect in
            guard let context=NSGraphicsContext.current?.cgContext else{return false}
            let path=RackToolMark(symbol:symbol).path(in:rect).cgPath
            context.setAlpha(0.62);context.setLineWidth(0.85);context.setLineCap(.round);context.setLineJoin(.round)
            context.saveGState();context.translateBy(x:0,y:0.45)
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.24).cgColor)
            context.addPath(path);context.strokePath();context.restoreGState()
            context.setStrokeColor(NSColor(ink).cgColor);context.addPath(path);context.strokePath()
            return true
        }
    }
}
private struct RackToolMark:Shape {
    let symbol:String
    func path(in rect:CGRect)->Path {
        var p=Path()
        func line(_ points:[CGPoint]) { guard let first=points.first else{return};p.move(to:first);for point in points.dropFirst(){p.addLine(to:point)} }
        switch symbol {
        case "square.grid.2x2":
            // Material samples: a single panel with three diagonal grain cuts.
            p.addRoundedRect(in:CGRect(x:2,y:2,width:12,height:12),cornerSize:CGSize(width:1.4,height:1.4))
            line([CGPoint(x:3,y:8),CGPoint(x:8,y:3)])
            line([CGPoint(x:4,y:12),CGPoint(x:12,y:4)])
            line([CGPoint(x:8,y:13),CGPoint(x:13,y:8)])
        case "slider.horizontal.3":
            // A miniature cover layout, matching the object being edited.
            p.addRoundedRect(in:CGRect(x:2.5,y:1.5,width:11,height:13),cornerSize:CGSize(width:0.8,height:0.8))
            line([CGPoint(x:5,y:5),CGPoint(x:11,y:5)])
            line([CGPoint(x:5,y:7.5),CGPoint(x:11,y:7.5)])
            line([CGPoint(x:5,y:10),CGPoint(x:8,y:10)])
        case "plus":
            // Import into the shelf.
            line([CGPoint(x:2,y:10),CGPoint(x:2,y:14),CGPoint(x:14,y:14),CGPoint(x:14,y:10)])
            line([CGPoint(x:8,y:1),CGPoint(x:8,y:10)])
            line([CGPoint(x:5,y:7),CGPoint(x:8,y:10),CGPoint(x:11,y:7)])
        default:
            // Quiet circular arrows for a new arrangement.
            p.move(to:CGPoint(x:2.5,y:6));p.addCurve(to:CGPoint(x:13,y:4.5),control1:CGPoint(x:4,y:0),control2:CGPoint(x:11,y:0.5))
            line([CGPoint(x:13,y:1),CGPoint(x:13,y:4.5),CGPoint(x:9.5,y:4.5)])
            p.move(to:CGPoint(x:13.5,y:10));p.addCurve(to:CGPoint(x:3,y:11.5),control1:CGPoint(x:12,y:16),control2:CGPoint(x:5,y:15.5))
            line([CGPoint(x:3,y:15),CGPoint(x:3,y:11.5),CGPoint(x:6.5,y:11.5)])
        }
        return p.applying(CGAffineTransform(scaleX:rect.width/16,y:rect.height/16)).offsetBy(dx:rect.minX,dy:rect.minY)
    }
}
struct EngravedGrip:View {
    let ink:Color
    var body:some View {
        HStack(spacing:3.5){
            ForEach(0..<5,id:\.self){_ in
                Capsule().fill(ink.opacity(0.35)).frame(width:1.2,height:10)
                    .shadow(color:.white.opacity(0.55),radius:0.2,x:0.4,y:0.7)
            }
        }.frame(width:45,height:28).allowsHitTesting(false)
    }
}
