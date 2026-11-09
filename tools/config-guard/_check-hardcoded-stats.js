// 界面文案里不许出现"系统内部规模"数字
//
// 起因：ios-zl2 第102轮读彩蛋文案时发现 `ZLSecretInfo.lines[1]` 写着
//   「这个启动器用了 55 个 Swift 文件」
// 而项目早就是 70 个了 —— **用户点 5 下版本号，会看到一句过时的话**。
//
// 这类数字特别危险：
//   · 写在 Swift 字符串字面量里，`_check-doc-stats` 只管文档、管不到代码
//   · 没有任何路径会去校验它（不像 README/STATUS 有检查）
//   · 用户看到时还会当成"作者说的准确信息"
//
// 判据：src 里的**字符串字面量**不许包含文件/构件数量类说法。
// 想告诉用户"这是什么"，用不会变的描述（技术栈、机制、能力），不要用计数。

const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

// 匹配："... N 个 Swift 文件 ..." / "... N 个文件 ..." / "... N 个 jar ..."
const PATTERNS = [
  { re: /"[^"]*\d+\s*个\s*Swift\s*文件[^"]*"/, what: '个 Swift 文件' },
  { re: /"[^"]*\d+\s*个\s*\.m\s*文件[^"]*"/, what: '个 .m 文件' },
  { re: /"[^"]*\d+\s*个\s*jar[^"]*"/, what: '个 jar' },
];

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const problems = [];

for (const f of files) {
  const lines = fs.readFileSync(path.join(SRC, f), 'utf8').split('\n');
  lines.forEach((line, i) => {
    const s = line.trim();
    if (s.startsWith('//')) return;                  // 注释可以写
    // NSLog / print 里写数字无所谓（那是日志，不是界面）
    if (/NSLog|print\(/.test(s)) return;
    for (const p of PATTERNS) {
      if (p.re.test(line)) {
        problems.push(`${f}:${i + 1} 界面文案里写死了「${p.what}」：${s.slice(0, 60)}`);
      }
    }
  });
}

console.log(`扫描 ${files.length} 个 Swift 文件的字符串字面量`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 界面文案里没有写死系统规模数字（这类数字一定会过时）');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处写死了会过时的数字：`);
for (const p of problems) console.log(`  · ${p}`);
console.log('');
console.log('修法：换成不会变的说法（技术栈 / 机制 / 能力），或干脆删掉那句。');
console.log('      要报规模就交给文档，那里有 _check-doc-stats 盯着。');
process.exit(1);
