// 检查 SettingsScreen 里 picker(...) 调用的参数个数
// picker 签名: picker(_ key: String, _ title: String, _ summary: String?, options: [ZLOption])
// 无标签参数必须是 3 个，加 options: 一个。多一个少一个都编译不过。

const fs = require('fs');
const src = fs.readFileSync('D:\\ios-zl2\\src\\SettingsScreen.swift', 'utf8');

// 找到所有 picker( 开头的调用
const re = /\bpicker\(/g;
let m;
const problems = [];
let count = 0;

while ((m = re.exec(src)) !== null) {
  // 排掉函数定义本身
  const before = src.slice(Math.max(0, m.index - 20), m.index);
  if (/func\s+$/.test(before)) continue;
  // 排掉枚举 case 与点语法：case picker(...) / .picker(...) / kind: .picker(...)
  if (/case\s+$/.test(before)) continue;
  if (src[m.index - 1] === '.') continue;
  if (/\.picker\(/.test(src.slice(Math.max(0, m.index - 1), m.index + 7))) continue;
  // 排掉字符串里的内容
  const lineStart = src.lastIndexOf('\n', m.index) + 1;
  const lineText = src.slice(lineStart, src.indexOf('\n', m.index));
  if (/^\s*(\/\/|\*)/.test(lineText)) continue;


  count++;
  // 从 ( 开始做括号配对，取出完整实参
  let i = m.index + 'picker'.length;
  let depth = 0, start = i, end = -1;
  for (; i < src.length; i++) {
    const c = src[i];
    if (c === '(') depth++;
    else if (c === ')') { depth--; if (depth === 0) { end = i; break; } }
    else if (c === '"') {
      // 跳过字符串
      i++;
      while (i < src.length && src[i] !== '"') { if (src[i] === '\\') i++; i++; }
    }
  }
  if (end < 0) { problems.push(`第 ${count} 个 picker 括号不配对`); continue; }
  const argsRaw = src.slice(start + 1, end);

  // 按顶层逗号切分
  const args = [];
  let d = 0, cur = '';
  let inStr = false;
  for (let j = 0; j < argsRaw.length; j++) {
    const c = argsRaw[j];
    if (inStr) {
      cur += c;
      if (c === '\\') { cur += argsRaw[++j]; continue; }
      if (c === '"') inStr = false;
      continue;
    }
    if (c === '"') { inStr = true; cur += c; continue; }
    if ('([{'.includes(c)) { d++; cur += c; continue; }
    if (')]}'.includes(c)) { d--; cur += c; continue; }
    if (c === ',' && d === 0) { args.push(cur.trim()); cur = ''; continue; }
    cur += c;
  }
  if (cur.trim()) args.push(cur.trim());

  const labeled = args.filter(a => /^options\s*:/.test(a));
  const unlabeled = args.filter(a => !/^[a-zA-Z_][a-zA-Z0-9_]*\s*:/.test(a));

  const lineNo = src.slice(0, m.index).split('\n').length;
  if (unlabeled.length !== 3) {
    problems.push(`第 ${lineNo} 行 picker 无标签参数 ${unlabeled.length} 个（应为 3）`);
  }
  if (labeled.length !== 1) {
    problems.push(`第 ${lineNo} 行 picker 的 options: 参数 ${labeled.length} 个（应为 1）`);
  }
}

if (problems.length === 0) {
  console.log(`✓ ${count} 处 picker 调用参数个数全部正确`);
} else {
  console.log('✗ 发现问题：');
  problems.forEach(p => console.log('  - ' + p));
  process.exit(1);
}
