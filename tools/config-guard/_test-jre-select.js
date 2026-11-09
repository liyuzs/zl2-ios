// getSelectedJavaHome 的完整仿真
//
// 复刻 core/LauncherPreferences.m:101 的逻辑，配合 CoreBridge.bootstrap 写入的
// java_homes 映射，验证「每个 MC 版本最终会挑到哪套 JRE」。
//
// 为什么必须仿真：这段逻辑跨了 Swift（写映射）和 ObjC（读映射 + 向上调），
// 中间靠一个字典约定相连。写错一个值，表现是「游戏启动黑屏/崩溃」，
// 而且只有真机跑起来才看得到。

const BUNDLED = [8, 17, 21, 25];   // 包里实际带的（Java 8 其实没带，见下）

// CoreBridge.bootstrap 写入的映射（修复后）
const HOMES_FIXED = {
  '0': { '1_17_newer': '17', '1_16_5_older': '8', 'execute_jar': '17' },
  '8': 'internal', '17': 'internal', '21': 'internal', '25': 'internal',
};

// 修复前的映射（保留用于回归对比）
const HOMES_OLD = {
  '0': { '1_17_newer': '21', '1_16_5_older': '8', 'execute_jar': '17' },
  '8': 'internal', '17': 'internal', '21': 'internal', '25': 'internal',
};

// IPA 里实际只有 17 / 21 / 25 三套，没有 Java 8（这点很关键：+java-8-openjdk+ 目录不存在）
const BUNDLED_DIRS = ['17', '21', '25'];

// 复刻 getSelectedJavaHome
function getSelectedJavaHome(pref, defaultJRETag, minVersion) {
  const selected = pref['0'];
  let selectedVer = selected[defaultJRETag];
  if (minVersion > parseInt(selectedVer, 10)) {
    const allKeys = Object.keys(pref).map(k => parseInt(k, 10)).filter(n => !isNaN(n));
    allKeys.sort((a, b) => a - b);
    let found = null;
    for (const v of allKeys) {
      if (v >= minVersion) { found = String(v); break; }
    }
    selectedVer = found;
    if (!selectedVer) return null;
  }
  const dir = pref[selectedVer];
  const path = dir === 'internal'
    ? `bundle/java_runtimes/java-${selectedVer}-openjdk`
    : `${dir}`;
  // 文件系统检查
  if (BUNDLED_DIRS.includes(selectedVer)) return path;
  return null;
}

// 复刻 CoreBridge.requiredJavaVersion（修复后）
function requiredJavaVersion(id) {
  const parts = String(id).split('.');
  if (parts.length >= 2) {
    const ma = parseInt(parts[0], 10), mi = parseInt(parts[1], 10);
    if (!isNaN(ma) && !isNaN(mi)) {
      if (ma === 1) {
        if (mi >= 21) return 21;
        if (mi === 20) {
          const patch = parts.length >= 3 ? (parseInt(parts[2], 10) || 0) : 0;
          return patch >= 5 ? 21 : 17;
        }
        if (mi >= 17) return 17;
        if (mi >= 12) return 17;
        return 8;
      }
      if (ma >= 26) return 25;
      if (ma >= 22) return 25;
    }
  }
  return 17;
}

// 完整链路：MC 版本 → minJava → 最终 JRE
function pickJRE(pref, mcId) {
  const minJava = requiredJavaVersion(mcId);
  const tag = minJava <= 8 ? '1_16_5_older' : '1_17_newer';
  const home = getSelectedJavaHome(pref, tag, minJava);
  if (home === null) return { minJava, ver: null, home: null };
  const m = home.match(/java-(\d+)-openjdk/);
  return { minJava, ver: m ? parseInt(m[1], 10) : null, home };
}

let pass = 0, fail = 0;
function eq(label, got, want) {
  if (got === want) pass++;
  else { fail++; console.log(`  [FAIL] ${label}: 得到 ${got}，期望 ${want}`); }
}

// 期望的 JRE：必须 >= 该版本要求的 Java，且不能高出太多（高出会崩）
const EXPECT = [
  ['1.16.5', 17], ['1.17',   17], ['1.17.1', 17], ['1.18.2', 17], ['1.19.4', 17],
  ['1.20',   17], ['1.20.1', 17], ['1.20.2', 17], ['1.20.4', 17],   // ← 关键回归
  ['1.20.5', 21], ['1.20.6', 21],
  ['1.21',   21], ['1.21.4', 21],
  ['26.1',   25],
];

console.log('=== 修复后：每个版本挑到的 JRE ===');
EXPECT.forEach(([mc, want]) => {
  const r = pickJRE(HOMES_FIXED, mc);
  eq(`${mc} -> Java ${want}`, r.ver, want);
});

console.log('=== 回归对比：修复前 1.17~1.20.4 全被拉去 Java 21 ===');
[['1.17', 21], ['1.20.1', 21], ['1.20.4', 21]].forEach(([mc, oldVer]) => {
  const r = pickJRE(HOMES_OLD, mc);
  if (r.ver === oldVer) {
    pass++;
    console.log(`  （确认旧逻辑确实会挑 ${oldVer}：${mc}）`);
  } else {
    fail++;
    console.log(`  [FAIL] 旧逻辑在 ${mc} 上挑到 ${r.ver}，与预期的 ${oldVer} 不符`);
  }
});

console.log('=== 不变量：挑到的 JRE 必须 >= minJava（否则核心会报缺运行时）===');
EXPECT.forEach(([mc]) => {
  const r = pickJRE(HOMES_FIXED, mc);
  if (r.ver !== null && r.ver >= r.minJava) pass++;
  else { fail++; console.log(`  [FAIL] ${mc}: minJava=${r.minJava} 但挑到 ${r.ver}`); }
});

console.log('=== 不变量：挑到的 JRE 不能比 minJava 高出一代以上（高出会崩）===');
EXPECT.forEach(([mc]) => {
  const r = pickJRE(HOMES_FIXED, mc);
  const over = r.ver !== null && r.ver > r.minJava;
  if (!over) pass++;
  else { fail++; console.log(`  [FAIL] ${mc}: minJava=${r.minJava} 却挑到更高的 ${r.ver}`); }
});

console.log('=== ≤1.11 必须失败（包里没有 Java 8）===');
[['1.11.2'], ['1.8.9']].forEach(([mc]) => {
  const r = pickJRE(HOMES_FIXED, mc);
  eq(`${mc} 应无可用运行时`, r.home, null);
});

console.log('');
console.log(`结果：通过 ${pass}，失败 ${fail}`);
process.exit(fail === 0 ? 0 : 1);
