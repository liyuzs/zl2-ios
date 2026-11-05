// CraftLauncher · 皮肤站（Yggdrasil / 外置认证）
// 支持 LittleSkin、Blessing Skin 等所有标准 Yggdrasil 皮肤站
import Foundation

// MARK: - 数据

struct ZLYggdrasilProfile: Identifiable, Equatable {
    var id: String          // 去掉横线的 UUID
    var name: String        // 游戏内名字
    var skinURL: URL?
    var capeURL: URL?
}

enum ZLYggdrasilError: LocalizedError {
    case invalidServer
    case badCredentials
    case network(String)
    case noProfile

    var errorDescription: String? {
        switch self {
        case .invalidServer: return "皮肤站地址不对，应该形如 https://littleskin.cn/api/yggdrasil"
        case .badCredentials: return "邮箱或密码错误"
        case .network(let m): return "网络错误：\(m)"
        case .noProfile: return "这个账号还没有创建角色，请先在皮肤站网页里创建"
        }
    }
}

// MARK: - 客户端

struct ZLYggdrasilClient {
    let server: String   // 例如 https://littleskin.cn/api/yggdrasil
    private let session = URLSession.shared

    /// 规范化地址：补 https、去掉末尾斜杠
    static func normalize(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.lowercased().hasPrefix("http") { s = "https://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        // 用户可能只填了域名，补上标准路径
        if !s.lowercased().contains("/api/yggdrasil") {
            s += "/api/yggdrasil"
        }
        guard URL(string: s) != nil else { return nil }
        return s
    }

    /// 用邮箱 + 密码登录，返回角色信息（含皮肤地址）
    func login(email: String, password: String) async throws -> ZLYggdrasilProfile {
        guard let url = URL(string: server + "/authserver/authenticate") else {
            throw ZLYggdrasilError.invalidServer
        }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "agent": ["name": "Minecraft", "version": 1],
            "username": email,
            "password": password,
            "requestUser": false
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw ZLYggdrasilError.network("没有响应")
        }
        if http.statusCode == 403 {
            throw ZLYggdrasilError.badCredentials
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ZLYggdrasilError.network("HTTP \(http.statusCode)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["selectedProfile"] as? [String: Any],
              let id = profile["id"] as? String,
              let name = profile["name"] as? String else {
            throw ZLYggdrasilError.noProfile
        }

        // 拉皮肤
        let skin = try? await fetchSkin(uuid: id)
        return ZLYggdrasilProfile(id: id, name: name,
                                  skinURL: skin?.skin, capeURL: skin?.cape)
    }

    /// 查询皮肤地址
    func fetchSkin(uuid: String) async throws -> (skin: URL?, cape: URL?) {
        guard let url = URL(string: server + "/sessionserver/session/minecraft/profile/\(uuid)")
        else { throw ZLYggdrasilError.invalidServer }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("ZL2-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let props = json["properties"] as? [[String: Any]] else { return (nil, nil) }

        for p in props where (p["name"] as? String) == "textures" {
            guard let b64 = p["value"] as? String,
                  let decoded = Data(base64Encoded: b64),
                  let obj = try? JSONSerialization.jsonObject(with: decoded) as? [String: Any],
                  let textures = obj["textures"] as? [String: Any] else { continue }
            var skin: URL?
            var cape: URL?
            if let s = textures["SKIN"] as? [String: Any],
               let u = s["url"] as? String { skin = URL(string: u) }
            if let c = textures["CAPE"] as? [String: Any],
               let u = c["url"] as? String { cape = URL(string: u) }
            return (skin, cape)
        }
        return (nil, nil)
    }

    /// 下载皮肤 PNG 并存到游戏目录（离线模式下也能用）
    @discardableResult
    static func downloadSkin(_ url: URL, to gameDir: URL) async -> Bool {
        do {
            var req = URLRequest(url: url, timeoutInterval: 20)
            req.setValue("ZL2-iOS/1.0", forHTTPHeaderField: "User-Agent")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  data.count > 100 else { return false }
            let fm = FileManager.default
            try? fm.createDirectory(at: gameDir, withIntermediateDirectories: true)
            let dst = gameDir.appendingPathComponent("skin.png")
            try data.write(to: dst)
            return true
        } catch {
            return false
        }
    }
}
