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
// 判据演进（四次）：
//   110轮 只认 accessibilityLabel → 78 处（含大量误报）
//   112轮 补 Text(…)：图标+文字的按钮本来就有名字 → 45
//   113轮 补 Button("标题")：标题即无障碍名 → 33
//   114轮 **改成结构性判定**：按大括号取出整个 Button label 块再判断，
//          不再用固定行窗口 —— 文字可能在图标**上方**（TerracottaScreen 的
//          `Text("分享联机核心日志") + Spacer + chevron.right` 就是这样）。
function countUnlabeledIconButtons(src) {
  // 返回 { unlabeled, icons, inButton } —— 后两个是分母：
  //   icons    = 含 Image(systemName:) 的行数
  //   inButton = 其中真的落在 Button label 块里的数量
  // 若 inButton 为 0（Button 块识别失效），"无标签按钮 0 处"是空真，必须报错。
  const lines = src.split('\n');

  // 给一个行号，找它所属 Button 的 label 块文本（找不到返回 null）
  const labelBlockOf = (idx) => {
    for (let k = idx; k >= Math.max(0, idx - 25); k--) {
      if (!/Button\s*(\(|\{)/.test(lines[k])) continue;
      // Button 带标题参数 → 有名字
      const m = lines[k].match(/Button\s*\(([^)]*)/);
      if (m) {
        const arg = m[1].trim();
        if (arg.length > 0 && !/^(role|action|label)\s*:/.test(arg)) return { titled: true, body: '' };
      }
      // 从这一行往后做括号配对，取出整块
      let depth = 0, started = false, buf = '';
      for (let q = k; q < Math.min(lines.length, k + 120); q++) {
        const line = lines[q];
        buf += line + '\n';
        for (const ch of line) {
          if (ch === '{') { depth++; started = true; }
          else if (ch === '}') { depth--; }
        }
        if (started && depth <= 0) {
          // **关键约束（第114轮）**：图片那一行必须在这个 Button 的块内。
          // 否则"往上找 25 行"会跳到无关的按钮上 —— 路径条里的装饰图标
          // 就是这样被误算进工具栏按钮的（FileManagerScreen 实测）。
          if (idx < k || idx > q) return null;
          return { titled: false, body: buf };
        }
      }
      return null;
    }
    return null;
  };

  let n = 0, icons = 0, inButton = 0;
  for (let i = 0; i < lines.length; i++) {
    if (!/Image\(systemName:\s*"/.test(lines[i])) continue;
    icons++;
    const blk = labelBlockOf(i);
    if (!blk) continue;            // 不在任何 Button 里（装饰性图标）
    inButton++;
    if (blk.titled) continue;      // Button("标题") 自带名字
    if (/accessibilityLabel/.test(blk.body)) continue;
    if (/Text\s*\(/.test(blk.body)) continue;
    n++;
  }
  return { unlabeled: n, icons, inButton };
}

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const current = {};
let totalIcons = 0;        // 含 Image(systemName:) 的行数（全部）
let totalInButton = 0;     // 其中落在 Button label 块里的
for (const f of files) {
  const r = countUnlabeledIconButtons(fs.readFileSync(path.join(SRC, f), 'utf8'));
  totalIcons += r.icons;
  totalInButton += r.inButton;
  if (r.unlabeled > 0) current[f] = r.unlabeled;
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

console.log(`扫了 ${files.length} 个文件：${totalIcons} 个 Image(systemName:)，其中 ${totalInButton} 个在 Button 里`);
// 零匹配即失败：inButton 为 0 说明 Button 块识别失效，"无标签 0 处"是空真
if (totalInButton === 0) {
  console.log('⚠ 没有一个带图标的 Button 被识别出来 —— 判据可能已过时');
  console.log('  这不是"没问题"，是"没看到东西"。请核对 labelBlockOf 与 Button 的写法。');
  process.exit(1);
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
