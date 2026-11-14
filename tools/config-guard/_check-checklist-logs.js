// 验证清单 ↔ 代码 的日志文案契约
//
// 起因：docs/真机验证清单-给朋友.md 里有一张表，教朋友「打开日志搜这几句，
// 命中哪句就说明是哪一层的问题」。但那些字符串**没有任何机制保证真的存在**：
// 改了日志文案，清单就悄悄失效，而失效的表现是"朋友搜不到，以为日志是空的"。
//
// 实测就发现一处：清单写 `找不到内置 JRE`，而代码里根本没有这句话 ——
// 真实的失败信息是 Swing 侧抛出的「这个版本需要 Java N，但包里只有：…」，
// 而且它显示在启动页上，压根不写进 ame.log。
//
// 判据：
//   1. 从清单那张表里抽出所有行内代码（反引号包起来的）
//   2. 跳过 JVM/系统自己产生的字样（异常类名等），那些不是我们的文案
//   3. 带占位符（... 或独立 X）的，拆成片段，要求每个片段都出现
//   4. 其余要求整串出现（在 core/**/*.m 或 src/*.swift 里）
//   5. 任一不满足 → 报错并退出 1
//
// **局限**（不查什么）：
//   · **只查清单里"反引号包起来的行内代码"那 17 处**。清单正文的自然语言描述
//     （"日志在 ame.log 末尾"、"超 2MB 会清空"、"它显示在启动失败那一屏"）**完全不在范围** ——
//     那些说错了，本检查照样 ✓。
//   · **只查"这串字在代码里存不存在"，不查"它是在日志里还是在屏幕上"**。第54轮就抓到过一条
//     **同时错两处**的指引：清单让人去日志里搜，而那串其实是 Swift 抛的错误、只显示在界面上。
//     现在靠人工在表头注明了"个别只在屏幕上出现"，**没有机制守着**。
//   · 跳过规则（JVM/系统字样、纯路径）是**人工白名单**。清单里新写一句系统文案会被当成"我们的文案"误报。
//   · **只认 `真机验证清单-给朋友.md` 一份清单**。若将来出现第二份（比如给开发者的），不在范围。

const fs = require('fs');
const path = require('path');

const PATHS = require('./_paths');
const { CORE, SRC } = PATHS;
const DOC = path.join(PATHS.DOCS, "真机验证清单-给朋友.md");
// ---- 收集全部源码文本 ----
function readTree(dir, exts) {
  const out = [];
  const stack = [dir];
  while (stack.length) {
    const cur = stack.pop();
    let entries;
    try { entries = fs.readdirSync(cur, { withFileTypes: true }); } catch { continue; }
    for (const e of entries) {
      const full = path.join(cur, e.name);
      if (e.isDirectory()) {
        if (e.name === 'build' || e.name === 'external' || e.name === '.git') continue;
        stack.push(full);
      } else if (exts.some(x => e.name.endsWith(x))) {
        try { out.push(fs.readFileSync(full, 'utf8')); } catch {}
      }
    }
  }
  return out.join('\n');
}

const code = readTree(CORE, ['.m', '.h']) + '\n' + readTree(SRC, ['.swift']);

// ---- 从清单表格里抽行内代码 ----
const doc = fs.readFileSync(DOC, 'utf8');

// 只取「搜这句 / 说明什么」那张表
const tableStart = doc.indexOf('| 搜这句 |');
if (tableStart < 0) {
  console.log('✗ 没在清单里找到「搜这句」表格 —— 表格可能被改名或删了');
  process.exit(1);
}
const tableEnd = doc.indexOf('\n\n', tableStart);
const table = doc.slice(tableStart, tableEnd < 0 ? doc.length : tableEnd);

const spans = new Set();
for (const m of table.matchAll(/`([^`]+)`/g)) spans.add(m[1]);

// ---- 不是我们写的字样（JVM / 系统 / 类名）----
const NOT_OURS = [
  'UnsatisfiedLinkError', 'ClassNotFoundException', 'NoSuchMethodError',
  'NoClassDefFoundError', 'Error opening zip file', 'PojavLauncher',
  'CraftLauncher-', 'ZL2-', 'ame.log', 'latest.log', 'libs/launcher.jar',
  'libs/patchjna_agent.jar', 'controlmap/default.json',
];

function fragmentsOf(s) {
  // 占位符：连续三个点 / 独立的 X
  return s.split(/\.\.\.|\bX\b/).map(x => x.trim()).filter(x => x.length >= 3);
}

let pass = 0;
const bad = [];

for (const span of spans) {
  if (NOT_OURS.includes(span)) { pass++; continue; }
  // 纯文件名/路径类（含 / 且以 . 结尾扩展）不当作日志文案
  if (/^[\w./-]+\.(json|jar|log|txt|xml)$/.test(span)) { pass++; continue; }

  const frags = fragmentsOf(span);
  if (frags.length === 0) { pass++; continue; }

  const missing = frags.filter(f => !code.includes(f));
  if (missing.length === 0) {
    pass++;
  } else {
    bad.push({ span, missing });
  }
}

console.log(`清单表格里的行内代码：${spans.size} 处`);
console.log('');

if (bad.length === 0) {
  console.log('✓ 清单里让用户搜的每一句，都能在代码里找到对应文案');
  process.exit(0);
}

console.log(`⚠ ${bad.length} 处对不上（清单会静默失效）：`);
for (const b of bad) {
  console.log(`\n  \`${b.span}\``);
  for (const m of b.missing) console.log(`    代码里找不到： "${m}"`);
}
console.log('');
console.log('修法二选一：① 改清单，写成代码里真实的文案 ② 改代码，让日志真的输出这句');
process.exit(1);
