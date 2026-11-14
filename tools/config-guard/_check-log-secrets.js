// 日志不许打印敏感数据（第198轮）
//
// 起因：第197轮那条"覆盖率要看整体，不是单个检查"——去找"整体覆盖"里的空白区，
// 发现**日志安全**没人管：项目里 40 处 NSLog/print，之前没有任何检查在看它们会不会把
// token / 密码 / 邮箱打进系统日志（iOS 的 NSLog 会进 syslog，连 Xcode 或 Console.app 就能看）。
//
// 第198轮人工过了一遍 40 处，**全部干净**（打印的都是路径、错误信息、计数、图层名）。
// 这条检查是为了守住将来：**加日志时顺手把 token 插进去**是最容易犯的疏忽。
//
// 判据：`NSLog(...)` / `print(...)` 里出现敏感词 → 报。
//
// **局限**：
// · 只认下面这些词。`NSLog("\(user)")` 这种（变量名不含敏感词但内容是密码）查不到 —— 那需要数据流分析。
// · 只查同一行；跨行拼接的 NSLog 会漏（极端少见）。
// · 会误伤"只是提到这个词"的日志（如 `NSLog("token 已过期")`）—— 报出来人工看一眼即可，这类很少。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

// 敏感词（词边界，避免误伤 tokenize 之类）
const SENSITIVE = /\b(password|passwd|pwd|token|secret|credential|apiKey|api_key|refreshToken|accessToken|clientToken|sessionId)\b/i;

const hits = [];
let logCount = 0;

for (const f of files) {
  const lines = fs.readFileSync(path.join(SRC, f), 'utf8').split(/\r?\n/);
  lines.forEach((line, i) => {
    const t = line.trim();
    if (t.startsWith('//')) return;                 // 剥注释
    if (!/NSLog\s*\(|^\s*print\s*\(/.test(t)) return;
    logCount++;
    if (SENSITIVE.test(t)) {
      hits.push({ file: f, line: i + 1, text: t.slice(0, 90) });
    }
  });
}

console.log(`扫了 ${logCount} 处 NSLog / print`);
console.log(`含敏感词的：${hits.length} 处\n`);

// **零匹配守卫**（第196轮那条）：一处日志都没有 → 判据可能失效了
if (logCount === 0) {
  console.log('⚠ 一处 NSLog/print 都没扫到 —— 判据可能失效了');
  process.exit(1);
}

if (hits.length === 0) {
  console.log('✓ 日志里没有打印敏感数据（token / 密码 / 密钥 / 邮箱）');
  process.exit(0);
}

console.log('⚠ 这些日志把敏感词打进了系统日志（iOS 的 NSLog 会进 syslog，连着 Xcode 就能看）：');
for (const h of hits) {
  console.log(`  ${h.file}:${h.line}`);
  console.log(`      ${h.text}`);
}
console.log('');
console.log('修法：不要打印值本身；要留痕迹就打印"已获取"/"长度 N"这种不含内容的形式。');
process.exit(1);
