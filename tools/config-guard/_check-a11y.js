// 图标按钮的无障碍：只禁止新增，不要求一次改完
//
// 起因：ios-zl2 第110轮。全项目 169 处纯图标 `Image(systemName:)`，而 accessibilityLabel
// 只有 2 处 —— VoiceOver 用户听到的全是"按钮"。一次改完 169 处风险太高（没有编译器、
// 没有真机），所以先补最关键的导航入口（顶栏 5 个 + 主界面 4 个，已完成），
// 再用**基线**把剩下的钉住：数量只能降不能升。
//
// 判据：每个文件里"无标签的图标按钮"数量，不得超过基线。基线存在同目录
// `_a11y-baseline.json`，需要主动下调（改好了就更新基线，数字会跟着降）。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const BASELINE = path.join(__dirname, '_a11y-baseline.json');

// 统计一个文件里"按钮的 label 是纯 Image 且没有名字"的次数
//
// 第111轮修正：原来的判据只看"附近有没有 accessibilityLabel"，
// 于是把「图标 + Text("添加服务器")」这类**自带文字名字**的按钮也算成无标签（误报）。
// 现在额外要求：按钮的 label 块里**没有 Text(**，才算没名字。
function countUnlabeledIconButtons(src) {
  const lines = src.split('\n');
  let n = 0;
  for (let i = 0; i < lines.length; i++) {
    if (!/Image\(systemName:\s*"/.test(lines[i])) continue;
    // 往回找 12 行，看是不是 Button 的 label
    const up = lines.slice(Math.max(0, i - 12), i + 1).join('\n');
    if (!/Button\s*(\(|\{)/.test(up)) continue;
    // 往后找 10 行：有 accessibilityLabel 或 Text( 都算有名字
    const down = lines.slice(i, i + 10).join('\n');
    if (/accessibilityLabel/.test(down)) continue;
    if (/Text\s*\(/.test(down)) continue;

    // 第113轮补：`Button("标题") { }` / `Button(变量) { }` 这类**带标题参数**的按钮
    // 本身就念得出名字（iOS 会拿标题当无障碍名）。要排除的只是
    // `Button { }`（无参）与 `Button(role:/action:/label:)`（全是修饰参数）。
    let btnTitle = false;
    for (let k = i; k >= Math.max(0, i - 12); k--) {
      const m = lines[k].match(/Button\s*\(([^)]*)/);
      if (!m) continue;
      const arg = m[1].trim();
      btnTitle = arg.length > 0 && !/^(role|action|label)\s*:/.test(arg);
      break;
    }
    if (btnTitle) continue;

    n++;
  }
  return n;
}

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const current = {};
for (const f of files) {
  const c = countUnlabeledIconButtons(fs.readFileSync(path.join(SRC, f), 'utf8'));
  if (c > 0) current[f] = c;
}

const total = Object.values(current).reduce((a, b) => a + b, 0);

// 没有基线就生成一份（第一次运行）
if (!fs.existsSync(BASELINE)) {
  fs.writeFileSync(BASELINE, JSON.stringify(current, null, 2) + '\n', 'utf8');
  console.log(`已生成基线：${Object.keys(current).length} 个文件 / ${total} 处无标签图标按钮`);
  console.log('以后只许降不许升（改好了记得下调基线）。');
  process.exit(0);
}

const baseline = JSON.parse(fs.readFileSync(BASELINE, 'utf8'));
const problems = [];
for (const [f, c] of Object.entries(current)) {
  const base = baseline[f] || 0;
  if (c > base) {
    problems.push(`${f}: ${c} 处（基线 ${base}）—— 新增的图标按钮要加 .accessibilityLabel("…")`);
  }
}

console.log(`无标签图标按钮：当前 ${total} 处，基线 ${Object.values(baseline).reduce((a, b) => a + b, 0)} 处`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 没有新增无标签的图标按钮');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 个文件超出基线：`);
for (const p of problems) console.log(`  · ${p}`);
console.log('');
console.log('修法：给这个按钮加 `.accessibilityLabel("中文名")`；');
console.log('      改好并降了基线后，把 _a11y-baseline.json 里的数字同步调低。');
process.exit(1);
