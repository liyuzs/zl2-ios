// 环境变量契约审计：Java 侧引用的环境变量 vs 我们实际 setenv 的
//
// 背景：ios-zl2 的 Java 侧（core/resources/libs/launcher.jar 里的 Tools.class）
// 常量池里同时出现 `GAME_DIR` 与 `POJAV_GAME_DIR`、`AME_HOME` 与 `POJAV_HOME`，
// 说明它做了「优先读一个、没有就退回另一个」的回退。我们原来只设了不带前缀的那份，
// 一旦某条代码路径走 POJAV_ 分支就会拿到 null。
//
// 这类问题在真机上的表现是「莫名其妙找不到游戏目录 / 找不到 JRE」，
// 而且日志里只有一句空指针。只能靠静态对撞提前发现。
//
// 做法：
//   ① 用最小 zip 读取器把 jar 里的 .class 解出来（Node 自带 zlib.inflateRawSync）
//   ② 从 class 常量池里抽形如 ALL_CAPS_WITH_UNDERSCORE 的字符串
//   ③ 只保留「像环境变量/路径配置」的那些（带 _DIR / _HOME / _PATH / POJAV_ 等）
//   ④ 与 core + src 里 setenv("X", ...) 的名字对撞

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const { REPO } = require('./_paths');
const LIBS_DIRS = [
  path.join(REPO, 'core', 'resources', 'libs'),
  path.join(REPO, 'core', 'resources', 'libs_caciocavallo'),
  path.join(REPO, 'core', 'resources', 'libs_caciocavallo17'),
];

// ---------- 最小 zip 读取器 ----------
function readZip(buf) {
  // 从尾部找 EOCD (0x06054b50)
  let eocd = -1;
  for (let i = buf.length - 22; i >= 0 && i > buf.length - 66000; i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) throw new Error('找不到 EOCD');
  const count = buf.readUInt16LE(eocd + 10);
  let off = buf.readUInt32LE(eocd + 16);

  const entries = [];
  for (let n = 0; n < count; n++) {
    if (buf.readUInt32LE(off) !== 0x02014b50) break;
    const method = buf.readUInt16LE(off + 10);
    const compSize = buf.readUInt32LE(off + 20);
    const nameLen = buf.readUInt16LE(off + 28);
    const extraLen = buf.readUInt16LE(off + 30);
    const commentLen = buf.readUInt16LE(off + 32);
    const localOff = buf.readUInt32LE(off + 42);
    const name = buf.toString('utf8', off + 46, off + 46 + nameLen);
    entries.push({ name, method, compSize, localOff });
    off += 46 + nameLen + extraLen + commentLen;
  }
  return entries;
}

function readEntry(buf, entry) {
  const lh = entry.localOff;
  if (buf.readUInt32LE(lh) !== 0x04034b50) return null;
  const nameLen = buf.readUInt16LE(lh + 26);
  const extraLen = buf.readUInt16LE(lh + 28);
  const start = lh + 30 + nameLen + extraLen;
  const data = buf.subarray(start, start + entry.compSize);
  try {
    if (entry.method === 0) return data;
    if (entry.method === 8) return zlib.inflateRawSync(data);
  } catch { return null; }
  return null;
}

// ---------- 从 class 常量池抽可读字符串 ----------
function classStrings(bytes) {
  const out = [];
  let cur = '';
  for (const b of bytes) {
    if (b >= 32 && b < 127) cur += String.fromCharCode(b);
    else { if (cur.length >= 3) out.push(cur); cur = ''; }
  }
  if (cur.length >= 3) out.push(cur);
  return out;
}

