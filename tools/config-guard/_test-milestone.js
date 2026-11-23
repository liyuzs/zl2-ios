// 契约测试：`ZLLaunchMilestone.greeting(for:)` 只在**少数几个特定数字**上返回非 nil。
//
// 为什么值得测：这个彩蛋的全部价值在于"稀有"。
//   · 如果哪天有人把 `case 10:` 改成 `case 10...20:` → 十次到二十次每次都弹
//   · 如果哪天有人把 `default: return nil` 改成 `default: return "欢迎回来"` → 每次启动都弹
//   这两种改动都**能通过编译、能通过全部静态检查**，但会把"惊喜"变成"骚扰"。
//
// 判据（每条都是不变量，不是"看起来对"）：
//   ① 至少 4 个里程碑（1 / 10 / 25 / 50 / 100 / 365 是设计值，允许增删但要 ≥4）
//   ② 数字严格递增且唯一
//   ③ 每个文案非空，且**互不重复**（重复 = 有人复制粘贴忘了改）
//   ④ `default:` 必须 `return nil`（否则每个数字都会弹）
//   ⑤ 不许出现区间写法（`case 10...20` / `case 10..<20`）
//   ⑥ 第一个必须是 1（"第一次踏入这个世界"是给朋友的第一句话，不能丢）
//
// **局限**：
// · 解析的是 Swift 源码文本，不是真的执行 Swift（本地没有编译器）——
//   所以它只能证明"文本符合形状"，不能证明"编译得过"。
// · 只认 `case N:` + 换行 + `return "..."` 这一种写法；
//   写成 `case let x where x == 10:` 或 `case 10: return Self.text` 会漏判（然后 ① 会把它算少）。
// · 不校验文案的**语义**是否合适（"第 365 次说过年"这种只能人看）。
// · 不检查调用方（HomeScreen）是否真的用了 `zl.milestoneSeen` 去重 —— 那是
//   `_check-orphan-keys.js`（键登记）和代码审阅的事。
// · 文案里出现数字不影响本测试（本项目 `_check-code-hardcoded-counts.js` 管那个）。

const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const failures = [];
const fail = (msg) => failures.push(msg);

const src = fs.readFileSync(path.join(SRC, 'ZLPolish.swift'), 'utf8');

// ── 截出 enum ZLLaunchMilestone { ... } 的整个体 ──────────────────────
const enumMatch = src.match(/enum\s+ZLLaunchMilestone\s*\{([\s\S]*?)\n\}/);
if (!enumMatch) {
  console.log('✗ 在 ZLPolish.swift 里找不到 `enum ZLLaunchMilestone`');
  console.log('  如果你把它改名或搬走了，请更新本测试的路径/正则。');
  process.exit(1);
}
const body = enumMatch[1];

// ── 抽 case：`case N:` 之后紧跟着 `return "..."` ──────────────────────
const cases = [];
for (const m of body.matchAll(/case\s+(\d+)\s*:\s*\n\s*return\s+"([^"]*)"/g)) {
  cases.push({ n: Number(m[1]), text: m[2] });
}

console.log(`=== 抽到 ${cases.length} 个里程碑 ===`);
for (const c of cases) console.log(`  第 ${String(c.n).padStart(3)} 次 → 「${c.text}」`);
console.log('');

// ── ① 至少 4 个 ───────────────────────────────────────────────────────
if (cases.length < 4) {
  fail(`里程碑只有 ${cases.length} 个（应 ≥ 4）—— 要么设计退化了，要么上面的正则没匹配到（写法变了？）`);
}

// ── ② 严格递增且唯一 ─────────────────────────────────────────────────
for (let i = 1; i < cases.length; i++) {
  if (cases[i].n <= cases[i - 1].n) {
    fail(`数字不是严格递增：第 ${i} 个是 ${cases[i].n}，前一个是 ${cases[i - 1].n}`);
  }
}
const seen = new Set();
for (const c of cases) {
  if (seen.has(c.n)) fail(`数字重复：${c.n}`);
  seen.add(c.n);
}

// ── ③ 文案非空且互不重复 ─────────────────────────────────────────────
const texts = new Map();
for (const c of cases) {
  if (!c.text.trim()) fail(`第 ${c.n} 次的文案是空的`);
  if (texts.has(c.text)) fail(`文案重复：「${c.text}」同时用在第 ${texts.get(c.text)} 次和第 ${c.n} 次`);
  else texts.set(c.text, c.n);
}

// ── ④ default 必须 return nil ────────────────────────────────────────
const defMatch = body.match(/default\s*:\s*\n\s*return\s+([^\n]+)/);
if (!defMatch) {
  fail('找不到 `default:` 分支 —— 枚举 case 必须穷尽，或 default 的写法变了');
} else if (!/^nil\s*;?$/.test(defMatch[1].trim())) {
  fail(`default 分支返回的是 \`${defMatch[1].trim()}\`，应该是 \`nil\` —— `
     + '否则**每一个**启动次数都会命中，彩蛋变成每次启动都弹');
}

// ── ⑤ 不许区间写法 ──────────────────────────────────────────────────
for (const m of body.matchAll(/case\s+(\d+)\s*\.\.\.?\s*(\d+)?/g)) {
  fail(`出现了区间写法 \`case ${m[1]}...${m[2] || ''}\` —— 里程碑必须是**离散的点**，不能是范围`);
}

// ── ⑥ 第一个必须是 1 ────────────────────────────────────────────────
if (cases.length > 0 && cases[0].n !== 1) {
  fail(`第一个里程碑是第 ${cases[0].n} 次，应该是 **1** —— "第一次踏入这个世界"是给朋友的第一句话`);
}

// ── 结果 ────────────────────────────────────────────────────────────
console.log('');
if (failures.length === 0) {
  console.log(`✓ ${cases.length} 个里程碑全部合规：递增、唯一、文案不重复、default 返回 nil、无区间写法、含第 1 次`);
  process.exit(0);
}

console.log(`✗ ${failures.length} 处不合规：`);
for (const f of failures) console.log('  · ' + f);
process.exit(1);
