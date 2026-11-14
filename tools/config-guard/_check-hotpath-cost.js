// 渲染期开销：body / computed var 里不许有昂贵操作
//
// 起因：ios-zl2 第124轮发现 `HomeScreen.onAppear → listVersions() → directorySize()`，
// 每次进首页都在主线程递归扫全部版本目录。第125轮把同一套方法推广到"渲染期"：
// **body 与 computed var 会在每次重绘时求值**，里面放 IO 或全量遍历的代价最高。
//
// 判据（刻意保守，只认几类明确的昂贵操作），覆盖**三个高频层**：
//   ① `var body` / `var xxx: some View` —— 每次重绘都会求值（最贵）
//   ② `.onChange(...) { }` —— 每次值变化都跑
//   ③ `ForEach(...) { }` —— 每一行都跑
//   出现 listVersions / directorySize / 目录枚举 / JSON 解码 / 读文件 → 报。
//
// **豁免**（这些是显式副作用，不是渲染期计算 —— 第125轮实测踩过）：
//   `.task { }` / `.onAppear { }` / `.onDisappear { }` / `.onChange { }` /
//   `.onReceive { }` / `.refreshable { }` / `.sheet { }` / `.alert { }` / `.confirmationDialog { }`
//   闭包内部不判。`FileManagerScreen` 的属性页把递归算目录大小放在 `.task` 里，正是正确做法。
//
// **局限**（查不到什么）：只认下面这 5 类操作；别的昂贵写法（大数组 sort、字符串拼接、正则）
//   不判 —— 那需要真正的复杂度分析。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

const COSTLY = [
  { re: /listVersions\(/, name: 'listVersions（扫版本目录）' },
  { re: /directorySize\(/, name: 'directorySize（递归遍历）' },
  { re: /contentsOfDirectory|enumerator\(at:/, name: '目录枚举' },
  { re: /JSONDecoder\(\)|JSONSerialization\.jsonObject/, name: 'JSON 解码' },
  { re: /Data\(contentsOf:/, name: '读文件内容' },
];

const isHotContainer = (line) =>
  /^\s*(?:private\s+)?var\s+\w+\s*:\s*some\s*View\s*\{/.test(line) ||
  /^\s*var\s+body\s*:\s*some\s*View\s*\{/.test(line);

function blockEnd(lines, startIdx) {
  let depth = 0, started = false;
  for (let i = startIdx; i < lines.length; i++) {
    for (const ch of lines[i]) {
      if (ch === '{') { depth++; started = true; }
      else if (ch === '}') depth--;
    }
    if (started && depth <= 0) return i;
  }
  return lines.length - 1;
}

const isSideEffectModifier = (line) =>
  /\.(task|onAppear|onDisappear|onChange|onReceive|refreshable|sheet|alert|confirmationDialog)\s*[({]/.test(line);

const hits = [];
let containers = 0;

for (const f of files) {
  const lines = fs.readFileSync(path.join(SRC, f), 'utf8').split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    if (!isHotContainer(lines[i])) continue;
    containers++;
    const end = blockEnd(lines, i);

    // 跳过副作用闭包覆盖的行
    const skip = new Set();
    for (let k = i; k <= end; k++) {
      if (isSideEffectModifier(lines[k])) {
        const e = blockEnd(lines, k);
        for (let q = k; q <= e; q++) skip.add(q);
      }
    }

    for (let k = i + 1; k <= end; k++) {
      if (skip.has(k)) continue;
      const trimmed = lines[k].trim();
      if (trimmed.startsWith('//')) continue;
      for (const c of COSTLY) {
        if (c.re.test(lines[k])) {
          hits.push({ file: f, line: k + 1, inAt: i + 1, kind: c.name, code: trimmed.slice(0, 72) });
        }
      }
    }
  }
}

// ---- ② .onChange(...) { } 与 ③ ForEach(...) { } ----
let onChangeCount = 0, forEachCount = 0;

for (const f of files) {
  const lines = fs.readFileSync(path.join(SRC, f), "utf8").split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    if (/\.onChange\s*\(/.test(line)) {
      onChangeCount++;
      const end = blockEnd(lines, i);
      for (let q = i; q <= end; q++) {
        const t = lines[q].trim();
        if (t.startsWith("//")) continue;
        for (const c of COSTLY) {
          if (c.re.test(lines[q])) hits.push({ file: f, line: q + 1, inAt: i + 1, kind: c.name, code: t.slice(0, 72) });
        }
      }
    }

    if (/\bForEach\s*\(/.test(line)) {
      forEachCount++;
      const end = blockEnd(lines, i);
      for (let q = i; q <= end; q++) {
        const t = lines[q].trim();
        if (t.startsWith("//")) continue;
        for (const c of COSTLY) {
          if (c.re.test(lines[q])) hits.push({ file: f, line: q + 1, inAt: i + 1, kind: c.name, code: t.slice(0, 72) });
        }
      }
    }
  }
}
console.log(`扫了 ${containers} 个渲染块、${onChangeCount} 个 .onChange、${forEachCount} 个 ForEach`);
console.log('');

if (hits.length === 0) {
  console.log('✓ 三个高频层都没有昂贵操作（渲染块 / .onChange / ForEach 里不扫盘、不解码、不读文件）');
  process.exit(0);
}

console.log(`⚠ ${hits.length} 处昂贵操作写在了高频位置（渲染块 / .onChange / ForEach）—— 会反复执行：`);
for (const h of hits) {
  console.log(`  ${h.file}:${h.line}（在 L${h.inAt} 起的高频块里）  ${h.kind}`);
  console.log(`      ${h.code}`);
}
console.log('');
console.log('修法：把计算挪进 .task { } / .onAppear { } 并存进 @State，');
console.log('      或像 listVersions 那样做成"默认不算、需要才传参"。');
process.exit(1);
