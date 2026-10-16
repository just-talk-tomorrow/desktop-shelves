import AppKit
import SwiftUI

/// Coordinates measured from the generated 1536 × 1024 skin. Only compositing
/// and live content use code; the enclosure, material and controls are bitmap art.
enum GeneratedRackMetrics {
    static let crop=CGRect(x:62,y:12,width:1412,height:990)
    static let aspect:CGFloat=crop.width/crop.height
    static let width:CGFloat=344
    static let scale:CGFloat=width/crop.width
    static let height:CGFloat=width/aspect
    static func slot(_ index:Int)->CGRect {
        CGRect(x:44+CGFloat(index%4)*336,y:49+CGFloat(index/4)*450,width:318,height:428)
            .applying(CGAffineTransform(scaleX:scale,y:scale))
    }
    static func controlFrame(_ index:Int,width:CGFloat,theme:RackTheme = .rams)->CGRect {
        let side=max(22,width/490.63*32)
        let centers:[CGFloat]=theme == .naturalWood ? [1016,1110,1203,1296]:[1035,1134,1233,1332]
        let center=centers[index]*width/crop.width
        return CGRect(x:center-side/2,y:23*width/crop.width-side/2,width:side,height:side)
    }
    static func controlIndex(at point:CGPoint,width:CGFloat,theme:RackTheme)->Int? {
        (0..<4).first{controlFrame($0,width:width,theme:theme).contains(point)}
    }
    static func pages(current:Int,total:Int)->[Int] {
        let start=max(0,min(current-1,total-4))
        return Array(start..<min(total,start+4))
    }
}

struct GeneratedSkinImage:View {
    let theme:RackTheme
    var body:some View {
        GeometryReader { geo in
            if let image=theme.skinImage {
                let scale=geo.size.width/GeneratedRackMetrics.crop.width
                Image(nsImage:image).resizable()
                    .frame(width:1536*scale,height:1024*scale)
                    .offset(x:-62*scale,y:-12*scale)
            }
        }.clipped().clipShape(RoundedRectangle(cornerRadius:7))
            .allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct GeneratedRackView:View {
    @ObservedObject var store:MagazineStore
    let theme:RackTheme
    let width:CGFloat
    @Binding var themeValue:String
    let alignToGrid:()->Void
    let importImages:()->Void
    let showPreview:(MagazineItem)->Void
    let export:(MagazineItem)->Void
    private var layoutScale:CGFloat {width/GeneratedRackMetrics.width}
    private var height:CGFloat {width/GeneratedRackMetrics.aspect}
    var body:some View {
        ZStack(alignment:.topLeading){
            GeneratedSkinImage(theme:theme)
            RackDragSurface().frame(width:max(0,GeneratedRackMetrics.controlFrame(0,width:width,theme:theme).minX-8*layoutScale-4),height:13*layoutScale).offset(x:8*layoutScale,y:0)
            ForEach(0..<8,id:\.self){index in
                let slot=GeneratedRackMetrics.slot(index).applying(CGAffineTransform(scaleX:layoutScale,y:layoutScale))
                if index<store.visibleItems.count {
                    let item=store.visibleItems[index]
                    if let image=PhotoImageCache.image(at:store.imageURL(item)) {
                        Button{showPreview(item)}label:{MagazineMockup(image:image,template:item.template,seed:item.seed).frame(width:slot.width,height:slot.height)}
                            .buttonStyle(.plain).help(item.originalName).accessibilityLabel("查看封面：\(item.originalName)")
                            .contextMenu {
                                Button("随机换一个模板"){store.reroll(item)}
                                Button("导出封面…"){export(item)}
                                Button("移除这本杂志"){store.remove(item)}
                            }
                            .frame(width:slot.width,height:slot.height).offset(x:slot.minX,y:slot.minY)
                    }
                } else {
                    Button(action:importImages){Color.clear.contentShape(Rectangle())}
                        .buttonStyle(.plain).accessibilityLabel("添加图片")
                        .frame(width:slot.width,height:slot.height).offset(x:slot.minX,y:slot.minY)
                }
            }
            // Reuse the very same generated rail pixels above live covers, so
            // the books sit behind the retaining lips rather than floating on them.
            GeneratedSkinImage(theme:theme).mask {
                Path { path in
                    for y:CGFloat in [475,924] {
                        path.addRect(CGRect(x:0,y:y*GeneratedRackMetrics.scale*layoutScale,width:width,height:23*GeneratedRackMetrics.scale*layoutScale))
                    }
                }.fill(.white)
            }.allowsHitTesting(false)
            ForEach(0..<4,id:\.self){index in
                let hit=GeneratedRackMetrics.controlFrame(index,width:width,theme:theme)
                RackNativeControl(label:controlLabels[index]){sender in activateControl(index,sender:sender)}
                    .frame(width:hit.width,height:hit.height)
                    .position(x:hit.midX,y:hit.midY)
            }
            ForEach(Array(GeneratedRackMetrics.pages(current:store.page,total:store.pages).enumerated()),id:\.offset){offset,page in
                Button{store.page=page}label:{
                    Circle().fill(page == store.page ? (theme == .rams ? Color(red:0.94,green:0.30,blue:0.08):Color(white:0.22)):Color(white:0.42).opacity(0.55))
                        .frame(width:page == store.page ? 4:3,height:page == store.page ? 4:3)
                        .shadow(color:.white.opacity(0.45),radius:0.1,y:0.4)
                        .frame(width:32,height:32).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(page<store.pages ? "第 \(page+1) 页，共 \(store.pages) 页":"空分页")
                    .help("第 \(page+1) 页，共 \(store.pages) 页")
                    .position(x:width/2+(CGFloat(offset)-CGFloat(GeneratedRackMetrics.pages(current:store.page,total:store.pages).count-1)/2)*32,y:height-5.5*layoutScale)
            }
            RackDragSurface().frame(width:7,height:height-16).offset(x:0,y:8)
            RackDragSurface().frame(width:7,height:height-16).offset(x:width-7,y:8)
        }.frame(width:width,height:height).buttonStyle(.plain)
            .shadow(color:.black.opacity(0.25),radius:2,x:0,y:2)
            .shadow(color:.black.opacity(0.24),radius:10,x:0,y:9)
    }
    private let controlLabels=["切换架子主题","选择封面风格","导入图片","随机换版"]
    private func activateControl(_ index:Int,sender:NSView){
        if index == 2 {importImages();return}
        if index == 3 {store.shuffleTemplates();return}
        let menu=NSMenu()
        if index == 0 {
            for choice in RackTheme.allCases {
                menu.addItem(RackMenuItem(choice.title,selected:choice == theme){themeValue=choice.rawValue})
            }
            menu.addItem(.separator())
            menu.addItem(RackMenuItem("对齐两排系统组件",action:alignToGrid))
        } else {
            for style in CoverStyle.mainChoices {
                menu.addItem(RackMenuItem(style.title,selected:style == store.style){store.setStyle(style)})
            }
            let effects=NSMenu(),parent=NSMenuItem(title:"指定印刷效果",action:nil,keyEquivalent:"")
            for style in CoverStyle.effectChoices {
                effects.addItem(RackMenuItem(style.title,selected:style == store.style){store.setStyle(style)})
            }
            parent.submenu=effects;menu.addItem(.separator());menu.addItem(parent)
        }
        menu.popUp(positioning:nil,at:NSPoint(x:0,y:sender.bounds.minY-2),in:sender)
    }
}
