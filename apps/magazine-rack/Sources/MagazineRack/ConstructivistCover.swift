import AppKit
import SwiftUI

/// Forty photo-led studies in early editorial constructivism. Artwork never rotates the photograph.
struct ConstructivistCover: View {
    let image: NSImage
    let template: Int
    let seed: Int

    private var index: Int { positive(template, 40) }
    private var family: Int { index / 5 }
    private var variant: Int { index % 5 }
    private var paper: Color { Color(red: 0.91, green: 0.88, blue: 0.78) }
    private var ink: Color { Color(red: 0.10, green: 0.11, blue: 0.10) }
    private var red: Color { Color(red: 0.77, green: 0.17, blue: 0.12) }
    private var title: String {
        ["ФОТО", "АТЛАС", "МИР", "РАКУРС", "ГОРОД", "КАДР", "ФОРМА", "СВЕТ"][positive(seed &+ family &+ variant, 8)]
    }
    private func positive(_ value: Int, _ count: Int) -> Int { ((value % count) + count) % count }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                composition.frame(width: 300, height: 420).clipped()
                    .scaleEffect(x: proxy.size.width / 300, y: proxy.size.height / 420, anchor: .topLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
        .accessibilityLabel("构成主义摄影封面 · 模板 \(index + 1)")
    }

    private var composition: some View {
        ZStack(alignment: .topLeading) {
            paper
            switch family {
            case 0: diagonalDispatch
            case 1: orbitAtlas
            case 2: architecture
            case 3: filmContact
            case 4: fieldReport
            case 5: splitEdition
            case 6: windowStudy
            default: printWorkshop
            }
        }
    }

