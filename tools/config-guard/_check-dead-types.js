// 零使用的顶层类型（死代码）
//
// 起因：ios-zl2 第84轮摸出一条信号 ——「定义了但零调用」「写了但没人读」。
// 第85轮把它做成扫描，先看「零外部引用」有 181 个，但绝大多数是**只在本文件用的辅助类型**
// （`GuideStep`、`ZLSettingRow`、各种 DTO），那属于正常的文件内组织，不是死代码。
//
// 真正的死代码是：**连自己文件里都没人用** —— 标识符在整个 src 里只出现 1 次（就是声明本身）。
// （第143轮起：统计前会剥掉整行注释 —— 否则注释里提一次就被当成"有人用"）
// （第143轮起：ObjC 的 `NSClassFromString(@"X")` 也算引用 —— 否则 ZLOverlayHost 这类会被误删）
// 这样筛出来 17 个，其中：
//   · `ZLKeycode`（102 行 101 个键码常量）+ 同文件的 `ZLKeySpec` 整套 —— 整个文件零引用 → 已删
//   · `ZLWaveShape` —— 第67轮删掉 `ZLWaveLine` 之后就被落下了
//   · 其余几个小部件/协议 → 逐个确认后处理
//
// **必须排除的一类**：由框架/系统隐式实例化的类型。它们的名字在代码里只出现一次，
// 但绝不是死的：
//   · `@main struct XxxApp: App`            —— 应用入口
//   · `struct Xxx: AppShortcutsProvider`    —— 快捷指令提供者
//   · `final class Xxx: NEPacketTunnelProvider` —— 网络扩展
//   · `class Xxx: NSObject, UIApplicationDelegate` —— 应用代理
//   · `: SceneDelegate` / `: UIWindowSceneDelegate`
// 第85轮差点把 `ZL2StyleApp`（@main）和 `CraftLauncherShortcuts` 当死代码删掉。

const fs = require('fs');
const path = require('path');
const PATHS = require('./_paths');
const { SRC } = PATHS;
// 系统/框架隐式实例化 —— 名字只出现一次是正常的
const FRAMEWORK_MARKERS = [
  '@main',
  'AppShortcutsProvider',
  'NEPacketTunnelProvider',
  'UIApplicationDelegate',
  'SceneDelegate',
  'UIWindowSceneDelegate',
  'NSItemProviderReading',
  'PreviewProvider',
];

// 明确保留（功能未接入但有意留着），登记理由
const ALLOW = {
  // 第143轮发现：276 行的完整页面（改名 / 换 MC / 换加载器），但**从未接线**
  // （不在 AppRoute 里，也没有任何导航到它）。它是"写好了没挂载"的真功能，
  // 不是死代码 —— 下一轮要决定：接上一个入口，或删掉。先占位避免一改就红。
  'ModifyVersionScreen': '真功能未接线，待决定（接线或删）',
  'MCVersionPicker': '同上，ModifyVersionScreen 的私有子视图',
  ZLEasyTierPacketTunnelProvider: '远程联机（Terracotta）未接入，NE 扩展类先留着',
  EasyTierBridge:                 '同上',
  SwitchGameDirIntent:            '快捷指令意图，等 AppIntents 配置齐了再接',
  CraftLauncherShortcuts:         '快捷指令提供者，系统隐式调用（也已被框架标记排除）',
  ZLSharedStore:                  'App Group 共享存储，等 NE 接入后使用',
};

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const texts = new Map(files.map(f => [f, fs.readFileSync(path.join(SRC, f), 'utf8')]));

// **统计前剥掉整行注释**（第143轮）：
// 注释里提到一个类型名，会让它从"只出现 1 次"变成 2 次，从而被当成"有人用"。
// 实例：`SampleData` 整个 enum 零引用，但有一句 `/// …走 SampleData` → 被漏掉。
// 保守做法：只剥**整行**注释（`^\s*//`），不剥行尾 —— 行尾剥 `//` 会破坏 URL 字符串。
const stripLineComments = src => src
  .split('\n')
  .map(line => (line.trim().startsWith('//') ? '' : line))
  .join('\n');
const joined = [...texts.values()].map(stripLineComments).join('\n');

