// ZL2-iOS · 设置页
// 结构对齐 ZL2 安卓版：左侧竖排分类（渲染 / 游戏 / 控制 / 手柄 / 启动器，分隔线后 Java 管理 / 控制管理 / 关于）
// 每个分类内的设置项、控件类型、标题/说明文案均取自 AllSettings.kt 与 values-zh-rCN/strings.xml
import Foundation
import SwiftUI
import Combine

// MARK: - 设置读写（key 与 AllSettings.kt 一致，默认值统一回退到 ZLSettings）

final class ZLSettingsStore: ObservableObject {
    static let shared = ZLSettingsStore()

    /// 每次写入自增，驱动 SwiftUI 刷新
    @Published private(set) var revision = 0

    private let defaults = UserDefaults.standard

    func bool(_ def: ZLSettingDef) -> Bool {
        if let v = defaults.object(forKey: def.key) as? Bool { return v }
        return def.defaultValue == "true"
    }

    func int(_ def: ZLSettingDef) -> Int {
        if let v = defaults.object(forKey: def.key) as? Int { return v }
        return Int(def.defaultValue) ?? 0
    }

    /// 可空整数：安卓默认 null 的项（ramAllocation / physicalKeyImeCode / lastIgnoredVersion）
    func intOrNil(_ def: ZLSettingDef) -> Int? {
        if let v = defaults.object(forKey: def.key) as? Int { return v }
        if def.isNullable || def.defaultValue.isEmpty { return nil }
        return Int(def.defaultValue)
    }

    func string(_ def: ZLSettingDef) -> String {
        if let v = defaults.object(forKey: def.key) as? String { return v }
        return def.isNullable ? "" : def.defaultValue
    }

    func set(_ def: ZLSettingDef, _ value: Bool) {
        defaults.set(value, forKey: def.key)
        revision += 1
    }

    func set(_ def: ZLSettingDef, _ value: Int) {
        defaults.set(value, forKey: def.key)
        revision += 1
    }

    func set(_ def: ZLSettingDef, _ value: String) {
        defaults.set(value, forKey: def.key)
        revision += 1
    }

    func reset(_ def: ZLSettingDef) {
        defaults.removeObject(forKey: def.key)
        revision += 1
    }

    /// "x,y" → (x, y)，用于鼠标热点 / 菜单悬浮窗位置
    static func parsePoint(_ raw: String) -> (Int, Int) {
        let parts = raw.split(separator: ",")
        if parts.count == 2,
           let x = Int(parts[0].trimmingCharacters(in: .whitespaces)),
           let y = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
            return (x, y)
        }
        return (50, 50)
    }
}

// MARK: - 设置行描述

private struct ZLOption: Identifiable {
    let value: String
    let label: String
    var id: String { value }
}

private struct ZLSettingRow: Identifiable {
    enum Kind {
        case toggle
        case slider(unit: String, minValue: Int?, maxValue: Int?)
        case picker([ZLOption])
        case text(placeholder: String)
        case number(placeholder: String)
        case info(String)
        case hotspot
        case keyCode
        case blur
        case animateSpeed
        case darkMode
    }

    let key: String
    let title: String
    let summary: String?
    let kind: Kind
    /// 该项在当前平台无效（iOS 没有此能力 / 还没接线），UI 应置灰
    var disabled: Bool = false
    /// 置灰原因，显示在标题下方
    var note: String? = nil

    var id: String { key }
    var def: ZLSettingDef? { ZLSettings.def(key) }
}

// MARK: - 设置页

