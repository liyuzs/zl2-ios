// 交付文档里不许手写"会变的精确数量"（第180轮）
//
// 起因：`从这里开始.md` 里写着「72 个自检脚本」（实际 61 个 _check / 106 个全部）、
//       「已知问题 8 条」（实际 10 条）—— 都是加东西时忘了改的。
// 第116轮就学过「会变的数字不手写」，但这份文档没落实。
//
// 判据：文档里出现「N 个脚本」「已知问题 N 条」「N 项检查」「N 个页面」这类
//       **精确数量 + 可增长名词** 的组合 → 报。
//
// **允许的**：
// · 体积（"约 93 MB"）—— 读者用它判断"下载有没有坏"，且写作"约"，有意义
// · 日期（"2026-11-08"）—— 事实记录
// · 步骤数（"三步" / "两条提醒"）—— 结构固定，不随代码增长
const fs = require('fs');
const path = require('path');

const DELIVERY = 'D:\\ZL2-iOS交付包';

// 会随代码增长、且**用来做承诺**的数量（读者会拿它判断"这套东西还完整吗"）
// 只查这三类 —— 第180轮第一次跑时误报了 3 处，都是下面"不查"的形态。
// **第200轮**：加「条已知限制」—— 我自己在交付包里写了「完整的 11 条已知限制见…」，
// 而 STATUS 里已经是 11 条但还会变。这个写法原来不在正则里，所以没被抓到。
//
// **第195轮**：除了「N 条已知问题」，还要认**反向语序**「已知问题 N 条」——
// 交付包里正是这么写的（「诚实版功能状态（含已知问题 8 条）」），而实际已经 11 条了。
// 原正则只认"数量在前"，漏掉了这一种。
const GROWING = /(?:(\d+)\s*(?:项检查|个自检脚本|条已知问题|个已知问题|条已知限制|个已知限制)|(?:项检查|个自检脚本|已知问题|已知限制)\s*(\d+)\s*条)/g;

// **局限**（不查什么）：
//   · 「115 个设置项」「1536 条文案」—— **源码规模统计**，读者用它了解体量，不是承诺
//   · 「补过 20 处差异」—— **历史记录**，数字是当时的事实
//   · 「1 个路由没有入口」—— **具体事实**（就是 `.room` 那一个），不是计数
//   · 「约 93 MB」—— 体积，读者用它判断下载完整性
//   · 只查 `.md`；HTML / txt 里的同类表述查不到

// 允许的结构性数量（步骤/提醒/路线之类）
const ALLOW = /三步|两步|四步|两条|三条|四条|三条安装路线|两处|三处/;

const files = fs.readdirSync(DELIVERY).filter(f => f.endsWith('.md'));
const hits = [];

for (const f of files) {
  const src = fs.readFileSync(path.join(DELIVERY, f), 'utf8');
  const lines = src.split(/\r?\n/);
  lines.forEach((line, i) => {
    if (ALLOW.test(line)) return;
    for (const m of line.matchAll(GROWING)) {
      hits.push({ file: f, line: i + 1, text: m[0], whole: line.trim().slice(0, 78) });
    }
  });
}

console.log(`扫了交付包里的 ${files.length} 个 .md`);
console.log(`手写"会变的精确数量"的地方：${hits.length} 处\n`);

if (hits.length === 0) {
  console.log('✓ 没有手写的会变数量（体积/日期/步骤数不在范围内）');
  process.exit(0);
}

console.log('⚠ 这些数量会随代码增长而过时：');
for (const h of hits) {
  console.log(`  ${h.file}:${h.line}  「${h.text}」`);
  console.log(`      ${h.whole}`);
}
console.log('');
console.log('修法：去掉数字，只说清"是什么"。例如：');
console.log('  「72 个自检脚本的分类」→「自检脚本的分类（哪个该跑、哪个已退役）」');
console.log('  「含已知问题 8 条」→「含已知问题」');
console.log('（体积可以保留"约 N MB"——读者用它判断下载完整性。）');
process.exit(1);
