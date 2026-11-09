// CraftLauncher · iOS 特色功能
// 1) App Intents：用 Siri / 快捷指令一键启动游戏
// 2) 桌面小组件用的数据共享
import Foundation
import SwiftUI
import AppIntents
import WidgetKit

// MARK: - App Intents（Siri / 快捷指令）

/// 「启动 Minecraft」——可以加到快捷指令，或者对 Siri 说「用 CraftLauncher 启动游戏」
struct LaunchGameIntent: AppIntent {
    static var title: LocalizedStringResource = "启动 Minecraft"
    static var description = IntentDescription("用 CraftLauncher 直接进入游戏")
    static var openAppWhenRun: Bool = true     // 需要前台才能启动游戏

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 打一个标记，RootView 起来后自动开始启动流程
        UserDefaults.standard.set(true, forKey: "zl.pendingLaunch")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "zl.pendingLaunchAt")
        return .result(dialog: "正在启动 Minecraft…")
    }
}

/// 「打开下载中心」
struct OpenDownloadIntent: AppIntent {
    static var title: LocalizedStringResource = "打开版本下载"
    static var description = IntentDescription("打开 CraftLauncher 的版本下载页")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        ZLPendingAction.setRoute("download")
        return .result()
    }
}

/// 「切换游戏目录」
struct SwitchGameDirIntent: AppIntent {
    static var title: LocalizedStringResource = "切换游戏目录"
    static var description = IntentDescription("在 CraftLauncher 里切换实例目录")

    @Parameter(title: "目录名")
    var name: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 光写 UserDefaults 是不够的：VersionRepository / CoreBridge 都是内存单例，
        // 不调 activate 的话要杀进程重启才生效。
        let store = GameDirectoryStore.shared
        guard store.instances.contains(where: { $0.id == name }) else {
            return .result(dialog: "没有叫「\(name)」的游戏目录")
        }
        // activate 会改 @Published，必须在主线程
        await MainActor.run { store.activate(name) }
        ZLPendingAction.setRoute("versionList")
        return .result(dialog: "已切换到 \(name)")
    }
}

/// 让这些 Intent 出现在「快捷指令」App 里
struct CraftLauncherShortcuts: AppShortcutsProvider {
    // 关键：AppShortcutsProvider.appShortcuts 带 @AppShortcutsBuilder（result builder），
    // 所以这里**不能**写数组字面量 [ ]、元素之间也**不能**写逗号 ——
    // 直接并列写多个 AppShortcut(...) 就行，builder 会自动合并成数组。
    // （之前误以为缺方括号，加了 [ ] 反而报 "cannot convert [AppShortcut] to AppShortcut"）
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LaunchGameIntent(),
            phrases: [
                "用 \(.applicationName) 启动游戏",
                "打开 \(.applicationName) 开始玩"
            ],
            shortTitle: "启动游戏",
            systemImageName: "play.circle.fill"
        )
        AppShortcut(
            intent: OpenDownloadIntent(),
            phrases: ["用 \(.applicationName) 下载版本"],
            shortTitle: "下载版本",
            systemImageName: "arrow.down.circle.fill"
        )
    }
}

// MARK: - 小组件共享数据

/// 把「上次玩的版本」「已装版本数」等写进 App Group，供桌面小组件读取。
/// 需要在 Xcode 里给主 App 和 Widget 都开启 App Groups（group.com.liyuzs.craftlauncher）。
enum ZLSharedStore {
    static let suiteName = "group.com.liyuzs.craftlauncher"

    /// 优先用 App Group（有付费开发者账号时），否则回退到 App 自己的存储。
    /// 免费签名不支持 App Groups，回退后数据只在 App 内可见（小组件读不到，但不会崩）。
    private static var defaults: UserDefaults? {
        if let shared = UserDefaults(suiteName: suiteName) {
            return shared
        }
        return UserDefaults.standard
    }

    /// 同步当前状态给小组件
    static func sync(versionName: String, installedCount: Int, lastPlayed: Date?) {
        guard let d = defaults else { return }
        d.set(versionName, forKey: "widget.version")
        d.set(installedCount, forKey: "widget.count")
        if let t = lastPlayed {
            d.set(t, forKey: "widget.lastPlayed")
        }
        // 有装小组件时刷新；没有时会静默跳过，不会崩
        WidgetCenter.shared.reloadAllTimelines()
    }

