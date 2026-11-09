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
//   ① CLAIMS 表只覆盖表里这些说法。表没列的操作教错了，这条检查发现不了 ——
//   它不是"文案与实现一致性"的完备证明，只是把踩过的坑钉住。
//   ② 全仓手势扫描只判"整个 App 里有没有这个手势的实现"，
//      判不了"这个手势在此处是否真的生效"（那需要语义，写不了可靠规则）。
//      举例：`contextMenu` 与 `textSelection(.enabled)` 都算"长按"的证据 ——
//      iOS 上本来就是长按触发，但具体落到哪个控件仍需人看。
//   ③ 扫描排除 `ZLStrings.swift`：那是安卓文案整包提取（1536 条），
//      多数没被界面引用，拿它判会一直误报。
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

// ---- 全仓手势扫描 ----
// 手势词出现在用户可见文案里，但整个 src 找不到对应实现 → 报。
// 长按的证据放宽到 contextMenu / textSelection：iOS 上这两者本来就用长按触发。
// 排除 ZLStrings.swift：那是从安卓源码整包提取的**文案库**（1536 条），
// 里面绝大多数字符串根本没有被界面引用 —— 拿它判"教用户做了什么"会一直误报。
// 只扫真正可能显示给用户的文件。
const SWIFT_FILES = fs.readdirSync(SRC).filter(f => f.endsWith('.swift') && f !== 'ZLStrings.swift');
const readAll = () => SWIFT_FILES.map(f => fs.readFileSync(path.join(SRC, f), 'utf8')).join('\n');
const allSrc = readAll();

const GESTURES = [
  { word: '长按', ev: /onLongPressGesture|contextMenu|textSelection\(/ },
  { word: '双击', ev: /onTapGesture\(\s*count:\s*2|TapGesture\(\s*count:\s*2/ },
  { word: '拖动', ev: /DragGesture|\.onDrag|draggable/ },
  { word: '滑动', ev: /DragGesture|swipeActions|MagnificationGesture/ },
];

// 全仓**字符串字面量**里是否出现这个手势词（剥掉注释，避免注释误触）
const literalHas = w => new RegExp('"[^"\\n]*' + w).test(stripComments(readAll()));
let swept = 0;
for (const g of GESTURES) {
  if (!literalHas(g.word)) continue;   // 没有任何用户可见文案提到这个手势
  swept++;
  if (!g.ev.test(allSrc)) {
    problems.push(`文案里提到「${g.word}」，但整个 src 找不到承接它的实现`);
  }
}
console.log(`检查了 ${checked} 条"文案里教了的操作"，${swept} 类手势`);
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
