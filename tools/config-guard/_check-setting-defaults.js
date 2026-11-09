// 设置项的默认值只许在一处声明
//
// 起因：ios-zl2 第86轮追「FPS 显示」这条链路时发现两处默认值打架：
//   · `ZLSettings` 里 `showFPS` 声明 defaultValue = "true"
//   · `GameOverlay.boolValue` 又自带一个 `defaultWhenUnset: Bool = false`，
//     并且加了一道 `UserDefaults.object(forKey:) == nil` 的门
// 结果：设置页按声明显示「显示 FPS = 开」，游戏里却按"没设置过"当作关 —— 用户看到的和实际不一样。
//
// 判据（窄而精确）：
//   1. 全仓不许出现 `defaultWhenUnset`（这正是"另写一套默认值"的写法）
//   2. 定义 `func boolValue(_ key: String` / `intValue` / `stringValue` 的文件，
//      必须委托给 `store.bool(` / `store.int(` / `store.string(` —— 由 ZLSettingsStore
//      按 def.defaultValue 兜底，这样默认值只有一份来源
//
// 不试图检查"所有默认值写法"（变量太多、误报会很多），只锁这一种已知会拧的写法。

const fs = require('fs');
const path = require('path');
const { SRC } = require('./_paths');
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

const problems = [];

for (const f of files) {
  const raw = fs.readFileSync(path.join(SRC, f), 'utf8');
  // 只扫代码，不扫注释（项目里注释会提到这些名字）
  const code = raw.split('\n')
    .filter(l => { const s = l.trim(); return !s.startsWith('//') && !s.startsWith('*') && !s.startsWith('/*'); })
    .join('\n');

  if (code.includes('defaultWhenUnset')) {
    problems.push(`${f}: 出现 defaultWhenUnset —— 这就是给设置项另写一套默认值，会与 ZLSettings 声明打架`);
  }

  // 检查这三个 helper 定义是否委托给 store
  // 第89轮把 readSettingBool 也纳入：它当初同样自带 default 参数并加了 UserDefaults 门，
  // 与 GameOverlay.boolValue 是同一个毛病，而旧版检查只盯三个名字所以漏了。
  const helperRe = /func\s+(boolValue|intValue|stringValue|readSettingBool)\s*\(\s*_\s+key\s*:\s*String[^)]*\)\s*->\s*(\w+)/g;
  for (const m of code.matchAll(helperRe)) {
    const name = m[1];
    const want = {
      boolValue: 'store.bool(',
      intValue: 'store.int(',
      stringValue: 'store.string(',
      readSettingBool: 'ZLSettingsStore.shared.bool(',   // ControlEditor 里的写法
    }[name];
    // 该 helper 的块内必须出现 want
    const start = m.index;
    const open = code.indexOf('{', start);
    let depth = 0, end = open;
    for (let i = open; i < code.length; i++) {
      if (code[i] === '{') depth++;
      else if (code[i] === '}') { depth--; if (depth === 0) { end = i; break; } }
    }
    const body = code.slice(open, end + 1);
    if (!body.includes(want)) {
      problems.push(`${f}: ${name}(_:) 没有委托给 ${want}…) —— 默认值会绕开 ZLSettings`);
    }
    // 第二个判据（第89轮补）：
    // 光"委托给了 store"不够 —— 可以在委托前面再加一道 `UserDefaults…== nil { return dv }`，
    // 那样默认值又被绕开了，而旧版判据看不出来。这类 helper 的体内不该出现 UserDefaults。
    if (body.includes('UserDefaults')) {
      problems.push(`${f}: ${name}(_:) 体内还在直接读 UserDefaults —— 等于另写一套默认值`);
    }
  }
}

if (problems.length === 0) {
  console.log('✓ 设置项默认值只有一个来源（ZLSettings 的 defaultValue）');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处会让默认值打架：`);
for (const p of problems) console.log(`  · ${p}`);
console.log('');
console.log('修法：删掉 helper 自带的默认值参数，改由 ZLSettingsStore 按 def.defaultValue 兜底。');
process.exit(1);
