#import "authenticator/BaseAuthenticator.h"
#import "AppDelegate.h"
#import "SceneDelegate.h"
#import "LauncherNavigationController.h"
#import "LauncherPreferences.h"
#import "LauncherSplitViewController.h"
#import "PLLogOutputView.h"
#import "SurfaceViewController.h"
#import "MinecraftOptionUtils.h"

#include <objc/runtime.h>
#include "ios_uikit_bridge.h"
#include "utils.h"

void internal_showDialog(NSString* title, NSString* message) {
    NSLog(@"[UI] Dialog shown: %@: %@", title, message);

    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
        message:message
        preferredStyle:UIAlertControllerStyleAlert];
    //text.dataDetectorTypes = UIDataDetectorTypeLink;
    UIAlertAction* okAction = [UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];

    UIWindow *alertWindow = [[UIWindow alloc] initWithWindowScene:UIWindow.mainWindow.windowScene];
    alertWindow.frame = UIScreen.mainScreen.bounds;
    alertWindow.rootViewController = [UIViewController new];
    alertWindow.windowLevel = 1000;
    [alertWindow makeKeyAndVisible];
    objc_setAssociatedObject(alert, @selector(alertWindow), alertWindow, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [alertWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

void showDialog(NSString* title, NSString* message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        internal_showDialog(title, message);
    });
}

JNIEXPORT void JNICALL Java_net_kdt_pojavlaunch_uikit_UIKit_showError(JNIEnv* env, jclass clazz, jstring title, jstring message, jboolean exitIfOk) {
    const char *title_c = (*env)->GetStringUTFChars(env, title, 0);
    const char *message_c = (*env)->GetStringUTFChars(env, message, 0);
    NSString *title_o = @(title_c);
    NSString *message_o = @(message_c);
    (*env)->ReleaseStringUTFChars(env, title, title_c);
    (*env)->ReleaseStringUTFChars(env, message, message_c);

    if (SurfaceViewController.isRunning) {
        NSLog(@"%@\n%@", title_o, message_o);
        [PLLogOutputView handleExitCode:1];
        return;
    }

dispatch_async(dispatch_get_main_queue(), ^{

    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:title_o message:message_o
        preferredStyle:UIAlertControllerStyleAlert];
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentLeft;

    NSMutableAttributedString *atrStr = [[NSMutableAttributedString alloc] initWithString:message_o attributes:@{NSParagraphStyleAttributeName:style,NSFontAttributeName:[UIFont systemFontOfSize:13.0]}];

    [alert setValue:atrStr forKey:@"attributedMessage"];

    UIAlertAction* okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            if (exitIfOk == JNI_TRUE) {
                exit(-1);
            }
        }];
    [alert addAction:okAction];
    
    UIAlertAction* copyAction = [UIAlertAction actionWithTitle:@"Copy" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            UIPasteboard.generalPasteboard.string = message_o;
            if (exitIfOk == JNI_TRUE) {
                exit(-1);
            }
        }];
    [alert addAction:copyAction];
    
    [currentVC() presentViewController:alert animated:YES completion:nil];
});
}

// ZL2-iOS: 补上 UIKit 的两个 native 方法。
//
// 从 jar 的字节码反查发现：org/lwjgl/glfw/GLFW.class 引用了
// net/kdt/pojavlaunch/uikit/UIKit.updateMCGuiScale —— 也就是说 LWJGL
// 在创建/缩放窗口时会调它。而我们原来只导出了 Java_..._UIKit_showError，
// 这个方法缺失，被调用时就是 UnsatisfiedLinkError（启动或改窗口尺寸时崩）。
//
// 核心本来就有等价实现（MinecraftOptionUtils 的 updateMCGuiScale，
// 按窗口尺寸重算 guiScale），直接转发即可。
JNIEXPORT void JNICALL Java_net_kdt_pojavlaunch_uikit_UIKit_updateMCGuiScale(
        JNIEnv* env, jclass clazz, jint height) {
    (void)env; (void)clazz; (void)height;
    @autoreleasepool {
        [MinecraftOptionUtils.sharedInstance updateMCGuiScale];
    }
}

