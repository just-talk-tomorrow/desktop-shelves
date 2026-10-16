import AppKit
import SwiftUI

/// The frame construction changes together with the material, not just its tint.
enum RackTheme: String, CaseIterable {
    case oak, walnut, steel, acrylic, naturalWood, rams

    var title: String {
        switch self {
        case .naturalWood: return "自然木框 · 生图皮肤"
        case .rams: return "Rams · 生图皮肤"
        case .oak: return "橡木书店"
        case .walnut: return "胡桃木柜"
        case .steel: return "黑钢展架"
        case .acrylic: return "磨砂亚克力"
        }
    }
    var ink: Color {
        switch self {
        case .naturalWood, .rams: return Color(white:0.23)
        case .oak: return Color(red: 0.24, green: 0.17, blue: 0.10)
        case .walnut: return Color(red: 0.95, green: 0.87, blue: 0.73)
        case .steel: return Color(white: 0.88)
        case .acrylic: return Color(red: 0.22, green: 0.29, blue: 0.32)
        }
    }
    var rim: CGFloat {
        switch self { case .oak: return 12; case .walnut: return 14; case .steel: return 7; case .acrylic: return 10; case .naturalWood, .rams: return 8 }
    }
    var corner: CGFloat {
        switch self { case .oak: return 9; case .walnut: return 5; case .steel: return 3; case .acrylic: return 19; case .naturalWood, .rams: return 7 }
    }
    var isGenerated:Bool {self == .naturalWood || self == .rams}
    var aspect:CGFloat {isGenerated ? GeneratedRackMetrics.aspect:1}
    var skinImage:NSImage? {
        guard isGenerated,let root=EditorialAssetLibrary.root else{return nil}
        return NSImage(contentsOf:root.appendingPathComponent("EditorialAssets/skin-\(rawValue).png"))
    }
    fileprivate var isWood: Bool { self == .oak || self == .walnut }
    fileprivate var woodBase: Color {
        self == .walnut ? Color(red: 0.31, green: 0.19, blue: 0.12) : Color(red: 0.72, green: 0.51, blue: 0.29)
    }
}

struct RackMaterialBackground: View {
    let theme: RackTheme
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                if theme.isGenerated,let image=theme.skinImage { Image(nsImage:image).resizable() }
                else if theme.isWood { woodFrame(size: size) }
                else if theme == .steel { steelFrame(size: size) }
                else { acrylicFrame(size: size) }
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.corner))
        }
    }

    private func woodFrame(size: CGSize) -> some View {
        let rim = theme.rim
        return ZStack {
            WoodSurface(theme: theme, horizontal: false)
            // A recessed backing makes the solid wood stiles visibly thicker.
            ZStack {
                WoodSurface(theme: theme, horizontal: false)
                (theme == .oak ? Color(red: 0.94, green: 0.84, blue: 0.67) : Color(red: 0.21, green: 0.13, blue: 0.09)).opacity(theme == .oak ? 0.58 : 0.43)
                LinearGradient(colors: [.black.opacity(0.23), .clear, .clear, .black.opacity(0.07)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(Rectangle().strokeBorder(.black.opacity(0.29), lineWidth: 1))
            .padding(.horizontal, rim)
            .padding(.vertical, 30)
            VStack {
                WoodSurface(theme: theme, horizontal: true).frame(height: 30)
                    .overlay(alignment: .bottom) { Color.black.opacity(0.29).frame(height: 1) }
                Spacer(minLength: 0)
                WoodSurface(theme: theme, horizontal: true).frame(height: 30)
                    .overlay(alignment: .top) { Color.white.opacity(0.28).frame(height: 1) }
            }
            // Mortise seams and end-grain dowels are understated but recognisably joinery.
            ForEach([false, true], id: \.self) { right in
                ForEach([false, true], id: \.self) { bottom in
                    Circle()
                        .fill(theme == .oak ? Color(red: 0.43, green: 0.27, blue: 0.12) : Color(red: 0.53, green: 0.35, blue: 0.21))
                        .overlay(Circle().strokeBorder(.black.opacity(0.26), lineWidth: 0.6))
                        .overlay(alignment: .top) { Circle().fill(.white.opacity(0.2)).frame(width: 2, height: 1).offset(y: 1) }
                        .frame(width: 3.5, height: 3.5)
                        .position(x: right ? size.width - rim / 2 : rim / 2, y: bottom ? size.height - rim / 2 : rim / 2)
                }
            }
            RoundedRectangle(cornerRadius: theme.corner).strokeBorder(.white.opacity(0.36), lineWidth: 0.8)
        }
    }

    private func steelFrame(size: CGSize) -> some View {
        ZStack {
            Color(red: 0.12, green: 0.14, blue: 0.15)
            Rectangle().fill(Color(red: 0.18, green: 0.20, blue: 0.21)).padding(7)
                .overlay(Rectangle().strokeBorder(.black.opacity(0.7), lineWidth: 1).padding(7))
            HStack {
                steelPost
                Spacer()
                steelPost
            }
            VStack {
                LinearGradient(colors: [Color(white: 0.43), Color(white: 0.16)], startPoint: .top, endPoint: .bottom).frame(height: 5)
                Spacer()
                Color(white: 0.10).frame(height: 6)
            }
            ForEach([false, true], id: \.self) { right in
                ForEach([false, true], id: \.self) { bottom in
                    Circle().fill(Color(white: 0.57))
                        .overlay(Rectangle().fill(Color(white: 0.15)).frame(width: 2.5, height: 0.7).rotationEffect(.degrees(35)))
                        .frame(width: 3.8, height: 3.8)
                        .position(x: right ? size.width - 3.5 : 3.5, y: bottom ? size.height - 12 : 12)
                }
            }
        }
    }
    private var steelPost: some View {
        Rectangle().fill(LinearGradient(colors: [Color(white: 0.34), Color(white: 0.08), Color(white: 0.21)], startPoint: .leading, endPoint: .trailing)).frame(width: 7)
    }
    private func acrylicFrame(size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 19).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 19).fill(Color(red: 0.83, green: 0.93, blue: 0.96).opacity(0.36))
            RoundedRectangle(cornerRadius: 13).fill(.white.opacity(0.12)).padding(10)
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.45), lineWidth: 1).padding(10))
            LinearGradient(colors: [.white.opacity(0.28), .clear, Color(red: 0.63, green: 0.80, blue: 0.85).opacity(0.13)], startPoint: .topLeading, endPoint: .bottomTrailing)
            RoundedRectangle(cornerRadius: 19).strokeBorder(.white.opacity(0.82), lineWidth: 1.5)
            ForEach([false, true], id: \.self) { right in
                ForEach([false, true], id: \.self) { bottom in
                    Circle().fill(LinearGradient(colors: [.white, Color(white: 0.48), Color(white: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(Circle().strokeBorder(.black.opacity(0.22), lineWidth: 0.5))
                        .frame(width: 6, height: 6)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                        .position(x: right ? size.width - 12 : 12, y: bottom ? size.height - 12 : 12)
                }
            }
        }
    }
}

/// Grain is a bundled original texture; the deterministic fallback remains usable offline.
private struct WoodSurface: View {
    let theme: RackTheme
    let horizontal: Bool
    private var texture: NSImage? {
        guard let root = EditorialAssetLibrary.root else { return nil }
        return NSImage(contentsOf: root.appendingPathComponent("EditorialAssets/wood-\(theme.rawValue).png"))
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                theme.woodBase
                if let texture {
                    Image(nsImage: texture).resizable().scaledToFill()
                        .frame(width: horizontal ? geometry.size.height : geometry.size.width,
                               height: horizontal ? geometry.size.width : geometry.size.height)
                        .rotationEffect(.degrees(horizontal ? 90 : 0))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                } else {
                    WoodGrain(theme: theme, horizontal: horizontal)
                }
                LinearGradient(colors: [.white.opacity(0.14), .clear, .black.opacity(0.12)], startPoint: .leading, endPoint: .trailing)
            }.clipped()
        }
    }
}

