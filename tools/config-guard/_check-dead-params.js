// 找"死参数"：private func 的某个参数在函数体里从来没出现（第205轮）
//
// 承第204轮：`onboardingStep` 的 `done` 参数传了但函数体从没提 ——
// 而 **Swift 不对未使用的函数参数报警**（只对未使用的变量报），所以它能存活很久。
// grep 函数名也看不出来（调用点都在用那个参数）。
//
// 范围：只查 `private func` / `fileprivate func` —— 它们的参数可以随便删，不影响外部调用者。
// （协议实现、override 的参数不能删，所以不查。）
//
// **局限**：
// · 只查 private/fileprivate func。`internal` 的公开函数不查（参数是契约）。
// · 用缩进 + 花括号配对找函数体；非常规缩进会漏。
// · 参数名在函数体里出现一次就算"用了" —— 哪怕是出现在注释里（注释已剥）或字符串里（没剥）。
// · 不查 `body` 这类计算属性、也不查 init。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

const problems = [];
let funcCount = 0, paramCount = 0;

for (const f of files) {
  const lines = fs.readFileSync(path.join(SRC, f), 'utf8').split(/\r?\n/);

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    if (/^\s*\/\//.test(raw)) continue;

    // 匹配 private/fileprivate func 定义（参数列表可能跨行，这里只看同一行的开头部分）
    // **第205轮**：原要求 `^\s+`（行首必须有缩进），漏掉了**顶层** private func（合法但少见）。改成 `^\s*`。
    const m = raw.match(/^\s*(?:private|fileprivate)\s+func\s+(\w+)\s*\(([^)]*)/);
    if (!m) continue;

    funcCount++;
    const funcName = m[1];
    const paramText = m[2];

    // 解析参数名：`_ n: Int` → n · `x: Int` → x · `onPick: (String) -> Void` → onPick
    const names = [];
    // 按逗号切，但忽略括号内的逗号
    let depth = 0, cur = '';
    const parts = [];
    for (const ch of paramText) {
      if (ch === '(' || ch === '[' || ch === '<') depth++;
      else if (ch === ')' || ch === ']' || ch === '>') depth--;
      if (ch === ',' && depth === 0) { parts.push(cur); cur = ''; } else cur += ch;
    }
    if (cur.trim()) parts.push(cur);

    for (const p of parts) {
      const head = p.split(':')[0].trim();
      if (!head) continue;
      const toks = head.split(/\s+/);
      const nm = toks[toks.length - 1];   // `_ n` → n
      if (!nm || !/^[a-zA-Z_]\w*$/.test(nm)) continue;
      if (nm === '_') continue;            // 纯占位
      names.push(nm);
    }
    if (names.length === 0) continue;

    // 找函数体：从这里往下，花括号配对
    let depth2 = 0, started = false, body = '';
    for (let j = i; j < lines.length; j++) {
      const L = lines[j];
      for (let k = 0; k < L.length; k++) {
        const ch = L[k];
        if (ch === '{') { depth2++; started = true; }
        else if (ch === '}') depth2--;
        // 只在函数体内部收集（跳过签名行本身的花括号之前）
        if (started && depth2 > 0) body += ch;
      }
      body += '\n';
      if (started && depth2 === 0) break;
      // 防御：最多看 200 行
      if (j - i > 200) break;
    }

    // 剥注释
    //
    // **第205轮修**：原来用 `body.replace(/\/\/.*$/gm, '')` 剥行内注释 ——
    // 结果 **把 `https://modrinth.com/project/\(h.id)` 里的 `//` 也当注释剥掉了**，
    // 于是 `h` 连同整段 URL 一起消失，`projectURL(_ h:)` 被误报成死参数。
    // 现在**只跳过整行注释**（行首是 //），不做行内剥离 —— 代价是行内注释里的参数名
    // 会被算作"用过"（可能漏报），但漏报比误报安全（第193轮那条）。
    const bodyNoComment = body.split('\n').filter(l => !/^\s*\/\//.test(l)).join('\n');

    for (const nm of names) {
      paramCount++;
      // 词边界匹配
      const re = new RegExp('\\b' + nm + '\\b');
      if (!re.test(bodyNoComment)) {
        problems.push({ file: f, line: i + 1, func: funcName, param: nm });
      }
    }
  }
}

console.log(`扫了 ${funcCount} 个 private/fileprivate func，${paramCount} 个参数`);
console.log(`函数体里从没用到的参数：${problems.length} 个\n`);

// **零匹配守卫**（第196轮那条）
if (funcCount === 0 || paramCount === 0) {
  console.log('⚠ 一个 private func / 参数都没扫到 —— 判据可能失效了');
  process.exit(1);
}

if (problems.length === 0) {
  console.log('✓ 没有死参数（每个 private func 的参数都在函数体里出现过）');
  process.exit(0);
}

console.log('⚠ 这些参数传进来了，但函数体里一次都没出现（Swift 不会警告）：');
for (const p of problems) {
  console.log(`  ${p.file}:${p.line}  ${p.func}(… ${p.param} …)`);
}
console.log('');
console.log('修法：删掉那个参数 + 同步所有调用点；或者说明它为什么必须留着。');
process.exit(1);
