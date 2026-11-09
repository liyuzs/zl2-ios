// 三套存储对撞审计
//
// 这个项目里有三套互不相通的偏好存储：
//   ① UserDefaults.standard          —— App 自己的记账本，核心完全不看
//   ② PLPreferences 的 plist          —— getPrefObject/getPrefBool/getPrefInt 读这里
//   ③ <GAME_DIR>/launcher_profiles.json —— resolveKeyForCurrentProfile 读这里
//
// 两个方向都查：
//
//   ① 写方向 —— Swift 只写了 UserDefaults，而核心在读同名/语义相同的键。
//      那是假功能：用户改了设置，核心根本没收到。
//
//   ② 读方向 —— Swift 从 UserDefaults 读一个**核心拥有**的键（核心在读 / 在别名表里），
//      而这个键在 UserDefaults 里从没被写过。
//      那是读错存储：永远返回 nil，静默落到默认值。
//      （第52轮就是这样：预检读 control.default_ctrl 读到默认值，
//        用户换布局就误报「文件不存在」。）

const fs = require('fs');
const path = require('path');

const SRC = 'D:\\ios-zl2\\src';
const CORE = 'D:\\ios-zl2\\core';

function readAll(dir, exts) {
  const out = [];
  for (const f of fs.readdirSync(dir)) {
    const full = path.join(dir, f);
    const st = fs.statSync(full);
    if (st.isDirectory()) continue;
    if (!exts.some(e => f.endsWith(e))) continue;
    out.push({ name: f, text: fs.readFileSync(full, 'utf8') });
  }
  return out;
}

const swiftFiles = readAll(SRC, ['.swift']);
const coreFiles = readAll(CORE, ['.m', '.h']);

// ---- 1. Swift 侧：写 UserDefaults 的键 ----
const udWrites = new Map();   // key -> [file:line]
// 也统计 Swift 侧有没有通过 setPrefObject / resolve 方式写同一个键
const prefWrites = new Set();

for (const f of swiftFiles) {
  const lines = f.text.split('\n');
  lines.forEach((line, i) => {
    // UserDefaults.standard.set(..., forKey: "X")
    let m = line.match(/UserDefaults\.standard\.set\([^)]*forKey:\s*"([^"]+)"\)/);
    if (m) {
      const k = m[1];
      if (!udWrites.has(k)) udWrites.set(k, []);
      udWrites.get(k).push(`${f.name}:${i + 1}`);
    }
    // setPrefObject("X", ...)
    m = line.match(/setPref(?:Object|Bool|Int|Float)\(\s*"([^"]+)"/);
    if (m) prefWrites.add(m[1]);
  });
}

// ---- 2. 核心侧：真正读的键 ----
const coreReads = new Map();  // key -> [file:line]
for (const f of coreFiles) {
  const lines = f.text.split('\n');
  lines.forEach((line, i) => {
    let m;
    // getPrefObject / getPrefBool / getPrefInt / getPrefFloat
    const re1 = /getPref(?:Object|Bool|Int|Float)\(@?"([^"]+)"/g;
    while ((m = re1.exec(line)) !== null) {
      if (!coreReads.has(m[1])) coreReads.set(m[1], []);
      coreReads.get(m[1]).push(`${f.name}:${i + 1}`);
    }
    // resolveKeyForCurrentProfile:@"X"
    const re2 = /resolveKeyForCurrentProfile:@?"([^"]+)"/g;
    while ((m = re2.exec(line)) !== null) {
      if (!coreReads.has(m[1])) coreReads.set(m[1], []);
      coreReads.get(m[1]).push(`${f.name}:${i + 1}`);
    }
    // profile[@"X"] / selectedProfile[@"X"]
    const re3 = /(?:selectedProfile|profile)\[@"([^"]+)"\]/g;
    while ((m = re3.exec(line)) !== null) {
      if (!coreReads.has(m[1])) coreReads.set(m[1], []);
      coreReads.get(m[1]).push(`${f.name}:${i + 1}`);
    }
  });
}

// ---- 2.5 别名表 ----
// 来自 core/PLProfiles.m:50 的 prefDefaults 字典：
// resolveKey 在 profile 里找不到时，会去 getPrefObject(右边这个键)。
// 不识破这层映射，审计就会把「写了右边的键」误判成「没写」。
const ALIAS = {
  'defaultTouchCtrl': 'control.default_ctrl',
  'defaultGamepadCtrl': 'control.default_gamepad_ctrl',
  'javaArgs': 'java.java_args',
  'renderer': 'video.renderer',
};

