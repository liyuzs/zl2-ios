#import "SurfaceViewController.h"

#include "jni.h"
#include <assert.h>
#include <dlfcn.h>

#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>

#include "EGL/egl.h"
#include "EGL/eglext.h"
#include "GL/osmesa.h"

#include "glfw_keycodes.h"
#include "ctxbridges/bridge_tbl.h"
#include "ctxbridges/osmesa_internal.h"
#include "utils.h"

int clientAPI;

void JNI_LWJGL_changeRenderer(const char* value_c) {
    JNIEnv *env;
    (*runtimeJavaVMPtr)->GetEnv(runtimeJavaVMPtr, (void **)&env, JNI_VERSION_1_4);
    jstring key = (*env)->NewStringUTF(env, "org.lwjgl.opengl.libname");
    jstring value = (*env)->NewStringUTF(env, value_c);
    jclass clazz = (*env)->FindClass(env, "java/lang/System");
    jmethodID method = (*env)->GetStaticMethodID(env, clazz, "setProperty", "(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;");
    (*env)->CallStaticObjectMethod(env, clazz, method, key, value);
}

void pojavTerminate() {
    CallbackBridge_nativeSetInputReady(NO);
    if (!br_terminate) return;
    br_terminate();
}

void* pojavGetCurrentContext() {
    return br_get_current();
}

int pojavInit(BOOL useStackQueue) {
    clientAPI = GLFW_OPENGL_API;
    isInputReady = 1;
    isUseStackQueueCall = useStackQueue;
    return JNI_TRUE;
}

// ZL2-iOS: 判断某个渲染库是否真的存在于 App.app/Frameworks/ 下。
// libmobileglues.dylib 未随包构建，若盲目 dlopen 会在启动游戏时崩溃。
static BOOL zl2_renderer_available(NSString *libName) {
    NSString *frameworksPath = [[[NSBundle mainBundle] bundlePath]
                                stringByAppendingPathComponent:@"Frameworks"];
    NSString *full = [frameworksPath stringByAppendingPathComponent:libName];
    return [[NSFileManager defaultManager] fileExistsAtPath:full];
}

int pojavInitOpenGL() {
    NSString *renderer = NSProcessInfo.processInfo.environment[@"RENDERER"];

    // 用户配置里可能残留 iOS 上不存在的渲染器（如 MobileGlues），先兜底回落
    if (renderer.length == 0 || ![renderer isEqualToString:@"auto"]) {
        if (renderer.length > 0 && !zl2_renderer_available(renderer)) {
            NSLog(@"[ZL2] 渲染器 %@ 不在包内，回落到 GL4ES", renderer);
            renderer = @ RENDERER_NAME_GL4ES;
            setenv("RENDERER", renderer.UTF8String, 1);
        }
    }

    BOOL isAuto = [renderer isEqualToString:@"auto"];
    if (isAuto || [renderer isEqualToString:@ RENDERER_NAME_GL4ES]) {
        // At this point, if renderer is still auto (unspecified major version), pick gl4es
        renderer = @ RENDERER_NAME_GL4ES;
        setenv("RENDERER", renderer.UTF8String, 1);
        set_gl_bridge_tbl();
    } else if ([renderer isEqualToString:@ RENDERER_NAME_MOBILEGLUES]) {
        renderer = @ RENDERER_NAME_MOBILEGLUES;
        setenv("RENDERER", renderer.UTF8String, 1);
        set_gl_bridge_tbl();
    } else if ([renderer isEqualToString:@ RENDERER_NAME_MTL_ANGLE]) {
        set_gl_bridge_tbl();
    } else if ([renderer hasPrefix:@"libOSMesa"]) {
        setenv("GALLIUM_DRIVER","zink",1);
        set_osm_bridge_tbl();
    }
    JNI_LWJGL_changeRenderer(renderer.UTF8String);
    // Preload renderer library
    dlopen([NSString stringWithFormat:@"@rpath/%@", renderer].UTF8String, RTLD_GLOBAL);

    return !br_init();
    //return 0;
}

void pojavSetWindowHint(int hint, int value) {
    if (hint == GLFW_CLIENT_API) {
        clientAPI = value;
    } else if (strcmp(getenv("RENDERER"), "auto")==0 && hint == GLFW_CONTEXT_VERSION_MAJOR) {
        switch (value) {
            case 1:
            case 2:
                setenv("RENDERER", RENDERER_NAME_GL4ES, 1);
                JNI_LWJGL_changeRenderer(RENDERER_NAME_GL4ES);
                break;
            // case 4: use Zink?
            default:
                // ZL2-iOS: 原来默认走 MobileGlues，但该库未随包构建，会崩。
                // 有 MTL_ANGLE 就优先用它（Metal 直通，iOS 上效率最好），否则退 GL4ES。
                if (zl2_renderer_available(@ RENDERER_NAME_MTL_ANGLE)) {
                    setenv("RENDERER", RENDERER_NAME_MTL_ANGLE, 1);
                    JNI_LWJGL_changeRenderer(RENDERER_NAME_MTL_ANGLE);
                } else {
                    setenv("RENDERER", RENDERER_NAME_GL4ES, 1);
                    JNI_LWJGL_changeRenderer(RENDERER_NAME_GL4ES);
                }
                break;
        }
    }
}

void pojavSwapBuffers() {
    br_swap_buffers();
    // ZL2-iOS: 每完成一次缓冲交换 = 渲染了一帧。
    // 计数交给 Swift 层的 ZL2FrameStats 去算 FPS，这里只累加，零开销。
    extern void ZL2FrameStatsTick(void);
    ZL2FrameStatsTick();
}

void pojavMakeCurrent(basic_render_window_t* window) {
    br_make_current(window);
}

void* pojavCreateContext(basic_render_window_t* contextSrc) {
    if (clientAPI == GLFW_NO_API) {
        // Game has selected Vulkan API to render
        return (__bridge void *)SurfaceViewController.surface.layer;
    }

    static BOOL inited = NO;
    if (!inited) {
        inited = YES;
        pojavInitOpenGL();
    }

    return br_init_context(contextSrc);
}

void pojavSwapInterval(int interval) {
    if (!br_swap_interval) return;
    br_swap_interval(interval);
}
