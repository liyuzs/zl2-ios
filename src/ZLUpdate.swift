// CraftLauncher · 更新检查与反馈
// 从 GitHub Releases 读最新版本，与当前版本对比
import SwiftUI
import UIKit

// MARK: - 版本信息

struct ZLUpdateInfo: Equatable {
    let version: String        // 如 "0.2.0"
    let tag: String            // 如 "v0.2.0"
    let notes: String          // 更新说明
    let downloadURL: String    // IPA 下载地址
    let releaseURL: String     // Release 页面
    let publishedAt: Date
}

// MARK: - 检查器

@MainActor
final class ZLUpdateChecker: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(ZLUpdateInfo)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    /// 当前版本（来自 Info.plist）
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
    static var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    private let repo = "liyuzs/zl2-ios"

    /// 检查更新（手动或自动都可以调）
    func check() async {
        guard state != .checking else { return }
        state = .checking

        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            state = .failed("地址错误")
            return
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("CraftLauncher/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                state = .failed("网络异常")
                return
            }
            // 没有 Release 时 GitHub 返回 404，视为已是最新
            if http.statusCode == 404 {
                state = .upToDate
                return
            }
            guard http.statusCode == 200 else {
                state = .failed("服务器返回 \(http.statusCode)")
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                state = .failed("数据格式错误")
                return
            }

            let tag = (json["tag_name"] as? String) ?? ""
            let name = (json["name"] as? String) ?? tag
            let body = (json["body"] as? String) ?? ""
            let htmlURL = (json["html_url"] as? String) ?? ""
            let published = (json["published_at"] as? String) ?? ""

            // 从 assets 里找 IPA
            var ipaURL = ""
            if let assets = json["assets"] as? [[String: Any]] {
                for a in assets {
                    if let n = a["name"] as? String, n.lowercased().hasSuffix(".ipa"),
                       let u = a["browser_download_url"] as? String {
                        ipaURL = u
                        break
                    }
                }
            }
            if ipaURL.isEmpty {
                ipaURL = "https://github.com/\(repo)/releases/latest/download/CraftLauncher.ipa"
            }

            // 版本号：去掉前缀 v，取数字部分
            let remoteVersion = Self.normalize(tag.isEmpty ? name : tag)
            let current = Self.normalize(Self.currentVersion)

            let info = ZLUpdateInfo(
                version: remoteVersion,
                tag: tag,
                notes: body.trimmingCharacters(in: .whitespacesAndNewlines),
                downloadURL: ipaURL,
                releaseURL: htmlURL,
                publishedAt: Self.parseDate(published)
            )

            if Self.isNewer(remote: remoteVersion, than: current) {
                state = .available(info)
            } else {
                state = .upToDate
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - 版本比较

    /// 把 "v0.2.1" 或 "0.2.1" 统一成 "0.2.1"
    static func normalize(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.lowercased().hasPrefix("v") { t.removeFirst() }
        // 只保留数字和点
        let allowed = Set("0123456789.")
        t = String(t.filter { allowed.contains($0) })
        return t.isEmpty ? "0" : t
    }

    /// remote 是否比 current 新
    static func isNewer(remote: String, than current: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        let n = max(r.count, c.count)
        for i in 0..<n {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv > cv { return true }
            if rv < cv { return false }
        }
        return false
    }

    private static func parseDate(_ s: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s) ?? Date()
    }
}

// MARK: - 更新卡片（放关于页）

struct ZLUpdateCard: View {
    @StateObject private var checker = ZLUpdateChecker()
    @State private var toast: String?

    var body: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("版本与更新")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Spacer()
                    Text("v\(ZLUpdateChecker.currentVersion) (\(ZLUpdateChecker.currentBuild))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(ZLTheme.textSecond)
                }

                statusRow

                HStack(spacing: 10) {
                    // 检查更新
                    Button {
                        ZLHaptic.light()
                        Task { await checker.check() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12))
                            Text("检查更新").font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(ZLTheme.primaryDeep)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(ZLTheme.primarySoft)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(ZLQPressStyle(scale: 0.94, haptic: true))
                    .disabled(checker.state == .checking)

                    // 反馈
                    Button {
                        ZLHaptic.light()
                        openFeedback()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.bubble")
                                .font(.system(size: 12))
                            Text("反馈区").font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(ZLTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(ZLTheme.surfaceAlt)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(ZLQPressStyle(scale: 0.94, haptic: true))

                    Spacer()
                }

                if case .available(let info) = checker.state {
                    Divider().padding(.vertical, 2)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("发现新版本 v\(info.version)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ZLTheme.primaryDeep)
                        if !info.notes.isEmpty {
                            Text(info.notes)
                                .font(.system(size: 11))
                                .foregroundStyle(ZLTheme.textSecond)
                                .lineLimit(6)
                        }
                        HStack(spacing: 10) {
                            Button("打开下载页") {
                                if let u = URL(string: info.releaseURL) { UIApplication.shared.open(u) }
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ZLTheme.primaryDeep)

                            Button("复制下载链接") {
                                toast = ZLClipboard.copy(info.downloadURL, label: "下载链接")
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(ZLTheme.textSecond)
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
        .task {
            // 打开关于页时自动检查一次
            await checker.check()
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.8)))
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { self.toast = nil }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch checker.state {
        case .idle:
            Text("点「检查更新」看看有没有新版本")
                .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
        case .checking:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.6)
                Text("正在检查…").font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
            }
        case .upToDate:
            Text("已是最新版本")
                .font(.system(size: 11)).foregroundStyle(ZLTheme.success)
        case .available(let info):
            Text("有新版本 v\(info.version) 可用")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(ZLTheme.primaryDeep)
        case .failed(let msg):
            Text("检查失败：\(msg)")
                .font(.system(size: 11)).foregroundStyle(ZLTheme.danger)
        }
    }

    private func openFeedback() {
        // 带上版本信息，方便排查
        let body = """

---
**设备信息**（自动填写，请保留）
- 应用版本：v\(ZLUpdateChecker.currentVersion) (\(ZLUpdateChecker.currentBuild))
- 系统版本：iOS \(UIDevice.current.systemVersion)
- 设备型号：\(UIDevice.current.model)
"""
        let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr = "https://github.com/liyuzs/zl2-ios/issues/new?labels=feedback&title=&body=\(encoded)"
        if let u = URL(string: urlStr) {
            UIApplication.shared.open(u)
        }
    }
}
