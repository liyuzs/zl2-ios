#import "config.h"
#import "utils.h"
#import "LauncherPreferences.h"
#import "PLPreferences.h"
#import "UIKit+hook.h"
#import <CoreFoundation/CoreFoundation.h>

static PLPreferences* pref;

void loadPreferences(BOOL reset) {
    assert(getenv("AME_HOME"));
    if (reset) {
        [pref reset];
    } else {
        pref = [[PLPreferences alloc] initWithAutomaticMigrator];
    }
}

void toggleIsolatedPref(BOOL forceEnable) {
    if (!pref.instancePath) {
        pref.instancePath = [NSString stringWithFormat:@"%s/launcher_preferences.plist", getenv("GAME_DIR")];
    }
    [pref toggleIsolationForced:forceEnable];
}

id getPrefObject(NSString *key) {
    return [pref getObject:key];
}
BOOL getPrefBool(NSString *key) {
    return [getPrefObject(key) boolValue];
}
float getPrefFloat(NSString *key) {
    return [getPrefObject(key) floatValue];
}
NSInteger getPrefInt(NSString *key) {
    return [getPrefObject(key) intValue];
}

void setPrefObject(NSString *key, id value) {
    [pref setObject:key value:value];
}
void setPrefBool(NSString *key, BOOL value) {
    setPrefObject(key, @(value));
}
void setPrefFloat(NSString *key, float value) {
    setPrefObject(key, @(value));
}
void setPrefInt(NSString *key, NSInteger value) {
    setPrefObject(key, @(value));
}

void resetWarnings() {
    for (int i = 0; i < pref.globalPref[@"warnings"].count; i++) {
        NSString *key = pref.globalPref[@"warnings"].allKeys[i];
        pref.globalPref[@"warnings"][key] = @YES;
    }
}

#pragma mark Safe area

CGRect getSafeArea(CGRect screenBounds) {
    UIEdgeInsets safeArea = UIEdgeInsetsFromString(getPrefObject(@"control.control_safe_area"));
    if (screenBounds.size.width < screenBounds.size.height) {
        safeArea = UIEdgeInsetsMake(safeArea.right, safeArea.top, safeArea.left, safeArea.bottom);
    }
    return UIEdgeInsetsInsetRect(screenBounds, safeArea);
}

void setSafeArea(CGSize screenSize, CGRect frame) {
    UIEdgeInsets safeArea;
    // TODO: make safe area consistent across opposite orientations?
    if (screenSize.width < screenSize.height) {
        safeArea = UIEdgeInsetsMake(
            frame.origin.x,
            screenSize.height - CGRectGetMaxY(frame),
            screenSize.width - CGRectGetMaxX(frame),
            frame.origin.y);
    } else {
        safeArea = UIEdgeInsetsMake(
            frame.origin.y,
            frame.origin.x,
            screenSize.height - CGRectGetMaxY(frame),
            screenSize.width - CGRectGetMaxX(frame));
    }
    setPrefObject(@"control.control_safe_area", NSStringFromUIEdgeInsets(safeArea));
}

UIEdgeInsets getDefaultSafeArea() {
    UIEdgeInsets safeArea = UIApplication.sharedApplication.windows.firstObject.safeAreaInsets;
    CGSize screenSize = UIScreen.mainScreen.bounds.size;
    if (screenSize.width < screenSize.height) {
        safeArea.left = safeArea.top;
        safeArea.right = safeArea.bottom;
    }
    safeArea.top = safeArea.bottom = 0;
    return safeArea;
}

#pragma mark Java runtime

NSString* getSelectedJavaHome(NSString* defaultJRETag, int minVersion) {
    NSDictionary *pref = getPrefObject(@"java.java_homes");
    NSDictionary<NSString *, NSString *> *selected = pref[@"0"];
    NSString *selectedVer = selected[defaultJRETag];
    if (minVersion > selectedVer.intValue) {
        NSArray *sortedVersions = [pref.allKeys valueForKeyPath:@"self.integerValue"];
        sortedVersions = [sortedVersions sortedArrayUsingSelector:@selector(compare:)];
        for (NSNumber *version in sortedVersions) {
            if (version.intValue >= minVersion) {
                selectedVer = version.stringValue;
                break;
            }
        }
        if (!selectedVer) {
            NSLog(@"Error: requested Java >= %d was not installed!", minVersion);
            return nil;
        }
    }

    id selectedDir = pref[selectedVer];
    if ([selectedDir isEqualToString:@"internal"]) {
        selectedDir = [NSString stringWithFormat:@"%@/java_runtimes/java-%@-openjdk", NSBundle.mainBundle.bundlePath, selectedVer];
    } else {
        selectedDir = [NSString stringWithFormat:@"%s/java_runtimes/%@", getenv("AME_HOME"), selectedDir];
    }

    if ([NSFileManager.defaultManager fileExistsAtPath:selectedDir]) {
        return selectedDir;
    } else {
        NSLog(@"Error: selected runtime for %@ does not exist: %@", defaultJRETag, selectedDir);
        return nil;
    }
}

#pragma mark Renderer

// ZL2-iOS: 只暴露真正打包进 IPA 的渲染库。
// libmobileglues.dylib 没有随包构建（core/external 下无源码、CMakeLists 无目标），
// 选它会让 egl_bridge 的 dlopen 失败并崩溃，所以在 iOS 上不提供该选项。
static NSArray* availableRendererKeys(void) {
    NSMutableArray *array = @[@"auto", @ RENDERER_NAME_GL4ES].mutableCopy;

    // 渲染库位于 App.app/Frameworks/ 下，用 @rpath 加载过，这里按文件存在性判断
    NSString *frameworksPath = [[[NSBundle mainBundle] bundlePath]
                                stringByAppendingPathComponent:@"Frameworks"];

    NSFileManager *fm = [NSFileManager defaultManager];

    // MTL_ANGLE (libtinygl4angle.dylib)
    if ([fm fileExistsAtPath:[frameworksPath stringByAppendingPathComponent:@ RENDERER_NAME_MTL_ANGLE]]) {
        [array addObject:@ RENDERER_NAME_MTL_ANGLE];
    }
    // VK_ZINK (libOSMesa.8.dylib)
    if ([fm fileExistsAtPath:[frameworksPath stringByAppendingPathComponent:@ RENDERER_NAME_VK_ZINK]]) {
        [array addObject:@ RENDERER_NAME_VK_ZINK];
    }
    return array;
}

NSArray* getRendererKeys(BOOL containsDefault) {
    NSMutableArray *array = availableRendererKeys().mutableCopy;

    if (containsDefault) {
        [array insertObject:@"(default)" atIndex:0];
    }

    return array;
}

NSArray* getRendererNames(BOOL containsDefault) {
    // 本地化名必须与 getRendererKeys 一一对应，顺序不能乱
    NSMutableArray *array = @[
        localize(@"preference.title.renderer.debug.auto", nil),
        localize(@"preference.title.renderer.debug.gl4es", nil)
    ].mutableCopy;

    NSArray *keys = availableRendererKeys();
    if ([keys containsObject:@ RENDERER_NAME_MTL_ANGLE]) {
        [array addObject:localize(@"preference.title.renderer.debug.angle", nil)];
    }
    if ([keys containsObject:@ RENDERER_NAME_VK_ZINK]) {
        [array addObject:localize(@"preference.title.renderer.debug.zink", nil)];
    }

    if (containsDefault) {
        [array insertObject:@"(default)" atIndex:0];
    }

    return array;
}
