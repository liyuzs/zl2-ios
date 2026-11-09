// 重新生成 docs/设置项审计.md
//
// 为什么要有这个脚本：
//   第79轮发现审计文档的数字严重过时（写 13 项生效，实际 54），根因是**手写的统计**。
//   于是那轮改成"从代码生成"，但生成逻辑写在一次性命令里 —— 第87轮又要改分类时，
//   只能手工重算。所以把生成器固化下来。
//
// 用法：node _gen-settings-audit.js
//   → 读 src/ZLSettings.swift 的 115 个 key
//   → 读 src/SettingsScreen.swift 的 platformOnly / notWired 两个集合
//   → 覆写 docs/设置项审计.md
//
// 配套检查：_check-settings-audit.js 会核对文档数字是否等于代码实际。
// 所以流程是：改完集合 → 跑本脚本 → 跑检查。

const PATHS = require('./_paths');
const fs = require('fs');
const path = require('path');

const ROOT = PATHS.REPO;
const OUT = path.join(ROOT, 'docs', '设置项审计.md');

const settingsSrc = fs.readFileSync(path.join(ROOT, 'src', 'ZLSettings.swift'), 'utf8');
const screenSrc = fs.readFileSync(path.join(ROOT, 'src', 'SettingsScreen.swift'), 'utf8');

