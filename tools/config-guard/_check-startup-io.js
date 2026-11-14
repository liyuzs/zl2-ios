// 首屏性能：断言「列版本」的默认路径不做递归目录扫描
//
// 起因：ios-zl2 第124轮。`listVersions()` 对每个版本目录调 `directorySize()`，
// 而后者用 `fm.enumerator` **递归遍历整个目录**（jar + libraries 数百文件 + mods），
// 逐个 stat 累加。而 `HomeScreen.onAppear → refreshInstalledVersion() → listVersions()`，
// 也就是说**每次进首页都在主线程递归扫一遍所有版本目录**。
// 而 `sizeBytes` 全项目只有版本列表一处显示。
//
// 改法：`listVersions(includeSize: Bool = false)`，默认不算。
//
// **为什么需要这条检查**：本地没有真机、没法测首屏耗时，只能静态守住这个"默认值"。
// 一旦有人把默认改成 true、或绕过参数直接调 `directorySize`，这条会报。
//
// **局限**（不查什么）：
//   · **只查 `listVersions` 这一个函数**。别的"默认路径做昂贵事"它看不见 ——
//     比如 `VersionRepository.sizeBytes` 在别处被间接调用、或 `GameDirectoryStore` 列实例时算大小。
//   · **只认 `directorySize` 一个昂贵操作**。JSON 解码、读文件、正则等别的贵操作不在范围
//     （那些归 `_check-hotpath-cost`，但它只看渲染期/onChange/ForEach，**不看 `onAppear`**）。
//   · **判据是"窗口内有没有 `includeSize` 门控"**（第194轮加固成前 2 行 + 本行 + 后 1 行）。
//     如果门控写成更远的形态（提前 return、或把 Bool 参数换成枚举/配置对象），会误报或漏报。
//   · **它守的是"默认值"，不是"实际耗时"**。就算默认 false，用户在版本列表里主动打开"显示大小"那一屏
//     仍然会卡 —— **真机耗时从未测过，这条检查给不了任何性能保证**。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const REPO_FILE = path.join(SRC, 'VersionRepository.swift');
const problems = [];

let src = '';
try {
  src = fs.readFileSync(REPO_FILE, 'utf8');
} catch {
  console.log('✗ 找不到 VersionRepository.swift');
  process.exit(1);
}

// ---- ① 签名必须带 includeSize 且默认 false ----
const sig = src.match(/func listVersions\(([^)]*)\)/);
if (!sig) {
  problems.push('找不到 listVersions 的声明');
} else {
  const params = sig[1].trim();
  if (!/includeSize\s*:\s*Bool\s*=\s*false/.test(params)) {
    problems.push(`listVersions 的参数应为 includeSize: Bool = false，实际是「${params}」—— 默认算大小会让每次进首页都递归扫全部版本目录`);
  }
}

// ---- ② 同函数内对 directorySize 的调用必须被 includeSize 门控 ----
// 取 listVersions 函数体（大括号配对）
function blockAfter(s, openBraceIdx) {
  let depth = 0;
  for (let i = openBraceIdx; i < s.length; i++) {
    if (s[i] === '{') depth++;
    else if (s[i] === '}') { depth--; if (depth === 0) return s.slice(openBraceIdx, i + 1); }
  }
  return s.slice(openBraceIdx);
}

if (sig) {
  const bodyStart = src.indexOf('{', src.indexOf('func listVersions'));
  if (bodyStart > 0) {
    const body = blockAfter(src, bodyStart);
    const bodyLines = body.split('\n');
    for (let bi = 0; bi < bodyLines.length; bi++) {
      if (!bodyLines[bi].includes('directorySize(')) continue;
      // **第194轮加固**：原来只判"同一行有没有 includeSize"。
      // 当前代码是三元写法 `includeSize ? directorySize(dir) : 0`（同行 ✓），
      // 但如果改写成 `if includeSize { size = directorySize(dir) }`，
      // `directorySize(` 那行就不含 includeSize → **假警报**。
      // 所以改成看窗口（前 2 行 + 本行 + 后 1 行）——门控在这几行内出现就算。
      const window = [bodyLines[bi - 2] || '', bodyLines[bi - 1] || '',
                      bodyLines[bi], bodyLines[bi + 1] || ''].join(' ');
      if (!window.includes('includeSize')) {
        problems.push(`listVersions 里直接调了 directorySize 而没有 includeSize 门控：「${bodyLines[bi].trim().slice(0, 60)}」`);
      }
    }
  }
}

// ---- ③ 说明性输出：哪些调用点要 size、哪些不要 ----
const allSwift = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const withSize = [], withoutSize = [];
for (const f of allSwift) {
  const t = fs.readFileSync(path.join(SRC, f), 'utf8');
  for (const m of t.matchAll(/listVersions\(\s*(includeSize\s*:\s*true)?\s*\)/g)) {
    (m[1] ? withSize : withoutSize).push(f);
  }
}
const uniq = a => [...new Set(a)];

console.log(`调用点：要大小的 ${withSize.length} 处（${uniq(withSize).join('、') || '无'}）`);
console.log(`        不算大小的 ${withoutSize.length} 处（${uniq(withoutSize).join('、') || '无'}）`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 列版本的默认路径不做递归目录扫描（首页不会因此卡）');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处会让首屏变慢：`);
for (const p of problems) console.log(`  · ${p}`);
console.log('');
console.log('修法：listVersions 保持 includeSize: Bool = false；只有需要显示大小的页面传 true。');
process.exit(1);
