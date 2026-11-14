// 可用设置项是否都有 UI 入口（第148轮）
//
// 与 `_check-settings-wiring.js`（第135轮）的分工：
//   · wiring 查**代码层**：有没有人消费这个值（核心桥接 / Swift 消费）
//   · 本条查**UI 层**：用户能不能改到它（控件 / 自动写入 / 手势 / 内部记账）
// 两个角度都重要 —— 有消费但没入口 = 用户改不到；有入口但没消费 = 假功能。
//
// 第148轮实测：可用 30 项 = 21 UI 控件 + 4 自动写入 + 1 手势 + 4 内部记账，**0 项改不到**。
//
// **局限**：
// · 只认 `toggle/slider/picker/number/switchRow/listRow/writeSetting*/ZLSettings.def` 这些形态。
// · 三个"不需控件"的名单（`AUTO_WRITTEN` / `BY_GESTURE` / `INTERNAL`）是**人工维护**的：
//   新增一个"自动写入"的设置项而没登记，会被误报成"找不到入口"（这是保守方向，可接受）。
// · 判不了"控件是否真的可用"（比如它可能在置灰分支里）—— 那由 `ZLUnsupportedSettings` 的四个集合管。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const settingsSrc = fs.readFileSync(path.join(SRC, 'ZLSettings.swift'), 'utf8');
const defs = [...settingsSrc.matchAll(/\.init\(key:\s*"([^"]+)"/g)].map(m => m[1]);

// 四个"不可用"集合（跳过注释行 —— 注释里的引号会被误抓）
const screenSrc = fs.readFileSync(path.join(SRC, 'SettingsScreen.swift'), 'utf8');
function collectSet(name) {
  const idx = screenSrc.indexOf('static let ' + name + ': Set<String>');
  if (idx < 0) return [];
  const open = screenSrc.indexOf('[', idx);
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
const disabled = new Set(['platformOnly', 'notWired', 'renderOnly', 'launcherLook'].flatMap(collectSet));
const usable = defs.filter(k => !disabled.has(k));

// UI 入口候选文件
const UI_FILES = ['SettingsScreen.swift', 'GameMenuScreen.swift', 'ControlEditor.swift'];
const uiText = UI_FILES.map(f => fs.readFileSync(path.join(SRC, f), 'utf8')).join('\n');

function hasControl(key) {
  const k = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const patterns = [
    new RegExp('(?:toggle|slider|picker|text|stepper|segmented|info|chip|menu|number|decimalSliderRow|textField)\\s*\\(\\s*"' + k + '"'),
    new RegExp('(?:switchRow|sliderRow|decimalSliderRow|listRow\\s*\\([^)]*key:)\\s*[^)]*"' + k + '"'),
    new RegExp('writeSetting\\w+\\(\\s*"' + k + '"'),
    new RegExp('ZLSettings\\.def\\(\\s*"' + k + '"'),
  ];
  return patterns.some(re => re.test(uiText));
}

// 三类"不需要控件"的（人工维护，新增时登记）
const AUTO_WRITTEN = new Set([
  'controlLayout',      // ControlEditor.saveLayout / CoreBridge.syncControlLayoutIfNeeded
  'currentAccount',     // AccountStore.persist
  'currentGamePathId',  // GameDirectoryStore.activate
  'finishedGame',       // CoreBridge.recordGameLaunch
]);
const BY_GESTURE = new Set(['menuBallPos']);   // 拖动悬浮球
const INTERNAL = new Set([
  'lastIgnoredVersion', 'terracottaNoticeVer', 'lastUpgradeCheck', 'lastSponsorReportMonth',
]);

const cat = { ui: [], auto: [], gesture: [], internal: [], none: [] };
for (const k of usable) {
  if (hasControl(k)) cat.ui.push(k);
  else if (AUTO_WRITTEN.has(k)) cat.auto.push(k);
  else if (BY_GESTURE.has(k)) cat.gesture.push(k);
  else if (INTERNAL.has(k)) cat.internal.push(k);
  else cat.none.push(k);
}

console.log(`可用设置项 ${usable.length} 个 = UI 控件 ${cat.ui.length} + 自动写入 ${cat.auto.length} + 手势 ${cat.gesture.length} + 内部记账 ${cat.internal.length} + **没入口 ${cat.none.length}**`);
console.log('');

if (cat.none.length === 0) {
  console.log('✓ 每个"可用"设置项用户都能改到（控件 / 自动写入 / 手势 / 内部记账）');
  process.exit(0);
}

console.log(`⚠ ${cat.none.length} 项用户改不到：`);
for (const k of cat.none) console.log(`  · ${k}`);
console.log('');
console.log('修法：① 在设置页/游戏内菜单加控件；② 如果它由别处自动写入，加进 AUTO_WRITTEN 并注明来源；');
console.log('      ③ 如果它只是内部记账没有 UI，加进 INTERNAL 并写明理由。');
process.exit(1);
