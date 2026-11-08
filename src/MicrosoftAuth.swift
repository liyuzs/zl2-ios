// ZL2-iOS · 微软账号登录
// 流程对齐 ZL2/Minecraft 官方启动器：
//   设备码 → 轮询令牌 → XBL → XSTS → Minecraft 登录 → 拉取档案
import Foundation

// MARK: - 设备码
struct DeviceCodeInfo: Sendable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int
}

// MARK: - 账号令牌
struct MSAuthToken: Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    /// 用 refresh_token 换一个新的 access_token。
    /// 微软的 access_token 默认 1 小时过期，不刷新的话每次都要重新登录。
    func refreshed(refreshToken rt: String,
                   session: URLSession = .shared) async throws -> MSAuthToken {
        let url = URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/token")!
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id=\(MicrosoftAuth.clientID)",
            "grant_type=refresh_token",
            "refresh_token=\(rt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rt)",
        ].joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw MSAuthError.network("刷新失败 HTTP \(http.statusCode)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else {
            throw MSAuthError.network("刷新返回格式错误")
        }
        return MSAuthToken(accessToken: token,
                           refreshToken: json["refresh_token"] as? String ?? rt,
                           expiresIn: json["expires_in"] as? Int ?? 3600)
    }
}

struct MinecraftProfile: Sendable {
    let id: String          // 无连字符 UUID
    let name: String
    let skins: [SkinEntry]
    let capes: [CapeEntry]
}

struct SkinEntry: Sendable {
    let id: String
    let state: String
    let url: URL
    let variant: String     // classic / slim
}

struct CapeEntry: Sendable {
    let id: String
    let state: String
    let url: URL
    let alias: String
}

enum MSAuthError: LocalizedError {
    case pending
    case slowDown
    case expired
    case declined
    case notOwned
    case xboxBanned
    case xboxMinor
    case xboxTerms
    case xboxTimeLimit
    case rateLimited
    case ipBlocked
    case network(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .pending: return "等待用户在网页完成登录…"
        case .slowDown: return "请求过快，稍后重试"
        case .expired: return "设备码已过期，请重新获取"
        case .declined: return "用户取消了登录"
        case .notOwned: return "该账号未拥有 Minecraft"
        case .xboxBanned: return "您的账号因违反 Xbox 社区规范已被封禁"
        case .xboxMinor: return "账号受限制，监护人尚未授权在线游戏"
        case .xboxTerms: return "账号尚未接受 Xbox 服务条款"
        case .xboxTimeLimit: return "账号已达到游戏时间限制"
        case .rateLimited: return "登录过于频繁，请稍后再试"
        case .ipBlocked: return "当前 IP 地址已被禁止登录"
        case .network(let m): return "网络错误：\(m)"
        case .invalidResponse(let m): return "响应异常：\(m)"
        }
    }
}

