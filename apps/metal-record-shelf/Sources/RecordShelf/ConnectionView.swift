import AppKit
import SwiftUI

struct ConnectionView: View {
    @ObservedObject var model: ShelfModel
    @State private var albumLink = ""
    @State private var selected: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "opticaldisc").font(.system(size: 28, weight: .ultraLight))
                VStack(alignment: .leading, spacing: 3) {
                    Text("金属唱片架").font(.system(size: 20, weight: .semibold))
                    Text("喜欢的专辑，留在桌面上。").foregroundStyle(.secondary)
                }
                Spacer()
                if model.connected {
                    Button("断开网易云") { model.logout() }
                }
            }
            HStack(alignment: .center, spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(.white)
                    if let qr = model.qrImage {
                        Image(nsImage: qr).interpolation(.none).resizable().scaledToFit().padding(12)
                    } else if model.connected {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 56, weight: .light)).foregroundStyle(.green)
                    } else if model.loginBusy { ProgressView() }
                    else {
                        Image(systemName: "qrcode").font(.system(size: 64, weight: .ultraLight)).foregroundStyle(.gray)
                    }
                }.frame(width: 190, height: 190)
                VStack(alignment: .leading, spacing: 12) {
                    Label(model.connected ? "已连接网易云" : "扫码连接网易云", systemImage: model.connected ? "checkmark.seal" : "iphone")
                        .font(.system(size: 14, weight: .medium))
                    Text(model.qrStatus).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if model.connected {
                        Button("同步收藏和喜欢的音乐") { model.refresh() }.disabled(model.loading)
                    } else { Button(model.qrImage == nil ? "生成登录二维码" : "重新生成") { model.beginLogin() }.disabled(model.loginBusy && model.qrImage == nil) }
                    Text("读取收藏专辑和喜欢歌曲所属专辑，点封面唤起网易云音乐客户端。授权可在系统允许时保存到本机钥匙串；无法保存时仍可本次使用，无需输入电脑密码。").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            Text("添加一张专辑").font(.system(size: 13, weight: .medium))
            HStack {
                TextField("粘贴网易云专辑链接 / 数字专辑 ID", text: $albumLink)
                    .textFieldStyle(.roundedBorder).onSubmit { add() }
                Button("摆上架子") { add() }.disabled(model.loading || albumLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            HStack(alignment: .top, spacing: 8) {
                if model.loading { ProgressView().controlSize(.small) }
                Text(model.status).font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
            }.frame(minHeight: 24, alignment: .top)
            if !model.albums.isEmpty {
                HStack {
                    Picker("架上专辑", selection: $selected) {
                        Text("选择要移出的专辑").tag(String?.none)
                        ForEach(model.albums) { album in Text("\(album.title) · \(album.artist)").tag(Optional(album.id)) }
                    }
                    Button("移出架子") {
                        if let album = model.albums.first(where: { $0.id == selected }) { model.remove(album); selected = nil }
                    }.disabled(selected == nil || model.loading)
                }.font(.system(size: 11))
            }
            Spacer(minLength: 0)
            Text("架子在桌面层，普通窗口会盖住它。拖动金属背景可移动；菜单栏唱片图标可隐藏、锁定和退出。")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(24).frame(width: 570, height: 535)
        .onDisappear { model.cancelLogin() }
    }
    private func add() {
        let value = albumLink
        Task { if await model.add(value) { albumLink = "" } }
    }
}
