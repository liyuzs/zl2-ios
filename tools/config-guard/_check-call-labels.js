// 参数标签对撞（编译前置检查）
//
// 起因：这个项目本地没有 Swift 编译器，而"调用时标��写错"是编译错误里最隐蔽的一种 ——
// 声明是 `requiredJavaVersion(_ metadata:)`，调用写成 `requiredJavaVersion(for: meta)`
// 一眼看不出来，但编译直接失败。我自己已经犯过两次。
//
// 做法：
//   ① 把每个文件压成单行（换行/缩进不影响标签，压平后正则才可靠）
//   ② 收集工程内类型的方法声明 → 名字 → 若干组「参数标签序列」（支持重载）
//   ③ 收集对这些类型的调用点，抽出实参标签序列
//   ④ 参数个数对不上（有默认值/尾随闭包）就跳过，只比对个数相同的
//
// **覆盖范围：工程内全部类型**（第120轮从"12 个白名单"扩到全部）。
// 起因：第119轮往 GameMenuScreen.listRow 里加 enabled: 时插错了位置（会编译失败），
// 而这条检查当时只盯 12 个类型，listRow 不在里面 —— 它报了"全部对得上"。
// 扩到全工程后比对了 289 个调用点，误报 0（前提是解析器先跳过字符串字面量）。
// 系统 API 仍不查 —— 那需要真正的类型系统。
//
// **局限**（查不到什么 —— 第121轮更新，别高估它）：
// ① **裸调用只查"实参里没有三元"的那部分**。第120轮试过全查，误报 9 → 加过滤后 94；
//    第121轮换策略：实参串里出现 `?`（三元 `a ? b : c`，其冒号在顶层、与标签冒号字面相同）
//    就跳过这个调用，其余照查 —— 实测 1657 处裸调用 **0 误报**，
//    且能精确抓到第119轮那个「enabled: 插到 options: 前面」（调用 _,key,enabled,options vs 声明 _,key,options,enabled）。
//    代价：含三元的调用不查（本项目里约 81 处）。
// ② 不查系统 API 与跨文件重载（同名方法在多个类型里时，只要有一个声明匹配就放过）。
//
// 所以：**这一层的价值是"静态调用的标签与顺序全对"**，不是"所有调用都验过"。
// 剩下的靠 swift-lint（括号）+ 人工回读改动的调用点。

const fs = require('fs');
const path = require('path');
const { SRC } = require('./_paths');
// 工程内全部类型（含 struct / enum / class / actor / extension 目标）。
// 不再维护白名单 —— 白名单总会漏掉新写的类型（第119轮就是这么漏的）。
let WATCH_TYPES = [];

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'))
  .map(f => ({ name: f, raw: fs.readFileSync(path.join(SRC, f), 'utf8') }));

const flat = files.map(f => ({ name: f.name, text: f.raw.replace(/\s+/g, ' ') }));

// 收集工程内所有类型名（在压平后的文本里扫，正则更可靠）
{
  const seen = new Set();
  for (const f of flat) {
    let m;
    const re = /\b(?:extension|enum|struct|class|actor)\s+([A-Za-z_]\w*)/g;
    while ((m = re.exec(f.text)) !== null) seen.add(m[1]);
  }
  WATCH_TYPES = [...seen];
}

// ---- 平衡括号取参数字符串 ----
function argsAt(s, openIdx) {
  // openIdx 指向 '('
  let depth = 0;
  for (let i = openIdx; i < s.length; i++) {
    const c = s[i];
    if (c === '(') depth++;
    else if (c === ')') {
      depth--;
      if (depth === 0) return s.slice(openIdx + 1, i);
    }
  }
  return null;
}

