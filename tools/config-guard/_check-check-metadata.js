// 检查元数据：每个 `_check-*.js` 都要写明**自己什么时候会失效**
//
// 起因（第135轮的教训）：`_audit-stores.js` 因为代码从"字面量键"改成"动态键 `def.key`"
// 而悄悄失明 —— 它不报错、不改输出、一直显示通过，110 多轮没人发现它其实看不见了。
//
// 防这类事的第一道：**让每条检查自己说清"我查不到什么"**。
// 写在文件头部的注释里，关键词：局限 / 查不到 / 不覆盖 / 只认 / 失效。
//
// 存量用**基线冻结**（`BASELINE`）：只许降不许升。
// 新增一条检查却不写局限 → 数量增加 → 报。
// 把某条检查的局限补上 → 数量减少 → 提示可以把 BASELINE 调小。
const fs = require('fs');
const path = require('path');

const { GUARD } = require('./_paths');

// 当前基线（第136轮：39 条检查里 26 条还没写局限）
// **第213轮：29 → 26**（给 _check-orphan-views / _check-interpolation / _check-fixed-widths 各补了局限段）
// 改小之前确认过：是**真的补了**，不是判据变宽 —— 那三条现在能被 **局限** 命中。
// **第214轮：26 → 25**（给 `_check-hardcoded-stats` 补了局限，含"多行字符串查不到"这个真实缺口）
// **第215轮：25 → 22**（给 `_check-imports` / `_check-layout-keys` / `_check-workflow` 各补了局限）
// **第216轮：22 → 19**（_check-dark-mode / _check-delivery-index / _check-picker）
// **第217轮：19 → 16**（_check-settings-wiring / _check-trademark-strings / _check-pending-action）
// **第218轮：16 → 13**（_check-startup-io / _check-ci-contract / _check-duplicates）
// **第220轮：13 → 11**（补了三个，但其中一个原本就算'写了' —— 基线按实跑结果定，不按减法算）
// **第221轮：11 → 8**（_check-hstack-budget / _check-delivery-docs / _check-script-inventory）
// **第222轮：8 → 5**（_check-install-docs / _check-settings-audit / _check-runtime-assets）
const BASELINE = 5;

// 必须写成**标题形式**，裸词不算：
//   · 裸的「局限」二字会被测试探针的注释（"故意没写局限"）误命中 —— 第108轮同款坑。
//   · 所以只认：`**局限**` / `局限：` / `查不到什么` / `不覆盖` / `失效条件` / `只认哪些`
const KEYWORDS = /\*\*局限\*\*|局限：|查不到什么|不覆盖|失效条件|只认哪些/;
const HEAD_LINES = 60;      // 局限段应该在文件头部

const files = fs.readdirSync(GUARD).filter(f => /^_check-.*\.js$/.test(f)).sort();
const missing = [];
const has = [];

for (const f of files) {
  const text = fs.readFileSync(path.join(GUARD, f), 'utf8');
  const head = text.split(/\r?\n/).slice(0, HEAD_LINES).join('\n');
  if (KEYWORDS.test(head)) has.push(f);
  else missing.push(f);
}

console.log(`检查脚本 ${files.length} 个：写了局限 ${has.length} 个，没写 ${missing.length} 个（基线 ${BASELINE}）`);
console.log('');

if (missing.length > BASELINE) {
  console.log(`⚠ 没写局限的从 ${BASELINE} 涨到 ${missing.length} —— 新加的检查没写明自己查不到什么：`);
  for (const f of missing) console.log(`  · ${f}`);
  console.log('');
  console.log('修法：在文件头注释里加一段「**局限**」，写清：');
  console.log('  · 只认哪些写法（改了写法它就会失明）');
  console.log('  · 判不了哪些情况（需要语义、需要运行时）');
  console.log('  · 什么时候该来改它');
  process.exit(1);
}

if (missing.length < BASELINE) {
  console.log(`✓ 没写局限的从 ${BASELINE} 降到 ${missing.length} —— 可以把本脚本的 BASELINE 改成 ${missing.length} 了`);
  console.log(`✓ 没有新增"没写局限"的检查`);
  process.exit(0);
}

console.log('✓ 没有新增"没写局限"的检查（基线未变）');
