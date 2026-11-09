// 核心孤儿函数审计
//
// 起因：generateAndSaveDefaultControl() 在整个工程里**没有任何调用点**
// （grep 只有定义），而 defaultTouchCtrl 的默认值就是 "default.json"，
// 于是首次启动必然弹 "Could not open" 且屏幕上没有控件。
//
// 这类问题有一个共同特征：函数写好了、声明了、逻辑也对，就是没人调用。
// 编译不会报错，链接也不会报错（静态库里的符号没人用而已）。
//
// 这个脚本把 core/ 下所有 C 函数定义抽出来，统计它们在
// 全部 core + src 里的真实引用次数（排除定义行和头文件声明），
// 把 0 引用的列出来。

const fs = require('fs');
const path = require('path');

const REPO = 'D:\\ios-zl2';
const CORE = path.join(REPO, 'core');
const SRC = path.join(REPO, 'src');

function collect(dir, exts, maxDepth = 6, depth = 0, out = []) {
  if (depth > maxDepth || !fs.existsSync(dir)) return out;
  for (const f of fs.readdirSync(dir)) {
    if (f === 'external' || f === 'build') continue;   // 第三方与构建产物不管
    const full = path.join(dir, f);
    let st;
    try { st = fs.statSync(full); } catch { continue; }
    if (st.isDirectory()) collect(full, exts, maxDepth, depth + 1, out);
    else if (exts.some(e => f.endsWith(e))) out.push(full);
  }
  return out;
}

const coreFiles = collect(CORE, ['.m', '.h']);
const srcFiles = collect(SRC, ['.swift', '.h']);
const allFiles = [...coreFiles, ...srcFiles];

const texts = new Map();
for (const f of allFiles) texts.set(f, fs.readFileSync(f, 'utf8'));

// ---- 1. 抽 C 函数定义（.m 文件，行首类型 + 名字 + 括号，排除 ObjC 方法）----
const defs = [];   // { name, file, line }
for (const f of coreFiles) {
  if (!f.endsWith('.m')) continue;
  const text = texts.get(f);
  text.split('\n').forEach((line, i) => {
    if (/^\s*[-+]\s*\(/.test(line)) return;          // ObjC 方法
    if (/^\s*\/\//.test(line)) return;                // 注释
    if (/^\s*#/.test(line)) return;                   // 预处理
    // 行首开始、返回类型 + 空格 + 名字 + (
    const m = line.match(/^([A-Za-z_][A-Za-z0-9_]*[\s\*]+)+([A-Za-z_][A-Za-z0-9_]*)\s*\(/);
    if (!m) return;
    const name = m[2];
    if (['if', 'for', 'while', 'switch', 'return', 'sizeof'].includes(name)) return;
    defs.push({ name, file: f, line: i + 1 });
  });
}

// ---- 2. 统计引用 ----
function countRefs(name, defFile, defLine) {
  let n = 0;
  const re = new RegExp(`\\b${name}\\s*\\(`, 'g');
  for (const [f, text] of texts) {
    const lines = text.split('\n');
    lines.forEach((line, i) => {
      // 跳过定义行本身
      if (f === defFile && i + 1 === defLine) return;
      // 跳过纯声明（头文件里的 xxx name(...); 或 .m 里的前向声明）
      const trimmed = line.trim();
      if (/;\s*$/.test(trimmed) && re.test(trimmed) && !/\{\s*$/.test(trimmed)) {
        // 形如 "void foo(int a);" —— 是声明不是调用
        if (/^[A-Za-z_][A-Za-z0-9_]*[\s\*]+[A-Za-z_][A-Za-z0-9_]*\s*\(/.test(trimmed)) return;
      }
      re.lastIndex = 0;
      let m;
      while ((m = re.exec(line)) !== null) n++;
    });
  }
  return n;
}

const orphans = [];
for (const d of defs) {
  const n = countRefs(d.name, d.file, d.line);
  if (n === 0) orphans.push({ ...d, rel: path.relative(REPO, d.file) });
}

// ---- 3. 输出 ----
console.log(`core/ 下 C 函数定义：${defs.length} 个`);
console.log('');

// 只对「看起来应该被调用」的函数报警（生成/初始化/加载/更新/设置类）
const SHOULD_BE_CALLED = /^(generate|setup|init|load|update|prepare|create|register|install|apply|reset|save|sync|refresh|start|stop)/i;
const important = orphans.filter(o => SHOULD_BE_CALLED.test(o.name));
const others = orphans.filter(o => !SHOULD_BE_CALLED.test(o.name));

if (important.length === 0) {
  console.log('✓ 没有「应该被调用但没人调用」的初始化类函数');
} else {
  console.log(`⚠ ${important.length} 个初始化/生成类函数零引用（很可能从未生效）：`);
  for (const o of important) console.log(`  · ${o.name}   ${o.rel}:${o.line}`);
}

if (others.length > 0) {
  console.log('');
  console.log(`（另有 ${others.length} 个其它零引用函数，供参考）`);
  for (const o of others.slice(0, 25)) console.log(`  · ${o.name}   ${o.rel}:${o.line}`);
  if (others.length > 25) console.log(`  …… 其余 ${others.length - 25} 个略`);
}

// generateAndSaveDefaultControl 是本脚本的起因，单独复核
const g = defs.find(d => d.name === 'generateAndSaveDefaultControl');
console.log('');
if (g) {
  const n = countRefs(g.name, g.file, g.line);
  console.log(`generateAndSaveDefaultControl 现有引用数：${n} ${n > 0 ? '✓ 已被调用' : '✗ 仍是孤儿'}`);
  if (n === 0) process.exit(1);
} else {
  console.log('没找到 generateAndSaveDefaultControl 定义');
}

process.exit(0);
