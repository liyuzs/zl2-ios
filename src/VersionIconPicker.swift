//  ZL2-iOS · 版本自定义图标
//
//  安卓 ZL2 允许给每个版本挑一个封面图标（显示在首页卡片和版本管理页）。
//  iOS 版原本这个按钮是空的，这里补上真实实现：
//    · 内置一组 SF Symbols 供选择
//    · 支持从相册选图
//    · 选择结果按版本 ID 存进 UserDefaults，重启后仍在
//
//  存法：UserDefaults key = "zl2.versionIcon.<版本ID>"
//        value 形如 "sf:cube.fill" 或 "file:<沙盒内相对路径>"

import SwiftUI
// UIImage 来自 UIKit。虽然 PhotosUI 通常会把它带进来，
// 但那是"通常"——显式导入为零成本，去掉这个不确定性。
import UIKit
import PhotosUI

// MARK: - 图标存储

enum VersionIconStore {

    private static let prefix = "zl2.versionIcon."

    /// 内置可选图标（都是 SF Symbols，iOS 16 全都有）
    static let builtins: [(symbol: String, name: String)] = [
        ("cube.fill",            "方块"),
        ("cube.transparent.fill","半透明方块"),
        ("shippingbox.fill",     "箱子"),
        ("leaf.fill",            "草叶"),
        ("flame.fill",           "火焰"),
        ("drop.fill",            "水滴"),
        ("bolt.fill",            "闪电"),
        ("snowflake",            "雪花"),
        ("mountain.2.fill",      "山峰"),
        ("tree.fill",            "树"),
        ("sparkles",             "星光"),
        ("star.fill",            "星星"),
        ("heart.fill",           "爱心"),
        ("crown.fill",           "皇冠"),
        ("shield.fill",          "盾牌"),
        ("hammer.fill",          "锤子"),
        ("wrench.and.screwdriver.fill", "扳手"),
        ("gamecontroller.fill",  "手柄"),
        ("paintpalette.fill",    "调色板"),
        ("theatermasks.fill",    "面具"),
        ("flame",                "火苗描边"),
        ("circle.hexagongrid.fill", "蜂巢"),
        ("hexagon.fill",         "六边形"),
        ("atom",                 "原子"),
        ("moon.stars.fill",      "月夜"),
        ("sun.max.fill",         "太阳"),
        ("cloud.bolt.rain.fill", "雷雨"),
        ("ant.fill",             "蚂蚁"),
        ("ladybug.fill",         "瓢虫"),
        ("tortoise.fill",        "陆龟"),
    ]

    /// 默认图标
    static let fallbackSymbol = "cube.fill"

    // MARK: 读取

    /// 返回该版本的图标描述。没有自定义时返回 nil（调用方自行决定默认值）。
    static func icon(for versionID: String) -> String? {
        guard !versionID.isEmpty else { return nil }
        return UserDefaults.standard.string(forKey: prefix + versionID)
    }

    /// 是否是 SF Symbol
    static func isSymbol(_ value: String) -> Bool {
        value.hasPrefix("sf:")
    }

    /// 取出真实图标名（去掉 sf: 前缀）
    static func symbolName(_ value: String) -> String {
        isSymbol(value) ? String(value.dropFirst(3)) : fallbackSymbol
    }

    /// 取出自定义图片的沙盒绝对路径（若有）
    static func imageURL(_ value: String) -> URL? {
        guard value.hasPrefix("file:") else { return nil }
        let rel = String(value.dropFirst(5))
        guard !rel.isEmpty else { return nil }
        return Self.iconDirectory.appendingPathComponent(rel)
    }

    // MARK: 写入

    static func setSymbol(_ symbol: String, for versionID: String) {
        guard !versionID.isEmpty else { return }
        UserDefaults.standard.set("sf:" + symbol, forKey: prefix + versionID)
    }

