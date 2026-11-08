//
//  ZLOverlayHost.swift
//  ZL2-iOS · 把 SwiftUI 的 GameOverlay 挂到 ObjC 的游戏画面控制器上
//
//  SurfaceViewController 是 ObjC 写的（继承自 Amethyst），
//  它用 UIKit 手工搭视图树，没有 SwiftUI 容器。
//  这里提供两个静态方法，让它能用一行代码把悬浮层挂上去 / 摘下来。
//
//  用法（在 SurfaceViewController.m 里）：
//      [ZLOverlayHost attachTo:self.rootView];
//      [ZLOverlayHost detach];
//

import SwiftUI
import UIKit

@objc(ZLOverlayHost)
@MainActor
public final class ZLOverlayHost: NSObject {

    private static var host: UIHostingController<AnyView>?

    /// 把游戏内悬浮层挂到指定视图上
    @objc(attachTo:)
    public static func attach(to container: UIView) {
        guard host == nil else { return }

        let root = AnyView(
            GameOverlay()
                .allowsHitTesting(true)
        )
        let vc = UIHostingController(rootView: root)
        vc.view.backgroundColor = .clear
        vc.view.isOpaque = false
        vc.view.frame = container.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

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
    @objc(relayoutIn:)
    public static func relayout(in container: UIView) {
        host?.view.frame = container.bounds
    }
}
