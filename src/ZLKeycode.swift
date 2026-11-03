// ZL2-iOS · 键盘键位表（自动提取自 ZL2 的 ui/control/Keyboard.kt）
// 来源：/tmp/zl2/ZalithLauncher/src/main/java/com/movtery/zalithlauncher/ui/control/Keyboard.kt
import Foundation

/// GLFW 键码（与 ZL2 的 ControlEventKeycode 一致）
enum ZLKeycode {
    static let escape = 256   // Esc
    static let f1 = 290   // F1
    static let f2 = 291   // F2
    static let f3 = 292   // F3
    static let f4 = 293   // F4
    static let f5 = 294   // F5
    static let f6 = 295   // F6
    static let f7 = 296   // F7
    static let f8 = 297   // F8
    static let f9 = 298   // F9
    static let f10 = 299   // F10
    static let f11 = 300   // F11
    static let f12 = 301   // F12
    static let grave_accent = 96   // `
    static let num1 = 49   // 1
    static let num2 = 50   // 2
    static let num3 = 51   // 3
    static let num4 = 52   // 4
    static let num5 = 53   // 5
    static let num6 = 54   // 6
    static let num7 = 55   // 7
    static let num8 = 56   // 8
    static let num9 = 57   // 9
    static let num0 = 48   // 0
    static let minus = 45   // -
    static let equal = 61   // +
    static let backspace = 259   // Backspace
    static let tab = 258   // Tab
    static let q = 81   // Q
    static let w = 87   // W
    static let e = 69   // E
    static let r = 82   // R
    static let t = 84   // T
    static let y = 89   // Y
    static let u = 85   // U
    static let i = 73   // I
    static let o = 79   // O
    static let p = 80   // P
    static let left_bracket = 91   // [
    static let right_bracket = 93   // ]
    static let backslash = 92   // \\
    static let caps_lock = 280   // Capslock
    static let a = 65   // A
    static let s = 83   // S
    static let d = 68   // D
    static let f = 70   // F
    static let g = 71   // G
    static let h = 72   // H
    static let j = 74   // J
    static let k = 75   // K
    static let l = 76   // L
    static let semicolon = 59   // ;
    static let apostrophe = 39   // '
    static let enter = 257   // Enter
    static let left_shift = 340   // Shift
    static let z = 90   // Z
    static let x = 88   // X
    static let c = 67   // C
    static let v = 86   // V
    static let b = 66   // B
    static let n = 78   // N
    static let m = 77   // M
    static let comma = 44   // ,
    static let period = 46   // .
    static let slash = 47   // /
    static let right_shift = 344   // Shift
    static let left_control = 341   // Ctrl
    static let left_alt = 342   // Alt
    static let space = 32   // Space
    static let right_alt = 346   // Alt
    static let right_control = 345   // Ctrl
    static let print_screen = 283   // Printf
    static let scroll_lock = 281   // Scroll
    static let pause = 284   // Pause
    static let insert = 260   // Insert
    static let home = 268   // Home
    static let page_up = 266   // PgUp
    static let num_lock = 282   // Num lk
    static let kp_divide = 331   // /
    static let kp_multiply = 332   // *
    static let kp_subtract = 333   // -
    static let delete = 261   // Delete
    static let end = 269   // End
    static let page_down = 267   // PgDn
    static let kp_7 = 327   // 7
    static let kp_8 = 328   // 8
    static let kp_9 = 329   // 9
    static let kp_add = 334   // +
    static let kp_4 = 324   // 4
    static let kp_5 = 325   // 5
    static let kp_6 = 326   // 6
    static let up = 265   // ↑
    static let kp_1 = 321   // 1
    static let kp_2 = 322   // 2
    static let kp_3 = 323   // 3
    static let kp_enter = 335   // Enter
    static let left = 263   // ←
    static let down = 264   // ↓
    static let right = 262   // →
    static let kp_0 = 320   // 0
    static let kp_decimal = 330   // .
}

/// 键盘按键定义（label + 键码 + 宽度权重）
struct ZLKeySpec: Identifiable, Hashable {
    var id: String { label + "\(keycode)" }
    var label: String
    var keycode: Int
    var weight: Double = 1.0
    var aspect: Double = 1.0
    var isSpacer: Bool = false
}

