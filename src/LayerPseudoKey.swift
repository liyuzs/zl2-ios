//
//  LayerPseudoKey.swift
//  ZL2-iOS · 图层 uuid ↔ 伪键码
//
//  ────────────────────────────────────────────────────────────
//  要解决的问题：
//
//  核心（Pojav 的 ControlLayout）的按钮只认整数键码数组 keycodes[4]，
//  而 ZL2 的图层切换事件存的是 uuid 字符串。
//
//  两边对不上，所以把 uuid 映射成一个**负数伪键码**塞进 keycodes：
//
//    核心已占用的特殊键码：-1 ~ -9（SPECIALBTN_*）
//    我们用的区间：        <= -1000
//
//  核心的 executebtn: 遇到 <= -1000 的键码就走 default 分支，
//  在那里调 ZLLayerSwitcher 反查回 uuid 并切换。
//
//  ────────────────────────────────────────────────────────────
//  为什么用「顺序编号」而不是哈希：
//
//  一开始我用 FNV-1a 哈希 uuid，实测 20 万个随机 uuid 的碰撞率 9%，
//  和生日悖论的理论值吻合——这不是算法问题，是「哈希空间太小」的必然。
//
//  但图层只有 2~5 个，根本不需要 100 万个桶。
//  改成按图层在数组里的顺序编号（-1001, -1002, ...），
//  在同一个布局内**零碰撞**，且反查只要一次数组下标。
//  ────────────────────────────────────────────────────────────

import Foundation

enum LayerPseudoKey {

    /// 伪键码的边界（比核心的 -1 ~ -9 小得多，不会撞）
    static let threshold = -1000

    /// 第 index 层对应的伪键码：-1001, -1002, -1003 ...
    static func encode(index: Int) -> Int {
        threshold - (index + 1)
    }

    /// 伪键码 → 层序号
    static func decodeIndex(_ pseudo: Int) -> Int? {
        guard pseudo <= threshold else { return nil }
        let idx = threshold - pseudo - 1
        return idx >= 0 ? idx : nil
    }

    /// 判断某个键码是不是伪键码
    static func isPseudoKey(_ code: Int) -> Bool {
        code <= threshold
    }

    /// 从一个布局生成「伪键码 → 图层 uuid」映射
    ///
    /// 按 layers 数组顺序编号，同一布局内唯一。
    static func buildMapping(for layout: ZLControlLayout) -> [Int: String] {
        var map: [Int: String] = [:]
        for (index, layer) in layout.layers.enumerated() {
            guard !layer.uuid.isEmpty else { continue }
            map[encode(index: index)] = layer.uuid
        }
        return map
    }

    /// 映射表存盘的键（UserDefaults）
    private static let storeKey = "zl.layerPseudoKeyMapping"

    /// 保存映射（切换时需要反查）
    static func persist(_ mapping: [Int: String]) {
        let dict = Dictionary(uniqueKeysWithValues: mapping.map { (String($0.key), $0.value) })
        UserDefaults.standard.set(dict, forKey: storeKey)
    }

    /// 读回映射
    static func restore() -> [Int: String] {
        guard let raw = UserDefaults.standard.dictionary(forKey: storeKey) as? [String: String] else {
            return [:]
        }
        var out: [Int: String] = [:]
        for (k, v) in raw {
            if let n = Int(k) { out[n] = v }
        }
        return out
    }
}

