// 安装文档一致性检查
//
// 起因：ios-zl2 有三份讲安装的文档，朋友会同时看到：
//   · README.md 的「怎么装」
//   · docs/安装教程-超详细.md
//   · docs/给朋友的安装指南.md
// 第72轮发现它们各说各的：README 推荐「NB 全能助手（中文，推荐）」，
// 而另外两份分别给 TrollStore / SideStore / Sideloadly 三条路线，**完全不提它**。
// 三套说法并存 = 用户不知道该信哪个。
//
// 判据（简单但高信号）：
//   1. 三份都必须提到 JIT（这是这个 App 能不能跑的关键）
//   2. 三份都必须提到 StikDebug（唯一被采用的 JIT 方案）
//   3. 工具名如果**只在一份文档里出现**，报告出来 ——
//      那种"孤例工具"通常是被废弃的旧方案，或者写错了名字
//
// 不判断"哪个工具更好"，只暴露不一致，具体怎么改由人决定。
//
// **局限**（不查什么）：
//   · **只查"关键词/工具名出没出现"，不查"步骤本身对不对"** —— 文档教"打开某开关"而那个开关
//     其实是置灰的，本检查看不见（那是 `_check-guide-claims` 的活）。
//   · **"孤例"只提示、不算失败** —— 所以一个新工具只在三份文档里写了一份，**不会红**。
//   · **只认这三份文档**。将来加第四份（英文版 / 给开发者的）不在范围。
//   · **判不了"三份说的路线是否等价"** —— 第173轮就是安装指南写"仅横屏"而 `project.yml` 早已改成竖屏。

const PATHS = require('./_paths');
const fs = require('fs');
const path = require('path');

const ROOT = PATHS.REPO;
const DOCS = [
  { name: 'README.md',                  path: path.join(ROOT, 'README.md') },
  { name: '安装教程-超详细.md',          path: path.join(ROOT, 'docs', '安装教程-超详细.md') },
  { name: '给朋友的安装指南.md',         path: path.join(ROOT, 'docs', '给朋友的安装指南.md') },
];

// 已知的 iOS 侧加载 / 签名 / JIT 工具。用来从文本里抽"提到了哪些工具"。
const TOOLS = [
  'TrollStore', 'SideStore', 'Sideloadly', 'AltStore', 'iLoader',
  'StikDebug', 'NB 全能助手', '爱思助手', 'AltServer', 'Jitterbug',
];

const present = [];
const missing = [];

for (const d of DOCS) {
  let text = '';
  try { text = fs.readFileSync(d.path, 'utf8'); }
  catch {
    missing.push({ doc: d.name, why: '文件不存在' });
    continue;
  }
  const found = TOOLS.filter(t => text.includes(t));
  present.push({ doc: d.name, found, text });
}

let fail = 0;

// **第210轮**：先说清查了几份文档 —— 否则"通过"的输出里看不出范围（第209轮那条）。
console.log(`=== 1. 每份文档都要提到 JIT ===（共 ${DOCS.length} 份）`);
for (const { doc, text } of present) {
  if (/JIT/.test(text)) {
    console.log(`  ✓ ${doc}`);
  } else {
    console.log(`  ✗ ${doc} 没提 JIT（不开 JIT 这个 App 基本没法玩）`);
    fail++;
  }
}

console.log('\n=== 2. 每份文档都要提到 StikDebug ===');
for (const { doc, text } of present) {
  if (/StikDebug/.test(text)) {
    console.log(`  ✓ ${doc}`);
  } else {
    console.log(`  ✗ ${doc} 没提 StikDebug（唯一的 JIT 方案）`);
    fail++;
  }
}

console.log('\n=== 3. 只在一份文档里出现的工具（孤例，可能是过时方案）===');
const counts = new Map();
for (const p of present) {
  for (const t of p.found) {
    if (!counts.has(t)) counts.set(t, []);
    counts.get(t).push(p.doc);
  }
}
const lonely = [...counts.entries()].filter(([, docs]) => docs.length === 1);
if (lonely.length === 0) {
  console.log('  ✓ 没有孤例工具，三份文档提到的工具集合一致');
} else {
  for (const [tool, docs] of lonely) {
    console.log(`  ⚠ ${tool} —— 只出现在「${docs[0]}」`);
    console.log(`      另外两份都没提，用户会不知道要不要用它`);
  }
  // 孤例只作提示，不算失败：可能是有意在不同人群里区分
}

console.log('\n=== 汇总 ===');
for (const p of present) {
  console.log(`  ${p.doc}: ${p.found.join(' / ') || '（没提到任何已知工具）'}`);
}

console.log('');
if (missing.length) {
  for (const m of missing) console.log(`  ✗ ${m.doc}: ${m.why}`);
  fail += missing.length;
}

if (fail === 0) {
  console.log('✓ 安装文档在 JIT 与 StikDebug 上一致');
  process.exit(0);
}
console.log(`⚠ ${fail} 项必须修（JIT / StikDebug 缺失）`);
process.exit(1);
