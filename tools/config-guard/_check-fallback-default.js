// 代码里的"读不到时的兜底"必须与 ZLSettings.defaultValue 一致（第164轮）
//
// 两端：
//   · 一端：`ZLSettings` 的 `defaultValue: "25"`（声明）
//   · 另一端：直接读 `UserDefaults` 时的兜底
//       `string(forKey:) ?? "X"` · `integer(forKey:)`（无 ?? → 0）· `bool(forKey:)`（无 ?? → false）
//       `object(forKey:) as? Bool ?? X`
//
// 为什么要有这条：`ZLSettingsStore` 读不到时**会用 defaultValue 兜底** ✓，
// 但 `CoreBridge` 等处**直接读 UserDefaults**，用的是自己的 `?? `。
// **两个值之间没有任何机制保证一致** —— 改了 defaultValue 忘了改 `??`，
// 用户没设置过时拿到的就不是声明的默认值，而首启动行为会静默变错。
//
// **局限**：
// · 只认这四种写法（string+?? / integer / bool / object as? Bool ??）。用变量拼 key 查不到。
// · `integer(forKey:)` / `bool(forKey:)` 判据只在"没有 ?? 覆盖"时生效；
//   若写成 `integer(forKey:) ?? 5`，本检查不比对那个 5（是另一种形态）。
// · 只查 ZLSettings 里声明过的 key（孤儿键由 `_check-orphan-keys.js` 管）。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const settingsSrc = fs.readFileSync(path.join(SRC, 'ZLSettings.swift'), 'utf8');
const defs = new Map();
for (const m of settingsSrc.matchAll(/\.init\(key:\s*"([^"]+)"[^)]*?type:\s*\.(\w+)[^)]*?defaultValue:\s*"([^"]*)"/g)) {
  defs.set(m[1], { type: m[2], def: m[3] });
}

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift') && f !== 'SettingsScreen.swift');
const problems = [];
let checked = 0;

for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');
  const lines = src.split(/\r?\n/);
  lines.forEach((line, i) => {
    if (line.trim().startsWith('//')) return;
    if (!/UserDefaults/.test(line)) return;

    // ① string(forKey:) ?? "X"
    for (const m of line.matchAll(/string\(\s*forKey:\s*"([^"]+)"\s*\)\s*\?\?\s*"([^"]*)"/g)) {
      const key = m[1], fb = m[2];
      const d = defs.get(key); if (!d) continue;
      checked++;
      if (d.def !== fb) problems.push({ file: f, line: i + 1, key, code: 'string ?? "' + fb + '"', want: '"' + d.def + '"' });
    }

    // ② integer(forKey:) 无 ?? → 读不到给 0
    for (const m of line.matchAll(/integer\(\s*forKey:\s*"([^"]+)"\s*\)/g)) {
      const key = m[1];
      const d = defs.get(key); if (!d) continue;
      const rest = line.slice(m.index + m[0].length);
      if (/^\s*\?\?/.test(rest)) continue;   // 有 ?? 覆盖，另算
      checked++;
      if (d.def !== '0' && d.def !== 'null' && d.def !== '') {
        problems.push({ file: f, line: i + 1, key, code: 'integer() 无 ??（读不到给 0）', want: d.def });
      }
    }

    // ③ bool(forKey:) 无 ?? → 读不到给 false
    for (const m of line.matchAll(/bool\(\s*forKey:\s*"([^"]+)"\s*\)/g)) {
      const key = m[1];
      const d = defs.get(key); if (!d) continue;
      const rest = line.slice(m.index + m[0].length);
      if (/^\s*\?\?/.test(rest)) continue;
      checked++;
      if (d.def !== 'false' && d.def !== 'null' && d.def !== '') {
        problems.push({ file: f, line: i + 1, key, code: 'bool() 无 ??（读不到给 false）', want: d.def });
      }
    }

    // ④ object(forKey:) as? Bool ?? X
    for (const m of line.matchAll(/object\(\s*forKey:\s*"([^"]+)"\s*\)\s*as\?\s*Bool\s*\?\?\s*(true|false)/g)) {
      const key = m[1], fb = m[2];
      const d = defs.get(key); if (!d) continue;
      checked++;
      if ((fb === 'true') !== (d.def === 'true')) {
        problems.push({ file: f, line: i + 1, key, code: 'as? Bool ?? ' + fb, want: d.def });
      }
    }
  });
}

console.log('检查了 ' + checked + ' 处"读不到时的兜底"（key 都在 ZLSettings 里）');
console.log('');

if (problems.length === 0) {
  console.log('✓ 代码里的兜底值都与 ZLSettings.defaultValue 一致');
  process.exit(0);
}

console.log('⚠ ' + problems.length + ' 处不一致（首启动行为会与声明不同）：');
for (const p of problems) {
  console.log('  ' + p.file + ':' + p.line + '  ' + p.key);
  console.log('      代码：' + p.code + '    ZLSettings 声明：' + p.want);
}
console.log('');
console.log('为什么危险：`ZLSettingsStore` 读不到时会用 defaultValue 兜底，但直接读 UserDefaults 的地方');
console.log('  用的是自己的 ??。**两个值之间没有任何机制保证一致** —— 改了 defaultValue 忘了改 ??，');
console.log('  用户没设置过时拿到的就不是声明的默认值。');
process.exit(1);
