// 启动前预检
//
// 为什么需要：点「尝试启动」时，如果版本文件不全（缺 jar、缺库、缺资源索引、
// 缺对应 JRE、缺控制布局），核心会失败，但用户要到几秒后看到「launchJVM 返回错误码 N」
// 才知道。而这些都是**启动前就能查出来**的静态条件。
//
// 这个文件把前面几十轮排查里确认过的「必崩条件」逐条变成检查项：
//   · 版本 JSON 是否存在、能否解析、有没有 mainClass
//   · client jar 是否存在（加载器版本要顺着 inheritsFrom 找到父版本的 jar）
//   · libraries 有没有内容
//   · assetIndex 对应的 index 文件在不在
//   · 该版本需要的 Java 大版本，对应运行时在不在
//   · 渲染器对应 dylib 是否在包内
//   · 当前控制布局文件在不在
//
// 注意：**只提示，不阻止启动**。检查条件宁可宽松 —— 一旦把能跑的组合误判成
// 「不能启动」，用户就永远试不了了，这比让他多试一次更糟。

import Foundation

enum ZLPreflight {

    /// 跑一遍预检。`meta` 是版本 JSON 解析后的字典（可空 —— 拿不到时只检查文件层面）
    static func run(versionID: String, meta: [String: Any]?) -> [ZLDiagItem] {
        let fm = FileManager.default
        let mcRoot = VersionRepository.shared.mcRoot
        var out: [ZLDiagItem] = []

        // ---- 1. 版本 JSON ----
        let jsonPath = mcRoot.appendingPathComponent("versions/\(versionID)/\(versionID).json")
        if fm.fileExists(atPath: jsonPath.path) {
            let mainClass = (meta?["mainClass"] as? String) ?? ""
            if mainClass.isEmpty {
                out.append(ZLDiagItem(title: "版本配置",
                                      value: "缺少 mainClass",
                                      level: .fail,
                                      advice: "版本 JSON 不完整，可能是下载中断。删掉这个版本重装"))
            } else {
                out.append(ZLDiagItem(title: "版本配置", value: "正常（\(mainClass)）", level: .ok))
            }
        } else {
            out.append(ZLDiagItem(title: "版本配置",
                                  value: "文件不存在",
                                  level: .fail,
                                  advice: "这个版本还没装好，去「下载」页重新安装"))
        }

        // ---- 2. client jar（加载器版本要顺着 inheritsFrom 找父版本）----
        let jarID = (meta?["inheritsFrom"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? versionID
        let jarPath = mcRoot.appendingPathComponent("versions/\(jarID)/\(jarID).jar")
        let jarSize = (try? fm.attributesOfItem(atPath: jarPath.path)[.size] as? Int) ?? 0
        if jarSize >= 1024 {
            let note = jarID == versionID ? "在位" : "在位（来自原版 \(jarID)）"
            out.append(ZLDiagItem(title: "游戏本体 jar", value: note, level: .ok))
        } else {
            out.append(ZLDiagItem(title: "游戏本体 jar",
                                  value: jarID == versionID ? "缺失或太小" : "缺失（原版 \(jarID) 没装）",
                                  level: .fail,
                                  advice: jarID == versionID
                                    ? "重新安装这个版本"
                                    : "先把原版 \(jarID) 装上，加载器版本要用它的本体"))
        }

        // ---- 3. libraries ----
        let libRoot = mcRoot.appendingPathComponent("libraries")
        let libFiles = collectFiles(libRoot, suffix: ".jar", limit: 400)
        if libFiles == 0 {
            out.append(ZLDiagItem(title: "依赖库",
                                  value: "一个都没有",
                                  level: .fail,
                                  advice: "重新安装这个版本（libraries 目录是空的）"))
        } else if libFiles < 5 {
            out.append(ZLDiagItem(title: "依赖库",
                                  value: "只有 \(libFiles) 个，可能没下完",
                                  level: .warn,
                                  advice: "如果启动报 ClassNotFoundException，就重装"))
        } else {
            out.append(ZLDiagItem(title: "依赖库", value: "\(libFiles) 个", level: .ok))
        }

        // ---- 4. 资源索引 ----
        if let idx = (meta?["assetIndex"] as? [String: Any])?["id"] as? String, !idx.isEmpty {
            let idxPath = mcRoot.appendingPathComponent("assets/indexes/\(idx).json")
            if fm.fileExists(atPath: idxPath.path) {
                let objs = collectFiles(mcRoot.appendingPathComponent("assets/objects"), suffix: nil, limit: 5)
                out.append(ZLDiagItem(title: "资源索引",
                                      value: objs > 0 ? "正常（有资源文件）" : "正常（但资源文件还没下）",
                                      level: objs > 0 ? .ok : .warn,
                                      advice: objs > 0 ? nil : "没有资源文件时游戏能起但没贴图没声音"))
            } else {
                out.append(ZLDiagItem(title: "资源索引",
                                      value: "indexes/\(idx).json 不存在",
                                      level: .warn,
                                      advice: "重装这个版本可以补上；没有资源时游戏仍可能启动"))
            }
        }

        // ---- 5. Java 运行时 ----
        let major = CoreBridge.requiredJavaVersion(meta ?? [:])
        if CoreBridge.hasRuntime(java: major) {
            out.append(ZLDiagItem(title: "Java 运行时", value: "Java \(major) 在位", level: .ok))
        } else {
            let have = CoreBridge.bundledJavaVersions()
            out.append(ZLDiagItem(title: "Java 运行时",
                                  value: "需要 Java \(major)，包里只有 \(have.isEmpty ? "无" : have.map(String.init).joined(separator: "/"))",
                                  level: .fail,
                                  advice: "这个包缺对应的运行时，需要重新构建打包"))
        }

        // ---- 6. 渲染器 ----
        let stored = UserDefaults.standard.string(forKey: "renderer") ?? ""
        let safe = ZLRenderers.sanitize(stored)
        let keys = ZLRenderers.availableKeys()
        if keys.contains(safe) {
            out.append(ZLDiagItem(title: "渲染器",
                                  value: ZLRenderers.displayName(for: safe),
                                  level: .ok))
        } else {
            out.append(ZLDiagItem(title: "渲染器",
                                  value: "包内没有可用的渲染器",
                                  level: .fail,
                                  advice: "构建不完整，需要重新打包（Frameworks 缺 dylib）"))
        }

        // ---- 7. 控制布局 ----
        //
        // 注意：布局名存在**核心的 plist** 里（setPrefObject("control.default_ctrl")），
        // 不是 UserDefaults；而且值自带 .json 后缀（默认 "default.json"）。
        // 一开始这里写成 UserDefaults + 手拼 ".json"，会永远去查 default.json，
        // 用户换了布局就误报「不存在」。直接用现成的解析入口。
        let layoutName = CoreLayoutExporter.coreActiveLayoutName
        let layoutPath = mcRoot.appendingPathComponent("controlmap/\(layoutName)")
        if fm.fileExists(atPath: layoutPath.path) {
            out.append(ZLDiagItem(title: "控制布局", value: layoutName, level: .ok))
        } else {
            out.append(ZLDiagItem(title: "控制布局",
                                  value: "controlmap/\(layoutName) 不存在",
                                  level: .warn,
                                  advice: "进游戏会没有虚拟按键。重开一次 App 通常会自动生成"))
        }

        return out
    }

    /// 数目录下某后缀的文件（限深度，避免在 libraries 里走几万层）
    private static func collectFiles(_ root: URL, suffix: String?, limit: Int) -> Int {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: root,
                                     includingPropertiesForKeys: [.isRegularFileKey],
                                     options: [.skipsHiddenFiles]) else { return 0 }
        var count = 0
        for case let url as URL in en {
            if let s = suffix, !url.lastPathComponent.hasSuffix(s) { continue }
            count += 1
            if count >= limit { break }
        }
        return count
    }

    /// 一句话结论（给界面顶部的横幅用）
    static func summary(_ items: [ZLDiagItem]) -> (text: String, level: ZLDiagLevel) {
        let fails = items.filter { $0.level == .fail }
        let warns = items.filter { $0.level == .warn }
        if !fails.isEmpty {
            return ("\(fails.count) 项必崩条件不满足，启动很可能失败", .fail)
        }
        if !warns.isEmpty {
            return ("\(warns.count) 项需要注意，但可以试着启动", .warn)
        }
        return ("七项前置条件全部就位", .ok)
    }
}