    private func photo(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, mono: Bool = false,
                       anchor: Alignment = .center) -> some View {
        Image(nsImage: image).resizable().scaledToFill()
            .frame(width: w, height: h, alignment: anchor).clipped()
            .saturation(mono ? 0 : 1)
            .position(x: x + w / 2, y: y + h / 2)
    }
    private func block(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) -> some View {
        Rectangle().fill(color).frame(width: w, height: h).position(x: x + w / 2, y: y + h / 2)
    }
    private func words(_ value: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                       size: CGFloat = 23, color: Color? = nil, alignment: Alignment = .leading) -> some View {
        Text(value).font(.system(size: size, weight: size > 14 ? .black : .medium, design: size < 10 ? .monospaced : .default))
            .tracking(size < 10 ? 1.5 : -0.3).foregroundStyle(color ?? ink)
            .lineLimit(1).minimumScaleFactor(0.7)
            .frame(width: w, height: h, alignment: alignment)
            .position(x: x + w / 2, y: y + h / 2)
    }
    private func circle(_ x: CGFloat, _ y: CGFloat, _ diameter: CGFloat, fill: Color, line: Bool = false) -> some View {
        Circle().fill(line ? Color.clear : fill)
            .overlay(Circle().strokeBorder(fill, lineWidth: line ? 1 : 0))
            .frame(width: diameter, height: diameter).position(x: x + diameter / 2, y: y + diameter / 2)
    }
    @ViewBuilder private func motif(_ ordinal: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> some View {
        let number = positive((seed &* 3) &+ (index * 5) &+ (ordinal * 11), 36) + 1
        if let artwork = ConstructivistImageCache.image(number: number) {
            Image(nsImage: artwork).resizable().scaledToFit().frame(width: w, height: h)
                .position(x: x + w / 2, y: y + h / 2)
        } else {
            // Printed geometric device is intentional even without the optional illustration atlas.
            ZStack {
                Circle().strokeBorder(red, lineWidth: 1.5)
                Rectangle().fill(ink).frame(width: w * 0.65, height: 2).rotationEffect(.degrees(-35))
                Circle().fill(red).frame(width: w * 0.19, height: w * 0.19).offset(x: w * 0.2, y: -h * 0.18)
            }.frame(width: w, height: h).position(x: x + w / 2, y: y + h / 2)
        }
    }
    private func folio(_ color: Color? = nil) -> some View {
        words("PHOTO ARCHIVE   /   \(String(format: "%02d", index + 1))", 16, 402, 268, 10, size: 6, color: color)
    }
    private func hatch(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> some View {
        Canvas { context, size in
            for row in stride(from: CGFloat(3), through: size.height, by: 5) {
                for column in stride(from: CGFloat(3), through: size.width, by: 5) {
                    context.fill(Path(ellipseIn: CGRect(x: column, y: row, width: 1.1, height: 1.1)), with: .color(ink.opacity(0.48)))
                }
            }
        }.frame(width: w, height: h).position(x: x + w / 2, y: y + h / 2)
    }

    private var diagonalDispatch: some View {
        let top: CGFloat = [40, 27, 52, 18, 36][variant]
        let left: CGFloat = [12, 0, 15, 0, 10][variant]
        return ZStack(alignment: .topLeading) {
            photo(left, top, 300 - left * 2, 344, mono: variant == 2)
            block(variant % 2 == 0 ? -20 : 120, variant == 3 ? 346 : 327, 211, 40, red)
                .rotationEffect(.degrees(variant % 2 == 0 ? -11 : 8), anchor: .center)
            words(title, 18, 8, 217, 31, size: 27, color: variant == 3 ? paper : ink)
            motif(0, variant % 2 == 0 ? 234 : 18, 347, 49, 43)
            motif(1, variant % 2 == 0 ? 188 : 78, 363, 29, 27)
            words(["A NEW POINT OF VIEW", "CITY / MOTION", "THE PHOTO ISSUE", "LIGHT IN COMMON", "OBSERVATIONS"][variant], 18, 377, 220, 15, size: 8)
            folio()
        }
    }

    private var orbitAtlas: some View {
        let top: CGFloat = [42, 49, 30, 54, 35][variant]
        return ZStack(alignment: .topLeading) {
            photo(8, top, 284, 334, mono: variant == 1)
            circle(variant % 2 == 0 ? 208 : 14, 12, 72, fill: red, line: variant == 2)
            circle(variant % 2 == 0 ? 199 : 6, 4, 90, fill: ink, line: true)
            words(title, 17, 9, 189, 32, size: 25)
            block(0, 363, 300, 33, paper)
            motif(0, variant == 3 ? 17 : 229, 345, 55, 46)
            motif(1, variant == 3 ? 79 : 186, 371, 27, 24)
            words(["ATLAS OF THE EVERYDAY", "ORBIT / 02", "WORLD IN A FRAME", "A PERSONAL ATLAS", "EARTH & LIGHT"][variant], variant == 3 ? 119 : 17, 374, variant == 3 ? 161 : 191, 14, size: 8)
            folio()
        }
    }

    private var architecture: some View {
        let inset: CGFloat = [16, 9, 19, 12, 8][variant]
        return ZStack(alignment: .topLeading) {
            photo(inset, 44, 300 - inset * 2, 324, mono: variant == 4)
            block(0, 0, variant == 1 ? 115 : 67, 35, red)
            words(title, variant == 1 ? 128 : 79, 5, variant == 1 ? 155 : 205, 30, size: 26)
            Path { path in
                path.move(to: CGPoint(x: 8, y: 39)); path.addLine(to: CGPoint(x: 292, y: 39))
                path.move(to: CGPoint(x: 8, y: 39)); path.addLine(to: CGPoint(x: 8, y: 390))
            }.stroke(ink.opacity(0.6), lineWidth: 0.7)
            motif(0, variant % 2 == 0 ? 20 : 219, 344, 63, 51)
            motif(1, variant % 2 == 0 ? 87 : 184, 371, 28, 26)
            words(["FORM / FUNCTION", "CITY STRUCTURES", "THE BUILT WORLD", "SPACE & SCALE", "URBAN OBSERVATIONS"][variant], variant % 2 == 0 ? 124 : 20, 377, 160, 14, size: 7)
            folio()
        }
    }

    private var filmContact: some View {
        let narrow = variant == 1 || variant == 4
        return ZStack(alignment: .topLeading) {
            ink
            photo(narrow ? 20 : 12, 44, narrow ? 260 : 276, 332, mono: variant == 0 || variant == 3)
            ForEach(0..<13) { n in
                block(4, 48 + CGFloat(n) * 25, 5, 10, paper.opacity(0.8))
                block(291, 48 + CGFloat(n) * 25, 5, 10, paper.opacity(0.8))
            }
            words(title, 17, 6, 207, 31, size: 26, color: paper)
            block(230, 9, 53, 24, red)
            words(String(format: "%02d", index + 1), 234, 9, 45, 24, size: 15, color: paper, alignment: .center)
            motif(0, variant % 2 == 0 ? 218 : 16, 352, 61, 42)
            motif(1, variant % 2 == 0 ? 178 : 83, 372, 27, 22)
            words(["FRAME / BY / FRAME", "CONTACT SHEET", "NOTES ON LIGHT", "THE MOVING IMAGE", "KEEP THE NEGATIVE"][variant], variant % 2 == 0 ? 17 : 122, 381, 163, 11, size: 6, color: paper)
            folio(paper.opacity(0.8))
        }
    }

    private var fieldReport: some View {
        let y: CGFloat = [41, 29, 46, 34, 20][variant]
        return ZStack(alignment: .topLeading) {
            photo(0, y, 300, 350)
            block(0, 0, 300, y, variant == 3 ? red : paper)
            words(title, 16, 5, 214, 30, size: 25, color: variant == 3 ? paper : ink)
            block(variant % 2 == 0 ? 204 : 12, 322, 85, 71, paper)
            hatch(variant % 2 == 0 ? 207 : 15, 325, 79, 65)
            motif(0, variant % 2 == 0 ? 213 : 20, 329, 65, 51)
            motif(1, variant % 2 == 0 ? 166 : 108, 362, 28, 28)
            words(["FIELD / REPORT", "IN THE OPEN", "WALK & OBSERVE", "LOCAL STUDIES", "A VIEW FROM HERE"][variant], variant % 2 == 0 ? 15 : 151, 379, 139, 15, size: 7)
            folio()
        }
    }

    private var splitEdition: some View {
        let stripe: CGFloat = [18, 11, 24, 15, 9][variant]
        return ZStack(alignment: .topLeading) {
            photo(stripe, 40, 300 - stripe, 337, mono: variant == 1)
            block(0, 0, stripe, 394, red)
            block(stripe, 0, 300 - stripe, 37, ink)
            words(title, stripe + 12, 3, 247, 32, size: 26, color: paper)
            block(stripe, 356, variant == 3 ? 112 : 93, 38, red)
            motif(0, variant == 3 ? 170 : 206, 344, 69, 49)
            motif(1, variant == 3 ? 244 : 164, 371, 29, 24)
            words(["LIGHT STUDY", "THE NEW DAILY", "OPEN ARCHIVE", "LOOK AGAIN", "COLLECTED VIEWS"][variant], stripe + 9, 367, variant == 3 ? 96 : 79, 15, size: 7, color: paper)
            folio()
        }
    }

    private var windowStudy: some View {
        let x: CGFloat = [12, 0, 10, 0, 8][variant]
        return ZStack(alignment: .topLeading) {
            photo(x, 16, 300 - x * 2, 362)
            block(16, 18, variant == 2 ? 154 : 131, 41, paper)
            words(title, 23, 23, variant == 2 ? 140 : 116, 30, size: 26)
            block(16, 61, variant == 2 ? 154 : 131, 4, red)
            circle(232, 25, 39, fill: red, line: variant == 3)
            motif(0, variant % 2 == 0 ? 20 : 212, 340, 66, 51)
            motif(1, variant % 2 == 0 ? 95 : 171, 370, 27, 25)
            block(variant % 2 == 0 ? 137 : 14, 378, 150, 18, paper)
            words(["THE WINDOW ISSUE", "PHOTO / DOCUMENT", "WAYS OF SEEING", "A MOMENT HELD", "THE COMMON WORLD"][variant], variant % 2 == 0 ? 142 : 19, 381, 141, 11, size: 6)
            folio()
        }
    }

    private var printWorkshop: some View {
        let top: CGFloat = [43, 33, 52, 38, 24][variant]
        return ZStack(alignment: .topLeading) {
            photo(11, top, 278, 326, mono: variant == 2)
            words(title, 15, 4, 232, 31, size: 26)
            block(14, 36, variant == 2 ? 109 : 65, 4, red)
            hatch(252, 8, 32, 27)
            block(0, 361, 300, 35, paper)
            motif(0, variant == 4 ? 16 : 222, 342, 62, 48)
            motif(1, variant == 4 ? 88 : 183, 368, 28, 26)
            words(["PRINTED / MATTER", "THE PAPER EDITION", "IMAGE & IMPRESSION", "SMALL OBSERVATIONS", "NOTES FROM THE PRESS"][variant], variant == 4 ? 126 : 16, 374, 160, 15, size: 7)
            // Registration marks reference printing tools without pretending to be interface controls.
            circle(276, 400, 7, fill: red, line: true)
            folio()
        }
    }
}

private enum ConstructivistImageCache {
    private static let cache = NSCache<NSString, NSImage>()
    static func image(number: Int) -> NSImage? {
        let name = String(format: "construct-%02d", number)
        if let image = cache.object(forKey: name as NSString) { return image }
        guard let root = EditorialAssetLibrary.root,
              let image = NSImage(contentsOf: root.appendingPathComponent("EditorialAssets")
                .appendingPathComponent(name).appendingPathExtension("png")) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }
}
