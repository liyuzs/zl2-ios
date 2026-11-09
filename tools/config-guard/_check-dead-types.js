// 零使用的顶层类型（死代码）
//
// 起因：ios-zl2 第84轮摸出一条信号 ——「定义了但零调用」「写了但没人读」。
// 第85轮把它做成扫描，先看「零外部引用」有 181 个，但绝大多数是**只在本文件用的辅助类型**
// （`GuideStep`、`ZLSettingRow`、各种 DTO），那属于正常的文件内组织，不是死代码。
//
// 真正的死代码是：**连自己文件里都没人用** —— 标识符在整个 src 里只出现 1 次（就是声明本身）。
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

const SRC = 'D:\\ios-zl2\\src';

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
  ZLEasyTierPacketTunnelProvider: '远程联机（Terracotta）未接入，NE 扩展类先留着',
  EasyTierBridge:                 '同上',
  SwitchGameDirIntent:            '快捷指令意图，等 AppIntents 配置齐了再接',
  CraftLauncherShortcuts:         '快捷指令提供者，系统隐式调用（也已被框架标记排除）',
  ZLSharedStore:                  'App Group 共享存储，等 NE 接入后使用',
};

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const texts = new Map(files.map(f => [f, fs.readFileSync(path.join(SRC, f), 'utf8')]));
const joined = [...texts.values()].join('\n');

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
console.log('');

if (dead.length === 0) {
  console.log('✓ 没有零使用的顶层类型');
  process.exit(0);
}

console.log(`⚠ ${dead.length} 个顶层类型在整个 src 里只出现 1 次（= 没人用）：`);
for (const d of dead) console.log(`    ${d.name}   ${d.file}:${d.line}`);
console.log('');
console.log('处理：① 删掉 ② 接上线 ③ 有意保留的加进 ALLOW 并写理由。');
console.log('注意：@main App / AppShortcutsProvider / NEPacketTunnelProvider 这类框架实例化的不算死代码。');
process.exit(1);
