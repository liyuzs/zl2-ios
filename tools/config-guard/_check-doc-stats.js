// 文档规模数字 与 仓库实际 的契约
//
// 起因：README.md 和 STATUS.md 里写着「70 个 Swift / 33,202 行」，
// 但加了 ZLPreflight.swift 之后就变成 71 个 / 33,635 行了 —— 没人会记得同步。
// 这类数字每次改动都会漂，靠人工维护必错。
//
// 判据（刻意收窄，避免噪音）：
//   · 只校验「当前状态」那几行 —— 认 代码规模 / 代码： / 界面代码为原创重写 这三个标记
//   · 只校验**文件数**（`N 个 Swift`）
//   · 行数不校验：精确行数是假精度，改一行代码就变，文档里已改成「约 N 万行」
//   · 历史里程碑那类行（`| 10-31 | 项目启动，8 个 Swift 文件 |`）不匹配标记，自然跳过
//
// 为什么只查文件数：文件数是「项目规模」的有效信息，而且变化慢；
// 行数是"看起来很精确其实没意义"的典型，任何一次编辑都会让它变成谎话。

const PATHS = require('./_paths');
const fs = require('fs');
const path = require('path');

const ROOT = PATHS.REPO;
const SRC = path.join(ROOT, 'src');

// ---- 实际值 ----
const swiftFiles = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const actualSwift = swiftFiles.length;

// 核心 .m：排除 build（本地产物）与 external（第三方源码）
function walk(dir, ext, skip) {
  const out = [];
  const stack = [dir];
  while (stack.length) {
    const cur = stack.pop();
    let entries;
    try { entries = fs.readdirSync(cur, { withFileTypes: true }); } catch { continue; }
    for (const e of entries) {
      const full = path.join(cur, e.name);
      if (e.isDirectory()) {
        if (skip.includes(e.name)) continue;
        stack.push(full);
      } else if (e.name.endsWith(ext)) {
        out.push(full);
      }
    }
  }
  return out;
}
const actualM = walk(path.join(ROOT, 'core'), '.m', ['build', 'external', '.git']).length;
const jars = walk(path.join(ROOT, 'core', 'resources'), '.jar', ['.git']);
const actualDocs = fs.readdirSync(path.join(ROOT, 'docs')).filter(f => f.endsWith('.md')).length;
const actualScripts = (() => {
  try {
    return fs.readdirSync('C:\\Users\\21793\\.dsh\\config-guard')
      .filter(f => f.endsWith('.js') || f.endsWith('.ps1')).length;
  } catch { return -1; }
})();const actualJar = jars.length;

// ---- 文档里的当前状态行 ----
const MARKERS = ['代码规模', '代码：', '界面代码为原创重写', '文档：', '自动化检查', '分组导航'];
const DOCS = ['README.md', 'STATUS.md'];
// **第208轮**：把 `HANDOFF-*.md`（交接文档）也纳入。
// 用通配是因为文件名带日期（`HANDOFF-20261108.md`），将来交接时会换名。
//
// **注意两个门槛，别误以为"加进来就管住了"**：
//   ① 文件要在 `DOCS` 里
//   ② **行要含 `MARKERS` 里某个词**（见下面 L94 的过滤）
// HANDOFF 里那处「### Swift 侧（70 个文件）」**标题行不含 MARKERS** ——
// 所以它**从来没被这条检查管过**，是第208轮人工发现并修掉的。
// 加进来是为了：将来 HANDOFF 里如果出现「代码规模：…」这种行，会被管住。
try {
  const handoffs = fs.readdirSync(ROOT).filter(f => /^HANDOFF-.*\.md$/.test(f));
  for (const h of handoffs) DOCS.push(h);
} catch { /* 读不到就跳过，下面的"名单存在性"会管 */ }

const problems = [];
let checked = 0;
const missingDocs = [];   // DOCS 里读不到的文件（改名/删了）—— 读不到就等于没查

for (const doc of DOCS) {
  const full = path.join(ROOT, doc);
  let text;
  let text2;
  try { text2 = fs.readFileSync(full, 'utf8'); } catch { missingDocs.push(doc); continue; }
  text = text2;

  // 一行里可能同时有三个数字，逐个比对
  const CLAIMS = [
    { name: 'Swift 文件', re: /(\d+)\s*个\s*Swift/, actual: actualSwift },
  // **第208轮**：还有一种写法是「Swift 侧（70 个文件）」—— 数量在括号里、单位是"个文件"，
  // 原来的 `N 个 Swift` 匹配不到它，所以 HANDOFF 里那处过期了很久没人发现。
  { name: 'Swift 侧文件数', re: /Swift\s*侧\s*[（(]\s*(\d+)\s*个文件/, actual: actualSwift },
    { name: '核心 .m',   re: /(\d+)\s*个\s*`?\.m`?/, actual: actualM },
    { name: 'jar',       re: /(\d+)\s*个\s*jar/, actual: actualJar },
    // 第94轮补：文档篇数（README 曾写 24 篇、STATUS 曾写 28 篇，实际 30 篇）
    { name: 'docs 篇数', re: /`docs\/`\s*(\d+)\s*篇/, actual: actualDocs },
    // 第94轮补：脚本数（两份文档都曾写 25 个，实际 67 个）
    { name: '脚本数', re: /(\d+)\s*个脚本/, actual: actualScripts },
  ];

  text.split('\n').forEach((line, i) => {
    if (!MARKERS.some(m => line.includes(m))) return;
    for (const c of CLAIMS) {
      const m = line.match(c.re);
      if (!m) continue;
      checked++;
      const claimed = parseInt(m[1], 10);
      if (claimed !== c.actual) {
        problems.push({ doc, line: i + 1, what: c.name, claimed, actual: c.actual, text: line.trim() });
      }
    }
  });
}

console.log(`实际：${actualSwift} 个 Swift / ${actualM} 个核心 .m / ${actualJar} 个 jar`);
console.log(`检查了 ${checked} 处「当前状态」里的规模数字`);
console.log('');

// 名单存在性：DOCS 里的文件读不到，这条检查的主要对象就没了
if (missingDocs.length > 0) {
  console.log('⚠ 这些文档读不到（改名或删了）：' + missingDocs.join('、'));
  console.log('  它们是这条检查的主要对象，读不到就等于没查。请更新 DOCS 名单。');
  process.exit(1);
}
if (problems.length === 0) {
  console.log('✓ README / STATUS 里的规模数字与实际一致');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处过时：`);
for (const p of problems) {
  console.log(`\n  ${p.doc}:${p.line}  ${p.what} 写着 ${p.claimed}，实际 ${p.actual}`);
  console.log(`    ${p.text}`);
}
console.log('');
console.log('修法：把数字改成实际值。（行数/体积这类会频繁变化的，用约数或干脆不写）');
process.exit(1);
