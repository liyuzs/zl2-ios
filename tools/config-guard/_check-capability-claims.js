// 面向朋友的文档，能力边界都要说到（第211轮）
//
// 起因：项目里有**三份"能力清单"** —— `从这里开始.md`（200 轮加的）· `给朋友的安装指南.md` · `STATUS.md`。
// 第211轮对比发现：安装指南的「已知不行」**缺了 3 条**（MC 1.11-、分享进来、外置认证只是离线身份），
// 而**后两条正是朋友最容易误解的** —— 他会以为登录了就能进正版服，或者以为"用其他应用打开"应该有这个 App。
//
// 判据：**面向朋友的两份文档**里，每个"能力边界"关键词都必须出现。
// （STATUS 是技术文档，写法不同，不在本检查范围 —— 它的边界由第11条已知限制管。）
//
// **局限**：
// · 只认关键词，判不了"说的是不是同一件事"（比如"外置认证"出现但说的是别的）。
// · 关键词表是手写的 —— **新增能力边界时要记得往 `RULES` 里加一条**，否则这条检查看不见它。
// · 只查交付包里的副本（`从这里开始.md`）和仓库里的源（`docs/给朋友的安装指南.md`）。
//   **第250轮试过把 `STATUS.md` 也纳入，报出 3 处"缺失"，然后撤回**：
//   STATUS 的「已知问题」用**另一种表述体系**覆盖着同样的事实（第11条"外置登录只做一半"≈离线身份、
//   第8条"MC 1.11- 不支持"、第6条"缺 JNA 组件"），而它是**给接手者的技术文档**，不是"给朋友的说明"。
//   **两套表述体系不能套同一组关键字** —— 硬套只会得到假阳性，然后你会去改本来没问题的文档。
const fs = require('fs');
const path = require('path');

const { REPO } = require('./_paths');
const DELIVERY = 'D:\\ZL2-iOS交付包';

// 每个"能力边界"：只要有一种写法出现就算说到了
const RULES = [
  { key: 'Forge 不支持',      re: /Forge|NeoForge/ },
  { key: 'MC 1.11 及更早不支持', re: /1\.11/ },
  { key: '远程联机不可用',     re: /Network Extension|远程.{0,4}联机/ },
  // **第211轮修了三次**：
  // ① `/外置|皮肤站/` —— 太宽（"外置"在别处也出现）
  // ② `/离线身份/` —— **我自己加的说明注释里也提到这个词**，注释骗过了判据（同类问题第5次）
  // ③ 要求"表格行"—— 但从这里开始.md 用的是**列表项**（`· 外置认证只是离线身份`），太严
  // 现在：**行首必须是 `|` / `·` / `-`**（表格行或列表项），且同一行同时出现「外置/皮肤站」和「离线身份」。
  // `>` 开头的引用块（说明性注释）不算 —— 那正是骗过判据的那种。
  { key: '外置认证是离线身份',  re: /^[|·\-][^\n]*(外置|皮肤站)[^\n]*离线身份/m },
  { key: '分享进来未实现',     re: /CFBundleDocumentTypes|分享.{0,8}进来|用「文件」App/ },
  // **第247轮补的 3 条**：这三条朋友真会遇到（想分版本模组 / 微软掉登录 / 想装 OptiFine），
  // 而第211轮建的检查只覆盖了 5 条。
  { key: '版本隔离已置灰',     re: /版本隔离|所有版本共用\s*mods/ },
  { key: '微软 token 会过期',  re: /微软.{0,12}(重新登录|过期|续期)|token\s*不自动/ },
  { key: 'OptiFine 装不了',    re: /OptiFine/ },
];

const DOCS = [
  { name: '从这里开始.md',        path: path.join(DELIVERY, '从这里开始.md') },
  { name: '给朋友的安装指南.md',  path: path.join(REPO, 'docs', '给朋友的安装指南.md') },
];

const missing = [];
let checked = 0;

for (const d of DOCS) {
  let text;
  try { text = fs.readFileSync(d.path, 'utf8'); }
  catch { missing.push({ doc: d.name, key: '(读不到这个文件)' }); continue; }

  for (const r of RULES) {
    checked++;
    if (!r.re.test(text)) missing.push({ doc: d.name, key: r.key });
  }
}

console.log(`查了 ${DOCS.length} 份面向朋友的文档 × ${RULES.length} 条能力边界 = ${checked} 处`);
console.log(`没提到的：${missing.length} 处\n`);

// **零匹配守卫**（第196轮那条）
if (checked === 0) {
  console.log('⚠ 一处都没检查到 —— 判据可能失效了');
  process.exit(1);
}

if (missing.length === 0) {
  console.log('✓ 两份面向朋友的文档里，每条能力边界都提到了');
  process.exit(0);
}

console.log('⚠ 这些边界在某份文档里没提到（朋友会误判）：');
for (const m of missing) console.log(`  ${m.doc}  ← 缺「${m.key}」`);
console.log('');
console.log('修法：补进那份文档的「已知不行」表。新增能力边界时，也记得往本脚本的 RULES 里加一条。');
process.exit(1);
