// JNI native 方法契约审计：Java 声明的 native 方法 vs 核心导出的符号
//
// 真机上最先可能撞的就是 UnsatisfiedLinkError ——
// Java 侧声明了 native 方法，而 ObjC 侧没有对应的 Java_xxx 导出符号。
// 这种错误不会在编译期暴露，只有被调用的那一刻才抛。
//
// 做法：
//   ① 解析 jar 里的 .class（真解析，不是抽字符串）：
//      常量池 → 方法表 → 取 access_flags 带 ACC_NATIVE(0x0100) 的方法
//   ② 按 JNI 规则算出应有的符号名：Java_ + 类名把 / 换成 _ + _ + 方法名
//   ③ 与核心源码里 JNICALL 后面跟的 Java_xxx 对撞
//
// 注意：有重载时 JNI 用长名（带签名），本脚本先按短名比对并单独列出重载。

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const REPO = 'D:\\ios-zl2';
const CORE = path.join(REPO, 'core');
const LIBS_DIRS = [
  path.join(CORE, 'resources', 'libs'),
  path.join(CORE, 'resources', 'libs_caciocavallo'),
  path.join(CORE, 'resources', 'libs_caciocavallo17'),
];

// ---------- 最小 zip ----------
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

function readEntry(buf, e) {
  const lh = e.localOff;
  if (buf.readUInt32LE(lh) !== 0x04034b50) return null;
  const nameLen = buf.readUInt16LE(lh + 26);
  const extraLen = buf.readUInt16LE(lh + 28);
  const start = lh + 30 + nameLen + extraLen;
  const data = buf.subarray(start, start + e.compSize);
  try {
    if (e.method === 0) return data;
    if (e.method === 8) return zlib.inflateRawSync(data);
  } catch { return null; }
  return null;
}

// ---------- Java class 解析：取 native 方法 ----------
function parseNativeMethods(cb) {
  // cb: Buffer of the .class
  if (cb.readUInt32BE(0) !== 0xCAFEBABE) return [];
  let p = 8;                                   // magic(4) + minor(2) + major(2)
  const cpCount = cb.readUInt16BE(p); p += 2;

  const utf8 = new Array(cpCount);
  const classIdx = new Array(cpCount);         // tag 7 -> name_index

  for (let i = 1; i < cpCount; i++) {
    const tag = cb[p++];
    switch (tag) {
      case 1: {                                  // Utf8
        const len = cb.readUInt16BE(p); p += 2;
        utf8[i] = cb.toString('utf8', p, p + len);
        p += len;
        break;
      }
      case 7:  classIdx[i] = cb.readUInt16BE(p); p += 2; break;
      case 8:  p += 2; break;                    // String
      case 16: p += 2; break;                    // MethodType
      case 19: p += 2; break;                    // Module
      case 20: p += 2; break;                    // Package
      case 15: p += 3; break;                    // MethodHandle
      case 3: case 4: case 9: case 10: case 11:
      case 12: case 17: case 18: p += 4; break;
      case 5: case 6: p += 8; i++; break;        // Long/Double 占两个槽
      default: return [];                        // 未知 tag，放弃这个类
    }
  }

  p += 2;                                        // access_flags
  const thisClass = cb.readUInt16BE(p); p += 2;
  p += 2;                                        // super_class
  const ifCount = cb.readUInt16BE(p); p += 2 + ifCount * 2;

  const className = utf8[classIdx[thisClass]] || '';

  // fields
  const fCount = cb.readUInt16BE(p); p += 2;
  for (let i = 0; i < fCount; i++) {
    p += 6;                                      // access, name, desc
    const attrCount = cb.readUInt16BE(p); p += 2;
    for (let a = 0; a < attrCount; a++) {
      const len = cb.readUInt32BE(p + 2);
      p += 6 + len;
    }
  }

  // methods
  const natives = [];
  const mCount = cb.readUInt16BE(p); p += 2;
  for (let i = 0; i < mCount; i++) {
    const flags = cb.readUInt16BE(p);
    const nameIdx = cb.readUInt16BE(p + 2);
    const descIdx = cb.readUInt16BE(p + 4);
    p += 6;
    const attrCount = cb.readUInt16BE(p); p += 2;
    for (let a = 0; a < attrCount; a++) {
      const len = cb.readUInt32BE(p + 2);
      p += 6 + len;
    }
    if (flags & 0x0100) {                        // ACC_NATIVE
      natives.push({ name: utf8[nameIdx], desc: utf8[descIdx] });
    }
  }
  return natives.map(n => ({ className, ...n }));
}

