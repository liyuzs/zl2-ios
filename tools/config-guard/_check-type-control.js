// 设置项的 type 与 UI 控件是否匹配（第152轮）
//
// 背景：`ZLSettingDef.type` 全仓 **0 次直接读取**，但 UI 控件间接决定存进去的 Swift 类型。
// 用错控件 → 存错类型 → `CoreBridge` 用 `as? Int` 读不到 → **静默失效、无任何提示**
// （第151轮修的"分辨率 asInt 读不到"就是这类）。
//
// 所以这条检查把 `type` 当**契约**用：type 声明了什么，UI 就必须用对应族的控件。
//
// **局限**：
// · COMPAT 表是人工维护的：新增专用控件（像 animateSpeed / keyCode）时要记得登记，
//   否则会误报成"不匹配"（这是保守方向，宁可多报）。
// · 只查 `helper("key")` 这种直接绑定的调用。控件若通过变量间接绑定（拼 key），查不到。
// · 判不了"控件存的值和 type 是否真的一致" —— 只按控件族的约定推断。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const settingsSrc = fs.readFileSync(path.join(SRC, 'ZLSettings.swift'), 'utf8');
const screenSrc = fs.readFileSync(path.join(SRC, 'SettingsScreen.swift'), 'utf8');

// key → type（剥掉注释行，避免注释里的示例被当定义）
const defs = new Map();
const settingsClean = settingsSrc.split(/\r?\n/).map(l => (l.trim().startsWith('//') ? '' : l)).join('\n');
for (const m of settingsClean.matchAll(/\.init\(key:\s*"([^"]+)"[^)]*?type:\s*\.(\w+)/g)) {
  defs.set(m[1], m[2]);
}

const CONTROL = /\b(toggle|slider|picker|text|number|info|hotspot|keyCode|blur|animateSpeed|decimalSlider|segmented|stepper|menu|darkMode)\s*\(\s*"([^"]+)"/g;
const controls = new Map();
for (const m of screenSrc.matchAll(CONTROL)) {
  const kind = m[1], key = m[2];
  if (!controls.has(key)) controls.set(key, []);
  controls.get(key).push(kind);
}

// 每种 type 允许哪些控件：
// · `picker` 对 string 也合法 —— 选中的是枚举**字面量**字符串（如 renderer 的 "auto" / "libgl4es_114.dylib"）
// · `animateSpeed` 是 int 专用滑杆（内部用 `def.range` 当上下限，已核实存 Int）
// · `blur` 也是 int 专用（`backgroundBlur` 是 0-40 的模糊半径，blurRow 内部 `store.set(def, Int(...))`）
// · `keyCode` 只读展示 + 重置，**不写值**（值由按键绑定流程写入 int，如 physicalKeyImeCode）
// · `info` 是纯展示，任何类型都能用（下面单独跳过）
// · `blur` 是 bool 专用（背景模糊开关）
// · `darkMode` 是 enumValue 专用（三选项 picker）
const COMPAT = {
  bool:       ['toggle'],
  int:        ['slider', 'number', 'decimalSlider', 'stepper', 'segmented', 'animateSpeed', 'blur', 'keyCode'],
  long:       ['slider', 'number', 'decimalSlider', 'stepper'],
  string:     ['text', 'picker'],
  enumValue:  ['picker', 'menu', 'segmented', 'darkMode'],
  stringList: ['text'],
  parcelable: ['hotspot', 'keyCode'],
};

const problems = [];
let checked = 0;

for (const [key, kinds] of controls) {
  const t = defs.get(key);
  if (!t) {
    problems.push(key + '：UI 有控件，但 ZLSettings 里没这个 key');
    continue;
  }
  const allowed = COMPAT[t] || [];
  for (const k of kinds) {
    if (k === 'info') { checked++; continue; }   // 纯展示，任何类型都能用
    if (allowed.includes(k)) { checked++; continue; }
    problems.push(key + '：type 是 .' + t + '，但用了 ' + k + '(...) 控件（该类型允许：' + (allowed.join(' / ') || '无') + '）');
  }
}

console.log('有 UI 控件的设置项 ' + controls.size + ' 个 · 控件-类型配对 ' + checked + ' 处');
console.log('');

if (problems.length === 0) {
  console.log('✓ 所有设置项的 type 与 UI 控件都匹配（不会存错类型）');
  process.exit(0);
}

console.log('⚠ ' + problems.length + ' 处不匹配：');
for (const p of problems) console.log('  · ' + p);
console.log('');
console.log('为什么重要：控件决定存进去的 Swift 类型。');
console.log('  比如 .int 的项用 toggle → 存 Bool → CoreBridge 的 `as? Int` 读不到 → **静默失效**。');
process.exit(1);
