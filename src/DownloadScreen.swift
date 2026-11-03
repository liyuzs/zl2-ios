// ZL2-iOS · 下载中心
// 对照 ZL2 安卓版：版本列表 + 加载器选择 + 安装状态
import SwiftUI

struct DownloadScreen: View {
    @State private var query = ""
    @State private var category = 0   // 0 游戏 / 1 整合包 / 2 模组

    private let categories = ["游戏", "整合包", "模组"]

    // 演示数据；真实实现走 Mojang 版本清单接口
    private let versions: [DownloadableVersion] = [
        .init(id: "1.21.4", type: "正式版", date: "2025-03-25", loaders: ["Fabric", "NeoForge"]),
        .init(id: "1.20.1", type: "正式版", date: "2023-06-12", loaders: ["Forge", "Fabric", "Quilt"]),
        .init(id: "1.12.2", type: "正式版", date: "2017-09-18", loaders: ["Forge"]),
        .init(id: "1.8.9", type: "正式版", date: "2015-12-09", loaders: ["Forge"]),
        .init(id: "26.1.2", type: "快照", date: "2026-01-15", loaders: []),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                searchBar
                categoryBar
                ForEach(filtered) { v in
                    versionRow(v)
                }
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.vertical, 12)
        }
        .background(ZLTheme.surface)
    }

    private var filtered: [DownloadableVersion] {
        query.isEmpty ? versions : versions.filter { $0.id.contains(query) }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ZLTheme.textSecond)
            TextField("搜索版本号", text: $query)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(ZLTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(ZLTheme.cardStroke, lineWidth: 1))
    }

    private var categoryBar: some View {
        HStack(spacing: 8) {
            ForEach(categories.indices, id: \.self) { i in
                Button { category = i } label: {
                    Text(categories[i])
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(category == i ? .white : ZLTheme.textSecond)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(category == i ? ZLTheme.primary : ZLTheme.cardBg)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(ZLTheme.cardStroke, lineWidth: category == i ? 0 : 1))
                }
            }
            Spacer()
        }
    }

    private func versionRow(_ v: DownloadableVersion) -> some View {
        ZLCard {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(v.id).font(.system(size: 15, weight: .semibold))
                        Text(v.type)
                            .font(.system(size: 10))
                            .foregroundStyle(v.type == "正式版" ? ZLTheme.success : ZLTheme.warning)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background((v.type == "正式版" ? ZLTheme.success : ZLTheme.warning).opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text(v.date).font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                    if !v.loaders.isEmpty {
                        Text(v.loaders.joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundStyle(ZLTheme.primary)
                    }
                }
                Spacer()
                Button { } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(ZLTheme.primary)
                }
            }
        }
    }
}

struct DownloadableVersion: Identifiable {
    let id: String
    let type: String
    let date: String
    let loaders: [String]
}
