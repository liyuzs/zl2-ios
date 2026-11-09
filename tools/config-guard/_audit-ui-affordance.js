// UI 假交互审计
//
// 起因：ios-zl2 多人联机页的「启用多人联机」Toggle 绑的是
// `@State private var enabled = true` —— 本地状态，没持久化、没人读，
// 用户拨来拨去什么都不发生。后来发现「导出整合包」整屏有同类问题：
// 三个假格式、一个死 Toggle、五个只绑定不读取的输入框。
//
// 核心判据（探针）：一个 @State 在文件里出现几次？
//   · 1 次 = 只有声明            → 死残留，无害（没有控件绑它），只提示
//   · 2 次 = 声明 + 某处 $x 绑定 → **有害**：用户操作去了没人读的地方
//   · >=3 次 = 有地方读          → 正常
//
// 绑定形式覆盖 Toggle / TextField / Slider / Picker / Stepper ——
// 不只是 Toggle，TextField 绑一个没人读的状态同样是"用户白填"。

const fs = require('fs');
const path = require('path');
const { SRC } = require('./_paths');
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift')).map(f => ({
  name: f,
  text: fs.readFileSync(path.join(SRC, f), 'utf8'),
}));

const fakeUI = [];      // 有害：绑了控件但没人读
const deadState = [];   // 无害：只声明没用
const deadBindings = []; // 有害：常量 + 空 set 的假 Binding

for (const f of files) {
  const text = f.text;

  // ---- 1. @State 探针 ----
  const stateRe = /@State\s+(?:private\s+)?var\s+([A-Za-z_][A-Za-z0-9_]*)/g;
  const states = new Map();
  let m;
  while ((m = stateRe.exec(text)) !== null) {
    states.set(m[1], text.slice(0, m.index).split('\n').length);
  }

  for (const [name, declLine] of states) {
    const count = (text.match(new RegExp(`\\b${name}\\b`, 'g')) || []).length;

    if (count === 1) {
      deadState.push(`${f.name}:${declLine}  ${name}`);
      continue;
    }
    if (count !== 2) continue;

    const bindForms = [
      ['Toggle(isOn:)',      new RegExp(`isOn:\\s*\\$${name}\\b`)],
      ['TextField(text:)',   new RegExp(`text:\\s*\\$${name}\\b`)],
      ['Slider(value:)',     new RegExp(`Slider\\(\\s*value:\\s*\\$${name}\\b`)],
      ['Picker(selection:)', new RegExp(`selection:\\s*\\$${name}\\b`)],
      ['Stepper(value:)',    new RegExp(`value:\\s*\\$${name}\\b`)],
    ];
    const hit = bindForms.find(([, re]) => re.test(text));
    if (!hit) continue;     // 没人读、也不是绑定目标 → 不归本审计管

    fakeUI.push(`${f.name}:${declLine}  ${hit[0]} 绑定 ${name} —— 只有声明+绑定，没有任何地方读`);
  }

  // ---- 2. 常量 + 空 set 的假 Binding ----
  const re = /Binding\(\s*get:\s*\{\s*(true|false|\d+|"[^"]*")\s*\}\s*,\s*set:\s*\{\s*_[^}]*\}\s*\)/g;
  while ((m = re.exec(text)) !== null) {
    const line = text.slice(0, m.index).split('\n').length;
    deadBindings.push(`${f.name}:${line}  常量 → 空 set`);
  }
}

console.log(`扫描 ${files.length} 个 Swift 文件`);
console.log('');

if (fakeUI.length === 0) {
  console.log('✓ 没有「绑了控件却没人读」的假交互');
} else {
  console.log(`⚠ ${fakeUI.length} 个假交互（有害 —— 用户以为设置生效了）：`);
  fakeUI.forEach(r => console.log('  ' + r));
}
console.log('');

if (deadBindings.length === 0) {
  console.log('✓ 没有「常量 + 空 set」的假 Binding');
} else {
  console.log(`⚠ ${deadBindings.length} 个假 Binding（有害）：`);
  deadBindings.forEach(r => console.log('  ' + r));
}
console.log('');

if (deadState.length === 0) {
  console.log('✓ 没有残留的无用 @State');
} else {
  console.log(`· ${deadState.length} 个只声明没用的 @State（无害，可清理）：`);
  deadState.slice(0, 20).forEach(r => console.log('  ' + r));
  if (deadState.length > 20) console.log(`  …… 其余 ${deadState.length - 20} 个略`);
}

const harmful = fakeUI.length + deadBindings.length;
process.exit(harmful === 0 ? 0 : 1);
