// ZL2-iOS · 游戏内菜单
//
// 逐项对齐 ZL2 安卓源码：
//   ui/screens/game/elements/GameMenuSubscreen.kt   —— 整体结构、5 个 Tab 的内容、右栏操作项
//   ui/components/Menu.kt                           —— DualMenuSubscreen / MenuTextButton /
//                                                      MenuSwitchButton / MenuListLayout / MenuSliderLayout
//   ui/screens/game/GameScreen.kt                   —— 菜单入口（悬浮球 / 返回键）
//   ui/screens/game/elements/ForceCloseDialog.kt    —— 强制关闭确认弹窗
//   utils/GameResolution.kt                         —— 自定义分辨率范围与初始化
//
// 安卓端的布局（Menu.kt:183-290）：
//   · 左 1/3 卡片：顶部图标 Tab（SecondaryScrollableTabRow）+ 5 页设置
//   · 右 1/3 卡片：标题「游戏菜单」+ 操作列表
//   · 中间是 25% 黑色遮罩，点遮罩关闭菜单
//   · 安卓端没有「返回游戏」按钮，关闭菜单即回到游戏；「强制关闭」在右栏第一项
//
// iOS 适配（源码里没有的分支）：
//   · 竖屏时两张卡片改为上下堆叠（游戏本身是横屏，这里只做兜底，不改内容）
//   · Tab 改为等宽平分（安卓是 minTabWidth 58dp 的可滚动 TabRow，卡片窄时也能放下 5 个图标）

import SwiftUI
import UIKit
import CoreMotion

// MARK: - 游戏菜单

struct GameMenuScreen: View {
    // MARK: 输入

    @Binding private var isPresented: Bool

    /// 安卓 GameMenuSubscreen 的 `SdlBridge.enabled`：只有 SDL 渲染路径才可用。
    /// iOS 端尚未接入 SDL，默认 false（对应「自动唤起输入法（SDL）」置灰）。
    private let sdlEnabled: Bool
    /// 安卓 `isGyroscopeAvailable(context)`，iOS 用 CoreMotion 判断。
    private let gyroscopeAvailable: Bool
    /// 安卓 `gamepadViewModel.getAllConfigKeys()`；iOS 未接入配置管理时为空数组。
    private let gamepadMappingConfigs: [String]
    /// 安卓 `AllSettings.enableTerracotta`。
    private let enableTerracotta: Bool

    // 以下回调对应 GameScreen.kt:757-781 传给 GameMenuSubscreen 的 lambda。
    // 传 nil 表示 iOS 端还没接入，按钮会给出明确提示而不是静默失败。
    private let onForceClose: (() -> Void)?
    private let onSwitchLog: (() -> Void)?
    private let onOpenTerracottaMenu: (() -> Void)?
    private let onRefreshWindowSize: (() -> Void)?
    private let onInputMethod: (() -> Void)?
    private let onSendKeycode: (() -> Void)?
    private let onReplacementControl: (() -> Void)?
    private let onEditLayout: (() -> Void)?
    private let onShowToast: ((String) -> Void)?

    // MARK: 状态

    @StateObject private var store = ZLSettingsStore.shared
    @StateObject private var toast = GameMenuToastCenter()
    @State private var tab: GameMenuTab = .overview
    @State private var appeared = false
    @State private var forceCloseAlert = false

    // MARK: 初始化

