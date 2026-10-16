import AppKit
import SwiftUI

/// A small personal photo journal: forty compositions, with restrained printed ephemera.
struct JapaneseCover: View {
    let image: NSImage
    let template: Int
    let seed: Int

    private var index: Int { positive(template, 40) }
    private var family: Int { index / 5 }
    private var variant: Int { index % 5 }
    private var paper: Color { Color(red: 0.97, green: 0.96, blue: 0.92) }
    private var ink: Color { Color(red: 0.23, green: 0.27, blue: 0.24) }
    private var accent: Color {
        [Color(red: 0.76, green: 0.83, blue: 0.76), Color(red: 0.77, green: 0.85, blue: 0.88),
         Color(red: 0.86, green: 0.73, blue: 0.67), Color(red: 0.88, green: 0.85, blue: 0.73),
         Color(red: 0.77, green: 0.79, blue: 0.69)][variant]
    }
    private var title: String { ["日々", "散歩", "休日", "記録", "よりみち", "木漏れ日", "旅の途中", "小さな発見", "暮らし", "好きな場所", "森の記憶", "ひとやすみ", "街角", "季節の便り", "光を集めて"][positive(seed &+ variant, 15)] }
    private var theme: Int {
        // Each composition has a coherent little collection, rather than unrelated stickers.
        [0, 1, 2, 1, 0, 0, 2, 1][family]
    }
    private var stickerPool: [Int] {
        switch theme {
        case 0: return Array(1...6) + Array(19...27) + [30, 33]
        case 1: return Array(13...18) + [31, 32, 34, 35, 36]
        default: return Array(7...12) + [25, 26, 27]
        }
    }
    private func positive(_ value: Int, _ modulus: Int) -> Int { ((value % modulus) + modulus) % modulus }
    private func asset(_ kind: String, _ number: Int) -> NSImage? {
        EditorialImageCache.image(named: String(format: "%@-%02d", kind, number))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                composition
                    .frame(width: 300, height: 420)
                    .clipped()
                    .scaleEffect(x: geometry.size.width / 300, y: geometry.size.height / 420, anchor: .topLeading)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
        }
        .accessibilityLabel("\(title) · 写真日記 · 模板 \(index + 1)")
    }

    @ViewBuilder private var composition: some View {
        ZStack(alignment: .topLeading) {
            paper
            switch family {
            case 0: fieldNotes
            case 1: postcard
            case 2: scrapbook
            case 3: filmJournal
            case 4: garden
            case 5: paperCutout
            case 6: illustratedBand
            default: travelJournal
            }
        }
    }

    private func photo(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                       anchor: Alignment = .center, border: CGFloat = 0) -> some View {
        Image(nsImage: image).resizable().scaledToFill()
            .frame(width: w, height: h, alignment: anchor).clipped()
            .overlay(Rectangle().strokeBorder(.white.opacity(0.95), lineWidth: border))
            .position(x: x + w / 2, y: y + h / 2)
    }

    private func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                      size: CGFloat = 24, color: Color? = nil, weight: Font.Weight = .medium,
                      design: Font.Design = .serif, alignment: Alignment = .leading) -> some View {
        Text(value).font(.system(size: size, weight: weight, design: design))
            .tracking(size <= 10 ? 1.8 : 1.0)
            .foregroundStyle(color ?? ink)
            .lineLimit(1).minimumScaleFactor(0.35)
            .frame(width: w, height: h, alignment: alignment).clipped()
            .position(x: x + w / 2, y: y + h / 2)
    }

    private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) -> some View {
        Rectangle().fill(color).frame(width: w, height: h).position(x: x + w / 2, y: y + h / 2)
    }

    @ViewBuilder private func sticker(_ ordinal: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> some View {
        let n = stickerPool[positive((seed &* 7) &+ (variant * 3) &+ (ordinal * 5), stickerPool.count)]
        if let artwork = asset("sticker", n) {
            Image(nsImage: artwork).resizable().scaledToFit()
                .frame(width: w, height: h).position(x: x + w / 2, y: y + h / 2)
        }
    }

    /// Printed paper assets sit beneath a short caption; absent assets keep a clean paper label.
    private func label(_ caption: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                       ordinal: Int = 0, size: CGFloat = 12) -> some View {
        ZStack {
            if let artwork = asset("paper", [7,8,9,10,11,12,22][positive(seed &+ (index * 3) &+ ordinal, 7)]) {
                Image(nsImage: artwork).resizable().scaledToFit()
            } else {
                Rectangle().fill(paper.opacity(0.96))
            }
            Text(caption).font(.system(size: size, weight: .medium, design: .serif))
                .tracking(1).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.35)
                .padding(.horizontal, 8)
        }
        .frame(width: w, height: h).position(x: x + w / 2, y: y + h / 2)
    }

    private func tape(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat = 57, ordinal: Int = 0) -> some View {
        Group {
            if let artwork = asset("paper", positive(seed &+ ordinal &+ 11, 6) + 1) {
                Image(nsImage: artwork).resizable().scaledToFit()
            } else {
                Rectangle().fill(accent.opacity(0.65))
            }
        }.frame(width: w, height: 20).position(x: x + w / 2, y: y + 10)
    }

    private func folio(_ x: CGFloat = 18, _ y: CGFloat = 398, color: Color? = nil) -> some View {
        text("PHOTO JOURNAL   /   \(String(format: "%02d", index + 1))", x, y, 264, 10, size: 7, color: color, design: .monospaced)
    }

    private var fieldNotes: some View {
        let top: CGFloat = [42, 53, 30, 43, 61][variant]
        let left: CGFloat = [17, 17, 16, 18, 12][variant]
        let width: CGFloat = [266, 266, 268, 264, 276][variant]
        return ZStack(alignment: .topLeading) {
            rect(0, 0, 300, 420, variant == 2 ? accent.opacity(0.3) : paper)
            photo(left, top, width, 321, border: variant == 1 ? 3 : 0)
            text(variant == 4 ? "offday / field notes" : "FIELD NOTES", 18, 11, 233, 20, size: 9, design: .monospaced)
            tape(variant == 1 ? 25 : 185, top - 8, 67)
            label(title, variant == 3 ? 166 : 24, 339, 111, 41, size: 25)
            sticker(0, variant == 3 ? 15 : 227, 342, 58, 63)
            sticker(1, variant == 3 ? 78 : 188, 367, 36, 35)
            if variant == 2 || variant == 4 { sticker(2, 247, 12, 32, 35) }
            folio()
        }
    }

    private var postcard: some View {
        let top: CGFloat = [53, 33, 41, 63, 27][variant]
        return ZStack(alignment: .topLeading) {
            rect(0, 0, 300, 420, variant == 1 ? accent.opacity(0.4) : paper)
            photo(15, top, 270, 307, border: variant == 2 ? 5 : 0)
            text(variant == 3 ? "A SMALL JOURNEY" : "POSTCARD", 18, 12, 200, 19, size: 10, design: .monospaced)
            sticker(0, 246, 7, 39, 43)
            label(title, 22, 346, 122, 40, size: 25)
            sticker(1, 220, 359, 58, 42)
            if variant == 0 || variant == 3 {
                tape(21, top - 8, 60)
                text("from my camera", 26, 385, 173, 14, size: 8, design: .monospaced)
            } else {
                label("a day to remember", 157, 352, 126, 24, ordinal: 1, size: 9)
            }
            if variant == 4 { sticker(2, 183, 377, 31, 27) }
            folio()
        }
    }

    private var scrapbook: some View {
        let upper: CGFloat = [247, 264, 245, 258, 247][variant]
        return ZStack(alignment: .topLeading) {
            rect(0, 0, 300, 420, variant == 4 ? accent.opacity(0.35) : paper)
            photo(12, 34, 276, upper, border: variant == 3 ? 5 : 0)
            photo(variant == 1 ? 152 : 19, upper + 44, variant == 1 ? 135 : 151, 99,
                  anchor: variant % 2 == 0 ? .leading : .trailing, border: 5)
            tape(33, 26, 63)
            tape(variant == 1 ? 188 : 72, upper + 36, 43, ordinal: 1)
            text("collected moments", 15, 9, 233, 16, size: 8, design: .monospaced)
            let captionX: CGFloat = variant == 1 ? 17 : 181
            text(title, captionX, upper + 49, 105, 34, size: 25)
            sticker(0, captionX + 5, upper + 85, 55, 47)
            sticker(1, 247, 5, 34, 31)
            if variant == 2 { sticker(2, 245, 373, 34, 32) }
            folio()
        }
    }

    private var filmJournal: some View {
        let frame = variant == 2 || variant == 4
        return ZStack(alignment: .topLeading) {
            rect(0, 0, 300, 420, frame ? ink : paper)
            photo(frame ? 18 : 13, 48, frame ? 264 : 274, 310)
            if frame {
                ForEach(0..<13) { n in
                    rect(5, 51 + CGFloat(n) * 24, 6, 10, paper.opacity(0.7))
                    rect(289, 51 + CGFloat(n) * 24, 6, 10, paper.opacity(0.7))
                }
            }
            text("OFFDAY / FILM JOURNAL", 18, 13, 261, 19, size: 10, color: frame ? paper : ink, design: .monospaced)
            label(title, variant == 1 ? 161 : 23, 342, 119, 39, size: 25)
            sticker(0, variant == 1 ? 20 : 229, 359, 52, 44)
            sticker(1, variant == 1 ? 79 : 187, 377, 28, 26)
            if variant == 3 { tape(191, 39, 63) }
            folio(color: frame ? paper.opacity(0.8) : ink)
        }
    }

    private var garden: some View {
        let margin: CGFloat = [20, 12, 24, 17, 15][variant]
        return ZStack(alignment: .topLeading) {
            rect(0, 0, 300, 420, accent.opacity(0.22))
            photo(margin, 45, 300 - margin * 2, 326)
            Rectangle().strokeBorder(ink.opacity(0.3), lineWidth: 0.7)
                .frame(width: 286, height: 406).position(x: 150, y: 210)
            text(variant == 3 ? "庭の記録" : "little garden", 19, 17, 204, 23, size: variant == 3 ? 17 : 14)
            sticker(0, 244, 8, 39, 43)
            label(title, variant == 2 ? 150 : 23, 346, 128, 40, size: 24)
            sticker(1, variant == 2 ? 20 : 218, 354, 62, 51)
            if variant == 0 || variant == 4 { sticker(2, variant == 2 ? 79 : 181, 380, 32, 25) }
            folio(19, 399)
        }
    }

    private var paperCutout: some View {
        let x: CGFloat = [13, 21, 13, 27, 15][variant]
        let w: CGFloat = [274, 266, 274, 258, 270][variant]
        return ZStack(alignment: .topLeading) {
            rect(0, 0, 300, 420, accent)
            rect(variant % 2 == 0 ? 0 : 39, 18, 265, 386, paper.opacity(0.88))
            photo(x, variant == 4 ? 48 : 41, w, 322)
            tape(variant == 3 ? 209 : 30, variant == 4 ? 49 : 32, 58)
            text("a personal collection", 17, 12, 252, 16, size: 8, design: .monospaced)
            label(title, variant % 2 == 0 ? 27 : 157, 342, 117, 43, size: 25)
            sticker(0, variant % 2 == 0 ? 220 : 22, 349, 56, 52)
            sticker(1, variant % 2 == 0 ? 181 : 88, 378, 29, 26)
            if variant == 2 { sticker(2, 248, 9, 30, 30) }
            folio()
        }
    }

    private var illustratedBand: some View {
        let bottom: CGFloat = [338, 340, 329, 345, 335][variant]
        return ZStack(alignment: .topLeading) {
            photo(0, 0, 300, bottom)
            rect(0, bottom, 300, 420 - bottom, variant == 2 || variant == 4 ? accent.opacity(0.55) : paper)
            label("OFFDAY", 15, 14, 85, 26, size: 13)
            if variant == 1 || variant == 3 { tape(216, 18, 63) }
            text(title, 19, bottom + 13, 113, 34, size: 26)
            sticker(0, 164, bottom - 11, 57, 62)
            sticker(1, 226, bottom + 8, 50, 49)
            if variant == 0 || variant == 4 { sticker(2, 131, bottom + 40, 25, 25) }
            folio(19, 400)
        }
    }

    private var travelJournal: some View {
        let x: CGFloat = [16, 12, 20, 14, 17][variant]
        return ZStack(alignment: .topLeading) {
            rect(0, 0, 300, 420, variant == 2 ? accent.opacity(0.36) : paper)
            photo(x, 48, 300 - x * 2, 315, border: variant == 1 ? 5 : 0)
            text(variant == 4 ? "WALK / LOOK / KEEP" : "the little travel journal", 18, 13, 242, 21, size: 11, design: .serif)
            sticker(0, 254, 7, 30, 35)
            label(title, variant == 3 ? 166 : 24, 344, 112, 40, size: 25)
            sticker(1, variant == 3 ? 19 : 220, 357, 59, 43)
            if variant == 1 || variant == 4 { sticker(2, variant == 3 ? 83 : 185, 376, 28, 25) }
            tape(variant == 0 ? 185 : 35, 39, variant == 2 ? 76 : 54)
            folio()
        }
    }
}

private enum EditorialImageCache {
    private static let cache = NSCache<NSString, NSImage>()
    static func image(named name: String) -> NSImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let resource = EditorialAssetLibrary.root,
              let image = NSImage(contentsOf: resource.appendingPathComponent("EditorialAssets")
                .appendingPathComponent(name).appendingPathExtension("png")) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }
}
