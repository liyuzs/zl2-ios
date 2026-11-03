// ZL2-iOS · 游戏内浮动菜单（双栏）
// 参考：ZL2 的 GameMenuSubscreen.kt（1163 行）
// 结构：左栏 5 个标签（概览/鼠标/手柄/手势/陀螺仪），右栏游戏动作
import SwiftUI

// MARK: - 菜单标签
enum ZLGameMenuTab: Int, CaseIterable, Identifiable {
    case overview = 0
    case mouse = 1
    case gamepad = 2
    case gesture = 3
    case gyroscope = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .overview: return "概览"
        case .mouse: return "虚拟鼠标"
        case .gamepad: return "手柄"
        case .gesture: return "手势"
        case .gyroscope: return "陀螺仪"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .mouse: return "computermouse.fill"
        case .gamepad: return "gamecontroller.fill"
        case .gesture: return "hand.tap.fill"
        case .gyroscope: return "gyroscope"
        }
    }
}

// MARK: - 游戏内菜单
struct GameMenuScreen: View {
    var versionName: String
    var onClose: () -> Void = {}
    var onForceClose: () -> Void = {}
    var onBackToGame: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onEditLayout: () -> Void = {}
    var onOpenLog: () -> Void = {}

    @State private var tab: ZLGameMenuTab = .overview
    @AppStorage("mouseCaptureSensitivity") private var mouseSensitivity = 156.0
    @AppStorage("mouseLongPressDelay") private var mouseLongDelay = 195.0
    @AppStorage("gyroInterval") private var gyroInterval = 16.0
    @AppStorage("gyroSmooth") private var gyroSmooth = true
    @AppStorage("gyroSensitivity") private var gyroSensitivity = 100.0
    @AppStorage("gamepadDeadZone") private var deadZone = 100.0
    @AppStorage("gestureEnabled") private var gestureEnabled = false
    @AppStorage("longPressDelay") private var longPressDelay = 256.0

