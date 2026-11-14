// 同一个 switch 内重复 case（第185轮，v2：从 case 往上找 switch）
//
// 承第184轮的判据："作用域是否局部封闭"。这个检查**只看一个 switch 块** → 封闭 ✓，
// 且重复 case 是**硬编译错误**（"case is already handled by previous patterns"）。
//
// **v1 的方向错了**：从 `switch` 往下用"花括号计数 + 缩进 = switch 缩进 + 4"找 case，
// 结果 111 个 switch 只匹配到 5 处 `.name`（实际全项目有 336 处 `case .x`）—— 分母异常小就是判据失效的信号。
// v2 改用**从 case 往上找最近的 `switch ... {`**（第162轮 `_check-silent-default` 用的就是这方向，验证过可靠）。
//
// **局限**：
// · 只查 `.name` 形式（`case 0:` / `case "s":` 这类字面量不查，范围重叠要更复杂分析）。
// · `case .a where cond:` 与 `case .a:` 在 Swift 里**合法**（where 让它们不重叠）→ 本检查会报，需人工确认。
// · 往上找"最近的 switch"时，如果 case 所在的行本身有 `switch` 关键字（极少）会误判。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

const bySwitch = new Map();   // switch 行号 → [{name, line}]
let caseRefs = 0;

for (const f of files) {
  const lines = fs.readFileSync(path.join(SRC, f), 'utf8').split(/\r?\n/);

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    const line = raw.trim();
    if (line.startsWith('//')) continue;
    if (!/^case\s/.test(line)) continue;

    // 收 `.name`（一行多个要拆）
    const names = [];
    for (const part of line.replace(/^case\s+/, '').split(',')) {
      const m = part.trim().match(/^\.([A-Za-z_]\w*)/);
      if (m) names.push(m[1]);
    }
    if (names.length === 0) continue;

    // 往上找最近的 `switch ... {`
    let swLine = -1;
    for (let j = i - 1; j >= Math.max(0, i - 80); j--) {
      const l2 = lines[j].trim();
      if (l2.startsWith('//')) continue;
      if (/switch\s+.+\{/.test(l2) || /^switch\s*\{/.test(l2)) { swLine = j; break; }
      // 遇到明显的外层结束就停（避免跨进别的函数）
      if (/^(func|var|let)\s/.test(l2)) break;
    }
    if (swLine < 0) continue;

    caseRefs += names.length;
    const key = f + ':' + (swLine + 1);
    if (!bySwitch.has(key)) bySwitch.set(key, []);
    for (const n of names) bySwitch.get(key).push({ name: n, line: i + 1 });
  }
}

const problems = [];
for (const [key, items] of bySwitch) {
  const seen = new Map();
  for (const it of items) {
    if (!seen.has(it.name)) seen.set(it.name, []);
    seen.get(it.name).push(it.line);
  }
  for (const [n, ls] of seen) {
    if (ls.length > 1) problems.push({ key, name: n, at: ls });
  }
}

console.log(`归到 switch 的 \`.name\` 引用：${caseRefs} 处（分布在 ${bySwitch.size} 个 switch）`);
console.log(`重复的：${problems.length} 处\n`);

// **第196轮**：零匹配保护。
if (caseRefs === 0) {
  console.log('⚠ 一处 `.name` case 引用都没归到 switch —— 判据可能失效了');
  process.exit(1);
}

if (problems.length === 0) {
  console.log('✓ 没有同一个 switch 内重复的 case');
  process.exit(0);
}

console.log('⚠ 这些 switch 里同一个 case 出现了两次（Swift 会报 case is already handled）：');
for (const p of problems) {
  console.log(`  ${p.key}  .${p.name}  在 L${p.at.join(', L')}`);
}
console.log('');
console.log('注意：`case .a where cond:` 和 `case .a:` 是合法的（where 让它们不重叠）—— 人工确认后忽略。');
process.exit(1);
