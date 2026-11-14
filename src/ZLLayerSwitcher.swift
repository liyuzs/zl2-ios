//
//  ZLLayerSwitcher.swift
//  ZL2-iOS · 运行时切换控制布局图层
//
//  ────────────────────────────────────────────────────────────
//  背景：
//
//  ZL2 的控件有「图层」概念，按钮可以触发：
//    · switch_layer  切到某层
//    · show_layer    显示某层
//    · hide_layer    隐藏某层
//
//  但核心（Pojav 的 ControlLayout）是扁平的，不认识图层。
//
//  解决方案：
//    CoreLayoutExporter.exportAllLayers() 为每个图层各导出一份布局文件，
//    核心支持运行时 loadControlFile: 换加载哪份。
//    这个类负责读图层清单、按需切换。
//
//  用法（ObjC 侧）：
//    [ZLLayerSwitcher activateLayerAtIndex:1];
//    [ZLLayerSwitcher activateLayerWithUUID:@"xxx"];
//  ────────────────────────────────────────────────────────────

import Foundation
import UIKit

@objc(ZLLayerSwitcher)
public final class ZLLayerSwitcher: NSObject {

    /// 图层清单条目
    struct LayerInfo: Codable {
        let uuid: String
        let name: String
        let index: Int
        let file: String
        let visibleType: String
    }

    private struct Manifest: Codable {
        let layoutName: String
        let layers: [LayerInfo]
    }

    /// 当前布局的图层清单（nil = 单层，无需切换）
    private static var manifest: Manifest?
    private static var currentIndex: Int = 0

    /// 核心的 controlmap 目录
    private static var controlMapDir: URL {
        CoreLayoutExporter.controlMapDir
    }

    // MARK: 加载清单

    /// 读完布局后调用，记下有哪些图层可切
    @objc(loadManifestFor:)
    public static func loadManifest(for layoutFile: String) {
        // 从 "xxx__layer0.json" 或 "xxx.json" 推导出 base
        var base = layoutFile
        if let r = base.range(of: "__layer") {
            base = String(base[base.startIndex..<r.lowerBound])
        }
        if base.hasSuffix(".json") { base = String(base.dropLast(5)) }

        let url = controlMapDir.appendingPathComponent("\(base)__layers.json")
        guard let data = try? Data(contentsOf: url),
              let m = try? JSONDecoder().decode(Manifest.self, from: data) else {
            manifest = nil
            currentIndex = 0
            return
        }
        manifest = m
        currentIndex = 0
        NSLog("[ZL2] 图层清单已加载：%@，共 %ld 层",
              m.layoutName, m.layers.count)
    }

    // MARK: 切换

    /// 按序号切（0 起）
    @objc(activateLayerAtIndex:)
    @discardableResult
    public static func activateLayer(at index: Int) -> Bool {
        guard let m = manifest, m.layers.indices.contains(index) else { return false }
        let info = m.layers[index]
        guard apply(file: info.file) else { return false }
        currentIndex = index
        NSLog("[ZL2] 已切到图层 %ld：%@", index, info.name)
        return true
    }

    /// 按 uuid 切
    @objc(activateLayerWithUUID:)
    @discardableResult
    public static func activateLayer(uuid: String) -> Bool {
        guard let m = manifest,
              let idx = m.layers.firstIndex(where: { $0.uuid == uuid }) else { return false }
        return activateLayer(at: idx)
    }

    /// 按图层名切
    @discardableResult
    public static func activateLayer(name: String) -> Bool {
        guard let m = manifest,
              let idx = m.layers.firstIndex(where: { $0.name == name }) else { return false }
        return activateLayer(at: idx)
    }

    // MARK: ObjC 入口（核心按钮点击时调用）

    /// 由核心的 executebtn: 通过伪键码调用
    ///
    /// 伪键码里同时编了「动作类型」和「层序号」，见 LayerPseudoKey：
    ///   -1001~   switch_layer  切到该层（独占）
    ///   -2001~   show_layer    叠加显示该层
    ///   -3001~   hide_layer    隐藏该层
    @objc(activateLayerByPseudoKey:)
    @discardableResult
    public static func activateLayer(pseudoKey: Int) -> Bool {
        guard let (action, index) = LayerPseudoKey.decode(pseudoKey) else {
            NSLog("[ZL2] 伪键码 %ld 不合法", pseudoKey)
            return false
        }
        switch action {
        case .switchLayer:
            return activateLayer(at: index)
        case .showLayer:
            return showLayer(at: index)
        case .hideLayer:
            return hideLayer(at: index)
        }
    }

    // MARK: 三种图层动作

