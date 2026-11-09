// 设置项审计文档 ↔ 代码集合 的契约
//
// 起因：ios-zl2 第79轮查「115 个设置项是否真被消费」时发现，`docs/设置项审计.md`
// 的数字**严重过时**：
//   · 文档说「真正生效 13 项」→ 实际 54 项（低估 4 倍）
//   · 文档说「待接线 14 项」   → 实际 4 项
//   · 文档说「安卓专属 60 项」 → 实际 57 项
// 原因是接线一直在推进，但没人回头改这张表。`docs/设置项接线进度.md`
// 里还写着「现在 36 项」，同样偏低。
//
// 权威来源永远是代码：`src/SettingsScreen.swift` 的 `ZLUnsupportedSettings`
// 里 `platformOnly` / `notWired` 两个集合。这份检查把文档里的数字和代码对撞。

const PATHS = require('./_paths');
const fs = require('fs');
const path = require('path');

const ROOT = PATHS.REPO;
const SETTINGS_SWIFT = path.join(ROOT, 'src', 'ZLSettings.swift');
const SCREEN_SWIFT = path.join(ROOT, 'src', 'SettingsScreen.swift');
const AUDIT_DOC = path.join(ROOT, 'docs', '设置项审计.md');
const PROGRESS_DOC = path.join(ROOT, 'docs', '设置项接线进度.md');

const read = p => fs.readFileSync(p, 'utf8');

// ---- 代码侧 ----
const settingsSrc = read(SETTINGS_SWIFT);
const keys = [...settingsSrc.matchAll(/\.init\(key:\s*"([^"]+)"/g)].map(m => m[1]);
const screenSrc = read(SCREEN_SWIFT);

function extractSet(name) {
  const start = screenSrc.indexOf('static let ' + name);
  if (start < 0) return [];
  const end = screenSrc.indexOf(']', start);
  const block = screenSrc.slice(start, end);
  return [...block.matchAll(/"([a-zA-Z]+)"/g)].map(m => m[1]);
}

// **读全部四个集合**（第79/87轮只读两个，把可用算成 54/42，真实是 30）
const SETS = ['platformOnly', 'notWired', 'renderOnly', 'launcherLook'];
const bySet = {};
for (const s of SETS) bySet[s] = extractSet(s);

const platform = bySet.platformOnly;
const notWired = bySet.notWired;
const covered = new Set([...platform, ...notWired, ...bySet.renderOnly, ...bySet.launcherLook]);
const working = keys.filter(k => !covered.has(k));

// 守卫：源文件里凡是 `static let xxx: Set<String>` 都必须被本脚本读到，
// 否则新增一个集合就会静默漏算（这正是上一轮的错误来源）。
// 派生集合（`= a.union(b)...`）不算分类，跳过
const declRe = /static let (\w+)[ \t]*:[ \t]*Set<String>[ \t]*=[ \t]*([^\n]*)/g;
const declaredSets = [];
for (const m of screenSrc.matchAll(declRe)) {
  let expr = m[2].trim();
  // 赋值号后面换行了（派生集合的常见写法）：看接下来几行
  if (expr === '') {
    const after = screenSrc.slice(m.index).split('\n').slice(1, 4).join('');
    if (after.includes('.union(')) continue;      // 派生集合，跳过
  } else if (expr.includes('.union(')) {
    continue;                                     // 派生集合，跳过
  }
  declaredSets.push(m[1]);
}
const missed = declaredSets.filter(s => !SETS.includes(s));
if (missed.length) {
  console.log(`✗ SettingsScreen.swift 里还有这些集合没被本脚本覆盖：${missed.join(', ')}`);
  console.log('  → 把它们加进顶部的 SETS（否则"可用"数量会算错）');
  process.exit(1);
}

const expected = {
  working: working.length,
  platform: platform.length,
  notWired: notWired.length,
  total: keys.length,
};

// ---- 文档侧 ----
let auditDoc = '';
try { auditDoc = read(AUDIT_DOC); } catch {
  console.log('✗ 找不到 docs/设置项审计.md');
  process.exit(1);
}

// 从总览表里抠数字：| ✅ **可改且生效** | 54 | 47% | ... |
function tableNumber(text, labelPattern) {
  const re = new RegExp('\\|\\s*' + labelPattern + '[^|]*\\|\\s*(\\d+)\\s*\\|');
  const m = text.match(re);
  return m ? parseInt(m[1], 10) : null;
}

const docWorking = tableNumber(auditDoc, '✅');
const docPlatform = tableNumber(auditDoc, '⛔');
const docNotWired = tableNumber(auditDoc, '🔧');

const problems = [];
function cmp(name, docVal, codeVal) {
  if (docVal === null) { problems.push(`${name}：文档总览表里没找到这一行`); return; }
  if (docVal !== codeVal) problems.push(`${name}：文档写 ${docVal}，代码是 ${codeVal}`);
}

cmp('可用项', docWorking, expected.working);
cmp('安卓专属', docPlatform, expected.platform);
cmp('待接线', docNotWired, expected.notWired);

// 进度文档里那句「真正生效 13 项 → 现在 N 项」
let progressNote = '';
try {
  const progressDoc = read(PROGRESS_DOC);
  const m = progressDoc.match(/现在\s*\**(\d+)\**\s*项/);
  if (m && parseInt(m[1], 10) !== expected.working) {
    progressNote = `docs/设置项接线进度.md 说「现在 ${m[1]} 项」，代码是 ${expected.working}`;
  }
} catch {}

console.log(`代码：共 ${expected.total} 项 → 可用 ${expected.working} / 安卓专属 ${expected.platform} / 待接线 ${expected.notWired}`);
console.log('');

if (problems.length === 0 && !progressNote) {
  console.log('✓ 审计文档的数字与代码集合一致');
  process.exit(0);
}

for (const p of problems) console.log(`  ⚠ ${p}`);
if (progressNote) console.log(`  ⚠ ${progressNote}`);
console.log('');
console.log('修法：改文档（代码是权威）；或者如果你改了代码的集合，也把文档一起改。');
process.exit(1);