    var body: some View {
        HStack(spacing: 0) {
            // 左栏：控制设置
            VStack(spacing: 0) {
                tabBar
                Divider().background(ZLTheme.cardStroke)
                ScrollView {
                    VStack(spacing: 12) {
                        switch tab {
                        case .overview: overviewTab
                        case .mouse: mouseTab
                        case .gamepad: gamepadTab
                        case .gesture: gestureTab
                        case .gyroscope: gyroTab
                        }
                    }
                    .padding(14)
                }
            }
            .frame(maxWidth: .infinity)
            .background(ZLTheme.background)

            Divider().background(ZLTheme.cardStroke)

            // 右栏：游戏动作
            VStack(spacing: 12) {
                Text(versionName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                    .lineLimit(1)
                    .padding(.top, 16)

                actionButton("返回游戏", "play.fill", ZLTheme.primary) { onBackToGame() }
                actionButton("编辑控制布局", "slider.horizontal.3", ZLTheme.primaryDeep) { onEditLayout() }
                actionButton("启动器设置", "gearshape.fill", ZLTheme.primaryDeep) { onOpenSettings() }
                actionButton("运行日志", "doc.text.fill", ZLTheme.primaryDeep) { onOpenLog() }

                Spacer()

                Button { onForceClose() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "power").font(.system(size: 13))
                        Text("强制结束").font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(ZLTheme.danger)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(ZLTheme.danger.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button { onClose() } label: {
                    Text("关闭菜单")
                        .font(.system(size: 12))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 14)
            .frame(width: 220)
            .background(ZLTheme.background)
        }
        .background(ZLTheme.background.ignoresSafeArea())
    }

    // 标签栏
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ZLGameMenuTab.allCases) { t in
                Button { tab = t } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.icon)
                            .font(.system(size: 15))
                            .foregroundStyle(tab == t ? ZLTheme.primary : ZLTheme.textSecond)
                        Text(t.title)
                            .font(.system(size: 9))
                            .foregroundStyle(tab == t ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                    }
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(tab == t ? ZLTheme.primarySoft : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // 概览
    private var overviewTab: some View {
        VStack(spacing: 10) {
            infoCard("当前版本", versionName)
            infoCard("控制布局", "默认")
            ZLCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("快捷操作").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text("· 双指滑动 = 鼠标滚轮")
                    Text("· 长按 = 右键")
                    Text("· 三指下滑 = 打开菜单")
                }
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
            }
        }
    }

    // 虚拟鼠标
    private var mouseTab: some View {
        VStack(spacing: 10) {
            sliderCard("抓取鼠标滑动灵敏度", $mouseSensitivity, 50...300, "%", 0)
            sliderCard("虚拟鼠标长按触发的延迟", $mouseLongDelay, 50...500, "ms", 0)
            toggleCard("鼠标点击", "启用屏幕点击映射为左键", $mouseClick)
        }
    }

    // 手柄
    private var gamepadTab: some View {
        VStack(spacing: 10) {
            toggleCard("手柄控制", "启用或关闭手柄控制功能", $gamepadOn)
            sliderCard("手柄死区缩放", $deadZone, 50...200, "%", 0)
            sliderCard("手柄光标灵敏度", $gamepadCursor, 25...300, "%", 0)
            sliderCard("手柄视角灵敏度", $gamepadCamera, 25...300, "%", 0)
        }
    }

    // 手势
    private var gestureTab: some View {
        VStack(spacing: 10) {
            toggleCard("手势控制", "启用双指/三指手势", $gestureEnabled)
            sliderCard("长按触发延迟", $longPressDelay, 100...1000, "ms", 0)
            ZLCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("手势映射").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    rowText("轻点", "鼠标右键")
                    rowText("长按", "鼠标左键")
                }
            }
        }
    }

    // 陀螺仪
    private var gyroTab: some View {
        VStack(spacing: 10) {
            toggleCard("陀螺仪控制", "用手机陀螺仪控制视角", $gyroOn)
            sliderCard("陀螺仪灵敏度", $gyroSensitivity, 25...300, "%", 0)
            sliderCard("采样率", $gyroInterval, 5...50, "ms", 0)
            toggleCard("数据平滑", "降低抖动，让视角更稳", $gyroSmooth)
        }
    }

    // 组件
    private func infoCard(_ k: String, _ v: String) -> some View {
        ZLCard {
            HStack {
                Text(k).font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                Spacer()
                Text(v).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary)
            }
        }
    }

    private func sliderCard(_ title: String, _ value: Binding<Double>,
                            _ range: ClosedRange<Double>, _ unit: String, _ decimals: Int) -> some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary)
                HStack {
                    Slider(value: value, in: range).tint(ZLTheme.primary)
                    Text("\(Int(value.wrappedValue))\(unit)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ZLTheme.primaryDeep).frame(width: 48)
                }
            }
        }
    }

    private func toggleCard(_ title: String, _ desc: String, _ on: Binding<Bool>) -> some View {
        ZLCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text(desc).font(.system(size: 10))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                Spacer()
                Toggle("", isOn: on).labelsHidden().tint(ZLTheme.primary)
            }
        }
    }

    private func rowText(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
            Spacer()
            Text(v).font(.system(size: 11)).foregroundStyle(ZLTheme.textPrimary)
        }
    }

    private func actionButton(_ title: String, _ icon: String, _ color: Color,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13))
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .foregroundStyle(color)
            .padding(.horizontal, 14).frame(height: 44)
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // 额外存储
    @AppStorage("mouseClick") private var mouseClick = true
    @AppStorage("gamepadOn") private var gamepadOn = true
    @AppStorage("gamepadCursor") private var gamepadCursor = 100.0
    @AppStorage("gamepadCamera") private var gamepadCamera = 100.0
    @AppStorage("gyroOn") private var gyroOn = false
}
