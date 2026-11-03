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

    private let sections = ["渲染设置", "游戏设置", "控制设置", "手柄设置", "启动器设置", "其它"]
    private let icons = ["paintbrush.pointed.fill", "gamecontroller.fill", "dpad.fill", "gamepad.fill", "shippingbox.fill", "ellipsis.circle"]

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
                        case 4: launcherSettings
                        default: otherSettings
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

    @AppStorage("jvmArgs") private var jvmArgs = ""
    @AppStorage("showLogAuto") private var showLogAuto = true

    @ViewBuilder
    private var gameSettings: some View {
        // JVM 参数（真机：输入框 + 内存提示）
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("JVM 参数").font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                TextField("-Dfile.encoding=UTF-8", text: $jvmArgs)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.horizontal, 10).frame(height: 38)
                    .background(ZLTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                HStack {
                    Text("留白则忽略此设置")
                        .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                    Spacer()
                    Text("\(memoryMB)MB")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ZLTheme.primaryDeep)
                }
            }
        }

        // 日志字号 + 刷新间隔（真机）
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("日志字号大小").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("调整日志界面上文字的显示大小").font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                HStack {
                    Slider(value: $logFontSize, in: 10...24, step: 1).tint(ZLTheme.primary)
                    Text("\(Int(logFontSize))sp").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ZLTheme.primaryDeep).frame(width: 48)
                }
            }
        }
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("日志刷新间隔").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("设置日志刷新时间间隔，过低会加重负担").font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                HStack {
                    Slider(value: $logFlushMs, in: 50...1000, step: 50).tint(ZLTheme.primary)
                    Text("\(Int(logFlushMs))ms").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ZLTheme.primaryDeep).frame(width: 58)
                }
            }
        }

        ZLCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("自动显示日志").font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text("游戏启动后自动显示运行日志").font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                Spacer()
                Toggle("", isOn: $showLogAuto).labelsHidden().tint(ZLTheme.primary)
            }
        }

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
    @AppStorage("logFontSize") private var logFontSize = 16.0
    @AppStorage("logFlushMs") private var logFlushMs = 200.0
    @AppStorage("mouseSensitivity") private var mouseSensitivity = 156.0
    @AppStorage("gyroInterval") private var gyroInterval = 16.0
    @AppStorage("gyroSmooth") private var gyroSmooth = true
    @AppStorage("animMode") private var animMode = 1
    @AppStorage("animLow") private var animLow = 6.0
    @AppStorage("animHeight") private var animHeight = 6.0
    @AppStorage("longPressDelay") private var longPressDelay = 256.0
    @AppStorage("physicalMouse") private var physicalMouse = false
    @AppStorage("matrixMouse") private var matrixMouse = false

    @ViewBuilder
    private var controlSettings: some View {
        // 长按触发的延迟（真机：滑块 256ms）
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("手感长按触发的延迟").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("按下后需要按住多久才判定为长按").font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                HStack {
                    Slider(value: $longPressDelay, in: 100...600, step: 16)
                        .tint(ZLTheme.primary)
                    Text("\(Int(longPressDelay))ms")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ZLTheme.primaryDeep).frame(width: 56)
                }
            }
        }

        settingCard(title: "长按触发的操作类型", desc: "设置长按控件时触发的动作", current: "长按持续触发")

        ZLCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("实物鼠标控制").font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text("连接实体鼠标时禁用虚拟指针，直接用系统鼠标").font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                Spacer()
                Toggle("", isOn: $physicalMouse).labelsHidden().tint(ZLTheme.primary)
            }
        }

        ZLCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("矩阵鼠标控制").font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text("在虚拟按键上滑动时，让指针持续移动").font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                Spacer()
                Toggle("", isOn: $matrixMouse).labelsHidden().tint(ZLTheme.primary)
            }
        }

        // 抓取鼠标滑动灵敏度（真机 156%）
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("抓取鼠标滑动灵敏度").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("调节鼠标指针移动的灵敏度").font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                HStack {
                    Slider(value: $mouseSensitivity, in: 50...300, step: 1).tint(ZLTheme.primary)
                    Text("\(Int(mouseSensitivity))%").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ZLTheme.primaryDeep).frame(width: 52)
                }
            }
        }

        // 陀螺仪（真机：采样率 / 平滑 / 窗口）
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("陀螺仪采样率").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("使用手机陀螺仪控制视角的采样间隔").font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                HStack {
                    Slider(value: $gyroInterval, in: 4...50, step: 1).tint(ZLTheme.primary)
                    Text("\(Int(gyroInterval))ms").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ZLTheme.primaryDeep).frame(width: 52)
                }
            }
        }
        ZLCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("陀螺仪数据平滑").font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text("降低抖动，让视角更稳").font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                Spacer()
                Toggle("", isOn: $gyroSmooth).labelsHidden().tint(ZLTheme.primary)
            }
        }

        settingCard(title: "控制布局", desc: "编辑屏幕按键的位置、大小与触发事件", current: "默认布局", trailing: actionButtons())
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

    // MARK: 其它（Java 管理 + 关于）
    @ViewBuilder
    private var otherSettings: some View {
        NavigationLink(value: AppRoute.javaManage) {
            HStack(spacing: 12) {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundStyle(ZLTheme.primary)
                    .frame(width: 36, height: 36)
                    .background(ZLTheme.primarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Java 管理").font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text("管理已安装的 Java 运行时").font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
            }
            .padding(14)
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)

        NavigationLink(value: AppRoute.about) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(ZLTheme.primary)
                    .frame(width: 36, height: 36)
                    .background(ZLTheme.primarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("关于").font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text("致谢与开源许可").font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
            }
            .padding(14)
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var launcherSettings: some View {
        themeCard
        // 动画速度（真机：空白/从未加载/从网络加载）
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("动画速度").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Picker("", selection: $animMode) {
                    Text("空白").tag(0)
                    Text("从未加载").tag(1)
                    Text("从网络加载").tag(2)
                }
                .pickerStyle(.segmented)
            }
        }
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("动画低速 / 动画高度").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                HStack {
                    Text("低速").font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                    Slider(value: $animLow, in: 1...12, step: 1).tint(ZLTheme.primary)
                    Text("\(Int(animLow))s").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ZLTheme.primaryDeep).frame(width: 34)
                }
                HStack {
                    Text("高度").font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                    Slider(value: $animHeight, in: 1...12, step: 1).tint(ZLTheme.primary)
                    Text("\(Int(animHeight))s").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ZLTheme.primaryDeep).frame(width: 34)
                }
            }
        }

        settingCard(title: "下载源", desc: "国内网络下官方源可能很慢，下载失败时可切镜像", current: "优先使用官方源", trailing: actionButtons())
        settingCard(title: "启动器语言", desc: nil, current: "简体中文", trailing: actionButtons())
        settingCard(title: "关于", desc: nl2(), current: nil)
    }

    // MARK: 颜色主题（8 套，来自 ZL2）
    @EnvironmentObject private var themeManager: ThemeManager

    private var themeCard: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("颜色主题").font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(ZLTheme.textPrimary)
                        Text("跟随 ZL2 的 7 套配色，切换后全局生效")
                            .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                    }
                    Spacer()
                    Toggle("深色", isOn: Binding(
                        get: { themeManager.darkMode },
                        set: { themeManager.darkMode = $0 }
                    ))
                    .labelsHidden()
                    .tint(ZLTheme.primary)
                }

                HStack(spacing: 14) {
                    ForEach(ZLColorTheme.allCases) { t in
                        Button {
                            themeManager.themeName = t.rawValue
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(t.primary)
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Circle().stroke(themeManager.theme == t ? ZLTheme.textPrimary : .clear, lineWidth: 2)
                                    )
                                Text(t.displayName).font(.system(size: 10))
                                    .foregroundStyle(themeManager.theme == t ? ZLTheme.textPrimary : ZLTheme.textSecond)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
        }
    }

    private func nl2() -> String {
        CoreBridge.isCoreLinked ? "启动核心：Amethyst 已链接" : "启动核心：未接入（仅界面）"
    }
}