extension ZLKeySpec {
    /// ZL2 的主键盘键位表（真机同款）
    static let mainLayout: [ZLKeySpec] = [
        ZLKeySpec(label: "", keycode: 0, weight: 1.0, isSpacer: true),
        ZLKeySpec(label: "Esc", keycode: 256, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "", keycode: 0, weight: 0.6, isSpacer: true),
        ZLKeySpec(label: "F1", keycode: 290, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "F2", keycode: 291, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "F3", keycode: 292, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "F4", keycode: 293, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "", keycode: 0, weight: 0.1, isSpacer: true),
        ZLKeySpec(label: "F5", keycode: 294, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "F6", keycode: 295, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "F7", keycode: 296, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "F8", keycode: 297, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "", keycode: 0, weight: 0.1, isSpacer: true),
        ZLKeySpec(label: "F9", keycode: 298, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "F10", keycode: 299, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "F11", keycode: 300, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "F12", keycode: 301, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "`", keycode: 96, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "1", keycode: 49, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "2", keycode: 50, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "3", keycode: 51, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "4", keycode: 52, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "5", keycode: 53, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "6", keycode: 54, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "7", keycode: 55, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "8", keycode: 56, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "9", keycode: 57, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "0", keycode: 48, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "-", keycode: 45, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "+", keycode: 61, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "Backspace", keycode: 259, weight: 1.5, aspect: 1.5),
        ZLKeySpec(label: "Tab", keycode: 258, weight: 1.3, aspect: 1.3),
        ZLKeySpec(label: "Q", keycode: 81, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "W", keycode: 87, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "E", keycode: 69, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "R", keycode: 82, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "T", keycode: 84, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "Y", keycode: 89, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "U", keycode: 85, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "I", keycode: 73, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "O", keycode: 79, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "P", keycode: 80, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "[", keycode: 91, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "]", keycode: 93, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "\\", keycode: 92, weight: 1.2, aspect: 1.2),
        ZLKeySpec(label: "Capslock", keycode: 280, weight: 1.4, aspect: 1.4),
        ZLKeySpec(label: "A", keycode: 65, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "S", keycode: 83, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "D", keycode: 68, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "F", keycode: 70, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "G", keycode: 71, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "H", keycode: 72, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "J", keycode: 74, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "K", keycode: 75, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "L", keycode: 76, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: ";", keycode: 59, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "'", keycode: 39, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "Enter", keycode: 257, weight: 2.1, aspect: 2.1),
        ZLKeySpec(label: "Shift", keycode: 340, weight: 2.0, aspect: 2.0),
        ZLKeySpec(label: "Z", keycode: 90, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "X", keycode: 88, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "C", keycode: 67, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "V", keycode: 86, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "B", keycode: 66, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "N", keycode: 78, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "M", keycode: 77, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: ",", keycode: 44, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: ".", keycode: 46, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "/", keycode: 47, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "Shift", keycode: 344, weight: 2.2, aspect: 2.2),
        ZLKeySpec(label: "Ctrl", keycode: 341, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "", keycode: 0, weight: 1.0, isSpacer: true),
        ZLKeySpec(label: "Alt", keycode: 342, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "Space", keycode: 32, weight: 7.0, aspect: 7.0),
        ZLKeySpec(label: "Alt", keycode: 346, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "", keycode: 0, weight: 2.0, isSpacer: true),
        ZLKeySpec(label: "Ctrl", keycode: 345, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "Printf", keycode: 283, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "Scroll", keycode: 281, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "Pause", keycode: 284, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "", keycode: 0, weight: 12.2, isSpacer: true),
        ZLKeySpec(label: "Insert", keycode: 260, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "Home", keycode: 268, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "PgUp", keycode: 266, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "", keycode: 0, weight: 7.8, isSpacer: true),
        ZLKeySpec(label: "Num lk", keycode: 282, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "/", keycode: 331, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "*", keycode: 332, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "-", keycode: 333, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "Delete", keycode: 261, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "End", keycode: 269, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "PgDn", keycode: 267, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "", keycode: 0, weight: 7.8, isSpacer: true),
        ZLKeySpec(label: "7", keycode: 327, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "8", keycode: 328, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "9", keycode: 329, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "+", keycode: 334, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "", keycode: 0, weight: 11.0, isSpacer: true),
        ZLKeySpec(label: "4", keycode: 324, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "5", keycode: 325, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "6", keycode: 326, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "", keycode: 0, weight: 1.0, isSpacer: true),
        ZLKeySpec(label: "", keycode: 0, weight: 1.0, isSpacer: true),
        ZLKeySpec(label: "↑", keycode: 265, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "", keycode: 0, weight: 1.0, isSpacer: true),
        ZLKeySpec(label: "1", keycode: 321, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "2", keycode: 322, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "3", keycode: 323, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "Enter", keycode: 335, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "←", keycode: 263, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "↓", keycode: 264, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "→", keycode: 262, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "", keycode: 0, weight: 8.8, isSpacer: true),
        ZLKeySpec(label: "0", keycode: 320, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: ".", keycode: 330, weight: 1.0, aspect: 1.0),
        ZLKeySpec(label: "", keycode: 0, weight: 1.0, isSpacer: true),
    ]
}
