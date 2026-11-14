// 文档里写的配置属性必须与 project.yml 一致（第173轮）
//
// 起因：第165轮把 iPhone 改成允许竖屏，但 `给朋友的安装指南.md` 还写着「方向 | 仅横屏」——
// 而 `_check-delivery-docs` 只查"副本与仓库同步"，**不管内容对不对**，所以抓不到。
//
// 这类"配置改了、文档没改"的过时，只能靠**把文档里的具体值揪出来跟配置比对**。
// 能精确比对的三项（它们都在 `给朋友的安装指南.md` 的属性表里，且都在 project.yml 里唯一确定）：
//   · 最低系统 ↔ deploymentTarget
//   · 包名     ↔ PRODUCT_BUNDLE_IDENTIFIER
//   · 方向     ↔ UISupportedInterfaceOrientations 里有没有 Portrait
//
// **局限**：
// · 只查这三项。文档里其他描述（包内结构、路由、功能清单）判不了。
// · 认的是表格行格式 `| 属性 | 值 |`。改成散文就查不到。
// · 版本号**故意不查** —— 因为它有两层含义（源码版本 vs 旧 IPA 内置版本），文档需要同时说清，不能简单比对。
const fs = require('fs');
const path = require('path');

const { REPO } = require('./_paths');
const DELIVERY = 'D:\\ZL2-iOS交付包';
const GUIDE = path.join(DELIVERY, '给朋友的安装指南.md');

if (!fs.existsSync(GUIDE)) { console.log('· 交付包里没有安装指南，跳过'); process.exit(0); }

const yml = fs.readFileSync(path.join(REPO, 'project.yml'), 'utf8');

// **第209轮**：不只扫安装指南 —— **HANDOFF（交接文档）里也有一张配置表**
// （`| 包名 | `com.liyuzs.craftlauncher` |` / `| 最低系统 | iOS 16.0 |`），格式完全一样。
// 它之前不在扫描范围里，所以那两处**一直没被这条检查保护**。
// HANDOFF 文件名带日期，用通配匹配。
//
// **第209轮修**：第一次写成从 `DELIVERY` 找 `HANDOFF-*.md` —— 但 HANDOFF 在**仓库根目录**
// （交付包里它叫 `交接文档-当前.md`），所以一个都没匹配到、检查静默通过。
// 改为从 `REPO` 找。**这就是"没报可能是它根本没在看"的又一例**。
const DOCS = [{ name: '给朋友的安装指南.md', text: fs.readFileSync(GUIDE, 'utf8') }];
for (const f of fs.readdirSync(REPO).filter(x => /^HANDOFF-.*\.md$/.test(x))) {
  DOCS.push({ name: f, text: fs.readFileSync(path.join(REPO, f), 'utf8') });
}

// ---- project.yml 的事实 ----
const dm = yml.match(/deploymentTarget:\s*\n\s*iOS:\s*"([\d.]+)"/) || yml.match(/IPHONEOS_DEPLOYMENT_TARGET:\s*"([\d.]+)"/);
const deployTarget = dm ? dm[1] : null;

const bm = yml.match(/PRODUCT_BUNDLE_IDENTIFIER:\s*(\S+)/);
const bundleID = bm ? bm[1].trim() : null;

// iPhone 方向段（到 ~ipad 之前）
const oStart = yml.indexOf('UISupportedInterfaceOrientations:');
const oIpad = yml.indexOf('UISupportedInterfaceOrientations~ipad:', oStart);
const orientSeg = oStart >= 0 ? yml.slice(oStart, oIpad > 0 ? oIpad : oStart + 600) : '';
const hasPortrait = /UIInterfaceOrientationPortrait/.test(orientSeg);

console.log(`project.yml：最低系统 ${deployTarget || '?'} · 包名 ${bundleID || '?'} · iPhone 竖屏 ${hasPortrait ? '是' : '否'}`);
console.log('');

const problems = [];

for (const { name, text: doc } of DOCS) {
  // ---- ① 最低系统 ----
  const docSys = doc.match(/\|\s*最低系统\s*\|\s*\**iOS\s*([\d.]+)\**/);
  if (docSys && deployTarget && docSys[1] !== deployTarget) {
    problems.push(`[${name}] 最低系统：文档写 iOS ${docSys[1]}，project.yml 是 ${deployTarget}`);
  }

  // ---- ② 包名 ----
  const docBundle = doc.match(/\|\s*包名\s*\|\s*`([^`]+)`/);
  if (docBundle && bundleID && docBundle[1] !== bundleID) {
    problems.push(`[${name}] 包名：文档写 ${docBundle[1]}，project.yml 是 ${bundleID}`);
  }

  // ---- ③ 方向 ----
  const docDir = doc.match(/\|\s*方向\s*\|\s*([^|\n]+)\|/);
  if (docDir) {
    const saysPortrait = /竖屏/.test(docDir[1]);
    if (saysPortrait !== hasPortrait) {
      problems.push(`[${name}] 方向：文档说"${docDir[1].trim()}"，而 project.yml 里 iPhone ${hasPortrait ? '允许' : '不允许'}竖屏`);
    }
  }
}

if (problems.length === 0) {
  console.log(`✓ ${DOCS.map(d => d.name).join(' / ')} 里的配置属性（最低系统 / 包名 / 方向）与 project.yml 一致`);
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处文档与配置不一致：`);
for (const p of problems) console.log('  · ' + p);
console.log('');
console.log('修法：改文档（配置是对的），或改配置（文档写的是新设计）。');
console.log('这类过时的特点是：改了配置忘改文档，而同步检查只看"副本和仓库一致"，看不出内容错了。');
process.exit(1);
