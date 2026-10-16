import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct RackView:View {
    @ObservedObject var store:MagazineStore
    let importImages:()->Void
    let showPreview:(MagazineItem)->Void
    let export:(MagazineItem)->Void
    let alignToGrid:()->Void
    let themeChanged:()->Void
    @State private var targeted=false
    @AppStorage("rackTheme") private var themeValue = RackTheme.oak.rawValue
    private var theme:RackTheme { RackTheme(rawValue:themeValue) ?? .oak }
    var body:some View {
        GeometryReader { geo in
            let w=geo.size.width-88
            let scale=w/344
            Group {
                if theme.isGenerated {
                    GeneratedRackView(store:store,theme:theme,width:w,themeValue:$themeValue,alignToGrid:alignToGrid,importImages:importImages,showPreview:showPreview,export:export)
                } else {
                    rack.frame(width:344,height:344).scaleEffect(scale,anchor:.topLeading).frame(width:w,height:w,alignment:.topLeading)
                }
            }.padding(44)
        }
        .onChange(of:themeValue){_,_ in themeChanged()}
        .onDrop(of:[UTType.fileURL.identifier],isTargeted:$targeted) { providers in
            Task { @MainActor in
                var urls:[URL]=[]
                for provider in providers {
                    if let url=await loadURL(provider){urls.append(url)}
                }
                store.importURLs(urls)
            }
            return !providers.isEmpty
        }
    }
    @ViewBuilder private func controlLabel(symbol:String)->some View {
        if theme.isGenerated {
            Image(nsImage:NSImage(size:CGSize(width:12,height:12))).renderingMode(.original)
                .frame(width:14,height:16).contentShape(Rectangle())
        } else {EngravedControl(symbol:symbol,ink:theme.ink)}
    }
    private var themeControl:some View {
                Menu {
                    ForEach(RackTheme.allCases,id:\.self) { choice in
                        Button((theme == choice ? "✓ " : "")+choice.title){themeValue=choice.rawValue}
                    }
                    Divider()
                    Button("随机架子主题") { themeValue=RackTheme.allCases.filter{$0 != theme}.randomElement()!.rawValue }
                    Button("对齐系统组件",action:alignToGrid)
                } label:{controlLabel(symbol:"square.grid.2x2")}
                .menuStyle(.borderlessButton).menuIndicator(.hidden).environment(\.colorScheme, theme == .walnut || theme == .steel ? .dark : .light).fixedSize().help("切换架子主题：\(theme.title)").accessibilityLabel("切换架子主题")

    }
    private var styleControl:some View {
                Menu {
                    ForEach(CoverStyle.mainChoices,id:\.self) { style in
                        Button((store.style == style ? "✓ " : "")+style.title){store.setStyle(style)}
                    }
                    Divider()
                    Menu("指定印刷效果") {
                        ForEach(CoverStyle.effectChoices,id:\.self) { style in
                            Button((store.style == style ? "✓ " : "")+style.title){store.setStyle(style)}
                        }
                    }
                } label:{controlLabel(symbol:"slider.horizontal.3")}
                .menuStyle(.borderlessButton).menuIndicator(.hidden).environment(\.colorScheme, theme == .walnut || theme == .steel ? .dark : .light).fixedSize().help("选择封面风格").accessibilityLabel("选择封面风格")

    }
    private var importControl:some View {
                Button(action:importImages){controlLabel(symbol:"plus")}.help("导入图片 · 自动套版").accessibilityLabel("导入图片")

    }
    private var randomControl:some View {
                Button{store.shuffleTemplates() }label:{controlLabel(symbol:"shuffle")}
                .disabled(store.items.isEmpty).help("随机更换封面模板").accessibilityLabel("随机换版")
    }
    private var rack:some View {
        VStack(spacing:0) {
            HStack(spacing:6) {
                RackDragSurface().frame(width:55,height:30).overlay(EngravedGrip(ink:theme.ink)).help("按住拖动杂志架")
                Spacer(minLength:4)
                themeControl
                styleControl
                importControl
                randomControl
            }.buttonStyle(.plain).font(.system(size:9.5,weight:.regular)).foregroundStyle(theme.ink.opacity(0.85)).padding(.horizontal,22).frame(height:30)
            VStack(spacing:0) {
                row(0)
                RackDragSurface().frame(height:22).help("按住空白处拖动")
                row(1)
            }.padding(.top,14).padding(.horizontal,13)
            Spacer(minLength:0)
            HStack(spacing:0){
                Spacer(minLength:0)
                ForEach(paginationSlots,id:\.self){index in
                    Button { store.page=index } label:{
                        Circle().fill(theme.ink.opacity(index == store.page ? 0.83 : 0.32))
                            .frame(width:index == store.page ? 4.5:3.5,height:index == store.page ? 4.5:3.5)
                            .shadow(color:.white.opacity(0.48),radius:0.2,x:0,y:0.6)
                            .frame(width:13,height:26).contentShape(Rectangle())
                    }
                    .accessibilityLabel(index<store.pages ? "第 \(index+1) 页，共 \(store.pages) 页" : "空分页")
                    .help(index<store.pages ? "第 \(index+1) 页" : "")
                }
                Spacer(minLength:0)
            }.buttonStyle(.plain).frame(height:30).help(store.message)

        }
        .background {RackMaterialBackground(theme:theme)}
        .overlay(alignment:.leading){RackDragSurface().frame(width:12).padding(.vertical,12)}
        .overlay(alignment:.trailing){RackDragSurface().frame(width:12).padding(.vertical,12)}
        
        
        .clipShape(RoundedRectangle(cornerRadius:theme.corner))
        .overlay(RoundedRectangle(cornerRadius:theme.corner).strokeBorder(targeted ? Color.orange : Color.white.opacity(0.3),lineWidth:targeted ? 3:0.8).allowsHitTesting(false))
        .shadow(color:.black.opacity(0.34),radius:3,x:0,y:3)
        .shadow(color:.black.opacity(0.28),radius:13,x:0,y:12)
        .shadow(color:.black.opacity(0.15),radius:22,x:0,y:17)
    }
    // Four recessed dots remain visible even for a single page, as on the reference rack.
    // Large collections use a sliding four-page window, so every real page stays reachable.
    private var paginationSlots:[Int] {
        GeneratedRackMetrics.pages(current:store.page,total:store.pages)
    }
    private func row(_ row:Int)->some View {
        VStack(spacing:0){
            HStack(alignment:.bottom,spacing:7) {
                ForEach(0..<4,id:\.self){column in
                    let index=row*4+column
                    if index<store.visibleItems.count {
                        let item=store.visibleItems[index]
                        if let image=PhotoImageCache.image(at:store.imageURL(item)) {
                            Button{showPreview(item)}label:{MagazineMockup(image:image,template:item.template,seed:item.seed).frame(width:74,height:107).offset(y:2.5)}.buttonStyle(.plain).help(item.originalName).accessibilityLabel("查看封面：\(item.originalName)")
                            .contextMenu {
                                Button("随机换一个模板"){store.reroll(item)}
                                Button("导出封面…"){export(item)}
                                Button("移除这本杂志"){store.remove(item)}
                            }
                        }
                    } else {
                        Button(action:importImages){Image(systemName:"plus").font(.system(size:17,weight:.light)).foregroundStyle(theme.ink.opacity(0.65)).frame(width:74,height:107).background(Color.white.opacity(0.16)).overlay(Rectangle().strokeBorder(Color.black.opacity(0.08),style:StrokeStyle(lineWidth:1,dash:[3,4])))}.buttonStyle(.plain).accessibilityLabel("添加图片")
                    }
                }
            }
            RackShelfLedge(theme:theme).frame(height:6)

        }
    }
    private func loadURL(_ provider:NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier:UTType.fileURL.identifier,options:nil){item,_ in
                let url:URL?
                if let u=item as? URL {url=u} else if let d=item as? Data {url=URL(dataRepresentation:d,relativeTo:nil)} else {url=nil}
                continuation.resume(returning:url)
            }
        }
    }
}
