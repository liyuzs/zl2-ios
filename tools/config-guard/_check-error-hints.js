// 面向用户的失败提示必须带"怎么办"
//
// **第101轮的自我纠错**：我一开始扫 `value:` 行，看到「缺少 mainClass」「一套都没找到」
// 就下了结论"只描述不指引"，还往 value 里塞了「→ 怎么办」——结果发现
// `ZLDiagItem` 本来就有一个 `advice` 字段（`/// 出问题时怎么办`），
// 两个界面（DiagnosticsScreen / LaunchScreen）都在渲染它，
// 预检那 9 条**全都已经写了 advice**。
//
// 所以判据改成盯既有设计：
//   1. 每个 `level: .fail` / `.warn` 的 ZLDiagItem，必须带非空 `advice:`
//   2. 只查两处直接怼到用户脸上的文件（预检卡片、诊断列表）
//
// 教训：**先看结构，再谈缺失** —— 别把"我没找到"当成"不存在"。

// **局限**
// · 只要求 `ZLPreflight` / `ZLDiagnostics` 里每条 `.fail` / `.warn` 的 `ZLDiagItem` 有非空 `advice:`。
// · **查不到"advice 写得有没有用"** —— 满足"非空"就算过，写"重试一下"这种废话它也通过。
// · **失效条件**：如果以后把诊断项改成别的结构（不再用 `ZLDiagItem`），它会对新结构完全失明。
//   （第137轮起：这种情况下会因"零匹配"直接报错，不再静默通过）
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const TARGETS = [
  { file: 'ZLPreflight.swift', why: '启动前预检卡片' },
  { file: 'ZLDiagnostics.swift', why: '环境诊断列表' },
];

const problems = [];
let diagCount = 0;      // 匹配到的 ZLDiagItem 总数
let leveled = 0;        // 其中带 fail/warn 的

for (const t of TARGETS) {
  const full = path.join(SRC, t.file);
  if (!fs.existsSync(full)) { problems.push(`${t.file} 不存在`); continue; }
  const src = fs.readFileSync(full, 'utf8');

  // 按 ZLDiagItem( ... ) 切成条目块，块内同时看 level 与 advice
  const re = /ZLDiagItem\(([\s\S]*?)\)\)?/g;
  let m;
  while ((m = re.exec(src)) !== null) {
    diagCount++;
    const block = m[1];
    const lv = block.match(/level:\s*\.(fail|warn)/);
    if (!lv) continue;
    leveled++;

    const advice = block.match(/advice:\s*(.+)/);
    const hasAdvice = advice && advice[1].trim() !== 'nil' && advice[1].trim() !== '""';
    if (!hasAdvice) {
      const title = (block.match(/title:\s*"([^"]*)"/) || [, '?'])[1];
      const lineNo = src.slice(0, m.index).split('\n').length;
      problems.push(`${t.file}:${lineNo} 「${title}」是 ${lv[1]}，但没有 advice（用户不知道怎么办）`);
    }
  }
}

console.log(`检查 ${TARGETS.length} 个文件：匹配到 ${diagCount} 条 ZLDiagItem，其中 ${leveled} 条带 fail/warn`);
console.log('');

// **零匹配即失败**：说明正则和代码结构对不上了，这时候"全都有 advice"是空真
if (diagCount === 0 || leveled === 0) {
  console.log('⚠ 一条 ZLDiagItem 都没匹配到 —— 判据可能已过时（结构改名/正则失配）');
  console.log('  这不是"没问题"，是"没看到东西"。请核对 ZLDiagItem 的写法是否变了。');
  process.exit(1);
}

if (problems.length === 0) {
  console.log('✓ 预检与诊断里每条 fail/warn 都带了 advice（"怎么办"）');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 条缺 advice：`);
for (const p of problems) console.log(`  · ${p}`);
console.log('');
console.log('修法：给该条加 `advice: "一句话说清用户该做什么"` —— 界面会自动在红字下方显示它。');
process.exit(1);
