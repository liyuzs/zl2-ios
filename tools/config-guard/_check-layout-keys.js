// 布局导出键 ↔ 核心读取 的契约
//
// 起因：ios-zl2 第74轮核对「键位编辑器对齐 ZL2 JSON 格式」时，把
// `CoreLayoutExport` 导出的每个键去核心源码里对撞，发现 4 个键**核心完全不认**：
//
//   textSize        文字大小 —— 核心实际用 adjustsFontSizeToFitWidth 自动缩放，不可配
//   joystickColor   摇杆颜色 —— 核心用固定样式
//   joystickSize    摇杆大小 —— 同上
//   pressedBgColor  "按下态"背景 —— 核心根本没有"按下态外观"这个概念
//
// 而编辑器里这四项都有滑杆、还能在预览里看到变化 —— 用户调完进游戏发现没变，
// 只会以为自己没弄对。已在编辑器里加说明；这里加检查，防止再新增"导出了但没人读"的键。
//
// 判据：`d["键"] = ...` 里的每个键，都要在 core/**/*.m|h 里出现过。
// 例外必须登记理由（下面 ALLOW），不默默放过。
//
// **局限**（不查什么）：
//   · **只查一个方向**：导出的键核心认不认。**核心读了但导出没给的键查不到** ——
//     那类问题在真机上表现为"某项设置永远是默认值"，而不是报错。
//   · **核心侧用字符串拼接的键查不到**（如 `[NSString stringWithFormat:@"%@_size", base]`）——
//     那种键名是运行期拼出来的，静态看不出来。
//   · **改了核心的读取逻辑后要人工同步本检查**：它比的是"键名出现过"，不是"键名真的被用来取那个值"。
//   · 只认 `CoreLayoutExport.swift` 一个文件里的导出（如果将来出现第二个导出入口，它看不见）。

const PATHS = require('./_paths');
const fs = require('fs');
const path = require('path');

const ROOT = PATHS.REPO;
const EXPORT = path.join(ROOT, 'src', 'CoreLayoutExport.swift');

// 核心暂不支持、但我们仍保留输出的键（将来核心支持时可无缝生效）
const ALLOW = {
  textSize:        '核心用 adjustsFontSizeToFitWidth 自动缩放，暂无 textSize 概念',
  joystickColor:   '核心摇杆用固定样式，未从布局 JSON 取颜色',
  joystickSize:    '核心摇杆尺寸由 width/height 决定，未单独读这个键',
  pressedBgColor:  '核心没有"按下态外观"概念（整个 pressed* 家族都不支持）',
};

function readTree(dir, exts, skip) {
  const out = [];
  const stack = [dir];
  while (stack.length) {
    const cur = stack.pop();
    let entries;
    try { entries = fs.readdirSync(cur, { withFileTypes: true }); } catch { continue; }
    for (const e of entries) {
      const full = path.join(cur, e.name);
      if (e.isDirectory()) {
        if (skip.includes(e.name)) continue;
        stack.push(full);
      } else if (exts.some(x => e.name.endsWith(x))) {
        try { out.push(fs.readFileSync(full, 'utf8')); } catch {}
      }
    }
  }
  return out.join('\n');
}

const exportSrc = fs.readFileSync(EXPORT, 'utf8');
const coreSrc = readTree(path.join(ROOT, 'core'), ['.m', '.h'], ['external', 'build', '.git']);

const keys = new Set();
for (const m of exportSrc.matchAll(/d\["([A-Za-z_]+)"\]\s*=/g)) keys.add(m[1]);

const missing = [];
const allowed = [];
for (const k of [...keys].sort()) {
  if (coreSrc.includes(k)) continue;
  if (ALLOW[k]) { allowed.push(k); continue; }
  missing.push(k);
}

console.log(`导出布局里共 ${keys.size} 个键`);
console.log(`核心源码不认的：${allowed.length + missing.length} 个`);
console.log('');

if (allowed.length) {
  console.log(`· 已登记为例外（核心暂不支持，保留输出以便将来兼容）：`);
  for (const k of allowed) console.log(`    ${k}  —— ${ALLOW[k]}`);
  console.log('');
}

if (missing.length === 0) {
  console.log('✓ 除已登记例外外，导出的每个键核心都会读');
  process.exit(0);
}

console.log(`⚠ ${missing.length} 个键核心完全不认，且没登记理由：`);
for (const k of missing) console.log(`    ${k}`);
console.log('');
console.log('修法二选一：① 核心支持它 ② 别导出它 ③ 确认要在编辑器里保留的话，');
console.log('          在本脚本的 ALLOW 里写明理由，并在编辑器里告诉用户"进游戏不生效"。');
process.exit(1);
