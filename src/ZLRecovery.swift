// ZL2-iOS · 解码失败兜底
//
// 为什么需要这个：
//   项目里很多持久化用 `try? JSONDecoder().decode(...)`，解码失败就当"没有数据"，
//   随后用户只要改一次东西，save() 就会把**原来那份解不开的数据覆盖掉** —— 永久丢失。
//
//   触发场景不是臆想：
//     · 新版本给 Account / ServerCodable / ControlAppearance 加字段并改成非可选
//     · 字段类型从 Int 换成 String
//     · 换了 CodingKeys 的拼写
//   任何一条都能让老数据在升级后解不开。对用户来说就是「账号突然全没了」
//   「服务器列表空了」「我自己调的控制布局变回默认了」，而且没有任何提示。
//
// 做法很朴素：**解码失败时先把原始字节原样存一份**，再让上层走"当作没有数据"的分支。
// 数据在 plist 里（keys 以 zl.recover. 开头），需要时可以从备份里手工恢复。
//
// 注意：只备份，不自动修复、不自动回填 —— 自动回填会把半损坏的数据再写回去。

import Foundation

enum ZLRecovery {

    /// 备份键前缀
    static let prefix = "zl.recover."

    /// 记录备份时间的键后缀
    private static let stampSuffix = ".at"

    /// 把解码失败的原始数据存一份。
    /// - Parameters:
    ///   - data: 解码失败的原始字节
    ///   - key: 原存储键，用来生成备份键，便于将来找回
    static func preserveRawData(_ data: Data, for key: String) {
        guard !data.isEmpty else { return }
        let d = UserDefaults.standard
        let backupKey = prefix + key

        // 只保留第一次坏掉的那份 —— 后面再坏可能是同一份数据反复尝试，
        // 覆盖掉反而丢了最早的、最可能完整的版本。
        if d.data(forKey: backupKey) == nil {
            d.set(data, forKey: backupKey)
            d.set(Date().timeIntervalSince1970, forKey: backupKey + stampSuffix)
            NSLog("[ZL2] 数据解码失败，已备份原始内容到 %@（%ld 字节，原键 %@）",
                  backupKey, data.count, key)
        } else {
            NSLog("[ZL2] 数据解码失败，%@" + " 已有更早的备份，本次不覆盖", backupKey)
        }
    }

    /// 是否存在某个键的备份（用于在诊断/设置里提示"有可恢复的数据"）
    static func hasBackup(for key: String) -> Bool {
        UserDefaults.standard.data(forKey: prefix + key) != nil
    }

    /// 取回备份的原始数据（供将来做恢复功能，或用户自己导出）
    static func backupData(for key: String) -> Data? {
        UserDefaults.standard.data(forKey: prefix + key)
    }

    /// 列出所有备份键（诊断报告里用得到）
    static func allBackupKeys() -> [String] {
        UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) && !$0.hasSuffix(stampSuffix) }
            .sorted()
    }
}
