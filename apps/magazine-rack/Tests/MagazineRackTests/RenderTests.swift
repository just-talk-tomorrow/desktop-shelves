import AppKit
import SwiftUI
import XCTest
@testable import MagazineRack
final class RenderTests:XCTestCase {
    @MainActor func testAllTemplatesRenderVisibleCoverAndExportPNG() throws {
        let image=NSImage(size:.init(width:300,height:420),flipped:false){rect in NSColor.systemBlue.setFill();rect.fill();return true}
        var hashes=Set<Int>()
        for template in 0..<240 {
            let renderer=ImageRenderer(content:MagazineCover(image:image,template:template,seed:7).frame(width:300,height:420));renderer.scale=1
            let cg=try XCTUnwrap(renderer.cgImage,"template \(template)")
            let bitmap=NSBitmapImageRep(cgImage:cg)
            let png=try XCTUnwrap(bitmap.representation(using:.png,properties:[:]))
            XCTAssertGreaterThan(png.count,2000,"template must include rendered artwork")
            let color=try XCTUnwrap(bitmap.colorAt(x:150,y:210));XCTAssertGreaterThan(color.alphaComponent,0.9)
            hashes.insert(png.hashValue)
            if template==0 {try png.write(to:URL(fileURLWithPath:"/private/tmp/magazine-cover-render-test.png"))}
        }
        XCTAssertEqual(hashes.count,240,"all 240 variants must be visually distinct")
        let small=ImageRenderer(content:MagazineCover(image:image,template:0,seed:7).frame(width:98,height:137))
        let cg=try XCTUnwrap(small.cgImage); let bitmap=NSBitmapImageRep(cgImage:cg)
        XCTAssertGreaterThan(try XCTUnwrap(bitmap.colorAt(x:49,y:68)).alphaComponent,0.9,"small cover must not be clipped away")
    }
}

extension RenderTests {
    @MainActor func testRackThemesRenderDifferentMaterials() throws {
        var outputs=Set<Int>()
        for theme in RackTheme.allCases {
            XCTAssertEqual(RackTheme(rawValue:theme.rawValue),theme)
            let renderer=ImageRenderer(content:RackMaterialBackground(theme:theme).frame(width:440,height:384))
            let cg=try XCTUnwrap(renderer.cgImage)
            let png=try XCTUnwrap(NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:]))
            XCTAssertGreaterThan(png.count,2000)
            outputs.insert(png.hashValue)
        }
        XCTAssertEqual(outputs.count,RackTheme.allCases.count)
    }
}

extension RenderTests {
    @MainActor func testPrintProcessorProducesActualProcessedPixelsAndStableResult() throws {
        let source=NSImage(size:.init(width:80,height:110),flipped:false){rect in
            NSColor.systemOrange.setFill();rect.fill()
            NSColor.systemBlue.setFill();NSRect(x:0,y:0,width:40,height:55).fill();return true
        }
        let a=PrintImageProcessor.render(image:source,template:12,seed:15)
        let cg=try XCTUnwrap(a.cgImage(forProposedRect:nil,context:nil,hints:nil))
        XCTAssertEqual(cg.width,600,"CoreImage processing must not silently return the source")
        XCTAssertEqual(cg.height,840)
        let b=PrintImageProcessor.render(image:source,template:12,seed:15)
        XCTAssertTrue(a === b,"Stable source and settings reuse processed output")
    }
}

extension RenderTests {
    @MainActor func testDarkPhotoInkRetainsVisibleTonalInformation() throws {
        let source=NSImage(size:.init(width:80,height:110),flipped:false){rect in
            NSColor(white:0.05,alpha:1).setFill();rect.fill()
            NSColor(white:0.14,alpha:1).setFill();NSRect(x:0,y:0,width:40,height:110).fill();return true
        }
        for template in [12,22] {
            let output=PrintImageProcessor.render(image:source,template:template,seed:4)
            let cg=try XCTUnwrap(output.cgImage(forProposedRect:nil,context:nil,hints:nil))
            let bitmap=NSBitmapImageRep(cgImage:cg)
            var bright=0
            for y in stride(from:20,to:820,by:10) {
                for x in stride(from:20,to:580,by:10) {
                    let color=try XCTUnwrap(bitmap.colorAt(x:x,y:y)?.usingColorSpace(.deviceRGB))
                    if color.redComponent>0.2 {bright += 1}
                }
            }
            XCTAssertGreaterThan(bright,500,"dark source must retain visible ink tones in effect \(template)")
        }
    }
}

extension RenderTests {
    @MainActor func testMagazineMockupsKeepReadableCoverAndStablePhysicalVariants() throws {
        let source=NSImage(size:.init(width:80,height:110),flipped:false){rect in NSColor.systemBlue.setFill();rect.fill();return true}
        var variants=Set<Int>(), outputs=Set<Int>()
        for seed in 0..<30 {
            let geometry=MagazineMockupGeometry(seed:seed)
            XCTAssertEqual(geometry,MagazineMockupGeometry(seed:seed))
            XCTAssertLessThan(abs(geometry.lean),3)
            XCTAssertLessThanOrEqual(abs(geometry.yaw),8)
            guard variants.insert(geometry.variant).inserted else {continue}
            let renderer=ImageRenderer(content:MagazineMockup(image:source,template:120,seed:seed).frame(width:98,height:137));renderer.scale=3
            let cg=try XCTUnwrap(renderer.cgImage)
            let bitmap=NSBitmapImageRep(cgImage:cg)
            let center=try XCTUnwrap(bitmap.colorAt(x:cg.width/2,y:cg.height/2))
            XCTAssertGreaterThan(center.alphaComponent,0.95,"book face must remain visible")
            outputs.insert(try XCTUnwrap(bitmap.representation(using:.png,properties:[:])).hashValue)
        }
        XCTAssertEqual(variants.count,5)
        XCTAssertEqual(outputs.count,5)
        for seed in [Int.min,Int.max,-1] {XCTAssertTrue((0..<5).contains(MagazineMockupGeometry(seed:seed).variant))}
    }
}
