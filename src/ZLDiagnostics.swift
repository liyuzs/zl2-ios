//
//  ZLDiagnostics.swift
//  ZL2-iOS · 一键环境诊断
//
//  ────────────────────────────────────────────────────────────
//  为什么需要这个：
//
//  这个 App 有个绕不开的现实——**从没在任何 iPhone 上跑通过**。
//  朋友第一次装很可能失败，而失败时最麻烦的是「说不清哪里出了问题」。
//
//  这个模块做三件事：
//    1. 把所有关键环境事实收集成一份结构化报告
//    2. 逐项判定「正常 / 警告 / 失败」，给出人话解释
//    3. 支持导出成文本，直接复制发给开发者
//
//  设计原则：不依赖任何外部服务，全部本地检查，失败也不崩。
//  ────────────────────────────────────────────────────────────

import Foundation
import UIKit

// MARK: - 检查项

enum ZLDiagLevel: String {
    case ok      = "正常"
    case warn    = "注意"
    case fail    = "异常"
    case skip    = "跳过"

    var symbol: String {
        switch self {
        case .ok:   return "checkmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.octagon.fill"
        case .skip: return "minus.circle.fill"
        }
    }
}

struct ZLDiagItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let level: ZLDiagLevel
    /// 出问题时怎么办
    var advice: String? = nil
}

// MARK: - 诊断器

enum ZLDiagnostics {

    /// 跑一遍完整诊断
    static func run() -> [ZLDiagItem] {
        var items: [ZLDiagItem] = []

        items.append(contentsOf: checkDevice())
        items.append(contentsOf: checkRuntime())
        items.append(contentsOf: checkCore())
        items.append(contentsOf: checkSandbox())
        items.append(contentsOf: checkGameData())
        items.append(contentsOf: checkRecoveryBackups())

        return items
    }

    /// 有没有"解码失败被备份下来"的数据。
    ///
    /// 平时应该是 0 项。一旦不为 0，说明某份持久化数据解不开了（多半是升级后字段变了），
    /// 原始字节被 `ZLRecovery` 存进了 plist —— 数据还在，但 App 里看不到。
    /// 不报出来的话，用户只会觉得"我的账号/服务器/布局突然没了"。
    private static func checkRecoveryBackups() -> [ZLDiagItem] {
        let keys = ZLRecovery.allBackupKeys()
        if keys.isEmpty {
            return [ZLDiagItem(title: "数据备份", value: "无异常备份", level: .ok)]
        }
        let names = keys.map { $0.replacingOccurrences(of: ZLRecovery.prefix, with: "") }
        return [ZLDiagItem(
            title: "数据备份",
            value: "\(keys.count) 份数据解码失败但已备份（\(names.joined(separator: "、"))）——原始内容完好，打包日志时会一并带出",
            level: .warn
        )]
    }

    // MARK: 设备与环境

    private static func checkDevice() -> [ZLDiagItem] {
        var out: [ZLDiagItem] = []
        let dev = UIDevice.current

        out.append(ZLDiagItem(
            title: "设备型号",
            value: "\(dev.model)（\(hardwareIdentifier())）",
            level: .ok
        ))

        out.append(ZLDiagItem(
            title: "系统版本",
            value: "iOS \(dev.systemVersion)",
            level: .ok
        ))

        // iOS 16 是最低要求（project.yml 里设的）
        let major = Int(dev.systemVersion.split(separator: ".").first ?? "0") ?? 0
        if major < 16 {
            out.append(ZLDiagItem(
                title: "系统版本要求",
                value: "当前 \(major)，需要 16 以上",
                level: .fail,
                advice: "这个 App 最低要求 iOS 16，请升级系统"
            ))
        }

        // 内存
        let memGB = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024 / 1024
        out.append(ZLDiagItem(
            title: "物理内存",
            value: String(format: "%.1f GB", memGB),
            level: memGB < 3 ? .warn : .ok,
            advice: memGB < 3 ? "内存偏小，建议分配 512MB 给游戏，并关掉后台应用" : nil
        ))

        return out
    }

    // MARK: Java 运行时

