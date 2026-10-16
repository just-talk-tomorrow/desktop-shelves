import AppKit
import SwiftUI

/// Original paper and illustration assets bundled with the offline application.
enum EditorialAssetLibrary {
    static var root:URL? {
        if let override=ProcessInfo.processInfo.environment["MAGAZINE_RESOURCE_ROOT"] {return URL(fileURLWithPath:override)}
        return Bundle.main.resourceURL
    }
}
struct MagazineCover:View {
    let image:NSImage
    let template:Int
    let seed:Int
    @ViewBuilder var body:some View {
        let normalized=((template % 240)+240)%240
        switch normalized {
        case 40..<80: AmericanCover(image:image,template:normalized-40,seed:seed)
        case 80..<120: ConstructivistCover(image:image,template:normalized-80,seed:seed)
        case 120..<200: PrintEffectCover(image:image,template:normalized-120,seed:seed)
        case 200..<240: MinimalEditorialCover(image:image,template:normalized-200,seed:seed)
        default: JapaneseCover(image:image,template:normalized,seed:seed)
        }
    }
}

/// Reuse source identity so effect renders remain cached during UI redraws.
enum PhotoImageCache {
    private static let cache:NSCache<NSURL,NSImage> = {
        let cache=NSCache<NSURL,NSImage>();cache.countLimit=24;return cache
    }()
    static func image(at url:URL)->NSImage? {
        if let image=cache.object(forKey:url as NSURL){return image}
        guard let image=NSImage(contentsOf:url) else{return nil}
        cache.setObject(image,forKey:url as NSURL);return image
    }
}
