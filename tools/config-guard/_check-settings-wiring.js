// 设置项落地归属检查（第135轮）
//
// 起因：`_audit-stores.js` 的判据是"抓字面量键"，而设置项的实际写入走
// `ZLSettingsStore.set(_:_:)` → `defaults.set(value, forKey: def.key)`
// —— **键是运行时变量**，任何正则都抓不到 → 它报的 17 处「读了 UserDefaults 但没人写」全是误报。
//
// 真正该问的是：**每个"可用"设置项有没有落地归属**？
//   ① 核心桥接 —— CoreBridge 里引用了这个键（把值翻译成核心偏好）
//   ② Swift 消费 —— 别的 Swift 文件引用了它（自己用）
//   ③ 都没有 → 用户在设置页拨了没反应（假功能）或内部状态位（无 UI，无害）
//
// 实测（第135轮）：可用 30 项 = 核心桥接 11 + Swift 消费 15 + 无归属 4（全是内部状态位）。
//
// **局限**（不查什么）：
//   · **只判"有没有人引用这个键"，不判"引用了有没有真生效"**。第135轮的结论是"链路完整"，
//     但那是**引用链的完整**，不是**效果的完整** —— 引用了却走错分支、引用时传了错的值，它都不知道。
//   · **它自己也会被"动态键"绕过**：判据扫的是 `ZLSettings.def("xxx")` 这类**字面量键**。
//     将来如果写成 `store.bool(def)` 传变量，本检查看不见 —— 这正是第135轮 `_audit-stores` 栽的那个坑的变体。
//   · **"无归属 4 项"是人工判定的**：判据只报"没有任何归属"，分不清"真假功能"和"内部状态位"，
//     最后一步靠人看（那 4 个是 `lastIgnoredVersion` / `terracottaNoticeVer` / `lastUpgradeCheck` / `lastSponsorReportMonth`）。
//   · **只看"可用 30 项"**，85 项置灰的不在范围（它们"没生效"是设计意图，不是缺陷）。
// 那 4 项在设置页没有控件（设置页是手写行，不遍历定义），所以没有假功能。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

// ---- 定义 ----
const settingsSrc = fs.readFileSync(path.join(SRC, 'ZLSettings.swift'), 'utf8');
const defs = [...settingsSrc.matchAll(/\.init\(key:\s*"([^"]+)"/g)].map(m => m[1]);

// ---- 四个不可用集合（按括号深度取，跳过注释行 —— 注释里的引号会被误抓）----
const screenSrc = fs.readFileSync(path.join(SRC, 'SettingsScreen.swift'), 'utf8');
function collectSet(name) {
  const idx = screenSrc.indexOf('static let ' + name + ': Set<String>');
  if (idx < 0) return [];
  const open = screenSrc.indexOf('[', idx);
  if (open < 0) return [];
  let depth = 0, end = -1;
  for (let i = open; i < screenSrc.length; i++) {
    if (screenSrc[i] === '[') depth++;
    else if (screenSrc[i] === ']') { depth--; if (depth === 0) { end = i; break; } }
  }
  if (end < 0) return [];
  const out = [];
  for (const line of screenSrc.slice(open + 1, end).split(/\r?\n/)) {
    const t = line.trim();
    if (t.startsWith('//')) continue;
    for (const m of t.matchAll(/"([^"]+)"/g)) out.push(m[1]);
  }
  return out;
}

const names = ['platformOnly', 'notWired', 'renderOnly', 'launcherLook'];
const disabled = new Set(names.flatMap(collectSet));
const usable = defs.filter(k => !disabled.has(k));

// ---- 归属判断 ----
const coreBridge = fs.readFileSync(path.join(SRC, 'CoreBridge.swift'), 'utf8');
const others = files.filter(f => !['SettingsScreen.swift', 'ZLSettings.swift', 'CoreBridge.swift'].includes(f));
const otherTexts = others.map(f => ({ f, t: fs.readFileSync(path.join(SRC, f), 'utf8') }));

// 内部状态位白名单：这些在设置页没有控件，只做内部记账（不影响用户）
const INTERNAL_ONLY = new Set([
  'lastIgnoredVersion', 'terracottaNoticeVer', 'lastUpgradeCheck', 'lastSponsorReportMonth',
]);

const problems = [];
let bridged = 0, consumed = 0, internal = 0;

for (const k of usable) {
  const needle = '"' + k + '"';
  const inCB = coreBridge.includes(needle);
  const inOther = otherTexts.some(o => o.t.includes(needle));

  if (inCB) { bridged++; continue; }
  if (inOther) { consumed++; continue; }
  if (INTERNAL_ONLY.has(k)) { internal++; continue; }

  problems.push(k);
}

console.log(`设置项：定义 ${defs.length} · 置灰 ${disabled.size} · **可用 ${usable.length}**`);
console.log(`落地归属：核心桥接 ${bridged} · Swift 消费 ${consumed} · 内部状态位 ${internal}`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 每个"可用"设置项都有落地归属（核心桥接 / Swift 消费 / 内部状态位）');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 项"可用"但没有任何归属 —— 用户在设置页改了不会生效：`);
for (const k of problems) console.log(`  · ${k}`);
console.log('');
console.log('修法：要么在 CoreBridge 里把它桥接给核心，要么在别的 Swift 文件里消费它；');
console.log('      如果它只是内部记账没有 UI，加进本脚本的 INTERNAL_ONLY 白名单（并写明理由）。');
process.exit(1);
