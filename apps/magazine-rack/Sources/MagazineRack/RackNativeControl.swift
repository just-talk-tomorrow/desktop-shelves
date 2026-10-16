import AppKit
import SwiftUI

/// Transparent but fully hittable native overlay for artwork-baked controls.
/// Explicit first-mouse handling also works on an inactive desktop-level panel.
struct RackNativeControl:NSViewRepresentable {
    let label:String
    let action:(NSView)->Void
    func makeNSView(context:Context)->HitView {HitView(label:label,action:action)}
    func updateNSView(_ view:HitView,context:Context){view.action=action;view.toolTip=label}
    final class HitView:NSView {
        var action:(NSView)->Void
        let label:String
        private var hovered=false
        private var tracking:NSTrackingArea?
        init(label:String,action:@escaping(NSView)->Void){self.label=label;self.action=action;super.init(frame:.zero);toolTip=label}
        required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
        override func acceptsFirstMouse(for event:NSEvent?)->Bool {true}
        override var mouseDownCanMoveWindow:Bool {false}
        override func resetCursorRects(){addCursorRect(bounds,cursor:.pointingHand)}
        override func updateTrackingAreas(){
            if let tracking {removeTrackingArea(tracking)}
            let next=NSTrackingArea(rect:.zero,options:[.mouseEnteredAndExited,.activeAlways,.inVisibleRect],owner:self,userInfo:nil)
            addTrackingArea(next);tracking=next;super.updateTrackingAreas()
        }
        override func mouseEntered(with event:NSEvent){hovered=true;needsDisplay=true}
        override func mouseExited(with event:NSEvent){hovered=false;needsDisplay=true}
        override func draw(_ dirtyRect:NSRect){
            guard hovered else{return}
            NSColor.labelColor.withAlphaComponent(0.08).setFill()
            NSBezierPath(roundedRect:bounds.insetBy(dx:1,dy:1),xRadius:4,yRadius:4).fill()
        }
        override func mouseDown(with event:NSEvent){action(self)}
        override func isAccessibilityElement()->Bool {true}
        override func accessibilityRole()->NSAccessibility.Role? {.button}
        override func accessibilityLabel()->String? {label}
        override func accessibilityPerformPress()->Bool {action(self);return true}
    }
}
final class RackMenuItem:NSMenuItem {
    private let callback:()->Void
    init(_ title:String,selected:Bool=false,action:@escaping()->Void){
        callback=action;super.init(title:title,action:#selector(run),keyEquivalent:"");target=self;state=selected ? .on:.off
    }
    required init(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
    @objc private func run(){callback()}
}
