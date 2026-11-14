// 路径拼接安全（防目录穿越）
//
// 起因：ios-zl2 第80轮扫路径拼接时发现，好几处把**远端数据**或**用户输入**直接拼进路径：
//   · ModrinthAPI      dir.appendingPathComponent(file.filename)   // filename 来自接口
//   · MojangAPI        directory.appendingPathComponent(relativePath)  // 来自版本 JSON
//   · VersionInstaller libRoot.appendingPathComponent(path)         // 来自版本 JSON
//   · LoaderInstaller  libRoot.appendingPathComponent(path)         // 来自加载器元数据
//   · FileManagerScreen current.appendingPathComponent(newName)     // 用户手输
//   · LoaderInstaller  versionsDir.appendingPathComponent(versionID)
// 这些字符串里只要出现 `..` 或 `/`，文件就会写到预期目录之外：
// 远端数据能把文件写出沙盒区，用户手滑输入 `../` 能把文件挪进 App 自己的数据目录。
//
// 现在统一走 src/ZLPathSafety.swift。本检查保证：
//   1. 这个助手文件存在且提供了三件套
//   2. 处理远端数据的文件里，用变量拼路径时必须经过 ZLPathSafety
//   3. 已知安全的例外要显式登记（当前只有 UUID 临时文件名一处）

// **局限**
// · 只认 `appendingPathComponent` / `safeComponent` 这类**具体 API**。如果改用 `URL(fileURLWithPath:).appendingPathComponent` 的变体、或自己拼字符串路径，它看不见。
// · 只判"有没有过 ZLPathSafety"（结构），判不了"过了之后是否用对"（语义）。
// · **失效条件**：项目要是引入新的路径拼接方式（比如 `appending(component:)`），需要同步更新它的 API 名单。
const fs = require('fs');
const path = require('path');
const { SRC } = require('./_paths');
const read = f => fs.readFileSync(path.join(SRC, f), 'utf8');

// ---- 1. 助手必须存在且完整 ----
let helper = '';
try { helper = read('ZLPathSafety.swift'); } catch {
  console.log('✗ 缺少 src/ZLPathSafety.swift');
  process.exit(1);
}
const needApi = ['func safeComponent', 'func validateNewName', 'func safeRelativePath'];
const missApi = needApi.filter(a => !helper.includes(a));
if (missApi.length) {
  console.log(`✗ ZLPathSafety 缺少：${missApi.join(', ')}`);
  process.exit(1);
}

// ---- 2. 处理远端/用户数据的文件：变量拼路径必须过闸 ----
const GUARDED = [
  'ModrinthAPI.swift',
  'MojangAPI.swift',
  'VersionInstaller.swift',
  'LoaderInstaller.swift',
  'FileManagerScreen.swift',
];

// 已知安全的例外：行里含这些标记就跳过
const ALLOW_LINES = [
  { match: 'UUID().uuidString', why: '临时文件名 = lastPathComponent + UUID，不含分隔符' },
  { match: 'appendingPathComponent("', why: '字面量路径段，不来自外部' },
  { match: 'ZLPathSafety.', why: '已过校验' },
];

// 「已过校验」有两种写法：
//   · 同一行里直接调 ZLPathSafety
//   · 前面几行 guard 过，再用 safeRel / safePath 这类变量（本项目的写法）
// 所以候选行要向上回看 LOOKBACK 行，向后看 2 行（临时文件名那种跨行）。
// 精确做法：先把文件里「由 ZLPathSafety 赋值出来的变量名」收集起来，
// 拼路径的那一行必须**用到其中之一**（或自己就内联调用）。
// 只回看"附近有没有 ZLPathSafety"太宽松 —— 校验写了却没用校验后的变量时抓不到
// （第80轮注入验证时当场踩到这一点）。
// 两种合法写法：
//   ① let safeX = ZLPathSafety.xxx(...)  然后用 safeX
//   ② ZLPathSafety.validateNewName(name) 通过后用原 name（用户输入场景，校验后原名就安全）
const SAFE_ASSIGN = /let\s+(\w+)\s*=\s*ZLPathSafety\.\w+\(/g;
const VALIDATED_NAME = /ZLPathSafety\.validateNewName\(\s*(\w+)/g;

let bad = [];
let concatSites = 0;      // 匹配到多少处 appendingPathComponent（判据的"分母"）
const missingGuarded = [];
for (const file of GUARDED) {
  // 先查存在：`read()` 没有 try/catch，文件不存在会直接抛异常（崩掉而不是走 missingGuarded）
  if (!fs.existsSync(path.join(SRC, file))) { missingGuarded.push(file); continue; }
  const text = read(file);
  const lines = text.split('\n');

  const safeVars = new Set();
  for (const m of text.matchAll(SAFE_ASSIGN)) safeVars.add(m[1]);
  for (const m of text.matchAll(VALIDATED_NAME)) safeVars.add(m[1]);

  lines.forEach((line, i) => {
    if (!line.includes('appendingPathComponent(')) return;
    concatSites++;
    if (ALLOW_LINES.some(a => line.includes(a.match))) return;
    if (safeVars.size && [...safeVars].some(v => new RegExp('\\b' + v + '\\b').test(line))) return;

    const fwd = lines.slice(i, Math.min(lines.length, i + 3)).join('\n');
    if (ALLOW_LINES.some(a => fwd.includes(a.match))) return;

    bad.push({ file, line: i + 1, text: line.trim().slice(0, 90) });
  });
}

console.log(`检查 ${GUARDED.length} 个文件：匹配到 ${concatSites} 处 appendingPathComponent`);
console.log('');

// 名单存在性：GUARDED 里的文件读不到，那就等于没查那个文件
if (missingGuarded.length > 0) {
  console.log('⚠ GUARDED 里这些文件读不到（改名或删了）：' + missingGuarded.join('、'));
  console.log('  请更新 GUARDED 名单，否则它们永远不会被这条检查覆盖。');
  process.exit(1);
}

// 零匹配即失败：说明写法变了（或 GUARDED 名单过时），这时候"全都过了校验"是空真
if (concatSites === 0) {
  console.log('⚠ 一处 appendingPathComponent 都没匹配到 —— 判据可能已过时');
  console.log('  这不是"没问题"，是"没看到东西"。请核对 GUARDED 名单与拼接写法。');
  process.exit(1);
}

if (bad.length === 0) {
  console.log('✓ 远端数据与用户输入的路径段都过了 ZLPathSafety');
  process.exit(0);
}

console.log(`⚠ ${bad.length} 处未过校验：`);
for (const b of bad) {
  console.log(`  ${b.file}:${b.line}`);
  console.log(`    ${b.text}`);
}
console.log('');
console.log('修法：用 ZLPathSafety.safeComponent(单层) 或 safeRelativePath(多段)，');
console.log('      用户输入用 validateNewName 并报错；确实安全的在 ALLOW_LINES 登记理由。');
process.exit(1);
