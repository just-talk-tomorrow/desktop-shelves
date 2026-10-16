import AppKit
import CoreImage
import SwiftUI

/// Quiet paper studies: a photograph, a little printing ink, and generous unoccupied paper.
struct MinimalEditorialCover: View {
    let image: NSImage
    let template: Int
    let seed: Int

    private var index: Int { ((template % 40) + 40) % 40 }
    private var family: Int { index / 5 }
    private var variation: Int { index % 5 }
    private var printedImage: NSImage { MinimalPrintCache.halftone(image) }
    private var paper: Color { Color(red: 0.965, green: 0.952, blue: 0.916) }
    private var ink: Color { Color(red: 0.19, green: 0.20, blue: 0.18) }
    private var hasLabels: Bool { index % 4 != 0 && family != 7 }
    private var caption: String {
        let titles = ["a quiet moment", "日々の記録", "PHOTO STUDY", "collected light", "余白"]
        return titles[(((seed % 5) + 5) % 5 + variation) % 5]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                composition.frame(width: 300, height: 420).clipped()
                    .scaleEffect(x: geometry.size.width / 300, y: geometry.size.height / 420, anchor: .topLeading)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
        }
        .accessibilityLabel("\(caption) · 極簡写真研究 · \(index + 1)")
    }

    private var composition: some View {
        ZStack(alignment: .topLeading) {
            paper
            if let texture = MinimalPrintCache.paperTexture {
                Image(nsImage: texture).resizable().scaledToFill().frame(width: 300, height: 420)
                    .clipped().opacity(0.22).blendMode(.multiply)
            }
            switch family {
            case 0: circularStudy
            case 1: cornerContactSheet
            case 2: upperLandscape
            case 3: offsetStudy
            case 4: centralPostcard
            case 5: contactStrip
            case 6: pairedStudies
            default: silentPhotograph
            }
        }
    }

    private func photograph(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                            anchor: Alignment = .center, circle: Bool = false) -> some View {
        Image(nsImage: printedImage).resizable().scaledToFill()
            .frame(width: w, height: h, alignment: anchor).clipped()
            .clipShape(PrintPhotoShape(circle: circle))
            .blendMode(.multiply)
            .position(x: x + w / 2, y: y + h / 2)
    }
    private func label(_ words: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat = 150,
                       size: CGFloat = 8, align: Alignment = .leading) -> some View {
        Text(words).font(.system(size: size, weight: .regular, design: .monospaced))
            .tracking(0.9).foregroundStyle(ink.opacity(0.83)).lineLimit(1).minimumScaleFactor(0.8)
            .frame(width: width, height: 16, alignment: align)
            .position(x: x + width / 2, y: y + 8)
    }
    private func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> some View {
        Path { path in path.move(to: CGPoint(x: x1, y: y1)); path.addLine(to: CGPoint(x: x2, y: y2)) }
            .stroke(ink.opacity(0.48), style: StrokeStyle(lineWidth: 0.65, lineCap: .round, dash: [0.7, 3.2]))
    }
    private func outline(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> some View {
        Rectangle().stroke(ink.opacity(0.43), style: StrokeStyle(lineWidth: 0.65, lineCap: .round, dash: [0.7, 3.2]))
            .frame(width: width, height: height).position(x: x + width / 2, y: y + height / 2)
    }
    private func curve(_ start: CGPoint, _ end: CGPoint, control: CGPoint) -> some View {
        Path { path in path.move(to: start); path.addQuadCurve(to: end, control: control) }
            .stroke(ink.opacity(0.42), style: StrokeStyle(lineWidth: 0.65, lineCap: .round, dash: [0.7, 3.2]))
    }

    private var circularStudy: some View {
        let diameter: CGFloat = [88, 104, 78, 96, 86][variation]
        let x: CGFloat = [36, 45, 160, 31, 59][variation]
        let y: CGFloat = [70, 112, 53, 58, 169][variation]
        return ZStack(alignment: .topLeading) {
            photograph(x, y, diameter, diameter, circle: true)
            outline(x - 9, y - 9, diameter + 18, diameter + 18)
            if variation % 2 == 0 {
                line(x + diameter / 2, y + diameter + 10, x + diameter / 2, 353)
                line(x + diameter / 2, 353, 256, 353)
                if hasLabels {
                    label(caption, x, 35, 220)
                    label("photograph / paper", 137, 365, 125, size: 6)
                }
            } else {
                line(x + diameter + 9, y + diameter / 2, 264, y + diameter / 2)
                line(264, y + diameter / 2, 264, 361)
                if hasLabels {
                    label(caption, 34, 362, 215)
                    label("a personal collection", x, y - 32, 210, size: 6)
                }
            }
        }
    }

    private var cornerContactSheet: some View {
        let panel: CGFloat = [47, 53, 42, 49, 45][variation]
        let gap: CGFloat = variation == 2 ? 5 : 3
        let total = panel * 2 + gap
        let x: CGFloat = variation == 3 ? 29 : 271 - total
        let y: CGFloat = [255, 244, 283, 266, 233][variation]
        return ZStack(alignment: .topLeading) {
            ForEach(0..<4) { n in
                photograph(x + CGFloat(n % 2) * (panel + gap), y + CGFloat(n / 2) * (panel + gap), panel, panel,
                           anchor: [.topLeading, .topTrailing, .bottomLeading, .bottomTrailing][n])
            }
            line(x - 12, 46, x - 12, y + total)
            line(29, y - 13, 271, y - 13)
            if variation == 1 || variation == 4 { line(x + total + 8, y, x + total + 8, 383) }
            if hasLabels {
                label(caption, 31, 47, 225)
                label("four observations", x, y + total + 8, total + 9, size: 6)
            }
        }
    }

    private var upperLandscape: some View {
        let width: CGFloat = [194, 152, 222, 178, 164][variation]
        let height: CGFloat = [77, 99, 64, 86, 111][variation]
        let x: CGFloat = variation == 1 ? 112 : (300 - width) / 2
        let y: CGFloat = [65, 47, 94, 119, 54][variation]
        return ZStack(alignment: .topLeading) {
            photograph(x, y, width, height, anchor: variation == 4 ? .top : .center)
            let end = CGPoint(x: variation % 2 == 0 ? 55 : 254, y: 359)
            curve(CGPoint(x: x + width / 2, y: y + height + 7), end,
                  control: CGPoint(x: variation % 2 == 0 ? 263 : 35, y: 290))
            line(end.x - 15, end.y, end.x + 15, end.y)
            if variation == 3 { line(35, 36, 35, 375) }
            if hasLabels {
                label(caption, x, y - 28, min(width + 20, 240))
                label("light / distance", variation % 2 == 0 ? 75 : 130, 365, 120, size: 6)
            }
        }
    }

    private var offsetStudy: some View {
        let x: CGFloat = [158, 37, 132, 54, 170][variation]
        let y: CGFloat = [179, 229, 101, 144, 247][variation]
        let width: CGFloat = [102, 106, 125, 92, 86][variation]
        let height: CGFloat = [124, 110, 95, 139, 110][variation]
        return ZStack(alignment: .topLeading) {
            photograph(x, y, width, height)
            line(31, y + height + 11, 269, y + height + 11)
            line(x - 11, 36, x - 11, 383)
            if variation == 2 { outline(33, 268, 45, 45) }
            if hasLabels {
                label(caption, 32, 45, 230)
                label("photo study", x, y + height + 17, 115, size: 6)
            }
        }
    }

    private var centralPostcard: some View {
        let width: CGFloat = [160, 144, 172, 122, 152][variation]
        let height: CGFloat = [112, 154, 98, 160, 122][variation]
        let x = (300 - width) / 2
        let y: CGFloat = [153, 128, 170, 123, 149][variation]
        return ZStack(alignment: .topLeading) {
            photograph(x, y, width, height)
            outline(x - 8, y - 8, width + 16, height + 16)
            if variation == 1 || variation == 3 {
                line(150, 41, 150, y - 16)
                line(150, y + height + 17, 150, 376)
            } else {
                line(28, y + height / 2, x - 16, y + height / 2)
                line(x + width + 16, y + height / 2, 272, y + height / 2)
            }
            if hasLabels {
                label(caption, 39, 47, 222, align: .center)
                label("a quiet collection", 50, 354, 200, size: 6, align: .center)
            }
        }
    }

    private var contactStrip: some View {
        let count = variation == 1 || variation == 4 ? 4 : 3
        let width: CGFloat = count == 4 ? 51 : 68
        let height: CGFloat = [68, 83, 55, 77, 62][variation]
        let x = (300 - (CGFloat(count) * width + CGFloat(count - 1) * 4)) / 2
        let y: CGFloat = [271, 92, 180, 245, 143][variation]
        return ZStack(alignment: .topLeading) {
            ForEach(0..<count, id: \.self) { n in
                photograph(x + CGFloat(n) * (width + 4), y, width, height,
                           anchor: [.leading, .center, .trailing, .bottom][n])
            }
            line(29, y - 11, 271, y - 11)
            line(29, y + height + 11, 271, y + height + 11)
            if variation % 2 == 0 { line(29, 42, 29, 379) }
            if hasLabels {
                label(caption, 39, 48, 225)
                label("contact / light / memory", x, y + height + 16, 227, size: 6)
            }
        }
    }

    private var pairedStudies: some View {
        let mirrored = variation % 2 == 1
        let x: CGFloat = mirrored ? 42 : 148
        let y: CGFloat = [74, 138, 105, 58, 177][variation]
        return ZStack(alignment: .topLeading) {
            photograph(x, y, 108, 112, anchor: .top)
            photograph(mirrored ? 168 : 40, y + 135, 73, 78, anchor: .bottomTrailing)
            line(mirrored ? 159 : 136, y, mirrored ? 159 : 136, y + 213)
            line(31, y + 123, 269, y + 123)
            if variation == 4 { outline(34, 46, 37, 37) }
            if hasLabels {
                label(caption, 32, 26, 230)
                label("near / far", mirrored ? 168 : 40, y + 220, 93, size: 6)
            }
        }
    }

    private var silentPhotograph: some View {
        Group {
            switch variation {
            case 0: photograph(0, 0, 300, 420)
            case 1: photograph(11, 11, 278, 398)
            case 2: photograph(0, 12, 300, 396, anchor: .leading)
            case 3: photograph(19, 48, 262, 324)
            default: photograph(14, 0, 272, 420, anchor: .trailing)
            }
        }
    }
}

