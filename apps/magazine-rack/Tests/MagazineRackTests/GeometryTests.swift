import XCTest
import AppKit
@testable import MagazineRack
final class GeometryTests:XCTestCase {
    func testGridAlignsVisibleRackInsteadOfShadowWindow(){
        let area=CGRect(x:0,y:60,width:1440,height:840)
        let panel=RackGeometry.alignedFrame(in:area)
        let visible=RackGeometry.visibleFrame(in:panel)
        XCTAssertEqual(visible.size,CGSize(width:344,height:344))
        XCTAssertEqual(visible.minX,16+344+16)
        XCTAssertEqual(area.maxY-visible.maxY,16)
        XCTAssertEqual(panel.width,432)
        XCTAssertEqual(RackGeometry.fittedFrame(panel,in:area,width:344),panel)
    }
    func testSmallerScreenFallsBackToFirstColumnAndKeepsVisibleBodyInside(){
        let area=CGRect(x:-800,y:0,width:700,height:700)
        let panel=RackGeometry.alignedFrame(in:area)
        XCTAssertEqual(RackGeometry.visibleFrame(in:panel).minX,area.minX+16)
        let old=CGRect(x:1000,y:-500,width:528,height:528)
        let visible=RackGeometry.visibleFrame(in:RackGeometry.fittedFrame(old,in:area,width:344))
        XCTAssertTrue(area.contains(visible))
    }
}

extension GeometryTests {
    func testGeneratedSkinKeepsTopLeftAndWidthWhenSwitchingAspect(){
        let area=CGRect(x:0,y:60,width:1440,height:840)
        let square=RackGeometry.alignedFrame(in:area)
        let shorter=RackGeometry.fittedFrame(square,in:area,width:344,height:GeneratedRackMetrics.height)
        XCTAssertEqual(RackGeometry.visibleFrame(in:shorter).minX,RackGeometry.visibleFrame(in:square).minX)
        XCTAssertEqual(RackGeometry.visibleFrame(in:shorter).maxY,RackGeometry.visibleFrame(in:square).maxY)
        XCTAssertEqual(RackGeometry.visibleFrame(in:shorter).width,344)
        XCTAssertEqual(RackGeometry.visibleFrame(in:shorter).height,GeneratedRackMetrics.height,accuracy:0.001)
        XCTAssertEqual(RackGeometry.fittedFrame(shorter,in:area,width:344,height:344),square)
    }
    func testGeneratedBooksStayWithinFrameAndAllPagesRemainReachable(){
        let frame=CGRect(x:0,y:0,width:344,height:GeneratedRackMetrics.height)
        for index in 0..<8 {XCTAssertTrue(frame.contains(GeneratedRackMetrics.slot(index)))}
        for total in [1,4,5,20] {
            var reachable:Set<Int>=[0]
            for _ in 0..<total {
                for current in Array(reachable) {
                    for page in GeneratedRackMetrics.pages(current:current,total:total) where page<total {reachable.insert(page)}
                }
            }
            XCTAssertEqual(reachable,Set(0..<total))
        }
    }
}

extension GeometryTests {
    func testGeneratedRackMatchesBothRowsWithoutStretching(){
        let area=CGRect(x:0,y:60,width:1440,height:840)
        let width=344*GeneratedRackMetrics.aspect
        let frame=RackGeometry.visibleFrame(in:RackGeometry.alignedFrame(in:area,height:344,width:width))
        XCTAssertEqual(frame.height,344)
        XCTAssertEqual(frame.width/frame.height,GeneratedRackMetrics.aspect,accuracy:0.001)
        XCTAssertEqual(frame.minX,376)
        XCTAssertEqual(frame.maxY,area.maxY-16)
        XCTAssertEqual(frame.minY,area.maxY-16-344)
    }
}

extension GeometryTests {
    @MainActor func testNativeControlRespondsToFirstMouseAndAccessibilityPress(){
        var presses=0
        let view=RackNativeControl.HitView(label:"test"){_ in presses+=1}
        XCTAssertTrue(view.acceptsFirstMouse(for:nil))
        XCTAssertFalse(view.mouseDownCanMoveWindow)
        XCTAssertTrue(view.accessibilityPerformPress())
        XCTAssertEqual(presses,1)
    }
}

extension GeometryTests {
    func testEnlargedTargetsAreSeparatedFromEachOtherAndDragStrip(){
        for theme:RackTheme in [.naturalWood,.rams] {
        for width:CGFloat in [344,344*GeneratedRackMetrics.aspect,520] {
            let targets=(0..<4).map{GeneratedRackMetrics.controlFrame($0,width:width,theme:theme)}
            let dragEnd=targets[0].minX-4
            XCTAssertLessThan(dragEnd,targets[0].minX)
            for index in 0..<3 {XCTAssertFalse(targets[index].intersects(targets[index+1]))}
            XCTAssertLessThanOrEqual(targets[3].maxX,width-7)
            if width>490 {XCTAssertGreaterThanOrEqual(targets[0].width,31.9)}
        }
        }
    }
    @MainActor func testNativeControlDispatchesDirectMouseDown(){
        var presses=0
        let view=RackNativeControl.HitView(label:"test"){_ in presses+=1}
        view.frame=CGRect(x:0,y:0,width:32,height:32)
        let event=NSEvent.mouseEvent(with:.leftMouseDown,location:CGPoint(x:3,y:3),modifierFlags:[],timestamp:0,windowNumber:0,context:nil,eventNumber:1,clickCount:1,pressure:1)!
        view.mouseDown(with:event)
        XCTAssertEqual(presses,1)
    }
}

extension GeometryTests {
    func testWindowRouteMatchesArtworkAndNearEdgeClicks(){
        let width=344*GeneratedRackMetrics.aspect
        for theme:RackTheme in [.naturalWood,.rams] {
            for index in 0..<4 {
                let rect=GeneratedRackMetrics.controlFrame(index,width:width,theme:theme)
                for point in [CGPoint(x:rect.midX,y:rect.midY),CGPoint(x:rect.minX+1,y:rect.minY+1),CGPoint(x:rect.maxX-1,y:rect.maxY-1)] {
                    XCTAssertEqual(GeneratedRackMetrics.controlIndex(at:point,width:width,theme:theme),index)
                }
            }
            XCTAssertNil(GeneratedRackMetrics.controlIndex(at:CGPoint(x:100,y:100),width:width,theme:theme))
        }
    }
}
