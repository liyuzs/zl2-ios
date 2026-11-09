//
//  GLFWKeyNames.swift
//  ZL2-iOS · GLFW 按键名 ↔ 键码
//
//  ────────────────────────────────────────────────────────────
//  为什么需要这个：
//
//  编辑器把按键事件存成字符串，形如 "GLFW_KEY_ESCAPE"
//  （见 ControlEditor.swift 的 ControlItem.keyEvent 注释）。
//
//  核心（Pojav / Amethyst 的 ControlButton）要的是整数 keycodes。
//  两者之间必须有一张名称→数值的映射表。
//
//  数值规范来自 GLFW 3.x 的 glfw3.h：
//    32..96   可打印 ASCII（空格到反引号）
//    161..175  国际键
//    256..348  特殊键（Esc / 功能键 / 方向键 / 小键盘）
//
//  这份表和 core/glfw_keycodes.h 是同一套规范，直接对齐。
//  ────────────────────────────────────────────────────────────

import Foundation

enum GLFWKeyNames {

    /// 按键名 → GLFW 键码
    ///
    /// 同时接受带前缀（`GLFW_KEY_A`）和不带前缀（`A`）两种写法，
    /// 因为不同版本的 ZL2 布局文件里两种都有出现过。
    static let nameToCode: [String: Int] = {
        var m: [String: Int] = [:]

        // MARK: 可打印字符（ASCII 32..96）
        // 空格
        m["SPACE"] = 32
        // 单引号 / 逗号 / 减号 / 句点 / 斜杠
        m["APOSTROPHE"] = 39
        m["COMMA"] = 44
        m["MINUS"] = 45
        m["PERIOD"] = 46
        m["SLASH"] = 47
        // 数字 0-9（49..57）
        let digits = ["0": 48, "1": 49, "2": 50, "3": 51, "4": 52,
                      "5": 53, "6": 54, "7": 55, "8": 56, "9": 57]
        for (k, v) in digits {
            m[k] = v
            // 也接受 NUM_1 这种
            m["NUM_\(k)"] = v
        }
        // 分号 / 等号
        m["SEMICOLON"] = 59
        m["EQUAL"] = 61
        // 字母 A-Z（65..90）
        for (i, ch) in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated() {
            m[String(ch)] = 65 + i
        }
        // 左方括号 / 反斜杠 / 右方括号 / 反引号
        m["LEFT_BRACKET"] = 91
        m["BACKSLASH"] = 92
        m["RIGHT_BRACKET"] = 93
        m["GRAVE_ACCENT"] = 96

        // MARK: 功能键
        m["ESCAPE"] = 256
        m["ESC"] = 256
        m["ENTER"] = 257
        m["RETURN"] = 257
        m["TAB"] = 258
        m["BACKSPACE"] = 259
        m["INSERT"] = 260
        m["DELETE"] = 261
        m["RIGHT"] = 262
        m["LEFT"] = 263
        m["DOWN"] = 264
        m["UP"] = 265
        m["PAGE_UP"] = 266
        m["PAGE_DOWN"] = 267
        m["HOME"] = 268
        m["END"] = 269
        m["CAPS_LOCK"] = 280
        m["SCROLL_LOCK"] = 281
        m["NUM_LOCK"] = 282
        m["PRINT_SCREEN"] = 283
        m["PAUSE"] = 284

        // F1..F25
        for i in 1...25 {
            m["F\(i)"] = 289 + i
        }

        // 方向键的别名。核心的键名表里用的是 DPAD_UP/DOWN/LEFT/RIGHT
        // （见 CustomControlsUtils.m:524，以及 core/glfw_keycodes.h:145-148，
        // 数值与 UP/LEFT/DOWN/RIGHT 完全相同）。
        // 只写 UP/LEFT/... 的话，布局里写 DPAD_UP 的按钮会静默失效。
        m["DPAD_RIGHT"] = 262
        m["DPAD_LEFT"] = 263
        m["DPAD_DOWN"] = 264
        m["DPAD_UP"] = 265

        // 小键盘。
        //
        // 注意名字：核心用的是 NUMPAD_*（core/glfw_keycodes.h:183-199、
        // CustomControlsUtils.m:576-587），不是 GLFW 文档里的 KP_*。
        // 两套都写，兼容不同来源的布局文件。
        for i in 0...9 {
            m["NUMPAD_\(i)"] = 320 + i
            m["KP_\(i)"] = 320 + i
        }
        let numpad: [String: Int] = [
            "DECIMAL": 330, "DIVIDE": 331, "MULTIPLY": 332,
            "SUBTRACT": 333, "ADD": 334, "ENTER": 335, "EQUAL": 336,
        ]
        for (suffix, code) in numpad {
            m["NUMPAD_\(suffix)"] = code
            m["KP_\(suffix)"] = code
        }

        // 修饰键
        m["LEFT_SHIFT"] = 340
        m["LEFT_CONTROL"] = 341
        m["LEFT_ALT"] = 342
        m["LEFT_SUPER"] = 343
        m["RIGHT_SHIFT"] = 344
        m["RIGHT_CONTROL"] = 345
        m["RIGHT_ALT"] = 346
        m["RIGHT_SUPER"] = 347
        m["MENU"] = 348

        // MARK: 核心特有的特殊按钮（负数键码）
        //
        // 这些不是 GLFW 的键，是核心自己定义的虚拟按钮，
        // 定义在 core/utils.h:42-50，处理在 SurfaceViewController.m:879 起的 switch 里。
        // 数值全是负数，所以查表时**不能**用 `code > 0` 过滤（会把这些全丢掉）。
        //
        // 注意与图层伪键码的区间不冲突：伪键码是 -1000 及以下
        // （见 LayerPseudoKey.swift），这些是 -1..-9。
        m["SPECIALBTN_KEYBOARD"] = -1
        m["SPECIALBTN_TOGGLECTRL"] = -2
        m["SPECIALBTN_MOUSEPRI"] = -3
        m["SPECIALBTN_MOUSESEC"] = -4
        m["SPECIALBTN_VIRTUALMOUSE"] = -5
        m["SPECIALBTN_MOUSEMID"] = -6
        m["SPECIALBTN_SCROLLUP"] = -7
        m["SPECIALBTN_SCROLLDOWN"] = -8
        m["SPECIALBTN_MENU"] = -9

        // 0 = 无按键。核心表里叫 NONE（CustomControlsUtils.m:514），
        // ZL2 的布局里常见 GLFW_KEY_UNKNOWN，两个都认。
        m["NONE"] = 0
        m["UNKNOWN"] = 0

        // 短名别名（ZL2 某些布局里省掉了 SPECIALBTN_ 前缀）
        m["MENU_BUTTON"] = -9

        return m
    }()

    /// 键码 → 标准名（导出 JSON 时如果核心需要名字用得上）
    static let codeToName: [Int: String] = {
        var m: [Int: String] = [:]
        // 反转，但优先保留第一个（即常用的写法）
        for (name, code) in nameToCode {
            if m[code] == nil { m[code] = name }
        }
        return m
    }()

    /// 把 "GLFW_KEY_ESCAPE" / "ESCAPE" / "glfw_key_escape" 统一解析成键码
    /// - Returns: 无法识别时返回 nil
    static func code(for raw: String) -> Int? {
        guard !raw.isEmpty else { return nil }

        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // 去掉 GLFW_KEY_ / GLFW_ / KEY_ 前缀
        for prefix in ["GLFW_KEY_", "GLFW_", "KEY_"] where s.hasPrefix(prefix) {
            s = String(s.dropFirst(prefix.count))
            break
        }
        // 单字符直接取 ASCII
        if s.count == 1, let ascii = s.unicodeScalars.first?.value,
           ascii >= 32, ascii <= 126 {
            return Int(ascii)
        }
        return nameToCode[s]
    }
}
