//
//  AccountService.swift
//  ZL2-iOS · 账户体系（离线 / 微软 / 外置认证）+ 纯 Swift MD5
//
//  设计说明：
//  - 只用 Foundation，不依赖 CryptoKit / CommonCrypto / 任何第三方库
//  - 离线账号 UUID 遵循 Minecraft 规则：MD5("OfflinePlayer:<name>") → UUID v3
//  - 账户通过 UserDefaults + JSONEncoder 持久化
//  - 面向 iOS 16+
//

import Foundation
import Combine

// MARK: - 账户类型

/// 账户来源。rawValue 会落盘/存库，改名会影响已有数据，不要随意改。
enum AccountType: String, Codable, CaseIterable, Sendable {
    case offline
    case microsoft
    case authlib

    /// 界面上展示的名字
    var displayName: String {
        switch self {
        case .offline:   return "离线账号"
        case .microsoft: return "微软账号"
        case .authlib:   return "外置认证"
        }
    }

    /// 是否需要联网换取 accessToken
    var requiresNetwork: Bool {
        switch self {
        case .offline:               return false
        case .microsoft, .authlib:   return true
        }
    }
}

// MARK: - 账户模型

/// 一个已登录账户。
///
/// - `uuid` 是 Minecraft 风格的 32 位小写无横线字符串（如 `b50ad385829d3141a2167e7d7539ba7f`），
///   需要带横线的标准形态时用 `uuidDashed`。
struct Account: Codable, Identifiable, Equatable, Sendable {
    /// 本地标识，和游戏内 UUID 无关
    var id: UUID
    var type: AccountType
    var username: String
    /// 32 位无横线
    var uuid: String
    /// 离线账号为 nil；微软 / 外置认证为真实 token
    var accessToken: String?
    /// 微软账号的刷新令牌，用于静默续期
    var refreshToken: String?

    init(id: UUID = UUID(),
         type: AccountType,
         username: String,
         uuid: String,
         accessToken: String? = nil,
         refreshToken: String? = nil) {
        self.id = id
        self.type = type
        self.username = username
        self.uuid = AccountUUID.compact(from: uuid)
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    /// 由微软登录返回的档案构造账号
    static func microsoft(profile: MinecraftProfile, accessToken: String) -> Account {
        Account(type: .microsoft,
                username: profile.name,
                uuid: profile.id,
                accessToken: accessToken)
    }

    /// 带横线的标准 UUID 字符串（展示 / 日志用）
    var uuidDashed: String { AccountUUID.dashed(fromCompact: uuid) }

    /// 是否已过期之类的判断留给具体认证服务，这里只表示有没有 token
    var hasValidToken: Bool {
        guard let token = accessToken else { return false }
        return !token.isEmpty
    }
}

// MARK: - UUID 字符串格式互转

enum AccountUUID {
    /// 去掉横线并转小写
    static func compact(from dashed: String) -> String {
        dashed.replacingOccurrences(of: "-", with: "").lowercased()
    }

    /// 32 位无横线 → 标准 8-4-4-4-12
    static func dashed(fromCompact compact: String) -> String {
        let hex = compact.replacingOccurrences(of: "-", with: "").lowercased()
        guard hex.count == 32 else { return hex }
        let chars = Array(hex)
        func part(_ range: Range<Int>) -> String { String(chars[range]) }
        return "\(part(0..<8))-\(part(8..<12))-\(part(12..<16))-\(part(16..<20))-\(part(20..<32))"
    }
}

// MARK: - 错误

enum AccountError: LocalizedError, Equatable {
    /// 用户名不是 1~16 位 [A-Za-z0-9_]
    case invalidUsername
    /// 用户名为空
    case emptyName
    /// 当前流程不支持该账户类型
    case unsupportedAccountType(AccountType)
    /// 需要 token 但没有
    case missingAccessToken
    /// 持久化写入失败
    case storageFailure(String)

    var errorDescription: String? {
        switch self {
        case .invalidUsername:
            return "用户名不合法"
        case .emptyName:
            return "请输入用户名"
        case .unsupportedAccountType(let type):
            return "暂不支持\(type.displayName)"
        case .missingAccessToken:
            return "登录凭证缺失，请重新登录"
        case .storageFailure(let reason):
            return "账户保存失败：\(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidUsername:
            return "只允许 1~16 位英文、数字和下划线"
        case .emptyName:
            return "输入一个 1~16 位的玩家名"
        case .unsupportedAccountType, .missingAccessToken:
            return "换一种账户类型，或重新登录"
        case .storageFailure:
            return "检查设备存储空间后重试"
        }
    }
}

// MARK: - 纯 Swift MD5（RFC 1321）

/// 轻量 MD5 实现，只用于算离线 UUID。
/// 不追求性能，但保证与 RFC 1321 / CommonCrypto / python hashlib 结果一致。
enum MD5 {
    /// 每轮左移位数
    private static let shiftTable: [UInt32] = [
        7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
        5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
        4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
        6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
    ]