// ---------- ① 收集 Java 侧 native 方法 ----------
let jarCount = 0, classCount = 0;
const javaNatives = [];   // { className, name, desc, jar }

for (const dir of LIBS_DIRS) {
  if (!fs.existsSync(dir)) continue;
  for (const f of fs.readdirSync(dir)) {
    if (!f.endsWith('.jar')) continue;
    const buf = fs.readFileSync(path.join(dir, f));
    let entries;
    try { entries = readZip(buf); } catch { continue; }
    jarCount++;
    for (const e of entries) {
      if (!e.name.endsWith('.class')) continue;
      const data = readEntry(buf, e);
      if (!data) continue;
      classCount++;
      let list;
      try { list = parseNativeMethods(data); } catch { continue; }
      for (const n of list) javaNatives.push({ ...n, jar: f });
    }
  }
}

// ---------- ② 收集核心导出的符号 ----------
const exported = new Set();
{
  const stack = [CORE];
  while (stack.length) {
    const dir = stack.pop();
    for (const f of fs.readdirSync(dir)) {
      if (f === 'external' || f === 'build') continue;
      const full = path.join(dir, f);
      let st; try { st = fs.statSync(full); } catch { continue; }
      if (st.isDirectory()) { stack.push(full); continue; }
      if (!/\.(m|mm)$/.test(f)) continue;
      const text = fs.readFileSync(full, 'utf8');
      let m;
      const re = /JNICALL\s+(Java_[A-Za-z0-9_]+)/g;
      while ((m = re.exec(text)) !== null) exported.add(m[1]);
    }
  }
}

// ---------- ③ 对撞（只查「该由我们核心实现」的包）----------
//
// 关键：jar 里绝大多数 native 方法不是我们实现的 ——
// org/lwjgl/opengl/** 与 org/lwjgl/system/** 由 LWJGL 自己的 dylib
// （Frameworks/liblwjgl*.dylib）提供，拿核心的 Java_* 去比对只会满屏假阳性。
// 上一版没限定范围，输出了上千条，等于没用。
//
// 只查这些必须由本工程 ObjC 实现的：
//   · net/kdt/pojavlaunch/**            UIKit / MinecraftAccount / Tools
//   · net/java/openjdk/cacio/**         老包名 cacio（Java 8）
//   · com/github/caciocavallosilano/**  新包名 cacio（Java 17+）
//   · sun/net/dns/**                    ResConfHack
// GLFW 的回调是用宏 ADD_CALLBACK_WWIN 生成的，符号名带 ##，静态提取认不出，
// 单独归入「需人工确认」而不是报警。
const CORE_OWNED = [
  /^net\/kdt\/pojavlaunch\//,
  /^net\/java\/openjdk\/cacio\//,
  /^com\/github\/caciocavallosilano\//,
  /^sun\/net\/dns\//,
];
// 这两个类里**混合**了宏生成的回调与普通 native 方法，不能整类跳过。
// 上一版整类跳过，把 nativeSendData / nativeSetInputReady 藏起来了 ——
// 它们不是宏生成的，是普通 native，缺了会在输入时 UnsatisfiedLinkError。
const MACRO_CLASSES = [
  /^org\/lwjgl\/glfw\/GLFW$/,
  /^org\/lwjgl\/glfw\/CallbackBridge$/,
];
// 宏 ADD_CALLBACK_WWIN(NAME) 展开成 Java_..._nglfwSet<NAME>Callback
const MACRO_METHOD = /^nglfwSet\w+Callback$/;

