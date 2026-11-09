// 引导/提示文案里教的**操作**，必须有对应实现
//
// 起因：ios-zl2 第108轮。主界面首次引导第 2 步写着
//   「长按卡片提起它，拖动并让它停靠到另一侧」
// 而主界面唯一的长按是头像转圈 —— 没有拖动停靠。新用户照着做只会困惑。
// （同族问题：第102轮彩蛋里的「长按空白处新建按钮」也不存在。）
//
// 做法：一张**说法 → 代码证据**的表。文案里出现某个说法，就必须能在对应文件里
// 找到支撑它的实现；找不到就报。
//
// **局限（必须写清，否则后人会高估它）**：
//   只覆盖表里这些说法。表没列的操作教错了，这条检查发现不了 ——
//   它不是"文案与实现一致性"的完备证明，只是把踩过的坑钉住。
//   新增引导步骤时，请顺手往 CLAIMS 里加一条。

const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const GUIDE = path.join(SRC, 'GuideScreens.swift');   // 引导文案
const POLISH = path.join(SRC, 'ZLPolish.swift');      // 彩蛋 / 提示文案

const read = p => { try { return fs.readFileSync(p, 'utf8'); } catch { return ''; } };

// **扫描前先剥注释**：注释里提到"长按卡片提起"（比如记录这次修复的原因）不算教用户，
// 不剥的话检查会被自己的说明文字触发（第108轮实测踩过一次）。
const stripComments = src => src
  .replace(/\/\*[\s\S]*?\*\//g, '')
  .split('\n')
  .map(line => line.replace(/\/\/.*$/, ''))
  .join('\n');

const guideText = stripComments(read(GUIDE)) + '\n' + stripComments(read(POLISH));
const home = read(path.join(SRC, 'HomeScreen.swift'));
const editor = read(path.join(SRC, 'ControlEditor.swift'));

// 说法 → { 文案里会出现的关键词, 证据所在文件, 证据正则, 说明 }
const CLAIMS = [
  {
    phrase: '长按卡片提起',
    evidence: () => /onLongPressGesture[\s\S]{0,400}?(dock|停靠|DragGesture)/.test(home),
    where: 'HomeScreen.swift 需要"长按 + 拖动/停靠"的实现',
  },
  {
    phrase: '拖动并让它停靠',
    evidence: () => /dock|停靠/.test(home),
    where: 'HomeScreen.swift 里应有"停靠"相关实现',
  },
  {
    phrase: '长按空白处新建',
    evidence: () => /SpatialTapGesture|onLongPressGesture[\s\S]{0,200}?addItem/.test(editor),
    where: 'ControlEditor.swift 里应有空白处的长按新建手势',
  },
  {
    phrase: '通过预览功能',
    evidence: () => /previewMode|private var preview/.test(editor),
    where: 'ControlEditor.swift 里应有预览实现',
  },
  {
    phrase: '收藏柜',
    evidence: () => /vaultStyles|vault/.test(editor),
    where: 'ControlEditor.swift 里应有收藏柜',
  },
  {
    phrase: '创建新的控件层',
    evidence: () => /func addLayer|addLayer\(/.test(editor),
    where: 'ControlEditor.swift 里应有 addLayer',
  },
];

const problems = [];
let checked = 0;

for (const c of CLAIMS) {
  if (!guideText.includes(c.phrase)) continue;   // 文案没教这个，跳过
  checked++;
  if (!c.evidence()) {
    problems.push(`文案里教了「${c.phrase}」，但找不到实现 —— ${c.where}`);
  }
}

console.log(`检查了 ${checked} 条"文案里教了的操作"`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 引导/提示里教的每个操作，都能在代码里找到实现');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 条教了但做不到：`);
for (const p of problems) console.log(`  · ${p}`);
console.log('');
console.log('修法：要么补实现，要么把文案改成实际能做操作 —— 别教用户做不存在的事。');
process.exit(1);
