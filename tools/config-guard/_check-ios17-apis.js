// 编译风险：用了 iOS 17+ 的 API，却没加可用性判断 —— 在 deploymentTarget = 16.0 的工程里
// 这不是"运行时才崩"，而是**编译直接失败**（"only available in iOS 17.0 or newer"）。
//
// 为什么需要这条：这个项目**本地没有 Swift 编译器**（Windows），一切靠 CI。
// 第 258 轮第一次真编译，26 种错误里就有 `symbolEffect` / `onChange(of:initial:_:)` 这类
// iOS 17+ API —— 它们是写代码时"看着眼熟就用了"，静态检查一条都没拦住。
// 之后每一轮加了新界面，都可能在同一个地方再摔一次。
//
// 判据：
//   1. 扫 src/*.swift 的每一行，命中**确凿属于 iOS 17+** 的符号（表在下面，只收能确定的）
//   2. 命中行往上 20 行内出现 `#available(iOS 17` 或 `#available(iOS 17.0` → 放行
//   3. 否则报错
//
// **局限**（不查什么）：
//   · **只认表里那 15 个符号**。SDK 里其它 iOS 17+ API 看不见 —— 表要人加，
//     而"哪些是 17+"靠的是经验，可能漏。
//   · **"往上 20 行内有 #available"是近似**，不是真正的词法作用域分析：
//     同一个函数里两个 `if #available` 块之间写的调用会被误放行；
//     反过来，`#available` 写在调用之后 20 行外会误报。
//   · **不查 iOS 18 / 19 API**（同一类问题，但表里没有）。
//   · **0 命中是正常的**（现在项目里确实没用这些）—— 所以本检查**不做零匹配报错**，
//     它守的是"以后别写进来"。有效性只能靠注入验证（造一行 `.symbolEffect` 看它报不报）。
const fs = require('fs');
const path = require('path');
const PATHS = require('./_paths');
const SRC = PATHS.SRC;

// 确凿的 iOS 17.0+ 符号（带点的是修饰符，@ 的是宏/属性包装器）
const IOS17 = [
  'symbolEffect', 'scrollTargetBehavior', 'scrollPosition', 'containerRelativeFrame',
  'sensoryFeedback', 'PhaseAnimator', 'KeyframeAnimator', '@Observable', '@Model',
  '.inspector(', 'contentMargins', 'scrollClipDisabled', '@Bindable', 'Map(initialPosition',
];
// `onChange(of:` 本身 iOS 14 就有；**带 initial 参数的那个重载**才是 iOS 17+
const ONCHANGE_INITIAL = /onChange\(\s*of:[^)]*\binitial:/;

const GUARD = /#available\(\s*iOS\s*17/;
const WINDOW = 20;   // 往上找多少行

if (!fs.existsSync(SRC)) { console.log('✗ 找不到 src/ —— 这不是"没问题"，是"没看到东西"'); process.exit(1); }
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
if (files.length === 0) { console.log('✗ src/ 里一个 .swift 都没有 —— 判据没东西可查'); process.exit(1); }

const problems = [];
let scanned = 0, hits = 0, guarded = 0;

for (const f of files) {
  const lines = fs.readFileSync(path.join(SRC, f), 'utf8').split(/\r?\n/);
  scanned++;
  lines.forEach((line, i) => {
    const code = line.replace(/\/\/.*$/, '');          // 去掉行内注释，免得注释里的示例被当真
    if (!code.trim()) return;
    let sym = null;
    for (const s of IOS17) if (code.includes(s)) { sym = s; break; }
    if (!sym && ONCHANGE_INITIAL.test(code)) sym = 'onChange(of:…initial:)';
    if (!sym) return;
    hits++;
    const from = Math.max(0, i - WINDOW + 1);
    const near = lines.slice(from, i + 1).join('\n');
    if (GUARD.test(near)) { guarded++; return; }
    problems.push(`${f}:${i + 1} 用了 iOS 17+ 的 ${sym}，但往上 ${WINDOW} 行内没有 #available(iOS 17 …)`);
  });
}

console.log(`扫了 ${files.length} 个 Swift 文件 · iOS 17+ 符号命中 ${hits} 处（${guarded} 处在守卫内）`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 没有"裸用 iOS 17+ API"的地方（deploymentTarget 16.0 下这类写法会编译失败）');
  process.exit(0);
}
console.log(`✗ ${problems.length} 处会在 iOS 16 目标上编译失败：`);
for (const p of problems) console.log('  · ' + p);
console.log('');
console.log('修法：① 换成 iOS 16 的等价写法（首选）② 或包在 `if #available(iOS 17, *) { … }` 里');
process.exit(1);
