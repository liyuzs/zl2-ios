//
//  ZL2FrameStats.m
//  ZL2-iOS · 帧率与内存统计
//
//  核心（C/ObjC）每渲染一帧会调用 ZL2FrameStatsTick()，
//  Swift 层通过 ZL2FrameStats 读取累计帧数，自己算 FPS。
//
//  为什么不在这里算 FPS：
//    · 这里在渲染线程，不能加锁、不能碰 UI
//    · 交给 Swift 的 Timer 每秒读一次差分，最省事也最安全
//
//  内存统计用 mach task_info 拿真实常驻内存（RSS），
//  比 ProcessInfo.physicalMemory 准得多。
//

#import <Foundation/Foundation.h>
#import <mach/mach.h>

// 用原子累加，避免多线程竞争
static _Atomic(uint64_t) g_frameCount = 0;

/// 由渲染线程每帧调用（见 egl_bridge.m 的 pojavSwapBuffers）
void ZL2FrameStatsTick(void) {
    atomic_fetch_add_explicit(&g_frameCount, 1, memory_order_relaxed);
}

/// 读取自启动以来的累计帧数
uint64_t ZL2FrameStatsTotal(void) {
    return atomic_load_explicit(&g_frameCount, memory_order_relaxed);
}

/// 重置计数（进入游戏时调一次，让 FPS 从头算）
void ZL2FrameStatsReset(void) {
    atomic_store_explicit(&g_frameCount, 0, memory_order_relaxed);
}

/// 当前进程真实常驻内存（字节）。失败返回 0。
uint64_t ZL2FrameStatsResidentMemory(void) {
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t kr = task_info(mach_task_self(),
                                 MACH_TASK_BASIC_INFO,
                                 (task_info_t)&info,
                                 &size);
    if (kr != KERN_SUCCESS) {
        return 0;
    }
    return (uint64_t)info.resident_size;
}
