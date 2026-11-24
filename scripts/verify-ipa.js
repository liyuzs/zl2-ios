// 核对一个 IPA 里"该有的东西是不是真在里面"
//
// 为什么有这个脚本：交付包里的 `ZL2.ipa` 每次重建都要人工核一遍内容（条目数、主程序体积、
// 四个渲染库、三套 JRE、启动器 jar、log4j 补丁、UniversalJIT26.js、版本号），
// 而**人工核一遍是一次性的**（第123轮那条：验证的价值取决于它能被重复）。
// 更关键的是：体积校验（≥100 MB）只是个粗代理 ——
// 缺一套 JRE 也还有 100 MB 出头，可是那个版本的 MC 直接起不来。
//
// 用法：
//   node scripts/verify-ipa.js                      # 默认核交付包里的 ZL2.ipa
//   node scripts/verify-ipa.js 某路径.ipa
//   node scripts/verify-ipa.js --quiet 某路径.ipa    # 只输出失败项
//
// 退出码：0 = 全部就位；1 = 有硬项失败（不要用它替换交付包）。
//
// **局限**（不查什么）：
//   · 只查"文件在不在、体积够不够、版本号像不像"。**不查能否启动** —— 那要真机。
//   · 不校验代码签名（发行包本来就没签名，签名是安装时做的）。
//   · 不查 Info.plist 的其它键（只读版本号），也不查 Info.plist 是不是合法 plist
//     （按 ASCII 片段找，找不到就报"读不到版本号"，不猜）。
//   · 不查 dylib 的架构与依赖（`lipo`/`otool` 那套要 macOS）。

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const args = process.argv.slice(2);
const quiet = args.includes('--quiet');
// 交付包目录同样支持 ZL2_DELIVERY（与 tools/config-guard/_paths.js 用同一个变量名）
const DELIVERY = process.env.ZL2_DELIVERY || 'D:/ZL2-iOS交付包';
const target = args.filter(a => !a.startsWith('--'))[0]
  || path.join(DELIVERY, 'ZL2.ipa');

// ---------- 最小 zip 读取（同 tools/config-guard/_audit-jni-classes.js）----------
function readCentral(buf) {
  let eocd = -1;
  for (let i = buf.length - 22; i >= 0 && i > buf.length - 66000; i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) throw new Error('找不到 EOCD（不是 zip，或文件被截断）');
  const count = buf.readUInt16LE(eocd + 10);
  let off = buf.readUInt32LE(eocd + 16);
  const entries = [];
  for (let n = 0; n < count; n++) {
    if (buf.readUInt32LE(off) !== 0x02014b50) break;
    const nameLen = buf.readUInt16LE(off + 28);
    const extraLen = buf.readUInt16LE(off + 30);
    const commentLen = buf.readUInt16LE(off + 32);
    entries.push({
      name: buf.toString('utf8', off + 46, off + 46 + nameLen),
      method: buf.readUInt16LE(off + 10),
      compSize: buf.readUInt32LE(off + 20),
      size: buf.readUInt32LE(off + 24),
      localOffset: buf.readUInt32LE(off + 42),
    });
    off += 46 + nameLen + extraLen + commentLen;
  }
  return entries;
}

function readEntry(buf, e) {
  const lho = e.localOffset;
  if (buf.readUInt32LE(lho) !== 0x04034b50) throw new Error('本地头损坏：' + e.name);
  const nameLen = buf.readUInt16LE(lho + 26);
  const extraLen = buf.readUInt16LE(lho + 28);
  const start = lho + 30 + nameLen + extraLen;
  const data = buf.subarray(start, start + e.compSize);
  return e.method === 0 ? data : zlib.inflateRawSync(data);
}

// ---------- 判定 ----------
const problems = [];
const notes = [];
function need(cond, msg) { if (!cond) problems.push(msg); }
function note(msg) { notes.push(msg); }

if (!fs.existsSync(target)) {
  console.log('✗ 找不到文件：' + target);
  process.exit(1);
}

const buf = fs.readFileSync(target);
const mb = (buf.length / 1048576).toFixed(1);   // 与文档口径一致（MiB，文档里都写"MB"）

let entries;
try { entries = readCentral(buf); }
catch (e) { console.log('✗ ' + target + ' 读不了：' + e.message); process.exit(1); }

const names = entries.map(e => e.name);
const has = n => names.includes(n);
const hasRe = re => names.some(n => re.test(n));
const countRe = re => names.filter(n => re.test(n)).length;

// 1) 条目数：build-243 是 998；低于 900 说明有整块没打进去
need(entries.length >= 900, `只有 ${entries.length} 个条目（build-243 是 998）—— 有整块资源没打进去`);

