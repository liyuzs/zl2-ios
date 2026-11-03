// ZL2-iOS · 设置（依据真机截图还原）
// 真机布局：顶部栏 · 左侧竖排分类 · 右侧「标题+说明+当前项+操作」卡片
import SwiftUI

struct SettingsScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    var onDownload: () -> Void = {}

    @State private var section = 0
    @AppStorage("renderer")    private var renderer = "MobileGlues (OpenGL 4.0, 1.17+)"
    @AppStorage("vulkanDriver") private var vulkanDriver = "Turnip"
    @AppStorage("graphicsApi") private var graphicsApi = "仅首次启动时设置为 OpenGL"
    @AppStorage("resolution")  private var resolution = 50.0
    @AppStorage("memoryMB")    private var memoryMB = 2048

    private let sections = ["渲染设置", "游戏设置", "控制设置", "手柄设置", "Java 管理", "启动器设置"]
    private let icons = ["paintbrush.pointed.fill", "gamecontroller.fill", "dpad.fill", "gamecontroller", "cup.and.saucer.fill", "shippingbox.fill"]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "设置 - \(sections[section])",
                     active: .settings,
                     onBack: onBack, onHome: onHome, onDownload: onDownload)

            HStack(alignment: .top, spacing: 0) {
                sideRail
                ScrollView {
                    VStack(spacing: ZLTheme.cardGap) {
                        switch section {
                        case 0: renderSettings
                        case 1: gameSettings
                        case 2: controlSettings
                        case 3: gamepadSettings
                        case 4: javaSettings
                        default: launcherSettings
                        }
                    }
                    .padding(.trailing, ZLTheme.screenPadding)
                    .padding(.bottom, ZLTheme.screenPadding)
                }
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private var sideRail: some View {
        VStack(spacing: 6) {
            ForEach(sections.indices, id: \.self) { i in
                Button { section = i } label: {
                    VStack(spacing: 4) {
                        Image(systemName: icons[i]).font(.system(size: 19))
                        Text(sections[i]).font(.system(size: 11))
                    }
                    .foregroundStyle(section == i ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                    .frame(width: 76, height: 62)
                    .background(section == i ? ZLTheme.primarySoft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.leading, 8)
        .padding(.vertical, 8)
        .frame(width: 92)
    }

    // MARK: 卡片（真机样式：标题 + 灰说明 + 当前选择项 + 右侧操作）
    private func settingCard(title: String,
                             desc: String?,
                             current: String?,
                             trailing: AnyView? = nil) -> some View {
        ZLCard {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    if let desc {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundStyle(ZLTheme.textSecond)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let current {
                        Text("当前选择项：\(current)")
                            .font(.system(size: 12))
                            .foregroundStyle(ZLTheme.textSecond)
                    }
                }
                Spacer(minLength: 8)
                trailing
            }
        }
    }

    private func actionButtons() -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                Button { } label: {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 15))
                        .foregroundStyle(ZLTheme.textSecond)
                        .frame(width: 40, height: 40)
                        .background(ZLTheme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                Button { } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13))
                        .foregroundStyle(ZLTheme.textSecond)
                        .frame(width: 34, height: 40)
                        .background(ZLTheme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        )
    }

    @ViewBuilder
    private var renderSettings: some View {
        settingCard(title: "全局渲染器",
                    desc: "全局默认的渲染器，通过动态库转换层，确保游戏能在移动端运行",
                    current: renderer,
                    trailing: actionButtons())
        settingCard(title: "Vulkan 驱动器",
                    desc: nil,
                    current: vulkanDriver,
                    trailing: actionButtons())
        settingCard(title: "图形 API",
                    desc: "设置 Minecraft 26.2+ 将使用的图形 API",
                    current: graphicsApi,
                    trailing: actionButtons())
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("游戏窗口分辨率")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                HStack {
                    Slider(value: $resolution, in: 20...100, step: 10)
                        .tint(ZLTheme.primary)
                    Text("\(Int(resolution))%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ZLTheme.primaryDeep)
                        .frame(width: 52)
                }
                Text("分辨率越低，渲染压力越小、帧率越稳。")
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond)
            }
        }
    }

    @ViewBuilder
    private var gameSettings: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("内存分配")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                HStack {
                    Slider(value: Binding(
                        get: { Double(memoryMB) },
                        set: { memoryMB = Int($0) }
                    ), in: 1024...8192, step: 512)
                    .tint(ZLTheme.primary)
                    Text("\(memoryMB) MB")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ZLTheme.primaryDeep)
                        .frame(width: 78)
                }
                Text("并非越大越好，分配过高会让系统资源紧张，反而卡顿闪退。")
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond)
            }
        }
        settingCard(title: "自动选择 Java 环境", desc: "少数客户端需要特定版本时才需手动指定", current: "已开启")
        settingCard(title: "全局版本隔离", desc: "每个版本独立配置文件、模组、光影、存档，互不干扰", current: "已开启")
    }


    // MARK: 控制设置
    @ViewBuilder
    private var controlSettings: some View {
        settingCard(title: "控制布局", desc: "编辑屏幕按键的位置、大小与触发事件", current: "默认布局", trailing: actionButtons())
        settingCard(title: "按键透明度", desc: "控制布局在游戏内的可见度", current: "100%", trailing: actionButtons())
        settingCard(title: "滑动手势", desc: "启用两指滑动模拟鼠标滚轮", current: "已开启")
        settingCard(title: "输入法模式", desc: "游戏内文字输入方式", current: "直接输入", trailing: actionButtons())
    }

    // MARK: 手柄设置
    @ViewBuilder
    private var gamepadSettings: some View {
        settingCard(title: "手柄映射", desc: "为外接手柄配置按键映射", current: "未连接手柄", trailing: actionButtons())
        settingCard(title: "摇杆模式", desc: "左摇杆的控制方式", current: "移动", trailing: actionButtons())
        settingCard(title: "扳机灵敏度", desc: "LT/RT 扳机的触发阈值", current: "中等", trailing: actionButtons())
        settingCard(title: "震动反馈", desc: "手柄震动强度", current: "关闭")
    }

    // MARK: Java 管理
    @ViewBuilder
    private var javaSettings: some View {
        settingCard(title: "已安装的 Java", desc: "内置 JRE 17（java_runtimes/java-17-openjdk）", current: "17", trailing: actionButtons())
        settingCard(title: "自动选择 Java 环境", desc: "按游戏版本自动匹配所需 Java", current: "已开启")
        settingCard(title: "JVM 参数", desc: "额外的虚拟机启动参数，一般无需修改", current: "默认")
        settingCard(title: "内存分配", desc: nil, current: "\(memoryMB) MB", trailing: actionButtons())
    }

    @ViewBuilder
    private var launcherSettings: some View {
        settingCard(title: "下载源", desc: "国内网络下官方源可能很慢，下载失败时可切镜像", current: "优先使用官方源", trailing: actionButtons())
        settingCard(title: "启动器语言", desc: nil, current: "简体中文", trailing: actionButtons())
        settingCard(title: "关于", desc: nl2(), current: nil)
    }

    private func nl2() -> String {
        CoreBridge.isCoreLinked ? "启动核心：Amethyst 已链接" : "启动核心：未接入（仅界面）"
    }
}