// **跨语言动态引用**（第143轮补的第三个盲区）：
// ObjC 侧用 `NSClassFromString(@"ZL2iOS.ZLOverlayHost")` / `@"ZLOverlayHost"` 实例化 Swift 类时，
// Swift 源码里一个引用都没有 —— 原来会被判成死代码。
// 实例：`ZLOverlayHost.swift` 差点被误删，而它负责 FPS 悬浮层（SurfaceViewController.m:134/292）。
const dynamicNames = new Set();
try {
  const coreDir = path.join(PATHS.REPO, 'core');
  const walkCore = dir => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      if (e.name === 'build' || e.name === 'external') continue;
      const full = path.join(dir, e.name);
      if (e.isDirectory()) { walkCore(full); continue; }
      if (!e.name.endsWith('.m')) continue;
      const t = fs.readFileSync(full, 'utf8');
      for (const m of t.matchAll(/NSClassFromString\(\s*@"([\w.]+)"/g)) {
        dynamicNames.add(m[1].split('.').pop());   // 去掉模块前缀
      }
    }
  };
  walkCore(coreDir);
} catch (e) {
  console.log('（提示：没能扫 core 的动态类引用 —— ' + e.message + '）');
}

const declRe = /^[ \t]*(?:public |internal |private |fileprivate )?(?:final )?(?:struct|class|enum|protocol|actor)\s+([A-Z]\w*)/gm;

const dead = [];
for (const [file, text] of texts) {
  for (const m of text.matchAll(declRe)) {
    const name = m[1];
    if (ALLOW[name]) continue;

    const count = (joined.match(new RegExp('\\b' + name + '\\b', 'g')) || []).length;
    if (count > 1) continue;                        // 自己文件里有人用，正常

    // 框架隐式实例化？看声明附近有没有标记
    const after = text.slice(m.index, m.index + 400);
    if (FRAMEWORK_MARKERS.some(k => after.includes(k))) continue;
    const before = text.slice(Math.max(0, m.index - 200), m.index);
    if (FRAMEWORK_MARKERS.some(k => before.includes(k))) continue;

    const line = text.slice(0, m.index).split('\n').length;
    dead.push({ name, file, line });
  }
}

console.log(`扫描 ${files.length} 个文件`);

// ---- 附加判据（第143轮）：整个文件是死代码 ----
// 原理：如果一个文件里**所有**顶层类型都只在本文件出现，那这个文件没有任何外部入口。
// 实例：LaunchContract.swift 6 个类型全部零外部引用，但互相引用让它们各自的 count > 1。
const typeDeclRe = /^[ \t]*(?:public |internal |private |fileprivate )?(?:final )?(?:struct|class|enum|actor|protocol)\s+(\w+)/gm;
const deadFiles = [];
for (const [f, text] of texts) {
  const names = [];
  let m2;
  typeDeclRe.lastIndex = 0;
  while ((m2 = typeDeclRe.exec(text)) !== null) names.push(m2[1]);
  if (names.length === 0) continue;
  // 逐个数：这个类型在**其它文件**里出现几次
  const outsideCounts = names.map(n => {
    if (dynamicNames.has(n)) return 1;    // 被 ObjC 动态实例化 → 不是死代码
    let c = 0;
    for (const [g, gt] of texts) {
      if (g === f) continue;
      c += (gt.match(new RegExp("\\b" + n + "\\b", "g")) || []).length;
    }
    return c;
  });
  // 文件里所有类型都在 ALLOW 里 → 不是"未登记的"死文件
  const allAllowed = names.every(n => ALLOW[n]);
  if (outsideCounts.every(c => c === 0) && !allAllowed) deadFiles.push({ file: f, types: names });
}

if (deadFiles.length > 0) {
  console.log('⚠ ' + deadFiles.length + ' 个文件里**所有**顶层类型都没有外部引用（= 整个文件是死代码）：');
  for (const d of deadFiles) {
    console.log(`   ${d.file}  —— ${d.types.length} 个类型：${d.types.join("、")}`);
  }
  console.log('');
}
console.log('');

if (dead.length === 0 && deadFiles.length === 0) {
  console.log('✓ 没有零使用的顶层类型');
  process.exit(0);
}

console.log(`⚠ ${dead.length} 个顶层类型在整个 src 里只出现 1 次（= 没人用）：`);
for (const d of dead) console.log(`    ${d.name}   ${d.file}:${d.line}`);
console.log('');
console.log('处理：① 删掉 ② 接上线 ③ 有意保留的加进 ALLOW 并写理由。');
console.log('注意：@main App / AppShortcutsProvider / NEPacketTunnelProvider 这类框架实例化的不算死代码。');
process.exit(1);