    init(isPresented: Binding<Bool>,
         sdlEnabled: Bool = false,
         gyroscopeAvailable: Bool = GameMenuScreen.systemGyroscopeAvailable,
         gamepadMappingConfigs: [String] = [],
         enableTerracotta: Bool = false,
         onForceClose: (() -> Void)? = nil,
         onSwitchLog: (() -> Void)? = nil,
         onOpenTerracottaMenu: (() -> Void)? = nil,
         onRefreshWindowSize: (() -> Void)? = nil,
         onInputMethod: (() -> Void)? = nil,
         onSendKeycode: (() -> Void)? = nil,
         onReplacementControl: (() -> Void)? = nil,
         onEditLayout: (() -> Void)? = nil,
         onShowToast: ((String) -> Void)? = nil) {
        self._isPresented = isPresented
        self.sdlEnabled = sdlEnabled
        self.gyroscopeAvailable = gyroscopeAvailable
        self.gamepadMappingConfigs = gamepadMappingConfigs
        self.enableTerracotta = enableTerracotta
        self.onForceClose = onForceClose
        self.onSwitchLog = onSwitchLog
        self.onOpenTerracottaMenu = onOpenTerracottaMenu
        self.onRefreshWindowSize = onRefreshWindowSize
        self.onInputMethod = onInputMethod
        self.onSendKeycode = onSendKeycode
        self.onReplacementControl = onReplacementControl
        self.onEditLayout = onEditLayout
        self.onShowToast = onShowToast
    }

    /// 安卓 isGyroscopeAvailable(context) 的 iOS 版本
    static let systemGyroscopeAvailable: Bool = CMMotionManager().isGyroAvailable

    /// strings.xml（terracotta.xml）里的 terracotta_menu，ZLStrings 未收录
    static let terracottaMenuTitle = "联机菜单"

    // MARK: - 主体

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width >= geo.size.height
            let cardWidth = max(200, geo.size.width / 3)