// ---- 从参数串抽取「外部标签」序列 ----
// `_ a: T` → '_'   `java a: T` → 'java'   `a: T` → 'a'
function splitTopLevel(args) {
  const parts = [];
  let depth = 0, cur = '';
  let inStr = false;
  for (let i = 0; i < args.length; i++) {
    const ch = args[i];
    // 字符串字面量里的逗号与括号都不算结构（第120轮）：
    // ZLClipboard.copy("\(s.address),label: ...") 的逗号曾把实参切错，产生假报。
    if (ch === '"' && args[i - 1] !== '\\') { inStr = !inStr; cur += ch; continue; }
    if (inStr) { cur += ch; continue; }
    if ('([{<'.includes(ch)) depth++;
    else if (')]}>'.includes(ch)) depth--;
    if (ch === ',' && depth === 0) { parts.push(cur); cur = ''; }
    else cur += ch;
  }
  parts.push(cur);
  return parts;
}

// 找顶层（不在 ()[]{}<> 里）的冒号。
// 关键：`meta ?? [:]` 里的冒号在方括号内，**不是**标签分隔符 ——
// 一开始用 indexOf(':') 就把它当标签了，产生假报。
function topLevelColon(s) {
  let depth = 0, inStr = false;
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (c === '"' && s[i - 1] !== '\\') { inStr = !inStr; continue; }
    if (inStr) continue;              // 字符串里的冒号不是标签分隔符
    if ('([{<'.includes(c)) depth++;
    else if (')]}>'.includes(c)) depth--;
    else if (c === ':' && depth === 0) return i;
  }
  return -1;
}

// mode: 'decl' 声明 / 'call' 调用。
// 关键区别：调用实参**没有冒号就是无标签**（那就是变量名/表达式，不是标签）。
function labelsOf(args, mode) {
  if (args === null) return null;
  const trimmed = args.trim();
  if (trimmed === '') return [];

  return splitTopLevel(trimmed).map(p => {
    const seg = p.trim();
    if (!seg) return null;
    const colon = topLevelColon(seg);
    if (colon < 0) {
      // 没有冒号：调用里是"无标签实参"，声明里说明这段解析失败
      return mode === 'call' ? '_' : null;
    }
    const head = seg.slice(0, colon).trim();
    const words = head.split(/\s+/).filter(w => w.length > 0);
    if (words.length === 0) return mode === 'call' ? '_' : null;
    if (words[0] === '_') return '_';
    // 调用里出现 `a: b` 时冒号前只有标签；声明里冒号前可能有两个词（外部名 内部名）
    return words[0];
  });
}

// ---- ① 收集声明 ----
const decls = new Map();   // "Type.name" → [ [labels...], ... ]
const declRe = new RegExp(`\\b(${WATCH_TYPES.join('|')})\\b[^{};]{0,200}?func\\s+(\\w+)\\s*\\(`, 'g');