private struct PrintPhotoShape: Shape {
    let circle: Bool
    func path(in rect: CGRect) -> Path {
        circle ? Path(ellipseIn: rect) : Path(rect)
    }
}

private enum MinimalPrintCache {
    private static let images = NSCache<NSString, NSImage>()
    private static let processedPhotos: NSCache<NSImage, NSImage> = { let cache=NSCache<NSImage,NSImage>();cache.countLimit=24;return cache }()
    private static let context = CIContext(options: [.cacheIntermediates: false])
    static var paperTexture: NSImage? {
        let key = "paper-fiber" as NSString
        if let cached = images.object(forKey: key) { return cached }
        guard let root = EditorialAssetLibrary.root,
              let texture = NSImage(contentsOf: root.appendingPathComponent("EditorialAssets/paper-fiber.png")) else { return nil }
        images.setObject(texture, forKey: key)
        return texture
    }
    static func halftone(_ original: NSImage) -> NSImage {
        if let result = processedPhotos.object(forKey: original) { return result }
        guard let cgImage = original.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return original }
        var source = CIImage(cgImage: cgImage)
        let scale = min(1, 720 / max(source.extent.width, source.extent.height))
        source = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        source = PrintTone.balance(source, context: context)
        let monochrome = source.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.0, kCIInputBrightnessKey: 0.025])
        let dots = monochrome.applyingFilter("CIDotScreen", parameters: [kCIInputCenterKey: CIVector(x: 0, y: 0), kCIInputAngleKey: CGFloat.pi / 4, kCIInputWidthKey: 4.5, kCIInputSharpnessKey: 0.65])
        guard let output = context.createCGImage(dots, from: monochrome.extent) else { return original }
        let result = NSImage(cgImage: output, size: NSSize(width: output.width, height: output.height))
        processedPhotos.setObject(result, forKey: original)
        return result
    }
}
