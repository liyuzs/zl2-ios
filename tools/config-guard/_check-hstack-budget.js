// _check-hstack-budget.js v3：放弃"跨属性解析"，改用两条可预测的判据
//
// v2 试图解析 computed property 里的宽度，实测有两个坑：
//   · `.frame(maxWidth: .infinity)` 让正则把 `.` 当数字
//   · HStack 块的括号配对一旦被注释/闭包干扰，就会把后面的代码也吃进来
// 结果是一个"看起来很聪明但结果不可信"的检查 —— 这比没有检查更糟。
//
// v3 回到可预测的两条：
//   ① 同一 HStack 的**内联**多个固定宽度之和 ≥ 预算 85%（沿用 v1）
//   ② **窄栏+面板组合**（启发式）：同一个文件里同时存在
//        `.frame(width: 92)`（左侧导航栏）与 `.frame(maxWidth: 100~220)`（侧面板）
//      按 92 + N + 30（间距与内边距的保守估计）算，> 315pt 就报。
//      这条覆盖资源页那种"宽度写在两个 computed property 里"的写法。
//      范围取 100–220 的理由：低于 100 的多半是装饰条；高于 220 的多半是
//      面板**内部**控件（资源页筛选面板里那张搜索框写的是 260，被父级夹着），
//      抓进来就是误报（第107轮实测过一次）。
//      要注意它仍是**估计**：间距与内边距按 30 打包算，不精确还原。
//      真机观感仍要人眼看 —— 真机验证清单与 STATUS 第 5 条都记着这件事。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const SCREEN = 375;
const PADDING = 18;
const BUDGET = SCREEN - PADDING * 2;   // 339
const INLINE_WARN = Math.floor(BUDGET * 0.85);   // 288
const RAIL_PAIR_LIMIT = 315;           // 92 + N + 30 的上限
const IGNORE_ABOVE = 400;

function blockAfter(src, openBraceIdx) {
  let depth = 0;
  for (let i = openBraceIdx; i < src.length; i++) {
    if (src[i] === '{') depth++;
    else if (src[i] === '}') { depth--; if (depth === 0) return src.slice(openBraceIdx, i + 1); }
  }
  return src.slice(openBraceIdx);
}

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const problems = [];
let rows = 0;

for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');

  // ---- 判据 ②：窄栏 + 面板组合（启发式）----
  const hasRail = /\.frame\(\s*width:\s*92\s*[,)]/.test(src);
  if (hasRail) {
    for (const pm of src.matchAll(/\.frame\(\s*maxWidth:\s*([0-9]+)\s*[,)]/g)) {
      const v = parseInt(pm[1], 10);
      // 只看 100–220pt —— 这是"侧面板"真正会跟左栏抢空间的区间。
      // 超过 220 的多半是面板**内部**的控件（如资源页筛选面板里那张搜索框写的是 260），
      // 它被父级 maxWidth 夹着，不参与这一行的空间竞争。
      if (v < 100 || v > 220) continue;
      const total = 92 + v + 30;
      if (total > RAIL_PAIR_LIMIT) {
        const lineNo = src.slice(0, pm.index).split('\n').length;
        problems.push({
          file: f, line: lineNo, total, left: BUDGET - total,
          detail: `左栏 92 + 侧面板 maxWidth ${v} + 间距/内边距≈30（启发式）`,
        });
      }
    }
  }

  // ---- 判据 ①：同一 HStack 内联的多个固定宽度 ----
  const re = /HStack\s*(?:\([^)]*\))?\s*\{/g;
  let m;
  while ((m = re.exec(src)) !== null) {
    const block = blockAfter(src, m.index + m[0].length - 1);
    const widths = [];
    let d = 0;
    for (let k = 0; k < block.length; k++) {
      const ch = block[k];
      if (ch === '{') { d++; continue; }
      if (ch === '}') { d--; continue; }
      if (d !== 1 || ch !== '.') continue;
      // 数字必须真的以数字开头（避免把 .infinity 里的点当数字）
      const wm = block.slice(k, k + 60).match(/^\.frame\(\s*(?:width:\s*|maxWidth:\s*)([0-9]+(?:\.[0-9]+)?)/);
      if (!wm) continue;
      const v = parseFloat(wm[1]);
      if (v > 0 && v < IGNORE_ABOVE) widths.push(v);
    }
    if (widths.length < 2) continue;
    rows++;
    const sum = widths.reduce((a, b) => a + b, 0);
    if (sum >= INLINE_WARN) {
      const lineNo = src.slice(0, m.index).split('\n').length;
      problems.push({ file: f, line: lineNo, total: sum, left: BUDGET - sum, detail: widths.join(' + ') });
    }
  }
}

console.log(`预算：${SCREEN}pt − ${PADDING}×2 = ${BUDGET}pt`);
console.log(`判据① 同一 HStack 内联固定宽度之和 ≥${INLINE_WARN}pt；判据② 窄栏 92 + 侧面板 + 30 > ${RAIL_PAIR_LIMIT}pt`);
console.log(`检查了 ${rows} 行内联多宽度 HStack`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 没有"固定宽度之和把中间挤死"的行');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处空间不足：`);
for (const p of problems) {
  console.log(`  ${p.file}:${p.line}  合计约 ${p.total}pt，只剩 ${p.left}pt`);
  console.log(`      ${p.detail}`);
}
console.log('');
console.log('修法：把侧面板 maxWidth 收小，或把它收进 sheet / 折叠。');
process.exit(1);
