// 白名单里的 .swift 文件名，在 src/ 里还存在吗（第207轮）
//
// 起因：`_check-fixed-widths.js` 的白名单里有一条 `'TerracottaScreen.swift'`，
// 而那个文件**第132轮就删了**。白名单指向一个不存在的文件 —— 不影响判据运行
// （它永远匹配不到），但**会误导下一个人**："为什么允许 TerracottaScreen？"
//
// 这和第206轮那条是同一件事的两面：
//   · 206 轮：**例外要有理由**
//   · 207 轮：**例外的对象要存在** —— 对象没了，理由也就变成了假话
//
// 判据：检查脚本里所有 `'Xxx.swift'` 字面量，对应的文件在 `src/` 里必须存在。
//
// **局限**：
// · 只查带 `.swift` 后缀的字符串字面量。白名单里写的是"类型名"或"键名"的查不到
//   （那需要另一套判据 —— 比如 `_check-orphan-keys.js` 管 UserDefaults 键）。
// · 只查 `config-guard/` 下的脚本，不查项目源码里的 `'Xxx.swift'` 字面量
//   （源码里可能是注释或文档里的引用）。
// · 如果某个脚本故意提到一个"计划中"的文件名，会误报 —— 那种情况加 `// stale-ok` 说明。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');
const WORK = __dirname;

const srcFiles = new Set(fs.readdirSync(SRC).filter(f => f.endsWith('.swift')));
const scripts = fs.readdirSync(WORK).filter(f => f.startsWith('_') && f.endsWith('.js'));

const stale = [];
let checked = 0;

for (const s of scripts) {
  if (s === '_check-stale-allows.js') continue;   // 跳过自己
  const text = fs.readFileSync(path.join(WORK, s), 'utf8');
  const lines = text.split(/\r?\n/);

  lines.forEach((line, i) => {
    // 跳过整行注释（第205轮那条：只剥整行，不做行内剥离）
    if (/^\s*\/\//.test(line)) return;
    for (const m of line.matchAll(/'([A-Za-z0-9_]+\.swift)'/g)) {
      checked++;
      if (!srcFiles.has(m[1])) {
        stale.push({ script: s, line: i + 1, name: m[1] });
      }
    }
  });
}

console.log(`扫了 ${scripts.length} 个脚本，${checked} 处 'Xxx.swift' 字面量`);
console.log(`指向的文件在 src/ 里不存在的：${stale.length} 处\n`);

// **零匹配守卫**（第196轮那条）
if (checked === 0) {
  console.log('⚠ 一处 .swift 字面量都没扫到 —— 判据可能失效了');
  process.exit(1);
}

if (stale.length === 0) {
  console.log('✓ 白名单里没有指向已删除文件的条目');
  process.exit(0);
}

console.log('⚠ 这些指的是已经不在 src/ 里的文件（条目过时了）：');
for (const x of stale) {
  console.log(`  ${x.script}:${x.line}  '${x.name}'`);
}
console.log('');
console.log('修法：删掉这个条目（文件都没了，白名单也就没意义了）。');
process.exit(1);
