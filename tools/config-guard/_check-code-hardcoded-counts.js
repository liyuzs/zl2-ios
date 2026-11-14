// 代码里的用户可见文案含"硬编码数量"（第187轮）
//
// 第180轮那条"会变的数字不手写"当时只做了**文档**检查（`_check-doc-hardcoded-counts`）。
// 但代码里的文案同样会腐烂：现在 `DownloadScreen` 写着「下面是内置的 **7 个**常用版本」——
// 将来增删内置版本，这句话就错了。
//
// 判据：用户可见字符串里出现「数字 + 量词」（个/条/项/种/套/处/次/行），
//      且**不是插值**（没写成 `\(count)`）→ 报。
//
// **局限**：
// · 只查 Text / Label / Button / title / detail / placeholder / advice / value 这几种字面量。
//   别的途径显示的文案（Alert 的 message 传字符串变量、ZLStrings 的表）查不到。
// · 判不了"这个数字是内容数量（会变）还是设计参数（如分页大小）"—— 两种都会报，要人工分。
// · 只认 `数字 + 个/条/项/种/套/处/行`。「两天」「三处」这类中文数字不查。
//
// **豁免**：
// · 插值形式 `\(xxx)` —— 那是动态的 ✓
// · 「第一次」「第7轮」「1.20.1」这类不是计数的
// · 「一个」「两个」这种量词前是中文数字（较少随代码变）
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

// 用户可见字符串的提取（同 dump-strings 的口径）
const RE = /(?:Text|Label|Button|title|detail|placeholder|advice|value)\s*\(\s*"([^"]{4,})"/g;

// 数字 + 量词，且数字不是插值
const COUNT = /(\d+)\s*(个|条|项|种|套|处|行)/;

// 豁免：这些不是"会随代码增长的计数"
const ALLOW = [
  /第\s*\d+\s*轮/,       // 轮次
  /\d+\.\d+/,            // 版本号
  /\d+\s*个\s*像素|px/i,  // 尺寸
  /^\d+$/,               // 纯数字
];

const hits = [];

for (const f of files) {
  const lines = fs.readFileSync(path.join(SRC, f), 'utf8').split(/\r?\n/);
  lines.forEach((line, i) => {
    if (line.trim().startsWith('//')) return;
    for (const m of line.matchAll(RE)) {
      const text = m[1];
      // **把插值挖掉，只查剩下的字面量部分**（第187轮修正）：
      // 原来"整串含 \( 就跳过"，结果 `"清单获取失败：\(e)\n下面是内置的 7 个常用版本"`
      // 整串被跳过 —— 但那个 "7 个" 明明是写死的。
      const literalPart = text.replace(/\\\([^)]*\)/g, '');
      const cm = literalPart.match(COUNT);
      if (!cm) continue;
      if (ALLOW.some(re => re.test(text))) continue;
      hits.push({ file: f, line: i + 1, text: text.slice(0, 78), count: cm[0] });
    }
  });
}

console.log(`用户可见文案里"硬编码数量"：${hits.length} 处\n`);

if (hits.length === 0) {
  console.log('✓ 没有硬编码在文案里的会变数量');
  process.exit(0);
}

console.log('⚠ 这些文案写死了数量（将来增删内容就会过时）：');
for (const h of hits) {
  console.log(`  ${h.file}:${h.line}  「${h.count}」`);
  console.log(`      ${h.text}`);
}
console.log('');
console.log('修法：改成插值，如「内置的 \\(versions.count) 个常用版本」。');
process.exit(1);
