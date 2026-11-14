// 缩进体检：找出"在块内却贴着行首"这类排版问题
//
// 起因：ios-zl2 第116轮，一次替换把 `if X {` 放到了第 0 列（本该 16 空格），
// 而 swift-lint 报"括号配对正确"、**所有检查全绿** —— 机械检查不验排版。
// 第117轮把这条盲区补成一个可执行判据。
//
// 判据（判"小于期望"，判"大于"不报 —— `.modifier` 链、续行本来就更深）：
//   逐行跟踪大括号深度 → 行首 `}` 期望 4×(depth−1)，其余 4×depth
//
// **判据演进中修掉的三类误报**（都已排除，写在这里免得后人重踩）：
//   ① `case …` / `default:` / **`@unknown default:`** —— Swift 要求与 `switch` 同列
//   ② 行首 `]` / `)` 的收尾行 —— 数组与参数列表收尾，缩进本就与开头对齐
//   ③ **多行字符串 `"""` 内部的行** —— 那是文本内容，不是代码
//      （ZLUpdate.swift 里的崩溃报告模板有 7 行文本，曾全被误报）
//
// **局限**（不查什么）：
//   · **只判"小于期望"，缩进过大不报** —— 所以"该在 if 里却多缩进了一层、看起来像在另一块"看不见。
//   · **按 4 空格硬编码**。项目目前 0 行 tab 缩进（2026-11-08 核实），所以按字符数算成立；
//     **哪天有人用 2 空格或 tab，全部判据失效而它仍按 4 倍期望报**（会满屏误报，不会静默）。
//   · **多行字符串靠"跳过 99 行"的状态机**。字符串里再出现 `"""`（转义或嵌套）会让状态机错位；
//     而且**被跳过的那些行根本没有排版检查**（它们本来就该由人看）。
//   · **查不到"缩进合规但语义归错块"**：把一行放进错误的 `if` 里，缩进完全对，本检查看不出。
//     这类只能靠 `_check-dup-decl` 那种按块归属的判据，或人读。
//
// 注：本项目全部用空格缩进（实测 0 行 tab 缩进），所以直接按字符数算；若将来引入 tab，
// 这里要先展开 tab 再比较。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

function stripLine(line) {
  let out = '';
  let inStr = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (!inStr && c === '/' && line[i + 1] === '/') break;   // 行注释
    if (c === '"' && line[i - 1] !== '\\') inStr = !inStr;
    if (!inStr) out += c;
  }
  return out;
}

const problems = [];
let checked = 0;
let multilineSkips = 0;

for (const f of files) {
  const lines = fs.readFileSync(path.join(SRC, f), 'utf8').split(/\r?\n/);
  let depth = 0;
  let inMultiline = false;

  lines.forEach((raw, idx) => {
    const trimmedRaw = raw.trim();

    // ---- 多行字符串：`"""` 之间的内容一律不判 ----
    const tripleCount = (raw.match(/"""/g) || []).length;
    if (inMultiline) {
      multilineSkips++;
      if (tripleCount > 0) inMultiline = false;
      return;
    }
    if (tripleCount > 0) {
      if (tripleCount === 1) inMultiline = true;
      return;
    }

    if (trimmedRaw.length === 0) return;
    if (trimmedRaw.startsWith('//')) return;
    if (/^(case\s|default\s*:|@unknown\s+default\s*:)/.test(trimmedRaw)) return;
    if (/^[\]\)]/.test(trimmedRaw)) return;

    const code = stripLine(raw);
    const trimmed = code.trim();
    if (trimmed.length === 0) return;

    const indent = raw.length - raw.trimStart().length;
    const startsWithClose = trimmed.startsWith('}');
    const expected = startsWithClose ? 4 * Math.max(0, depth - 1) : 4 * depth;

    checked++;
    if (indent < expected) {
      problems.push({ file: f, line: idx + 1, indent, expected, text: trimmed.slice(0, 60) });
    }

    for (const ch of trimmed) {
      if (ch === '{') depth++;
      else if (ch === '}') depth = Math.max(0, depth - 1);
    }
  });
}

console.log(`检查了 ${checked} 行非空代码（跳过 ${multilineSkips} 行多行字符串内容）`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 没有"块内却贴行首"的缩进问题');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 行缩进小于所在块的期望值：`);
for (const p of problems.slice(0, 20)) {
  console.log(`  ${p.file}:${p.line}  实际 ${p.indent} 空格，期望 ≥${p.expected}`);
  console.log(`      ${p.text}`);
}
if (problems.length > 20) console.log(`  …还有 ${problems.length - 20} 处`);
console.log('');
console.log('修法：把这一行缩进到期望值。注意这类错**括号检查查不出来**，只能靠这里或人眼。');
process.exit(1);
