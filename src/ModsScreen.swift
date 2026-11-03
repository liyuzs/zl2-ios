// ZL2-iOS · 模组与整合包管理
// 对照 ZL2：模组列表、前置依赖提示、启停开关、导入
import SwiftUI

struct ModsScreen: View {
    @State private var query = ""
    @State private var mods: [ModItem] = ModItem.samples

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                summary
                searchBar
                ForEach(filtered) { item in
                    modRow(item)
                }
                importButton
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.vertical, 12)
        }
        .background(ZLTheme.surface)
    }

    private var filtered: [ModItem] {
        query.isEmpty ? mods : mods.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    // 依赖缺失提醒（ZL2 里最容易踩的坑）
    private var summary: some View {
        let missing = mods.filter { $0.enabled && !$0.dependencies.isEmpty }
        return Group {
            if missing.isEmpty {
                EmptyView()
            } else {
                ZLCard {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ZLTheme.warning)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("请确认前置依赖已安装")
                                .font(.system(size: 13, weight: .semibold))
                            Text(missing.prefix(2).map { "\($0.name) 需要 \($0.dependencies.joined(separator: "、"))" }
                                .joined(separator: "\n"))
                                .font(.system(size: 11))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                    }
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(ZLTheme.textSecond)
            TextField("搜索模组", text: $query).font(.system(size: 14))
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(ZLTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(ZLTheme.cardStroke, lineWidth: 1))
    }

    private func modRow(_ item: ModItem) -> some View {
        ZLCard {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ZLTheme.primary.opacity(0.12))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "shippingbox").foregroundStyle(ZLTheme.primary))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(.system(size: 14, weight: .medium))
                    Text("\(item.version) · \(item.loader)")
                        .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                    if !item.dependencies.isEmpty {
                        Text("前置：\(item.dependencies.joined(separator: "、"))")
                            .font(.system(size: 10)).foregroundStyle(ZLTheme.warning)
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { item.enabled },
                    set: { newValue in
                        if let i = mods.firstIndex(where: { $0.id == item.id }) {
                            mods[i].enabled = newValue
                        }
                    }
                )).labelsHidden()
            }
        }
    }

    private var importButton: some View {
        ZLPrimaryButton(title: "从文件导入模组", icon: "square.and.arrow.down") {
            // 后续接 UIDocumentPickerViewController
        }
        .padding(.top, 4)
    }
}

struct ModItem: Identifiable {
    let id = UUID()
    var name: String
    var version: String
    var loader: String
    var dependencies: [String]
    var enabled: Bool

    static let samples: [ModItem] = [
        .init(name: "JEI", version: "15.20.0.130", loader: "Forge", dependencies: [], enabled: true),
        .init(name: "JourneyMap", version: "5.10.3", loader: "Forge", dependencies: [], enabled: true),
        .init(name: "Waystones", version: "14.0.2", loader: "Forge", dependencies: ["Balm"], enabled: true),
        .init(name: "AppleSkin", version: "2.5.1", loader: "Forge", dependencies: [], enabled: false),
        .init(name: "Dynamic FPS", version: "3.11.4", loader: "Forge", dependencies: [], enabled: true),
    ]
}
