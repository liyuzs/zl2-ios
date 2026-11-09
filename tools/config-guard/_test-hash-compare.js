// ⚠️ 已退役（2026-11-08）—— 别跑这个脚本。
// 它验证的是**已废弃的 FNV 哈希**伪键码方案（encode(uuid) → hash % 900000），
// 而 LayerPseudoKey 现在用的是顺序编号 encode(index:action:) = threshold - action*1000 - (index+1)，
// 完全不哈希。跑这个脚本会输出一堆 ✅，但验证的东西已经不存在了。
// 现行版本的测试是 _test-pseudo-v2.js。
// 保留它只因为「为什么放弃哈希」这个结论值得留档（图层只有 2~5 个，
// 不需要百万桶，哈希碰撞 9% 是自找麻烦）。
// 它对比几种哈希方案的碰撞率 —— 那个决策早做完了，结论是「根本不该用哈希」。
// 对比几种哈希方案的碰撞率，选出真正能用的

function fnvMod(uuid) {
  let hash = 2166136261 >>> 0;
  for (const ch of Buffer.from(uuid, 'utf8')) {
    hash ^= ch;
    hash = Math.imul(hash, 16777619) >>> 0;
  }
  return -1000 - (hash % 900000);
}

function fnvMask(uuid) {
  let hash = 2166136261 >>> 0;
  for (const ch of Buffer.from(uuid, 'utf8')) {
    hash ^= ch;
    hash = Math.imul(hash, 16777619) >>> 0;
  }
  // 用低位掩码，2^20 = 1048576，2 的幂没有取模偏差
  return -1000 - (hash & 0xFFFFF);
}

function djb2(uuid) {
  let hash = 5381;
  for (const ch of Buffer.from(uuid, 'utf8')) {
    hash = ((hash * 33) ^ ch) >>> 0;
  }
  return -1000 - (hash & 0xFFFFF);
}

function randomUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = Math.random() * 16 | 0;
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  });
}

const N = 200000;
const samples = Array.from({ length: N }, randomUUID);

function measure(name, fn) {
  const seen = new Set();
  let coll = 0;
  for (const u of samples) {
    const k = fn(u);
    if (seen.has(k)) coll++;
    else seen.add(k);
  }
  const rate = coll / N * 100;
  console.log(`  ${name.padEnd(20)} 碰撞 ${String(coll).padStart(5)} 次  ${rate.toFixed(3)}%  ${rate < 1 ? '✅' : rate < 5 ? '⚠' : '❌'}`);
  return rate;
}

console.log(`=== ${N} 个随机 uuid 对比 ===`);
const a = measure('FNV + 取模 900000', fnvMod);
const b = measure('FNV + 掩码 2^20', fnvMask);
const c = measure('djb2 + 掩码 2^20', djb2);

console.log('\n=== 结论 ===');
const best = [
  ['FNV+取模', a],
  ['FNV+掩码', b],
  ['djb2+掩码', c],
].sort((x, y) => x[1] - y[1]);
console.log(`  最佳方案: ${best[0][0]}  碰撞率 ${best[0][1].toFixed(3)}%`);
console.log(`  理论期望: 200000 个数落进 1048576 个桶，生日悖论估算约 ${(200000*200000/2/1048576/200000*100).toFixed(2)}%`);
