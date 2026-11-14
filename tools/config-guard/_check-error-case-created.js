// 错误枚举的 case 必须真的能被抛出（第175轮）
//
// 第174轮发现 `MSAuthError.ipBlocked`/`.rateLimited` 定义了却没人用；
// 第175轮推广到全部 12 个错误枚举，又查出 `ZLLoaderInstallerError.mergeFailed`/`.libraryFailed`
// 从未被抛出（且 `.libraryFailed` 的文案会骗人 —— 实际是收集后报告，不抛错）。
//
// 判据：每个 `enum XxxError` 的每个 case，在整个项目里必须有**创建点**：
//   · `throw .c` / `throw Type.c`
//   · `= Type.c` / `= .c`（赋值给 lastError 之类）
//   · `return .c` / `: .c` / `, .c`
//
// **豁免**：case 附近（前后 6 行）写着"未实现/不会抛出/当前没有/没解析"之类注释的，
// 视为**已明确标注的欠账**，不报 —— 因为这些是有意保留的（如 MSAuthError 的 4 个 Xbox case：
// 文案备好了，但当前没解析 Xbox 错误码）。要求和代码一起提交说明为什么留着。
//
// **局限**：
// · 通过静态工厂间接创建的 case（`Type.from(json)` 里 throw .c）—— 那种 throw 在同一文件，
//   本检查能看到；但若工厂在别的模块把它当值传递，可能看不到。
// · 同名 case 在不同枚举间会混淆（只能按"任一处被创建过"宽松判定）。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const allSrc = files.map(f => fs.readFileSync(path.join(SRC, f), 'utf8')).join('\n');
// 判"创建点"时剥掉注释（注释里的名字不算真的创建）
const codeOnly = allSrc.split(/\r?\n/)
  .filter(l => !l.trim().startsWith('//') && !l.trim().startsWith('///'))
  .join('\n');

// 明确标注的豁免关键词
const ACK = /未实现|不会(被)?抛出|当前没有|没解析|预留|文案备好/;

let total = 0, dead = 0;
const report = [];

for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');
  const lines = src.split(/\r?\n/);

  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/enum\s+(\w+)\s*:\s*[^{]*Error[^{]*\{/);
    if (!m) continue;
    const enumName = m[1];

    let depth = 0, body = [];
    for (let j = i; j < lines.length; j++) {
      for (const ch of lines[j]) { if (ch === '{') depth++; else if (ch === '}') depth--; }
      body.push({ text: lines[j], idx: j });
      if (depth === 0 && j > i) break;
    }

    for (const { text, idx } of body) {
      const cm = text.match(/^\s*case\s+([a-zA-Z_]\w*)/);
      if (!cm) continue;
      const c = cm[1];
      total++;

      const pats = [
        new RegExp(`throw\\s+\\.${c}\\b`),
        new RegExp(`throw\\s+${enumName}\\.${c}\\b`),
        new RegExp(`=\\s*\\.${c}\\b`),
        new RegExp(`=\\s*${enumName}\\.${c}\\b`),
        new RegExp(`return\\s+\\.${c}\\b`),
        // **不要加 `[:,(]\s*\.c`** —— 它会匹配 `case .c:`（switch 模式匹配 = 消费，不是创建），
        // 导致所有带 `case .c:` 的 case 都算"被创建过"，注入验证通不过（第175轮实测踩到）。
        new RegExp(`\\?\\s*\\.${c}\\b`),
      ];
      if (pats.some(re => re.test(codeOnly))) continue;

      // 豁免：**只查本行**的行尾标注。
      // 原来查"前后 6 行"→ 相邻 case 的标注会互相覆盖（删掉 xboxTimeLimit 的标注后，
      // 上一行 xboxTerms 的「// 未实现：同上」还在范围里 → 注入验证通不过，第175轮实测踩到）。
      const nearby = lines[idx];
      if (ACK.test(nearby)) continue;

      dead++;
      report.push({ file: f, line: idx + 1, enumName, caseName: c });
    }
  }
}

console.log(`检查了 ${total} 个错误 case`);
console.log(`从未被创建、也没标注说明的：${dead} 个\n`);

if (dead === 0) {
  console.log('✓ 每个错误 case 要么能被抛出，要么有明确标注说明为什么留着');
  process.exit(0);
}

console.log('⚠ 这些 case 定义了却没有任何创建点（死分支）：');
for (const r of report) console.log(`  ${r.file}:${r.line}  ${r.enumName}.${r.caseName}`);
console.log('');
console.log('两种处理：');
console.log('  · 该抛没抛 → 补抛出点（很可能意味着某条失败路径静默了）');
console.log('  · 确实不用了 → 删掉；若是"文案备好但没实现"，保留并在 case 旁写清原因（本检查会豁免）');
process.exit(1);
