// ⚠️ 已退役（2026-11-08）—— 别跑这个脚本。
// 它验证的是**已废弃的 FNV 哈希**伪键码方案（encode(uuid) → hash % 900000），
// 而 LayerPseudoKey 现在用的是顺序编号 encode(index:action:) = threshold - action*1000 - (index+1)，
// 完全不哈希。跑这个脚本会输出一堆 ✅，但验证的东西已经不存在了。
// 现行版本的测试是 _test-pseudo-v2.js。
// 保留它只因为「为什么放弃哈希」这个结论值得留档（图层只有 2~5 个，
// 不需要百万桶，哈希碰撞 9% 是自找麻烦）。
// 验证 LayerPseudoKey 的哈希算法：确定性、无碰撞、落在正确区间

function encode(uuid) {
  if (!uuid) return null;
  let hash = 2166136261 >>> 0;          // FNV offset basis
  for (const ch of Buffer.from(uuid, 'utf8')) {
    hash ^= ch;
    hash = Math.imul(hash, 16777619) >>> 0;  // FNV prime, 32位
  }
  const offset = (hash % 900000) >>> 0;
  return -1000 - offset;
}

// 核心占用的区间：-1 ~ -9
const CORE_TAKEN = new Set([-1,-2,-3,-4,-5,-6,-7,-8,-9]);

console.log('=== 1. 确定性（同一 uuid 多次计算结果一致）===');
const sample = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
const r1 = encode(sample), r2 = encode(sample), r3 = encode(sample);
console.log(`  ${sample}`);
console.log(`  → ${r1} / ${r2} / ${r3}  ${r1===r2 && r2===r3 ? '✅ 一致' : '❌ 不一致'}`);

console.log('\n=== 2. 区间正确（必须 <= -1000，避开核心的 -1~-9）===');
const uuids = [
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  'ffffffff-ffff-ffff-ffff-ffffffffffff',
  '00000000-0000-0000-0000-000000000000',
  'layer-main-uuid-1111',
  'layer-bag-uuid-2222',
];
let allOk = true;
for (const u of uuids) {
  const k = encode(u);
  const ok = k <= -1000 && !CORE_TAKEN.has(k);
  if (!ok) allOk = false;
  console.log(`  ${u.padEnd(40)} → ${String(k).padStart(8)}  ${ok ? '✅' : '❌'}`);
}

console.log('\n=== 3. 碰撞测试（10 万个随机 uuid）===');
function randomUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}
const N = 100000;
const seen = new Map();
let collisions = 0;
for (let i = 0; i < N; i++) {
  const u = randomUUID();
  const k = encode(u);
  if (seen.has(k)) collisions++;
  else seen.set(k, u);
}
console.log(`  ${N} 个 uuid，碰撞 ${collisions} 次`);
console.log(`  碰撞率 ${(collisions / N * 100).toFixed(3)}%`);
console.log(`  ${collisions === 0 ? '✅ 无碰撞' : collisions < N * 0.001 ? '✅ 碰撞率可接受' : '⚠ 碰撞偏多'}`);

console.log('\n=== 4. 空值处理 ===');
console.log(`  encode('') → ${encode('')}  ${encode('') === null ? '✅ 返回 null' : '❌'}`);

console.log('\n=== 总结 ===');
console.log(`  区间正确: ${allOk ? '✅' : '❌'}`);
console.log(`  确定性:   ${r1===r2 && r2===r3 ? '✅' : '❌'}`);
console.log(`  碰撞率:   ${(collisions/N*100).toFixed(3)}%`);
