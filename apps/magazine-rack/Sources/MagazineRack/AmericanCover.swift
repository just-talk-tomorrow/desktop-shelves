import AppKit
import SwiftUI

/// Mid-century American photo keepsakes: eight construction families, five editions each.
struct AmericanCover: View {
    let image: NSImage
    let template: Int
    let seed: Int

    private var index: Int { modulo(template, 40) }
    private var family: Int { index / 5 }
    private var variant: Int { index % 5 }
    private var cream: Color { Color(red: 0.97, green: 0.92, blue: 0.80) }
    private var navy: Color { Color(red: 0.13, green: 0.23, blue: 0.29) }
    private var cherry: Color { Color(red: 0.73, green: 0.20, blue: 0.16) }
    private var teal: Color { Color(red: 0.20, green: 0.47, blue: 0.46) }
    private var gold: Color { Color(red: 0.81, green: 0.57, blue: 0.25) }
    private var accent: Color { [cherry, teal, navy, gold, cherry][variant] }
    private var title: String {
        let titles = ["DAY TRIP", "OPEN ROAD", "GOOD TIMES", "SUMMER CLUB", "FIELD NOTES",
                      "SLOW SUNDAY", "OUT OF TOWN", "WEEKENDERS", "THE GOOD LIFE", "HAPPY TRAILS",
                      "LOCAL FAVORITES", "GOLDEN HOUR", "LITTLE ESCAPES", "WISH YOU WERE HERE",
                      "TAKE IT EASY", "JUST WANDERING", "SUNNY SIDE", "AFTER HOURS", "HOME AGAIN", "ON VACATION"]
        return titles[modulo(seed &+ (index * 7), titles.count)]
    }
    private func modulo(_ n: Int, _ m: Int) -> Int { ((n % m) + m) % m }
    private func resource(_ name: String) -> NSImage? { AmericanAssetCache.load(name) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                composition.frame(width: 300, height: 420).clipped()
                    .scaleEffect(x: proxy.size.width / 300, y: proxy.size.height / 420, anchor: .topLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading).clipped()
        }
        .accessibilityLabel("\(title) · American vintage · \(index + 1)")
    }

    private var composition: some View {
        ZStack(alignment: .topLeading) {
            cream
            switch family {
            case 0: roadsidePostcard
            case 1: dinerJournal
            case 2: ticketAlbum
            case 3: travelAnnual
            case 4: motelKeepsake
            case 5: fieldCompanion
            case 6: sunnyClub
            default: photoGazette
            }
        }
    }

    private func rectangle(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) -> some View {
        Rectangle().fill(color).frame(width: w, height: h).position(x: x + w / 2, y: y + h / 2)
    }
    private func photo(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                       anchor: Alignment = .center, border: CGFloat = 0) -> some View {
        let visibleHeight = y < 100 && h > 280 ? min(h, 350-y) : h
        return Image(nsImage: image).resizable().scaledToFill().frame(width: w, height: visibleHeight, alignment: anchor).clipped()
            .overlay(Rectangle().strokeBorder(cream, lineWidth: border))
            .position(x: x + w / 2, y: y + visibleHeight / 2)
    }
    private func caption(_ words: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                         size: CGFloat = 28, color: Color? = nil, weight: Font.Weight = .heavy,
                         design: Font.Design = .serif, alignment: Alignment = .leading) -> some View {
        Text(words).font(.system(size: size, weight: weight, design: design))
            .tracking(size < 12 ? 1.3 : -0.4).foregroundStyle(color ?? navy)
            .lineLimit(1).minimumScaleFactor(0.3)
            .frame(width: w, height: h, alignment: alignment).clipped()
            .position(x: x + w / 2, y: y + h / 2)
    }
    private func sticker(_ ordinal: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> some View {
        let number = modulo((seed &* 5) &+ (family * 3) &+ (variant * 7) &+ (ordinal * 11), 36) + 1
        return Group {
            if let art = resource(String(format: "american-%02d", number)) {
                Image(nsImage: art).resizable().scaledToFit().frame(width: w, height: h)
                    .position(x: x + w / 2, y: y + h / 2)
            }
        }
    }
    private func paperLabel(_ words: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                            ordinal: Int = 0, size: CGFloat = 15) -> some View {
        ZStack {
            if let art = resource(String(format: "paper-%02d", [7,8,9,10,11,12,22][modulo(seed &+ index &+ ordinal, 7)])) {
                Image(nsImage: art).resizable().scaledToFit()
            } else {
                Rectangle().fill(cream)
            }
            Text(words).font(.system(size: size, weight: .bold, design: .serif)).tracking(0.8)
                .foregroundStyle(navy).lineLimit(1).minimumScaleFactor(0.3).padding(.horizontal, 8)
        }.frame(width: w, height: h).position(x: x + w / 2, y: y + h / 2)
    }
    private func tape(_ x: CGFloat, _ y: CGFloat, width: CGFloat = 59) -> some View {
        Group {
            if let art = resource(String(format: "paper-%02d", modulo(seed &+ variant &+ 13, 6) + 1)) {
                Image(nsImage: art).resizable().scaledToFit()
            } else {
                Rectangle().fill(gold.opacity(0.55))
            }
        }.frame(width: width, height: 18).position(x: x + width / 2, y: y + 9)
    }
    private func smallPrint(_ color: Color? = nil) -> some View {
        caption("PERSONAL PHOTO ARCHIVE  /  NO. \(String(format: "%02d", index + 1))", 17, 400, 267, 9,
                size: 6.5, color: color, weight: .medium, design: .monospaced)
    }
    private func checker(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ color: Color) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<20) { i in
                VStack(spacing: 0) {
                    Rectangle().fill(i % 2 == 0 ? color : cream)
                    Rectangle().fill(i % 2 == 0 ? cream : color)
                }
            }
        }.frame(width: w, height: 12).position(x: x + w / 2, y: y + 6)
    }

    private var roadsidePostcard: some View {
        let top: CGFloat = [47, 60, 38, 49, 34][variant]
        let photoHeight: CGFloat = [315, 306, 324, 316, 330][variant]
        return ZStack(alignment: .topLeading) {
            photo(14, top, 272, photoHeight, border: variant == 3 ? 4 : 0)
            caption(variant == 4 ? "GREETINGS FROM" : "THE WEEKEND POST", 17, 12, 218, 18, size: 11, color: accent)
            if variant == 1 || variant == 4 {
                caption(title, 18, top - 2, 264, 35, size: 29, color: cream)
                paperLabel("a little getaway", 18, 361, 146, 26, size: 11)
            } else {
                caption(title, 18, 363, 234, 32, size: 29, color: accent)
                tape(28, top - 8)
            }
            sticker(0, 244, 7, 39, 39)
            sticker(1, variant == 2 ? 197 : 243, 359, variant == 2 ? 40 : 43, 38)
            if variant == 2 { sticker(2, 250, 375, 27, 23) }
            smallPrint()
        }
    }

    private var dinerJournal: some View {
        let top: CGFloat = [47, 35, 55, 44, 30][variant]
        return ZStack(alignment: .topLeading) {
            rectangle(0, 0, 300, 420, variant == 3 ? teal.opacity(0.2) : cream)
            photo(12, top, 276, 317)
            checker(0, 0, 300, accent)
            caption(variant == 2 ? "SUNDAY SPECIAL" : "GOOD COMPANY", 17, 17, 222, 22, size: 16, color: accent)
            if variant == 0 || variant == 3 {
                paperLabel(title, 18, 350, 194, 40, size: 25)
                sticker(0, 220, 347, 62, 56)
                sticker(1, 173, 378, 35, 28)
            } else {
                caption(title, 19, 365, 213, 29, size: 26, color: accent, design: .rounded)
                sticker(0, 235, 355, 49, 46)
                sticker(1, 247, 14, 35, 32)
                if variant == 4 { paperLabel("OPEN ALL WEEKEND", 20, 324, 138, 25, size: 8) }
            }
            smallPrint()
        }
    }

    private var ticketAlbum: some View {
        let top: CGFloat = [41, 50, 33, 42, 55][variant]
        return ZStack(alignment: .topLeading) {
            rectangle(0, 0, 300, 420, accent.opacity(0.25))
            photo(16, top, 268, 321, border: variant == 1 ? 3 : 0)
            caption("ONE WAY TO A GOOD DAY", 17, 12, 255, 19, size: 9, color: navy, design: .monospaced)
            rectangle(14, 350, 272, 42, cream)
            Path { path in path.move(to: CGPoint(x: 229, y: 354)); path.addLine(to: CGPoint(x: 229, y: 388)) }
                .stroke(navy.opacity(0.5), style: StrokeStyle(lineWidth: 0.7, dash: [2, 3]))
            caption(title, 22, 354, 198, 31, size: 26, color: accent)
            caption(String(format: "%03d", index + 1), 239, 362, 39, 17, size: 12, color: navy, design: .monospaced)
            sticker(0, variant == 1 ? 242 : 20, top - 10, 39, 41)
            sticker(1, variant == 1 ? 201 : 248, 381, 30, 25)
            if variant == 2 || variant == 4 { tape(175, top - 8, width: 66) }
            smallPrint()
        }
    }

    private var travelAnnual: some View {
        let left: CGFloat = variant == 2 ? 31 : 13
        return ZStack(alignment: .topLeading) {
            rectangle(0, 0, 300, 420, variant == 1 ? navy : cream)
            if variant == 2 { rectangle(0, 0, 21, 420, accent) }
            photo(left, 58, 287 - left, 320)
            caption(title, variant == 2 ? 31 : 16, 15, variant == 2 ? 251 : 268, 32,
                    size: variant == 4 ? 33 : 30, color: variant == 1 ? cream : accent)
            if variant == 0 || variant == 3 {
                paperLabel("NOTES FROM THE ROAD", 21, 352, 160, 27, size: 10)
                sticker(0, 226, 354, 56, 45)
                sticker(1, 183, 376, 33, 26)
            } else {
                sticker(0, 22, 358, 45, 43)
                sticker(1, 240, 365, 41, 34)
                paperLabel("a personal edition", 94, 371, 128, 21, size: 8)
            }
            smallPrint(variant == 1 ? cream : navy)
        }
    }

    private var motelKeepsake: some View {
        let top: CGFloat = [43, 57, 35, 49, 42][variant]
        return ZStack(alignment: .topLeading) {
            rectangle(0, 0, 300, 420, variant == 3 ? navy : cream)
            photo(11, top, 278, 324)
            caption(variant == 4 ? "ROOM FOR DAYDREAMS" : "VACANCY / WEEKEND CLUB", 16, 12, 265, 18,
                    size: 10, color: variant == 3 ? cream : accent, design: .rounded)
            if variant == 1 || variant == 4 {
                paperLabel(title, 21, 351, 210, 39, size: 27)
                sticker(0, 239, 342, 45, 58)
            } else {
                caption(title, 17, 367, 238, 27, size: 27, color: variant == 3 ? cream : accent, design: .rounded)
                sticker(0, 244, 363, 39, 38)
            }
            sticker(1, variant == 0 ? 23 : 243, top - 12, 39, 40)
            if variant == 2 || variant == 3 { tape(42, top - 8) }
            if variant == 4 { sticker(2, 195, 384, 26, 24) }
            smallPrint(variant == 3 ? cream : navy)
        }
    }

    private var fieldCompanion: some View {
        let upper: CGFloat = [246, 261, 251, 247, 255][variant]
        return ZStack(alignment: .topLeading) {
            rectangle(0, 0, 300, 420, variant == 2 ? teal.opacity(0.2) : cream)
            photo(12, 36, 276, upper)
            photo(variant == 1 || variant == 4 ? 151 : 17, upper + 45, 133, 104,
                  anchor: variant % 2 == 0 ? .leading : .trailing, border: 4)
            caption("THE FIELD COMPANION", 17, 9, 225, 18, size: 10, color: accent, design: .monospaced)
            tape(variant == 1 ? 190 : 34, 28, width: 63)
            let x: CGFloat = variant == 1 || variant == 4 ? 17 : 162
            caption(title, x, upper + 49, 121, 35, size: 25, color: accent)
            sticker(0, x + 15, upper + 88, 48, 43)
            sticker(1, 252, 7, 30, 27)
            if variant == 3 { sticker(2, 251, 374, 28, 27) }
            smallPrint()
        }
    }

    private var sunnyClub: some View {
        let end: CGFloat = [339, 350, 329, 341, 335][variant]
        return ZStack(alignment: .topLeading) {
            photo(0, 0, 300, end)
            rectangle(0, end, 300, 420 - end, variant == 2 ? teal : cream)
            paperLabel(variant == 4 ? "SUNSHINE CLUB" : "OFF DUTY", 15, 14, 112, 26, size: 11)
            caption(title, 17, end + 11, 196, 33, size: 27, color: variant == 2 ? cream : accent, design: .rounded)
            sticker(0, 220, end - 9, 61, 59)
            sticker(1, 179, end + 36, 32, 27)
            if variant == 1 || variant == 3 { tape(217, 17, width: 63) }
            if variant == 4 { checker(0, 388, 300, cherry) }
            smallPrint(variant == 2 ? cream : navy)
        }
    }

    private var photoGazette: some View {
        let top: CGFloat = [54, 43, 64, 45, 52][variant]
        return ZStack(alignment: .topLeading) {
            rectangle(0, 0, 300, 420, variant == 4 ? gold.opacity(0.26) : cream)
            caption(variant == 3 ? "THE LOCAL" : "WEEKEND GAZETTE", 16, 11, 268, 26, size: variant == 3 ? 30 : 24, color: accent)
            rectangle(16, 40, 268, 1, navy.opacity(0.5))
            photo(14, top, 272, 316)
            if variant == 0 || variant == 2 {
                paperLabel(title, 21, 352, 206, 37, size: 26)
                sticker(0, 236, 348, 47, 52)
            } else {
                caption(title, 19, 365, 219, 31, size: 27, color: accent)
                sticker(0, 245, 357, 39, 42)
            }
            sticker(1, variant == 1 ? 23 : 243, top - 8, 35, 33)
            if variant == 4 { sticker(2, 207, 379, 25, 22) }
            smallPrint()
        }
    }
}

private enum AmericanAssetCache {
    private static let images = NSCache<NSString, NSImage>()
    static func load(_ name: String) -> NSImage? {
        if let image = images.object(forKey: name as NSString) { return image }
        guard let directory = EditorialAssetLibrary.root?.appendingPathComponent("EditorialAssets"),
              let image = NSImage(contentsOf: directory.appendingPathComponent(name).appendingPathExtension("png")) else { return nil }
        images.setObject(image, forKey: name as NSString)
        return image
    }
}
