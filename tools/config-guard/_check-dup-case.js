// enum 内重复 case（第184轮）
//
// 第183轮补了"同类型内重复声明 var/let"（`_check-dup-decl.js`）。
// 但 `case` 没覆盖 —— 而 `enum X { case a; case a }` 同样是编译错误（invalid redeclaration）。
//
// 判据：同一个 `enum` 块内，`case` 名出现两次 → 报。
// 注意 `case a, b, c` 一行多个要拆开。
//
// **局限**：
// · 只查 enum 块内的 `case`（`switch` 里的 `case` 不算 —— 那个在别的作用域）。
// · 用缩进判断是否在 enum 块内（非常规缩进会漏）。
// · 不查"case 与已有 static 属性重名"。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

const problems = [];
let enumCount = 0, caseCount = 0;

for (const f of files) {
  const lines = fs.readFileSync(path.join(SRC, f), 'utf8').split(/\r?\n/);

  // 栈：[{ name, indent, cases: Map<name,[行号]> }]
  const stack = [];

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    const line = raw.trim();
    if (line === '' || line.startsWith('//')) continue;
    const indent = raw.match(/^ */)[0].length;

    // 进入 enum？
    const em = line.match(/^(?:@\w+\s+)*(?:public\s+|internal\s+|private\s+|fileprivate\s+)?enum\s+(\w+)/);
    if (em && line.includes('{')) {
      stack.push({ name: em[1], indent, cases: new Map() });
      enumCount++;
    }

    // 记录 case（只有在 enum 栈内、且缩进是本 enum 的直接子级）
    if (stack.length > 0 && line.startsWith('case ')) {
      const top = stack[stack.length - 1];
      if (indent === top.indent + 4) {
        // `case a` / `case a, b, c` / `case a(Int)`
        const body = line.replace(/^case\s+/, '');
        for (const part of body.split(',')) {
          const nm = part.trim().match(/^([A-Za-z_]\w*)/);
          if (!nm) continue;
          const n = nm[1];
          caseCount++;
          if (!top.cases.has(n)) top.cases.set(n, []);
          top.cases.get(n).push(i + 1);
        }
      }
    }

    // 退出 enum（`}` 缩进 <= enum 缩进）
    if (line.startsWith('}') && stack.length > 0) {
      const top = stack[stack.length - 1];
      if (indent <= top.indent) {
        stack.pop();
        for (const [n, ls] of top.cases) {
          if (ls.length > 1) problems.push({ file: f, enumName: top.name, caseName: n, lines: ls });
        }
      }
    }
  }

  while (stack.length > 0) {
    const top = stack.pop();
    for (const [n, ls] of top.cases) {
      if (ls.length > 1) problems.push({ file: f, enumName: top.name, caseName: n, lines: ls });
    }
  }
}

console.log(`扫了 ${enumCount} 个 enum，共 ${caseCount} 个 case`);
console.log(`重复的：${problems.length} 处\n`);

// **第196轮**：零匹配保护 —— 一个 enum 都没扫到时，输出和"全部合规"长得一样。
const __guardCount = enumCount + caseCount;
if (__guardCount === 0) {
  console.log('⚠ 一个 enum / case 都没扫到 —— 判据可能失效了');
  process.exit(1);
}

if (problems.length === 0) {
  console.log('✓ 没有 enum 内重复 case');
  process.exit(0);
}

console.log('⚠ 这些 enum 里同一个 case 声明了两次（Swift 会报 invalid redeclaration）：');
for (const p of problems) {
  console.log(`  ${p.file}  ${p.enumName}.${p.caseName}  在 L${p.lines.join(', L')}`);
}
process.exit(1);