// 一个文件里可能有多个类型（比如 ServerListScreen.swift 同时有
// ServerListScreen 和 MinecraftPing，两者都有 ping 方法）。
// 所以不能"把文件里所有 func 都归到文件里出现过的每个类型"——
// 那会让 `ping(_ s:)` 和 `ping(host:timeout:)` 混在一起，产生假报。
// 正确做法：按「最近的类型声明」归属。
for (const f of flat) {
  const marks = [];
  const typeRe = /\b(?:extension|enum|struct|class|actor)\s+([A-Za-z_]\w*)/g;
  let tm;
  while ((tm = typeRe.exec(f.text)) !== null) {
    marks.push({ idx: tm.index, type: tm[1] });
  }
  if (marks.length === 0) continue;

  const re = /\bfunc\s+(\w+)\s*\(/g;
  let m;
  while ((m = re.exec(f.text)) !== null) {
    // 找它前面最近的一个类型声明
    let owner = null;
    for (const mk of marks) {
      if (mk.idx < m.index) owner = mk.type; else break;
    }
    if (!owner || !WATCH_TYPES.includes(owner)) continue;

    const name = m[1];
    const open = f.text.indexOf('(', m.index);
    const args = argsAt(f.text, open);
    const labels = labelsOf(args, 'decl');
    if (labels === null || labels.includes(null)) continue;
    const key = `${owner}.${name}`;
    if (!decls.has(key)) decls.set(key, []);
    decls.get(key).push(labels.join(','));
  }
}
declRe.lastIndex = 0;

// ---- ② 收集调用 ----
const problems = [];
let callsChecked = 0;

for (const f of flat) {
  const callRe = new RegExp(`\\b(${WATCH_TYPES.join('|')})\\s*\\.\\s*(\\w+)\\s*\\(`, 'g');
  let m;
  while ((m = callRe.exec(f.text)) !== null) {
    const type = m[1], name = m[2];
    const key = `${type}.${name}`;
    if (!decls.has(key)) continue;                  // 不是本工程的方法，跳过

    const open = f.text.indexOf('(', m.index);
    const args = argsAt(f.text, open);
    const callLabels = labelsOf(args, 'call');
    if (callLabels === null || callLabels.includes(null)) continue;

    const candidates = decls.get(key);
    // 参数个数不同的（有默认值、尾随闭包）不比对
    const sameArity = candidates.filter(c => c.split(',').filter(x => x !== '').length === callLabels.length);
    if (sameArity.length === 0) continue;

    callsChecked++;
    const got = callLabels.join(',');
    if (!sameArity.includes(got)) {
      problems.push({
        file: f.name, type, name,
        call: got || '（无参数标签）',
        decl: sameArity.join(' | '),
      });
    }
  }
}

// ---- ③ 裸调用：同类型内部、不带类型前缀的调用（如 listRow(...)）----
// 第121轮补。**只跳过实参含 `?` 的**：三元 `a ? b : c` 的冒号在顶层，
// 与标签冒号字面相同，静态无法区分 —— 宁可漏，不误报（实测 0 误报 / 1657 处）。
let bareChecked = 0, bareSkipped = 0;

for (const f of flat) {
  const marks = [];
  let tm;
  const typeRe = /\b(?:extension|enum|struct|class|actor)\s+([A-Za-z_]\w*)/g;
  while ((tm = typeRe.exec(f.text)) !== null) marks.push({ idx: tm.index, type: tm[1] });
  if (marks.length === 0) continue;

  // 排除成员访问（前面是 `.`）与标识符内部，只留裸调用
  const re = /(?<![.\w])([a-zA-Z_]\w*)\s*\(/g;
  let m;
  while ((m = re.exec(f.text)) !== null) {
    const name = m[1];
    if (['if','for','while','switch','guard','return','func','init','some','await',
         'try','catch','case','throw','in'].includes(name)) continue;

    let owner = null;
    for (const mk of marks) { if (mk.idx < m.index) owner = mk.type; else break; }
    if (!owner) continue;

    const key = `${owner}.${name}`;
    if (!decls.has(key)) continue;

    const rawArgs = argsAt(f.text, f.text.indexOf('(', m.index));
    if (rawArgs === null) continue;
    if (/\?/.test(rawArgs)) { bareSkipped++; continue; }     // 含三元 → 跳过

    const callLabels = labelsOf(rawArgs, 'call');
    if (callLabels === null || callLabels.includes(null)) continue;

    const sameArity = decls.get(key).filter(c => c.split(',').filter(x => x !== '').length === callLabels.length);
    if (sameArity.length === 0) continue;

    bareChecked++;
    const got = callLabels.join(',');
    if (!sameArity.includes(got)) {
      problems.push({
        file: f.name, type: owner, name,
        call: got || '（无参数标签）',
        decl: sameArity.join(' | '),
        bare: true,
      });
    }
  }
}
console.log(`声明：${decls.size} 个方法 · 静态调用 ${callsChecked} 处 · 裸调用 ${bareChecked} 处（跳过含三元的 ${bareSkipped} 处）`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 参数标签全部对得上');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处标签对不上（会编译失败）：`);
for (const p of problems) {
  console.log(`\n  ${p.file}  ${p.type}.${p.name}(...)${p.bare ? '  [同类型内部调用]' : ''}`);
  console.log(`    调用用的是： ${p.call}`);
  console.log(`    声明要求：   ${p.decl}`);
}
console.log('');
console.log('修法：按声明的标签改调用（`_` 表示该参数无标签）。');
process.exit(1);
