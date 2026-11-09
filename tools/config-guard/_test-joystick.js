// 验证方向键码生成逻辑
// ZL2 默认绑定 → 核心的 32 个整数数组

const KEY = { W: 87, A: 65, S: 83, D: 68 };

// ZL2 默认方向事件（来自 ZLJoystickDefaults）
const defaults = {
  north:     ['GLFW_KEY_W'],
  north_east:['GLFW_KEY_W', 'GLFW_KEY_D'],
  north_west:['GLFW_KEY_W', 'GLFW_KEY_A'],
  south:     ['GLFW_KEY_S'],
  south_east:['GLFW_KEY_S', 'GLFW_KEY_D'],
  south_west:['GLFW_KEY_S', 'GLFW_KEY_A'],
  east:      ['GLFW_KEY_D'],
  west:      ['GLFW_KEY_A'],
};

// 核心方向编号顺序
const ORDER = ['east','north_east','north','north_west','west','south_west','south','south_east'];

function codeOf(name) {
  const k = name.replace('GLFW_KEY_','');
  return KEY[k] || 0;
}

function buildDirectionKeycodes(events) {
  const out = new Array(32).fill(0);
  ORDER.forEach((dir, idx) => {
    const list = events[dir];
    if (!list) return;
    let slot = 0;
    for (const n of list) {
      if (slot >= 4) break;
      const c = codeOf(n);
      if (c > 0) { out[idx*4+slot] = c; slot++; }
    }
  });
  return out;
}

const result = buildDirectionKeycodes(defaults);

console.log('=== 32 个方向键码 ===');
const dirNames = ['EAST','NE','NORTH','NW','WEST','SW','SOUTH','SE'];
for (let i = 0; i < 8; i++) {
  const slots = result.slice(i*4, i*4+4);
  const readable = slots.map(c => {
    for (const [k,v] of Object.entries(KEY)) if (v === c) return k;
    return c === 0 ? '-' : c;
  }).join(',');
  console.log(`  ${String(i)} ${dirNames[i].padEnd(6)} → [${slots.join(',')}]  ${readable}`);
}

console.log('\n=== 正确性检查 ===');
const checks = [
  [2, 0, 87, '北 → W'],
  [1, 0, 87, '东北 → W'],
  [1, 1, 68, '东北 → D'],
  [5, 0, 83, '西南 → S'],
  [5, 1, 65, '西南 → A'],
  [0, 0, 68, '东 → D'],
  [4, 0, 65, '西 → A'],
];
let pass = 0, fail = 0;
for (const [dir, slot, expect, desc] of checks) {
  const got = result[dir*4+slot];
  if (got === expect) { pass++; console.log(`  ✅ ${desc}`); }
  else { fail++; console.log(`  ❌ ${desc}  期望 ${expect} 实际 ${got}`); }
}

console.log(`\n  通过 ${pass} / ${pass+fail}`);
console.log(`  数组长度: ${result.length}  ${result.length === 32 ? '✅' : '❌'}`);

// 检查是否有遗漏（非零元素个数）
const nonZero = result.filter(x => x !== 0).length;
console.log(`  非零槽位: ${nonZero} 个（8 方向 × 平均 1.5 键 ≈ 12）`);
