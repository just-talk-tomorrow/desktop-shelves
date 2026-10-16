import AppKit
import SwiftUI

/// A small physical record rack. All artwork comes from the connected library.
struct MetalShelfView: View {
    @ObservedObject var model: ShelfModel
    @State private var hoveredAlbum: String?

    private var darkRack: Bool { model.rackSkin == .graphite || model.rackSkin == .walnut }
    private var ink: Color { darkRack ? Color(white: 0.94) : Color(red: 0.20, green: 0.22, blue: 0.23) }
    private var rackRadius: CGFloat { model.rackSkin == .rams ? 22 : model.rackSkin == .cream ? 2 : model.rackSkin == .walnut ? 5 : model.rackSkin == .graphite ? 7 : model.rackSkin == .sage ? 22 : 18 }
    private var headerHeight: CGFloat { model.rackSkin == .rams ? 56 : model.rackSkin == .cream ? 60 : model.rackSkin == .sage ? 52 : model.rackSkin == .graphite ? 44 : model.rackSkin == .walnut ? 50 : 48 }
    private var rowHeight: CGFloat { model.rackSkin == .rams ? 110 : model.rackSkin == .cream ? 108 : model.rackSkin == .sage || model.rackSkin == .walnut ? 112 : 114 }
    private var footerHeight: CGFloat { 436 - headerHeight - rowHeight * 3 }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 23)
                .frame(height: headerHeight)
            ZStack {
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { row in
                        shelfRow(row)
                    }
                }
                if model.albums.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, 18)
            footer
                .frame(height: footerHeight)
        }
        .frame(width: 360, height: 436)
        .background { RackBackdrop(skin: model.rackSkin) }
        .clipShape(RoundedRectangle(cornerRadius: rackRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: rackRadius, style: .continuous)
                .strokeBorder(LinearGradient(colors: model.rackSkin == .rams ? [.white.opacity(0.70), .black.opacity(0.07)] : model.rackSkin == .cream ? [.black.opacity(0.55), .black.opacity(0.55)] : [.white.opacity(0.95), .white.opacity(0.25), .black.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: model.rackSkin == .cream || model.rackSkin == .rams ? 0.65 : 1)
        }
        .shadow(color: .black.opacity(model.rackSkin == .rams ? 0.10 : 0.23), radius: model.rackSkin == .rams ? 6 : 17, x: 0, y: model.rackSkin == .rams ? 4 : 12)
        .scaleEffect(ShelfGeometry.scale, anchor: .topLeading)
        .frame(width: ShelfGeometry.cabinetWidth, height: ShelfGeometry.cabinetHeight, alignment: .topLeading)
        .padding(ShelfGeometry.padding)
        .preferredColorScheme(darkRack ? .dark : .light)
    }

    private var header: some View {
        HStack(spacing: 5) {
            RackTitle(skin: model.rackSkin)
            Spacer(minLength: 4)
            Menu {
                Picker("架子材质", selection: $model.rackSkin) {
                    ForEach(RackSkin.allCases, id: \.self) { skin in
                        Text(skin.displayName).tag(skin)
                    }
                }
                Picker("唱片颜色", selection: $model.discStyle) {
                    ForEach(DiscStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
            } label: {
                Image(systemName: "paintpalette")
                    .font(.system(size: 11, weight: .regular))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("切换架子皮肤和唱片颜色")
            .accessibilityLabel("架子皮肤和唱片颜色")
            Button { withAnimation(.easeInOut(duration: 0.28)) { model.shuffleArrangement() } } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 11, weight: .regular))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("随机摆放")
            .accessibilityLabel("随机摆放")
            Button { model.showConnection() } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .regular))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("连接网易云 / 管理唱片架")
            .accessibilityLabel("连接网易云和唱片架设置")
        }
        .foregroundStyle(ink.opacity(0.88))
        .shadow(color: model.rackSkin == .rams ? .clear : darkRack ? .black.opacity(0.4) : .white.opacity(0.9), radius: 0, y: 1)
    }

    private func shelfRow(_ row: Int) -> some View {
        let displayItems = ShelfArrangement.displayItems(model.visibleAlbums, seed: model.layoutSeed)
        let rows = ShelfArrangement.rows(displayItems, seed: model.layoutSeed)
        let albums = row < rows.count ? rows[row] : []
        let previousCount = rows.prefix(row).reduce(0) { $0 + $1.count }
        let arrangedItems = rows.flatMap { $0 }
        let variation = model.layoutSeed >> (row * 11)
        let alignment: Alignment = switch variation % 3 {
        case 0: .leading
        case 1: .center
        default: .trailing
        }
        let spacing = model.rackSkin == .rams ? CGFloat(11) : model.rackSkin == .walnut ? CGFloat(14) : model.rackSkin == .cream ? CGFloat(12) : CGFloat(8 + (variation >> 3) % 14)
        return ZStack(alignment: .bottom) {
            if model.rackSkin == .walnut {
                CabinetDividers(row: row).padding(.bottom, 12)
            }
            // The shallow shadow is cast by the ledge onto the ribbed back panel.
            Rectangle()
                .fill(.black.opacity(model.rackSkin == .rams ? 0.09 : 0.28))
                .frame(height: model.rackSkin == .rams ? 3 : 7)
                .blur(radius: model.rackSkin == .rams ? 3 : 6)
                .offset(y: model.rackSkin == .rams ? 3 : 9)
                .padding(.horizontal, 5)
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(albums.enumerated()), id: \.element.id) { entry in
                    let item = entry.element
                    let primaryIndex = arrangedItems.firstIndex { $0.album.id == item.album.id && !$0.isCompanion } ?? (previousCount + entry.offset)
                    album(item.album, index: primaryIndex, isCompanion: item.isCompanion)
                }
            }
            // Side insets accommodate the per-record offsets, even on a full row.
            .frame(maxWidth: .infinity, alignment: model.rackSkin == .walnut || model.rackSkin == .cream || model.rackSkin == .rams ? .center : alignment)
            .padding(.horizontal, 8)
            .padding(.bottom, model.rackSkin == .cream ? 8 : 14)
            rackLedge
        }
        .frame(height: rowHeight)
    }

    private func album(_ album: RecordAlbum, index: Int, isCompanion: Bool = false) -> some View {
        let hoverID = album.id + (isCompanion ? "-companion" : "-primary")
        let arrangement = ShelfArrangement.style(for: album.id, seed: model.layoutSeed, index: index)
        let scale = min(90, max(66, arrangement.size)) / 84
        let isDisc = isCompanion ? !arrangement.isDisc : arrangement.isDisc
        return Button { model.openAlbum(album) } label: {
            ZStack(alignment: .bottomTrailing) {
                if isDisc {
                    compactDisc(album, color: model.discColor(for: album.id))
                } else {
                    albumCover(album)
                }
                if hoveredAlbum == hoverID {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 25, height: 25)
                        .background(.black.opacity(0.7), in: Circle())
                        .padding(5)
                }
            }
            .scaleEffect(scale, anchor: .bottom)
            .frame(width: 88, height: 86, alignment: .bottom)
            .contentShape(Rectangle())
            .offset(x: min(5, max(-5, arrangement.xOffset)), y: hoveredAlbum == hoverID ? -3 : 0)
            .animation(.easeOut(duration: 0.16), value: hoveredAlbum == hoverID)
        }
        .buttonStyle(.plain)
        .onHover { hoveredAlbum = $0 ? hoverID : nil }
        .help("\(album.title) · \(album.artist)\(isCompanion ? " · 配套展示" : "")\n点击在网易云客户端播放专辑首曲")
        .accessibilityLabel("\(album.title)，\(album.artist)\(isCompanion ? "，配套展示" : "")，在网易云播放专辑首曲")
    }

    private func albumCover(_ album: RecordAlbum) -> some View {
        artwork(album)
            .frame(width: 83, height: 83)
            .clipped()
            .overlay {
                Rectangle()
                    .strokeBorder(.white.opacity(0.55), lineWidth: 1)
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(LinearGradient(colors: [.black.opacity(0.30), .white.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 4)
            }
            .overlay {
                LinearGradient(colors: [.white.opacity(0.15), .clear, .black.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .shadow(color: .black.opacity(0.32), radius: 3, x: 2, y: 4)
    }

    private func vinylTint(_ style: DiscStyle) -> Color {
        switch style {
        case .amber: Color(red: 0.85, green: 0.46, blue: 0.10)
        case .rose: Color(red: 0.80, green: 0.34, blue: 0.43)
        case .jade: Color(red: 0.22, green: 0.60, blue: 0.43)
        case .black: Color(white: 0.075)
        default: Color(white: 0.76)
        }
    }

    @ViewBuilder
    private func compactDisc(_ album: RecordAlbum, color: DiscStyle) -> some View {
        if color == .glass || color == .mixed {
            GlassRecordView(album: album)
        } else {
            legacyDisc(album, color: color)
        }
    }

    private func legacyDisc(_ album: RecordAlbum, color: DiscStyle) -> some View {
        let silver = color == .silver
        let black = color == .black
        let tint = vinylTint(color)
        return ZStack {
            if silver {
                Circle()
                    .fill(AngularGradient(stops: [
                        .init(color: Color(white: 0.46), location: 0),
                        .init(color: Color(white: 0.91), location: 0.10),
                        .init(color: Color(white: 0.99), location: 0.17),
                        .init(color: Color(white: 0.56), location: 0.30),
                        .init(color: Color(white: 0.80), location: 0.42),
                        .init(color: Color(white: 0.97), location: 0.54),
                        .init(color: Color(white: 0.45), location: 0.69),
                        .init(color: Color(white: 0.89), location: 0.82),
                        .init(color: Color(white: 0.62), location: 1)
                    ], center: .center, startAngle: .degrees(-35), endAngle: .degrees(325)))
            } else {
                Circle().fill(tint.opacity(black ? 1 : 0.73))
                Circle().fill(AngularGradient(colors: [
                    .black.opacity(0.18), .white.opacity(black ? 0.13 : 0.35),
                    .clear, .black.opacity(0.25), .white.opacity(0.20), .clear, .black.opacity(0.18)
                ], center: .center, startAngle: .degrees(-35), endAngle: .degrees(325)))
                Circle()
                    .fill(RadialGradient(colors: [.clear, tint.opacity(0.12), tint.opacity(0.65)], center: .center, startRadius: 22, endRadius: 42))
            }
            ForEach(0..<(silver ? 9 : 21), id: \.self) { index in
                Circle()
                    .stroke(index.isMultiple(of: 2) ? .white.opacity(silver ? 0.15 : 0.11) : .black.opacity(0.17), lineWidth: 0.35)
                    .padding(CGFloat(3) + CGFloat(index) * (silver ? 1.6 : 0.86))
            }
            artwork(album)
                .frame(width: silver ? 43 : 32, height: silver ? 43 : 32)
                .clipShape(Circle())
                .overlay(Circle().stroke(.black.opacity(0.38), lineWidth: 1))
            Circle()
                .fill(black ? Color(white: 0.54) : Color(white: 0.82))
                .frame(width: silver ? 8 : 4, height: silver ? 8 : 4)
                .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 0.8))
            Circle()
                .stroke(.white.opacity(silver ? 0.75 : 0.28), lineWidth: 1)
        }
        .frame(width: 84, height: 84)
        .shadow(color: .black.opacity(0.30), radius: 3, x: 2, y: 4)
    }

    private func artwork(_ album: RecordAlbum) -> some View {
        AsyncImage(url: album.artwork) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Color(red: 0.34, green: 0.37, blue: 0.36)
                    VStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.system(size: 17, weight: .ultraLight))
                        Text(album.title)
                            .font(.system(size: 7, weight: .medium))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }
                    .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
    }

    @ViewBuilder private var rackLedge: some View {
        if model.rackSkin == .silver { metalLedge }
        else { AlternateRackLedge(skin: model.rackSkin) }
    }

    private var metalLedge: some View {
        ZStack(alignment: .bottom) {
            // Shallow horizontal shelf, frontal lip, and raised retaining rod.
            Rectangle()
                .fill(LinearGradient(colors: [Color(white: 0.93), Color(white: 0.55), Color(white: 0.88)], startPoint: .top, endPoint: .bottom))
                .frame(height: 13)
                .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.95)).frame(height: 1) }
                .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.25)).frame(height: 1) }
            Rectangle()
                .fill(LinearGradient(colors: [.white, Color(white: 0.63), Color(white: 0.89), Color(white: 0.42)], startPoint: .top, endPoint: .bottom))
                .frame(height: 3)
                .offset(y: -16)
                .shadow(color: .black.opacity(0.32), radius: 1, y: 2)
            HStack {
                bracket
                Spacer()
                bracket
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 27)
    }

    private var bracket: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 1)
                .fill(LinearGradient(colors: [Color(white: 0.48), .white, Color(white: 0.60)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 5, height: 26)
                .shadow(color: .black.opacity(0.25), radius: 1, x: 1, y: 1)
            Circle()
                .fill(Color(white: 0.49))
                .overlay(Circle().stroke(.white.opacity(0.75), lineWidth: 0.7))
                .frame(width: 3, height: 3)
                .padding(.top, 2)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 11) {
            Text(model.loading ? "正在整理你的唱片…" : "把喜欢的音乐，摆上来。")
                .font(.system(size: 13, weight: .medium))
            Text(model.loading ? "专辑封面正在送达唱片架" : "连接网易云，展示你的收藏专辑")
                .font(.system(size: 10))
                .foregroundStyle(ink.opacity(0.65))
            if model.loading {
                ProgressView().controlSize(.small)
            } else {
                Button("连接网易云") { model.showConnection() }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ink.opacity(0.9), in: Capsule())
                    .foregroundStyle(darkRack ? Color(white: 0.15) : .white)
            }
        }
        .foregroundStyle(ink)
        .padding(23)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.75), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 12, y: 5)
        .padding(.bottom, 15)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button { model.refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .frame(width: 24, height: 26)
            }
            .buttonStyle(.plain)
            .disabled(model.loading)
            .help("刷新收藏专辑")
            Text(model.footerText)
                .help(model.status)
                .font(.system(size: 9))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { model.page = max(0, model.page - 1) } label: {
                Image(systemName: "chevron.left").frame(width: 16, height: 26)
            }
            .disabled(model.page == 0)
            Text("\(model.page + 1) / \(max(1, model.pageCount))")
                .font(.system(size: 9, design: .monospaced))
                .monospacedDigit()
            Button { model.page = min(model.pageCount - 1, model.page + 1) } label: {
                Image(systemName: "chevron.right").frame(width: 16, height: 26)
            }
            .disabled(model.page + 1 >= model.pageCount)
        }
        .buttonStyle(.plain)
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(ink.opacity(0.70))
        .padding(.horizontal, 21)
    }

}
