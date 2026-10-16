import AppKit
import SwiftUI

/// Photo-only printed objects: no masthead, captions, symbols or stickers.
struct PrintEffectCover: View {
    let image: NSImage
    let template: Int
    let seed: Int

    var body: some View {
        Image(nsImage: PrintImageProcessor.render(image: image, template: template, seed: seed))
            .resizable().scaledToFill().clipped()
            .accessibilityLabel("无字纸张影像 · 效果 \((template % 80 + 80) % 80 + 1)")
    }
}