    /// K[i] = floor(2^32 * |sin(i)|)，i 从 1 开始，也就是 RFC 1321 里的 T 表。
    /// 已用 python hashlib 逐条对照验证（""/abc/"message digest"/"OfflinePlayer:Notch" 全部一致）。
    private static let constantTable: [UInt32] = [
        0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
        0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
        0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
        0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
        0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
        0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
        0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
        0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
        0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
        0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
        0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
        0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
        0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
        0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
        0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
        0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
    ]

    /// 16 字节摘要
    static func digest(_ message: [UInt8]) -> [UInt8] {
        // 1. 补位：追加 0x80，再补 0 到 length ≡ 56 (mod 64)
        var data = message
        let bitLength = UInt64(message.count) * 8
        data.append(0x80)
        while data.count % 64 != 56 {
            data.append(0x00)
        }
        // 2. 追加 64 位小端比特长度
        for index in 0..<8 {
            let shifted = bitLength >> (8 * index)
            data.append(UInt8(truncatingIfNeeded: shifted))
        }

        // 3. 初始向量
        var a0: UInt32 = 0x67452301
        var b0: UInt32 = 0xefcdab89
        var c0: UInt32 = 0x98badcfe
        var d0: UInt32 = 0x10325476

        var offset = 0
        while offset < data.count {
            // 当前 512 位分组的 16 个 32 位小端字
            var words = [UInt32](repeating: 0, count: 16)
            for j in 0..<16 {
                let base = offset + j * 4
                words[j] = UInt32(data[base])
                    | (UInt32(data[base + 1]) << 8)
                    | (UInt32(data[base + 2]) << 16)
                    | (UInt32(data[base + 3]) << 24)
            }

            var a = a0, b = b0, c = c0, d = d0

            for i in 0..<64 {
                var f: UInt32
                var g: Int
                switch i {
                case 0..<16:
                    f = (b & c) | (~b & d)
                    g = i
                case 16..<32:
                    f = (d & b) | (~d & c)
                    g = (5 * i + 1) % 16
                case 32..<48:
                    f = b ^ c ^ d
                    g = (3 * i + 5) % 16
                default:
                    f = c ^ (b | ~d)
                    g = (7 * i) % 16
                }

                let sum = a &+ f &+ constantTable[i] &+ words[g]
                let rotated = rotateLeft(sum, by: shiftTable[i])

                let temp = d
                d = c
                c = b
                b = b &+ rotated
                a = temp
            }

            a0 = a0 &+ a
            b0 = b0 &+ b
            c0 = c0 &+ c
            d0 = d0 &+ d

            offset += 64
        }

        // 4. 输出：四个字按小端拼成 16 字节
        var result = [UInt8]()
        result.reserveCapacity(16)
        for word in [a0, b0, c0, d0] {
            result.append(UInt8(truncatingIfNeeded: word))
            result.append(UInt8(truncatingIfNeeded: word >> 8))
            result.append(UInt8(truncatingIfNeeded: word >> 16))
            result.append(UInt8(truncatingIfNeeded: word >> 24))
        }
        return result
    }

    static func digest(_ text: String) -> [UInt8] {
        digest(Array(text.utf8))
    }

    /// 32 位小写十六进制摘要
    static func hexDigest(_ text: String) -> String {
        hexString(digest(text))
    }

    static func hexString(_ bytes: [UInt8]) -> String {
        let alphabet = Array("0123456789abcdef")
        var out = ""
        out.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            out.append(alphabet[Int(byte >> 4)])
            out.append(alphabet[Int(byte & 0x0f)])
        }
        return out
    }

    @inline(__always)
    private static func rotateLeft(_ value: UInt32, by amount: UInt32) -> UInt32 {
        let shift = amount & 31
        return (value << shift) | (value >> (32 - shift))
    }

    /// 自检：与 RFC 1321 / python hashlib 的已知结果比对。
    /// `MD5.selfCheck() == true` 说明补位、字节序和常量表都正确。
    static func selfCheck() -> Bool {
        hexDigest("") == "d41d8cd98f00b204e9800998ecf8427e"
            && hexDigest("abc") == "900150983cd24fb0d6963f7d28e17f72"
            && hexDigest("message digest") == "f96b697d7cb7938d525a2f31aaf161d0"
            && hexDigest("OfflinePlayer:Notch") == "b50ad385829da141a2167e7d7539ba7f"
    }
}

