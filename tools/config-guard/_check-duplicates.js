// 重复声明检查（编译前置第五层）
//
// 编译错误里另一类常见的是"无效的重复声明"：
//   两个文件都写了 `struct ZLTheme { ... }` → Invalid redeclaration of 'ZLTheme'
// 括号检查、导入检查、拼写检查、标签检查都发现不了它。
//
// 关键难点：**同名不代表重复**。最常见的干扰是 `CodingKeys`
// （每个 Codable 类型里都有自己的 `CodingKeys`）和短名字的嵌套枚举
// （比如 `GuideManager.Kind` 和 `ZLSettingRow.Kind`）。
// 所以判据必须是：**只查花括号深度为 0 的（顶层）类型声明**。
//
// 实现：先把注释和字符串字面量抹掉（否则里面的花括号会算错深度），
// 再逐字符走，深度 0 处的 `struct/class/enum/actor/protocol Name` 才算顶层。
//
// **局限**（不查什么）：
//   · **只查花括号深度 0 的顶层声明**。嵌套类型重名**不在范围**（两个不同外层里各有 `Kind` 是合法的）。
//   · **只查 `struct/class/enum/actor/protocol`**：`typealias`、`extension`（合法可重复）、
//     `func`（允许重载）、`var`/`let`（同一类型内的归 `_check-dup-decl`）都不查。
//   · **`private` 同名是合法的** —— Swift 里两个文件各自 `private struct Foo` 不冲突，
//     而本检查按"整个 src 的顶层名"算，**会误报**。目前项目里没出现，但它是真风险。
//   · **"抹掉注释和字符串"这步失效的话，深度全错** → 报出来的东西可能完全是假的。
//     所以第196轮补的分母（"判据实际识别了多少个类型块"）是这条检查的命门，别删。

const fs = require('fs');
const path = require('path');
const { SRC } = require('./_paths');
// 抹掉注释与字符串，保留长度（这样索引对得上，报错行号才准）
function stripNoise(s) {
  let out = '';
  let i = 0;
  const n = s.length;
  while (i < n) {
    const c = s[i];
    const d = s[i + 1];
    if (c === '/' && d === '/') {
      while (i < n && s[i] !== '\n') { out += ' '; i++; }
    } else if (c === '/' && d === '*') {
      out += '  '; i += 2;
      while (i < n && !(s[i] === '*' && s[i + 1] === '/')) {
        out += (s[i] === '\n' ? '\n' : ' ');
        i++;
      }
      if (i < n) { out += '  '; i += 2; }
    } else if (c === '"') {
      // 简单处理：普通字符串 / 多行字符串都按"到下一个未转义引号"算
      const triple = s.startsWith('"""', i);
      const quote = triple ? '"""' : '"';
      out += quote; i += quote.length;
      while (i < n) {
        if (s[i] === '\\') { out += '  '; i += 2; continue; }
        if (s.startsWith(quote, i)) { out += quote; i += quote.length; break; }
        out += (s[i] === '\n' ? '\n' : ' ');
        i++;
      }
    } else {
      out += c; i++;
    }
  }
  return out;
}

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

const topLevel = new Map();   // Name → [{ file, line }]
let considered = 0;

for (const name of files) {
  const raw = fs.readFileSync(path.join(SRC, name), 'utf8');
  const clean = stripNoise(raw);

  let depth = 0;
  for (let i = 0; i < clean.length; i++) {
    const c = clean[i];
    if (c === '{') { depth++; continue; }
    if (c === '}') { depth = Math.max(0, depth - 1); continue; }
    if (depth !== 0) continue;

    // 只在深度 0 处找类型声明关键字
    if (c === 's' || c === 'c' || c === 'e' || c === 'a' || c === 'p') {
      const rest = clean.slice(i);
      const m = rest.match(/^(?:public|internal|private|fileprivate|final|open|@\w+\s+)*?(struct|class|enum|actor|protocol)\s+([A-Za-z_]\w*)/);
      if (m) {
        considered++;
        const line = clean.slice(0, i).split('\n').length;
        if (!topLevel.has(m[2])) topLevel.set(m[2], []);
        topLevel.get(m[2]).push({ file: name, line });
        i += m[0].length - 1;
      }
    }
  }
}

const dups = [...topLevel.entries()].filter(([, v]) => v.length > 1);

console.log(`扫描 ${files.length} 个文件，顶层类型声明 ${considered} 个（唯一名 ${topLevel.size} 个）`);
console.log('');

if (dups.length === 0) {
  console.log('✓ 没有顶层同名类型（嵌套的 CodingKeys / Kind 之类不误报）');
  process.exit(0);
}

console.log(`⚠ ${dups.length} 个顶层类型被重复声明（Invalid redeclaration）：`);
for (const [name, list] of dups) {
  console.log(`\n  ${name}`);
  for (const l of list) console.log(`    ${l.file}:${l.line}`);
}
console.log('');
console.log('修法：合并成一个，或者给其中一个改名。');
process.exit(1);
