import SwiftUI

/// Each case is a different piece of furniture, not a palette applied to one rack.
struct RackTitle: View {
    let skin: RackSkin
    @ViewBuilder var body: some View {
        switch skin {
        case .rams:
            HStack(spacing: 7) {
                Circle().fill(Color(red: 0.87, green: 0.40, blue: 0.20)).frame(width: 4, height: 4)
                Text("唱片架").font(.system(size: 13, weight: .medium))
            }
        case .silver:
            HStack(spacing: 7) {
                Image(systemName: "opticaldisc").font(.system(size: 13, weight: .light))
                Text("RECORD SHELF").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.2)
            }
        case .walnut:
            Text("THE RECORD CABINET")
                .font(.system(size: 7, weight: .semibold, design: .serif)).tracking(0.9)
                .foregroundStyle(Color(red: 0.23, green: 0.16, blue: 0.08))
                .padding(.horizontal, 9).padding(.vertical, 7)
                .background(LinearGradient(colors: [Color(red: 0.86, green: 0.73, blue: 0.45), Color(red: 0.62, green: 0.47, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 2))
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(.white.opacity(0.22), lineWidth: 0.7))
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
        case .cream:
            VStack(alignment: .leading, spacing: 1) {
                Text("Records.").font(.system(size: 25, weight: .regular, design: .serif)).tracking(-1)
                Text("A PERSONAL COLLECTION").font(.system(size: 5.8, weight: .medium, design: .monospaced)).tracking(1.15)
            }
        case .sage:
            HStack(spacing: 5) {
                Circle().fill(Color(red: 0.32, green: 0.49, blue: 0.37)).frame(width: 4, height: 4)
                Text("sound / objects").font(.system(size: 9, weight: .medium)).tracking(0.4)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(.white.opacity(0.35), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.75), lineWidth: 0.7))
        case .graphite:
            HStack(alignment: .center, spacing: 7) {
                Text("01").font(.system(size: 17, weight: .black, design: .monospaced)).foregroundStyle(Color(red: 0.95, green: 0.56, blue: 0.25))
                VStack(alignment: .leading, spacing: 1) {
                    Text("STUDIO").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(2)
                    Text("RECORDS / ARCHIVE").font(.system(size: 5, design: .monospaced)).tracking(0.8).opacity(0.6)
                }
            }
        }
    }
}

struct RackBackdrop: View {
    let skin: RackSkin
    @ViewBuilder var body: some View {
        switch skin {
        case .rams: instrumentPanel
        case .silver: aluminium
        case .walnut: woodCabinet
        case .cream:
            Color(red: 0.95, green: 0.93, blue: 0.87)
                .overlay { paperGrain.opacity(0.6) }
        case .sage:
            ZStack {
                RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial)
                LinearGradient(colors: [Color(red: 0.84, green: 0.92, blue: 0.85).opacity(0.67), Color(red: 0.66, green: 0.80, blue: 0.73).opacity(0.42), .white.opacity(0.28)], startPoint: .topLeading, endPoint: .bottomTrailing)
                RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.7), lineWidth: 3).padding(3)
                HStack { acrylicPost; Spacer(); acrylicPost }.padding(.horizontal, 8).padding(.vertical, 20)
            }
        case .graphite:
            ZStack {
                LinearGradient(colors: [Color(white: 0.19), Color(white: 0.105)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Canvas { context, size in
                    for row in 0..<Int(size.height / 13) {
                        for col in 0..<Int(size.width / 13) {
                            let rect = CGRect(x: CGFloat(col) * 13 + 6, y: CGFloat(row) * 13 + 6, width: 2.6, height: 2.6)
                            context.fill(Path(ellipseIn: rect.offsetBy(dx: 0, dy: 0.7)), with: .color(.white.opacity(0.11)))
                            context.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.73)))
                        }
                    }
                }
                RoundedRectangle(cornerRadius: 5).strokeBorder(.black.opacity(0.5), lineWidth: 7)
            }
        }
    }
    private var instrumentPanel: some View {
        ZStack {
            Color(red: 0.894, green: 0.890, blue: 0.867)
            LinearGradient(colors: [.white.opacity(0.08), .clear, .black.opacity(0.015)], startPoint: .top, endPoint: .bottom)
            Canvas { context, _ in
                // A small functional detail; the album colours carry the composition.
                for index in 0..<4 {
                    let rect = CGRect(x: 170 + CGFloat(index) * 5, y: 11, width: 1, height: 4)
                    context.fill(Path(roundedRect: rect, cornerRadius: 0.5), with: .color(.black.opacity(0.12)))
                }
            }
        }
    }

    private var aluminium: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.94), Color(white: 0.84), Color(white: 0.68)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                for index in 0..<Int(size.width / 4) + 1 {
                    let x = CGFloat(index) * 4
                    context.fill(Path(CGRect(x: x, y: 0, width: 4, height: size.height)), with: .linearGradient(Gradient(stops: [.init(color: .black.opacity(0.13), location: 0), .init(color: .white.opacity(0.5), location: 0.36), .init(color: .white.opacity(0.08), location: 0.66), .init(color: .black.opacity(0.08), location: 1)]), startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x + 4, y: 0)))
                }
            }
            LinearGradient(colors: [.white.opacity(0.14), .clear, .black.opacity(0.08)], startPoint: .top, endPoint: .bottom)
        }
    }
    private var woodCabinet: some View {
        ZStack {
            woodGrain
            Color(red: 0.74, green: 0.68, blue: 0.55).padding(.horizontal, 14).padding(.top, 48).padding(.bottom, 47)
                .overlay { paperGrain.padding(.horizontal, 14).padding(.top, 48).padding(.bottom, 47) }
            // Heavy continuous side stiles make this a framed wooden cabinet.
            HStack {
                woodGrain.frame(width: 13).overlay(alignment: .trailing) { Rectangle().fill(.black.opacity(0.28)).frame(width: 2) }
                Spacer()
                woodGrain.frame(width: 13).overlay(alignment: .leading) { Rectangle().fill(.white.opacity(0.10)).frame(width: 1) }
            }
        }
    }
    private var woodGrain: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.42, green: 0.28, blue: 0.18), Color(red: 0.23, green: 0.14, blue: 0.085)], startPoint: .leading, endPoint: .trailing)
            Canvas { context, size in
                for index in 0..<Int(size.width / 3) + 2 {
                    var grain = Path(); let origin = CGFloat(index) * 3
                    grain.move(to: CGPoint(x: origin, y: 0))
                    for step in 1...50 {
                        let y = CGFloat(step) / 50 * size.height
                        grain.addLine(to: CGPoint(x: origin + sin(y / 58 + CGFloat(index) * 0.28) * 2, y: y))
                    }
                    context.stroke(grain, with: .color(index.isMultiple(of: 3) ? .black.opacity(0.22) : .white.opacity(0.055)), lineWidth: 0.7)
                }
            }
        }
    }
    private var paperGrain: some View {
        Canvas { context, size in
            for index in 0..<Int(size.height) {
                let y = CGFloat(index)
                var line = Path(); line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(.black.opacity(index.isMultiple(of: 3) ? 0.018 : 0.006)), lineWidth: 0.35)
            }
        }
    }
    private var acrylicPost: some View {
        RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.18)).frame(width: 5)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.6), lineWidth: 0.7))
    }
}