// MARK: - 离线账户工厂

/// 离线账户：只用玩家名，UUID 由名字推导，换设备也能保持稳定。
struct OfflineAccountFactory {
    /// 玩家名规则：1~16 位英文、数字、下划线
    static let usernamePattern = "^[A-Za-z0-9_]{1,16}$"
    static let maxUsernameLength = 16

    static func isValid(username: String) -> Bool {
        guard !username.isEmpty, username.count <= maxUsernameLength else { return false }
        return username.range(of: usernamePattern, options: .regularExpression) != nil
    }

    /// 校验并返回规整后的名字；不合法直接抛 `AccountError`
    static func validatedUsername(_ username: String) throws -> String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw AccountError.emptyName }
        guard isValid(username: trimmed) else { throw AccountError.invalidUsername }
        return trimmed
    }

    /// 创建离线账户（不落盘，落盘交给 `AccountStore.addOffline`）
    static func makeAccount(username: String) throws -> Account {
        let name = try validatedUsername(username)
        return Account(type: .offline,
                       username: name,
                       uuid: offlineUUIDCompact(forUsername: name),
                       accessToken: nil)
    }

    /// `MD5("OfflinePlayer:" + name)` → 16 字节，再打上 UUID v3 / RFC 4122 variant 位
    static func offlineUUIDBytes(forUsername username: String) -> [UInt8] {
        let digestBytes = MD5.digest("OfflinePlayer:" + username)
        var bytes = Array(digestBytes.prefix(16))
        guard bytes.count == 16 else {
            return [UInt8](repeating: 0, count: 16)
        }
        bytes[6] = (bytes[6] & 0x0f) | 0x30   // version 3（MD5 命名空间 UUID）
        bytes[8] = (bytes[8] & 0x3f) | 0x80   // RFC 4122 variant
        return bytes
    }

    /// 32 位无横线（`Account.uuid` 用这个）
    static func offlineUUIDCompact(forUsername username: String) -> String {
        MD5.hexString(offlineUUIDBytes(forUsername: username))
    }

    /// 标准带横线（8-4-4-4-12）
    static func offlineUUID(forUsername username: String) -> String {
        AccountUUID.dashed(fromCompact: offlineUUIDCompact(forUsername: username))
    }
}

// MARK: - 账户服务协议

/// 账户的增删查与持久化。主线程使用。
protocol AccountProviding: AnyObject {
    /// 新增一个离线账户，成功后它成为当前账户
    func addOffline(name: String) throws -> Account
    /// 当前选中的账户
    var current: Account? { get }
    /// 新增或更新（按 id 匹配），并设为当前账户
    func save(_ account: Account)
    /// 清空所有账户
    func clear()
}

// MARK: - 账户存储（UserDefaults 持久化）

/// 用 UserDefaults 存 JSON 数组。只存公开字段，token 也在里面（沙盒内，够用）。
final class AccountStore: ObservableObject, AccountProviding {

    /// 全局单例，界面默认用它
    static let shared = AccountStore()

    /// 账号列表变化时通知界面刷新（原来改完不重绘）
    @Published private(set) var accounts: [Account] = []

    private enum Keys {
        static let accounts = "zl2.account.accounts"
        static let current = "zl2.account.current"
        // 兼容 HomeScreen 里已有的 @AppStorage
        static let legacyName = "accountName"
        static let legacyType = "accountType"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var currentID: UUID?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: AccountProviding

    var current: Account? {
        if let currentID, let account = accounts.first(where: { $0.id == currentID }) {
            return account
        }
        return accounts.first
    }

    func addOffline(name: String) throws -> Account {
        let account = try OfflineAccountFactory.makeAccount(username: name)
        save(account)
        return account
    }

    func save(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }
        currentID = account.id
        persist()
    }

    func clear() {
        accounts = []
        currentID = nil
        defaults.removeObject(forKey: Keys.accounts)
        defaults.removeObject(forKey: Keys.current)
        defaults.removeObject(forKey: Keys.legacyName)
        defaults.removeObject(forKey: Keys.legacyType)
    }

    // MARK: 额外便利方法

    func select(_ account: Account) {
        guard accounts.contains(where: { $0.id == account.id }) else { return }
        currentID = account.id
        persist()
    }

    func remove(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        if currentID == account.id { currentID = accounts.first?.id }
        persist()
    }

    func removeAll() {
        clear()
    }

    // MARK: 持久化

