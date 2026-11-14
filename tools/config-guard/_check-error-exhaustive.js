// errorDescription 的 switch 必须穷尽（第176轮）
//
// 枚举 switch 通常有编译器穷尽检查 —— 但**加了 `default:` 就没有了**。
// 对 `errorDescription` 来说这是净损失：它存在的意义就是"每个错误都说人话"，
// 加了 default 就等于给未来的每个新 case 预设了一句兜底文案（通常是"未知错误"）。
//
// 第176轮实测：12 个 errorDescription 全部穷尽 ✓
//
// **局限**：
// · 只查 `switch self` 形式的 errorDescription / localizedDescription。
//   写成一串 `if case` 的查不到。
// · 只判"有没有 default"，判不了文案质量。
// · **不查"重要操作里只记日志不提示"** —— 第176轮实测分母只有 9 个 catch、
//   且 6 个有 UI 反馈、剩下 3 个是第149轮已知的空 catch（评估过，不值得单开一条检查）。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

let switches = 0;
const problems = [];

for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');
  const lines = src.split(/\r?\n/);

  for (let i = 0; i < lines.length; i++) {
    if (!/(var|func)\s+(errorDescription|localizedDescription)/.test(lines[i])) continue;

    let swIdx = -1;
    for (let j = i; j < Math.min(lines.length, i + 10); j++) {
      if (/switch\s+self/.test(lines[j])) { swIdx = j; break; }
    }
    if (swIdx < 0) continue;

    let depth = 0, end = -1;
    for (let j = swIdx; j < lines.length; j++) {
      for (const ch of lines[j]) { if (ch === '{') depth++; else if (ch === '}') depth--; }
      if (depth === 0) { end = j; break; }
    }
    if (end < 0) continue;

    switches++;
    for (let j = swIdx; j <= end; j++) {
      if (/^\s*default\s*:/.test(lines[j])) {
        problems.push({ file: f, line: j + 1, at: i + 1 });
        break;
      }
    }
  }
}

console.log(`errorDescription 的 switch：${switches} 个`);
console.log(`其中用 default 兜底的：${problems.length} 个\n`);

if (problems.length === 0) {
  console.log('✓ 全部穷尽 —— 新增错误 case 时编译器会强制你写文案');
  process.exit(0);
}

console.log('⚠ 这些 errorDescription 用了 default 兜底：');
for (const p of problems) console.log(`  ${p.file}:${p.line}（errorDescription 在 L${p.at}）`);
console.log('');
console.log('后果：将来给枚举加新 case 时不会有人提醒你补文案，它会静默显示成兜底那句。');
console.log('修法：删掉 default，把剩下的 case 显式列出来（编译器会告诉你漏了哪个）。');
process.exit(1);
