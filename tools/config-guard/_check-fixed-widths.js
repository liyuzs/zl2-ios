// 固定宽度溢出检查
//
// 起因：ios-zl2 第68轮盘 `.frame(width: N)` 时发现首页右侧面板写死 `width: 340`。
// 而 iPhone 竖屏可用宽度：320pt（SE）− 18×2（screenPadding）= **284pt**。
// 340 > 284 → 必然溢出，而且面板是右对齐（`HStack { Spacer(); panel }`），
// 溢出时被裁掉的是**左侧**，也就是标签文字。
//
// 判据刻意只查「**必然溢出**」的情况，避免误报：
//   · 阈值为 280pt：320 − 36 = 284 是最窄的常见手机可用宽度
//   · 只查 `.frame(width: N)` 里 N ≥ 280 的
//   · 排除以 `, height:` 同时指定的小组件？不排除 —— 但 N≥280 的基本都是整块面板
//
// **局限**（不查什么）：
//   · **只查字面量**。`width: someConstant` / `width: geo.size.width * 0.8` 这类**用变量的查不到** ——
//     而那种写法恰恰更可能溢出（值由运行时决定）。
//   · **`maxWidth` 完全不管** —— 它是自适应的，不会"必然溢出"，但可能"在小屏上挤"（那是 `_check-hstack-budget.js` 管）。
//   · **算不出真实可用宽度**：外层还有 `.padding` / 容器间距时，实际可用空间比 280 更小，
//     而本检查按固定阈值判，所以**"270pt 但外层还减了 40pt"这种漏判**。
//   · **iPad 上不溢出也被按 iPhone 阈值判**（但这项目 iPad 是横屏，宽度富裕，所以只可能误报不会漏报）。
//
// 更细的"挤压"（比如固定 210 的侧栏挤压自适应列表）机器判不出来，
// 那种要靠人工看，本检查不管。

const fs = require('fs');
const path = require('path');
const { SRC } = require('./_paths');
const THRESHOLD = 280;

// 这些文件是「不可达页面」或纯装饰，已知不修
//
// **第207轮**：原来这里有一条 `'TerracottaScreen.swift'`（注释是"整个页面不可达"）——
// 但那个文件**第132轮就删了**（359 行假页面）。白名单指向一个不存在的文件，
// 虽然不影响判据运行（它永远不会匹配），但会误导下一个人。
// 已删。这类问题现在由 `_check-stale-allows.js` 守。
const ALLOW = [
];

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const problems = [];
let checked = 0;

for (const name of files) {
  if (ALLOW.includes(name)) continue;
  const text = fs.readFileSync(path.join(SRC, name), 'utf8');
  const lines = text.split('\n');
  lines.forEach((line, i) => {
    const m = line.match(/\.frame\(\s*width:\s*(\d+)/);
    if (!m) return;
    const w = parseInt(m[1], 10);
    checked++;
    if (w >= THRESHOLD) {
      problems.push({ file: name, line: i + 1, width: w, text: line.trim() });
    }
  });
}

console.log(`检查了 ${checked} 处固定宽度，阈值 ${THRESHOLD}pt（320pt 屏减去两侧 18pt 内边距 = 284）`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 没有必然溢出的固定宽度（≥280pt）');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处固定宽度会超出最窄常见手机屏：`);
for (const p of problems) {
  console.log(`\n  ${p.file}:${p.line}  width: ${p.width}`);
  console.log(`    ${p.text}`);
}
console.log('');
console.log('修法：`.frame(width: N)` → `.frame(maxWidth: N)`（宽屏保持原宽度，窄屏自动收缩）。');
process.exit(1);
