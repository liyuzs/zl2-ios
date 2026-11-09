// ZL2-iOS · Swift ↔ Amethyst ObjC 桥接头
// 暴露启动入口、偏好系统、以及默认控制布局的生成入口。
//
// 注意：这里声明的每个函数都必须与 core/ 下的真实头文件完全一致 ——
// Swift 侧的类型检查只认这份声明，签名写错不会在 ObjC 那边报错，
// 而是链接期找不到符号，或者运行期参数错位。
// 对应关系：
//   launchJVM            → core/JavaLauncher.h
//   loadPreferences ...  → core/LauncherPreferences.h
//   generateAndSaveDefaultControl → core/customcontrols/CustomControlsUtils.h

#ifndef ZL2_CORE_BRIDGE_H
#define ZL2_CORE_BRIDGE_H

#import <Foundation/Foundation.h>

// MARK: - 启动入口（core/JavaLauncher.h）
int launchJVM(NSString *username, id launchTarget, int width, int height, int minVersion);

// MARK: - 偏好系统（core/LauncherPreferences.h）
// 依赖 AME_HOME 环境变量，调用前需先 setenv。
//
// 重要：setObject 只会写「已经存在于默认字典里的键」，
// 键没预定义就 NSLog 一行然后静默失败（见 PLPreferences.m:229）。
// 新加键必须先加到 PLPreferences 的 defaultPrefForGlobal。
void loadPreferences(BOOL reset);

id getPrefObject(NSString *key);
BOOL getPrefBool(NSString *key);
float getPrefFloat(NSString *key);
NSInteger getPrefInt(NSString *key);

void setPrefObject(NSString *key, id value);
void setPrefBool(NSString *key, BOOL value);
void setPrefFloat(NSString *key, float value);
void setPrefInt(NSString *key, NSInteger value);

// MARK: - 默认控制布局（core/customcontrols/CustomControlsUtils.h）
//
// 核心从来没有主动调用过它，而 defaultTouchCtrl 的默认值就是 "default.json"。
// 结果是首次启动会去读一个不存在的 <AME_HOME>/controlmap/default.json，
// 弹一句 Could not open，然后屏幕上没有任何控件。
// 所以由 Swift 在 bootstrap 里主动调一次。
//
// 前提：<AME_HOME>/controlmap/ 目录必须已存在 ——
// 该函数用 NSOutputStream 写文件，父目录不存在时会静默失败。
void generateAndSaveDefaultControl();

#endif
