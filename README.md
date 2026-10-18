# Desktop Shelves · 桌面唱片架、杂志架与刘海暂存柜

三款 macOS 原生桌面常驻应用：展示网易云音乐专辑的唱片架、把自己的图片制作成杂志封面的杂志架，以及融合 Codex Pacer 状态栏信息的刘海暂存柜。

## 下载安装

[下载唱片架与杂志架 ZIP](https://github.com/just-talk-tomorrow/desktop-shelves/releases/download/v2026.10.16/Desktop-Shelves-macOS-AppleSilicon-20261016.zip) · [下载刘海暂存柜 DMG](https://github.com/just-talk-tomorrow/desktop-shelves/releases/download/v2026.10.16/Codex-Pacer-Shelf-AppleSilicon-20261015-v2.dmg) · [发行说明与校验和](https://github.com/just-talk-tomorrow/desktop-shelves/releases/tag/v2026.10.16)

唱片架和杂志架在 ZIP 中；刘海暂存柜单独提供 DMG。将应用拖入“应用程序”后打开即可。

- **系统**：macOS 14 或更新版本，Apple Silicon（M 系列芯片）Mac。
- **签名**：个人临时签名，未经过 Apple 公证。若系统阻止启动，请核对来源后使用系统提供的允许打开流程。
- **首次使用**：自行连接网易云或导入图片。安装包不含制作者的账号、收藏或私人照片。
- **形态**：独立桌面应用，并非 WidgetKit 系统小组件；菜单栏有显示、隐藏及退出入口。

## 刘海暂存柜

- 基于 MIT 许可的 [Codex Pacer](https://github.com/RyanZhangNTU/codex-pacer) 3.1.1 定制，保留任务、输出速度及额度状态，并加入本地暂存抽屉。
- 支持文件、文件夹、文字、链接和图片；每页最多八项，可从访达直接拖入、拖出。
- 可框选截图后自动收入暂存柜，也可监听系统截图目录及晾衣架目录中新生成的截图。
- 使用独立应用身份和本地数据目录，可与官方 Codex Pacer 同时安装；定制版关闭官方自动更新。
- 发行 DMG 适用于 Apple Silicon、macOS 14+，采用本地临时签名且未经过 Apple 公证。

## 金属唱片架

- 手机网易云音乐扫码，读取收藏专辑及喜欢歌曲所属专辑，按专辑去重。
- 每页最多九张，可切换架型、彩胶、封面晕染玻璃效果和随机摆放。
- 点击封面唤起本机网易云音乐客户端；需自行安装客户端，不内置音源或下载服务。
- 收藏读取依赖第三方开源接口，服务变化可能影响连接。

## 杂志架

- 导入或拖入自己的图片，自动套用日式、美式、构成主义、留白、印刷与拼贴等封面模板。
- 两排四本，每页最多八张。底部圆点切换真实图片页；八张图片只有一页。
- 自然木框与 Rams 风格皮肤采用生成位图架体，书本、分页和操作为实时内容。
- 顶部图标从左至右：架体主题、封面风格、导入、随机。
- 点击书本预览，右键可导出封面或移除。主题菜单可对齐两排系统组件。

## 源码与构建

```text
apps/metal-record-shelf/   唱片架 Swift 应用与 Node 请求桥
apps/magazine-rack/        杂志架 Swift 应用及生成素材
apps/pacer-shelf/           Codex Pacer 刘海暂存柜定制版
```

使用 Xcode 命令行工具与 Swift。唱片架额外需要 Node.js（当前发行包使用 arm64 Node 24）。

```bash
cd apps/metal-record-shelf/Backend
npm ci
cd ../../..
bash apps/metal-record-shelf/scripts/build.sh
bash apps/magazine-rack/scripts/build.sh
bash apps/pacer-shelf/scripts/local/build-shelf.sh
```

产物位于各应用的 `output/`。唱片架构建时会打包本机 Node 运行时和依赖，所以朋友安装发行包无需另外安装 Node。

运行测试时将 Clang 缓存指向可写目录；渲染测试还需将 `MAGAZINE_RESOURCE_ROOT` 设置为杂志架的 `Resources` 绝对路径。

## 数据与第三方组件

图片和收藏保存在使用者自己的 Mac 用户目录；登录凭据由其系统钥匙串管理，不随应用包分发。杂志封面处理在本地执行。

唱片架依赖及版本见 `Backend/package.json` 与锁文件；第三方说明见 `Resources/THIRD_PARTY.txt`。Node 许可随源码和发行包保留。生成的视觉素材随杂志架 `Resources/EditorialAssets` 提供。

唱片架和杂志架源码及素材未另行指定开源许可。刘海暂存柜继承并保留 Codex Pacer 的 MIT 许可证及第三方许可；各第三方组件遵循各自许可。
