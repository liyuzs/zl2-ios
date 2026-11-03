// ZL2-iOS · Swift ↔ Amethyst ObjC 桥接头
// 只暴露启动入口，避免把 UIKit 头文件带进 Swift

#ifndef ZL2_CORE_BRIDGE_H
#define ZL2_CORE_BRIDGE_H

#import <Foundation/Foundation.h>

// Amethyst 的唯一启动入口（core/JavaLauncher.h）
// launchTarget 传 NSDictionary = 版本元数据；传 NSString = 直接跑 jar
int launchJVM(NSString *username, id launchTarget, int width, int height, int minVersion);

#endif