// 2) 主程序：Payload/<Something>.app/<Something>，且 ≥ 10 MB
const appRoot = names.map(n => (n.match(/^Payload\/([^/]+\.app)\/$/) || [])[1]).filter(Boolean)[0];
need(!!appRoot, '没有 Payload/<某个>.app/ 目录 —— 这不像一个 iOS 包');
if (appRoot) {
  const core = appRoot.replace(/\.app$/, '');
  const mainName = `Payload/${appRoot}/${core}`;
  const main = entries.find(e => e.name === mainName);
  need(!!main, `主程序 Payload/${appRoot}/${core} 不在包里`);
  if (main) need(main.size > 10 * 1024 * 1024, `主程序只有 ${(main.size / 1048576).toFixed(1)} MB（应 > 10 MB）`);
  note(`主程序 ${core}：${main ? (main.size / 1048576).toFixed(1) + ' MB' : '缺失'}`);

  // 3) 四个渲染库（iOS 上真实存在的只有这四个；mobileglues 从来没有文件）
  for (const lib of ['libgl4es_114.dylib', 'libtinygl4angle.dylib', 'libOSMesa.8.dylib', 'libMoltenVK.dylib']) {
    need(hasRe(new RegExp('/' + lib.replace(/\./g, '\\.') + '$')), `缺渲染库 ${lib} —— 选到它的那一刻会 dlopen 失败`);
  }
  // 4) mobileglues 必须不存在（代码里声明可选但包里没有 → 一选就崩）
  need(countRe(/mobileglues/i) === 0, `包里出现了 mobileglues 相关文件（${countRe(/mobileglues/i)} 个）—— 它与核心的渲染器开关对不上`);

  // 5) 三套 JRE
  for (const v of ['17', '21', '25']) {
    need(countRe(new RegExp('java_runtimes/java-' + v + '-openjdk/')) > 0, `缺 java-${v}-openjdk 运行时 —— 依赖这个版本的 MC 会起不来`);
  }

  // 6) 启动器 jar
  need(hasRe(/\/libs\/launcher\.jar$/), '缺 libs/launcher.jar（Java 侧主类所在）—— JVM 起来也找不到主类');
  const jarCount = countRe(/\/libs[^/]*\/[^/]+\.jar$/);
  need(jarCount >= 12, `只有 ${jarCount} 个启动器 jar（build-243 是 13 个）`);

  // 7) log4j 补丁与 JIT 脚本
  need(hasRe(/log4j-rce-patch-1\.12\.xml$/), '缺 log4j-rce-patch-1.12.xml');
  need(hasRe(/log4j-rce-patch-1\.7\.xml$/), '缺 log4j-rce-patch-1.7.xml');
  need(hasRe(/\/UniversalJIT26\.js$/), '缺 UniversalJIT26.js —— 开不了 JIT');

  // 8) Info.plist 里的版本号：不能还是静态的 0.1.0 / 1
  const plistEntry = entries.find(e => e.name === `Payload/${appRoot}/Info.plist`);
  need(!!plistEntry, '缺 Info.plist');
  if (plistEntry) {
    let text = '';
    try { text = readEntry(buf, plistEntry).toString('latin1'); }
    catch (e) { problems.push('Info.plist 读不了：' + e.message); }
    const m = text.match(/1\.0\.(\d{1,6})/);
    if (!m) {
      problems.push('Info.plist 里找不到 1.0.<build号> 形式的版本号 —— 版本注入可能没生效');
    } else {
      need(m[1] !== '1', `版本号是 1.0.1 —— 像是没注入 build 号（产出的包会和别的构建分不清）`);
      note(`版本 1.0.${m[1]}`);
    }
    need(!/0\.1\.0/.test(text), 'Info.plist 里还有 0.1.0 —— 那是第18轮之前写死的旧版本号');

    // 9) 这个包必须真的来自本工程（防"串包"：拿到别的工程/更早的包替换进交付目录，
    //    体积和条目数都可能正常，但装上去是完全另一个 App）
    need(/com\.liyuzs\.craftlauncher/.test(text), 'Info.plist 里没有 CFBundleIdentifier = com.liyuzs.craftlauncher —— 这个包不是本工程的（串包）');
    need(/CraftLauncher/.test(text), 'Info.plist 里没有 CFBundleDisplayName = CraftLauncher');
    need(/(^|[^0-9])16\.0([^0-9]|$)/.test(text), 'Info.plist 里找不到 MinimumOSVersion 16.0（最低系统被改过）');
  }
}

// ---------- 输出 ----------
if (!quiet) {
  console.log(`核对 ${path.basename(target)}（${mb} MB · ${entries.length} 个条目）`);
  for (const n of notes) console.log('  · ' + n);
  console.log('');
}

if (problems.length === 0) {
  console.log('✓ IPA 内容就位（条目 / 主程序 / 4 个渲染库 / 3 套 JRE / 启动器 jar / log4j 补丁 / JIT 脚本 / 版本号）');
  process.exit(0);
}
console.log(`✗ ${problems.length} 项不对：`);
for (const p of problems) console.log('  · ' + p);
process.exit(1);
