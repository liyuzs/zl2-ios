// 按钮的 action 是不是空的（第178轮）
//
// 分母：695 个 Button → 排除 `Button(action:)` 形式后 270 → 排除 `role: .cancel` 后 **241**。
//
// 空 action = `Button { } label: {...}` 或 `Button("x") { }` —— 点了没反应，
// 而用户看到的是个正常按钮（第108轮"有反馈的假功能"的同类）。
//
// **两种必须排除的合法写法**（第178轮实测：不排除会产生 11 个误报）：
// ① `Button(action: someFunc) { label }` —— 含 `action:` 时 `{}` 是 **label**，不是 action
// ② `Button("取消", role: .cancel) { }` —— 在 alert/dialog 里**空 action 是标准写法**，
//    关闭由系统处理。（role 可能写在下一行，所以往后看 2 行。）
//
// **局限**：
// · 只判"块内是否只有空白/注释"。判不了"action 里做了但没效果"（需语义）。
// · `Button(action: someVar) { }` 里 someVar 是否指向空闭包，本检查看不到 —— 跳过。
// · 自定义 ButtonStyle 包装的按钮不在此范围。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

let total = 0;
const empties = [];

for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');
  const lines = src.split(/\r?\n/);

  for (let i = 0; i < lines.length; i++) {
    if (!/\bButton\b/.test(lines[i])) continue;
    if (lines[i].trim().startsWith('//')) continue;

    const declLine = lines[i];

    // 排除 ① `Button(action:)`
    if (/Button\s*\(\s*action\s*:/.test(declLine)) continue;

    // 排除 ② `role: .cancel` / `.close`（往后看 2 行，覆盖多行签名）
    const roleWindow = [lines[i], lines[i + 1] || '', lines[i + 2] || ''].join(' ');
    if (/role\s*:\s*\.(cancel|close)/.test(roleWindow)) continue;

    total++;

    // 找声明之后第一个 `{`
    let braceIdx = -1;
    for (let j = i; j < Math.min(lines.length, i + 6); j++) {
      if (lines[j].indexOf('{') >= 0) { braceIdx = j; break; }
    }
    if (braceIdx < 0) continue;

    // 配对到块结束
    let depth = 0, endLine = -1;
    const startCol = lines[braceIdx].indexOf('{');
    for (let j = braceIdx; j < lines.length; j++) {
      const line = lines[j];
      const from = (j === braceIdx) ? startCol : 0;
      for (let k = from; k < line.length; k++) {
        if (line[k] === '{') depth++;
        else if (line[k] === '}') { depth--; if (depth === 0) { endLine = j; break; } }
      }
      if (endLine >= 0) break;
    }
    if (endLine < 0) continue;

    // 取块内容
    let block;
    if (endLine === braceIdx) {
      const s = lines[braceIdx];
      block = s.slice(s.indexOf('{') + 1, s.lastIndexOf('}'));
    } else {
      const parts = [lines[braceIdx].slice(lines[braceIdx].indexOf('{') + 1)];
      for (let j = braceIdx + 1; j < endLine; j++) parts.push(lines[j]);
      const last = lines[endLine];
      parts.push(last.slice(0, last.lastIndexOf('}')));
      block = parts.join('\n');
    }

    const meaningful = block.split(/\r?\n/)
      .map(l => l.trim())
      .filter(l => l !== '' && !l.startsWith('//'));
    if (meaningful.length === 0) empties.push({ file: f, line: i + 1, text: declLine.trim().slice(0, 70) });
  }
}

console.log(`Button（排除 action: 形式与 role: .cancel）：${total} 个`);
console.log(`action 块为空的：${empties.length} 个\n`);

if (empties.length === 0) {
  console.log('✓ 没有空 action 的按钮');
  process.exit(0);
}

console.log('⚠ 这些按钮的 action 是空的（点了没反应）：');
for (const e of empties) console.log(`  ${e.file}:${e.line}  ${e.text}`);
console.log('');
console.log('修法：补上动作，或把按钮换成纯展示（去掉 Button 外壳）。');
process.exit(1);
