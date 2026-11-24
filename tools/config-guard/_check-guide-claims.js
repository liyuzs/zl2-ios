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
//   ④ **新增（第134轮）**：`DISABLED_SETTINGS_CLAIMS` 专治「教程教用户开一个置灰的开关」。
//      判据：文案里出现某句操作，而它对应的设置键在 `notWired` / `platformOnly` 里 →
//      再看这句话附近 30 行有没有「做不到」的提示词或警示组件调用。
//      有提示 → 合格（正确写法：步骤留着 + 事先说清现在不行）；没有 → 报。
//      同时扫 `ZL2App.swift`（`MultiplayerScreen` 的教程在那里）。
//
// **局限**（不查什么）：
//   · **清单类文档里教的彩蛋不在范围**（`真机验证清单-给朋友.md` 的「几个小彩蛋」那节，2026-11-25 人工逐条核实过代码；改彩蛋时要回去对一遍）。
//   · **只覆盖 `CLAIMS` 表里那几条 + 全仓手势词**，**不是完备证明**（第108轮自己写明的）。
//   · **"点某个按钮"类不归它** —— 那些由 `_check-empty-button` 管（保证每个 Button 有非空 action）。
//   · **手势扫描按文件名排除 `ZLStrings.swift`**（安卓文案整包、多数未被引用）。将来把新文案移植回来，
//     **如果还放在那个文件里，就会被静默跳过**。
//   · **判不了"操作存在但用不了"**：手势有、底下不通（第189轮 `MultiplayerRoomScreen` 就是 —— 界面完整、路由没人导航）。

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
// **第206轮记（权衡说明）**：这里做**行内剥注释**（`//` 之后全去掉）—— 而 `//` 也可能是
// URL（`https://`）、正则字面量（`/\/\//`）或字符串（`"a//b"`）的一部分，所以它会误伤。
//
// **但本脚本必须这么做**：判据要读字符串**内容**（文案/键名），剥字符串会毁掉判据；
// 而不剥行内注释，注释里的词又会被当成真文案 —— 那是**假警报**，第193轮说过假警报更危险。
//
// 权衡后保留行内剥离：**误伤 URL 的后果较轻**（URL 本身不是判据的一部分，
// 除非动作词/键名恰好出现在 `//` 之后 —— 实测没有）。
  .map(line => line.replace(/\/\/[^\r\n]*/, ''))   // 不能用 .*$ 结尾的正则 —— JS 的 . 不匹配 \r，CRLF 文件会漏剥注释
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
// **第197轮**：说明"为什么只列这么几条"——免得下一个人以为它漏了一大堆。
// 实测全项目"教操作"的用户可见文案约 8 条，其余几条是：
//   · 标题/说明（「选择登录方式」「拖动后锁定位置」）—— 不是让人去做什么
//   · 「点某个按钮」类（「点「打包日志」」「点「检查更新」」）—— **已被 `_check-empty-button` 覆盖**
//     （那个检查保证每个 Button 都有非空 action）
//   · 警告（「删除不可撤销」）—— 不是操作指引
// 所以 CLAIMS 只需要收"教的不是按钮"的那些（手势 / 长按 / 先做什么后做什么）。
console.log('（对照：全项目"教操作"文案约 8 条 —— 其余是标题/说明/警告，或"点某个按钮"这类已被 _check-empty-button 覆盖）');
console.log('');

// ---- 附加判据（第134轮）：教程教了置灰的设置 ----
const SETTINGS_SRC = path.join(SRC, "SettingsScreen.swift");
const settingsText = read(SETTINGS_SRC);

function collectSet(name) {
  const m = settingsText.match(new RegExp("static let " + name + ": Set<String> = \\[([\\s\\S]*?)\\]"));
  if (!m) return new Set();
  const keys = new Set();
  for (const line of m[1].split(/\r?\n/)) {
    const t = line.trim();
    if (!t.startsWith("")) continue;
    const k = t.match(/^"([^"]+)"/);
    if (k) keys.add(k[1]);
  }
  return keys;
}
const disabledKeys = new Set([...collectSet("notWired"), ...collectSet("platformOnly")]);

// 文案 → 设置键（人工登记；新增教程步骤时补一条）
const DISABLED_SETTINGS_CLAIMS = [
  { text: "开启「启用多人联机」开关", key: "enableTerracotta" },
];

// 提示词 **或** 警示组件调用（第134轮：警示写在组件里，调用点只有组件名）
const HINT_WORDS = /尚未接入|未接入|走不通|不支持|用不了|暂时没有|还没接入|notConnectedNotice|warningBanner|unsupportedBadge/i;

const SCAN_FILES = [path.join(SRC, "ZL2App.swift"), GUIDE, POLISH];

let disabledClaims = 0;
for (const f of SCAN_FILES) {
  const text = stripComments(read(f));
  if (!text) continue;
  const lines = text.split(/\r?\n/);
  for (const claim of DISABLED_SETTINGS_CLAIMS) {
    if (!disabledKeys.has(claim.key)) continue;
    lines.forEach((line, i) => {
      if (!line.includes(claim.text)) return;
      const lo = Math.max(0, i - 30);
      const hi = Math.min(lines.length, i + 30);
      if (HINT_WORDS.test(lines.slice(lo, hi).join(String.fromCharCode(10)))) return;
      disabledClaims++;
      console.log("⚠ " + path.basename(f) + ":" + (i + 1) + " 教程教用户「" + claim.text + "」，");
      console.log("    但设置项 " + claim.key + " 在置灰集合里，附近也没有提示。");
    });
  }
}

const totalBad = problems.length + disabledClaims;

if (totalBad === 0) {
  console.log("✓ 引导/提示里教的每个操作，都能在代码里找到实现");
  console.log("✓ 也没有「教用户去开一个置灰的设置项」的教程");
  process.exit(0);
}

if (problems.length > 0) {
  console.log("⚠ " + problems.length + " 条教了但做不到：");
  for (const q of problems) console.log("  · " + q);
  console.log("");
}
console.log("修法：要么补实现，要么把文案改成实际能做操作。");
console.log("      若步骤要保留（说明设计意图），就在同一处加一条醒目提示（如 notConnectedNotice）。");
process.exit(1);