// ---------- ① 收集 Java 侧的候选环境变量名 ----------
const ENV_SHAPE = /^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$/;
// 只关心"像路径 / 开关 / 外部注入"的名字，避免把 GLFW_KEY_* 这类常量算进来
// 只关心"根路径 / 外部注入"这一类。范围收窄是刻意的：
// 上一版把 _MODE / _CODE 也收进来，结果抓出 60 多条 Vulkan/OpenAL 的枚举常量
// （VK_POLYGON_MODE_FILL、AL_DISTANCE_MODEL …），全是假阳性。
// 会喊狼来了的审计脚本等于没有，所以宁可窄。
const INTERESTING = /(^POJAV_|^GAME_DIR$|^AME_HOME$|^RENDERER$|^JAVA_HOME$|^LD_LIBRARY_PATH$|^CTRLMAP_PATH$|^NATIVE_LIB_DIR$|_GAME_DIR$|_HOME$|_LIBRARY_PATH$)/;
// 这些前缀是引擎/图形枚举常量，不是环境变量
const SKIP = /^(GLFW_|VK_|BVK_|EVK_|AL_|GLX_|GLU_|PFD_|WGL_|DC_|CUDA_|CDS_|USE_|EXTRACT_|INIT_|ERROR_|MAJOR_|MINOR_|REQUEST_|KEY_|ARRAY_OF|DISPLAY_DEVICE_|SHARED_LIBRARY|TYPE_|ACTION_|DIR_|DIRNAME_|ASSETS_|GL_)/;

const javaNames = new Set();
let scannedJars = 0, scannedClasses = 0;

for (const dir of LIBS_DIRS) {
  if (!fs.existsSync(dir)) continue;
  for (const f of fs.readdirSync(dir)) {
    if (!f.endsWith('.jar')) continue;
    const buf = fs.readFileSync(path.join(dir, f));
    let entries;
    try { entries = readZip(buf); } catch { continue; }
    scannedJars++;
    for (const e of entries) {
      if (!e.name.endsWith('.class')) continue;
      const data = readEntry(buf, e);
      if (!data) continue;
      scannedClasses++;
      for (const s of classStrings(data)) {
        if (!ENV_SHAPE.test(s)) continue;
        if (SKIP.test(s)) continue;
        if (!INTERESTING.test(s)) continue;
        javaNames.add(s);
      }
    }
  }
}

// ---------- ② 收集我们 setenv 的名字 ----------
const setNames = new Set();
function collect(dir, exts, depth = 0) {
  if (depth > 5 || !fs.existsSync(dir)) return;
  for (const f of fs.readdirSync(dir)) {
    if (f === 'external' || f === 'build') continue;
    const full = path.join(dir, f);
    let st; try { st = fs.statSync(full); } catch { continue; }
    if (st.isDirectory()) { collect(full, exts, depth + 1); continue; }
    if (!exts.some(e => f.endsWith(e))) continue;
    const text = fs.readFileSync(full, 'utf8');
    let m;
    const re = /setenv\(\s*@?"([^"]+)"/g;
    while ((m = re.exec(text)) !== null) setNames.add(m[1]);
    // Swift 里的 setGameEnv("A", "B", v) 形式
    const re2 = /setGameEnv\(\s*"([^"]+)"\s*,\s*"([^"]+)"/g;
    while ((m = re2.exec(text)) !== null) { setNames.add(m[1]); setNames.add(m[2]); }
  }
}
collect(path.join(REPO, 'core'), ['.m', '.h']);
collect(path.join(REPO, 'src'), ['.swift', '.h']);

// ---------- ③ 对撞 ----------
console.log(`扫描 jar：${scannedJars} 个，class：${scannedClasses} 个`);
console.log(`Java 侧引用的候选环境变量：${javaNames.size} 个`);
console.log(`我们 setenv 的名字：${setNames.size} 个`);
console.log('');

const missing = [...javaNames].filter(n => !setNames.has(n)).sort();
const covered = [...javaNames].filter(n => setNames.has(n)).sort();

if (covered.length) {
  console.log(`✓ 已覆盖（${covered.length}）：${covered.join(', ')}`);
}
console.log('');

if (missing.length === 0) {
  console.log('✓ Java 侧引用的环境变量我们都设了');
  process.exit(0);
}

console.log(`⚠ 有 ${missing.length} 个 Java 侧引用了但我们没设：`);
for (const n of missing) console.log(`    ${n}`);

console.log('');
console.log('（不是每个都必须设：有些是可选覆盖项，没设就走默认值。');
console.log('  重点看形如 POJAV_* / GAME_DIR / AME_HOME 这类"根路径"的。）');

// 根路径类的必须覆盖，其它只提示
const CRITICAL = /^(GAME_DIR|POJAV_GAME_DIR|AME_HOME|POJAV_HOME)$/;
const criticalMissing = missing.filter(n => CRITICAL.test(n));
if (criticalMissing.length) {
  console.log('');
  console.log(`✗ 关键根路径变量缺失：${criticalMissing.join(', ')}`);
  process.exit(1);
}
process.exit(0);