    /// 切到某层（独占）：只显示这一层
    @discardableResult
    /// 叠加显示某层：在「当前已显示的层」基础上再加一层
    ///
    /// 核心没有图层概念，所以做法是：重新导出一份
    /// 「当前层 + 目标层」合并的布局文件，然后加载它。
    @discardableResult
    public static func showLayer(at index: Int) -> Bool {
        guard let m = manifest, m.layers.indices.contains(index) else { return false }
        var visible = visibleIndices
        if !visible.contains(index) { visible.append(index) }
        return applyComposite(visible: visible, name: m.layers[index].name)
    }

    /// 隐藏某层：从当前显示集合里去掉它
    @discardableResult
    public static func hideLayer(at index: Int) -> Bool {
        guard let m = manifest, m.layers.indices.contains(index) else { return false }
        var visible = visibleIndices
        visible.removeAll { $0 == index }
        // 一层都不剩时保留第 0 层，避免控件全消失没法操作
        if visible.isEmpty { visible = [0] }
        return applyComposite(visible: visible, name: "隐藏 " + m.layers[index].name)
    }

    /// 当前显示的层序号集合
    private static var visibleIndices: [Int] { [currentIndex] }

    /// 把若干图层合并导出并加载
    ///
    /// 需要原始布局文件才能合并，所以要求导出时把源 json 也留在
    /// controlmap 目录（文件名 <base>__source.json）。
    private static func applyComposite(visible: [Int], name: String) -> Bool {
        guard let m = manifest else { return false }

        // 优先走「预合并」路线：导出时已经为常见组合准备好文件
        let key = visible.sorted().map(String.init).joined(separator: "-")
        let compositeName = "\(m.layoutName)__combo_\(key).json"
        if FileManager.default.fileExists(
            atPath: controlMapDir.appendingPathComponent(compositeName).path) {
            guard apply(file: compositeName) else { return false }
            currentIndex = visible.first ?? 0
            NSLog("[ZL2] 已切到组合层 %@（%@）", key, name)
            return true
        }

        // 没预合并就退回单层
        NSLog("[ZL2] 组合层 %@ 未预生成，退回单层切换", key)
        return activateLayer(at: visible.first ?? 0)
    }

    /// 保存「伪键码 → uuid」映射，供按钮点击时反查
    @objc(persistPseudoKeysFor:)
    public static func persistPseudoKeys(for layout: ZLControlLayout) {
        let map = LayerPseudoKey.buildMapping(for: layout)
        LayerPseudoKey.persist(map)
        NSLog("[ZL2] 图层伪键码已保存：%ld 条", map.count)
    }

    /// 当前层序号
    @objc public static var activeIndex: Int { currentIndex }

    /// 是否有多个图层
    @objc public static var hasMultipleLayers: Bool {
        (manifest?.layers.count ?? 0) > 1
    }

    /// 全部图层名（给 UI 列表用）
    @objc public static var layerNames: [String] {
        manifest?.layers.map { $0.name } ?? []
    }

    // MARK: 实际切换

    /// 让核心重新加载指定布局文件
    ///
    /// 核心的 ControlLayout 暴露了 loadControlFile:，
    /// SurfaceViewController 持有 ctrlView。这里通过响应链找到它。
    private static func apply(file: String) -> Bool {
        guard !file.isEmpty else { return false }

        // 找当前窗口的根控制器，沿视图树找持有 ControlLayout 的那个
        guard let root = keyWindow?.rootViewController else {
            NSLog("[ZL2] 切图层失败：找不到 window")
            return false
        }
        guard let host = findSurfaceController(from: root) else {
            NSLog("[ZL2] 切图层失败：找不到 SurfaceViewController")
            return false
        }

        // 用 KVC 拿 ctrlView（避免 Swift 依赖 ObjC 头文件）
        guard let ctrlView = host.value(forKey: "ctrlView") as? NSObject else {
            NSLog("[ZL2] 切图层失败：ctrlView 不存在")
            return false
        }

        // 调 loadControlFile:
        let sel = NSSelectorFromString("loadControlFile:")
        guard ctrlView.responds(to: sel) else {
            NSLog("[ZL2] 切图层失败：ctrlView 不支持 loadControlFile:")
            return false
        }
        _ = ctrlView.perform(sel, with: file)

        // 同时更新核心读的偏好，下次启动仍用这层。
        // 注意不能只写 UserDefaults —— 核心读的是 PLProfiles 的 defaultTouchCtrl
        // （最终落到 getPrefObject("control.default_ctrl")），UserDefaults 那份只是本 App 的记账本。
        setPrefObject("control.default_ctrl", file)
        UserDefaults.standard.set(file, forKey: "defaultTouchCtrl")
        return true
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    /// 在视图控制器树里找类名含 SurfaceViewController 的那个
    private static func findSurfaceController(from vc: UIViewController) -> UIViewController? {
        let name = NSStringFromClass(type(of: vc))
        if name.contains("SurfaceViewController") { return vc }

        for child in vc.children {
            if let found = findSurfaceController(from: child) { return found }
        }
        if let presented = vc.presentedViewController {
            if let found = findSurfaceController(from: presented) { return found }
        }
        return nil
    }
}