// ---- 3. 对撞 ----
// 只看「Swift 写了 UserDefaults，但从没用 setPref* 写过」的键
const suspicious = [];
for (const [key, where] of udWrites) {
  if (prefWrites.has(key)) continue;          // 已经同时写核心了
  if (key.startsWith('zl.')) continue;        // zl. 前缀是本 App 私有的
  if (key.startsWith('zl2.')) continue;
  // 核心是不是在读同名或语义对应的键？
  const coreHit = [];
  let handledByPref = false;
  for (const [ck, cw] of coreReads) {
    let hit = false;
    if (ck === key) hit = true;
    else {
      // 语义对应：核心的 X.Y 形式 vs Swift 的 X 或 Y
      const parts = ck.split('.');
      if (parts.length === 2 && (parts[1] === key || parts[0] === key)) hit = true;
    }
    if (!hit) continue;
    coreHit.push(`${ck} @ ${cw.join(', ')}`);
    // 只要对应的核心键已经被 setPref* 写过，这条就不算漏
    if (prefWrites.has(ck)) handledByPref = true;
    // 别名：核心读 "renderer"，实际落地在 "video.renderer"
    const alias = ALIAS[ck];
    if (alias && prefWrites.has(alias)) handledByPref = true;
  }
  if (coreHit.length && !handledByPref) suspicious.push({ key, uw: where, ch: coreHit });
}

console.log(`Swift 写 UserDefaults 的键：${udWrites.size} 个`);
console.log(`核心读偏好/资料的键：${coreReads.size} 个`);
console.log('');

if (suspicious.length === 0) {
  console.log('✓ 没有发现「只写 UserDefaults 而核心在读」的键');
  // 注意：这里**不能** process.exit —— 后面的反方向检查还没跑。
}

if (suspicious.length > 0) {
  console.log(`⚠ 可疑（${suspicious.length} 个）—— Swift 只写了 UserDefaults，核心在别处读：`);
  for (const s of suspicious) {
    console.log(`\n  [${s.key}]`);
    console.log(`    Swift 写入： ${s.uw.join(', ')}`);
    console.log(`    核心读取： ${s.ch.join(' | ')}`);
  }
  console.log('');
  console.log('（提示：若该键确为本 App 私有，加 zl. / zl2. 前缀即可免于报警）');
}

// ---- 4. 反方向：Swift 从 UserDefaults **读**一个从没人往里写的键 ----
//
// 这是第52轮踩到的坑：预检里写了
//     UserDefaults.standard.string(forKey: "control.default_ctrl") ?? "default"
// 但这个键只存在核心的 plist（setPrefObject），UserDefaults 里根本没有它 ——
// 读取永远返回 nil，静默落到默认值。表现是「检查项永远只看默认布局」，
// 用户换了布局就误报，而且不报错。
//
// 判据（低误报）：**读了、但全项目没有任何地方用 UserDefaults 写它**。
// 如果它是核心拥有的键（核心在读 / 别名表里有），那就是铁定的读错存储。
const udReads = new Map();   // key -> [file:line]
for (const f of swiftFiles) {
  const lines = f.text.split('\n');
  lines.forEach((line, i) => {
    const re = /UserDefaults\.standard\.(?:string|bool|integer|double|float|object|array|dictionary|data|url|value)\(forKey:\s*"([^"]+)"\)/g;
    let m;
    while ((m = re.exec(line)) !== null) {
      const k = m[1];
      if (!udReads.has(k)) udReads.set(k, []);
      udReads.get(k).push(`${f.name}:${i + 1}`);
    }
  });
}

const coreOwned = new Set([...coreReads.keys(), ...Object.values(ALIAS), ...Object.keys(ALIAS)]);

const readOrphans = [];
for (const [key, where] of udReads) {
  if (udWrites.has(key)) continue;        // 有人写过 → 正常
  const owned = coreOwned.has(key);
  readOrphans.push({ key, where, owned });
}

const ownedBad = readOrphans.filter(x => x.owned);
const plainBad = readOrphans.filter(x => !x.owned);

if (ownedBad.length) {
  console.log('');
  console.log(`⚠ ${ownedBad.length} 处「从 UserDefaults 读核心拥有的键」（铁定读错存储）：`);
  for (const x of ownedBad) {
    console.log(`\n  [${x.key}]`);
    console.log(`    Swift 读取： ${x.where.join(', ')}`);
    console.log(`    这个键存在核心的 plist 里，UserDefaults 中永远没有 → 读到的永远是默认值`);
    console.log(`    正确做法：CoreBridge 里的 getPref* / 或现成的解析入口（如 CoreLayoutExporter.coreActiveLayoutName）`);
  }
}

if (plainBad.length) {
  console.log('');
  console.log(`· ${plainBad.length} 处「读了 UserDefaults 但没人写」的键（可能只是默认值，人工确认）：`);
  for (const x of plainBad) {
    console.log(`    [${x.key}]  ${x.where.join(', ')}`);
  }
}

if (!ownedBad.length && !plainBad.length) {
  console.log('✓ 没有「读了 UserDefaults 但没人写」的键');
}

console.log('');
process.exit(ownedBad.length === 0 ? 0 : 1);
