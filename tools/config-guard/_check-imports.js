// 框架导入检查 —— 没有编译器时的"编译前置"防线
//
// 为什么需要：这个项目本地**没有 Swift/Xcode 编译器**，任何代码改动都无法验证
// 能否编译。而"用了某框架的符号但没 import 那个框架"是最常见、也最容易漏的
// 编译错误之一 —— 括号检查（swift-lint）查不出，人眼也容易忽略。
//
// 判据：按符号 → 框架的映射检查。命中符号却没导入对应框架就报错。
// 只收录"确定属于某个框架、且本项目实际用到"的符号，避免误报。
//
// **局限**（不查什么）：
//   · **映射表是手写的** —— 新用到一个框架的符号时，如果没往映射里加，这条检查看不见它。
//     （所以它防的是"常见符号的常见疏漏"，不是"所有漏 import"。）
//   · **只查"用了没 import"**，不查"import 了没用"（那只是警告，不影响编译）。
//   · **间接依赖查不到**：你用的类型来自 A 框架，而 A 自己依赖 B —— 那种情况下 B 不用你 import，
//     但如果你直接用了 B 的符号，本检查只在 B 在映射表里时才抓得到。
//   · 同名符号在多个框架里都有时（如 `Color`），映射只能挑一个 —— 挑错了会误报，所以映射表刻意保守。

const fs = require('fs');
const path = require('path');
const { SRC } = require('./_paths');
// 符号正则 → 必须导入的框架
const RULES = [
  {
    framework: 'UIKit',
    // UIKit 类型。注意 UIImage 有可能通过 PhotosUI 间接可见，但显式导入零成本，
    // 所以这里要求显式导入（本项目的取舍：宁可多一行 import，不留不确定性）。
    re: /\b(UIDevice|UIApplication|UIActivityViewController|UIImage|UIColor|UIPasteboard|UIWindow|UIAlertController|UIScreen|UIViewController|UIImpactFeedbackGenerator|UISelectionFeedbackGenerator|UINotificationFeedbackGenerator)\b/,
  },
  {
    framework: 'CryptoKit',
    re: /\bInsecure\.(SHA1|SHA256|MD5)\b|\bSHA256\.hash\b/,
  },
  {
    framework: 'Compression',
    re: /\bcompression_(decode|encode)_buffer\b|\bCOMPRESSION_[A-Z_]+\b/,
  },
  {
    framework: 'PhotosUI',
    re: /\bPHPickerViewController\b|\bPhotosPicker\b/,
  },
  {
    framework: 'AVFoundation',
    re: /\bAVAudioSession\b|\bAVAudioPlayer\b|\bAVPlayer\b/,
  },
  {
    framework: 'QuartzCore',
    // CACurrentMediaTime / CALayer 来自 QuartzCore。
    // **第 258 轮真编译撞过**：`ZL2FrameStats.swift` 只 import Foundation，
    // 用 `CACurrentMediaTime()` 直接报 "cannot find 'CACurrentMediaTime' in scope"。
    // UIKit 会间接带入 QuartzCore，所以「有 UIKit」也算满足（否则只 import UIKit 的文件会被误报）。
    alsoOk: ['UIKit'],
    re: /\b(CACurrentMediaTime|CALayer|CATransaction|CAShapeLayer|CABasicAnimation|CAAnimation)\b/,
  },
];

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const problems = [];
let checked = 0;

for (const name of files) {
  const full = path.join(SRC, name);
  let text;
  try { text = fs.readFileSync(full, 'utf8'); } catch { continue; }

  const importRe = /^\s*import\s+([A-Za-z_][A-Za-z0-9_]*)/gm;
  const imports = new Set();
  let m;
  while ((m = importRe.exec(text)) !== null) imports.add(m[1]);

  for (const rule of RULES) {
    if (!rule.re.test(text)) continue;
    checked++;
    const okBy = rule.alsoOk || [];
    if (!imports.has(rule.framework) && !okBy.some(f => imports.has(f))) {
      // 找出具体命中的符号，方便定位
      const hit = text.match(rule.re);
      const line = text.slice(0, hit.index).split('\n').length;
      problems.push({
        file: name,
        framework: rule.framework,
        symbol: hit[0],
        line,
        imports: [...imports].join(', ') || '（无）',
      });
    }
  }
}

console.log(`扫描 ${files.length} 个文件，命中框架符号 ${checked} 处`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 用到某框架符号的文件，都显式导入了对应框架');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处缺 import（会编译失败）：`);
for (const p of problems) {
  console.log(`\n  ${p.file}:${p.line}  用了 ${p.symbol}，但没有 import ${p.framework}`);
  console.log(`    当前 import：${p.imports}`);
}
console.log('');
console.log('修法：在文件顶部加 `import ' + problems[0].framework + '`（重复导入无害）。');
process.exit(1);
