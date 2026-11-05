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
        UserDefaults.standard.set("download", forKey: "zl.pendingRoute")
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
        UserDefaults.standard.set(name, forKey: "zl.game.instance")
        UserDefaults.standard.set("versionList", forKey: "zl.pendingRoute")
        return .result(dialog: "已切换到 \(name)")
    }
}

/// 让这些 Intent 出现在「快捷指令」App 里
struct CraftLauncherShortcuts: AppShortcutsProvider {
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

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// 同步当前状态给小组件
    static func sync(versionName: String, installedCount: Int, lastPlayed: Date?) {
        guard let d = defaults else { return }
        d.set(versionName, forKey: "widget.version")
        d.set(installedCount, forKey: "widget.count")
        if let t = lastPlayed {
            d.set(t, forKey: "widget.lastPlayed")
        }
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

    /// 检查有没有要跳转的页面
    static func consumeRoute() -> String? {
        let d = UserDefaults.standard
        guard let r = d.string(forKey: "zl.pendingRoute") else { return nil }
        d.removeObject(forKey: "zl.pendingRoute")
        return r
    }
}
