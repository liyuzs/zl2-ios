// 用户可见字符串里不许出现硬编码的版本号（第142轮）
//
// 两个真实事故（都可作为验收用例）：
// · 第141轮：`HomeScreen` 里 `Text("1.20.1 · Fabric 0.19.2")` —— 装什么版本都显示这一行
// · 第142轮：`ZL2App` 关于页 `Text("com.pi.phux.mobileglues · 1.3.4")` —— 声称一个不存在组件
//
// 判据：
//   `Text("...")` / `Label(...)` / `LabeledContent(..., value: "...")` 等**用户可见**字符串里，
//   出现版本号格式（`1.20.1` / `3.4.5`）且**不含中文** → 报。
//   含中文的多半是说明文字（"需要 1.20.1 以上"），只提示不报错。
//
// **局限**：
// · 只认上面那几种构造方式。用变量拼出来的、或者塞进 `ZLStrings` 常量的看不见。
// · 判"含不含中文"是启发式：像 `"Fabric 0.19.2"` 这种全英文但确实该显示的（品牌 + 版本）
//   会被误报 —— 那种情况加进 ALLOW 并写理由。
// · 不判"这个版本号是不是该从别处读" —— 那需要语义。它只保证"字面量不会悄悄变成假数据"。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

// 明确允许的：品牌/许可证名里的版本号是固定的，不是数据
const ALLOW = [
  { match: 'GPL-3.0', why: '许可证名称' },
  { match: 'Apache-2.0', why: '许可证名称' },
  { match: 'LGPL-2.1', why: '许可证名称' },
  { match: 'BSD-3-Clause', why: '许可证名称' },
  { match: 'MIT', why: '许可证名称（无版本号）' },
  { match: 'FTL', why: '许可证名称（无版本号）' },
];

const VERSION_RE = /\b\d+\.\d+(?:\.\d+)?\b/;
const VISIBLE = /(?:Text|Label|LabeledContent|navigationTitle|section|alert|confirmationDialog|Button)\s*\(\s*"([^"]{2,})"/;

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

const bad = [];       // 无中文 + 含版本号 → 报
const notes = [];     // 有中文 + 含版本号 → 只提示

for (const f of files) {
  const lines = fs.readFileSync(path.join(SRC, f), 'utf8').split(/\r?\n/);
  lines.forEach((line, i) => {
    const t = line.trim();
    if (t.startsWith('//')) return;
    const m = t.match(VISIBLE);
    if (!m) return;
    const str = m[1];
    if (!VERSION_RE.test(str)) return;
    if (ALLOW.some(a => str.includes(a.match))) return;

    const hasCN = /[\u4e00-\u9fa5]/.test(str);
    if (hasCN) notes.push({ file: f, line: i + 1, str });
    else bad.push({ file: f, line: i + 1, str, code: t.slice(0, 80) });
  });
}

console.log(`扫了 ${files.length} 个文件：用户可见字符串里含版本号 ${bad.length + notes.length} 处`);
console.log(`  其中无中文（硬编码数据，${bad.length} 处）· 有中文（说明文字，${notes.length} 处）`);
console.log('');

if (bad.length === 0) {
  console.log('✓ 没有硬编码的版本号（用户可见字符串里的版本都来自真实数据）');
  if (notes.length > 0) {
    console.log('');
    console.log('以下含中文、多半是说明文字，供参考（不算失败）：');
    for (const n of notes.slice(0, 8)) console.log(`  ${n.file}:${n.line}  "${n.str}"`);
    if (notes.length > 8) console.log(`  …还有 ${notes.length - 8} 处`);
  }
  process.exit(0);
}

console.log(`⚠ ${bad.length} 处"看起来是数据、但写死了"的版本号：`);
for (const b of bad) {
  console.log(`  ${b.file}:${b.line}  "${b.str}"`);
  console.log(`      ${b.code}`);
}
console.log('');
console.log('修法：从真实数据读（如 `VersionRepository.displayMeta(for:)`），读不到就不显示；');
console.log('      确实是固定值（品牌名/许可证）的，加进本脚本的 ALLOW 并写明理由。');
process.exit(1);
