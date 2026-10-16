import AppKit
import SwiftUI

struct MagazineMockupGeometry: Equatable {
    let variant: Int
    let depth: CGFloat
    let yaw: Double
    let lean: Double

    init(seed: Int) {
        let bits = UInt64(bitPattern: Int64(seed))
        variant = Int((bits &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407) % 5)
        depth = [11, 15, 12, 17, 13][variant]
        yaw = [-6, 4, -3, 8, 2][variant]
        lean = [-1.9, 1.4, -0.65, 2.1, 0.7][variant]
    }
}

/// A thin, face-out magazine: the generated artwork remains the whole front cover.
/// All dimensions below are in a 300 × 420 drawing space, independent of the slot size.
struct MagazineMockup: View {
    let image: NSImage
    let template: Int
    let seed: Int

    private var geometry: MagazineMockupGeometry { MagazineMockupGeometry(seed: seed) }
    private var variant: Int { geometry.variant }
    private var depth: CGFloat { geometry.depth }
    private var yaw: Double { geometry.yaw }
    private var lean: Double { geometry.lean }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 300, geometry.size.height / 420)
            publication
                .rotation3DEffect(.degrees(yaw), axis: (x: 0, y: 1, z: 0), anchor: .center, perspective: 0.22)
                .rotationEffect(.degrees(lean), anchor: .bottom)
                .frame(width: 300, height: 420)
                .scaleEffect(scale, anchor: .bottomLeading)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottomLeading)
        }
        .accessibilityHidden(true)
    }

    private var publication: some View {
        ZStack(alignment: .topLeading) {
            // A compact contact shadow makes the bottom edge sit on the shelf lip.
            Ellipse()
                .fill(.black.opacity(0.24))
                .frame(width: 267, height: 7)
                .blur(radius: 3)
                .offset(x: 16, y: 404)

            // The rear cover peeks beyond the fore-edge, rather than a thick hardback board.
            paperEdge
                .fill(Color(red: 0.25, green: 0.24, blue: 0.21))
                .offset(x: 1.1, y: 1.5)
                .shadow(color: .black.opacity(0.23), radius: 3.5, x: 3, y: 3)

            paperEdge
                .fill(LinearGradient(stops: [
                    .init(color: Color(red: 0.91, green: 0.89, blue: 0.82), location: 0),
                    .init(color: Color(red: 0.99, green: 0.98, blue: 0.93), location: 0.35),
                    .init(color: Color(red: 0.75, green: 0.73, blue: 0.67), location: 1)
                ], startPoint: .leading, endPoint: .trailing))

            if let texture = paperTexture("book-pages") {
                Image(nsImage: texture)
                    .resizable()
                    .frame(width: 300, height: 420)
                    .blendMode(.multiply)
                    .opacity(0.7)
                    .clipShape(paperEdge)
            }

            Canvas { context, _ in
                // Individual leaves remain hairlines at the final 98 pt slot width.
                for index in 0..<83 {
                    let y = 19 + CGFloat(index) * 4.64
                    let ripple = sin(CGFloat(index) * 1.71 + CGFloat(variant)) * 0.7
                    var line = Path()
                    line.move(to: CGPoint(x: 287.5, y: y))
                    line.addQuadCurve(to: CGPoint(x: 287 + depth, y: y + 3.5 + ripple), control: CGPoint(x: 292, y: y + 2.7))
                    context.stroke(line, with: .color(.black.opacity(index % 3 == 0 ? 0.19 : 0.08)), lineWidth: 0.6)
                }
                for index in 0..<5 {
                    let offset = CGFloat(index) * 0.85
                    var line = Path()
                    line.move(to: CGPoint(x: 15, y: 403 + offset))
                    line.addQuadCurve(to: CGPoint(x: 287 + depth, y: 407 + offset), control: CGPoint(x: 154, y: 407 + offset))
                    context.stroke(line, with: .color(.black.opacity(0.13)), lineWidth: 0.5)
                }
            }
            .clipShape(paperEdge)

            MagazineCover(image: image, template: template, seed: seed)
                .frame(width: 278, height: 394)
                .overlay {
                    // Narrow binding trough, broad low-opacity laminate, crisp fore-edge.
                    HStack(spacing: 0) {
                        LinearGradient(stops: [
                            .init(color: .black.opacity(0.39), location: 0),
                            .init(color: .white.opacity(0.12), location: 0.24),
                            .init(color: .black.opacity(0.12), location: 0.49),
                            .init(color: .clear, location: 1)
                        ], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 19)
                        .overlay {
                            if let texture = paperTexture("book-binding") {
                                Image(nsImage: texture).resizable()
                                    .blendMode(.multiply).opacity(0.14)
                            }
                        }
                        Spacer(minLength: 0)
                        LinearGradient(colors: [.clear, .white.opacity(0.29), .black.opacity(0.18)], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 4)
                    }
                }
                .overlay {
                    LinearGradient(stops: [
                        .init(color: .white.opacity(0.11), location: 0),
                        .init(color: .clear, location: 0.27),
                        .init(color: .white.opacity(0.015), location: 0.52),
                        .init(color: .white.opacity(0.10), location: 0.69),
                        .init(color: .clear, location: 0.83),
                        .init(color: .black.opacity(0.07), location: 1)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                .clipShape(MagazineFace())
                .overlay { MagazineFace().stroke(.black.opacity(0.20), lineWidth: 0.65) }
                .offset(x: 10, y: 10)
        }
        .frame(width: 300, height: 420)
    }

    private func paperTexture(_ name: String) -> NSImage? {
        guard let url = EditorialAssetLibrary.root?.appendingPathComponent("EditorialAssets/\(name).png") else { return nil }
        return PhotoImageCache.image(at: url)
    }

    private var paperEdge: Path {
        Path { path in
            path.move(to: CGPoint(x: 12, y: 12))
            path.addLine(to: CGPoint(x: 287, y: 10))
            path.addQuadCurve(to: CGPoint(x: 287 + depth, y: 15), control: CGPoint(x: 294, y: 10))
            path.addLine(to: CGPoint(x: 287 + depth, y: 406))
            path.addQuadCurve(to: CGPoint(x: 17, y: 407), control: CGPoint(x: 151, y: 410))
            path.closeSubpath()
        }
    }
}

private struct MagazineFace: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + 1.3, y: rect.minY + 1.2))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - 0.6, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.minY + 0.8))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - 1), control: CGPoint(x: rect.maxX - 1, y: rect.midY))
            path.addQuadCurve(to: CGPoint(x: rect.minX + 1.8, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.maxY - 0.5))
            path.addQuadCurve(to: CGPoint(x: rect.minX + 1.3, y: rect.minY + 1.2), control: CGPoint(x: rect.minX - 0.8, y: rect.midY))
            path.closeSubpath()
        }
    }
}
