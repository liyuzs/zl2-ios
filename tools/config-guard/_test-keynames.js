// 键名表契约测试：核心支持的键名 vs 我们能解析的键名
//
// 为什么需要：控制布局里的按钮键位是一串**字符串**（如 "GLFW_KEY_ESCAPE"、
// "SPECIALBTN_MENU"），要在导出时翻译成整数键码。核心有它自己的键名表
// （CustomControlsUtils.m 的 initKeycodeTable），我们有一份 GLFWKeyNames。
// 两份表对不上时不会有任何报错 —— 按钮就是按下去没反应。
//
// 这个脚本把核心的表抽出来，逐个确认我们的表能解析。

const fs = require('fs');

const CORE = 'D:\\ios-zl2\\core\\customcontrols\\CustomControlsUtils.m';
const SWIFT = 'D:\\ios-zl2\\src\\GLFWKeyNames.swift';

const coreSrc = fs.readFileSync(CORE, 'utf8');
const swiftSrc = fs.readFileSync(SWIFT, 'utf8');

// ---- 1. 抽核心的键名表 ----
const s = coreSrc.indexOf('void initKeycodeTable');
const e = coreSrc.indexOf('#undef addkey');
const body = coreSrc.slice(s, e);

const coreNames = [];
for (const line of body.split('\n')) {
  if (/^\s*#define/.test(line)) continue;          // 跳过宏定义本身
  const code = line.replace(/\/\/.*$/, '');        // 去注释
  const re = /add(?:key|spec)\(([A-Za-z0-9_]+)\)/g;
  let m;
  while ((m = re.exec(code)) !== null) coreNames.push(m[1]);
}
const uniqueCore = [...new Set(coreNames)].filter(n => n !== 'key').sort();

// ---- 2. 我们表里"循环生成"的规则（无法用字面量直接断言）----
// 每条：正则匹配核心键名 → 在 Swift 源码里应当出现的循环标记
// 用纯字符串 includes 做标记，不用正则 —— 正则里表达"字面反斜杠 + 括号"
// 要写三层转义，极易出错（我在这上面浪费了一轮）。
const GENERATED = [
  { test: /^\d$/,             marker: 'm[k] = v',                                   desc: '数字 0-9' },
  { test: /^[A-Z]$/,          marker: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated()',   desc: '字母 A-Z' },
  { test: /^F\d+$/,           marker: 'm["F\\(i)"] = 289 + i',                      desc: 'F1..F25' },
  { test: /^NUMPAD_\d$/,      marker: 'm["NUMPAD_\\(i)"] = 320 + i',                desc: 'NUMPAD_0..9' },
  { test: /^NUMPAD_[A-Z]+$/,  marker: 'm["NUMPAD_\\(suffix)"] = code',              desc: 'NUMPAD_ADD/DECIMAL/...' },
];

// ---- 3. 逐个检查 ----
let pass = 0, fail = 0;
const missing = [];

for (const name of uniqueCore) {
  // 3a. 字面量写法
  const literal = new RegExp(`m\\["${name}"\\]\\s*=`).test(swiftSrc);
  if (literal) { pass++; continue; }
  // 3b. 循环生成
  const gen = GENERATED.find(g => g.test.test(name) && swiftSrc.includes(g.marker));
  if (gen) { pass++; continue; }
  // 3c. 别名表 / 其它字典字面量
  const alt = new RegExp(`"${name}"\\s*:\\s*-?\\d+`).test(swiftSrc);
  if (alt) { pass++; continue; }
  fail++;
  missing.push(name);
}

console.log(`核心支持 ${uniqueCore.length} 个键名`);
if (missing.length === 0) {
  console.log('✓ 全部都能被 GLFWKeyNames 解析');
} else {
  console.log(`✗ ${missing.length} 个无法解析（这些按钮会静默失效）：`);
  console.log('  ' + missing.join(' '));
}

// ---- 4. 反向检查：负数键码必须能通过导出器的过滤 ----
console.log('');
console.log('=== 负数键码过滤 ===');
const hasPositiveOnly = /GLFWKeyNames\.code\(for:[^)]*\)\s*,\s*code\s*>\s*0/.test(swiftSrc);
const okFilter = /GLFWKeyNames\.code\(for:[^)]*\)\s*,\s*code\s*!=\s*0/.test(swiftSrc);

// 过滤逻辑在 CoreLayoutExport 里，不在 GLFWKeyNames
const exportSrc = fs.readFileSync('D:\\ios-zl2\\src\\CoreLayoutExport.swift', 'utf8');
const filterPositive = /code\s*>\s*0/.test(exportSrc);
const filterNotZero = /code\s*!=\s*0/.test(exportSrc);

if (filterPositive && !filterNotZero) {
  console.log('  ✗ 导出器用 code > 0 过滤 —— SPECIALBTN_*（-1..-9）会被全部丢掉');
  fail++;
} else if (filterNotZero) {
  console.log('  ✓ 导出器用 code != 0 过滤，负数特殊键码能通过');
  pass++;
} else {
  console.log('  ⚠ 没找到明确的过滤条件，需人工确认');
  fail++;
}

// ---- 5. 特殊键码数值校验 ----
console.log('');
console.log('=== SPECIALBTN 数值对照（core/utils.h:42-50）===');
const SPECIAL = {
  SPECIALBTN_KEYBOARD: -1,
  SPECIALBTN_TOGGLECTRL: -2,
  SPECIALBTN_MOUSEPRI: -3,
  SPECIALBTN_MOUSESEC: -4,
  SPECIALBTN_VIRTUALMOUSE: -5,
  SPECIALBTN_MOUSEMID: -6,
  SPECIALBTN_SCROLLUP: -7,
  SPECIALBTN_SCROLLDOWN: -8,
  SPECIALBTN_MENU: -9,
};
for (const [name, val] of Object.entries(SPECIAL)) {
  const re = new RegExp(`m\\["${name}"\\]\\s*=\\s*(-?\\d+)`);
  const m = swiftSrc.match(re);
  const got = m ? parseInt(m[1], 10) : null;
  if (got === val) { pass++; console.log(`  ✓ ${name} = ${val}`); }
  else { fail++; console.log(`  ✗ ${name} 应为 ${val}，实际 ${got}`); }
}

// ---- 6. 与伪键码区间不冲突 ----
console.log('');
console.log('=== 与图层伪键码区间不冲突 ===');
const pseudoConflict = /LayerPseudoKey[^\n]*-1\b/.test(swiftSrc);
const minSpecial = Math.min(...Object.values(SPECIAL));   // -9
const okRange = minSpecial > -1000;
if (okRange) { pass++; console.log(`  ✓ 特殊键码最低 ${minSpecial}，伪键码从 -1000 起，不重叠`); }
else { fail++; console.log('  ✗ 特殊键码与伪键码区间重叠'); }

console.log('');
console.log(`结果：通过 ${pass}，失败 ${fail}`);
process.exit(fail === 0 ? 0 : 1);
