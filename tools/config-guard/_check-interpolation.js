// 字符串插值引用检查
//
// 起因：ios-zl2 第43轮我在导出整合包的说明文本里写了
//     let packMinMem = Int(minMemory)
//     s += "建议最小内存：\(packMemMin) MB\n"
// —— 拼成了 packMemMin。这在 Xcode 里是编译错误，但本地的 swift-lint
// 只查括号配对，全绿通过。这类"只在插值里出现一次"的标识符，
// 几乎必然是拼错或者变量根本不存在。
//
// 判定：抽所有 \(ident) 形式的插值，只看"纯标识符"（不含 . 或 ( 的），
// 然后统计它在**整个 src 目录**里出现的次数。只出现 1 次 = 只在这里被引用过，
//
// **局限**（不查什么）：
//   · **只查纯标识符**（`\(packMemMin)`）。带点或带括号的（`\(a.b)` / `\(f(x))`）**不查** ——
//     因为那种写法里"拼错"和"正常访问"没法用正则区分。**所以真正的拼错如果写成 `\(obj.typo)`，本检查看不见。**
//   · "只出现 1 次"这个判据会**误报"真的只用一次的变量"**（比如某个只在一处插值的常量）—— 实际很少。
//   · **跨文件使用**：如果变量在 A 文件定义、只在 B 文件插值一次，**总数是 2（定义 + 插值）**，
//     所以不会误报；但如果它**定义在别处且名字只出现一次**（不可能，定义就是一次），这里不会漏。
//   · 字符串里**故意**写的占位符（如日志模板 `\(xxx)`）会被当成拼错。
// 那它要么拼错了，要么是个不存在的名字。
//
// 为什么要看整个目录而不是本文件：跨文件引用的常量/类型（如 ZLStrings.xxx）
// 至少会在自己的定义文件里出现一次，合计 >= 2，不会误报。

const fs = require('fs');
const path = require('path');
const { SRC } = require('./_paths');
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift')).map(f => ({
  name: f,
  text: fs.readFileSync(path.join(SRC, f), 'utf8'),
}));

// 全文词频（跨文件）
const freq = new Map();
function bump(name) { freq.set(name, (freq.get(name) || 0) + 1); }

for (const f of files) {
  const re = /\b[A-Za-z_][A-Za-z0-9_]*\b/g;
  let m;
  while ((m = re.exec(f.text)) !== null) bump(m[0]);
}

// 抽插值
const issues = [];
let total = 0;
for (const f of files) {
  // \( ... ) —— 只取最简单的"单个标识符"形式
  const re = /\\\(([A-Za-z_][A-Za-z0-9_]*)\)/g;
  let m;
  while ((m = re.exec(f.text)) !== null) {
    total++;
    const name = m[1];
    const line = f.text.slice(0, m.index).split('\n').length;
    const c = freq.get(name) || 0;
    if (c <= 1) issues.push(`${f.name}:${line}  \\(${name})  —— 这个名字在 src/ 里只出现 ${c} 次`);
  }
}

console.log(`扫描 ${files.length} 个文件，字符串插值（纯标识符形式）${total} 处`);

if (issues.length === 0) {
  console.log('✓ 所有插值引用的标识符都在别处出现过（不是拼写错误）');
  process.exit(0);
}

console.log('');
console.log(`⚠ ${issues.length} 处可疑：`);
issues.forEach(i => console.log('  ' + i));
console.log('');
console.log('（只在这里出现一次，多半是拼错；如果确实是别处定义的全局，请确认拼写）');
process.exit(1);
