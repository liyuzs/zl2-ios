// ZL2-iOS · 关于与开源许可
// 对照：ZL2 的 AboutInfoScreen.kt（致谢 / 赞助 / 依赖库 / 已加载插件）
//       + LicenseScreen.kt（许可证全文查看）
// 说明：iOS 版把「关于」和「许可」合并为一页，因为两边内容高度重合；
//       版权声明、第三方组件、许可证要点与全文入口都落在这里，不依赖网络。
import SwiftUI
import UIKit

// MARK: - 数据模型

private struct ZLLicenseComponent: Identifiable {
    let id = UUID()
    let name: String
    let copyright: String
    let license: String
    let url: String?
}

private struct ZLLicenseDoc: Identifiable {
    let id: String            // 许可证名
    let title: String
    let points: [String]      // 要点（中文）
    let fullText: String?     // 短许可证直接内置全文
    let fullTextURL: String   // 长许可证给官方全文链接
}

// MARK: - 页面

struct LicenseScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var shownDoc: ZLLicenseDoc?

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    private var osVersion: String {
        UIDevice.current.systemVersion
    }

    // 依据 ZL2 的 library/_Libraries.kt + iOS 工程实际链接的库整理
    private let components: [ZLLicenseComponent] = [
        .init(name: "CraftLauncher（本应用）",
              copyright: "Copyright © 2026 liyuzs —— 非官方 iOS 移植版",
              license: "GPL-3.0",
              url: "https://github.com/liyuzs/zl2-ios"),
        .init(name: "Zalith Launcher 2",
              copyright: "Copyright © 2025-2026 MovTery 及贡献者",
              license: "GPL-3.0",
              url: "https://github.com/ZalithLauncher/ZalithLauncher2"),
        .init(name: "Amethyst",
              copyright: "Copyright © 2022-2026 Angel Aura MC",
              license: "GPL-3.0",
              url: "https://github.com/AngelAuraMC/Amethyst-Android"),
        .init(name: "Terracotta（陶瓦联机）",
              copyright: "Copyright © 2023-2026 BurningTNT",
              license: "AGPL-3.0",
              url: "https://github.com/burningtnt/Terracotta"),
        .init(name: "LWJGL 3",
              copyright: "Copyright © 2012-present Lightweight Java Game Library",
              license: "BSD-3-Clause",
              url: "https://github.com/LWJGL/lwjgl3"),
        .init(name: "OpenJDK 17",
              copyright: "Copyright © Oracle 与 OpenJDK 贡献者",
              license: "GPL-2.0+CE",
              url: "https://openjdk.org/"),
        .init(name: "Mesa / gl4es",
              copyright: "Copyright © The Mesa Authors；gl4es 作者 Sebastien Chevalier 等",
              license: "MIT",
              url: "https://github.com/PojavLauncherTeam/gl4es"),
        .init(name: "MobileGlues",
              copyright: "Copyright © 2025-2026 MobileGL-Dev",
              license: "LGPL-2.1",
              url: "https://github.com/MobileGL-Dev/MobileGlues"),
        .init(name: "MoltenVK",
              copyright: "Copyright © 2015-2026 The Brenwill Workshop Ltd.",
              license: "Apache-2.0",
              url: "https://github.com/KhronosGroup/MoltenVK"),
        .init(name: "OpenAL Soft",
              copyright: "Copyright © 2004-2026 OpenAL Soft 贡献者",
              license: "LGPL-2.1",
              url: "https://openal-soft.org/"),
        .init(name: "AFNetworking",
              copyright: "Copyright © 2011-2026 Alamofire Software Foundation",
              license: "MIT",
              url: "https://github.com/AFNetworking/AFNetworking"),
        .init(name: "UnzipKit",
              copyright: "Copyright © 2013-2026 Dan Wheeler",
              license: "MIT",
              url: "https://github.com/abbeycode/UnzipKit"),
        .init(name: "fishhook",
              copyright: "Copyright © 2013-2026 Facebook, Inc.",
              license: "BSD-3-Clause",
              url: "https://github.com/facebook/fishhook"),
        .init(name: "XZ for Java",
              copyright: "Copyright © The XZ for Java authors",
              license: "0BSD",
              url: "https://tukaani.org/xz/java.html"),
        .init(name: "Fabric Loader",
              copyright: "Copyright © FabricMC 贡献者",
              license: "Apache-2.0",
              url: "https://github.com/FabricMC/fabric-loader"),
        .init(name: "Quilt Loader",
              copyright: "Copyright © QuiltMC 贡献者",
              license: "Apache-2.0",
              url: "https://github.com/QuiltMC/quilt-loader"),
    ]

    // 致谢（对应 AboutInfoScreen 的「赞助 / 感谢」区块）
    private let credits: [(name: String, note: String, url: String?)] = [
        ("bangbang93 · BMCLAPI", "国内 Minecraft 下载镜像，显著加快游戏文件下载", "https://bmclapi2.bangbang93.com/"),
        ("mcmod-info-mirror", "模组信息镜像，为资源搜索提供中文资料", "https://www.mcimirror.top/"),
        ("MC 百科 (mcmod.cn)", "模组 / 整合包中文百科", "https://www.mcmod.cn/"),
        ("Fold Craft Launcher", "启动器交互与实现参考", "https://github.com/FCL-Team/FoldCraftLauncher"),
        ("Hello Minecraft! Launcher", "版本管理与下载流程参考", "https://github.com/HMCL-dev/HMCL"),
        ("Plain Craft Launcher 2", "界面与交互参考", "https://github.com/Meloong-Git/PCL"),
        ("PojavLauncher", "iOS / Android 上运行 Java 版的技术参考", "https://github.com/PojavLauncherTeam/PojavLauncher"),
        ("Modrinth", "资源 API 与客户端实现参考", "https://github.com/modrinth/code"),
        ("Weblate 社区", "多语言翻译", "https://weblate.org/"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "关于与开源许可", onBack: onBack, onHome: onHome)
            ScrollView {
                VStack(spacing: ZLTheme.cardGap) {
                    appCard
                    creditsCard
                    componentsCard
                    licenseCard
                    privacyCard
                    footer
                }
                .padding(ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: $shownDoc) { doc in
            ZLLicenseDocSheet(doc: doc)
        }
    }

    // MARK: 应用信息

    private var appCard: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(ZLTheme.primarySoft)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "cube.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(ZLTheme.primary)
                        )
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ZL2-iOS").font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ZLTheme.textPrimary)
                        Text("Zalith Launcher 2 的 iOS 非官方复刻")
                            .font(.system(size: 12))
                            .foregroundStyle(ZLTheme.textSecond)
                        Text("版本 \(appVersion) (\(buildNumber)) · iOS \(osVersion)")
                            .font(.system(size: 11))
                            .foregroundStyle(ZLTheme.textSecond)
                    }
                    Spacer()
                }

                Divider()

                infoRow("启动核心", CoreBridge.isCoreLinked ? "Amethyst 已链接" : "未链接（仅界面构建）")
                infoRow("界面", "SwiftUI · 按 ZL2 Compose 界面重建")
                infoRow("许可证", "GPL-3.0（因链接 GPL 核心）")

                HStack(spacing: 10) {
                    Button {
                        shownDoc = licenseDoc("GPL-3.0")
                    } label: {
                        Text("查看 GPL-3.0")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ZLTheme.primaryDeep)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(ZLTheme.primarySoft)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Link(destination: URL(string: "https://github.com/ZalithLauncher/ZalithLauncher2")!) {
                        HStack(spacing: 5) {
                            Image(systemName: "link")
                            Text("上游项目")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ZLTheme.primaryDeep)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(ZLTheme.surfaceAlt)
                        .clipShape(Capsule())
                    }
                    Spacer()
                }
            }
        }
    }

    private func infoRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(key).font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                .frame(width: 64, alignment: .leading)
            Text(value).font(.system(size: 12, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: 致谢

    private var creditsCard: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("致谢", subtitle: "本项目建立在下面这些开源项目与社区的工作之上")
                ForEach(credits.indices, id: \.self) { i in
                    let item = credits[i]
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(ZLTheme.primarySoft)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ZLTheme.primary)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.system(size: 13, weight: .medium))
                                .foregroundStyle(ZLTheme.textPrimary)
                            Text(item.note).font(.system(size: 11))
                                .foregroundStyle(ZLTheme.textSecond)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 6)
                        if let s = item.url, let url = URL(string: s) {
                            Link(destination: url) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 14))
                                    .foregroundStyle(ZLTheme.textSecond)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: 第三方组件

    private var componentsCard: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("第三方组件", subtitle: "点击许可证名可查看要点与全文入口")
                ForEach(components) { c in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(c.name).font(.system(size: 13, weight: .medium))
                                .foregroundStyle(ZLTheme.textPrimary)
                            Text(c.copyright).font(.system(size: 10))
                                .foregroundStyle(ZLTheme.textSecond)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 6)
                        Button {
                            shownDoc = licenseDoc(c.license)
                        } label: {
                            Text(c.license)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(ZLTheme.primaryDeep)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ZLTheme.primarySoft)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        if let s = c.url, let url = URL(string: s) {
                            Link(destination: url) {
                                Image(systemName: "link")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ZLTheme.textSecond)
                                    .frame(width: 26, height: 26)
                            }
                        }
                    }
                    if c.id != components.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: 许可证

    private var licenseCard: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("开源许可证", subtitle: "点开可查看要点与官方全文")
                ForEach(["GPL-3.0", "LGPL-2.1", "AGPL-3.0", "Apache-2.0", "MIT", "BSD-3-Clause", "GPL-2.0+CE", "0BSD"],
                        id: \.self) { name in
                    Button {
                        shownDoc = licenseDoc(name)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 13))
                                .foregroundStyle(ZLTheme.primary)
                                .frame(width: 28, height: 28)
                                .background(ZLTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            Text(licenseDoc(name).title)
                                .font(.system(size: 13))
                                .foregroundStyle(ZLTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: 隐私

    private var privacyCard: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("隐私与网络", subtitle: nil)
                bullet("启动器不收集、不上传你的游戏存档、账号密码或设备信息。")
                bullet("登录微软账号时，令牌只保存在本机钥匙串 / 偏好中。")
                bullet("联网仅用于：Mojang 版本清单与文件、Fabric / Quilt 元数据、Modrinth 资源、微软账号认证。")
                bullet("所有游戏文件都保存在 App 沙盒的 Documents 目录里，卸载 App 会一并删除。")
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("本应用为社区非官方复刻，与 Mojang Studios、Microsoft 无关。")
            Text("Minecraft 是 Mojang Studios 的商标。")
            Text("Zalith Launcher 2 由 MovTery 开发，遵循 GPL-3.0。")
        }
        .font(.system(size: 10))
        .foregroundStyle(ZLTheme.textSecond)
        .multilineTextAlignment(.center)
        .padding(.top, 6)
        .padding(.bottom, 20)
    }

    // MARK: 小部件

    private func sectionTitle(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ZLTheme.textPrimary)
            if let subtitle {
                Text(subtitle).font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Circle().fill(ZLTheme.primary.opacity(0.6))
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text).font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: 许可证内容

    private func licenseDoc(_ name: String) -> ZLLicenseDoc {
        switch name {
        case "GPL-3.0":
            return ZLLicenseDoc(
                id: "GPL-3.0", title: "GNU 通用公共许可证 第 3 版",
                points: [
                    "本程序是自由软件：你可以再分发和/或修改它，但必须遵守 GPLv3 的条款。",
                    "分发时必须以相同许可证提供完整对应的源代码，并保留版权与许可声明。",
                    "不得附加额外限制；通过修改版提供交互式服务时，需向用户提供获取源代码的方式。",
                    "本程序不提供任何担保，法律允许范围内作者不承担责任（第 15、16 条）。",
                ],
                fullText: nil,
                fullTextURL: "https://www.gnu.org/licenses/gpl-3.0.txt")
        case "AGPL-3.0":
            return ZLLicenseDoc(
                id: "AGPL-3.0", title: "GNU Affero 通用公共许可证 第 3 版",
                points: [
                    "条款与 GPLv3 基本一致，但增加了「网络服务」条款：",
                    "如果修改后的程序通过网络向用户提供服务，必须向这些用户提供对应的源代码。",
                    "陶瓦联机（Terracotta）按 AGPL-3.0 授权，本项目以独立进程方式使用其原始版本。",
                ],
                fullText: nil,
                fullTextURL: "https://www.gnu.org/licenses/agpl-3.0.txt")
        case "LGPL-2.1":
            return ZLLicenseDoc(
                id: "LGPL-2.1", title: "GNU 宽通用公共许可证 第 2.1 版",
                points: [
                    "允许以动态链接的方式，在非自由软件中使用该库。",
                    "如果修改库本身并分发，必须以 LGPL 公开修改后的库源代码。",
                    "分发时必须附上许可证文本，并允许用户替换该库的版本。",
                ],
                fullText: nil,
                fullTextURL: "https://www.gnu.org/licenses/old-licenses/lgpl-2.1.txt")
        case "GPL-2.0+CE":
            return ZLLicenseDoc(
                id: "GPL-2.0+CE", title: "GPL 2.0（含 Classpath 例外）",
                points: [
                    "OpenJDK 采用 GPLv2 + Classpath Exception 授权。",
                    "Classpath 例外允许将 OpenJDK 与独立的、非 GPL 的程序链接并一起分发。",
                    "本项目以内置运行时的方式打包 OpenJDK 17，仅用于运行 Minecraft。",
                ],
                fullText: nil,
                fullTextURL: "https://openjdk.org/legal/gplv2+ce.html")
        case "Apache-2.0":
            return ZLLicenseDoc(
                id: "Apache-2.0", title: "Apache License 2.0",
                points: [
                    "可以自由使用、修改、分发，包括商业用途。",
                    "必须保留版权、许可与 NOTICE 声明；修改过的文件需要注明。",
                    "许可证不授予商标使用权；软件按现状提供，不附带担保。",
                ],
                fullText: nil,
                fullTextURL: "https://www.apache.org/licenses/LICENSE-2.0.txt")
        case "MIT":
            return ZLLicenseDoc(
                id: "MIT", title: "MIT License",
                points: [
                    "允许使用、复制、修改、合并、发布、分发、再许可和/或销售软件的副本。",
                    "必须在所有副本或重要部分中保留版权声明和本许可声明。",
                    "软件按「现状」提供，作者不承担任何责任。",
                ],
                fullText: """
                MIT License

                Copyright (c) 各项目作者

                Permission is hereby granted, free of charge, to any person obtaining a copy
                of this software and associated documentation files (the "Software"), to deal
                in the Software without restriction, including without limitation the rights
                to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
                copies of the Software, and to permit persons to whom the Software is
                furnished to do so, subject to the following conditions:

                The above copyright notice and this permission notice shall be included in all
                copies or substantial portions of the Software.

                THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
                IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
                FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
                AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
                LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
                OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
                SOFTWARE.
                """,
                fullTextURL: "https://opensource.org/license/mit")
        case "BSD-3-Clause":
            return ZLLicenseDoc(
                id: "BSD-3-Clause", title: "BSD 3-Clause License",
                points: [
                    "允许再分发源码与二进制形式，但必须保留版权声明与免责声明。",
                    "不得使用项目名或其贡献者的名字为衍生产品背书。",
                    "软件按现状提供，作者不承担任何责任。",
                ],
                fullText: """
                BSD 3-Clause License

                Copyright (c) 各项目作者

                Redistribution and use in source and binary forms, with or without
                modification, are permitted provided that the following conditions are met:

                1. Redistributions of source code must retain the above copyright notice, this
                   list of conditions and the following disclaimer.

                2. Redistributions in binary form must reproduce the above copyright notice,
                   this list of conditions and the following disclaimer in the documentation
                   and/or other materials provided with the distribution.

                3. Neither the name of the copyright holder nor the names of its
                   contributors may be used to endorse or promote products derived from
                   this software without specific prior written permission.

                THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
                AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
                IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
                DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
                FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
                DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
                SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
                CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
                OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
                OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
                """,
                fullTextURL: "https://opensource.org/license/bsd-3-clause")
        case "0BSD":
            return ZLLicenseDoc(
                id: "0BSD", title: "Zero-Clause BSD (0BSD)",
                points: [
                    "无任何使用条件，可自由使用、修改和分发。",
                    "软件按现状提供，作者不承担任何责任。",
                ],
                fullText: nil,
                fullTextURL: "https://opensource.org/license/0bsd")
        default:
            return ZLLicenseDoc(id: name, title: name,
                                points: ["详见项目主页的许可证声明。"],
                                fullText: nil,
                                fullTextURL: "https://opensource.org/licenses")
        }
    }
}

// MARK: - 许可证详情

private struct ZLLicenseDocSheet: View {
    let doc: ZLLicenseDoc
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(doc.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(doc.points, id: \.self) { p in
                            HStack(alignment: .top, spacing: 7) {
                                Circle().fill(ZLTheme.primary.opacity(0.6))
                                    .frame(width: 5, height: 5).padding(.top, 6)
                                Text(p).font(.system(size: 12))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                    }

                    if let full = doc.fullText {
                        Text(full)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(ZLTheme.textSecond)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ZLTheme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Link(destination: URL(string: doc.fullTextURL)!) {
                        HStack(spacing: 6) {
                            Image(systemName: "safari")
                            Text("在浏览器中打开官方全文")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ZLTheme.primaryDeep)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(ZLTheme.primarySoft)
                        .clipShape(Capsule())
                    }

                    Text("本页内容为便于阅读的中文摘要，法律效力以官方许可证原文为准。")
                        .font(.system(size: 10))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                .padding(18)
            }
            .background(ZLTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(ZLTheme.primaryDeep)
                }
            }
        }
    }
}
