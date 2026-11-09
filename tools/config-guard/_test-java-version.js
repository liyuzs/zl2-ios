// requiredJavaVersion 的逻辑仿真（v2，对齐 1.20.5 分界修复）
// 逐条复刻 CoreBridge.swift 的 requiredJavaVersion。
// 这个映射错了，表现是「启动时抛一句看不懂的 JRE 错误」或「模组莫名崩」，很难反查。

function requiredJavaVersion(meta) {
  const jv = meta.javaVersion;
  if (jv && typeof jv === 'object' && typeof jv.majorVersion === 'number' && jv.majorVersion > 0) {
    return jv.majorVersion;
  }
  const id = meta.id;
  if (typeof id === 'string') {
    const parts = id.split('.');
    if (parts.length >= 2) {
      const ma = parseInt(parts[0], 10);
      const mi = parseInt(parts[1], 10);
      if (!isNaN(ma) && !isNaN(mi)) {
        if (ma === 1) {
          if (mi >= 21) return 21;
          if (mi === 20) {
            const patch = parts.length >= 3 ? (parseInt(parts[2], 10) || 0) : 0;
            return patch >= 5 ? 21 : 17;
          }
          if (mi >= 17) return 17;
          if (mi >= 12) return 17;   // 官方要 8，包里没有，务实返回 17
          return 8;
        }
        if (ma >= 26) return 25;
        if (ma >= 22) return 25;
      }
    }
  }
  return 17;
}

let pass = 0, fail = 0;
function eq(label, got, want) {
  if (got === want) pass++;
  else { fail++; console.log(`  [FAIL] ${label}: 得到 ${got}，期望 ${want}`); }
}

console.log('=== 显式 javaVersion 优先 ===');
eq('元数据写 21', requiredJavaVersion({ id: '1.12.2', javaVersion: { majorVersion: 21 } }), 21);
eq('元数据写 8', requiredJavaVersion({ id: '1.21', javaVersion: { majorVersion: 8 } }), 8);
eq('元数据写 0 视为无效', requiredJavaVersion({ id: '1.21', javaVersion: { majorVersion: 0 } }), 21);

console.log('=== 关键回归：1.20.5 分界 ===');
eq('1.20    -> 17', requiredJavaVersion({ id: '1.20' }), 17);
eq('1.20.1  -> 17（最常见的版本之一）', requiredJavaVersion({ id: '1.20.1' }), 17);
eq('1.20.2  -> 17', requiredJavaVersion({ id: '1.20.2' }), 17);
eq('1.20.4  -> 17', requiredJavaVersion({ id: '1.20.4' }), 17);
eq('1.20.5  -> 21（分界点）', requiredJavaVersion({ id: '1.20.5' }), 21);
eq('1.20.6  -> 21', requiredJavaVersion({ id: '1.20.6' }), 21);
eq('1.20.10 -> 21', requiredJavaVersion({ id: '1.20.10' }), 21);

console.log('=== 1.21+ ===');
eq('1.21    -> 21', requiredJavaVersion({ id: '1.21' }), 21);
eq('1.21.1  -> 21', requiredJavaVersion({ id: '1.21.1' }), 21);
eq('1.21.4  -> 21', requiredJavaVersion({ id: '1.21.4' }), 21);

console.log('=== 1.17 ~ 1.19 ===');
eq('1.17    -> 17', requiredJavaVersion({ id: '1.17' }), 17);
eq('1.18.2  -> 17', requiredJavaVersion({ id: '1.18.2' }), 17);
eq('1.19.4  -> 17', requiredJavaVersion({ id: '1.19.4' }), 17);

console.log('=== 1.12 ~ 1.16（官方要 8，务实给 17）===');
eq('1.12.2  -> 17', requiredJavaVersion({ id: '1.12.2' }), 17);
eq('1.16.5  -> 17', requiredJavaVersion({ id: '1.16.5' }), 17);

console.log('=== ≤1.11（包里没有 Java 8，启动会给明确报错）===');
eq('1.11.2  -> 8', requiredJavaVersion({ id: '1.11.2' }), 8);
eq('1.8.9   -> 8', requiredJavaVersion({ id: '1.8.9' }), 8);
eq('1.7.10  -> 8', requiredJavaVersion({ id: '1.7.10' }), 8);

console.log('=== 新版本号体系 ===');
eq('22.0    -> 25', requiredJavaVersion({ id: '22.0' }), 25);
eq('26.1    -> 25', requiredJavaVersion({ id: '26.1' }), 25);

console.log('=== 快照与异常输入 ===');
eq('1.21.4-pre1 -> 21', requiredJavaVersion({ id: '1.21.4-pre1' }), 21);
eq('1.20.1-pre3 -> 17', requiredJavaVersion({ id: '1.20.1-pre3' }), 17);
eq('26w01a 无点号 -> 兜底 17', requiredJavaVersion({ id: '26w01a' }), 17);
eq('空 id -> 兜底 17', requiredJavaVersion({ id: '' }), 17);
eq('无 id -> 兜底 17', requiredJavaVersion({}), 17);
eq('id 非字符串 -> 兜底 17', requiredJavaVersion({ id: 123 }), 17);

console.log('=== 不变量：结果必须是包里可能带的版本之一 ===');
const BUNDLED = [8, 17, 21, 25];
const ids = ['1.7.10','1.8.9','1.11.2','1.12.2','1.16.5','1.17','1.19.2','1.20',
             '1.20.1','1.20.4','1.20.5','1.20.6','1.21','1.21.4','22.0','26.1',
             '26w01a','','x','1.21.4-pre1','1.20.1-pre3'];
ids.forEach(id => {
  const v = requiredJavaVersion({ id });
  if (BUNDLED.includes(v)) pass++;
  else { fail++; console.log(`  [FAIL] id="${id}" 得到 ${v}，不可能是包里的版本`); }
});

console.log('');
console.log(`结果：通过 ${pass}，失败 ${fail}`);
process.exit(fail === 0 ? 0 : 1);
