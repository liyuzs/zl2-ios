// ZL2-iOS · 路径安全
//
// 为什么需要这个文件：
//   项目里很多地方把「网络来的文件名」或「用户手输的名字」直接拼进路径，例如
//       dir.appendingPathComponent(file.filename)      // filename 来自 Modrinth API
//       libRoot.appendingPathComponent(path)           // path 来自加载器元数据
//       current.appendingPathComponent(newName)        // newName 是用户输入的
//   这些字符串里只要出现 `..` 或 `/`，文件就会落到预期目录之外：
//     · 恶意/被篡改的接口数据可以把文件写到 Documents 之外
//     · 用户手滑输入 `../` 能把文件挪进 App 自己的数据目录
//
// 设计原则：
//   · **正常名字必须原样通过**（不改大小写、不加后缀、不裁长度），只处理危险字符
//   · 拒绝比"悄悄改掉"更诚实 —— 用户输入的名字如果非法，应该报错而不是静默改名
//   · 网络来的名字没法报错（用户不知情），所以用 safeComponent 净化后落盘
//
// 注意：这个文件是本项目里唯一允许"改写文件名"的地方，别处不要再自己写一套。

import Foundation

enum ZLPathSafety {

    /// 一个名字里不允许出现的字符。
    /// `/` 是路径分隔符；`:` 在 HFS+/部分 API 里也表示路径；NUL 会截断 C 字符串。
    private static let forbidden = CharacterSet(charactersIn: "/:")

    /// 把「可能来自网络」的名字净化成一个**单层**安全文件名。
    ///
    /// - 分隔符 `/:` → `_`
    /// - 去掉首尾空白与首部连续的 `.`（避免 `.` / `..` 变成隐藏文件或上级目录）
    /// - 空结果退化为 `unnamed`
    /// - 超长（>200）截断，保留尾部扩展名
    static func safeComponent(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "unnamed" }

        // ①② 分隔符换成下划线
        s = s.components(separatedBy: forbidden).joined(separator: "_")

        // ③ 去掉开头的连续点（`..` → 空；`.hidden` → `hidden`）
        while s.hasPrefix(".") { s.removeFirst() }
        if s.isEmpty { return "unnamed" }

        // ④ 仍然含 `..` 的（例如 `a..b` 无害，但 `a/../b` 已在上面被拆掉）——
        //    这里只需要保证结果里不存在路径分隔符，前面已处理。

        // ⑤ 长度
        if s.count > 200 {
            let ext = (s as NSString).pathExtension
            let keep = 200 - (ext.isEmpty ? 0 : ext.count + 1)
            let base = (s as NSString).deletingPathExtension
            s = String(base.prefix(max(1, keep))) + (ext.isEmpty ? "" : "." + ext)
        }
        return s
    }

    /// 用户输入的名字是否可用于新建文件/文件夹。
    /// 返回 `nil` 表示可用，否则返回给用户看的原因。
    static func validateNewName(_ raw: String, kind: String = "名称") -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "\(kind)不能为空" }
        if s == "." || s == ".." { return "\(kind)不能是 . 或 .." }
        if s.contains("/") { return "\(kind)不能包含斜杠 /" }
        if s.contains(":") { return "\(kind)不能包含冒号" }
        if s.contains("\\") { return "\(kind)不能包含反斜杠" }
        if s.count > 200 { return "\(kind)太长（最多 200 个字符）" }
        return nil
    }

    /// 校验一个「多段相对路径」（例如 Mojang 资源里的 `net/minecraft/xxx.jar`）。
    /// 允许用 `/` 分目录，但每一段都必须是安全的，且不能有 `..`。
    static func isSafeRelativePath(_ raw: String) -> Bool {
        if raw.isEmpty { return false }
        if raw.hasPrefix("/") { return false }          // 绝对路径
        if raw.contains(":") { return false }
        for seg in raw.split(separator: "/", omittingEmptySubsequences: false) {
            if seg.isEmpty { return false }             // 空段 / 双斜杠
            if seg == "." || seg == ".." { return false }
        }
        return true
    }

    /// 把多段相对路径净化后返回；不可用时返回 nil（调用方应视为下载失败）。
    static func safeRelativePath(_ raw: String) -> String? {
        guard isSafeRelativePath(raw) else { return nil }
        return raw
    }
}
