// 脚本清单的完整性（双向）
//
// 起因：ios-zl2 第95轮核对文档时发现两件事：
//   ① 文档里提到的脚本**都存在**（54 个 `_` 前缀引用全部有效）—— 这个方向是好的
//   ② 但清单本身漏了一个：`_gen-settings-audit.js` 从未被写进 `README-脚本清单.md`
//   而且清单章节还写着「当前必跑（19 条）」，实际 `_run-all.ps1` 跑 49 项。
//
// 所以这个检查做两个方向：
//   A. **清单 → 磁盘**：清单里提到的每个脚本文件都必须真的存在（别让人去跑已删的脚本）
//   B. **磁盘 → 清单**：config-guard 里每个脚本都必须在清单里出现（别让新脚本变成"没人知道"）
//
// 它不判断"该不该跑"，只保证两个集合对得上 —— 分类是人的事，完备性是机器的事。

const fs = require('fs');
const path = require('path');
const GUARD = require('./_paths').GUARD;
const { REPO } = require('./_paths');
const LIST = path.join(GUARD, 'README-脚本清单.md');

const onDisk = fs.readdirSync(GUARD)
  .filter(f => f.endsWith('.js') || f.endsWith('.ps1'));

let list;
try { list = fs.readFileSync(LIST, 'utf8'); }
catch {
  console.log('✗ 找不到 README-脚本清单.md');
  process.exit(1);
}

const problems = [];

// ---- A. 磁盘 → 清单：每个脚本都要在清单里出现 ----
const notListed = onDisk.filter(f => !list.includes(f));
for (const f of notListed) {
  problems.push(`磁盘上有 ${f}，但清单里没提 —— 新脚本要登记（分类 + 该不该跑）`);
}

// ---- B. 清单 → 磁盘：清单提到的脚本必须存在 ----
const mentioned = new Set();
for (const m of list.matchAll(/`(_?[a-zA-Z0-9\-]+\.(?:js|ps1))`/g)) mentioned.add(m[1]);
for (const f of mentioned) {
  if (!onDisk.includes(f)) {
    problems.push(`清单里写了 ${f}，但文件不存在 —— 照它做会失败`);
  }
}

// ---- C. 仓库文档里 `_` 前缀的脚本引用也必须存在 ----
const docRefs = new Map();
const walk = dir => {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === '.git' || e.name === 'core') continue;
    const full = path.join(dir, e.name);
    if (e.isDirectory()) { walk(full); continue; }
    if (!e.name.endsWith('.md')) continue;
    const text = fs.readFileSync(full, 'utf8');
    for (const m of text.matchAll(/\b(_[a-zA-Z0-9\-]+\.(?:js|ps1))\b/g)) {
      if (!onDisk.includes(m[1])) {
        if (!docRefs.has(m[1])) docRefs.set(m[1], e.name);
      }
    }
  }
};
try { walk(REPO); } catch {}
for (const [script, doc] of docRefs) {
  problems.push(`${doc} 里提到 ${script}，但脚本不存在`);
}

// ---- D. 仓库副本同步：tools/config-guard 是交接用的版本管理副本 ----
// 第95轮发现"清单在交付包里、脚本却只在本机"是个交接缺口，所以把脚本拷进仓库。
// 这份检查保证两边不会飘：本机新增脚本忘了同步进仓库，会在这里报出来。
const REPO_COPY = path.join(REPO, 'tools', 'config-guard');
let repoNames = null;
try {
  repoNames = fs.readdirSync(REPO_COPY).filter(f => f.endsWith('.js') || f.endsWith('.ps1'));
} catch {
  problems.push('仓库里没有 tools/config-guard —— 交接时脚本会丢失');
}
if (repoNames) {
  const missingInRepo = onDisk.filter(f => !repoNames.includes(f));
  const extraInRepo = repoNames.filter(f => !onDisk.includes(f));
  for (const f of missingInRepo) problems.push(`本机有 ${f}，但仓库副本里没有（忘了同步）`);
  for (const f of extraInRepo) problems.push(`仓库副本里有 ${f}，本机已不存在（仓库该清理）`);
}

// ---- F. 内容必须字节一致（第147轮补） ----
// 判据 D 只比**文件名集合**。实测：`_check-dead-types.js` 改了没同步
// （工作副本 166 行 / 仓库副本 157 行），而这条检查报 ✓ ——
// "不许漏同步"实际只做到了"名字没漏"。
const contentDrift = [];
if (repoNames) {
  for (const f of onDisk) {
    if (!repoNames.includes(f)) continue;
    try {
      const a = fs.readFileSync(path.join(GUARD, f));
      const b = fs.readFileSync(path.join(REPO_COPY, f));
      if (!a.equals(b)) contentDrift.push(f);
    } catch { /* 读不到留给判据 D 报 */ }
  }
  for (const f of contentDrift) problems.push(`${f}：本机与仓库副本**内容不同**（改了没同步）`);
}

// ---- E. 不许写死仓库绝对路径（第96轮加：曾有 53 个脚本把仓库路径写死在常量里，入仓却不便携） ----
// 允许的只有 _paths.js / _paths.ps1 —— 它们是**唯一**该知道默认位置的地方。
// 豁免：_paths.* 是唯一该知道默认位置的地方；本文件自己是**检测器**，
// 必须包含那个模式串才能检测（否则没法写出这条判据）。
const PATH_EXEMPT = ['_paths.js', '_paths.ps1', '_check-script-inventory.js'];
for (const f of onDisk) {
  if (PATH_EXEMPT.includes(f)) continue;
  const text = fs.readFileSync(path.join(GUARD, f), 'utf8');
  if (/D:\\\\?ios-zl2/.test(text)) {
    problems.push(`${f} 里写死了仓库绝对路径 D:\\ios-zl2 —— 应改用 _paths（否则换机器就跑不了）`);
  }
}
console.log(`磁盘 ${onDisk.length} 个脚本 · 清单提到 ${mentioned.size} 个 · 仓库副本 ${repoNames ? repoNames.length : 0} 个 · 内容不一致 ${contentDrift.length} 个`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 清单与磁盘一致，文档引用的脚本都存在');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处不一致：`);
for (const p of problems) console.log(`  · ${p}`);
console.log('');
console.log('修法：新脚本写进清单（并标明该不该跑）；删掉的脚本从清单和文档里一起清掉。');
process.exit(1);