            ZStack {
                // 背景阴影层（Menu.kt:197-214，Color.Black.copy(alpha = 0.25f)），点击关闭
                Color.black.opacity(0.25)
                    .contentShape(Rectangle())
                    .onTapGesture { close() }

                if landscape {
                    HStack(spacing: 0) {
                        leftMenu
                            .frame(width: cardWidth)
                            .offset(x: appeared ? 0 : -40)
                        Spacer(minLength: 0)
                        rightMenu
                            .frame(width: cardWidth)
                            .offset(x: appeared ? 0 : 40)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 12) {
                        leftMenu
                        rightMenu
                    }
                    .padding(12)
                    .offset(y: appeared ? 0 : 24)
                }

                if let text = toast.text {
                    toastView(text)
                }
            }
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.2)) { appeared = true }
            }
        }
        .ignoresSafeArea()
        .alert(ZLStrings.game_button_force_close, isPresented: $forceCloseAlert) {
            Button(ZLStrings.generic_cancel, role: .cancel) {}
            Button(ZLStrings.generic_confirm, role: .destructive) {
                if let onForceClose {
                    onForceClose()
                } else {
                    showToast("iOS 端尚未接入 JVM 退出接口")
                }
            }
        } message: {
            // game_menu_option_force_close_text
            Text(ZLStrings.game_menu_option_force_close_text)
        }
    }

    // MARK: - 两张卡片

    private var leftMenu: some View {
        menuCard {
            tabBar

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    switch tab {
                    case .overview: overviewRows
                    case .mouse: mouseRows
                    case .gamepad: gamepadRows
                    case .gesture: gestureRows
                    case .gyroscope: gyroscopeRows
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private var rightMenu: some View {
        menuCard {
            // 右栏标题（GameMenuSubscreen.kt:187-193），高度 48dp
            Text(ZLStrings.game_menu_title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ZLTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(ZLTheme.surfaceAlt)

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    actionRows
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private func menuCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .shadow(color: Color.black.opacity(0.22), radius: 16, x: 0, y: 6)
    }

    // MARK: - Tab 栏（GameMenuSubscreen.kt:92-156）

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(GameMenuTab.allCases, id: \.self) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { tab = item }
                } label: {
                    VStack(spacing: 0) {
                        Image(systemName: item.icon)
                            .font(.system(size: item.iconSize, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                        Rectangle()
                            .fill(tab == item ? ZLTheme.primary : Color.clear)
                            .frame(height: 2)
                    }
                    .foregroundStyle(tab == item ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, maxWidth: .infinity)
                .accessibilityLabel(item.title)
            }
        }
        .frame(height: 46)
        .background(ZLTheme.surfaceAlt)
    }

    // MARK: - 右栏操作（GameMenuSubscreen.kt:208-439）

    @ViewBuilder
    private var actionRows: some View {
        // 强制关闭
        textButton(ZLStrings.game_button_force_close) { forceCloseAlert = true }
        // 日志输出
        textButton(ZLStrings.game_menu_option_switch_log) {
            perform(onSwitchLog)
        }

        // 开启多人联机时才会出现（GameMenuSubscreen.kt:249-265）
        if enableTerracotta {
            Color.clear.frame(height: 8)
            textButton(GameMenuScreen.terracottaMenuTitle) {
                perform(onOpenTerracottaMenu)
            }
        }

        Color.clear.frame(height: 8)

        // 开启菜单悬浮窗
        switchRow(ZLStrings.game_menu_option_show_menu, "showMenuBall") { value in
            if !value {
                // game_menu_option_show_menu_hided
                showToast(ZLStrings.game_menu_option_show_menu_hided)
            }
        }
        // 菜单悬浮窗不透明度
        sliderRow(ZLStrings.game_menu_option_menu_ball_opacity, "menuBallOpacity",
                  range: 20...100, suffix: "%",
                  enabled: boolValue("showMenuBall"))
        // 帧率显示
        switchRow(ZLStrings.game_menu_option_switch_fps, "showFPS",
                  enabled: boolValue("showMenuBall"))
        // 帧率显示模式
        listRow(ZLStrings.game_menu_option_fps_display_mode,
                key: "fpsDisplayMode",
                options: [
                    GameMenuOption(value: "FpsDisplayMode.NUMBER",
                                   label: ZLStrings.game_menu_option_fps_display_mode_number),
                    GameMenuOption(value: "FpsDisplayMode.CHART",
                                   label: ZLStrings.game_menu_option_fps_display_mode_chart),
                ],
                enabled: boolValue("showMenuBall") && boolValue("showFPS"))
        // 内存显示
        switchRow(ZLStrings.game_menu_option_switch_memory, "showMemory",
                  enabled: boolValue("showMenuBall"))
        // 请求最高刷新率
        switchRow(ZLStrings.settings_renderer_max_refresh_rate_title, "requestMaxRefreshRate")

        Color.clear.frame(height: 8)

        resolutionSection
    }

    // 分辨率规则 + 对应的子项（GameMenuSubscreen.kt:365-438）
    @ViewBuilder
    private var resolutionSection: some View {
        VStack(spacing: 8) {
            GameMenuListRow(
                title: ZLStrings.settings_renderer_resolution_rule_title,
                options: [
                    GameMenuOption(value: "ResolutionRule.PERCENTAGE",
                                   label: ZLStrings.settings_renderer_resolution_rule_percentage),
                    GameMenuOption(value: "ResolutionRule.CUSTOM",
                                   label: ZLStrings.generic_custom),
                ],
                current: stringValue("resolutionRule")
            ) { value in
                setString("resolutionRule", value)
                if value == "ResolutionRule.CUSTOM" {
                    ensureCustomResolutionInitialized()
                }
                onRefreshWindowSize?()
            }

            if stringValue("resolutionRule") == "ResolutionRule.PERCENTAGE" {
                sliderRow(ZLStrings.settings_renderer_resolution_scale_title, "resolutionRatio",
                          range: 25...300, suffix: "%") {
                    // 安卓 onValueChangeFinished 里才触发窗口重建
                    onRefreshWindowSize?()
                }
            } else {
                customResolutionCard
            }
        }
    }

    // 自定义分辨率输入卡片（GameMenuSubscreen.kt:446-495）
    private var customResolutionCard: some View {
        let widthRange = customResolutionRange(Int(screenPixelSize.width))
        let heightRange = customResolutionRange(Int(screenPixelSize.height))
        return VStack(alignment: .leading, spacing: 8) {
            Text(ZLStrings.settings_renderer_resolution_scale_title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
            HStack(spacing: 8) {
                GameMenuIntField(label: ZLStrings.settings_renderer_resolution_custom_width,
                                 value: intValue("customResolutionWidth"),
                                 range: widthRange) { value in
                    setInt("customResolutionWidth", value)
                    onRefreshWindowSize?()
                }
                GameMenuIntField(label: ZLStrings.settings_renderer_resolution_custom_height,
                                 value: intValue("customResolutionHeight"),
                                 range: heightRange) { value in
                    setInt("customResolutionHeight", value)
                    onRefreshWindowSize?()
                }
            }
        }
        .padding(10)
        .background(ZLTheme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 安卓 ensureCustomResolutionInitialized()：尚未初始化时用屏幕真实宽高填充
    private func ensureCustomResolutionInitialized() {
        guard intValue("customResolutionWidth") <= 0 || intValue("customResolutionHeight") <= 0 else { return }
        let px = screenPixelSize
        setInt("customResolutionWidth", Int(px.width))
        setInt("customResolutionHeight", Int(px.height))
    }

    /// 安卓 getRealScreenSize(context) —— 屏幕真实像素尺寸
    private var screenPixelSize: CGSize {
        let bounds = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        return CGSize(width: bounds.width * scale, height: bounds.height * scale)
    }

    /// 安卓 customResolutionRange(screenSide)：屏幕边长的 20% ~ 300%，偶数
    private func customResolutionRange(_ side: Int) -> ClosedRange<Int> {
        func friendly(_ value: Double) -> Int {
            var result = Int(value)
            if result % 2 != 0 { result -= 1 }
            return max(2, result)
        }
        let lower = friendly(Double(side) * 0.2)
        let upper = max(lower, Int((Double(side) * 3).rounded()))
        return lower...upper
    }

    // MARK: - 左栏 Tab 内容

    // 概览（GameMenuSubscreen.kt:497-611）
    @ViewBuilder
    private var overviewRows: some View {
        textButton(ZLStrings.game_menu_option_input_method) {
            performAndClose(onInputMethod)
        }
        switchRow(ZLStrings.game_menu_option_auto_show_ime, "sdlAutoShowIme",
                  enabled: sdlEnabled)
        switchRow(ZLStrings.game_menu_option_ime_magnifier_auto_show, "imeMagnifierAutoShow")

        Color.clear.frame(height: 8)

        textButton(ZLStrings.game_menu_option_send_keycode) {
            performAndClose(onSendKeycode)
        }
        textButton(ZLStrings.game_menu_option_replacement_control) {
            performAndClose(onReplacementControl)
        }
        textButton(ZLStrings.control_manage_info_edit) {
            performAndClose(onEditLayout)
        }
        sliderRow(ZLStrings.game_menu_option_controls_opacity, "controlsOpacity",
                  range: 0...100, suffix: "%")
    }

    // 虚拟鼠标（GameMenuSubscreen.kt:614-734）
    @ViewBuilder
    private var mouseRows: some View {
        let mode = stringValue("mouseControlMode")
        switchRow(ZLStrings.settings_control_mouse_hide_title, "hideMouse",
                  enabled: mode == "MouseControlMode.CLICK")
        switchRow(ZLStrings.settings_control_mouse_enable_click_title, "enableMouseClick",
                  enabled: mode == "MouseControlMode.SLIDE")
        listRow(ZLStrings.settings_control_mouse_control_mode_title,
                key: "mouseControlMode",
                options: [
                    GameMenuOption(value: "MouseControlMode.SLIDE",
                                   label: ZLStrings.settings_control_mouse_control_mode_slide),
                    GameMenuOption(value: "MouseControlMode.CLICK",
                                   label: ZLStrings.settings_control_mouse_control_mode_click),
                ])
        listRow(ZLStrings.settings_control_mouse_block_touch_title,
                key: "mouseTouchBlockMode",
                options: [
                    GameMenuOption(value: "MouseTouchBlockMode.NONE",
                                   label: ZLStrings.generic_close),
                    GameMenuOption(value: "MouseTouchBlockMode.LEFT",
                                   label: ZLStrings.settings_control_mouse_block_touch_left),
                    GameMenuOption(value: "MouseTouchBlockMode.RIGHT",
                                   label: ZLStrings.settings_control_mouse_block_touch_right),
                ])
        sliderRow(ZLStrings.settings_control_mouse_size_title, "mouseSize",
                  range: 5...50, suffix: "Dp")
        sliderRow(ZLStrings.settings_control_mouse_sensitivity_title, "cursorSensitivity",
                  range: 25...300, suffix: "%")
        sliderRow(ZLStrings.settings_control_mouse_capture_sensitivity_title, "mouseCaptureSensitivity",
                  range: 25...300, suffix: "%")
        sliderRow(ZLStrings.settings_control_mouse_long_press_delay_title, "mouseLongPressDelay",
                  range: 100...1000, suffix: "ms")
    }

    // 手柄（GameMenuSubscreen.kt:736-869）
    @ViewBuilder
    private var gamepadRows: some View {
        let gamepadOn = boolValue("gamepadControl")
        // 安卓 remapEnabled：总开关打开且处于映射模式
        let remapEnabled = gamepadOn && stringValue("gamepadInputMode") == "GamepadInputMode.Mapped"

        switchRow(ZLStrings.settings_gamepad_title, "gamepadControl")

        Color.clear.frame(height: 8)

        listRow(ZLStrings.settings_gamepad_input_mode_title,
                key: "gamepadInputMode",
                options: [
                    GameMenuOption(value: "GamepadInputMode.Mapped",
                                   label: ZLStrings.settings_gamepad_input_mode_mapped),
                    GameMenuOption(value: "GamepadInputMode.SdlDirect",
                                   label: ZLStrings.settings_gamepad_input_mode_sdl),
                ],
                enabled: gamepadOn)

        Color.clear.frame(height: 8)

        sliderRow(ZLStrings.settings_gamepad_deadzone_title, "gamepadDeadZoneScale",
                  range: 50...200, suffix: "%", enabled: remapEnabled)
        sliderRow(ZLStrings.settings_gamepad_cursor_sensitivity_title, "gamepadCursorSensitivity",
                  range: 25...300, suffix: "%", enabled: remapEnabled)
        sliderRow(ZLStrings.settings_gamepad_camera_sensitivity_title, "gamepadCameraSensitivity",
                  range: 25...300, suffix: "%", enabled: remapEnabled)

        if gamepadMappingConfigs.isEmpty {
            // 安卓这里是置灰的 MenuTextButton（未创建配置）
            textButton(ZLStrings.settings_gamepad_config_no_items, enabled: false) {}
        } else {
            GameMenuListRow(
                title: ZLStrings.settings_gamepad_config_title,
                options: gamepadMappingConfigs.map { GameMenuOption(value: $0, label: $0) },
                current: stringValue("gamepadMappingConfig"),
                enabled: remapEnabled
            ) { value in
                // 安卓这里还会调用 gamepadViewModel.reloadAllMappings()，由宿主接入
                setString("gamepadMappingConfig", value)
            }
        }
    }

    // 手势（GameMenuSubscreen.kt:871-1044）
    @ViewBuilder
    private var gestureRows: some View {
        let gestureOn = boolValue("gestureControl")
        let customHotbar = stringValue("hotbarRule") == "HotbarRule.Custom"
        let longClick = boolValue("hotbarLongClick")

        switchRow(ZLStrings.settings_control_gesture_control_title, "gestureControl")
        listRow(ZLStrings.settings_control_gesture_tap_action_title,
                key: "gestureTapMouseAction",
                options: gestureActionOptions,
                enabled: gestureOn)
        listRow(ZLStrings.settings_control_gesture_long_press_action_title,
                key: "gestureLongPressMouseAction",
                options: gestureActionOptions,
                enabled: gestureOn)
        sliderRow(ZLStrings.settings_control_gesture_long_press_delay_title, "gestureLongPressDelay",
                  range: 100...1000, suffix: "ms", enabled: gestureOn)

        Color.clear.frame(height: 8)

        listRow(ZLStrings.game_menu_option_hotbar_rule,
                key: "hotbarRule",
                options: [
                    GameMenuOption(value: "HotbarRule.Auto",
                                   label: ZLStrings.game_menu_option_hotbar_rule_auto),
                    GameMenuOption(value: "HotbarRule.Custom",
                                   label: ZLStrings.game_menu_option_hotbar_rule_custom),
                ])
        // 快捷栏宽/高在设置里存 0~1000，界面上按 0~100% 显示（安卓 hotbarWidth/10f）
        decimalSliderRow(ZLStrings.game_menu_option_hotbar_width, "hotbarWidth",
                         enabled: customHotbar)
        decimalSliderRow(ZLStrings.game_menu_option_hotbar_height, "hotbarHeight",
                         enabled: customHotbar)
        switchRow(ZLStrings.game_menu_option_hotbar_double_click, "hotbarDoubleClick")
        switchRow(ZLStrings.game_menu_option_hotbar_long_click, "hotbarLongClick")
        sliderRow(ZLStrings.game_menu_option_hotbar_long_click_delay, "hotbarLongClickDelay",
                  range: 100...1000, suffix: "ms", enabled: longClick)
    }

    private var gestureActionOptions: [GameMenuOption] {
        // 枚举顺序与安卓 GestureActionType 一致：MOUSE_RIGHT, MOUSE_LEFT
        [
            GameMenuOption(value: "GestureActionType.MOUSE_RIGHT",
                           label: ZLStrings.settings_control_gesture_trigger_mouse_right),
            GameMenuOption(value: "GestureActionType.MOUSE_LEFT",
                           label: ZLStrings.settings_control_gesture_trigger_mouse_left),
        ]
    }

    // 陀螺仪（GameMenuSubscreen.kt:1046-1162）
    @ViewBuilder
    private var gyroscopeRows: some View {
        let usable = gyroscopeAvailable
        let gyroOn = boolValue("gyroscopeControl")
        let enabled = usable && gyroOn
        let smoothing = boolValue("gyroscopeSmoothing")

        switchRow(ZLStrings.settings_control_gyroscope_title, "gyroscopeControl",
                  enabled: usable)
        sliderRow(ZLStrings.settings_control_gyroscope_sensitivity_title, "gyroscopeSensitivity",
                  range: 25...300, suffix: "%", enabled: enabled)
        sliderRow(ZLStrings.settings_control_gyroscope_sample_rate_title, "gyroscopeSampleRate",
                  range: 5...50, suffix: "ms", enabled: enabled)
        switchRow(ZLStrings.settings_control_gyroscope_smoothing_title, "gyroscopeSmoothing",
                  enabled: enabled)
        sliderRow(ZLStrings.settings_control_gyroscope_smoothing_window_title, "gyroscopeSmoothingWindow",
                  range: 2...10, enabled: enabled && smoothing)
        switchRow(ZLStrings.settings_control_gyroscope_invert_x_title, "gyroscopeInvertX",
                  enabled: enabled)
        switchRow(ZLStrings.settings_control_gyroscope_invert_y_title, "gyroscopeInvertY",
                  enabled: enabled)

        if !usable {
            // 安卓游戏菜单里只是把开关置灰；这里补一行官方文案说明原因（设置页同一句）
            Text(ZLStrings.settings_control_gyroscope_unsupported)
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - 行组件（对应 Menu.kt 的三个 Composable）

    /// MenuTextButton（Menu.kt:314-346）
    private func textButton(_ title: String, enabled: Bool = true,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .padding(.horizontal, 12)
                .background(ZLTheme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
    }

    /// MenuSwitchButton（Menu.kt:348-390）
    private func switchRow(_ title: String, _ key: String, enabled: Bool = true,
                           onChange: ((Bool) -> Void)? = nil) -> some View {
        let binding = Binding<Bool>(
            get: { boolValue(key) },
            set: { value in
                setBool(key, value)
                onChange?(value)
            }
        )
        return HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(ZLTheme.primary)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 52)
        .background(ZLTheme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
    }

    /// MenuListLayout（Menu.kt:392-475）—— 展开式单选列表，不是 iOS 的 Menu 弹窗
    private func listRow(_ title: String, key: String, options: [GameMenuOption],
                         enabled: Bool = true) -> some View {
        GameMenuListRow(title: title,
                        options: options,
                        current: stringValue(key),
                        enabled: enabled) { value in
            setString(key, value)
        }
    }

    /// MenuSliderLayout（整数，Menu.kt:556-633）
    private func sliderRow(_ title: String, _ key: String, range: ClosedRange<Int>,
                           suffix: String = "", enabled: Bool = true,
                           onCommit: (() -> Void)? = nil) -> some View {
        GameMenuSliderRow(
            title: title,
            value: Double(intValue(key)),
            range: Double(range.lowerBound)...Double(range.upperBound),
            step: 1,
            decimals: 0,
            suffix: suffix,
            enabled: enabled,
            onChange: { setInt(key, Int($0.rounded())) },
            onCommit: { _ in onCommit?() }
        )
    }

    /// 快捷栏宽高：存储值是 0~1000 的千分比，界面按 0~100.00% 显示
    private func decimalSliderRow(_ title: String, _ key: String,
                                  enabled: Bool = true) -> some View {
        GameMenuSliderRow(
            title: title,
            value: Double(intValue(key)) / 10.0,
            range: 0...100,
            step: 0.1,
            decimals: 2,
            suffix: "%",
            enabled: enabled,
            onChange: { setInt(key, Int(($0 * 10).rounded())) },
            onCommit: { _ in }
        )
    }

    // MARK: - 设置读写（key 与 AllSettings.kt 一致）

    private func boolValue(_ key: String) -> Bool {
        guard let def = ZLSettings.def(key) else { return false }
        return store.bool(def)
    }

    private func intValue(_ key: String) -> Int {
        guard let def = ZLSettings.def(key) else { return 0 }
        return store.int(def)
    }

    private func stringValue(_ key: String) -> String {
        guard let def = ZLSettings.def(key) else { return "" }
        return store.string(def)
    }

    private func setBool(_ key: String, _ value: Bool) {
        guard let def = ZLSettings.def(key) else { return }
        store.set(def, value)
    }

    private func setInt(_ key: String, _ value: Int) {
        guard let def = ZLSettings.def(key) else { return }
        store.set(def, value)
    }

    private func setString(_ key: String, _ value: String) {
        guard let def = ZLSettings.def(key) else { return }
        store.set(def, value)
    }

    // MARK: - 动作与提示

    private func close() {
        isPresented = false
    }

    private func perform(_ action: (() -> Void)?) {
        guard let action else {
            showToast("iOS 端尚未接入该功能")
            return
        }
        action()
    }

    /// 安卓里这些按钮点击后会 closeScreen()；iOS 端在确实有实现时才关闭
    private func performAndClose(_ action: (() -> Void)?) {
        guard let action else {
            showToast("iOS 端尚未接入该功能")
            return
        }
        close()
        action()
    }

    private func showToast(_ text: String) {
        onShowToast?(text)
        toast.show(text)
    }

    private func toastView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.black.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
    }
}

// MARK: - Tab 定义（GameMenuSubscreen.kt:90-103）

private enum GameMenuTab: CaseIterable {
    case overview
    case mouse
    case gamepad
    case gesture
    case gyroscope

    /// 安卓：ic_dashboard_filled / ic_mouse_filled / ic_sports_esports_filled /
    ///       ic_touch_app_filled / ic_mobile_rotate_filled
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .mouse: return "computermouse.fill"
        case .gamepad: return "gamecontroller.fill"
        case .gesture: return "hand.tap.fill"
        case .gyroscope: return "gyroscope"
        }
    }

    /// 安卓鼠标图标 16dp，其余 18dp
    var iconSize: CGFloat {
        self == .mouse ? 15 : 17
    }

    var title: String {
        switch self {
        case .overview: return "概览"
        case .mouse: return "虚拟鼠标"
        case .gamepad: return "手柄"
        case .gesture: return "手势"
        case .gyroscope: return "陀螺仪"
        }
    }
}

// MARK: - 列表项模型

private struct GameMenuOption: Identifiable {
    let value: String
    let label: String
    var id: String { value }
}

// MARK: - 展开式单选列表（Menu.kt:392-554）

private struct GameMenuListRow: View {
    let title: String
    let options: [GameMenuOption]
    let current: String
    var enabled: Bool = true
    let onChange: (String) -> Void

    @State private var expanded = false

    private var currentLabel: String {
        options.first(where: { $0.value == current })?.label ?? current
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                guard enabled, !options.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ZLTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(currentLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ZLTheme.textSecond)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(ZLTheme.surface)
                            .clipShape(Capsule())
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ZLTheme.textSecond)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded && !options.isEmpty {
                VStack(spacing: 0) {
                    ForEach(options) { option in
                        Button {
                            if option.value != current { onChange(option.value) }
                            withAnimation(.easeInOut(duration: 0.2)) { expanded = false }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: option.value == current ? "circle.inset.filled" : "circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(option.value == current ? ZLTheme.primary : ZLTheme.textSecond)
                                Text(option.label)
                                    .font(.system(size: 12))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .background(ZLTheme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
    }
}

// MARK: - 滑块行（Menu.kt:556-715，支持点数值直接输入）

private struct GameMenuSliderRow: View {
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var decimals: Int = 0
    var suffix: String = ""
    var enabled: Bool = true
    let onChange: (Double) -> Void
    let onCommit: (Double) -> Void

    @State private var editing = false
    @State private var draft = ""

    private var clamped: Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func display(_ raw: Double) -> String {
        String(format: "%.\(decimals)f", raw) + suffix
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button {
                    guard enabled else { return }
                    draft = display(clamped)
                    editing = true
                } label: {
                    Text(display(clamped))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ZLTheme.primaryDeep)
                }
                .buttonStyle(.plain)
            }

            Slider(value: Binding(get: { clamped }, set: { onChange($0) }),
                   in: range,
                   step: step,
                   onEditingChanged: { isEditing in
                       if !isEditing { onCommit(clamped) }
                   })
                .tint(ZLTheme.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(ZLTheme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(enabled ? 1 : 0.4)
        .allowsHitTesting(enabled)
        .alert(title, isPresented: $editing) {
            TextField("", text: $draft)
                .keyboardType(decimals == 0 ? .numberPad : .decimalPad)
            Button(ZLStrings.generic_cancel, role: .cancel) {}
            Button(ZLStrings.generic_confirm) {
                if let entered = Double(draft) {
                    let next = min(max(entered, range.lowerBound), range.upperBound)
                    onChange(next)
                    onCommit(next)
                }
            }
        } message: {
            Text("\(display(range.lowerBound)) ~ \(display(range.upperBound))")
        }
    }
}

// MARK: - 自定义分辨率输入框（GameMenuSubscreen.kt:472-492）

private struct GameMenuIntField: View {
    let label: String
    let value: Int
    let range: ClosedRange<Int>
    let onCommit: (Int) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(ZLTheme.textSecond)
            TextField("0", text: $text)
                .keyboardType(.numberPad)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .focused($focused)
                .padding(.horizontal, 8)
                .frame(height: 34)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onSubmit { commit() }
        }
        .onAppear { text = "\(value)" }
        .onChange(of: value) { newValue in
            if !focused, text != "\(newValue)" { text = "\(newValue)" }
        }
        .onChange(of: focused) { isFocused in
            if !isFocused { commit() }
        }
    }

    private func commit() {
        let parsed = Int(text) ?? value
        let next = min(max(parsed, range.lowerBound), range.upperBound)
        text = "\(next)"
        if next != value { onCommit(next) }
    }
}

// MARK: - Toast（安卓 Toast.makeText）

private final class GameMenuToastCenter: ObservableObject {
    @Published var text: String?
    private var token = UUID()

    func show(_ newText: String) {
        text = newText
        let current = UUID()
        token = current
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self, self.token == current else { return }
            self.text = nil
        }
    }
}