    static var versionName: String {
        defaults?.string(forKey: "widget.version") ?? "还没有版本"
    }
    static var installedCount: Int {
        defaults?.integer(forKey: "widget.count") ?? 0
    }
    static var lastPlayed: Date? {
        defaults?.object(forKey: "widget.lastPlayed") as? Date
    }
}

// MARK: - 待处理动作（App 启动后消费）

enum ZLPendingAction {
    /// 检查有没有 Siri 留下的启动指令
    static func consumeLaunchFlag() -> Bool {
        let d = UserDefaults.standard
        guard d.bool(forKey: "zl.pendingLaunch") else { return false }
        // 超过 2 分钟的指令作废（避免下次打开莫名其妙启动）
        let at = d.double(forKey: "zl.pendingLaunchAt")
        d.set(false, forKey: "zl.pendingLaunch")
        d.removeObject(forKey: "zl.pendingLaunchAt")
        guard Date().timeIntervalSince1970 - at < 120 else { return false }
        return true
    }

    /// 记下"下次打开时要跳到哪个页面"（同时记时间戳，供 consumeRoute 判断时效）
    static func setRoute(_ route: String) {
        let d = UserDefaults.standard
        d.set(route, forKey: "zl.pendingRoute")
        d.set(Date().timeIntervalSince1970, forKey: "zl.pendingRouteAt")
    }

    /// 「想自动启动游戏」这个意图先记下来，等首页真的读到版本列表再消费。
    ///
    /// 原来的做法是：RootView 里 `DispatchQueue.main.asyncAfter(0.8)` 之后再发一条 Notification。
    /// 而首页收到通知时第一句是 `guard !selectedVersion.isEmpty` —— 0.8 秒只是**猜**，
    /// 版本多、磁盘慢的时候列表还没读出来，就直接 return，**通知是一次性的，这次启动意图就没了**。
    /// 用户会说"用 Siri 启动游戏没反应"。
    ///
    /// 现在改成带时效的标志：首页每次读完版本列表都来问一句，能启就启。
    static func markAutoLaunchPending() {
        let d = UserDefaults.standard
        d.set(true, forKey: "zl.pendingAutoLaunch")
        d.set(Date().timeIntervalSince1970, forKey: "zl.pendingAutoLaunchAt")
    }

    /// 有没有待自动启动的意图（只读不消费，供"条件不满足先等等"时判断）
    static func hasPendingAutoLaunch() -> Bool {
        let d = UserDefaults.standard
        guard d.bool(forKey: "zl.pendingAutoLaunch") else { return false }
        let at = d.double(forKey: "zl.pendingAutoLaunchAt")
        return Date().timeIntervalSince1970 - at < 120
    }

    /// 取走「想自动启动」的意图（取到就清掉；超过 2 分钟作废）
    static func consumeAutoLaunchPending() -> Bool {
        let d = UserDefaults.standard
        guard d.bool(forKey: "zl.pendingAutoLaunch") else { return false }
        let at = d.double(forKey: "zl.pendingAutoLaunchAt")
        d.set(false, forKey: "zl.pendingAutoLaunch")
        d.removeObject(forKey: "zl.pendingAutoLaunchAt")
        guard Date().timeIntervalSince1970 - at < 120 else { return false }
        return true
    }

    /// 检查有没有要跳转的页面。
    ///
    /// **和启动标志一样要过期**：原来没有时效，于是"App 在运行中收到快捷指令 → 没被消费 →
    /// 这条路由一直留着 → 下次冷启动突然跳到那个页面"。用户会莫名其妙。
    static func consumeRoute() -> String? {
        let d = UserDefaults.standard
        guard let r = d.string(forKey: "zl.pendingRoute") else { return nil }
        let at = d.double(forKey: "zl.pendingRouteAt")
        d.removeObject(forKey: "zl.pendingRoute")
        d.removeObject(forKey: "zl.pendingRouteAt")
        guard Date().timeIntervalSince1970 - at < 120 else { return nil }
        return r
    }
}