struct SettingsScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    var onDownload: () -> Void = {}

    @StateObject private var store = ZLSettingsStore.shared
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var section = 0
    @State private var hotspotTarget: ZLSettingDef?
    /// 点击了被禁用设置项时弹出的提示
    @State private var toastText: String?

    // ZL2 的设置页分类（strings.xml: settings_tab_*）
    private let sections = [
        ZLStrings.settings_tab_renderer,
        ZLStrings.settings_tab_game,
        ZLStrings.settings_tab_control,
        ZLStrings.settings_tab_gamepad,
        ZLStrings.settings_tab_launcher,
    ]
    private let icons = [
        "paintbrush.pointed.fill",
        "gamecontroller.fill",
        "dpad.fill",
        "gamepad.fill",
        "shippingbox.fill",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "\(ZLStrings.generic_setting) - \(sections[max(0, min(section, sections.count - 1))])",
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
        .sheet(item: $hotspotTarget) { def in
            ZLHotspotEditor(def: def, store: store)
        }
        .overlay(alignment: .bottom) {
            if let toastText {
                Text(toastText)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Color.black.opacity(0.78))
                    .clipShape(Capsule())
                    .padding(.bottom, 40)
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
                            withAnimation(.easeOut(duration: 0.2)) { self.toastText = nil }
                        }
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: toastText)
        .onAppear(perform: syncThemeSettings)
    }

    // MARK: 左侧分类

    private var sideRail: some View {
        VStack(spacing: 6) {
            ForEach(sections.indices, id: \.self) { i in
                Button { section = i } label: {
                    railLabel(title: sections[i], icon: icons[i], selected: section == i)
                }
                .buttonStyle(.plain)
            }

            Divider()
                .padding(.vertical, 10)
                .padding(.horizontal, 18)

            NavigationLink(value: AppRoute.javaManage) {
                railLabel(title: ZLStrings.settings_tab_java_manage,
                          icon: "cup.and.saucer.fill", selected: false)
            }
            .buttonStyle(.plain)

            NavigationLink(value: AppRoute.controlManage) {
                railLabel(title: ZLStrings.settings_tab_control_manage,
                          icon: "dpad.fill", selected: false)
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.vertical, 10)
                .padding(.horizontal, 18)

            // 环境诊断：真机出问题时，用户打开这里复制报告发给开发者
            NavigationLink(value: AppRoute.diagnostics) {
                railLabel(title: "环境诊断",
                          icon: "stethoscope", selected: false)
            }
            .buttonStyle(.plain)

            NavigationLink(value: AppRoute.about) {
                railLabel(title: ZLStrings.settings_tab_info_about,
                          icon: "info.circle", selected: false)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.leading, 8)
        .padding(.vertical, 8)
        .frame(width: 92)
    }

    private func railLabel(title: String, icon: String, selected: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 19))
            Text(title).font(.system(size: 11)).lineLimit(1)
        }
        .foregroundStyle(selected ? ZLTheme.primaryDeep : ZLTheme.textSecond)
        .frame(width: 76, height: 62)
        .background(selected ? ZLTheme.primarySoft : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 渲染设置（15 项）

    @ViewBuilder
    private var renderSettings: some View {
        cardGroup(rows: [
            // 原来这里是自由输入框 —— 用户随手打一个 "OpenGL" 进去，
            // 核心会拿着这个名字去 dlopen("@rpath/OpenGL")，必然失败。
            // 改成只能从「包里真实存在的渲染库」里选（见 ZLRenderers.swift）。
            picker("renderer",
                   ZLStrings.settings_renderer_global_renderer_title,
                   ZLStrings.settings_renderer_global_renderer_summary,
                   options: ZLRenderers.pickerPairs().map { ZLOption(value: $0.value, label: $0.label) }),
            toggle("sfpewPluginLayer",
                   ZLStrings.settings_renderer_sfpew_plugin_layer_title,
                   ZLStrings.settings_renderer_sfpew_plugin_layer_summary),
            toggle("sfpewRelaxedContext",
                   ZLStrings.renderer_config_sfpew_relaxed_context_title,
                   ZLStrings.renderer_config_sfpew_relaxed_context_desc),
            text("vulkanDriver",
                 ZLStrings.settings_renderer_global_vulkan_driver_title,
                 nil,
                 placeholder: "default turnip"),
            picker("graphicsApi",
                   ZLStrings.settings_game_graphics_api_title,
                   ZLStrings.settings_game_graphics_api_summary,
                   options: [
                       ZLOption(value: "GraphicsApi.DEFAULT", label: ZLStrings.settings_game_graphics_api_default),
                       ZLOption(value: "GraphicsApi.OPENGL", label: "OpenGL"),
                       ZLOption(value: "GraphicsApi.DEFAULT_OPENGL", label: ZLStrings.settings_game_graphics_api_default_opengl),
                       ZLOption(value: "GraphicsApi.VULKAN", label: "Vulkan"),
                   ]),
        ])

        cardGroup(rows: [
            picker("resolutionRule",
                   ZLStrings.settings_renderer_resolution_rule_title,
                   ZLStrings.settings_renderer_resolution_rule_summary,
                   options: [
                       ZLOption(value: "ResolutionRule.PERCENTAGE", label: ZLStrings.settings_renderer_resolution_rule_percentage),
                       ZLOption(value: "ResolutionRule.CUSTOM", label: ZLStrings.generic_custom),
                   ]),
            slider("resolutionRatio",
                   ZLStrings.settings_renderer_resolution_scale_title,
                   ZLStrings.settings_renderer_resolution_scale_summary,
                   unit: "%"),
            number("customResolutionWidth",
                   ZLStrings.settings_renderer_resolution_custom_width,
                   ZLStrings.settings_renderer_resolution_custom_summary,
                   placeholder: "0"),
            number("customResolutionHeight",
                   ZLStrings.settings_renderer_resolution_custom_height,
                   nil,
                   placeholder: "0"),
        ])

        cardGroup(rows: [
            toggle("gameFullScreen",
                   ZLStrings.settings_renderer_full_screen_title,
                   ZLStrings.settings_renderer_full_screen_summary),
            toggle("sustainedPerformance",
                   ZLStrings.settings_renderer_sustained_performance_title,
                   ZLStrings.settings_renderer_sustained_performance_summary),
            toggle("requestMaxRefreshRate",
                   ZLStrings.settings_renderer_max_refresh_rate_title,
                   ZLStrings.settings_renderer_max_refresh_rate_summary),
            toggle("zinkPreferSystemDriver",
                   ZLStrings.settings_renderer_vulkan_driver_system_title,
                   ZLStrings.settings_renderer_vulkan_driver_system_summary),
            toggle("vsyncInZink",
                   ZLStrings.settings_renderer_vsync_in_zink_title,
                   ZLStrings.settings_renderer_vsync_in_zink_summary),
            toggle("dumpShaders",
                   ZLStrings.settings_renderer_shader_dump_title,
                   ZLStrings.settings_renderer_shader_dump_summary),
        ])
    }

    // MARK: - 游戏设置（11 项）

    /// 给用户看的隔离状态说明：让他知道模组/存档现在落在哪个目录
    private var isolationStatusText: String {
        if VersionRepository.shared.isolationEnabled {
            return "每个版本独立目录：versions/<版本>/ 下的 mods · saves · config"
        } else {
            return "所有版本共用：.minecraft/ 下的 mods · saves · config"
        }
    }

    @ViewBuilder
    private var gameSettings: some View {
        cardGroup(rows: [
            toggle("versionIsolation",
                   ZLStrings.settings_game_version_isolation_title,
                   ZLStrings.settings_game_version_isolation_summary),
            // 动态显示当前隔离规则，让用户知道模组/存档实际落在哪
            ZLSettingRow(key: "versionIsolation.status",
                         title: "当前隔离规则",
                         summary: isolationStatusText,
                         kind: .info(isolationStatusText)),
            toggle("skipGameIntegrityCheck",
                   ZLStrings.settings_game_skip_game_integrity_check_title,
                   ZLStrings.settings_game_skip_game_integrity_check_summary),
            text("versionCustomInfo",
                 ZLStrings.settings_game_version_custom_info_title,
                 ZLStrings.settings_game_version_custom_info_summary,
                 placeholder: ZLStrings.generic_unspecified),
        ])

        cardGroup(rows: [
            text("javaRuntime",
                 ZLStrings.settings_game_java_runtime_title,
                 ZLStrings.settings_game_java_runtime_summary,
                 placeholder: ZLStrings.generic_unspecified),
            toggle("autoPickJavaRuntime",
                   ZLStrings.settings_game_auto_pick_java_runtime_title,
                   ZLStrings.settings_game_auto_pick_java_runtime_summary),
            info("nativeLibPlugins",
                 ZLStrings.settings_game_native_lib_plugin_title,
                 ZLStrings.settings_game_native_lib_plugin_summary,
                 value: ZLStrings.generic_unspecified),
            slider("ramAllocation",
                   ZLStrings.settings_game_java_memory_title,
                   ZLStrings.settings_game_java_memory_summary,
                   unit: "MB",
                   minValue: 256,
                   maxValue: maxMemoryMB),
            text("jvmArgs",
                 ZLStrings.settings_game_jvm_args_title,
                 ZLStrings.settings_game_jvm_args_summary,
                 placeholder: "-Dfile.encoding=UTF-8"),
        ])

        cardGroup(rows: [
            toggle("showLogAutomatic",
                   ZLStrings.settings_game_show_log_automatic_title,
                   ZLStrings.settings_game_show_log_automatic_summary),
            slider("logTextSize",
                   ZLStrings.settings_game_log_text_size_title,
                   ZLStrings.settings_game_log_text_size_summary,
                   unit: "Sp"),
            slider("logBufferFlushInterval",
                   ZLStrings.settings_game_log_buffer_flush_interval_title,
                   ZLStrings.settings_game_log_buffer_flush_interval_summary,
                   unit: "ms"),
        ])
    }

    /// 安卓用 getMaxMemoryForSettings() 取设备可用上限，iOS 这里用物理内存换算
    private var maxMemoryMB: Int {
        max(1024, Int(ProcessInfo.processInfo.physicalMemory / 1024 / 1024))
    }

    // MARK: - 控制设置（29 项）

    @ViewBuilder
    private var controlSettings: some View {
        cardGroup(rows: [
            toggle("physicalMouseMode",
                   ZLStrings.settings_control_mouse_physical_mouse_mode_title,
                   ZLStrings.settings_control_mouse_physical_mouse_mode_summary),
            keyCode("physicalKeyImeCode",
                    ZLStrings.settings_control_physical_key_bind_ime_title,
                    ZLStrings.settings_control_physical_key_bind_ime_summary),
        ])

        cardGroup(rows: [
            hotspot("arrowMouseHotspot",
                    ZLStrings.settings_control_mouse_pointer_arrow_title,
                    ZLStrings.settings_control_mouse_pointer_arrow_summary),
            hotspot("linkMouseHotspot",
                    ZLStrings.settings_control_mouse_pointer_link_title,
                    ZLStrings.settings_control_mouse_pointer_link_summary),
            hotspot("iBeamMouseHotspot",
                    ZLStrings.settings_control_mouse_pointer_ibeam_title,
                    ZLStrings.settings_control_mouse_pointer_ibeam_summary),
            hotspot("crossHairMouseHotspot",
                    ZLStrings.settings_control_mouse_pointer_crosshair_title,
                    ZLStrings.settings_control_mouse_pointer_common_summary),
            hotspot("resizeNSMouseHotspot",
                    ZLStrings.settings_control_mouse_pointer_resize_ns_title,
                    ZLStrings.settings_control_mouse_pointer_resize_ns_summary),
            hotspot("resizeEWMouseHotspot",
                    ZLStrings.settings_control_mouse_pointer_resize_ew_title,
                    ZLStrings.settings_control_mouse_pointer_resize_ew_summary),
            hotspot("resizeAllMouseHotspot",
                    ZLStrings.settings_control_mouse_pointer_resize_all_title,
                    ZLStrings.settings_control_mouse_pointer_common_summary),
            hotspot("notAllowedMouseHotspot",
                    ZLStrings.settings_control_mouse_pointer_not_allowed_title,
                    ZLStrings.settings_control_mouse_pointer_not_allowed_summary),
        ])

        cardGroup(rows: [
            slider("mouseSize",
                   ZLStrings.settings_control_mouse_size_title,
                   nil,
                   unit: "Dp"),
            toggle("hideMouse",
                   ZLStrings.settings_control_mouse_hide_title,
                   ZLStrings.settings_control_mouse_hide_summary),
            toggle("enableMouseClick",
                   ZLStrings.settings_control_mouse_enable_click_title,
                   ZLStrings.settings_control_mouse_enable_click_summary),
            picker("mouseControlMode",
                   ZLStrings.settings_control_mouse_control_mode_title,
                   ZLStrings.settings_control_mouse_control_mode_summary,
                   options: [
                       ZLOption(value: "MouseControlMode.SLIDE", label: ZLStrings.settings_control_mouse_control_mode_slide),
                       ZLOption(value: "MouseControlMode.CLICK", label: ZLStrings.settings_control_mouse_control_mode_click),
                   ]),
            picker("mouseTouchBlockMode",
                   ZLStrings.settings_control_mouse_block_touch_title,
                   ZLStrings.settings_control_mouse_block_touch_summary,
                   options: [
                       ZLOption(value: "MouseTouchBlockMode.NONE", label: ZLStrings.generic_close),
                       ZLOption(value: "MouseTouchBlockMode.LEFT", label: ZLStrings.settings_control_mouse_block_touch_left),
                       ZLOption(value: "MouseTouchBlockMode.RIGHT", label: ZLStrings.settings_control_mouse_block_touch_right),
                   ]),
            slider("cursorSensitivity",
                   ZLStrings.settings_control_mouse_sensitivity_title,
                   ZLStrings.settings_control_mouse_sensitivity_summary,
                   unit: "%"),
            slider("mouseCaptureSensitivity",
                   ZLStrings.settings_control_mouse_capture_sensitivity_title,
                   ZLStrings.settings_control_mouse_capture_sensitivity_summary,
                   unit: "%"),
            slider("mouseLongPressDelay",
                   ZLStrings.settings_control_mouse_long_press_delay_title,
                   ZLStrings.settings_control_mouse_long_press_delay_summary,
                   unit: "ms"),
        ])

        cardGroup(rows: [
            toggle("gestureControl",
                   ZLStrings.settings_control_gesture_control_title,
                   ZLStrings.settings_control_gesture_control_summary),
            picker("gestureTapMouseAction",
                   ZLStrings.settings_control_gesture_tap_action_title,
                   ZLStrings.settings_control_gesture_tap_action_summary,
                   options: gestureActionOptions),
            picker("gestureLongPressMouseAction",
                   ZLStrings.settings_control_gesture_long_press_action_title,
                   ZLStrings.settings_control_gesture_long_press_action_summary,
                   options: gestureActionOptions),
            slider("gestureLongPressDelay",
                   ZLStrings.settings_control_gesture_long_press_delay_title,
                   ZLStrings.settings_control_mouse_long_press_delay_summary,
                   unit: "ms"),
        ])

        cardGroup(rows: [
            toggle("gyroscopeControl",
                   ZLStrings.settings_control_gyroscope_title,
                   ZLStrings.settings_control_gyroscope_summary),
            slider("gyroscopeSensitivity",
                   ZLStrings.settings_control_gyroscope_sensitivity_title,
                   nil,
                   unit: "%"),
            slider("gyroscopeSampleRate",
                   ZLStrings.settings_control_gyroscope_sample_rate_title,
                   ZLStrings.settings_control_gyroscope_sample_rate_summary,
                   unit: "ms"),
            toggle("gyroscopeSmoothing",
                   ZLStrings.settings_control_gyroscope_smoothing_title,
                   ZLStrings.settings_control_gyroscope_smoothing_summary),
            slider("gyroscopeSmoothingWindow",
                   ZLStrings.settings_control_gyroscope_smoothing_window_title,
                   ZLStrings.settings_control_gyroscope_smoothing_window_summary,
                   unit: ""),
            toggle("gyroscopeInvertX",
                   ZLStrings.settings_control_gyroscope_invert_x_title,
                   ZLStrings.settings_control_gyroscope_invert_x_summary),
            toggle("gyroscopeInvertY",
                   ZLStrings.settings_control_gyroscope_invert_y_title,
                   ZLStrings.settings_control_gyroscope_invert_y_summary),
        ])
    }

    private var gestureActionOptions: [ZLOption] {
        [
            ZLOption(value: "GestureActionType.MOUSE_LEFT", label: ZLStrings.settings_control_gesture_trigger_mouse_left),
            ZLOption(value: "GestureActionType.MOUSE_RIGHT", label: ZLStrings.settings_control_gesture_trigger_mouse_right),
        ]
    }

    // MARK: - 手柄设置（10 项；页面上展示 7 项 + 映射配置）

    @ViewBuilder
    private var gamepadSettings: some View {
        cardGroup(rows: [
            toggle("gamepadControl",
                   ZLStrings.settings_gamepad_title,
                   ZLStrings.settings_gamepad_summary),
            picker("gamepadInputMode",
                   ZLStrings.settings_gamepad_input_mode_title,
                   nil,
                   options: [
                       ZLOption(value: "GamepadInputMode.Mapped", label: ZLStrings.settings_gamepad_input_mode_mapped),
                       ZLOption(value: "GamepadInputMode.SdlDirect", label: ZLStrings.settings_gamepad_input_mode_sdl),
                   ]),
        ])

        cardGroup(rows: [
            slider("gamepadDeadZoneScale",
                   ZLStrings.settings_gamepad_deadzone_title,
                   ZLStrings.settings_gamepad_deadzone_summary,
                   unit: "%"),
            slider("gamepadCursorSensitivity",
                   ZLStrings.settings_gamepad_cursor_sensitivity_title,
                   ZLStrings.settings_gamepad_cursor_sensitivity_summary,
                   unit: "%"),
            slider("gamepadCameraSensitivity",
                   ZLStrings.settings_gamepad_camera_sensitivity_title,
                   ZLStrings.settings_gamepad_camera_sensitivity_summary,
                   unit: "%"),
            picker("joystickControlMode",
                   ZLStrings.settings_gamepad_joystick_mode_title,
                   ZLStrings.settings_gamepad_joystick_mode_summary,
                   options: [
                       ZLOption(value: "JoystickMode.LeftMovement", label: ZLStrings.settings_gamepad_joystick_mode_left),
                       ZLOption(value: "JoystickMode.RightMovement", label: ZLStrings.settings_gamepad_joystick_mode_right),
                   ]),
        ])

        cardGroup(rows: [
            info("gamepadMappingConfig",
                 ZLStrings.settings_gamepad_config_title,
                 ZLStrings.settings_gamepad_config_summary,
                 value: mappingConfigValue),
        ])
    }

    /// 手柄映射配置名（iOS 端尚未接入配置管理，只展示当前值）
    private var mappingConfigValue: String {
        guard let def = ZLSettings.def("gamepadMappingConfig") else { return "default" }
        let value = store.string(def)
        return value.isEmpty ? "default" : value
    }

    // MARK: - 启动器设置（14 项 + 背景/动画）

    @ViewBuilder
    private var launcherSettings: some View {
        themeCard

        cardGroup(rows: [
            // 视觉特效总开关：毛玻璃 / 扫光 / 倾斜高光都受它控制
            toggle(ZLGlassPerf.key,
                   "关闭视觉特效（省电、提帧）",
                   "关掉毛玻璃模糊、卡片扫光和倾斜高光。游戏卡或发热时打开这个"),
            darkMode("launcherDarkMode",
                     ZLStrings.settings_launcher_dark_mode_title,
                     nil),
            picker("launcherLanguage",
                   ZLStrings.settings_launcher_language,
                   nil,
                   options: languageOptions),
            toggle("launcherFestivalEffects",
                   ZLStrings.settings_launcher_festivals_effects_title,
                   ZLStrings.settings_launcher_festivals_effects_summary),
            toggle("launcherFullScreen",
                   ZLStrings.settings_launcher_full_screen_title,
                   ZLStrings.settings_launcher_full_screen_summary),
        ])

        backgroundCard

        cardGroup(rows: [
            slider("launcherBackgroundOpacity",
                   ZLStrings.settings_launcher_background_opacity_title,
                   ZLStrings.settings_launcher_background_opacity_summary,
                   unit: "%"),
            slider("videoBackgroundVolume",
                   ZLStrings.settings_launcher_background_video_volume_title,
                   ZLStrings.settings_launcher_background_video_volume_summary,
                   unit: "%"),
            blur("backgroundBlur",
                  ZLStrings.settings_title_blur,
                  ZLStrings.settings_launcher_background_blur_summary),
        ])

        cardGroup(rows: [
            toggle("launcherSwapAnimEnabled",
                   ZLStrings.settings_launcher_swap_anim_enabled_title,
                   ZLStrings.settings_launcher_swap_anim_enabled_summary),
            animateSpeed("launcherAnimateSpeedLevel",
                         ZLStrings.settings_launcher_animate_speed_title,
                         ZLStrings.settings_launcher_animate_speed_summary),
        ])

        cardGroup(rows: [
            picker("gameDownloadSource",
                   ZLStrings.settings_launcher_mirror_game_source_title,
                   nil,
                   options: mirrorOptions),
            picker("assetPlatformSource",
                   ZLStrings.settings_launcher_mirror_asset_platform_source_title,
                   nil,
                   options: mirrorOptions),
            slider("launcherLogRetentionDays",
                   ZLStrings.settings_launcher_log_retention_days_title,
                   ZLStrings.settings_launcher_log_retention_days_summary,
                   unit: ZLStrings.unit_day),
        ])
    }

    private var mirrorOptions: [ZLOption] {
        [
            ZLOption(value: "MirrorSourceType.AUTO", label: ZLStrings.settings_launcher_mirror_auto),
            ZLOption(value: "MirrorSourceType.OFFICIAL", label: ZLStrings.settings_launcher_mirror_official),
            ZLOption(value: "MirrorSourceType.MIRROR", label: ZLStrings.settings_launcher_mirror_mirror),
        ]
    }

    /// 语言名取自 values/strings.xml 里 translatable="false" 的原文
    private var languageOptions: [ZLOption] {
        [
            ZLOption(value: "AppLanguage.FOLLOW_SYSTEM", label: ZLStrings.generic_follow_system),
            ZLOption(value: "AppLanguage.ARABIC", label: "اَلْعَرَبِيَّةُ"),
            ZLOption(value: "AppLanguage.ENGLISH", label: "English"),
            ZLOption(value: "AppLanguage.SPANISH", label: "Español"),
            ZLOption(value: "AppLanguage.FILIPINO", label: "Filipino"),
            ZLOption(value: "AppLanguage.INDONESIAN", label: "Indonesia"),
            ZLOption(value: "AppLanguage.ITALIAN", label: "Italiano"),
            ZLOption(value: "AppLanguage.JAPANESE", label: "日本語"),
            ZLOption(value: "AppLanguage.KOREAN", label: "한국어"),
            ZLOption(value: "AppLanguage.PORTUGUESE", label: "Português"),
            ZLOption(value: "AppLanguage.BRAZILIAN_PORTUGUESE", label: "Português (Brasil)"),
            ZLOption(value: "AppLanguage.RUSSIAN", label: "Русский"),
            ZLOption(value: "AppLanguage.THAI", label: "ไทย"),
            ZLOption(value: "AppLanguage.TURKISH", label: "Türkçe"),
            ZLOption(value: "AppLanguage.UYGHUR", label: "ۋىغرۇچە"),
            ZLOption(value: "AppLanguage.VIETNAMESE", label: "Tiếng Việt"),
            ZLOption(value: "AppLanguage.SIMPLIFIED_CHINESE", label: "简体中文"),
            ZLOption(value: "AppLanguage.TRADITIONAL_CHINESE", label: "繁體中文"),
        ]
    }

    // MARK: 启动器背景（launcherBackground*；iOS 端暂未接入背景导入）

    private var backgroundCard: some View {
        ZLCard {
            HStack(alignment: .center, spacing: 12) {
                labelBlock(ZLStrings.settings_launcher_background_title,
                           ZLStrings.settings_launcher_background_summary)
                Spacer(minLength: 8)
                Text(ZLStrings.generic_unspecified)
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond)
            }
        }
    }

    // MARK: 颜色主题卡片（launcherColorTheme / launcherCustomColor / launcherCustomPaletteStyle）

    private var themeCard: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 14) {
                labelBlock(ZLStrings.settings_launcher_color_theme_title,
                           ZLStrings.settings_launcher_color_theme_summary)

                HStack(spacing: 14) {
                    ForEach(ZLColorTheme.allCases) { t in
                        Button {
                            themeManager.themeName = t.rawValue
                            if let def = ZLSettings.def("launcherColorTheme") {
                                store.set(def, colorThemeValue(t))
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(t.primary)
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Circle().stroke(themeManager.theme == t ? ZLTheme.textPrimary : .clear,
                                                        lineWidth: 2)
                                    )
                                Text(t.displayName)
                                    .font(.system(size: 10))
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

    private func colorThemeValue(_ theme: ZLColorTheme) -> String {
        switch theme {
        case .embermire: return "ColorThemeType.EMBERMIRE"
        case .velvetRose: return "ColorThemeType.VELVET_ROSE"
        case .mistwave: return "ColorThemeType.MISTWAVE"
        case .glacier: return "ColorThemeType.GLACIER"
        case .verdantField: return "ColorThemeType.VERDANTFIELD"
        case .urbanAsh: return "ColorThemeType.URBAN_ASH"
        case .verdantDawn: return "ColorThemeType.VERDANT_DAWN"
        }
    }

    /// 安卓的深色模式是 Enable / Disable / FollowSystem 三态
    private func syncThemeSettings() {
        if let def = ZLSettings.def("launcherDarkMode") {
            themeManager.darkMode = store.string(def) == "DarkMode.Enable"
        }
    }

    // MARK: - 行构造

    /// 给无效项打上「置灰 + 原因」，避免用户以为调了有用
    private func decorate(_ row: ZLSettingRow) -> ZLSettingRow {
        guard ZLUnsupportedSettings.isUnsupported(row.key) else { return row }
        var r = row
        r.disabled = true
        r.note = ZLUnsupportedSettings.note(for: row.key)
        return r
    }

    /// 兼容旧调用点
    private func markUnsupported(_ key: String, _ title: String) -> String {
        ZLUnsupportedSettings.isUnsupported(key) ? title + "（当前版本暂不支持）" : title
    }

    private func toggle(_ key: String, _ title: String, _ summary: String?) -> ZLSettingRow {
        decorate(ZLSettingRow(key: key, title: markUnsupported(key, title), summary: summary, kind: .toggle))
    }

    private func slider(_ key: String, _ title: String, _ summary: String?,
                        unit: String, minValue: Int? = nil, maxValue: Int? = nil) -> ZLSettingRow {
        decorate(ZLSettingRow(key: key, title: markUnsupported(key, title), summary: summary,
                              kind: .slider(unit: unit, minValue: minValue, maxValue: maxValue)))
    }

    private func picker(_ key: String, _ title: String, _ summary: String?,
                        options: [ZLOption]) -> ZLSettingRow {
        decorate(ZLSettingRow(key: key, title: markUnsupported(key, title), summary: summary, kind: .picker(options)))
    }

    private func text(_ key: String, _ title: String, _ summary: String?,
                      placeholder: String) -> ZLSettingRow {
        decorate(ZLSettingRow(key: key, title: markUnsupported(key, title), summary: summary, kind: .text(placeholder: placeholder)))
    }

    private func number(_ key: String, _ title: String, _ summary: String?,
                        placeholder: String) -> ZLSettingRow {
        ZLSettingRow(key: key, title: title, summary: summary, kind: .number(placeholder: placeholder))
    }

    private func info(_ key: String, _ title: String, _ summary: String?, value: String) -> ZLSettingRow {
        ZLSettingRow(key: key, title: title, summary: summary, kind: .info(value))
    }

    private func hotspot(_ key: String, _ title: String, _ summary: String?) -> ZLSettingRow {
        ZLSettingRow(key: key, title: title, summary: summary, kind: .hotspot)
    }

    private func keyCode(_ key: String, _ title: String, _ summary: String?) -> ZLSettingRow {
        ZLSettingRow(key: key, title: title, summary: summary, kind: .keyCode)
    }

    private func blur(_ key: String, _ title: String, _ summary: String?) -> ZLSettingRow {
        ZLSettingRow(key: key, title: markUnsupported(key, title), summary: summary, kind: .blur)
    }

    private func animateSpeed(_ key: String, _ title: String, _ summary: String?) -> ZLSettingRow {
        ZLSettingRow(key: key, title: markUnsupported(key, title), summary: summary, kind: .animateSpeed)
    }

    private func darkMode(_ key: String, _ title: String, _ summary: String?) -> ZLSettingRow {
        ZLSettingRow(key: key, title: title, summary: summary, kind: .darkMode)
    }

    // MARK: - 卡片渲染

    @ViewBuilder
    private func cardGroup(rows: [ZLSettingRow]) -> some View {
        ZLCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { i in
                    rowView(rows[i])
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                    if i < rows.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: ZLSettingRow) -> some View {
        // iOS 上无效的设置项：整个控件禁用 + 变灰 + 显示原因
        // 用 disabled 包住而不是隐藏，让用户知道「有这一项，但这里用不了」
        Group {
            if row.disabled {
                rowContent(row)
                    .disabled(true)
                    .opacity(0.45)
                    .overlay(alignment: .leading) {
                        // 盖一层透明视图吃掉所有点击，防止滑块/开关仍能拖动
                        Color.white.opacity(0.001)
                            .allowsHitTesting(true)
                            .onTapGesture {
                                toastText = row.note ?? "此设置在当前平台不可用"
                            }
                    }
            } else {
                rowContent(row)
            }
        }
    }

    @ViewBuilder
    private func rowContent(_ row: ZLSettingRow) -> some View {
        if let def = row.def {
            VStack(alignment: .leading, spacing: 6) {
                rowBody(row, def: def)
                if let note = row.note {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(ZLTheme.warning)
                }
            }
        }
    }

    @ViewBuilder
    private func rowBody(_ row: ZLSettingRow, def: ZLSettingDef) -> some View {
        switch row.kind {
        case .toggle:
            HStack(alignment: .center, spacing: 12) {
                labelBlock(row.title, row.summary)
                Spacer(minLength: 8)
                Toggle("", isOn: Binding(
                    get: { store.bool(def) },
                    set: { store.set(def, $0) }
                ))
                .labelsHidden()
                .tint(ZLTheme.primary)
            }

        case .slider(let unit, let minValue, let maxValue):
            sliderRow(def, row, unit: unit, minValue: minValue, maxValue: maxValue)

        case .picker(let options):
            HStack(alignment: .center, spacing: 12) {
                labelBlock(row.title, row.summary)
                Spacer(minLength: 8)
                pickerMenu(def, options: options)
            }

        case .text(let placeholder):
            VStack(alignment: .leading, spacing: 8) {
                labelBlock(row.title, row.summary)
                textField(def, placeholder: placeholder, numeric: false)
            }

        case .number(let placeholder):
            VStack(alignment: .leading, spacing: 8) {
                labelBlock(row.title, row.summary)
                textField(def, placeholder: placeholder, numeric: true)
            }

        case .info(let value):
            HStack(alignment: .center, spacing: 12) {
                labelBlock(row.title, row.summary)
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond)
                    .lineLimit(1)
            }

        default:
            legacyRowBody(row, def: def)
        }
    }

    @ViewBuilder
    private func legacyRowBody(_ row: ZLSettingRow, def: ZLSettingDef) -> some View {
        switch row.kind {
            case .hotspot:
                HStack(alignment: .center, spacing: 12) {
                    labelBlock(row.title, row.summary)
                    Spacer(minLength: 8)
                    Button {
                        hotspotTarget = def
                    } label: {
                        Text(ZLStrings.settings_control_mouse_pointer_hotspot)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ZLTheme.primaryDeep)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(ZLTheme.primarySoft)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

            case .keyCode:
                HStack(alignment: .center, spacing: 12) {
                    labelBlock(row.title, row.summary)
                    Spacer(minLength: 8)
                    Text(keyCodeText(def))
                        .font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                    Button {
                        store.reset(def)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ZLTheme.textSecond)
                    }
                    .buttonStyle(.plain)
                }

            case .blur:
                blurRow(def, row)

            case .animateSpeed:
                animateSpeedRow(def, row)

            case .darkMode:
                HStack(alignment: .center, spacing: 12) {
                    labelBlock(row.title, row.summary)
                    Spacer(minLength: 8)
                    pickerMenu(def, options: [
                        ZLOption(value: "DarkMode.Enable", label: ZLStrings.generic_enable),
                        ZLOption(value: "DarkMode.Disable", label: ZLStrings.generic_disable),
                        ZLOption(value: "DarkMode.FollowSystem", label: ZLStrings.generic_follow_system),
                    ], onChange: { value in
                        themeManager.darkMode = (value == "DarkMode.Enable")
                    })
                }
        }
    }

    @ViewBuilder
    private func labelBlock(_ title: String, _ summary: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let summary {
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func sliderRow(_ def: ZLSettingDef, _ row: ZLSettingRow,
                           unit: String, minValue: Int?, maxValue: Int?) -> some View {
        let lower = minValue ?? def.range?.lowerBound ?? 0
        let upper = max(maxValue ?? def.range?.upperBound ?? 100, lower + 1)
        let raw = store.int(def)
        let current = min(max(raw, lower), upper)

        VStack(alignment: .leading, spacing: 8) {
            labelBlock(row.title, row.summary)
            HStack(spacing: 12) {
                Slider(value: Binding(
                    get: { Double(min(max(store.int(def), lower), upper)) },
                    set: { store.set(def, Int($0.rounded())) }
                ), in: Double(lower)...Double(upper), step: 1)
                .tint(ZLTheme.primary)

                Text("\(current)\(unit)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ZLTheme.primaryDeep)
                    .frame(minWidth: 52, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private func pickerMenu(_ def: ZLSettingDef, options: [ZLOption],
                            onChange: ((String) -> Void)? = nil) -> some View {
        let current = store.string(def)
        let label = options.first(where: { $0.value == current })?.label
            ?? (current.isEmpty ? ZLStrings.generic_unspecified : current)

        Menu {
            ForEach(options) { option in
                Button {
                    store.set(def, option.value)
                    onChange?(option.value)
                } label: {
                    if option.value == current {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(ZLTheme.primaryDeep)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(ZLTheme.primarySoft)
            .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func textField(_ def: ZLSettingDef, placeholder: String, numeric: Bool) -> some View {
        TextField(placeholder, text: Binding(
            get: { store.string(def) },
            set: { v in
                if numeric {
                    // 数字项必须存成 Int，否则 CoreBridge 用 as? Int 读不到（分辨率就是这么失效的）
                    let digits = v.filter { $0.isNumber || $0 == "-" }
                    store.set(def, Int(digits) ?? 0)
                } else {
                    store.set(def, v)
                }
            }
        ))
        .textFieldStyle(.plain)
        .font(.system(size: 12, design: numeric ? .monospaced : .default))
        .keyboardType(numeric ? .numberPad : .default)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(ZLTheme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func keyCodeText(_ def: ZLSettingDef) -> String {
        guard let code = store.intOrNil(def) else {
            return ZLStrings.settings_control_physical_key_bind_ime_un_bind
        }
        return ZLStrings.settings_control_physical_key_bind_ime_bound
            .replacingOccurrences(of: "%s", with: "\(code)")
    }

    @ViewBuilder
    private func blurRow(_ def: ZLSettingDef, _ row: ZLSettingRow) -> some View {
        let lower = def.range?.lowerBound ?? 0
        let upper = def.range?.upperBound ?? 40
        let current = min(max(store.int(def), lower), upper)
        let typeDef = ZLSettings.def("backgroundBlurType")
        let isForeground = typeDef.map { store.string($0) == "BackgroundBlur.Foreground" } ?? false

        VStack(alignment: .leading, spacing: 8) {
            labelBlock(row.title, row.summary)
            HStack(spacing: 12) {
                Slider(value: Binding(
                    get: { Double(min(max(store.int(def), lower), upper)) },
                    set: { store.set(def, Int($0.rounded())) }
                ), in: Double(lower)...Double(upper), step: 1)
                .tint(ZLTheme.primary)

                Text("\(current)Dp")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ZLTheme.primaryDeep)
                    .frame(minWidth: 52, alignment: .trailing)

                if let typeDef {
                    Button {
                        store.set(typeDef, isForeground ? "BackgroundBlur.Background" : "BackgroundBlur.Foreground")
                    } label: {
                        Image(systemName: isForeground ? "circle.fill" : "circle.dashed")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ZLTheme.primaryDeep)
                            .frame(width: 30, height: 30)
                            .background(ZLTheme.primarySoft)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(ZLStrings.settings_title_blur)
                }
            }
        }
    }

    @ViewBuilder
    private func animateSpeedRow(_ def: ZLSettingDef, _ row: ZLSettingRow) -> some View {
        let lower = def.range?.lowerBound ?? 1
        let upper = def.range?.upperBound ?? 30
        let current = min(max(store.int(def), lower), upper)

        VStack(alignment: .leading, spacing: 8) {
            labelBlock(row.title, row.summary)
            HStack(spacing: 12) {
                Slider(value: Binding(
                    get: { Double(min(max(store.int(def), lower), upper)) },
                    set: { store.set(def, Int($0.rounded())) }
                ), in: Double(lower)...Double(upper), step: 1)
                .tint(ZLTheme.primary)

                // 安卓 valueText = "×" + value / 10f
                Text(String(format: "×%.1f", Double(current) / 10.0))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ZLTheme.primaryDeep)
                    .frame(minWidth: 52, alignment: .trailing)
            }
        }
    }
}

// MARK: - 鼠标热点编辑器（安卓：设置热点 → X/Y 百分比）

private struct ZLHotspotEditor: View {
    let def: ZLSettingDef
    @ObservedObject var store: ZLSettingsStore

    @Environment(\.dismiss) private var dismiss

    @State private var x: Double
    @State private var y: Double

    init(def: ZLSettingDef, store: ZLSettingsStore) {
        self.def = def
        _store = ObservedObject(wrappedValue: store)
        let point = ZLSettingsStore.parsePoint(store.string(def))
        _x = State(initialValue: Double(point.0))
        _y = State(initialValue: Double(point.1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(ZLStrings.settings_control_mouse_pointer_hotspot)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ZLTheme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text("\(ZLStrings.settings_control_mouse_pointer_hotspot_x_percent)：\(Int(x))%")
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond)
                Slider(value: $x, in: 0...100, step: 1)
                    .tint(ZLTheme.primary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("\(ZLStrings.settings_control_mouse_pointer_hotspot_y_percent)：\(Int(y))%")
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond)
                Slider(value: $y, in: 0...100, step: 1)
                    .tint(ZLTheme.primary)
            }

            HStack(spacing: 12) {
                Button(ZLStrings.generic_reset) {
                    let point = ZLSettingsStore.parsePoint(def.defaultValue)
                    x = Double(point.0)
                    y = Double(point.1)
                    store.set(def, "\(Int(x)),\(Int(y))")
                }
                .buttonStyle(.plain)
                .foregroundStyle(ZLTheme.textSecond)

                Spacer()

                Button(ZLStrings.generic_save) {
                    store.set(def, "\(Int(x)),\(Int(y))")
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ZLTheme.textOnGold)
                .padding(.horizontal, 22)
                .frame(height: 40)
                .background(ZLTheme.primary)
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .presentationDetents([.medium])
        .background(ZLTheme.background.ignoresSafeArea())
    }
}


// MARK: - 当前版本还没接进核心的设置项
//
// 设置页把 ZL2 安卓版的 115 项全部列了出来，但 iOS 上真正能生效的只有一部分。
// 这个枚举负责告诉 UI：「这一项现在调了没用，请置灰并加说明」。
//
// 分成三类：
//   1. platformOnly  —— 安卓专有能力，iOS 根本不存在（陀螺仪热区、悬浮球……）
//   2. notWired      —— iOS 应该支持，但核心还没接线（FPS 显示、版本隔离……）
//   3. 其余          —— 真正生效的，不在此列
//
// 判定依据见 docs/设置项审计.md
enum ZLUnsupportedSettings {

    /// 安卓专属能力，iOS 系统层面就没有对应 API，未来也不会有
    static let platformOnly: Set<String> = [
        // 陀螺仪：iOS 游戏内没有接 CoreMotion，且安卓的实现也不适用于 Metal 渲染管线
        "gyroscopeControl", "gyroscopeInvertX", "gyroscopeInvertY",
        "gyroscopeSampleRate", "gyroscopeSensitivity",
        "gyroscopeSmoothing", "gyroscopeSmoothingWindow",

        // 手柄：安卓走 SDL 直通，iOS 需要单独接 GameController.framework
        "gamepadControl", "gamepadCameraSensitivity", "gamepadCursorSensitivity",
        "gamepadDeadZoneScale", "gamepadInputMode", "gamepadInputModePrompted",
        "gamepadMappingConfig",

        // 鼠标热区：安卓 SurfaceView 的触摸判定区域，iOS 用 UIKit 手势，概念不同
        "arrowMouseHotspot", "crossHairMouseHotspot", "iBeamMouseHotspot",
        "linkMouseHotspot", "notAllowedMouseHotspot",
        "resizeAllMouseHotspot", "resizeEWMouseHotspot", "resizeNSMouseHotspot",

        // 物理键盘/鼠标：安卓 IME 那一套，iOS 走软键盘 + 外接键盘事件
        "physicalKeyImeCode", "physicalMouseMode",
        "sdlAutoShowIme", "imeMagnifierAutoShow",

        // 悬浮球位置与透明度：这里是 App 内部视图（不是系统悬浮窗），iOS 可用。
        // 已从 platformOnly 移出，实现在 GameOverlay 里。
        // showMenuBall / menuBallOpacity / menuBallPos 均可用。

        // 启动器外观：iOS 跟随系统外观，不做 Material3 自定义主题
        "launcherActionMenuSide", "launcherCustomColor",
        "launcherCustomPaletteStyle", "launcherDarkMode",
        "launcherTaskMenuExpanded",

        // 触控热键栏：安卓专属的屏幕下方快捷键条
        "hotbarDoubleClick", "hotbarHeight", "hotbarLongClick",
        "hotbarLongClickDelay", "hotbarRule", "hotbarWidth",

        // 搜索平台：iOS 版统一走 Modrinth，不做多平台切换
        "searchModpackPlatform", "searchModPlatform",
        "searchResourcePackPlatform", "searchShadersPlatform",

        // 其余触控/鼠标细分项
        "mouseSize", "mouseTouchBlockMode", "controlsOpacity",
        "cursorSensitivity", "mouseCaptureSensitivity", "mouseControlMode",
        "mouseLongPressDelay", "gestureControl", "gestureLongPressDelay",
        "gestureLongPressMouseAction", "gestureTapMouseAction",
        "joystickControlMode", "requestMaxRefreshRate",
        "showSponsorship", "hideMouse", "enableMouseClick",
    ]

    /// iOS 应该支持，但核心还没接线 —— 属于待办，不是永久不支持
    static let notWired: Set<String> = [
        // controlLayout 已实现（CoreLayoutExporter + CoreBridge.syncControlLayoutIfNeeded）
        "enableTerracotta",       // Terracotta 联机（需要 Network Extension）
        "enableTerracottaNodes",
        "terracottaNodes",
        // versionIsolation 从「已接线」移出来了，原因见下：
        // 核心 JavaLauncher.m:179-182 自己拼游戏目录，**完全忽略 GAME_DIR 环境变量**
        // （那个变量只在 launchJar 分支用）。所以靠 setenv("GAME_DIR", 隔离目录)
        // 根本改不到游戏真正用的目录，隔离形同虚设。
        // 而且不能把核心的 gameDir 指到 versions/<id> —— 那样它会去找
        // versions/<id>/versions/<id>/<id>.json，连版本本身都找不到。
        // 与其让 UI 显示一个"已开启"但实际无效的开关，不如如实标注。
        "versionIsolation",
        // 已接线，不要再加回：
        //   currentAccount   → AccountStore.persist() 写同步
        //   currentGamePathId → GameDirectoryStore.activate() 写同步
        //   finishedGame     → CoreBridge.recordGameLaunch()
        //   editorEnableWidgetSnap / editorSnapInAllLayers / editorWidgetSnapMode
        //                    → ControlEditor.applySnap()
        //   controlLayout    → CoreLayoutExporter
        //   showFPS / showMemory / fpsDisplayMode → ZL2PerfSampler
    ]

    /// 安卓渲染/启动相关，iOS 的图形栈完全不同
    private static let renderOnly: Set<String> = [
        "sfpewPluginLayer", "sfpewRelaxedContext", "vulkanDriver", "graphicsApi",
        "gameFullScreen", "sustainedPerformance", "zinkPreferSystemDriver",
        "vsyncInZink", "dumpShaders", "skipGameIntegrityCheck", "versionCustomInfo",
        "nativeLibPlugins", "logBufferFlushInterval", "assetPlatformSource",
    ]

    /// 启动器外观类（安卓 Material3 特有）
    private static let launcherLook: Set<String> = [
        "launcherFestivalEffects", "launcherFullScreen", "launcherSwapAnimEnabled",
        "launcherAnimateSpeedLevel", "launcherBackgroundOpacity",
        "videoBackgroundVolume", "backgroundBlur", "backgroundBlurType",
        "launcherLanguage", "launcherColorTheme",
    ]

    /// 全部「调了没用」的 key
    static let keys: Set<String> =
        platformOnly
            .union(notWired)
            .union(renderOnly)
            .union(launcherLook)

    static func isUnsupported(_ key: String) -> Bool { keys.contains(key) }

    /// 给 UI 用的说明文案；nil 表示这一项是可用的
    static func note(for key: String) -> String? {
        if platformOnly.contains(key) {
            return "iOS 不支持此能力"
        }
        if renderOnly.contains(key) {
            return "iOS 使用 Metal 渲染，此项不适用"
        }
        if launcherLook.contains(key) {
            return "iOS 版界面跟随系统外观"
        }
        if key == "versionIsolation" {
            return "iOS 核心启动时会自己算游戏目录，用的是固定的「实例/.minecraft」；" +
                   "按版本隔离需要改这个目录，改了版本本身又找不到，所以暂时无效。"
        }
        if notWired.contains(key) {
            return "尚未接入，暂时无效"
        }
        return nil
    }
}