    private static func checkRuntime() -> [ZLDiagItem] {
        var out: [ZLDiagItem] = []

        // 统一走 CoreBridge 的判定，不再在这里另写一份路径规则。
        // 之前这里写死 [17,21,25] 且只认 lib/libjli.dylib，
        // 而 CoreBridge 还认 Java 8 和 lib/jli/libjli.dylib —— 两处迟早会对不上。
        let found: [Int] = CoreBridge.bundledJavaVersions()

        if found.isEmpty {
            out.append(ZLDiagItem(
                title: "Java 运行时",
                value: "一套都没找到",
                level: .fail,
                advice: "IPA 可能不完整，重新下载（正常大小约 132 MB）"
            ))
        } else {
            out.append(ZLDiagItem(
                title: "Java 运行时",
                value: "已内置 Java " + found.map(String.init).joined(separator: " / "),
                level: .ok
            ))
            // MC 1.20.5+ 需要 21，1.17-1.20.4 需要 17
            if !found.contains(17) {
                out.append(ZLDiagItem(
                    title: "Java 17",
                    value: "缺失",
                    level: .warn,
                    advice: "MC 1.17 ~ 1.20.4 需要 Java 17"
                ))
            }
            if !found.contains(21) {
                out.append(ZLDiagItem(
                    title: "Java 21",
                    value: "缺失",
                    level: .warn,
                    advice: "MC 1.20.5 及更新版本需要 Java 21"
                ))
            }
            if !found.contains(25) {
                out.append(ZLDiagItem(
                    title: "Java 25",
                    value: "缺失",
                    level: .warn,
                    advice: "MC 26 及更新版本需要 Java 25"
                ))
            }
        }

        return out
    }

    // MARK: 启动核心

    private static func checkCore() -> [ZLDiagItem] {
        var out: [ZLDiagItem] = []

        #if ZL2_CORE_LINKED
        out.append(ZLDiagItem(title: "启动核心", value: "已链接（Amethyst）", level: .ok))
        #else
        out.append(ZLDiagItem(
            title: "启动核心",
            value: "未链接（模拟器构建）",
            level: .warn,
            advice: "当前是模拟器版本，无法真正启动游戏"
        ))
        #endif

        // 图形库
        let fw = Bundle.main.bundlePath + "/Frameworks"
        let need = ["libgl4es_114.dylib", "libtinygl4angle.dylib", "libOSMesa.8.dylib", "libMoltenVK.dylib"]
        var present: [String] = []
        var missing: [String] = []
        for lib in need {
            if FileManager.default.fileExists(atPath: fw + "/" + lib) {
                present.append(lib)
            } else {
                missing.append(lib)
            }
        }

        if missing.isEmpty {
            out.append(ZLDiagItem(
                title: "图形后端",
                value: "\(present.count) 个渲染库齐全",
                level: .ok
            ))
        } else {
            out.append(ZLDiagItem(
                title: "图形后端",
                value: "缺 \(missing.count) 个：\(missing.joined(separator: ", "))",
                level: .fail,
                advice: "IPA 不完整，重新下载"
            ))
        }

        // 当前实际使用的渲染器 —— 排查「启动黑屏 / 一进游戏就退」时，
        // 第一件要知道的事就是「它到底拿了哪个后端去 dlopen」。
        let storedRenderer = UserDefaults.standard.string(forKey: "renderer") ?? ""
        let effective = ZLRenderers.sanitize(storedRenderer)
        var rendererValue = ZLRenderers.displayName(for: effective)
        if storedRenderer != effective {
            // 拆开写，避免在字符串插值里嵌套三元 + 字符串字面量（读起来也清楚些）
            let shown = storedRenderer.isEmpty ? "空" : storedRenderer
            rendererValue += "（原值 \(shown) 不可用，已自动改）"
        }
        out.append(ZLDiagItem(
            title: "当前渲染器",
            value: rendererValue,
            level: storedRenderer == effective ? .ok : .warn,
            advice: storedRenderer == effective
                ? nil
                : "设置 → 渲染 → 渲染器 里重新选一个"
        ))

        // JIT 脚本
        let jit = Bundle.main.bundlePath + "/UniversalJIT26.js"
        out.append(ZLDiagItem(
            title: "JIT 脚本",
            value: FileManager.default.fileExists(atPath: jit) ? "已打包" : "缺失",
            level: FileManager.default.fileExists(atPath: jit) ? .ok : .fail,
            advice: FileManager.default.fileExists(atPath: jit)
                ? nil
                : "iOS 上跑 Java 必须有 JIT，缺了会闪退"
        ))

        return out
    }

