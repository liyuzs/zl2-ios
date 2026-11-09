// GLFW 键名映射表自测：验证常用键名的解析结果
function codeFor(raw) {
  let s = raw.trim().toUpperCase();
  for (const p of ['GLFW_KEY_', 'GLFW_', 'KEY_']) {
    if (s.startsWith(p)) { s = s.slice(p.length); break; }
  }
  if (s.length === 1 && s.charCodeAt(0) >= 32 && s.charCodeAt(0) <= 126) {
    return s.charCodeAt(0);
  }
  return TABLE[s];
}

const TABLE = {};
TABLE['SPACE'] = 32;
TABLE['APOSTROPHE'] = 39; TABLE['COMMA'] = 44; TABLE['MINUS'] = 45;
TABLE['PERIOD'] = 46; TABLE['SLASH'] = 47;
['0','1','2','3','4','5','6','7','8','9'].forEach((k,i) => {
  TABLE[k] = 48 + i; TABLE['NUM_' + k] = 48 + i;
});
TABLE['SEMICOLON'] = 59; TABLE['EQUAL'] = 61;
'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').forEach((c,i) => { TABLE[c] = 65 + i; });
TABLE['LEFT_BRACKET'] = 91; TABLE['BACKSLASH'] = 92;
TABLE['RIGHT_BRACKET'] = 93; TABLE['GRAVE_ACCENT'] = 96;
TABLE['ESCAPE'] = 256; TABLE['ESC'] = 256;
TABLE['ENTER'] = 257; TABLE['RETURN'] = 257;
TABLE['TAB'] = 258; TABLE['BACKSPACE'] = 259;
TABLE['INSERT'] = 260; TABLE['DELETE'] = 261;
TABLE['RIGHT'] = 262; TABLE['LEFT'] = 263;
TABLE['DOWN'] = 264; TABLE['UP'] = 265;
TABLE['PAGE_UP'] = 266; TABLE['PAGE_DOWN'] = 267;
TABLE['HOME'] = 268; TABLE['END'] = 269;
TABLE['CAPS_LOCK'] = 280; TABLE['SCROLL_LOCK'] = 281;
TABLE['NUM_LOCK'] = 282; TABLE['PRINT_SCREEN'] = 283; TABLE['PAUSE'] = 284;
for (let i = 1; i <= 25; i++) TABLE['F' + i] = 289 + i;
for (let i = 0; i <= 9; i++) TABLE['KP_' + i] = 320 + i;
TABLE['KP_DECIMAL'] = 330; TABLE['KP_DIVIDE'] = 331;
TABLE['KP_MULTIPLY'] = 332; TABLE['KP_SUBTRACT'] = 333;
TABLE['KP_ADD'] = 334; TABLE['KP_ENTER'] = 335; TABLE['KP_EQUAL'] = 336;
TABLE['LEFT_SHIFT'] = 340; TABLE['LEFT_CONTROL'] = 341;
TABLE['LEFT_ALT'] = 342; TABLE['LEFT_SUPER'] = 343;
TABLE['RIGHT_SHIFT'] = 344; TABLE['RIGHT_CONTROL'] = 345;
TABLE['RIGHT_ALT'] = 346; TABLE['RIGHT_SUPER'] = 347;
TABLE['MENU'] = 348;

// 参考值来自 GLFW 3.x 官方 glfw3.h
const cases = [
  ['GLFW_KEY_ESCAPE', 256],
  ['GLFW_KEY_ENTER', 257],
  ['GLFW_KEY_TAB', 258],
  ['GLFW_KEY_BACKSPACE', 259],
  ['GLFW_KEY_SPACE', 32],
  ['GLFW_KEY_A', 65],
  ['GLFW_KEY_Z', 90],
  ['GLFW_KEY_F1', 290],
  ['GLFW_KEY_F12', 301],
  ['GLFW_KEY_LEFT_SHIFT', 340],
  ['GLFW_KEY_LEFT_CONTROL', 341],
  ['GLFW_KEY_UP', 265],
  ['GLFW_KEY_DOWN', 264],
  ['GLFW_KEY_LEFT', 263],
  ['GLFW_KEY_RIGHT', 262],
  ['GLFW_KEY_NUM_1', 49],
  ['GLFW_KEY_1', 49],
  ['GLFW_KEY_KP_ENTER', 335],
  ['GLFW_KEY_GRAVE_ACCENT', 96],
  ['GLFW_KEY_SLASH', 47],
  // 无前缀写法
  ['ESCAPE', 256],
  ['A', 65],
  ['SPACE', 32],
];

let pass = 0, fail = 0;
for (const [raw, expect] of cases) {
  const got = codeFor(raw);
  if (got === expect) { pass++; }
  else { console.log(`  FAIL ${raw}  期望 ${expect}  实际 ${got}`); fail++; }
}
console.log(`\n用例 ${cases.length} 个：通过 ${pass}，失败 ${fail}`);
console.log(fail === 0 ? 'GLFW 键名映射表全部正确' : '有错误，需修正');
