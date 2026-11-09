// 验证带动作类型的伪键码方案
const THRESHOLD = -1000;

function encode(index, action) {
  // action: 1=switch, 2=show, 3=hide
  return THRESHOLD - action * 1000 - (index + 1);
}

function decode(pseudo) {
  if (pseudo > THRESHOLD) return null;
  const offset = THRESHOLD - pseudo;
  const actionRaw = Math.floor(offset / 1000);
  const index = (offset % 1000) - 1;
  if (index < 0) return null;
  return { action: actionRaw, index };
}

console.log('=== 编码示例 ===');
const names = { 1: 'switch', 2: 'show', 3: 'hide' };
for (const a of [1, 2, 3]) {
  for (const i of [0, 1, 2]) {
    const p = encode(i, a);
    const d = decode(p);
    const ok = d && d.action === a && d.index === i;
    console.log(`  ${names[a].padEnd(7)} 第${i}层 → ${String(p).padStart(6)}  解码 ${ok ? '✅' : '❌ ' + JSON.stringify(d)}`);
  }
}

console.log('\n=== 往返一致性（3 动作 × 100 层）===');
let ok = true, cnt = 0;
for (let a = 1; a <= 3; a++) {
  for (let i = 0; i < 100; i++) {
    const p = encode(i, a);
    const d = decode(p);
    cnt++;
    if (!d || d.action !== a || d.index !== i) { ok = false; console.log(`  FAIL a=${a} i=${i} p=${p} d=${JSON.stringify(d)}`); }
  }
}
console.log(`  ${cnt} 组往返：${ok ? '✅ 全部一致' : '❌ 有错误'}`);

console.log('\n=== 区间检查（必须 < -1000，避开核心 -1~-9）===');
const all = [];
for (let a = 1; a <= 3; a++) for (let i = 0; i < 10; i++) all.push(encode(i, a));
const min = Math.min(...all), max = Math.max(...all);
console.log(`  取值范围：${max} 到 ${min}`);
console.log(`  ${max < -1000 ? '✅ 全部低于 -1000' : '❌ 有越界'}`);

console.log('\n=== 非法输入 ===');
console.log(`  decode(-500)  → ${JSON.stringify(decode(-500))}  ${decode(-500)===null?'✅':'❌'}`);
console.log(`  decode(-999)  → ${JSON.stringify(decode(-999))}  ${decode(-999)===null?'✅':'❌'}`);

console.log('\n=== 与更早方案的差异（历史说明，非当前告警）===');
// 最早只有 switch 一种动作，编码是 -1000-(index+1) = -1001/-1002；
// 引入 show/hide 之后统一成 threshold - action*1000 - (index+1)，
// 于是 switch 变成 -2001/-2002。这是**已经完成的一次性迁移**，
// 不是本次运行发现的新变化 —— 当年迁移时要求布局重新导出过一次，
// 现在的新布局都是新编码，不需要再做什么。
console.log('  最早（仅 switch）: -1001 / -1002');
console.log('  现在（switch）    : ' + encode(0,1) + ' / ' + encode(1,1));
console.log('  → 历史迁移已完成；当前导出的布局都是新编码，无需再处理');
