// 同一个类型内有没有重复声明（第183轮）
//
// 起因：`HomeScreen.swift` 里有两个 `private var hasInstalledVersion`（L431 文案驱动版、L478 真实数据版），
// 是不同轮次加的（3b454c8 / 054d6f8），谁都没发现重名 —— **Swift 会报 invalid redeclaration，编译不过**。
// 而 `swift-lint.js` 只查括号配对，查不出这个。
//
// 判据：跟踪 struct / class / enum / extension 的嵌套，同一块内出现两次同名的
// `var` / `func` / `let` → 报。
//
// **局限**：
// · 只认这几个关键字开头的块（`protocol` / `actor` 没纳入）。
// · 不区分 `private var x` 和 `func x()` —— Swift 里同名 var 和 func 才算冲突，但这里一并报，需人工确认。
// · 不查"属性与继承来的名字冲突"（那要完整类型系统）。
// · 不算 `@State private var x` 与 `var x` 的修饰符差异 —— 同名就报。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

const problems = [];

for (const f of files) {
  const lines = fs.readFileSync(path.join(SRC, f), 'utf8').split(/\r?\n/);

  // 栈：每个元素 { name, depthAtEntry, decls: Map<name, [行号]> }
  const stack = [{ name: '(file)', decls: new Map() }];

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    const line = raw.trim();
    if (line.startsWith('//') || line === '') continue;

    // 进入一个类型块？（记下它的缩进，用来区分"属性级"和"方法体内的局部变量"）
    const tm = line.match(/^(?:@\w+\s+)*(?:public\s+|internal\s+|private\s+|fileprivate\s+)?(?:final\s+)?(struct|class|enum|extension)\s+(\w+)/);
    if (tm && line.includes('{')) {
      const indent = raw.match(/^ */)[0].length;
      stack.push({ name: tm[1] + ' ' + tm[2], decls: new Map(), indent });
    }

    // 记录声明（**只记属性级 + 只查 var/let**）
    // 第183轮两次修正：
    // ① 限定缩进 = 类型缩进 + 4，否则 `func path(in:) { var path = Path() }` 里的局部变量
    //    会和 `func path` 本身被算成重复（`ControlCornerShape` 就这么误报过）。
    // ② **只查 var/let** —— `func` 允许**重载**（同名不同参数是合法的），
    //    所以 `runtimeCheck(forJava:)` 和 `runtimeCheck(_:)` 不该报（第一次跑时 8 处里大多是这种）。
    //    `var` 不能重载，同名必然冲突 → 这才是要抓的。
    const dm = line.match(/^(?:@\w+\s+)*(?:private\s+|public\s+|internal\s+|fileprivate\s+)?(?:static\s+)?(var|let)\s+(\w+)/);
    if (dm) {
      const top = stack[stack.length - 1];
      const indent = raw.match(/^ */)[0].length;
      if (indent === top.indent + 4) {
        const n = dm[2];
        if (!top.decls.has(n)) top.decls.set(n, []);
        top.decls.get(n).push(i + 1);
      }
    }

    // 退出块：**用缩进判断** —— `}` 的缩进 <= 类型声明缩进，才是这个类型结束。
    // 第183轮修正：原来用"行首是 `}`"就弹栈，但 `body` 的结尾 `}`（缩进 4）也会把
    // `struct HomeScreen`（缩进 0）弹掉 → 后续属性全记到外面去了，判据完全空转。
    if (line.startsWith('}') && stack.length > 1) {
      const closeIndent = raw.match(/^ */)[0].length;
      const top = stack[stack.length - 1];
      if (closeIndent <= top.indent) {
        stack.pop();
        for (const [n, ls] of top.decls) {
          if (ls.length > 1) problems.push({ file: f, type: top.name, name: n, lines: ls });
        }
      }
    }
  }

  // 文件级（不在任何类型里）的残留
  while (stack.length > 1) {
    const top = stack.pop();
    for (const [n, ls] of top.decls) {
      if (ls.length > 1) problems.push({ file: f, type: top.name, name: n, lines: ls });
    }
  }
}


// **第186轮加的"粗数"**：用一条简单正则数顶层类型，供和判据实际识别的个数对账。
// 分母不是"扫了几个文件"（那是输入规模），而是"被测对象有多少个"。
const __roughTypes = files.reduce((n, f) => {
  const s = fs.readFileSync(path.join(SRC, f), 'utf8');
  return n + (s.match(/^(?:public |internal |private |fileprivate |final )*(?:struct|class|enum)\s+\w+/gm) || []).length;
}, 0);

console.log(`扫了 ${files.length} 个文件 · 粗数顶层类型 ${__roughTypes} 个（不含 extension / @MainActor；判据识别的个数应与它接近）`);
console.log(`同一类型内重复声明的：${problems.length} 处\n`);

if (problems.length === 0) {
  console.log('✓ 没有同一类型内的重复声明');
  process.exit(0);
}

console.log('⚠ 这些是同一类型内声明了两次（Swift 会报 invalid redeclaration，编译不过）：');
for (const p of problems) {
  console.log(`  ${p.file}  ${p.type}.${p.name}  在 L${p.lines.join(', L')}`);
}
console.log('');
console.log('修法：删掉一个，或合并。注意可能一个是"文案驱动"的旧实现、一个是"真实数据"的新实现 ——');
console.log('      保留后者，并检查所有调用点是否还在依赖前者。');
process.exit(1);
