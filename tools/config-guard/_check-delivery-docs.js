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

process.exit(orphans.length + drifted.length === 0 ? 0 : 1);
