// 原子写检查（数据完整性前置）
//
// 起因：ios-zl2 第64轮盘点 `write(to:)` 时发现 9 处写入**没有原子性**。
// 非原子写的意思是：写到一半 App 被杀（iOS 后台回收、用户强杀、崩溃），
// 磁盘上会留下**截断的文件**。对下面这些文件都是灾难：
//   · versions/<id>/<id>.json —— 版本配置坏了，这个版本再也启动不了（且不能自愈）
//   · launcher_profiles.json —— 存档式配置损坏
//   · controlmap/<布局>.json —— 控制布局变成非法 JSON，核心读它就崩
//   · 下载下来的 jar —— 变成半截 jar
//
// `.atomic` 的语义是"先写临时文件再 rename"，要么是旧内容、要么是完整新内容，
// 不存在"半截"状态。写用户可见/持久化文件时应该一律加上。
//
// 判据：`.write(to:` 语句附近（含跨行的参数）没有 `atomic` / `atomically` 就报。
// 临时目录/暂存目录里的写入可以不原子（本来就是要丢弃的），用路径关键字排除。

const fs = require('fs');
const path = require('path');
const { SRC } = require('./_paths');
// 这些路径关键字代表"临时/暂存"，不要求原子写
// 只放"临时/暂存路径"的线索词。**不要把测试用的探针名字放进来** ——
// 早期这里曾有 'probe'：某次注入测试为了避开误报加进去的，结果让这条检查
// 对任何名字含 probe 的真实代码视而不见（第104轮靠"注入后回读确认"才发现）。
const TEMP_HINTS = ['stage', 'tmp', 'temp', 'trash', 'temporaryDirectory'];

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const problems = [];
let checked = 0;

for (const name of files) {
  const text = fs.readFileSync(path.join(SRC, name), 'utf8');
  const lines = text.split('\n');

  lines.forEach((line, i) => {
    if (!line.includes('.write(to:')) return;
    checked++;

    // 取一个 3 行窗口，覆盖跨行调用（options 常常写在下一行）
    const window = [lines[i], lines[i + 1] || '', lines[i + 2] || ''].join(' ');

    // 已经原子
    if (/atomic/.test(window)) return;

    // 临时路径
    const lower = window.toLowerCase();
    if (TEMP_HINTS.some(h => lower.includes(h.toLowerCase()))) return;

    problems.push({
      file: name,
      line: i + 1,
      text: line.trim().slice(0, 100),
    });
  });
}

console.log(`检查了 ${checked} 处 write(to:)`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 写持久化文件的地方都用了原子写（临时/暂存目录除外）');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处非原子写（中途被杀会留下截断文件）：`);
for (const p of problems) {
  console.log(`\n  ${p.file}:${p.line}`);
  console.log(`    ${p.text}`);
}
console.log('');
console.log('修法：Data 加 `options: .atomic`；String 用 `atomically: true`。');
process.exit(1);
