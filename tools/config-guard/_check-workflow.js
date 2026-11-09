// 极简 YAML 结构校验：专门针对 GitHub Actions workflow 的 block scalar 缩进。
// 不追求完整 YAML 规范，只要能抓出「步骤缩进错、run 内容被截断、块标量丢失」这几类致命错。
const fs = require('fs');
const nodePath = require('path');
const PATHS = require('./_paths');
const wfPath = process.argv[2] || nodePath.join(PATHS.REPO, '.github/workflows/build.yml');
const raw = fs.readFileSync(wfPath, 'utf8');
const lines = raw.split(/\r?\n/);

let fail = 0;
const problems = [];
function problem(msg) { problems.push(msg); fail++; }

// 1) 顶层必须出现 steps: 且每个 - name: 在 jobs.<id>.steps 下
const stepLines = [];
lines.forEach((l, i) => {
  const m = l.match(/^(\s*)- name:\s*(.+)$/);
  if (m) stepLines.push({ indent: m[1].length, name: m[2].trim(), line: i + 1 });
});

if (stepLines.length === 0) problem('没有找到任何 - name: 步骤');

// 2) 所有步骤缩进必须一致
const indents = new Set(stepLines.map(s => s.indent));
if (indents.size !== 1) {
  problem(`步骤缩进不一致：${[...indents].join(', ')}（会导致 YAML 结构错乱）`);
}

// 3) block scalar（run: |）后面的内容必须比 run: 更深
stepLines.forEach((s, idx) => {
  // 找这个步骤块的范围
  const start = s.line - 1;
  const end = idx + 1 < stepLines.length ? stepLines[idx + 1].line - 1 : lines.length;
  const block = lines.slice(start, end);
  const runIdx = block.findIndex(l => /^\s*run:\s*\|/.test(l));
  if (runIdx < 0) return;
  const runIndent = block[runIdx].match(/^(\s*)/)[1].length;
  // run 内容从下一行开始
  let contentLines = 0;
  for (let i = runIdx + 1; i < block.length; i++) {
    const l = block[i];
    if (l.trim() === '') { contentLines++; continue; }
    const ind = l.match(/^(\s*)/)[1].length;
    if (ind <= runIndent) break;   // 回到同级 = 块结束
    contentLines++;
  }
  if (contentLines === 0) problem(`步骤「${s.name}」的 run: | 后面没有内容`);
});

// 4) 针对 Inject version 的专项检查：printf 三行续行必须都在
const iv = stepLines.find(s => s.name === 'Inject version');
if (!iv) {
  problem('没有找到 Inject version 步骤');
} else {
  const start = iv.line - 1;
  const idx = stepLines.indexOf(iv);
  const end = idx + 1 < stepLines.length ? stepLines[idx + 1].line - 1 : lines.length;
  const body = lines.slice(start, end).join('\n');
  const checks = [
    ['BUILD=', '缺少 BUILD 变量'],
    ['VER="1.0.${BUILD}"', '缺少 VER 变量'],
    ['printf', '缺少 printf'],
    ['MARKETING_VERSION', '缺少 MARKETING_VERSION 替换'],
    ['CURRENT_PROJECT_VERSION', '缺少 CURRENT_PROJECT_VERSION 替换'],
    ['sed -i -f', '缺少 sed -f 执行'],
    ['exit 1', '缺少失败断言'],
  ];
  checks.forEach(([needle, msg]) => { if (!body.includes(needle)) problem(msg); });
  // 绝对不能残留 heredoc 结束符被缩进的问题
  if (/^\s+SEDEOF\s*$/m.test(body)) problem('heredoc 结束符被缩进（POSIX shell 无法识别）');
  // printf 的三行续行：两个反斜杠续行
  const contCount = (body.match(/\\\s*$/gm) || []).length;
  if (contCount < 2) problem(`printf 续行不足（找到 ${contCount} 个，至少 2 个）`);
}

// 5) 检查是否有 tab 混入（YAML 禁止 tab 缩进）
lines.forEach((l, i) => {
  if (/^\t/.test(l)) problem(`第 ${i + 1} 行用 tab 缩进`);
});

if (fail === 0) {
  console.log(`✓ workflow 结构校验通过（${stepLines.length} 个步骤）`);
  stepLines.forEach(s => console.log(`   - ${s.name}`));
} else {
  console.log('✗ 发现问题：');
  problems.forEach(p => console.log('   - ' + p));
}
process.exit(fail === 0 ? 0 : 1);
