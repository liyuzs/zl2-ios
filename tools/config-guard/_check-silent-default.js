// 字符串 switch 里不许有"静默 default"（第162轮）
//
// 为什么只管字符串 switch：
//   · **枚举 switch** —— 编译器强制穷尽，`default` 只兜住"未来新增"；而且"处理少数 case +
//     default 忽略其余"是正常写法，不该报
//   · **数值 switch**（`ns.code` / `URLError.Code(rawValue:)`）—— 值域无界，`default` 必须有
//   · **字符串 switch** —— 编译器**完全不管**，`default` 会**掩盖一切漏掉的 case**
//
// 第161轮就是活例子：`switch route { case "download" ... case "settings" 缺失 → default: break }`
// 用户点「设置」App 会开但不跳页，**没有任何提示**。
// 那次修法就是把 `default: break` 改成 `default:` + NSLog。
//
// 所以这条检查要求：字符串 switch 的 `default` 块**至少留一行日志**（或不写 default，
// 让漏掉的 case 变成"什么也不做"——但那时至少要能看出来是故意的）。
//
// **局限**：
// · 只查 `case "..."` 形式的字符串 switch。用变量/常量做 case（`case SomeConst: `）查不到。
// · 只判"块里有没有实质内容"，判不了日志内容是否有用。
// · 枚举 switch 里"用 default 关掉穷尽性检查"这个隐患**不在本条范围**（那是正常写法，
//   只在"新增 case 忘了处理"时才出问题，而那时应该由 code review 发现）。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const problems = [];
let checked = 0;

for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');
  const lines = src.split(/\r?\n/);

  for (let i = 0; i < lines.length; i++) {
    if (!/^\s*default:/.test(lines[i])) continue;
    if (lines[i].trim().startsWith('//')) continue;

    // 找 switch subject
    let swLine = -1, subject = '';
    for (let j = i - 1; j >= Math.max(0, i - 60); j--) {
      const m = lines[j].match(/switch\s+(.+?)\s*\{/);
      if (m) { swLine = j; subject = m[1].trim(); break; }
    }
    if (swLine < 0) continue;

    // 必须是字符串 switch
    let hasStringCase = false;
    for (let j = swLine; j < Math.min(lines.length, i); j++) {
      if (/case\s+"/.test(lines[j])) { hasStringCase = true; break; }
    }
    if (!hasStringCase) continue;
    checked++;

    // 取 default 块内容
    const ind = lines[i].match(/^\s*/)[0].length;
    const body = [];
    const inline = lines[i].replace(/^\s*default:\s*/, '').trim();
    if (inline) body.push(inline);
    for (let j = i + 1; j < lines.length; j++) {
      const lineInd = lines[j].match(/^\s*/)[0].length;
      const t = lines[j].trim();
      if (t === '') continue;
      if (t.startsWith('}') && lineInd <= ind) break;
      if (lineInd <= ind && /^case\s|^default:/.test(t)) break;
      body.push(t);
    }

    const meaningful = body.filter(l => !l.startsWith('//'));
    const silent = meaningful.length === 0
      || meaningful.every(l => /^(break|return|continue|)$/.test(l.replace(/;$/, '')));

    if (silent) problems.push({ file: f, line: i + 1, subject: subject.slice(0, 44) });
  }
}

console.log(`字符串 switch 数量（含 default）：${checked} 个`);
console.log(`其中 default 是**静默**的：${problems.length} 处\n`);

if (problems.length === 0) {
  console.log('✓ 字符串 switch 的 default 都留了日志（或没有 default）');
  process.exit(0);
}

console.log('⚠ 这些字符串 switch 的 default 是静默的：');
for (const p of problems) {
  console.log(`  ${p.file}:${p.line}  switch ${p.subject}`);
}
console.log('');
console.log('为什么危险：字符串 switch **没有编译器保护**，`default: break` 会把"漏掉的 case"');
console.log('  变成"什么都没发生"。第161轮就因此让「设置」快捷项点了没反应，且无任何提示。');
console.log('修法：`default:` 里加一行 NSLog（说明"走的是未知值"），或在 case 里显式列出所有已知值。');
process.exit(1);
