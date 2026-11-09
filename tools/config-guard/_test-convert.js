// 模拟一次完整的控制布局转换：ZL2 格式 → Pojav 格式
// 验证 CoreLayoutExporter 的核心换算逻辑

const TABLE = {};
TABLE['SPACE'] = 32; TABLE['ESCAPE'] = 256; TABLE['ENTER'] = 257;
TABLE['TAB'] = 258; TABLE['LEFT_SHIFT'] = 340;
'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').forEach((c, i) => { TABLE[c] = 65 + i; });
for (let i = 1; i <= 25; i++) TABLE['F' + i] = 289 + i;

function codeFor(raw) {
  let s = raw.trim().toUpperCase();
  for (const p of ['GLFW_KEY_', 'GLFW_', 'KEY_']) {
    if (s.startsWith(p)) { s = s.slice(p.length); break; }
  }
  if (s.length === 1 && s.charCodeAt(0) >= 32 && s.charCodeAt(0) <= 126) return s.charCodeAt(0);
  return TABLE[s];
}

function keycodesOf(events) {
  let codes = [];
  for (const ev of events) {
    if (ev.type === 'key') {
      const c = codeFor(ev.value);
      if (c > 0) codes.push(c);
    }
  }
  if (codes.length > 4) codes = codes.slice(0, 4);
  while (codes.length < 4) codes.push(0);
  return codes;
}

function clamp(v, lo, hi) { return Math.min(Math.max(v, lo), hi); }

// 模拟一个放在屏幕中央、88x88 千分比、绑了 Shift 的按钮
const btn = {
  position: { x: 5000, y: 5000 },
  size: { type: 'percentage', widthPercentage: 880, heightPercentage: 880 },
  events: [{ type: 'key', value: 'GLFW_KEY_LEFT_SHIFT' }],
};

const cx = btn.position.x / 10000.0;
const cy = btn.position.y / 10000.0;
const w = btn.size.widthPercentage / 10000.0 * 400.0;
const h = btn.size.heightPercentage / 10000.0 * 400.0;
const keys = keycodesOf(btn.events);

console.log('=== 按钮转换结果 ===');
console.log(`  dynamicX = ${cx}     （期望 0.5 = 屏幕正中）`);
console.log(`  dynamicY = ${cy}     （期望 0.5）`);
console.log(`  width    = ${w.toFixed(1)}dp`);
console.log(`  height   = ${h.toFixed(1)}dp`);
console.log(`  keycodes = [${keys}]  （期望 [340,0,0,0]）`);

console.log('\n=== 多项事件测试 ===');
const multi = { events: [
  { type: 'key', value: 'GLFW_KEY_W' },
  { type: 'key', value: 'GLFW_KEY_LEFT_SHIFT' },
  { type: 'switch_layer', value: 'uuid-xxx' },
]};
console.log(`  输入 W + Shift + 切换图层`);
console.log(`  输出 [${keycodesOf(multi.events)}]  （期望 [87,340,0,0]，图层事件被忽略）`);

console.log('\n=== 校验 ===');
const ok1 = cx === 0.5 && cy === 0.5 && Math.abs(w - 35.2) < 0.1 && keys[0] === 340;
const ok2 = keycodesOf(multi.events)[0] === 87 && keycodesOf(multi.events)[1] === 340;
console.log('  居中定位: ' + (ok1 ? 'OK' : 'FAIL'));
console.log('  多事件解析: ' + (ok2 ? 'OK' : 'FAIL'));
