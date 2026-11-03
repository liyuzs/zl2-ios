// ZL2-iOS · Swift ↔ Amethyst ObjC 桥接头
// 暴露启动入口与最小初始化接口

#ifndef ZL2_CORE_BRIDGE_H
#define ZL2_CORE_BRIDGE_H

#import <Foundation/Foundation.h>

// 启动入口（core/JavaLauncher.h）
int launchJVM(NSString *username, id launchTarget, int width, int height, int minVersion);

// 偏好系统（core/LauncherPreferences.m）
// 依赖 AME_HOME 环境变量，调用前需先 setenv
void loadPreferences(BOOL reset);
id getPrefObject(NSString *key);
void setPrefObject(NSString *key, id value);

#endif
