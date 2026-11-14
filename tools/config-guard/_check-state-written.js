// @State 必须有写入路径，且"初值"不算写入（第177轮）
//
// 分母 343 个 @State。判据：`@State var name` 必须有写入路径之一：
//   · `name = ...`（赋值，排除 `==`）
//   · `$name`（binding，传给子视图让它写）
//   · `name += / -= / *= / /=`
//   · `name.toggle()` / `.append()` / `.removeAll()` 等原地修改
//   · `name[i] = ...`
//
// **两个关键细节（都是注入验证抓出来的）**：
// ① **声明行的 `= 初值` 不算写入** —— `@State var x = 42` 那行的 `= 42` 是初值。
//    不排除的话每个 @State 都"看起来被写过"，判据完全失效。
// ② **初值是表达式就不报** —— `= ZLLoadingTips.random` / `= Date()` 每次视图重建都会重新求值，
//    "从不被写入"是设计（第177轮 `cuteTip` 就是这种，误报过）。
//    只有**字面量初值**（0 / "" / false / [] / nil / .case）且从不被写 → 它应该是 `let`。
//
// **局限**：
// · 通过 `Binding(get:set:)` 手工包装的写路径查不到 → 会误报（本项目当前 0 处）。
// · 变量名在不同视图里重名时，只能按"任一处有写入"宽松判定 → 会漏报。
// · 只查 `@State`，不查 `@Binding`（后者本来就该由父视图写）。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

const states = [];
for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');
  const lines = src.split(/\r?\n/);
  lines.forEach((line, i) => {
    const m = line.match(/@State\s+(?:private\s+)?var\s+(\w+)\s*(?::\s*[^=]+)?=\s*(.+?)\s*$/);
    if (m) states.push({ file: f, line: i + 1, name: m[1], initial: m[2] });
    else {
      const m2 = line.match(/@State\s+(?:private\s+)?var\s+(\w+)/);
      if (m2) states.push({ file: f, line: i + 1, name: m2[1], initial: '' });
    }
  });
}

// 剥注释 + **剔除声明行**（细节①）
const base = files.map(f => fs.readFileSync(path.join(SRC, f), 'utf8'))
  .join('\n').split(/\r?\n/)
  .filter(l => !l.trim().startsWith('//') && !l.trim().startsWith('///'));
const codeOnly = base.join('\n');
const codeForWrite = base.filter(l => !/@State\s+(?:private\s+)?var\s+\w+/.test(l)).join('\n');

const problems = [];
for (const st of states) {
  const n = st.name;
  const writes = [
    new RegExp(`\\b${n}\\s*=(?!=)`),
    new RegExp(`\\$${n}\\b`),
    new RegExp(`\\b${n}\\s*[+\\-*/]=`),
    new RegExp(`\\b${n}\\.(toggle|append|insert|remove|formUnion|formIntersection|removeAll|removeLast|removeFirst)\\(`),
    new RegExp(`\\b${n}\\[[^\\]]*\\]\\s*=`),
  ];
  if (writes.some(re => re.test(codeForWrite))) continue;

  // 细节②：表达式初值不算问题
  const init = (st.initial || '').trim();
  const isLiteral = init !== '' && /^(-?\d+(\.\d+)?|"[^"]*"|true|false|nil|\[\]|\[:\]|""|Set\(\)|\.\w+)$/.test(init);
  if (!isLiteral) continue;

  problems.push(st);
}

console.log(`@State 声明：${states.length} 个`);
console.log(`字面量初值 + 从未被写入的：${problems.length} 个\n`);

if (problems.length === 0) {
  console.log('✓ 每个 @State 要么有写入路径，要么初值是表达式（每次重建求值）');
  process.exit(0);
}

console.log('⚠ 这些 @State 初值是字面量、且没有任何写入路径 —— 它们应该用 `let`（或删掉）：');
for (const p of problems) console.log(`  ${p.file}:${p.line}  ${p.name} = ${p.initial}`);
console.log('');
console.log('为什么是问题：@State 的意义是"会变、变了要重绘"。初值写死且从不被写入，');
console.log('  等于一个永远不变的常量却占着 @State 的位置 —— 读者会以为它能变。');
process.exit(1);