private struct WoodGrain: View {
    let theme: RackTheme
    let horizontal: Bool
    var body: some View {
        Canvas { context, size in
            let width = horizontal ? size.height : size.width
            let height = horizontal ? size.width : size.height
            var grain = context
            if horizontal {
                grain.translateBy(x: size.width, y: 0)
                grain.rotate(by: .degrees(90))
            }
            for index in 0..<100 {
                let x = CGFloat(index) * width / 99
                let wave = CGFloat(sin(Double(index) * 2.1))
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addCurve(to: CGPoint(x: x + wave * 2, y: height), control1: CGPoint(x: x + wave * 8 + 3, y: height * 0.34), control2: CGPoint(x: x - wave * 6, y: height * 0.72))
                grain.stroke(path, with: .color((index % 3 == 0 ? Color.white : Color.black).opacity(index % 3 == 0 ? 0.09 : 0.12)), lineWidth: index % 7 == 0 ? 1.1 : 0.45)
            }
            for knot in 0..<3 {
                let x = width * [0.24, 0.72, 0.46][knot]
                let y = height * [0.22, 0.61, 0.86][knot]
                for ring in 0..<7 {
                    let r = CGFloat(ring + 1)
                    grain.stroke(Path(ellipseIn: CGRect(x: x - r * 1.4, y: y - r * 5, width: r * 2.8, height: r * 10)), with: .color(.black.opacity(0.09)), lineWidth: 0.6)
                }
            }
        }
    }
}

struct RackShelfLedge: View {
    let theme: RackTheme
    var body: some View {
        Group {
            if theme.isWood {
                WoodSurface(theme: theme, horizontal: true)
                    .overlay(LinearGradient(colors: [.white.opacity(0.30), .clear, .black.opacity(0.24)], startPoint: .top, endPoint: .bottom))
                    .overlay(alignment: .top) { Color.white.opacity(0.42).frame(height: 0.7) }
            } else if theme == .steel {
                VStack(spacing: 2) {
                    Capsule().fill(Color(white: 0.42)).frame(height: 1)
                    Capsule().fill(Color(white: 0.08)).frame(height: 2)
                }.frame(maxHeight: .infinity)
            } else {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(LinearGradient(colors: [.white.opacity(0.9), Color(red: 0.71, green: 0.86, blue: 0.9).opacity(0.65), .white.opacity(0.48)], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 1.5).strokeBorder(.white.opacity(0.85), lineWidth: 0.6))
            }
        }
        .frame(height: 6)
        .shadow(color: .black.opacity(theme == .acrylic ? 0.15 : 0.30), radius: 2, y: 3)
    }
}
