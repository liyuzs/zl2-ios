// 主题配色的**文字可读性**：前景/背景配对的对比度必须够（WCAG 公式，纯算术）。
//
// 为什么要它：`_check-dark-mode` 只查**结构**（色板会不会切 Dark、键配不配对），
// 完全不管"深色下这行字看不看得清"。而 490 个色值都在 `ColorThemes.swift` 里，
// 对比度是**可以算出来的** —— 把视觉问题降维成算术问题，就不必等真机。
//
// 判据：12 组 Material 标准配对的对比度都 ≥ 4.5:1（WCAG AA 正文）。
//
// **局限**（不查什么）：
//   · **只算这 12 组配色**（primary/secondary/tertiary/error/background/surface/surfaceVariant/
//     四个 container/inverseSurface）。`outline*` 只要求 3:1，`scrim` 是遮罩，都不在范围。
//   · **不算透明度/叠层**：`.opacity(0.6)` 的次级文字、玻璃拟态的半透明卡片，实际对比度比这里低。
//   · **不算状态色**：hover/pressed/disabled 的派生颜色不在 `raw` 里。
//   · **只认 `"键": [7 个 0x 值]` 这一种写法**：色板换格式（比如改成分开定义）这里就扫不到 —— 靠下面的分母守卫兜。
//   · **不判"好不好看"**：对比度够 ≠ 配色好看，审美只能人看。
//   · **本可以算但没算的两项**（第 578 轮逐个探查后放弃，别重试）：
//     ① **触控目标 ≥44pt**：静态数出 **103 处**"写死尺寸 <44 且附近可点"，绝大多数是装饰线（`frame(height: 2)`）、
//        胶囊标签（`frame(height: 32)` 但由 `.padding(.horizontal, 12)` 撑开）、`Color.clear` 间距、隐藏元素（`1×1`）。
//        **图标尺寸 ≠ 点击区域** —— 静态分不开真问题，假阳性会把这个检查变成噪音（第 107 轮那条）。
//     ② **最小字号**：7pt 只有 2 处，都是面包屑里的 `chevron.right` 分隔箭头；8pt 的是任务中心图标上的角标数字（白字红底 Capsule）。
//        都是合理用法，**没有真问题** —— 分母 2–3，不值得单开一条。
const fs = require('fs');
const path = require('path');
const PATHS = require('./_paths');

const file = path.join(PATHS.SRC, 'ColorThemes.swift');
if (!fs.existsSync(file)) { console.log('✗ 读不到 ' + file + ' —— 这不是"没问题"，是"没看到东西"'); process.exit(1); }
const src = fs.readFileSync(file, 'utf8');

const pal = {};
for (const m of src.matchAll(/"([A-Za-z]+)":\s*\[([^\]]+)\]/g)) {
  const vals = m[2].split(',').map(x => x.trim()).filter(Boolean).map(x => parseInt(x.replace(/^0x/i, ''), 16));
  if (vals.length === 7) pal[m[1]] = vals;
}
const keyCount = Object.keys(pal).length;
if (keyCount < 60) {
  console.log(`✗ 只解析到 ${keyCount} 个色板键（应为 70）—— 判据可能失效了，先核对 ColorThemes.swift 的写法`);
  process.exit(1);
}

const srgb = c => { c /= 255; return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); };
const lum = h => 0.2126 * srgb((h >> 16) & 255) + 0.7152 * srgb((h >> 8) & 255) + 0.0722 * srgb(h & 255);
const contrast = (a, b) => { const l1 = lum(a), l2 = lum(b); const hi = Math.max(l1, l2), lo = Math.min(l1, l2); return (hi + 0.05) / (lo + 0.05); };

const PAIRS = [
  ['primary', 'onPrimary'], ['secondary', 'onSecondary'], ['tertiary', 'onTertiary'], ['error', 'onError'],
  ['background', 'onBackground'], ['surface', 'onSurface'], ['surfaceVariant', 'onSurfaceVariant'],
  ['primaryContainer', 'onPrimaryContainer'], ['secondaryContainer', 'onSecondaryContainer'],
  ['tertiaryContainer', 'onTertiaryContainer'], ['errorContainer', 'onErrorContainer'],
  ['inverseSurface', 'inverseOnSurface'],
];
const THEMES = ['釉烬', '绒玫', '雾澜', '冰川', '原野暮光', '钛影', '静林之晨'];
const MIN_RATIO = 4.5;

const all = [];
const missing = [];
for (const mode of ['Light', 'Dark']) {
  for (const [fg, bg] of PAIRS) {
    const fk = fg + mode, bk = bg + mode;
    if (!pal[fk] || !pal[bk]) { missing.push(!pal[fk] ? fk : bk); continue; }
    for (let i = 0; i < 7; i++) all.push({ mode, pair: `${fg} on ${bg}`, theme: THEMES[i], ratio: contrast(pal[fk][i], pal[bk][i]) });
  }
}

console.log(`扫了 ${keyCount} 个色板键 · 算了 ${all.length} 对（${PAIRS.length} 组配对 × 浅/深 × 7 主题）`);
if (all.length < 100) { console.log(`✗ 只算出 ${all.length} 对（应为 168）—— 判据可能失效`); process.exit(1); }
if (missing.length) console.log(`· 缺键（这些配对没算）：${[...new Set(missing)].join(', ')}`);

const bad = all.filter(r => r.ratio < MIN_RATIO).sort((a, b) => a.ratio - b.ratio);
const lowest = [...all].sort((a, b) => a.ratio - b.ratio).slice(0, 3);

if (bad.length === 0) {
  console.log(`✓ 全部 ${all.length} 对都 ≥ ${MIN_RATIO}:1（最低 ${lowest.map(r => r.ratio.toFixed(2)).join('/')} —— ${lowest[0].theme} · ${lowest[0].mode} · ${lowest[0].pair}）`);
  process.exit(0);
}
console.log(`\n⚠ ${bad.length} 对低于 ${MIN_RATIO}:1（文字会看不清）：`);
for (const r of bad) console.log(`  ${r.ratio.toFixed(2)}:1  ${r.theme} · ${r.mode} · ${r.pair}`);
console.log('\n修法：调深/调浅那一组色值，或换一组 Material 的 tonal palette。');
process.exit(1);