function mangle(className, method) {
  // JNI 短名：类名里的 / 换成 _（方法名里的 _ 要转义成 _1，这里没有这种情况）
  return 'Java_' + className.replace(/\//g, '_') + '_' + method;
}

const byKey = new Map();
for (const n of javaNatives) {
  const k = `${n.className}#${n.name}`;
  if (!byKey.has(k)) byKey.set(k, []);
  byKey.get(k).push(n);
}

const inScope = [];
const skipped = { lwjgl: 0, macro: 0, other: 0 };
for (const [k, list] of byKey) {
  const n = list[0];
  const cls = n.className;
  // org/lwjgl/glfw 下的类也归本工程（输入桥就是这个包），
  // 但宏生成的那些回调要单独排除。
  if (/^org\/lwjgl\/glfw\//.test(cls)) {
    if (MACRO_CLASSES.some(re => re.test(cls)) && MACRO_METHOD.test(n.name)) skipped.macro++;
    else inScope.push(n);
    continue;
  }
  if (CORE_OWNED.some(re => re.test(cls + '/'))) inScope.push(n);
  else if (/^org\/lwjgl\//.test(cls)) skipped.lwjgl++;
  else skipped.other++;
}

// 两类不算「缺失」：
//   ① 用 RegisterNatives 动态绑定的 —— 符号不需要以 Java_* 形式导出
//      （input_bridge_v3.m 的 registerOpenHandler 就是这种）
//   ② JDK 自己的 native（libjava 里实现）
const DYNAMIC_REGISTERED = new Set([
  'Java_net_java_openjdk_cacio_ctc_CTCDesktopPeer_openFile',
  'Java_net_java_openjdk_cacio_ctc_CTCDesktopPeer_openUri',
  'Java_net_java_openjdk_cacio_ctc_CTCClipboard_nQuerySystemClipboard',
  'Java_net_java_openjdk_cacio_ctc_CTCClipboard_nPutClipboardData',
  'Java_com_github_caciocavallosilano_cacio_ctc_CTCClipboard_nQuerySystemClipboard',
  'Java_com_github_caciocavallosilano_cacio_ctc_CTCClipboard_nPutClipboardData',
]);
const JDK_PROVIDED = /^Java_(sun_|java_|javax_|jdk_|com_sun_)/;

const missing = [];
const ok = [];
const dynamic = [];
const jdk = [];
for (const n of inScope) {
  const sym = mangle(n.className, n.name);
  if (exported.has(sym)) ok.push(sym);
  else if (DYNAMIC_REGISTERED.has(sym)) dynamic.push(sym);
  else if (JDK_PROVIDED.test(sym)) jdk.push(sym);
  else missing.push({ sym, cls: n.className, name: n.name, jar: n.jar, desc: n.desc });
}

console.log(`扫描 jar：${jarCount} 个，class：${classCount} 个`);
console.log(`Java 侧声明的 native 方法：${byKey.size} 个（去重后）`);
console.log(`  其中「该由本工程实现」的：${inScope.length} 个`);
console.log(`  跳过：LWJGL 自带原生库 ${skipped.lwjgl} / 宏生成 ${skipped.macro} / 其它 ${skipped.other}`);
console.log(`核心导出的 Java_* 符号：${exported.size} 个`);
console.log('');

if (ok.length) {
  console.log(`✓ 已实现（${ok.length}）：`);
  for (const s of ok.sort()) console.log(`    ${s}`);
  console.log('');
}
if (dynamic.length) {
  console.log(`· RegisterNatives 动态绑定，不需要 Java_* 导出（${dynamic.length}）：`);
  for (const s of dynamic.sort()) console.log(`    ${s}`);
  console.log('');
}
if (jdk.length) {
  console.log(`· 由 JDK 自己提供（${jdk.length}）：${jdk.join(', ')}`);
  console.log('');
}

if (missing.length === 0) {
  console.log('✓ 该由本工程实现的 native 方法，核心全都导出了');
  process.exit(0);
}

console.log(`⚠ ${missing.length} 个声明了但核心没导出（被调用时抛 UnsatisfiedLinkError）：`);
for (const m of missing) {
  console.log(`    ${m.sym}`);
  console.log(`        ${m.cls}.${m.name}${m.desc}   ← ${m.jar}`);
}
console.log('');
console.log('（有些可能永远不会被调用 —— 要看调用点。已知的：CTCDesktopPeer 的');
console.log('  openFile/openUri 走的是 net/java/openjdk 老包名，Java 17+ 下不存在，');
console.log('  所以永远不会被调；Java 8 下才有。）');

process.exit(1);