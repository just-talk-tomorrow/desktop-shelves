import AppKit
import CoreImage

/// Bounded, identity-based cache avoids serializing the source photograph on every SwiftUI redraw.
enum PrintImageProcessor {
    private final class Entry: NSObject {
        let source: NSImage
        let rendered: NSImage
        init(_ source: NSImage, _ rendered: NSImage) { self.source = source; self.rendered = rendered }
    }
    private static let cache: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.countLimit = 100
        cache.totalCostLimit = 110 * 1024 * 1024
        return cache
    }()
    private static let ci = CIContext(options: [.cacheIntermediates: false, .useSoftwareRenderer: true])
    private static let extent = CGRect(x: 0, y: 0, width: 600, height: 840)
    private static let textureCache = NSCache<NSString, NSImage>()

    static func render(image: NSImage, template: Int, seed: Int) -> NSImage {
        let index = (template % 80 + 80) % 80, family = index / 10, variant = index % 10
        let key = "\(ObjectIdentifier(image))-\(index)-\(seed)" as NSString
        if let cached = cache.object(forKey: key) { return cached.rendered }
        guard let original = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        let input = CIImage(cgImage: original)
        let scale = max(600 / input.extent.width, 840 / input.extent.height)
        let scaled = input.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let crop = scaled.transformed(by: CGAffineTransform(translationX: (600-scaled.extent.width)/2,
                                                          y: (840-scaled.extent.height)/2)).cropped(to: extent)
        var result = crop
        let v = Double(variant)
        switch family {
        case 0:
            result = duotone(crop, variant: variant, contrast: 1.18)
                .applyingFilter("CIColorPosterize", parameters: ["inputLevels": 5 + variant % 4])
            let dots = monochrome(crop, contrast: 1.15).applyingFilter("CIDotScreen", parameters: [
                "inputCenter": CIVector(x: 300, y: 420), "inputAngle": 0.35 + v * 0.07,
                "inputWidth": 3.0 + v * 0.22, "inputSharpness": 0.55])
            // Offset ink plate creates registration fringes along real image contours.
            let plate = dots.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.18, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0.48, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0.56, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.26)])
                .transformed(by: CGAffineTransform(translationX: Double(variant % 3 + 2), y: -2))
            result = plate.composited(over: result)
        case 1:
            result = monochrome(PrintTone.balance(crop, context: ci), contrast: 1.02 + v * 0.012)
                .applyingFilter("CIDotScreen", parameters: ["inputWidth": 3.3 + v * 0.35,
                    "inputAngle": 0.785, "inputSharpness": 0.82])
                .applyingFilter("CIFalseColor", parameters: ["inputColor0": CIColor(red: 0.10, green: 0.12, blue: 0.13),
                    "inputColor1": CIColor(red: 0.93, green: 0.89, blue: 0.77)])
        case 2:
            result = monochrome(PrintTone.balance(crop, context: ci), contrast: 1.18 + v * 0.018)
                .applyingFilter("CIColorPosterize", parameters: ["inputLevels": 5 + variant % 3])
        case 3, 4:
            result = crop.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0.76,
                "inputContrast": 0.96, "inputBrightness": 0.025])
        case 5:
            result = duotone(crop.applyingFilter("CIColorPosterize", parameters: ["inputLevels": 4]),
                              variant: variant, contrast: 1.35)
        case 6:
            result = crop.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0.75 + v * 0.025,
                "inputContrast": 1.1])
        default:
            result = crop.applyingFilter("CIPhotoEffectFade")
                .applyingFilter("CISepiaTone", parameters: ["inputIntensity": 0.12 + v * 0.035])
        }
        guard let processed = ci.createCGImage(result.cropped(to: extent), from: extent),
              let context = CGContext(data: nil, width: 600, height: 840, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        context.setFillColor(NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.85, alpha: 1).cgColor)
        context.fill(extent)
        if family == 5 && variant % 3 != 0 {
            // Printed contact-sheet panels have independent ink palettes, not four identical copies.
            let count = variant % 2 == 0 ? 2 : 4
            for n in 0..<count {
                let rect = count == 2 ? CGRect(x: 12, y: 12 + n * 414, width: 576, height: 402) :
                    CGRect(x: 12 + (n % 2)*294, y: 12 + (n / 2)*414, width: 282, height: 402)
                let panel = duotone(crop, variant: variant + n * 2, contrast: 1.38)
                    .applyingFilter("CIColorPosterize", parameters: ["inputLevels": 4])
                if let plate = ci.createCGImage(panel, from: extent) { context.draw(plate, in: rect) }
            }
        } else if family == 6 {
            var rng = Random(state: UInt64(truncatingIfNeeded: seed) &+ UInt64(index + 1))
            let strips = 4 + variant % 4
            for n in 0..<strips {
                let x = CGFloat(n) * 600 / CGFloat(strips), width = 600 / CGFloat(strips)
                context.saveGState()
                let path = CGMutablePath()
                path.move(to: CGPoint(x: x + 2, y: 0))
                for y in stride(from: 0, through: 840, by: 12) {
                    path.addLine(to: CGPoint(x: x + 2 + CGFloat(rng.next()) * 5, y: CGFloat(y)))
                }
                path.addLine(to: CGPoint(x: x + width - 3, y: 840))
                for y in stride(from: 840, through: 0, by: -12) {
                    path.addLine(to: CGPoint(x: x + width - 3 - CGFloat(rng.next()) * 5, y: CGFloat(y)))
                }
                path.closeSubpath(); context.addPath(path); context.clip()
                context.draw(processed, in: extent.offsetBy(dx: CGFloat(rng.next()-0.5)*25,
                                                            dy: CGFloat(rng.next()-0.5)*50))
                context.restoreGState()
            }
        } else {
            context.draw(processed, in: family == 7 && variant % 2 == 0 ? extent.insetBy(dx: 22, dy: 30) : extent)
        }
        let texture = family == 3 ? "paper-folds" : family == 4 ? "paper-crumple" : family == 1 ? "paper-newsprint" : "paper-fiber"
        overlayTexture(texture, in: context, alpha: family == 3 || family == 4 ? 0.38 : 0.25)
        paperDetails(in: context, family: family, variant: variant, seed: seed)
        guard let output = context.makeImage() else { return image }
        let rendered = NSImage(cgImage: output, size: NSSize(width: 300, height: 420))
        cache.setObject(Entry(image, rendered), forKey: key, cost: 600 * 840 * 4)
        return rendered
    }

    private static func monochrome(_ source: CIImage, contrast: Double) -> CIImage {
        source.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0, "inputContrast": contrast])
    }
    private static func duotone(_ source: CIImage, variant: Int, contrast: Double) -> CIImage {
        let colors: [(CIColor, CIColor)] = [
            (.init(red: 0.05, green: 0.25, blue: 0.57), .init(red: 1, green: 0.62, blue: 0.54)),
            (.init(red: 0.09, green: 0.36, blue: 0.27), .init(red: 0.99, green: 0.85, blue: 0.36)),
            (.init(red: 0.55, green: 0.08, blue: 0.23), .init(red: 0.87, green: 0.83, blue: 0.99)),
            (.init(red: 0.18, green: 0.13, blue: 0.42), .init(red: 1, green: 0.66, blue: 0.25)),
            (.init(red: 0.05, green: 0.31, blue: 0.38), .init(red: 0.95, green: 0.90, blue: 0.69))]
        let palette = colors[(variant % colors.count + colors.count) % colors.count]
        return monochrome(source, contrast: contrast).applyingFilter("CIFalseColor", parameters: [
            "inputColor0": palette.0, "inputColor1": palette.1])
    }
    private static func overlayTexture(_ name: String, in context: CGContext, alpha: CGFloat) {
        let key = name as NSString
        let texture: NSImage?
        if let cached = textureCache.object(forKey: key) { texture = cached }
        else {
            texture = EditorialAssetLibrary.root.flatMap { NSImage(contentsOf: $0.appendingPathComponent("EditorialAssets/\(name).png")) }
            if let texture { textureCache.setObject(texture, forKey: key) }
        }
        guard let cg = texture?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        context.saveGState(); context.setBlendMode(.multiply); context.setAlpha(alpha)
        context.draw(cg, in: extent); context.restoreGState()
    }
    private static func paperDetails(in context: CGContext, family: Int, variant: Int, seed: Int) {
        var rng = Random(state: UInt64(truncatingIfNeeded: seed) &+ UInt64(variant + 73))
        // Subpixel warm/dark fibers are tied to paper, never to a decorative grid.
        for n in 0..<3200 {
            let x = rng.next()*600, y = rng.next()*840
            context.setStrokeColor((n % 2 == 0 ? NSColor.white : NSColor.brown).withAlphaComponent(0.07 + rng.next()*0.1).cgColor)
            context.setLineWidth(0.35 + rng.next()*0.6)
            context.move(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x + rng.next()*6 - 3, y: y + rng.next()*2 - 1)); context.strokePath()
        }
        if family == 3 || family == 4 {
            let folds = family == 3 ? 2 + variant % 3 : 18 + variant
            for n in 0..<folds {
                let vertical = n % 2 == 0
                let x = 90 + rng.next()*420, y = 100 + rng.next()*640
                let start = family == 3 ? CGPoint(x: vertical ? x : 0, y: vertical ? 0 : y) : CGPoint(x: x, y: y)
                let end = family == 3 ? CGPoint(x: vertical ? x : 600, y: vertical ? 840 : y) :
                    CGPoint(x: max(0,min(600,x+(rng.next()-0.5)*300)), y: max(0,min(840,y+(rng.next()-0.5)*360)))
                for (offset, alpha, width) in [(CGFloat(-3), 0.15, CGFloat(8)), (CGFloat(0), 0.20, CGFloat(1.5)), (CGFloat(2), 0.34, CGFloat(1.2))] {
                    let strength = family == 4 ? alpha * 0.36 : alpha
                    context.setStrokeColor((offset > 0 ? NSColor.white : NSColor.black).withAlphaComponent(strength).cgColor)
                    context.setLineWidth(family == 4 ? width * 1.5 : width)
                    context.move(to: CGPoint(x: start.x+offset,y:start.y))
                    if family == 4 {
                        context.addQuadCurve(to: CGPoint(x:end.x+offset,y:end.y),
                            control: CGPoint(x:(start.x+end.x)/2+12,y:(start.y+end.y)/2-8))
                    } else { context.addLine(to: CGPoint(x:end.x+offset,y:end.y)) }
                    context.strokePath()
                }
            }
        }
    }
    private struct Random {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / 9007199254740992
        }
    }
}

/// Expose dark photographs for ink reproduction instead of crushing the subject to black.
enum PrintTone {
    static func balance(_ source:CIImage,context:CIContext)->CIImage {
        let average=source.applyingFilter("CIAreaAverage",parameters:["inputExtent":CIVector(cgRect:source.extent)])
        var sample=[UInt8](repeating:0,count:4)
        context.render(average,toBitmap:&sample,rowBytes:4,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBA8,colorSpace:CGColorSpaceCreateDeviceRGB())
        let light=(Double(sample[0])*0.2126+Double(sample[1])*0.7152+Double(sample[2])*0.0722)/255
        let exposure=min(5.0,max(-0.8,2.2 * log2(0.42/max(0.02,light))))
        return source.applyingFilter("CIExposureAdjust",parameters:["inputEV":exposure])
    }
}
