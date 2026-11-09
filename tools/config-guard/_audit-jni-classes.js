// JNI 类契约审计：核心 FindClass 找的类，jar 里到底有没有
//
// 起因：core/input_bridge_v3.m 在 JNI_OnLoad 里注册 CTCClipboard 的 native 方法，
// 而两个包名的 CTCClipboard 在我们放进去的 cacio jar 里都不存在 ——
// FindClass 返回 NULL + 留下未清理的异常，紧接着 RegisterNatives(env, NULL, ...)
// 会让 HotSpot 直接 abort。也就是**每次 JVM 启动都会崩**。
//
// 相邻的 CTCDesktopPeer 那段有 return 保护，clipboard 那段漏了。
// 这类问题不会在编译期暴露，只能靠对撞：把核心代码里的 FindClass 字面量
// 全抽出来，剔除 JDK 自带的那些，剩下的逐个到 jar 里找。

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const { REPO } = require('./_paths');
const CORE = path.join(REPO, 'core');
const LIBS_DIRS = [
  path.join(CORE, 'resources', 'libs'),
  path.join(CORE, 'resources', 'libs_caciocavallo'),
  path.join(CORE, 'resources', 'libs_caciocavallo17'),
];

// ---------- 最小 zip 读取（同 _audit-env.js）----------
function readZip(buf) {
  let eocd = -1;
  for (let i = buf.length - 22; i >= 0 && i > buf.length - 66000; i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) throw new Error('no EOCD');
  const count = buf.readUInt16LE(eocd + 10);
  let off = buf.readUInt32LE(eocd + 16);
  const entries = [];
  for (let n = 0; n < count; n++) {
    if (buf.readUInt32LE(off) !== 0x02014b50) break;
    const nameLen = buf.readUInt16LE(off + 28);
    const extraLen = buf.readUInt16LE(off + 30);
    const commentLen = buf.readUInt16LE(off + 32);
    const name = buf.toString('utf8', off + 46, off + 46 + nameLen);
    entries.push(name);
    off += 46 + nameLen + extraLen + commentLen;
  }
  return entries;
}

// ---------- 收集 jar 里的类 ----------
const jarClasses = new Map();   // "a/b/C.class" -> jarName
let jars = 0;
for (const dir of LIBS_DIRS) {
  if (!fs.existsSync(dir)) continue;
  for (const f of fs.readdirSync(dir)) {
    if (!f.endsWith('.jar')) continue;
    const buf = fs.readFileSync(path.join(dir, f));
    let names;
    try { names = readZip(buf); } catch { continue; }
    jars++;
    for (const n of names) {
      if (n.endsWith('.class')) jarClasses.set(n, f);
    }
  }
}

// ---------- 抽核心里的 FindClass 字面量 ----------
function collect(dir, depth = 0, out = []) {
  if (depth > 5 || !fs.existsSync(dir)) return out;
  for (const f of fs.readdirSync(dir)) {
    if (f === 'external' || f === 'build') continue;
    const full = path.join(dir, f);
    let st; try { st = fs.statSync(full); } catch { continue; }
    if (st.isDirectory()) { collect(full, depth + 1, out); continue; }
    if (!/\.(m|mm|h|swift)$/.test(f)) continue;
    const text = fs.readFileSync(full, 'utf8');
    const lines = text.split('\n');
    let m;
    const re = /FindClass\s*\(\s*[^,]+,\s*"([^"]+)"/g;
    while ((m = re.exec(text)) !== null) {
      const before = text.slice(0, m.index);
      const line = before.split('\n').length;
      out.push({ cls: m[1], file: f, line });
    }
  }
  return out;
}

const found = collect(CORE);

// JDK 自带的包：不需要在 jar 里
const JDK_PREFIXES = ['java/', 'javax/', 'sun/', 'jdk/', 'com/sun/', 'org/w3c/', 'org/xml/'];
// 只有旧包名的 cacio（Java 8 用），在 libs_caciocavallo 里
const results = [];
for (const r of found) {
  if (JDK_PREFIXES.some(p => r.cls.startsWith(p))) continue;
  const asFile = r.cls + '.class';
  results.push({ ...r, present: jarClasses.has(asFile), jar: jarClasses.get(asFile) });
}

// 按类名去重（同一个类可能在多个文件里被 FindClass）
const byClass = new Map();
for (const r of results) {
  if (!byClass.has(r.cls)) byClass.set(r.cls, { ...r, sites: [] });
  byClass.get(r.cls).sites.push(`${r.file}:${r.line}`);
}

console.log(`扫描 jar：${jars} 个，类：${jarClasses.size} 个`);
console.log(`核心 FindClass 的非 JDK 目标：${byClass.size} 个`);
console.log('');

const missing = [...byClass.values()].filter(r => !r.present);
const present = [...byClass.values()].filter(r => r.present);

if (present.length) {
  console.log(`✓ 存在于 jar（${present.length}）：`);
  for (const r of present) console.log(`    ${r.cls}  ← ${r.jar}`);
}
console.log('');

if (missing.length === 0) {
  console.log('✓ 核心 FindClass 的类都能在 jar 里找到');
  process.exit(0);
}

// 已知缺失、但**已在调用处判空处理**的类。不算遗漏，只提示。
// 加新条目时必须同时确认调用处真的判了空并清了异常，
// 否则 HotSpot 会在 RegisterNatives/GetMethodID 那里 abort。
const HANDLED = {
  'net/java/openjdk/cacio/ctc/CTCClipboard':
    'input_bridge_v3.m 已判空 + ExceptionClear 后跳过注册 —— 游戏内剪贴板不可用，但不崩',
  'com/github/caciocavallosilano/cacio/ctc/CTCClipboard':
    '同上（两个包名轮着找，都没有）',
};

const handled = missing.filter(r => HANDLED[r.cls]);
const unhandled = missing.filter(r => !HANDLED[r.cls]);

if (handled.length) {
  console.log(`· 已知缺失但已判空处理（${handled.length}）：`);
  for (const r of handled) {
    console.log(`    ${r.cls}`);
    console.log(`        ${HANDLED[r.cls]}`);
  }
  console.log('');
}

if (unhandled.length === 0) {
  console.log('✓ 没有「缺失又没判空」的 FindClass 目标');
  process.exit(0);
}

console.log(`⚠ ${unhandled.length} 个不在任何 jar 里、且未确认判空：`);
for (const r of unhandled) {
  console.log(`    ${r.cls}`);
  console.log(`        ${r.sites.join(', ')}`);
}
console.log('');
console.log('注意：FindClass 失败会返回 NULL 并留下待处理异常。');
console.log('如果随后没有判空就拿去 RegisterNatives / GetMethodID，HotSpot 会 abort。');
console.log('每一条都要么换成 jar 里存在的类，要么在调用处判空并清异常。');

process.exit(1);
