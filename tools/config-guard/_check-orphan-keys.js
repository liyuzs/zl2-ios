// UserDefaults 的键必须是 ZL2 设置项或已登记的内部键（第158轮）
//
// `applyUserSettings()` 用硬编码键名读设置。如果键名拼错、或指向一个已删的设置项，
// 就会**永远读到 nil**，而代码看起来完全正常 —— 设置不生效且无任何提示。
//
// 判据：扫所有含 `UserDefaults` 的行里的 `forKey: "xxx"`：
//   · 带点号的跳过（`debug.debug_always_attached_jit` 之类是核心自己的 pref 键）
//   · 在 ZLSettings 定义里 → OK
//   · 在 INTERNAL 白名单里 → OK（每个都写明为什么）
//   · 否则 → 孤儿键
//
// **局限**：
// · 只认 `forKey:` 这一种写法。用变量拼键名（`forKey: someVar`）查不到。
// · 只扫 UserDefaults 行 —— KVC 的 `value(forKey:)` 不是 UserDefaults 键
//   （第158轮第一版就把它误报成孤儿：`host.value(forKey: "ctrlView")`）。
// · INTERNAL 白名单人工维护，新增内部键要登记（保守方向：不登记就报）。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const settingsSrc = fs.readFileSync(path.join(SRC, 'ZLSettings.swift'), 'utf8');
const defined = new Set();
for (const m of settingsSrc.matchAll(/\.init\(key:\s*"([^"]+)"/g)) defined.add(m[1]);

// 不是 ZL2 设置项、也不是"孤儿"的键（每个都要写明为什么）
const INTERNAL = new Map([
  ['zl.authlib.server', '外置登录：皮肤站地址（AccountScreen 写，ZLYggdrasil 读）'],
  ['zl.authlib.uuid', '外置登录：角色 UUID'],
  ['lastLaunchDate', '最近一次启动时间（recordGameLaunch 写，首页 / App Group 读）'],
  ['firstLaunchDate', '首次启动时间'],
  ['control_layout', '**核心读的**布局文件名；ZL2 的设置项叫 controlLayout（见 CoreLayoutExport 注释）'],
  ['defaultTouchCtrl', '**核心 pref（control.default_ctrl）的记账本**，不是 ZL2 设置项（见 ZLLayerSwitcher 注释）'],
]);

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const orphans = [];
let checked = 0;

for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');
  const lines = src.split(/\r?\n/);
  lines.forEach((line, i) => {
    if (line.trim().startsWith('//')) return;
    if (!/UserDefaults/.test(line)) return;
    for (const m of line.matchAll(/forKey:\s*"([^"]+)"/g)) {
      const k = m[1];
      if (k.includes('.')) continue;
      if (defined.has(k)) continue;
      if (INTERNAL.has(k)) continue;
      checked++;
      orphans.push({ file: f, line: i + 1, key: k });
    }
  });
}

console.log(`ZLSettings 定义 ${defined.size} 个 key · 内部键白名单 ${INTERNAL.size} 个`);
console.log(`不在两者里的 UserDefaults 键：${checked} 处`);
console.log('');

if (orphans.length === 0) {
  console.log('✓ 所有 UserDefaults 键要么是 ZL2 设置项、要么是已登记的内部键');
  process.exit(0);
}

const byKey = {};
for (const o of orphans) (byKey[o.key] ||= []).push(o.file + ':' + o.line);

console.log(`⚠ ${Object.keys(byKey).length} 个孤儿键：`);
for (const [k, where] of Object.entries(byKey)) {
  console.log(`  ${k}  ← ${where.join(' · ')}`);
}
console.log('');
console.log('可能是：①拼错的键名（读不到 → 设置永远不生效、无任何提示）②该加进 ZLSettings ③内部状态（加进白名单并写明）');
process.exit(1);
