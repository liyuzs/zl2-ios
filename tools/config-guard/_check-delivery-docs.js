// 交付包 ↔ 仓库 文档一致性
//
// 起因：`给朋友的安装指南.md` 和 `推送操作手册.md` 一直**只存在于交付包**，
// 不在仓库里 —— 不受版本控制、改代码时不会跟着更新、也没人审查。
// 后来发现它们里面写着「确认大小是 132 MB」，而 IPA 一重新构建这个数字就变了，
// 朋友照它验大小会以为下载坏了。
//
// 两条断言：
//   ① 交付包里的每个文档，都必须在仓库里有来源（同名，或在下面的 ALIAS 映射里）
//   ② 映射过来的副本必须和仓库原件**字节一致** —— 否则就是忘了同步
//
// 不检查非文档文件（.ipa 等大文件）。
// 注意：`_run-all.ps1` 刻意**不**作为交付物 —— 它是工具，每加一个检查就会变，
// 留在交付包必然反复漂移。交付包只放"给人读"的东西（说明、清单）。

const fs = require('fs');
const path = require('path');
const { REPO } = require('./_paths');
const GUARD = require('./_paths').GUARD;
const DELIVERY = 'D:\\ZL2-iOS交付包';

// 交付包里的别名 → 仓库里的真身
const ALIAS = {
  '交接文档-当前.md': path.join(REPO, 'HANDOFF-20261108.md'),
  '项目状态-当前.md': path.join(REPO, 'STATUS.md'),
  '从这里开始.md':      path.join(REPO, 'docs', '交付包说明-从这里开始.md'),
  '脚本清单.md':       path.join(GUARD, 'README-脚本清单.md'),
};

const WATCHED_EXT = ['.md', '.ps1', '.js'];

function resolveSource(name) {
  if (ALIAS[name]) return ALIAS[name];
  const inDocs = path.join(REPO, 'docs', name);
const inScripts = path.join(REPO, 'scripts', name);   // 运维脚本放在 scripts/ 下
if (fs.existsSync(inScripts)) return inScripts;
  if (fs.existsSync(inDocs)) return inDocs;
  const inRoot = path.join(REPO, name);
  if (fs.existsSync(inRoot)) return inRoot;
  return null;
}

if (!fs.existsSync(DELIVERY)) {
  console.log('· 交付包目录不存在，跳过');
  process.exit(0);
}

const files = fs.readdirSync(DELIVERY)
  .filter(f => WATCHED_EXT.some(e => f.endsWith(e)));

const orphans = [];
const drifted = [];
let ok = 0;

for (const name of files) {
  const src = resolveSource(name);
  if (!src) {
    orphans.push(name);
    continue;
  }
  const a = fs.readFileSync(path.join(DELIVERY, name));
  const b = fs.readFileSync(src);
  if (!a.equals(b)) {
    drifted.push({ name, src, aLen: a.length, bLen: b.length });
  } else {
    ok++;
  }
}

console.log(`交付包里的文档/脚本：${files.length} 个`);
console.log('');

if (orphans.length === 0) {
  console.log('✓ 每个都找到了仓库里的来源');
} else {
  console.log(`⚠ ${orphans.length} 个只在交付包、不在仓库（不受版本控制，也不会随代码更新）：`);
  for (const o of orphans) console.log(`    ${o}`);
  console.log('  修法：复制进仓库 docs/，再让它成为"副本"而不是"孤本"');
}
console.log('');

if (drifted.length === 0) {
  console.log(`✓ ${ok} 个副本与仓库原件一致`);
} else {
  console.log(`⚠ ${drifted.length} 个副本与仓库不一致（忘了同步）：`);
  for (const d of drifted) {
    console.log(`    ${d.name}  (交付包 ${d.aLen} 字节 / 仓库 ${d.bLen} 字节)`);
    console.log(`      仓库源：${d.src}`);
  }
}

// ---- 第172轮加的判据：IPA 过期了，文档就必须有警告 ----
// 背景：`ZL2.ipa` 是 build-235（11/8），源码是 11/14，而文档说"这就是 App 本体" ——
// 朋友会以为装着的是最新代码。IPA 只能靠 CI 重建（需要 token），所以它会长期落后，
// 这时候**文档的警告就是唯一防线**。
let ipaStale = null;
try {
  const ipaPath = path.join(DELIVERY, 'ZL2.ipa');
  const zipPath = path.join(DELIVERY, 'zl2-ios-源码.zip');
  const a = fs.statSync(ipaPath), b = fs.statSync(zipPath);
  const days = (b.mtimeMs - a.mtimeMs) / 86400000;
  if (days > 1) {
    const doc = fs.readFileSync(path.join(DELIVERY, '从这里开始.md'), 'utf8');
    // **只认 `build-数字`** —— 这是最独特的标记。
    // 原来还认"旧包"，结果文档 L48 别处就写着「不覆盖旧包」→ 即使删掉 IPA 那行的警告也能匹配（判据失效）。
    const warned = /build-\d+/.test(doc);
    if (!warned) ipaStale = { days: Math.round(days) };
  }
} catch { /* 文件不在就跳过 —— 新交付包还没构建 IPA 时属于正常 */ }

if (ipaStale) {
  console.log(`⚠ ZL2.ipa 比源码旧 ${ipaStale.days} 天，而「从这里开始.md」里没有警告`);
  console.log('  朋友会以为那是最新版。在这份文档里写清"这是旧包，要最新版得重新构建"。');
  console.log('');
}

process.exit(orphans.length + drifted.length === 0 && !ipaStale ? 0 : 1);
