//
//  ZLOverlayHost.swift
//  ZL2-iOS · 把 SwiftUI 的 GameOverlay 挂到 ObjC 的游戏画面控制器上
//
//  SurfaceViewController 是 ObjC 写的（继承自 Amethyst），
//  它用 UIKit 手工搭视图树，没有 SwiftUI 容器。
//  这里提供三个静态方法，让它能用一行代码把悬浮层挂上去 / 摘下来 / 重排。
//
//  用法（在 SurfaceViewController.m 里）：
//      [ZLOverlayHost attachTo:self.rootView];
//      [ZLOverlayHost detach];
//      [ZLOverlayHost relayoutIn:self.rootView];
//
//  **第 258 轮修**（CI 第 240 次构建的 4 个 error 全在这个文件）：
//    · `GameOverlay()` 缺 `isMenuPresented` 参数 → 补一个静态菜单状态
//    · 文件末尾只剩孤立的 `@objc(relayoutIn:)`，**方法体没了** ——
//      第 143 轮删死方法（`relayout`）时连带把它一起删掉了，留下一个没有实现的声明。
//      现在补回来（core 里真在调它）。
//    · `.clear` / `.flexibleWidth` / `.flexibleHeight` 推断失败是上面两个错误的连锁。
//

import SwiftUI
import UIKit

@objc(ZLOverlayHost)
@MainActor
public final class ZLOverlayHost: NSObject {

    private static var host: UIHostingController<AnyView>?

    /// 悬浮层的"菜单展开"状态。
    /// `GameOverlay` 需要一个 `Binding<Bool>`（点悬浮球要能展开菜单），
    /// 而我们是静态方法、没有 View 状态，所以用一个静态变量 + 手写 Binding。
    private static var menuPresented = false

    /// 把游戏内悬浮层挂到指定视图上
    @objc(attachTo:)
    public static func attach(to container: UIView) {
        guard host == nil else { return }

        let root = AnyView(
            GameOverlay(
                isMenuPresented: Binding(
                    get: { ZLOverlayHost.menuPresented },
                    set: { ZLOverlayHost.menuPresented = $0 }
                )
            )
            .allowsHitTesting(true)
        )
        let vc = UIHostingController(rootView: root)
        vc.view.backgroundColor = UIColor.clear
        vc.view.isOpaque = false
        vc.view.frame = container.bounds
        vc.view.autoresizingMask = [UIView.AutoresizingMask.flexibleWidth,
                                    UIView.AutoresizingMask.flexibleHeight]

        container.addSubview(vc.view)

        // 让 SwiftUI 内容不挡住下面的游戏触摸：只有悬浮球那一小块可交互
        vc.view.isUserInteractionEnabled = true

        host = vc
    }

    /// 摘掉悬浮层
    @objc public static func detach() {
        guard let vc = host else { return }
        vc.view.removeFromSuperview()
        vc.removeFromParent()
        host = nil
    }

    /// 更新布局（旋转时调用）
    /// **这一段是第 143 轮删掉的，第 258 轮补回** —— core 的 SurfaceViewController 在方向变化时调它。
    @objc(relayoutIn:)
    public static func relayout(in container: UIView) {
        guard let vc = host else { return }
        vc.view.frame = container.bounds
    }
}