// 推送式的 AWT 画面刷新。Amethyst 把显示改成了拉取式
// （SurfaceView 主动调 CTCScreen.getCurrentScreenRGB()），这条路径本来就没人走 ——
// 全部 jar 里也只有 UIKit.class 自己声明了它、没有任何调用者。
// 但既然 Java 侧声明了 native，留个空实现比让它 UnsatisfiedLinkError 安全。
JNIEXPORT void JNICALL Java_net_kdt_pojavlaunch_uikit_UIKit_refreshAWTBuffer(
        JNIEnv* env, jclass clazz, jintArray buf) {
    (void)env; (void)clazz; (void)buf;
    // 故意留空：画面由 SurfaceView 的拉取式路径负责。
}

jstring UIKit_accessClipboard(JNIEnv* env, jint action, jbyteArray copySrc) {
    if (action == CLIPBOARD_PASTE) {
        // paste request
        if (UIPasteboard.generalPasteboard.hasStrings) {
            return (*env)->NewStringUTF(env, [UIPasteboard.generalPasteboard.string UTF8String]);
        } else {
            return (*env)->NewStringUTF(env, "");
        }
    } else if (action == CLIPBOARD_COPY) {
        // copy request
        const char* copySrcC = (*env)->GetByteArrayElements(env, copySrc, 0);
        if (copySrcC) {
            UIPasteboard.generalPasteboard.string = @(copySrcC);
            (*env)->ReleaseByteArrayElements(env, copySrc, copySrcC, 0);
        }
        return NULL;
    } else {
        // unknown request
        NSLog(@"Warning: unknown clipboard action: %x", action);
        return NULL;
    }
}

void UIKit_launchMinecraftSurfaceVC(UIWindow* window, NSDictionary* metadata) {
    // Leave this pref, might be useful later for launching with Quick Actions/Shortcuts/URL Scheme
    //setPreference(@"internal_launch_on_boot", getPreference(@"restart_before_launch"));
    setPrefObject(@"internal.selected_account", BaseAuthenticator.current.authData[@"username"]);
    dispatch_async(dispatch_get_main_queue(), ^{
        tmpRootVC = window.rootViewController;
        [UIView animateWithDuration:0.2 animations:^{
            window.alpha = 0;
        } completion:^(BOOL b){
            [window resignKeyWindow];
            window.alpha = 1;
            window.rootViewController = [[SurfaceViewController alloc] initWithMetadata:metadata];
            [window makeKeyAndVisible];
        }];
    });
}

void UIKit_returnToSplitView() {
    // Researching memory-safe ways to return from SurfaceViewController to the split view
    // so that the app doesn't close when quitting the game (similar behaviour to Android)
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = UIWindow.mainWindow;

        // Return from JavaGUIViewController
        if ([window.rootViewController isKindOfClass:LauncherSplitViewController.class]) {
            [currentVC() dismissViewControllerAnimated:YES completion:nil];
            return;
        }

        // Return from SurfaceViewController
        [UIView animateWithDuration:0.2 animations:^{
            window.alpha = 0;
        } completion:^(BOOL b){
            [window resignKeyWindow];
            window.alpha = 1;
            if (tmpRootVC) {
                window.rootViewController = tmpRootVC;
                tmpRootVC = nil;
            } else {
                window.rootViewController = [[LauncherSplitViewController alloc] initWithStyle:UISplitViewControllerStyleDoubleColumn];
            }
            [window makeKeyAndVisible];
        }];
    });
}

void launchInitialViewController(UIWindow *window) {
    window.rootViewController = [[LauncherSplitViewController alloc] initWithStyle:UISplitViewControllerStyleDoubleColumn];
#if 0
    if (getPrefBool(@"internal.internal_launch_on_boot")) {
        window.rootViewController = [[SurfaceViewController alloc] init];
    } else {
        window.rootViewController = [[LauncherSplitViewController alloc] initWithStyle:UISplitViewControllerStyleDoubleColumn];
    }
#endif
}
