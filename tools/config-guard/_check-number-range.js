// 用 number(...) 自由输入的设置项必须有 range（第151轮）
//
// 背景：`ZLSettings` 的 `range` 字段原来只被 slider 的 min/max 用过，
// 写入路径 `store.set(_:_: Int)` **完全不 clamp**。第151轮修了两处：
//   ① `set(Int)` 统一 clamp 到 `def.range`
//   ② 分辨率两项补 `range: 0...7680`（原来 nil，能存 0 / 负数 / 99999999）
//
// 但 clamp 只在 `range` 非 nil 时生效 —— 如果将来新增一个 `number(...)` 项却忘设 range，
// 就又会开一个自由输入的口子。这条检查守住它。
//
// **局限**：
// · 只查 `number(...)`（自由输入框）。`slider(...)` 的 min/max 本身来自 range，不受影响。
// · 判不了 range 的上下限"合不合理"（比如设成 0...999999 也算有 range）—— 那要人看。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const settingsSrc = fs.readFileSync(path.join(SRC, 'ZLSettings.swift'), 'utf8');
const screenSrc = fs.readFileSync(path.join(SRC, 'SettingsScreen.swift'), 'utf8');

// 定义表：key → 有没有 range
const defs = new Map();
for (const m of settingsSrc.matchAll(/\.init\(key:\s*"([^"]+)"[^)]*?type:\s*\.(\w+)[^)]*?range:\s*(nil|\d)/g)) {
  defs.set(m[1], { type: m[2], hasRange: m[3] !== 'nil' });
}

// 用 number(...) 的 key
const numberKeys = [];
for (const m of screenSrc.matchAll(/\bnumber\(\s*"([^"]+)"/g)) numberKeys.push(m[1]);

console.log(`用 number(...) 自由输入的设置项：${numberKeys.length} 个`);

const problems = [];
const ok = [];
for (const k of numberKeys) {
  const d = defs.get(k);
  if (!d) { problems.push(`${k}：ZLSettings 里找不到这个 key`); continue; }
  if (d.type !== 'int' && d.type !== 'float') {
    problems.push(`${k}：number(...) 是数字输入，但定义的类型是 .${d.type}`);
    continue;
  }
  if (!d.hasRange) {
    problems.push(`${k}：**没有 range** —— 用户能输入任意整数（0 / 负数 / 超大值），clamp 不会生效`);
    continue;
  }
  ok.push(k);
}

console.log(`  有 range：${ok.length} —— ${ok.join('、')}`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 每个自由输入的数字设置项都有 range（写入时会被 clamp）');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 个问题：`);
for (const p of problems) console.log(`  · ${p}`);
console.log('');
console.log('修法：在 ZLSettings 给这一项补 `range: 下限...上限`。');
console.log('      注意 0 是否合法 —— 比如分辨率 0 表示「跟随规则」，那下限就该是 0。');
process.exit(1);
