// 失效文档必须标注（第240轮）
//
// 起因：第238轮给 `docs/` 里 6 篇旧文档加了顶部失效标注，第239轮又在索引里补了标记。
// 但那是**手工做的两处**，将来新增一篇"描述未实现功能"的文档时没人会记得标。
//
// 判据（对 `MUST_MARK` 里每个文件，两处都要有）：
//   ① 文档自己前 12 行含失效词（已废弃 / 已置灰 / 未实现 / 已被取代 / 没有实现 / 不可用）
//   ② `README-文档索引.md` 里指向它的那一行含 `⚠️`
//
// **局限**（不查什么）：
//   · **名单是手写的** —— 新增一篇"描述未实现功能"的文档时，**必须手动加进 `MUST_MARK`**，
//     否则这条检查看不见它。它守的是"已登记的不许退回去"，不是"发现新的失效文档"。
//   · **只判"有没有那个词"，判不了"标得对不对"** —— 写"已废弃"但实际情况是"已实现"，它也过。
//   · 索引里只匹配"文件名出现在某行"，**同一文件在索引里出现两处时只查第一处**。
//   · 不扫 `delivery` 里那些文档（它们不是 `docs/` 的旧技术说明）。
const fs = require('fs');
const path = require('path');

const { REPO } = require('./_paths');   // ← 别写死路径（第183-185轮踩过 3 次，这是第 4 次）
const DOCS = path.join(REPO, 'docs');
const INDEX = path.join(DOCS, 'README-文档索引.md');

const MUST_MARK = [
  '联机方案.md',
  'EasyTier集成设计.md',
  '版本隔离实现说明.md',
  '电脑端任务书.md',
  '电脑端指令.md',
  '装机测试指南.md',
];

const OBSOLETE = /已废弃|已置灰|未实现|已被取代|没有实现|不可用/;

let index;
try { index = fs.readFileSync(INDEX, 'utf8').split(/\r?\n/); }
catch { console.log('✗ 读不到 README-文档索引.md'); process.exit(1); }

const problems = [];
let checked = 0;

for (const name of MUST_MARK) {
  const p = path.join(DOCS, name);
  checked++;

  // ① 文档顶部
  let head = '';
  try { head = fs.readFileSync(p, 'utf8').split(/\r?\n/).slice(0, 12).join('\n'); }
  catch { problems.push(`${name} —— **读不到**（改名或删了？）`); continue; }
  if (!OBSOLETE.test(head)) problems.push(`${name} —— 文档**前 12 行没有失效标注**`);

  // ② 索引里指向它的那一行
  const line = index.find(l => l.includes(name));
  if (!line) problems.push(`${name} —— **索引里没有它**（是漏登记还是改名了？）`);
  else if (!line.includes('⚠️')) problems.push(`${name} —— **索引里那行没有 ⚠️ 标记**`);
}

console.log(`查了 ${checked} 篇"必须标注"的文档 ×（文档顶部 + 索引那行）`);
console.log(`没标注的：${problems.length} 处\n`);

if (checked === 0) { console.log('⚠ 名单是空的 —— 判据没在查任何东西'); process.exit(1); }

if (problems.length === 0) {
  console.log('✓ 每篇失效文档自己顶部有标注，索引里也带 ⚠️（读者不会误点进去）');
  process.exit(0);
}

console.log('⚠ 这些地方缺标注：');
for (const p of problems) console.log(`  · ${p}`);
console.log('');
console.log('修法：① 文档标题下加一段 `> ⚠️ **本文档…** —— 具体说清哪一步不成立、该看哪里`；');
console.log('      ② 索引里那一行的描述前加 `⚠️ **未实现/已置灰/已废弃**`。');
console.log('      新增一篇失效文档时，记得把文件名加进本脚本的 MUST_MARK。');
process.exit(1);