// MARK: - 登录服务
actor MicrosoftAuth {
    // Minecraft 官方启动器的公开 client id
    static let clientID = "00000000402b5328"
    static let scope = "XboxLive.signin offline_access"

    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        session = URLSession(configuration: cfg)
    }

    // MARK: 1. 设备码
    func requestDeviceCode() async throws -> DeviceCodeInfo {
        let url = URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode")!
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "client_id=\(Self.clientID)&scope=\(Self.scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? Self.scope)"
        req.httpBody = body.data(using: .utf8)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw MSAuthError.invalidResponse("devicecode HTTP")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dc = json["device_code"] as? String,
              let uc = json["user_code"] as? String,
              let vu = json["verification_uri"] as? String else {
            throw MSAuthError.invalidResponse("devicecode 字段缺失")
        }
        return DeviceCodeInfo(deviceCode: dc,
                              userCode: uc,
                              verificationUri: vu,
                              expiresIn: json["expires_in"] as? Int ?? 900,
                              interval: json["interval"] as? Int ?? 5)
    }

    // MARK: 2. 轮询令牌
    func pollToken(_ info: DeviceCodeInfo,
                   onWaiting: @Sendable @escaping () -> Void) async throws -> MSAuthToken {
        let url = URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/token")!
        let deadline = Date().addingTimeInterval(TimeInterval(info.expiresIn))

        while Date() < deadline {
            try await Task.sleep(nanoseconds: UInt64(max(info.interval, 3)) * 1_000_000_000)
            onWaiting()

            var req = URLRequest(url: url, timeoutInterval: 20)
            req.httpMethod = "POST"
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let body = [
                "client_id=\(Self.clientID)",
                "grant_type=urn:ietf:params:oauth:grant-type:device_code",
                "device_code=\(info.deviceCode)",
            ].joined(separator: "&")
            req.httpBody = body.data(using: .utf8)

            let (data, _) = try await session.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            if let token = json["access_token"] as? String {
                return MSAuthToken(accessToken: token,
                                   refreshToken: json["refresh_token"] as? String,
                                   expiresIn: json["expires_in"] as? Int ?? 3600)
            }
            switch json["error"] as? String {
            case "authorization_pending": continue
            case "slow_down": continue
            case "authorization_declined": throw MSAuthError.declined
            case "expired_token": throw MSAuthError.expired
            case "bad_verification_code": throw MSAuthError.expired
            default: continue
            }
        }
        throw MSAuthError.expired
    }

    // MARK: 3. Xbox Live 认证
    func xblAuthenticate(_ msaToken: String) async throws -> (token: String, uhs: String) {
        let url = URL(string: "https://user.auth.xboxlive.com/user/authenticate")!
        let payload: [String: Any] = [
            "Properties": [
                "AuthMethod": "RPS",
                "SiteName": "user.auth.xboxlive.com",
                "RpsTicket": "d=\(msaToken)",
            ],
            "RelyingParty": "http://auth.xboxlive.com",
            "TokenType": "JWT",
        ]
        let json = try await postJSON(url, payload)
        guard let token = json["Token"] as? String,
              let claims = json["DisplayClaims"] as? [String: Any],
              let xui = claims["xui"] as? [[String: Any]],
              let uhs = xui.first?["uhs"] as? String else {
            throw MSAuthError.invalidResponse("XBL")
        }
        return (token, uhs)
    }

    // MARK: 4. XSTS 授权
    func xstsAuthorize(_ xblToken: String) async throws -> String {
        let url = URL(string: "https://xsts.auth.xboxlive.com/xsts/authorize")!
        let payload: [String: Any] = [
            "Properties": ["SandboxId": "RETAIL", "UserTokens": [xblToken]],
            "RelyingParty": "rp://api.minecraftservices.com/",
            "TokenType": "JWT",
        ]
        do {
            let json = try await postJSON(url, payload)
            guard let token = json["Token"] as? String else {
                throw MSAuthError.invalidResponse("XSTS token")
            }
            return token
        } catch MSAuthError.invalidResponse(let m) where m.contains("401") {
            throw MSAuthError.xboxTerms
        }
    }

    // MARK: 5. Minecraft 登录
    func minecraftLogin(xsts: String, uhs: String) async throws -> String {
        let url = URL(string: "https://api.minecraftservices.com/authentication/login_with_xbox")!
        let payload = ["identityToken": "XBL3.0 x=\(uhs);\(xsts)"]
        let json = try await postJSON(url, payload)
        guard let token = json["access_token"] as? String else {
            throw MSAuthError.invalidResponse("Minecraft token")
        }
        return token
    }

    // MARK: 6. 拉取档案（含皮肤、披风）
    func fetchProfile(mcToken: String) async throws -> MinecraftProfile {
        var req = URLRequest(url: URL(string: "https://api.minecraftservices.com/minecraft/profile")!, timeoutInterval: 20)
        req.setValue("Bearer \(mcToken)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw MSAuthError.invalidResponse("profile") }
        if http.statusCode == 404 { throw MSAuthError.notOwned }
        guard http.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String,
              let name = json["name"] as? String else {
            throw MSAuthError.invalidResponse("profile 字段")
        }
        let skins = (json["skins"] as? [[String: Any]] ?? []).compactMap { s -> SkinEntry? in
            guard let urlStr = s["url"] as? String, let url = URL(string: urlStr) else { return nil }
            return SkinEntry(id: s["id"] as? String ?? "",
                             state: s["state"] as? String ?? "",
                             url: url,
                             variant: s["variant"] as? String ?? "classic")
        }
        let capes = (json["capes"] as? [[String: Any]] ?? []).compactMap { c -> CapeEntry? in
            guard let urlStr = c["url"] as? String, let url = URL(string: urlStr) else { return nil }
            return CapeEntry(id: c["id"] as? String ?? "",
                             state: c["state"] as? String ?? "",
                             url: url,
                             alias: c["alias"] as? String ?? "")
        }
        return MinecraftProfile(id: id, name: name, skins: skins, capes: capes)
    }

    // MARK: 完整登录流程
    func signIn(onDeviceCode: @Sendable @escaping (DeviceCodeInfo) -> Void,
                onWaiting: @Sendable @escaping () -> Void) async throws -> (account: Account, profile: MinecraftProfile) {
        let info = try await requestDeviceCode()
        onDeviceCode(info)

        let msa = try await pollToken(info, onWaiting: onWaiting)
        let xbl = try await xblAuthenticate(msa.accessToken)
        let xsts = try await xstsAuthorize(xbl.token)
        let mcToken = try await minecraftLogin(xsts: xsts, uhs: xbl.uhs)
        let profile = try await fetchProfile(mcToken: mcToken)

        var acc = Account.microsoft(profile: profile, accessToken: mcToken)
        acc.refreshToken = msa.refreshToken
        return (acc, profile)
    }

    // MARK: 换皮肤
    func uploadSkin(mcToken: String, pngData: Data, variant: String) async throws {
        let url = URL(string: "https://api.minecraftservices.com/minecraft/profile/skins")!
        let boundary = "----ZL2\(UUID().uuidString)"
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.setValue("Bearer \(mcToken)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"variant\"\r\n\r\n\(variant)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"skin.png\"\r\nContent-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(pngData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 || http.statusCode == 204 else {
            throw MSAuthError.invalidResponse("上传皮肤失败")
        }
    }

    // MARK: 换披风
    func setCape(mcToken: String, capeID: String) async throws {
        let url = URL(string: "https://api.minecraftservices.com/minecraft/profile/capes/active")!
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(mcToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["capeId": capeID])
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MSAuthError.invalidResponse("设置披风失败")
        }
    }

    // MARK: 工具
    private func postJSON(_ url: URL, _ payload: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw MSAuthError.invalidResponse("无响应") }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw MSAuthError.invalidResponse("\(http.statusCode)")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MSAuthError.invalidResponse("非 JSON 响应")
        }
        return json
    }
}
