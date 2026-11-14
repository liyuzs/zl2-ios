import Foundation

/// 存储空间查询
///
/// 一处实现、两处使用：
/// · `ZLDiagnostics` 诊断页显示"可用空间"
/// · `VersionInstaller` 下载前预检（第128轮加）
///
/// 抽出来的理由见第119轮的教训：同一事实在两处各写一份，早晚会分叉。
enum ZLStorage {

    /// 当前可用的磁盘空间（字节）。
    ///
    /// **拿不到时返回 nil**，不要当成 0 —— 调用方要能区分"空间是 0"和"查不到"，
    /// 否则会把"查询失败"误报成"空间不足"。
    static func freeBytes() -> Int64? {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let free = attrs[.systemFreeSize] as? Int64 else { return nil }
        return free
    }

    /// 人类可读的大小（"1.2 GB"）
    static func human(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
