// ZLRenderers.sanitize 的逻辑仿真
// 目标：证明任何输入都不会产出一个核心 dlopen 不到的名字。
//
// 模拟一个 IPA，投入不同的「包内存在哪些库」组合，逐一验证。

function makeSanitize(existing) {
  const has = (k) => existing.includes(k);
  const GL4ES = 'libgl4es_114.dylib';
  const ANGLE = 'libtinygl4angle.dylib';
  const OSMESA = 'libOSMesa.8.dylib';

  function fallbackKey() {
    if (has(ANGLE)) return ANGLE;
    if (has(GL4ES)) return GL4ES;
    return GL4ES;
  }
  function sanitize(raw) {
    const v = (raw === null || raw === undefined ? '' : String(raw)).trim();
    if (v === '' || v.toLowerCase() === 'auto') return 'auto';
    if (has(v)) return v;
    const lower = v.toLowerCase();
    if (lower.includes('gl4es') && has(GL4ES)) return GL4ES;
    if ((lower.includes('angle') || lower.includes('tinygl')) && has(ANGLE)) return ANGLE;
    if ((lower.includes('mesa') || lower.includes('zink')) && has(OSMESA)) return OSMESA;
    return fallbackKey();
  }
  return sanitize;
}

let pass = 0, fail = 0;
function eq(label, got, want) {
  if (got === want) { pass++; }
  else { fail++; console.log(`  [FAIL] ${label}: 得到 "${got}"，期望 "${want}"`); }
}

// 完整包（三个渲染库都在）
const FULL = ['libgl4es_114.dylib', 'libtinygl4angle.dylib', 'libOSMesa.8.dylib'];
// 精简包（只有 gl4es，模拟最坏情况）
const MINIMAL = ['libgl4es_114.dylib'];
// 半残包
const NO_ANGLE = ['libgl4es_114.dylib', 'libOSMesa.8.dylib'];

console.log('=== 完整包 ===');
let s = makeSanitize(FULL);
eq('空值 -> auto', s(''), 'auto');
eq('null -> auto', s(null), 'auto');
eq('AUTO 大写 -> auto', s('AUTO'), 'auto');
eq('  auto  带空格 -> auto', s('  auto  '), 'auto');
eq('合法 gl4es 原样', s('libgl4es_114.dylib'), 'libgl4es_114.dylib');
eq('合法 angle 原样', s('libtinygl4angle.dylib'), 'libtinygl4angle.dylib');
eq('合法 osmesa 原样', s('libOSMesa.8.dylib'), 'libOSMesa.8.dylib');

console.log('=== 关键回归：MobileGlues 残留 ===');
// 这正是第 18 轮之前会崩的那个值
eq('MobileGlues 回落 ANGLE', s('libmobileglues.dylib'), 'libtinygl4angle.dylib');

console.log('=== 用户手输的常见错法 ===');
eq('"OpenGL" 无法识别 -> 回落 ANGLE', s('OpenGL'), 'libtinygl4angle.dylib');
eq('"gl4es" 短名 -> 完整名', s('gl4es'), 'libgl4es_114.dylib');
eq('"GL4ES" 大写短名 -> 完整名', s('GL4ES'), 'libgl4es_114.dylib');
eq('"angle" 短名 -> 完整名', s('angle'), 'libtinygl4angle.dylib');
eq('"zink" 短名 -> osmesa', s('zink'), 'libOSMesa.8.dylib');
eq('"mesa" 短名 -> osmesa', s('mesa'), 'libOSMesa.8.dylib');
eq('乱码 -> 回落', s('!!!???'), 'libtinygl4angle.dylib');
eq('路径注入 ../../etc -> 回落', s('../../etc/passwd'), 'libtinygl4angle.dylib');

console.log('=== 精简包（只有 gl4es）===');
s = makeSanitize(MINIMAL);
eq('MobileGlues -> GL4ES', s('libmobileglues.dylib'), 'libgl4es_114.dylib');
eq('angle 短名但包里没有 -> GL4ES', s('angle'), 'libgl4es_114.dylib');
eq('osmesa 全名但包里没有 -> GL4ES', s('libOSMesa.8.dylib'), 'libgl4es_114.dylib');
eq('auto 不受影响', s('auto'), 'auto');

console.log('=== 半残包（无 ANGLE）===');
s = makeSanitize(NO_ANGLE);
eq('未知值 -> 回落 GL4ES', s('whatever'), 'libgl4es_114.dylib');
eq('osmesa 可用则保留', s('libOSMesa.8.dylib'), 'libOSMesa.8.dylib');

console.log('=== 不变量：输出永远是 auto 或真实存在的文件 ===');
const cases = ['', 'auto', 'libmobileglues.dylib', 'OpenGL', 'gl4es', 'angle',
               'zink', 'mesa', 'libOSMesa.8.dylib', 'xxx', '  ', 'AUTO'];
[FULL, MINIMAL, NO_ANGLE].forEach((pkg, i) => {
  const fn = makeSanitize(pkg);
  cases.forEach(c => {
    const out = fn(c);
    const ok = out === 'auto' || pkg.includes(out);
    if (ok) pass++;
    else { fail++; console.log(`  [FAIL] 包${i} 输入"${c}" 输出"${out}" 不在包里！`); }
  });
});

console.log('');
console.log(`结果：通过 ${pass}，失败 ${fail}`);
process.exit(fail === 0 ? 0 : 1);