    private func load() {
        if let data = defaults.data(forKey: Keys.accounts),
           let saved = try? decoder.decode([Account].self, from: data) {
            accounts = saved
        }
        if let raw = defaults.string(forKey: Keys.current) {
            currentID = UUID(uuidString: raw)
        }
        // 老版本只有 accountName / accountType 两个键：迁移成一条离线账户
        if accounts.isEmpty,
           let legacyName = defaults.string(forKey: Keys.legacyName),
           !legacyName.isEmpty,
           let migrated = try? OfflineAccountFactory.makeAccount(username: legacyName) {
            accounts = [migrated]
            currentID = migrated.id
        }
    }

    private func persist() {
        if let data = try? encoder.encode(accounts) {
            defaults.set(data, forKey: Keys.accounts)
        }
        if let currentID {
            defaults.set(currentID.uuidString, forKey: Keys.current)
        } else {
            defaults.removeObject(forKey: Keys.current)
        }
        // 同步回首页那两个 @AppStorage 键，保证界面显示一致
        if let account = current {
            defaults.set(account.username, forKey: Keys.legacyName)
            defaults.set(account.type.rawValue, forKey: Keys.legacyType)
        }
    }
}

// MARK: - 微软 OAuth（只定义接口与数据结构，不实现真实请求）

struct MicrosoftOAuthConfiguration: Codable, Sendable, Equatable {
    var clientId: String
    var redirectURI: String
    var scopes: [String]
    var authorizeEndpoint: URL
    var tokenEndpoint: URL
    var xboxLiveEndpoint: URL
    var xstsEndpoint: URL

    static let minecraft = MicrosoftOAuthConfiguration(
        clientId: "00000000402b5328",
        redirectURI: "https://login.live.com/oauth20_desktop.srf",
        scopes: ["XboxLive.signin", "offline_access"],
        authorizeEndpoint: URL(string: "https://login.live.com/oauth20_authorize.srf")!,
        tokenEndpoint: URL(string: "https://login.live.com/oauth20_token.srf")!,
        xboxLiveEndpoint: URL(string: "https://user.auth.xboxlive.com/user/authenticate")!,
        xstsEndpoint: URL(string: "https://xsts.auth.xboxlive.com/xsts/authorize")!
    )
}

/// OAuth 拿到的令牌集合
struct MicrosoftTokenSet: Codable, Sendable, Equatable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?

    func isExpired(now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return now >= expiresAt
    }
}

/// 微软账号最终映射出的 Minecraft 身份
struct MicrosoftProfile: Codable, Sendable, Equatable {
    var username: String
    /// 带横线的 UUID
    var uuid: String
    var token: MicrosoftTokenSet
}

/// 微软登录流程。实现方负责 OAuth → Xbox Live → XSTS → Minecraft 三步换取。
protocol MicrosoftAuthenticating: AnyObject {
    func signIn(configuration: MicrosoftOAuthConfiguration) async throws -> MicrosoftProfile
    func refresh(profile: MicrosoftProfile) async throws -> MicrosoftProfile
    func signOut()
}

// MARK: - 外置认证（authlib-injector / yggdrasil）

struct AuthlibConfiguration: Codable, Sendable, Equatable {
    /// 认证服务器地址，如 https://littleskin.cn/api/yggdrasil
    var serverURL: URL
    var serverName: String?

    static let littleSkin = AuthlibConfiguration(
        serverURL: URL(string: "https://littleskin.cn/api/yggdrasil")!,
        serverName: "LittleSkin"
    )
}

struct AuthlibCredentials: Sendable, Equatable {
    var username: String
    var password: String
}

/// 外置认证会话（yggdrasil 的 accessToken / clientToken）
struct AuthlibSession: Codable, Sendable, Equatable {
    var profileName: String
    var profileUUID: String   // 32 位无横线
    var accessToken: String
    var clientToken: String
    var configuration: AuthlibConfiguration
}

/// 外置登录流程（authlib-injector 的 yggdrasil 协议）
protocol AuthlibAuthenticating: AnyObject {
    func signIn(configuration: AuthlibConfiguration,
                credentials: AuthlibCredentials) async throws -> AuthlibSession
    func refresh(session: AuthlibSession) async throws -> AuthlibSession
    func invalidate(session: AuthlibSession) async throws
}

// MARK: - 认证结果 → Account

extension Account {
    init(microsoft profile: MicrosoftProfile) {
        self.init(type: .microsoft,
                  username: profile.username,
                  uuid: AccountUUID.compact(from: profile.uuid),
                  accessToken: profile.token.accessToken)
    }

    init(authlib session: AuthlibSession) {
        self.init(type: .authlib,
                  username: session.profileName,
                  uuid: AccountUUID.compact(from: session.profileUUID),
                  accessToken: session.accessToken)
    }
}