struct AlternateRackLedge: View {
    let skin: RackSkin
    var body: some View {
        switch skin {
        case .rams: instrumentLedge
        case .walnut: woodenLedge
        case .cream: galleryLedge
        case .sage: acrylicLedge
        case .graphite: studioLedge
        case .silver: Color.clear
        }
    }
    private var instrumentLedge: some View {
        ZStack(alignment: .bottom) {
            // One folded strip: lit top surface, restrained front edge, tiny returns.
            Rectangle().fill(Color(red: 0.44, green: 0.45, blue: 0.43)).frame(height: 3.5)
                .overlay(alignment: .top) { Rectangle().fill(Color(white: 0.79)).frame(height: 0.7) }
                .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.14)).frame(height: 0.5) }
            HStack {
                Rectangle().fill(Color(red: 0.44, green: 0.45, blue: 0.43)).frame(width: 1.3, height: 6)
                Spacer()
                Rectangle().fill(Color(red: 0.44, green: 0.45, blue: 0.43)).frame(width: 1.3, height: 6)
            }.padding(.horizontal, 2)
        }.frame(height: 8)
    }

    private var woodenLedge: some View {
        Rectangle()
            .fill(LinearGradient(colors: [Color(red: 0.49, green: 0.34, blue: 0.23), Color(red: 0.30, green: 0.19, blue: 0.12), Color(red: 0.37, green: 0.24, blue: 0.15)], startPoint: .top, endPoint: .bottom))
            .frame(height: 12)
            .overlay(alignment: .top) { Rectangle().fill(Color(red: 0.65, green: 0.47, blue: 0.31)).frame(height: 2) }
            .shadow(color: .black.opacity(0.34), radius: 2, y: 3)
    }
    private var galleryLedge: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(white: 0.16)).frame(height: 3)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 4)
            HStack { Rectangle().frame(width: 2, height: 9); Spacer(); Rectangle().frame(width: 2, height: 9) }.foregroundStyle(Color(white: 0.16)).padding(.horizontal, 3)
        }.frame(height: 10)
    }
    private var acrylicLedge: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.24)).frame(height: 9)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.85), lineWidth: 0.7))
                .shadow(color: Color(red: 0.22, green: 0.42, blue: 0.32).opacity(0.20), radius: 5, y: 4)
            HStack { foot; Spacer(); foot }.padding(.horizontal, 14).offset(y: 4)
        }.frame(height: 15)
    }
    private var foot: some View {
        RoundedRectangle(cornerRadius: 1).fill(.white.opacity(0.4)).frame(width: 5, height: 15)
            .overlay(RoundedRectangle(cornerRadius: 1).stroke(.white.opacity(0.65), lineWidth: 0.6))
    }
    private var studioLedge: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(LinearGradient(colors: [Color(white: 0.33), Color(white: 0.15), Color(white: 0.08)], startPoint: .top, endPoint: .bottom)).frame(height: 12)
                .overlay(alignment: .top) { Rectangle().fill(Color(white: 0.50)).frame(height: 1) }
            HStack(spacing: 17) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1).fill(Color(white: 0.42)).frame(height: 2)
                        .overlay(alignment: .leading) { Rectangle().fill(Color(white: 0.35)).frame(width: 2, height: 9).offset(y: 4) }
                        .overlay(alignment: .trailing) { Rectangle().fill(Color(white: 0.35)).frame(width: 2, height: 9).offset(y: 4) }
                }
            }.padding(.horizontal, 10).offset(y: -15)
        }.frame(height: 25).shadow(color: .black.opacity(0.38), radius: 3, y: 4)
    }
}

struct CabinetDividers: View {
    let row: Int
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Spacer().frame(width: geometry.size.width * (row.isMultiple(of: 2) ? 0.33 : 0.62))
                Rectangle().fill(LinearGradient(colors: [Color(red: 0.48, green: 0.33, blue: 0.22), Color(red: 0.25, green: 0.16, blue: 0.10)], startPoint: .leading, endPoint: .trailing)).frame(width: 7)
                    .shadow(color: .black.opacity(0.22), radius: 2, x: 3)
                Spacer()
            }
        }
    }
}
