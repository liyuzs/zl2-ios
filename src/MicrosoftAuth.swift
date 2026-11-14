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
    // 第175轮删掉 `.slowDown` —— 它和 `.rateLimited`（"登录过于频繁，请稍后再试"）语义重复，
    // 而 429 现在走的是 `.rateLimited`。两个都在只会让人不知道该用哪个。
    case expired
    case declined
    case notOwned
    // **第175轮标注**：下面这四个 case 的文案备好了，但**当前没有任何地方解析 Xbox 错误码**，
    // 所以它们永远不会被抛出 —— 用户遇到"账号被封/未成年限制/未接受条款/时长用尽"时，
    // 看到的仍是通用的「响应异常：xxx」。
    // 保留而不是删掉：它们描述的是真实存在的情况，删了将来实现解析时还要重想文案。
    // 要实现的话，入口在这里：解析 Xbox Live 认证失败响应里的 XErr 码（2148916xxx）。
    case xboxBanned      // 未实现：当前没有解析 Xbox 错误码
    case xboxMinor       // 未实现：同上
    case xboxTerms       // 未实现：同上
    case xboxTimeLimit   // 未实现：同上
    case rateLimited
    case ipBlocked
    case network(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .pending: return "等待用户在网页完成登录…"

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

        // 轮询间隔必须可变：RFC 8628 规定服务端返回 `slow_down` 时，
        // 客户端要把间隔**增加 5 秒**。原来这里是常量（max(info.interval, 3)），
        // `slow_down` 也当 `authorization_pending` 一路 continue ——
        // 服务端会持续要求放慢，直到 deadline 耗尽才报 "expired"。
        // 表现就是：用户在手机上明明点完了授权，登录却失败。
        var pollInterval = max(info.interval, 3)

        while Date() < deadline {
            try await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000_000)
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
            case "authorization_pending":
                continue
            case "slow_down":
                // 服务端明确要求放慢：按 RFC 8628 加 5 秒，否则它会一直拒绝
                pollInterval += 5
                NSLog("[ZL2] 微软登录要求放慢轮询，间隔调到 %d 秒", pollInterval)
                continue
            case "authorization_declined": throw MSAuthError.declined
            case "expired_token": throw MSAuthError.expired
            case "bad_verification_code": throw MSAuthError.expired
            default:
                // 未知错误也记一下，否则只会表现为"转很久然后说过期"
                NSLog("[ZL2] 微软登录返回未知错误：%@", (json["error"] as? String) ?? "（无 error 字段）")
                continue
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
        // **第174轮**：原来 401/403 一律抛 `.invalidResponse("\(statusCode)")` →
        // 用户看到「响应异常：403」，不知道怎么办。而 MSAuthError 里已经有专门的说法：
        //   · 401 凭据被拒 → 让用户重新跑一次设备码登录
        //   · 403 微软按 IP 拒绝（代理/机房 IP 常见）→ 提示换网络
        //   · 429 频率限制 → 原来根本没拦，会掉到「非 JSON 响应」这种更莫名的话
        switch http.statusCode {
        case 401:
            throw MSAuthError.expired
        case 403:
            throw MSAuthError.ipBlocked
        case 429:
            throw MSAuthError.rateLimited
        default:
            break
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MSAuthError.invalidResponse("非 JSON 响应")
        }
        return json
    }
}
