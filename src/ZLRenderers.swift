//
//  ZLRenderers.swift
//  CraftLauncher
//
//  渲染器可用性探测。
//
//  为什么需要这个文件：
//  核心的 pojavInitOpenGL() 会从 RENDERER 环境变量取库名，然后直接
//  dlopen("@rpath/<名字>")。如果那个名字对应的 .dylib 不在包里，
//  启动游戏就是一个黑屏或崩溃。核心侧有兜底（egl_bridge.m 的
//  zl2_renderer_available），但它只兜「文件不存在」这一种情况；
//  设置界面原本是个自由输入框，用户随手打一个 OpenGL / angle 进去，
//  存的就是一个永远无法解析的名字。
//
//  所以在 Swift 侧做一件事：把「包里真实存在哪些渲染器」算出来，
//  设置页只让用户从这份清单里选，不给自由输入的机会。
//

import Foundation

/// 一个可选的渲染后端
struct ZLRendererOption: Identifiable, Equatable {
    /// 写进 UserDefaults 的值，必须与核心的 RENDERER 宏完全一致
    let key: String
    /// 界面上给用户看的名字
    let title: String
    /// 一句话说明这个后端是干什么的
    let detail: String

    var id: String { key }
}

enum ZLRenderers {

    // 与 core/utils.h 的宏保持一一对应。改这里之前先去看那个头文件。
    static let gl4es   = "libgl4es_114.dylib"
    static let angle   = "libtinygl4angle.dylib"
    static let osmosa  = "libOSMesa.8.dylib"
    static let moltenvk = "libMoltenVK.dylib"
    /// 核心声明过但从未随包构建的库。保留常量只为了能识别并拦截旧配置里的残留值。
    static let mobileglues = "libmobileglues.dylib"

    /// Frameworks 目录
    static var frameworksPath: String {
        Bundle.main.bundlePath + "/Frameworks"
    }

    static func exists(_ lib: String) -> Bool {
        FileManager.default.fileExists(atPath: frameworksPath + "/" + lib)
    }

    /// 包内实际可用的渲染后端（不含 auto）。
    /// 顺序即界面上展示的顺序：越靠前越推荐。
    static func availableOptions() -> [ZLRendererOption] {
        var list: [ZLRendererOption] = []

        // GL4ES 是最后的安全网：只要它在，任何 OpenGL 版本都能起得来。
        if exists(gl4es) {
            list.append(ZLRendererOption(
                key: gl4es,
                title: "GL4ES（兼容优先）",
                detail: "把 OpenGL 翻译成 OpenGL ES。兼容性最好，速度一般，出问题先用它。"
            ))
        }
        if exists(angle) {
            list.append(ZLRendererOption(
                key: angle,
                title: "ANGLE（Metal 直通）",
                detail: "走 Metal 后端，iOS 上通常最快，支持 OpenGL 3.2+。推荐大多数设备使用。"
            ))
        }
        if exists(osmosa) {
            list.append(ZLRendererOption(
                key: osmosa,
                title: "Zink / OSMesa",
                detail: "用 MoltenVK 走 Vulkan 转译路线。部分光影和模组用它更稳，但更吃性能。"
            ))
        }
        return list
    }

    /// 包内可用的渲染器 key 列表，用于校验
    static func availableKeys() -> [String] {
        availableOptions().map { $0.key }
    }

    /// 把一个用户存过的值规整成「一定能被 dlopen 到」的名字。
    ///
    /// 处理四种情况：
    ///   1) 空 / auto          → "auto"，交给核心按 OpenGL 版本自己挑
    ///   2) 在包里真实存在     → 原样返回
    ///   3) 不在包里（如 MobileGlues 残留）→ 回落到 ANGLE，没有 ANGLE 就 GL4ES
    ///   4) 完全看不懂的字符串 → 同上回落
    ///
    /// - Parameter raw: UserDefaults 里存的值
    /// - Returns: 可以直接写进 RENDERER 环境变量的值
    static func sanitize(_ raw: String?) -> String {
        let v = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if v.isEmpty || v.lowercased() == "auto" { return "auto" }
        if exists(v) { return v }
        // 用户可能只写了个短名（"gl4es" / "angle" / "zink"），做一次宽容匹配
        let lower = v.lowercased()
        if lower.contains("gl4es"), exists(gl4es) { return gl4es }
        if lower.contains("angle") || lower.contains("tinygl"), exists(angle) { return angle }
        if lower.contains("mesa") || lower.contains("zink"), exists(osmosa) { return osmosa }
        // 真的认不出来：回落到最稳的那个
        return fallbackKey()
    }

    /// 兜底后端：优先 ANGLE（快），没有就 GL4ES（稳）
    static func fallbackKey() -> String {
        if exists(angle) { return angle }
        if exists(gl4es) { return gl4es }
        // 两个都没有说明 IPA 是坏的，仍然返回一个明确的名字让核心报错更清楚
        return gl4es
    }

    /// 给渲染器 key 一个人类可读的名字（日志用）
    static func displayName(for key: String) -> String {
        switch key {
        case "auto": return "自动"
        case gl4es: return "GL4ES"
        case angle: return "ANGLE"
        case osmosa: return "Zink/OSMesa"
        case mobileglues: return "MobileGlues"
        default: return key
        }
    }

    /// 设置页下拉选项的 (值, 显示名) 列表：自动 + 每个真实可用的后端。
    /// 这里刻意不返回 SettingsScreen 里的 ZLOption —— 那个类型是 private，
    /// 跨文件引用不了，而且塞一个假选项进下拉框正是要避免的事。
    static func pickerPairs() -> [(value: String, label: String)] {
        var list: [(value: String, label: String)] = [("auto", "自动（推荐）")]
        for o in availableOptions() {
            list.append((o.key, o.title))
        }
        return list
    }
}