const keys = [...settingsSrc.matchAll(/\.init\(key:\s*"([^"]+)"/g)].map(m => m[1]);

function extractSet(name) {
  const start = screenSrc.indexOf('static let ' + name);
  if (start < 0) return [];
  const end = screenSrc.indexOf(']', start);
  return [...screenSrc.slice(start, end).matchAll(/"([a-zA-Z]+)"/g)].map(m => m[1]);
}

// **必须读全部四个集合**。
// 第79/87轮我只解析了 platformOnly + notWired 两个，漏掉 renderOnly / launcherLook，
// 于是把"可用"算成 54 / 42 —— 真实是 30。两轮审计都错了，因为把结构的一部分当成了全部。
const SETS = ['platformOnly', 'notWired', 'renderOnly', 'launcherLook'];
const bySet = {};
for (const s of SETS) bySet[s] = extractSet(s).sort();

const platform = bySet.platformOnly;
const notWired = bySet.notWired;
const renderOnly = bySet.renderOnly;
const launcherLook = bySet.launcherLook;

const covered = new Set([...platform, ...notWired, ...renderOnly, ...launcherLook]);
const working = keys.filter(k => !covered.has(k)).sort();

const pct = n => Math.round(n * 100 / keys.length);

// 安卓专属按前缀分组，便于阅读
const groups = new Map();
for (const k of platform) {
  let g = '其他';
  if (/^gyroscope/.test(k)) g = '陀螺仪';
  else if (/^gamepad/.test(k)) g = '手柄';
  else if (/MouseHotspot|^mouse|^cursor/.test(k)) g = '鼠标';
  else if (/^hotbar/.test(k)) g = '热键栏';
  else if (/^launcher/.test(k)) g = '启动器外观';
  else if (/^search/.test(k)) g = '搜索平台';
  else if (/menuBall/.test(k)) g = '悬浮球';
  else if (/ime|Ime|physical|sdl/.test(k)) g = '输入法 / 物理键';
  else if (/^(vulkan|graphics|sfpew|zink|vsync|dumpShaders|nativeLib|gameFullScreen)/.test(k)) g = '安卓渲染栈';
  if (!groups.has(g)) groups.set(g, []);
  groups.get(g).push(k);
}

const lines = [];
const W = s => lines.push(s);

W('# 设置项审计报告');
W('');
W('> 目的：搞清楚 115 个设置项里，哪些在 iOS 上真正生效');
W('> ');
W('> **本文由 `_gen-settings-audit.js` 从代码生成，不要手改。**');
W('> 权威来源：`src/SettingsScreen.swift` 的 `ZLUnsupportedSettings`（`platformOnly` / `notWired`）。');
W('> 改完那两个集合 → 跑生成器 → 跑 `_check-settings-audit.js`。');
W('> 第79轮就是栽在"手写统计"上：文档写 13 项生效，实际 54 项。');
W('');
W('---');
W('');
W('## 一、总览');
W('');
W(`ZLSettings.swift 照搬了安卓 ZL2 的全部 **${keys.length} 项**设置。逐项对撞代码后：`);
W('');
W('| 分类 | 数量 | 占比 | UI 处理 |');
W('|---|---|---|---|');
W(`| ✅ **可用** | ${working.length} | ${pct(working.length)}% | 正常可调 |`);
W(`| ⛔ 安卓专属（iOS 无对应能力） | ${platform.length} | ${pct(platform.length)}% | 置灰 + 说明「iOS 不支持」 |`);
W(`| 🔧 待接线（真 TODO） | ${notWired.length} | ${pct(notWired.length)}% | 置灰 + 说明「尚未接入」 |`);
W(`| 🎨 安卓渲染栈 | ${renderOnly.length} | ${pct(renderOnly.length)}% | 置灰 + 说明「iOS 使用 Metal 渲染」 |`);
W(`| 🪟 启动器外观（Material3 特有） | ${launcherLook.length} | ${pct(launcherLook.length)}% | 置灰 + 说明「跟随系统外观」 |`);
W('');
W('判定方式：不在上述两个集合里的算可用。');
W('');
W('---');
W('');
W(`## 二、可用的 ${working.length} 项`);
W('');
W(working.join(' · '));
W('');
W('---');
W('');
W(`## 三、待接线（${notWired.length} 项）`);
W('');
W('这些 iOS **应该支持**，只是还没接：');
W('');
for (const k of notWired) W(`- \`${k}\``);
W('');
W('> `versionIsolation` 严格说不算"待接线"，是"核心侧改不动"（核心自己拼游戏目录、忽略 `GAME_DIR`）。');
W('> 放在这里是为了让 UI 继续置灰。');
W('');
W('---');
W('');
W(`## 四、安卓专属（${platform.length} 项）`);
W('');
W('iOS 系统层面没有对应能力，置灰并说明原因。按类别：');
W('');
for (const g of [...groups.keys()].sort()) {
  const arr = groups.get(g);
  W(`**${g}（${arr.length} 项）**：${arr.join(' · ')}`);
  W('');
}
W('---');
W('');
W(`## 五、安卓渲染栈（${renderOnly.length} 项）`);
W('');
W('iOS 走 Metal / ANGLE，Turnip、Zink、SFPEW、Vulkan 这些在 iOS 上不存在对应实现：');
W('');
W(renderOnly.length ? renderOnly.map(k => '`' + k + '`').join(' · ') : '（无）');
W('');
W('---');
W('');
W(`## 六、启动器外观（${launcherLook.length} 项）`);
W('');
W('安卓 Material3 的特有外观项；iOS 版统一跟随系统外观：');
W('');
W(launcherLook.length ? launcherLook.map(k => '`' + k + '`').join(' · ') : '（无）');
W('');
W('---');
W('');
W('## 七、维护约定');
W('');
W('1. 改 `ZLUnsupportedSettings` 的两个集合 → 跑 `_gen-settings-audit.js` 重新生成本文。');
W('2. 接线了一个 `notWired` 项 → 从集合里删掉，并在注释里写「已接线，不要再加回：xxx → 谁实现的」。');
W('3. 不要凭"看起来像安卓专属"就归类：要找到 iOS 上对应的 API，或者明确说明没有。');
W('4. **新加设置项时，先确认它有消费方**：第87轮查出 12 项（`vulkanDriver` / `graphicsApi` / `sfpew*` / `zink*` / `vsyncInZink` / `dumpShaders` / `nativeLibPlugins` / `gameFullScreen` / `sustainedPerformance` / `skipGameIntegrityCheck` / `logBufferFlushInterval`）在设置页之外**零引用**，却一直显示为"可用"。');
W('');

fs.writeFileSync(OUT, lines.join('\n'), 'utf8');
console.log(`已生成 ${OUT}`);
console.log(`共 ${keys.length} 项 → 可用 ${working.length} / 安卓专属 ${platform.length} / 待接线 ${notWired.length}`);