    /// 保存一张图并绑定到版本
    @discardableResult
    static func saveImage(_ image: UIImage, for versionID: String) -> Bool {
        guard !versionID.isEmpty else { return false }
        guard let data = image.jpegData(compressionQuality: 0.86) else { return false }

        let dir = iconDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // 文件名用版本 ID 的稳定哈希，避免版本名里有 "/" 之类
        let safe = versionID.replacingOccurrences(of: "/", with: "_")
                          .replacingOccurrences(of: ":", with: "_")
        let fileName = "icon-\(safe).jpg"
        let url = dir.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: .atomic)
            UserDefaults.standard.set("file:" + fileName, forKey: prefix + versionID)
            return true
        } catch {
            return false
        }
    }

    static func clear(for versionID: String) {
        guard !versionID.isEmpty else { return }
        if let cur = icon(for: versionID), let url = imageURL(cur) {
            try? FileManager.default.removeItem(at: url)
        }
        UserDefaults.standard.removeObject(forKey: prefix + versionID)
    }

    // MARK: 路径

    /// Document/VersionIcons
    private static var iconDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory,
                                            in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("VersionIcons", isDirectory: true)
    }
}

// MARK: - 图标显示视图

/// 统一渲染版本图标：自定义图 / SF Symbol / 默认
struct VersionIconView: View {
    let versionID: String
    var size: CGFloat = 64
    var corner: CGFloat = 14

    private var custom: String? { VersionIconStore.icon(for: versionID) }

    var body: some View {
        Group {
            if let v = custom, let url = VersionIconStore.imageURL(v),
               let ui = UIImage(contentsOfFile: url.path) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else if let v = custom, VersionIconStore.isSymbol(v) {
                Image(systemName: VersionIconStore.symbolName(v))
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(ZLTheme.primary)
            } else {
                Image(systemName: VersionIconStore.fallbackSymbol)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(ZLTheme.primary)
            }
        }
        .frame(width: size, height: size)
        .background(ZLTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

// MARK: - 选择面板

struct VersionIconPicker: View {
    let versionID: String
    var versionName: String
    var onClose: () -> Void = {}

    @State private var pickedItem: PhotosPickerItem?
    @State private var toast: String?
    @State private var selectedSymbol: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏
            HStack {
                Button { onClose() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ZLTheme.textSecond)
                        .accessibilityLabel("关闭")
                }
                .buttonStyle(.plain)

                Spacer()
                VStack(spacing: 2) {
                    Text("自定义图标").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text(versionName).font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                Spacer()

                // 占位，保证标题居中
                Image(systemName: "xmark").font(.system(size: 16)).opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            ScrollView {
                VStack(spacing: 18) {
                    // 预览
                    VersionIconView(versionID: versionID, size: 88, corner: 20)
                        .padding(.top, 6)

                    // 从相册
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("从相册选择")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ZLTheme.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(ZLTheme.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 20)

                    // 内置图标网格
                    VStack(alignment: .leading, spacing: 10) {
                        Text("内置图标")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ZLTheme.textSecond)
                            .padding(.horizontal, 20)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(VersionIconStore.builtins, id: \.symbol) { item in
                                Button {
                                    VersionIconStore.setSymbol(item.symbol, for: versionID)
                                    selectedSymbol = item.symbol
                                    ZLHaptic.light()
                                    toast = "已选择：\(item.name)"
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(isSelected(item.symbol)
                                                  ? ZLTheme.primary
                                                  : ZLTheme.cardBg)
                                        Image(systemName: item.symbol)
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundStyle(isSelected(item.symbol)
                                                             ? .white
                                                             : ZLTheme.primary)
                                    }
                                    .frame(height: 52)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(ZLTheme.cardStroke, lineWidth: isSelected(item.symbol) ? 0 : 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // 恢复默认
                    Button {
                        VersionIconStore.clear(for: versionID)
                        selectedSymbol = nil
                        ZLHaptic.light()
                        toast = "已恢复默认图标"
                    } label: {
                        Text("恢复默认")
                            .font(.system(size: 13))
                            .foregroundStyle(ZLTheme.danger)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .onChange(of: pickedItem) { newItem in   // 第258轮：iOS 16 只有单参数版
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data),
                   VersionIconStore.saveImage(ui, for: versionID) {
                    await MainActor.run {
                        selectedSymbol = nil
                        ZLHaptic.success()
                        toast = "已设为自定义图片"
                    }
                } else {
                    await MainActor.run { toast = "图片读取失败，换一张试试" }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.78))
                    .clipShape(Capsule())
                    .padding(.bottom, 34)
                    .transition(.opacity)
                    .task {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        withAnimation { self.toast = nil }
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: toast)
    }

    private func isSelected(_ symbol: String) -> Bool {
        if let cur = VersionIconStore.icon(for: versionID), VersionIconStore.isSymbol(cur) {
            return VersionIconStore.symbolName(cur) == symbol
        }
        return false
    }
}
