// 破坏性按钮必须先确认（数据安全前置检查）
//
// 起因：ios-zl2 第63轮发现 `FileManagerScreen` 的「清空回收站」是
//     Button("清空回收站", role: .destructive) { emptyTrash() }
// —— 点一下就把回收站**永久**清空。而回收站存在的意义就是"删错了能捞回来"，
// 一步误触把这层保险毁掉，且不可恢复。其他 4 处删除（存档/资源/模组/版本）
// 都有确认弹窗，只有这一处漏了。
//
// 判据（刻意收窄，避免噪音）：
//   在同一文件里，如果某个函数体里出现 `removeItem`
//   （= 该函数真的在永久删除），那么任何 `role: .destructive` 的按钮
//   **不应该直接调用它**，而应该先设置一个 @State 标志（由确认弹窗接手）。
//
// 不检查 moveItem（移到回收站/临时目录是可恢复的）。

const fs = require('fs');
const path = require('path');

const SRC = 'D:\\ios-zl2\\src';
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

const problems = [];
let checkedFiles = 0;

for (const name of files) {
  const text = fs.readFileSync(path.join(SRC, name), 'utf8');
  if (!text.includes('removeItem')) continue;
  if (!text.includes('role: .destructive')) continue;
  checkedFiles++;

  const flat = text.replace(/\s+/g, ' ');

  // ① 找出「函数体里包含 removeItem」的函数名
  const fnRe = /\bfunc\s+([A-Za-z_]\w*)\s*\([^)]*\)[^{]*\{/g;
  const deleters = new Set();
  let m;
  while ((m = fnRe.exec(flat)) !== null) {
    const name2 = m[1];
    const bodyStart = m.index + m[0].length;
    // 取该函数体（按大括号配对）
    let depth = 1, i = bodyStart;
    while (i < flat.length && depth > 0) {
      if (flat[i] === '{') depth++;
      else if (flat[i] === '}') depth--;
      i++;
    }
    const body = flat.slice(bodyStart, i);
    if (body.includes('removeItem')) deleters.add(name2);
  }

  if (deleters.size === 0) continue;

  // ①.5 先算出所有确认弹窗的区间 —— 弹窗**里面**的 destructive 按钮
  // 正是"确认之后执行删除"的地方，不该被报。
  // 注意 Swift 的**尾随闭包**语法：
  //   confirmationDialog("…", isPresented: x) { Button(...) { … } } message: { Text(…) }
  // 按钮在参数括号**之后**的 { } 里，所以只匹配到 ")" 是不够的 ——
  // 必须继续把后面的尾随闭包（含 message: 标签那种）一起吃进来。
  // （第一版就是只算到 ")"，导致确认弹窗里的按钮被判成"窗口外"，产生误报。）
  const dialogRanges = [];
  const dlgRe = /confirmationDialog\s*\(/g;
  let dm;
  while ((dm = dlgRe.exec(flat)) !== null) {
    const open = flat.indexOf('(', dm.index);
    let depth = 0, i = open;
    for (; i < flat.length; i++) {
      if (flat[i] === '(') depth++;
      else if (flat[i] === ')') { depth--; if (depth === 0) break; }
    }
    // i 现在指向参数列表的 ')'
    let j = i + 1;
    for (;;) {
      let k = j;
      while (k < flat.length && flat[k] === ' ') k++;
      const lm = flat.slice(k, k + 60).match(/^(?:[A-Za-z_]\w*\s*:\s*)?\{/);
      if (!lm) break;
      k += lm[0].length - 1;                       // 落在 '{'
      let d2 = 0, e = k;
      for (; e < flat.length; e++) {
        if (flat[e] === '{') d2++;
        else if (flat[e] === '}') { d2--; if (d2 === 0) break; }
      }
      j = e + 1;                                   // 吃掉这个闭包，继续看有没有下一个
    }
    dialogRanges.push([open, j]);
  }
  const insideDialog = (idx) => dialogRanges.some(([a, b]) => idx > a && idx < b);

  // ② 找 role: .destructive 的按钮，看它直接调用了谁
  const btnRe = /Button\s*\([^)]{0,80}?role:\s*\.destructive[^)]{0,40}?\)\s*\{\s*([^{}]{0,120}?)\s*\}/g;
  while ((m = btnRe.exec(flat)) !== null) {
    if (insideDialog(m.index)) continue;      // 确认弹窗里的执行按钮，正常
    const action = m[1].trim();
    for (const d of deleters) {
      // 直接调用：`emptyTrash()` / `emptyTrash() ` / `self.emptyTrash()`
      const direct = new RegExp(`(?:^|\\s|self\\.)${d}\\s*\\(\\s*\\)\\s*$`).test(action);
      if (direct) {
        problems.push({ file: name, fn: d, action, deleters: [...deleters] });
      }
    }
  }
}

console.log(`含 removeItem + destructive 按钮的文件：${checkedFiles} 个`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 没有「destructive 按钮直接执行永久删除」的情况');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处破坏性按钮直接执行删除（应改为先确认）：`);
for (const p of problems) {
  console.log(`\n  ${p.file}`);
  console.log(`    按钮动作：${p.action}`);
  console.log(`    ${p.fn}() 函数体里有 removeItem（永久删除）`);
}
console.log('');
console.log('修法：按钮动作改成设置一个 @State 标志，由 .confirmationDialog 接手执行。');
process.exit(1);
