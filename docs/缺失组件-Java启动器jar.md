# Java 侧启动器 jar：从缺失到补上

> **状态：已补上（2026-11-08 第 31 轮）。** 之前这是「启动游戏必然失败」的根因。
> 现在 13 个 jar 已进仓库，`_check-runtime-assets.js` 跑出「✓ 全部就位」。

---

## 一、为什么需要这些 jar

`core/JavaLauncher.m` 拉起 JVM 时要用三条路径：

```objc
NSString *librariesPath = [NSString stringWithFormat:@"%@/libs", NSBundle.mainBundle.bundlePath];

// ① javaagent（现在是存在性判断，见第四节）
margv[..] = "-javaagent:<libs>/patchjna_agent.jar=";

// ② classpath 与主类
margv[..] = "-cp";  margv[..] = "<libs>/*";
margv[..] = "net.kdt.pojavlaunch.PojavLauncher";

// ③ Caciocavallo 的 bootclasspath（AWT 工具包）
NSString *cacio = "<bundle>/libs_caciocavallo17";
// 目录下所有 .jar 拼进 -Xbootclasspath/a:
```

**真正的 Minecraft 参数拼装（读版本 JSON、拼 classpath、解 natives、处理 Forge 安装器）
全在那个 Java 程序里**，Swift / ObjC 替代不了。

---

## 二、jar 是从哪来的

上游 `PojavLauncherTeam/PojavLauncher_iOS` 的 Release **v2.2**
（`net.kdt.pojavlauncher-2.2-ios.ipa`，103 MB，GPL-3.0）。

解包后 `Payload/PojavLauncher.app/` 下正好有需要的三个目录。

### 兼容性核对（放进来之前做的）

不只是看名字像，而是核对了包名与核心导出的 JNI 符号：

| jar 里的类 | 核心（ObjC）导出的符号 |
|---|---|
| `net/kdt/pojavlaunch/value/MinecraftAccount` | `Java_net_kdt_pojavlaunch_value_MinecraftAccount_getAccessTokenFromKeychain` |
| `net/kdt/pojavlaunch/uikit/UIKit` | `Java_net_kdt_pojavlaunch_uikit_UIKit_showError` |

主类 `net/kdt/pojavlaunch/PojavLauncher.class` 也确认在 `libs/launcher.jar` 里
（该 jar 共 71 个条目）。

每个 jar 都用 `ZipFile` 逐个打开验证过条目数正常、没有损坏。

---

## 三、放进仓库的内容（13 个 jar，5.2 MB）

| 目录 | 内容 | 用途 |
|---|---|---|
| `core/resources/libs/` | `launcher.jar`(62KB)、`gson-2.10.1.jar`(277KB)、`jsr305.jar`(32KB)、`lwjgl3-minecraft.jar`(1995KB)、`lwjgl-vulkan.jar`(2589KB)、`lwjgl-vma.jar`(68KB)、`lwjgl-shaderc.jar`(29KB)、`arc_dns_injector.jar`(13KB) | classpath + javaagent |
| `core/resources/libs_caciocavallo/` | `cacio-androidnw-1.10`、`cacio-shared-1.10`、`ResConfHack` | Java 8 用的 AWT |
| `core/resources/libs_caciocavallo17/` | `cacio-shared-1.18`、`cacio-tta-1.18` | Java 17+ 用的 AWT（**主要靠这个**） |

CI 的 `Bundle runtime & frameworks` 步骤会把它们 `cp -R` 进 app bundle，
并断言 `$APP/libs/launcher.jar` 真的存在，缺了直接 `exit 1`。

---

## 四、`patchjna_agent.jar` 仍然缺（已降级为可选）

上游 v2.2 的包里**没有这个 jar**——它是后来才加入的。而核心原本是
**无条件**加 `-javaagent:<libs>/patchjna_agent.jar`。

给 JVM 传一个指向不存在文件的 `-javaagent`，JVM 会在初始化阶段直接

```
Error opening zip file or JAR manifest missing : <path>
```

然后退出——启动流程还没开始就结束了。

已改成存在性判断：

```objc
NSString *patchJna = [librariesPath stringByAppendingPathComponent:@"patchjna_agent.jar"];
if ([NSFileManager.defaultManager fileExistsAtPath:patchJna]) {
    margv[++margc] = [NSString stringWithFormat:@"-javaagent:%@=", patchJna].UTF8String;
} else {
    NSLog(@"[ZL2] libs/patchjna_agent.jar 不存在，跳过 -javaagent");
}
```

缺它只影响 JNA 的部分行为，不影响 JVM 起来。
`arc_dns_injector.jar` 同理（而且它本来就被 `general.cosmetica` 开关挡着）。

---

## 五、还没验证的风险

**这是上游 2.2 的 jar 配我们这代核心，没有真机跑过。**

如果真机日志里出现：

| 现象 | 含义 | 对策 |
|---|---|---|
| `UnsatisfiedLinkError: ...` | Java 侧调了一个 ObjC 没实现的 native 方法 | 需要从 Amethyst 源码用 Gradle 构建同代 jar |
| `NoSuchMethodError` / `NoClassDefFoundError` | jar 之间版本不配套 | 同上 |
| `ClassNotFoundException: net.kdt.pojavlaunch.PojavLauncher` | jar 没打进 bundle | 检查 CI 的 cp 步骤与 `_check-runtime-assets.js` |

也就是说：**这一轮把"必然失败"变成了"可能成功"**，能否真的启动起来要靠真机验证。

---

## 六、如果要从源码重建

上游 Java 工程在 PojavLauncher 仓库里（`JavaApp/` 或 iOS 工程内的 Gradle 子项目）。
需要 JDK + Gradle，产出 `launcher.jar` 等。工作量大但版本可控。

---

## 七、日常检查

```bash
node C:\Users\21793\.dsh\config-guard\_check-runtime-assets.js
```

期望输出结尾是 `✓ 全部就位（11 项）`。
