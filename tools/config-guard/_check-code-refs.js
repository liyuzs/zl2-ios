// 注释里引用的「本仓库文件:行号」必须仍然指得到代码（第167轮）
//
// 项目里有 26 处注释用「见 SurfaceViewController.m:464」这种形式做**对照依据**
// （从安卓 ZL2 移植时逐行核对用的）。重构会让行号漂移，而**没有任何编译器检查**在意它们。
//
// 判据（三层，从宽到严）：
//   ① 文件必须存在（`GLFWKeyNames.swift` 引用的 `glfw_keycodes.h` 得真在仓库里）
//   ② 行号不能超出文件长度（文件缩短了 → 引用越界）
//   ③ **该行不能是空行或纯注释**（那说明它偏移到了空白区）
//
// 第③层是第167轮的新洞察：只看"不越界"会漏掉"偏移到别处但仍在文件内"的情况。
//
// **局限**：
// · 只查 `.m` / `.mm` / `.h` / `.swift`（**本仓库**的文件）。`.kt` / `.java` 大量引用的是
//   安卓参考源码，不在本仓库，按设计不检查。
// · **抓不到"偏移到另一段代码"** —— 比如注释说"见 X:100 的 loadControlObject"，
//   而 100 行现在是另一个函数，本检查仍会通过。要抓那种需要语义比对，做不到。
// · 只认 `文件:行号` 这一种写法。写「见上面那个函数」这类散文式引用查不到。
const fs = require('fs');
const path = require('path');

const { REPO, SRC } = require('./_paths');

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const REF = /(\w+\.(?:m|mm|h|swift)):(\d+)/g;

// 本仓库所有源文件的行内容
const content = new Map();
const collect = (dir) => {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (['build', 'external', '.git'].includes(e.name)) continue;
    const full = path.join(dir, e.name);
    if (e.isDirectory()) { collect(full); continue; }
    if (/\.(swift|m|mm|h)$/.test(e.name)) {
      try { content.set(e.name, fs.readFileSync(full, 'utf8').split(/\r?\n/)); } catch {}
    }
  }
};
collect(SRC);
collect(path.join(REPO, 'core'));

const refs = [];
for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');
  const lines = src.split(/\r?\n/);
  lines.forEach((line, i) => {
    if (!line.trim().startsWith('//') && !line.includes('///')) return;
    for (const m of line.matchAll(REF)) {
      refs.push({ file: f, line: i + 1, target: m[1], n: parseInt(m[2], 10) });
    }
  });
}

console.log(`注释里引用本仓库文件的「文件:行号」：${refs.length} 处`);

const missing = refs.filter(r => !content.has(r.target));
const overflow = refs.filter(r => content.has(r.target) && r.n > content.get(r.target).length);
const blank = refs.filter(r => {
  if (!content.has(r.target)) return false;
  const arr = content.get(r.target);
  if (r.n > arr.length) return false;
  const c = (arr[r.n - 1] || '').trim();
  return c === '' || c.startsWith('//');
});

const problems = [...missing, ...overflow, ...blank];
console.log(`其中有问题：${problems.length} 处\n`);

if (problems.length === 0) {
  console.log('✓ 所有「文件:行号」引用都指得到**代码**（文件存在、不越界、不是空行/注释）');
  console.log('  · 局限：抓不到"偏移到另一段代码"的情况（需要语义比对）');
  process.exit(0);
}

if (missing.length) {
  console.log(`⚠ 引用的文件不存在（${missing.length} 处）：`);
  for (const r of missing) console.log(`  ${r.file}:${r.line} → ${r.target}:${r.n}`);
}
if (overflow.length) {
  console.log(`⚠ 行号超出文件长度（${overflow.length} 处）：`);
  for (const r of overflow) console.log(`  ${r.file}:${r.line} → ${r.target}:${r.n}（只有 ${content.get(r.target).length} 行）`);
}
if (blank.length) {
  console.log(`⚠ 该行是空行/注释（${blank.length} 处，说明引用已漂移）：`);
  for (const r of blank) console.log(`  ${r.file}:${r.line} → ${r.target}:${r.n}`);
}
console.log('');
console.log('修法：把行号改成当前正确的位置；或改用函数名引用（`见 SurfaceViewController 的 loadControlFile`）');
console.log('      后者不会漂移 —— 代价是没法机械检查。');
process.exit(1);