    // MARK: 沙盒与权限

    private static func checkSandbox() -> [ZLDiagItem] {
        var out: [ZLDiagItem] = []

        // 文档目录可写性
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if let docs {
            let probe = docs.appendingPathComponent(".zl_write_probe")
            let ok = (try? "probe".write(to: probe, atomically: true, encoding: .utf8)) != nil
            try? FileManager.default.removeItem(at: probe)
            out.append(ZLDiagItem(
                title: "沙盒写入",
                value: ok ? "正常" : "不可写",
                level: ok ? .ok : .fail,
                advice: ok ? nil : "App 无法写文件，重装试试"
            ))
        }

        // 可用空间
        if let free = ZLStorage.freeBytes() {
            let freeGB = Double(free) / 1024 / 1024 / 1024
            out.append(ZLDiagItem(
                title: "可用空间",
                value: String(format: "%.1f GB", freeGB),
                level: freeGB < 2 ? .warn : .ok,
                advice: freeGB < 2 ? "空间不足，下载游戏版本可能失败" : nil
            ))
        }

        // 网络（只是提示，不主动测试以免卡住）
        out.append(ZLDiagItem(
            title: "网络",
            value: "需在下载版本时验证",
            level: .skip
        ))

        return out
    }

    // MARK: 游戏数据

    private static func checkGameData() -> [ZLDiagItem] {
        var out: [ZLDiagItem] = []

        let versionsDir = VersionRepository.shared.versionsDir
        let versions = (try? FileManager.default.contentsOfDirectory(
            at: versionsDir, includingPropertiesForKeys: nil)) ?? []

        out.append(ZLDiagItem(
            title: "已装版本",
            value: versions.isEmpty ? "还没下载任何版本" : "\(versions.count) 个",
            level: versions.isEmpty ? .skip : .ok,
            advice: versions.isEmpty ? "到「下载」页选一个版本，比如 1.20.1 + Fabric" : nil
        ))

        let accounts = AccountStore.shared.accounts
        out.append(ZLDiagItem(
            title: "账号",
            value: accounts.isEmpty ? "未登录" : "\(accounts.count) 个",
            level: accounts.isEmpty ? .skip : .ok
        ))

        // 版本隔离状态
        let iso = VersionRepository.shared.isolationEnabled
        out.append(ZLDiagItem(
            title: "版本隔离",
            value: iso ? "开启（每版本独立目录）" : "关闭（共用目录）",
            level: .ok
        ))

        return out
    }

    // MARK: 导出

    /// 生成可复制的纯文本报告
    static func exportText(_ items: [ZLDiagItem]) -> String {
        var lines: [String] = []
        lines.append("=== CraftLauncher 环境诊断 ===")
        lines.append("生成时间：\(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))")
        lines.append("")

        let fails = items.filter { $0.level == .fail }
        let warns = items.filter { $0.level == .warn }

        // items 为空有两种可能：真的没有任何检查项，或者**检查还没跑完**。
        // 原来看空就写「一切正常」——用户一进页面立刻点「打包日志分享」，
        // 报告里就会写着"一切正常"，把最需要排查的时刻误导成没问题。
        if items.isEmpty {
            lines.append("结论：（检查尚未完成——这份报告是在诊断跑完之前生成的，不代表一切正常）")
        } else if fails.isEmpty && warns.isEmpty {
            lines.append("结论：一切正常")
        } else {
            lines.append("结论：\(fails.count) 项异常，\(warns.count) 项需注意")
        }
        lines.append("")

        for item in items {
            lines.append("[\(item.level.rawValue)] \(item.title)：\(item.value)")
            if let a = item.advice {
                lines.append("       → \(a)")
            }
        }

        lines.append("")
        lines.append("=== 反馈时请把这段完整发给开发者 ===")
        return lines.joined(separator: "\n")
    }

    // MARK: 工具

    /// 硬件标识（如 iPhone15,2）
    private static func hardwareIdentifier() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine.isEmpty ? "未知" : machine
    }
}
