// 错误信息翻译必须优先按错误码判断（第145轮）
//
// 背景：`ZLFriendlyError.text` 原来全靠 `localizedDescription` 做文本匹配
// （`lower.contains("timed out")` 等 9 条），但 `localizedDescription` 是**按系统语言本地化**的：
//   · 英文系统 → "The request timed out." → 匹配
//   · 中文系统 → "请求超时。"            → 不匹配 → 落兜底 → 用户看到"请求超时。（错误码 -1001）"
// 而使用者是中文系统 → **9 条映射全部失效**。
//
// 判据（两条）：
//   ① 函数里必须有错误码判断（`NSURLErrorDomain` 或 `URLError.Code`）
//   ② 错误码判断必须出现在**第一个文本匹配之前**（否则文本分支会先吃掉）
//
// **局限**：
// · 只查 `ZLFriendlyError` 这一个函数 —— 它是全项目唯一的错误翻译入口（第145轮全仓扫过）。
// · 判不了"错误码映射得全不全"（只保证"优先按码判断"这个结构）。
// · 判不了其他地方的 `localizedDescription` 用法 —— 那些都是"拼进提示/日志"，不做逻辑判断。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const FILE = path.join(SRC, 'ZLPolish.swift');
const problems = [];

let src = '';
try {
  src = fs.readFileSync(FILE, 'utf8');
} catch {
  console.log('✗ 找不到 ZLPolish.swift');
  process.exit(1);
}

// 取 ZLFriendlyError.text 的函数体（从 `static func text(` 到配对的 `}`）
const start = src.indexOf('static func text(_ error: Error) -> String {');
if (start < 0) {
  console.log('✗ 找不到 ZLFriendlyError.text');
  process.exit(1);
}
let depth = 0, end = -1, opened = false;
for (let i = src.indexOf('{', start); i < src.length; i++) {
  if (src[i] === '{') { depth++; opened = true; }
  else if (src[i] === '}') { depth--; if (opened && depth === 0) { end = i; break; } }
}
const body = src.slice(start, end + 1);
const bodyOffset = start;

// ① 有没有错误码判断
const hasDomainCheck = /NSURLErrorDomain|URLError\.Code/.test(body);
if (!hasDomainCheck) {
  problems.push('函数里没有任何错误码判断（NSURLErrorDomain / URLError.Code）—— 只靠本地化文本，中文系统上会全部失效');
}

// ② 错误码判断是否在第一个文本匹配之前
if (hasDomainCheck) {
  const firstTextMatch = body.search(/lower\.contains\(|raw\.contains\(/);
  const firstCodeCheck = body.search(/NSURLErrorDomain|URLError\.Code/);
  if (firstTextMatch >= 0 && firstCodeCheck > firstTextMatch) {
    const line = src.slice(0, bodyOffset + firstTextMatch).split('\n').length;
    problems.push(`错误码判断在第一个文本匹配之后（约第 ${line} 行）—— 文本分支会先吃掉，错误码永远走不到`);
  }
}

// 统计一下现状（给个可验证的数字，符合第136轮那条）
const urlCases = (body.match(/case \.[a-zA-Z]+/g) || []).length;
const textRules = (body.match(/lower\.contains\(/g) || []).length;
console.log(`ZLFriendlyError.text：${urlCases} 个错误码 case · ${textRules} 条文本匹配（作为补充）`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 错误翻译优先按错误码判断（与系统语言无关），文本匹配只作补充');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 个问题：`);
for (const p of problems) console.log(`  · ${p}`);
console.log('');
console.log('修法：用 `ns.domain == NSURLErrorDomain` + `URLError.Code(rawValue: ns.code)` 判断，');
console.log('      `localizedDescription` 的文本匹配只能放在后面作补充。');
process.exit(1);
