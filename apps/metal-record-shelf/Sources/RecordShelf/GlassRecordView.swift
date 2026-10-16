import SwiftUI

/// The glass pigment is the album's own artwork, softened into a translucent swirl.
/// The artwork remains live: changing an album changes the entire disc, not only its label.
struct GlassRecordView: View {
    let album: RecordAlbum

    var body: some View {
        AsyncImage(url: album.artwork) { phase in
            glass(image: phase.image)
        }
        .frame(width: 84, height: 84)
        .shadow(color: .black.opacity(0.23), radius: 3.5, x: 1.5, y: 4)
        .accessibilityHidden(true)
    }

    private func glass(image: Image?) -> some View {
        ZStack {
            Circle().fill(.white.opacity(0.13))
            if let image {
                // A broad colour field with a second soft pool gives each record
                // its own flowing pigment while retaining the source palette.
                image.resizable().scaledToFill()
                    .frame(width: 110, height: 110)
                    .saturation(1.28)
                    .blur(radius: 7)
                    .opacity(0.86)
                    .offset(x: -6, y: 3)
                image.resizable().scaledToFill()
                    .frame(width: 96, height: 96)
                    .saturation(1.16)
                    .blur(radius: 13)
                    .offset(x: 25, y: -24)
                    .opacity(0.44)
                    .blendMode(.screen)
            } else {
                Circle().fill(LinearGradient(colors: [.white.opacity(0.35), .gray.opacity(0.22), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            Circle()
                .fill(LinearGradient(stops: [
                    .init(color: .white.opacity(0.36), location: 0),
                    .init(color: .white.opacity(0.03), location: 0.27),
                    .init(color: .clear, location: 0.58),
                    .init(color: .black.opacity(0.10), location: 0.90),
                    .init(color: .white.opacity(0.26), location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .fill(RadialGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.76),
                    .init(color: .white.opacity(0.10), location: 0.92),
                    .init(color: .white.opacity(0.44), location: 0.98),
                    .init(color: .black.opacity(0.12), location: 1)
                ], center: .center, startRadius: 0, endRadius: 42))
            // Subtle concentric tooling marks, kept behind the sharp paper label.
            ForEach(0..<13, id: \.self) { index in
                Circle()
                    .stroke(.white.opacity(index.isMultiple(of: 3) ? 0.12 : 0.045), lineWidth: 0.3)
                    .padding(CGFloat(4) + CGFloat(index) * 1.7)
            }
            Circle().trim(from: 0.54, to: 0.77)
                .stroke(LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.86), .white.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
                .padding(2.2)
                .blur(radius: 0.3)
            Circle().trim(from: 0.02, to: 0.19)
                .stroke(.white.opacity(0.43), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
                .padding(3)
            Circle()
                .stroke(AngularGradient(colors: [.cyan.opacity(0.42), .white.opacity(0.66), .pink.opacity(0.30), .orange.opacity(0.24), .white.opacity(0.76), .cyan.opacity(0.42)], center: .center), lineWidth: 0.75)
                .padding(0.6)
            Circle().stroke(.white.opacity(0.22), lineWidth: 0.5).frame(width: 32, height: 32)
            if let image {
                image.resizable().scaledToFill()
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 0.65))
                    .shadow(color: .black.opacity(0.15), radius: 0.8, y: 0.6)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(width: 84, height: 84)
        .compositingGroup()
        .mask {
            GlassDiscCutout().fill(style: FillStyle(eoFill: true))
        }
        .overlay {
            Circle().stroke(.white.opacity(0.8), lineWidth: 0.65).frame(width: 4.2, height: 4.2)
                .shadow(color: .black.opacity(0.24), radius: 0.4, y: 0.5)
        }
    }
}

private struct GlassDiscCutout: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect)
        path.addEllipse(in: CGRect(x: rect.midX - 2.1, y: rect.midY - 2.1, width: 4.2, height: 4.2))
        return path
    }
}
