// 版本比较逻辑仿真 —— 逐条复刻 ZLUpdate.swift 里的 extractBuild / normalize / isNewer
// 目标：证明「检查更新」不会误报，也不会漏报。

function extractBuild(s) {
  const lower = String(s).toLowerCase();
  const idx = lower.indexOf('build');
  if (idx >= 0) {
    const tail = lower.slice(idx + 'build'.length);
    const m = tail.match(/^[^0-9]*(\d+)/);
    if (m) return parseInt(m[1], 10);
  }
  // 退回：取最后一段纯数字
  const parts = lower.split(/[^0-9]+/).filter(Boolean);
  return parts.length ? parseInt(parts[parts.length - 1], 10) : null;
}

function normalize(s) {
  let t = String(s).trim();
  if (t.toLowerCase().startsWith('v')) t = t.slice(1);
  t = t.split('').filter(c => /[0-9.]/.test(c)).join('');
  while (t.startsWith('.')) t = t.slice(1);
  while (t.endsWith('.')) t = t.slice(0, -1);
  return t === '' ? '0' : t;
}

function semverNewer(remote, current) {
  const r = normalize(remote).split('.').map(Number).filter(n => !isNaN(n));
  const c = normalize(current).split('.').map(Number).filter(n => !isNaN(n));
  const n = Math.max(r.length, c.length);
  for (let i = 0; i < n; i++) {
    const rv = i < r.length ? r[i] : 0;
    const cv = i < c.length ? c[i] : 0;
    if (rv > cv) return true;
    if (rv < cv) return false;
  }
  return false;
}

function isNewer(remote, remoteBuild, current, currentBuild) {
  const rb = remoteBuild === null || remoteBuild === undefined ? null : remoteBuild;
  const cb = currentBuild === null || currentBuild === undefined ? null : currentBuild;
  if (rb !== null && cb !== null) return rb > cb;
  return semverNewer(remote, current);
}

// ---- 测试用例 ----
let pass = 0, fail = 0;
function eq(label, got, want) {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (ok) { pass++; } else { fail++; console.log(`  [FAIL] ${label}: 得到 ${JSON.stringify(got)}，期望 ${JSON.stringify(want)}`); }
}

console.log('=== extractBuild ===');
eq('build-236', extractBuild('build-236'), 236);
eq('Build 236', extractBuild('Build 236'), 236);
eq('build/7', extractBuild('build/7'), 7);
eq('BUILD-1000', extractBuild('BUILD-1000'), 1000);
eq('v1.0.236', extractBuild('v1.0.236'), 236);
eq('ZL2 构建 #88', extractBuild('ZL2 构建 #88'), 88);
eq('无数字', extractBuild('hello'), null);

console.log('=== normalize ===');
eq('v0.2.1', normalize('v0.2.1'), '0.2.1');
eq('1.0.236', normalize('1.0.236'), '1.0.236');
eq('空串', normalize(''), '0');
eq('多余点', normalize('..1..'), '1');

console.log('=== isNewer：build 号优先（真实场景）===');
// 用户在 build 100，线上是 build 236
eq('100 -> 236 应提示更新', isNewer('build-236', 236, '1.0.100', 100), true);
// 用户在 build 236，线上也是 236
eq('236 -> 236 不应提示', isNewer('build-236', 236, '1.0.236', 236), false);
// 用户在 build 300（比线上还新，比如本地自编译）
eq('300 -> 236 不应提示', isNewer('build-236', 236, '1.0.300', 300), false);

console.log('=== 关键回归：旧逻辑的误报 ===');
// 旧逻辑：normalize("build-236") = "236"，与 "0.1.0" 比较 -> 236 > 0 -> 永远提示更新
// 新逻辑用 build 号，同样场景应给出正确结论
eq('旧误报场景已修复', isNewer('build-236', 236, '0.1.0', 1), true); // build 1 -> 236，确实该更新
// 但如果用户已经在最新版，绝不能提示
eq('同版本不误报', isNewer('build-236', 236, '1.0.236', 236), false);

console.log('=== 语义化版本回退路径 ===');
eq('无 build 时 0.2.0 > 0.1.0', isNewer('v0.2.0', null, '0.1.0', null), true);
eq('无 build 时 0.1.0 == 0.1.0', isNewer('v0.1.0', null, '0.1.0', null), false);
eq('位数不同 1.0 vs 1.0.0', isNewer('1.0', null, '1.0.0', null), false);
eq('1.0.1 > 1.0', isNewer('1.0.1', null, '1.0', null), true);

console.log('=== 单边有 build 时退回语义化 ===');
eq('remote 有 build 但 current 无', isNewer('1.0.5', 5, '1.0.3', null), true);

console.log('');
console.log(`结果：通过 ${pass}，失败 ${fail}`);
process.exit(fail === 0 ? 0 : 1);
