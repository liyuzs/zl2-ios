// **这条检查有个已知局限，写在这里免得后人高估它**：
// 它只能看到 `HStack { ... }` **内联块里**的宽度。而本项目的布局宽度大多写在
// 独立的 computed property 里（`kindRail` / `filterPanel` / `resultList`），
// 组合发生在 HStack 的调用处，静态上追不到 —— 所以资源页那种
// 「左栏 92 + 筛选面板 210」的挤压，这条检查**抓不到**（第106轮实测确认）。
//
// 它能抓的是"同一行里直接并排写了多个固定宽度"这一类，仍有用；
// 跨属性的组合需要人看，`docs/真机验证清单` 与 STATUS 第 5 条都记着这件事。
// 横向预算：一行（HStack）里固定宽度之和会不会把中间挤死
//
// 起因：ios-zl2 第106轮。`_check-fixed-widths.js` 只看**单个** `.frame(width:)` 是否 ≥280，
// 但"偏挤"从来不是单个值造成的，是**同一行里几个固定宽度相加**造成的：
//
//   资源页那一行 = 左栏 92 + 筛选面板 maxWidth 210 + 卡片间距 + 右侧内边距
//   375pt 屏可用 375 − 18×2 = 339pt → 92 + 210 + 12 + 18 = 332，只剩 7pt 给结果列表
//
// 单个都"不超"，合起来就废了。所以这条检查算**每行的固定宽度总和**。
//
// 判据：一行里所有 `.frame(width: N)` 与 `.frame(maxWidth: N)`（N ≤ 400，排除整宽自适应）
// 之和 ≥ 预算的 85% 就报。预算按 iPhone 竖屏最窄常见宽度 375pt 减两侧内边距算。

const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const SCREEN = 375;            // iPhone SE2/12 mini 竖屏
const PADDING = 18;            // ZLTheme.screenPadding
const BUDGET = SCREEN - PADDING * 2;   // 339
const WARN_AT = Math.floor(BUDGET * 0.85);  // 288
const IGNORE_ABOVE = 400;      // 更大的多半是整宽容器，不算"抢占"

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const problems = [];
let rowsChecked = 0;

for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');

  // 把 HStack(...) { ... } 整块取出来（大括号配对）
  const re = /HStack\s*(?:\([^)]*\))?\s*\{/g;
  let m;
  while ((m = re.exec(src)) !== null) {
    const open = m.index + m[0].length - 1;   // 指向 '{'
    let depth = 0, i = open;
    for (; i < src.length; i++) {
      if (src[i] === '{') depth++;
      else if (src[i] === '}') { depth--; if (depth === 0) break; }
    }
    const block = src.slice(open, i + 1);

    // 行内固定宽度 —— **只取深度 1**（HStack 的直接子层）。
    // 第106轮第一版把所有嵌套都算进来，结果：
    //   ServerListScreen 的图标 44 与上下堆叠的骨架条 118/172 被加在一起（误报 402pt），
    //   而它们根本不在同一水平行上。
    const widths = [];
    {
      let d = 0;
      for (let k = 0; k < block.length; k++) {
        const ch = block[k];
        if (ch === '{') { d++; continue; }
        if (ch === '}') { d--; continue; }
        if (d !== 1) continue;
        if (ch !== '.') continue;
        const rest = block.slice(k, k + 60);
        const wm = rest.match(/^\.frame\(\s*(?:width:\s*|maxWidth:\s*)([0-9.]+)/);
        if (!wm) continue;
        const v = parseFloat(wm[1]);
        if (v > 0 && v < IGNORE_ABOVE) widths.push(v);
      }
    }
    if (widths.length < 2) continue;         // 单个宽度不算"挤"

    rowsChecked++;
    const sum = widths.reduce((a, b) => a + b, 0);
    if (sum >= WARN_AT) {
      const lineNo = src.slice(0, m.index).split('\n').length;
      problems.push({ file: f, line: lineNo, sum, widths, left: BUDGET - sum });
    }
  }
}

console.log(`预算：${SCREEN}pt 屏 − ${PADDING}×2 内边距 = ${BUDGET}pt（≥${WARN_AT}pt 报警）`);
console.log(`检查了 ${rowsChecked} 行含多个固定宽度的 HStack`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 没有"固定宽度之和把中间挤死"的行');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 行的固定宽度之和过大：`);
for (const p of problems) {
  const left = p.left >= 0 ? `只剩 ${p.left}pt` : `超出 ${-p.left}pt`;
  console.log(`  ${p.file}:${p.line}  合计 ${p.sum}pt（${p.widths.join('+')}），${left} 留给自适应内容`);
}
console.log('');
console.log('修法：把其中一个改成 maxWidth 并给小值，或把侧面面板收进 sheet/折叠。');
process.exit(1);
