# 缺失组件：Java 侧启动器 jar

> **状态：已确认为「启动游戏必然失败」的根本原因。**
> 发现于 2026-11-08 第 29 轮，用 `_check-runtime-assets.js` 自动检出。

---

## 一句话

`core/JavaLauncher.m` 在拉起 JVM 时会往 classpath 和 `-javaagent` 里塞三个 jar，
而**这个仓库里一个 `.jar` 文件都没有**，也没有任何 Java 构建步骤。

结果：点「启动游戏」必然失败。不是「可能失败」，是必然。

---

## 证据

### 核心需要什么

`core/JavaLauncher.m`：

```objc
// 第 263-264 行：无条件添加 -javaagent
NSString *librariesPath = [NSString stringWithFormat:@"%@/libs", NSBundle.mainBundle.bundlePath];
margv[++margc] = [NSString stringWithFormat:@"-javaagent:%@/patchjna_agent.jar=", librariesPath].UTF8String;

// 第 266 行：（开了 Cosmetica 时）
margv[++margc] = [NSString stringWithFormat:@"-javaagent:%@/arc_dns_injector.jar=...", librariesPath].UTF8String;

// 第 358-367 行：Caciocavallo 的 bootclasspath
NSString *cacio_libs_path = [NSString stringWithFormat:@"%@/libs_caciocavallo%s", NSBundle.mainBundle.bundlePath, ...];
// 目录下所有 .jar 拼进 -Xbootclasspath/a:

// 第 386-392 行：classpath 与主类
NSString *classpath = [NSString stringWithFormat:@"%@/*", librariesPath];
margv[++margc] = "-cp";
margv[++margc] = classpath.UTF8String;
margv[++margc] = "net.kdt.pojavlaunch.PojavLauncher";
```

也就是说需要：

| 路径 | 作用 | 缺了会怎样 |
|---|---|---|
| `<bundle>/libs/patchjna_agent.jar` | `-javaagent` | **JVM 直接启动失败**：`Error opening zip file or JAR manifest missing` |
| `<bundle>/libs/*.jar`（含 `PojavLauncher.jar`） | `-cp` + 主类 `net.kdt.pojavlaunch.PojavLauncher` | `ClassNotFoundException` —— 真正的 Minecraft 参数拼装全在这个 Java 程序里 |
| `<bundle>/libs_caciocavallo17/*.jar` | `-Xbootclasspath/a` | `-Dawt.toolkit=...CTCToolkit` 找不到类，AWT 起不来 |

### 仓库现状

```
全仓库 .jar 文件数：0
core/libs/              不存在
core/libs_caciocavallo17/ 不存在
core/CMakeLists.txt     没有任何 jar / java / gradle 构建步骤
```

### 已发布的 IPA 也缺

`ZL2.ipa`（build-235）解包后 980 个条目，`Payload/ZL2.app/` 下只有
`Frameworks/`、`java_runtimes/`、几个 js 和主程序，**没有 `libs/` 目录**。

---

## 为什么之前的检查没发现

之前几轮查的是「Swift 与核心之间的约定」（键名、布局格式、偏好键），
没有查「核心与它自己的资源文件之间」的约定。

新写的 `_check-runtime-assets.js` 补上了这一块：它把核心源码里所有
`<bundle>/xxx` 形式的路径抽出来，逐个对撞仓库里的实际文件。

---

## 怎么补

三个 jar 都来自上游 PojavLauncher 的 Java 工程（GPL-3.0），不是能"写几行 Swift 补上"的东西：

1. **`PojavLauncher.jar`** —— 上游 `PojavLauncher/JavaApp/` 用 Gradle 构建。
   它负责：读版本 JSON、拼 classpath、解 natives、启动游戏主类。
   几千行 Java，包含 `Tools`、`LauncherProfiles`、`MCLauncher`、`PojavClassLoader` 等。
2. **`patchjna_agent.jar`** —— 一个小 javaagent，用于 patch JNA。
3. **`libs_caciocavallo17/*.jar`** —— Caciocavallo 的 iOS/移动端实现，用于在没有 X11 的环境里跑 AWT。

### 可行的获取途径（按优先级）

| 途径 | 说明 |
|---|---|
| **A. 从上游 IPA 提取** | `PojavLauncherTeam/PojavLauncher_iOS` 的 Release 里有 IPA（v2.2，103 MB）。解包取 `Payload/*.app/libs/` 与 `libs_caciocavallo17/`。风险：版本与我们的核心不是同一代，需要试。 |
| **B. 自己构建** | 需要 Gradle + JDK，把上游 JavaApp 编译成 jar。工作量大但版本可控。 |
| **C. 从 .deb 提取** | 同 A，上游还发布了 rootless.deb（70 MB），结构类似。 |

拿到后放进仓库（建议 `core/resources/libs/` 与 `core/resources/libs_caciocavallo17/`），
并在 CI 的 `Bundle runtime & frameworks` 步骤里加两行 `cp -R`。

---

## 验收标准

补上之后，`_check-runtime-assets.js` 应该从

```
✗ 1 项缺失：Java 启动器 jar
```

变成

```
✓ 全部就位
```

同时 IPA 解包后应能看到 `Payload/ZL2.app/libs/` 与 `Payload/ZL2.app/libs_caciocavallo17/`。

---

## 给测试的人的提示

在这个问题修好之前，**「启动游戏」这一步一定失败**，而且失败得很快
（JVM 连启动都没完成，不会出现 Minecraft 窗口）。

如果看到的是「启动失败」但日志里有一行 `Error opening zip file` 或
`ClassNotFoundException: net.kdt.pojavlaunch.PojavLauncher`，
那就是这个问题，不用怀疑是操作或设备的问题。
