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
//   ③（第172轮）IPA 比源码旧超一天时，`从这里开始.md` 必须有 `build-数字` 警告
//   ④（第534轮）bundle 里的 HEAD、源码 zip 里的 `CHANGELOG.md` 必须与当前 HEAD 一致
//
// 不检查非文档文件（.ipa 等大文件），但 ④ 会读 bundle 的 refs 与 zip 里的一个条目。
// 注意：`_run-all.ps1` 刻意**不**作为交付物 —— 它是工具，每加一个检查就会变，
// 留在交付包必然反复漂移。交付包只放"给人读"的东西（说明、清单）。
//
// **局限**（不查什么）：
//   · **只保证"副本 == 仓库原件"，不保证两边都对** —— 第173轮就是两份都写"仅横屏"，
//     一致 ✓ 但错。**参照另一份抄本，只能防漏同步，防不了共同出错。**
//   · **只认 `ALIAS` 表里登记的那几个映射**。新增文档没登记 → 被判"孤本"（会报，好事）；
//     但**表本身要人维护**，漏登记一个就会把正常副本当孤本。
//   · **"IPA 比源码旧超 1 天"只看文件修改时间**：时钟不准、或 `git checkout` 恢复了旧时间戳，
//     会误报/漏报。它判的是"时间差"，不是"内容是否同一版本"。
//   · **第 ④ 条只拿 `CHANGELOG.md` 一个文件当探针**：如果某次提交没改 CHANGELOG，zip 落后
//     也不会被发现。它是"最灵敏的探针"，不是"完整校验"（完整校验要逐个文件比，zip 里近千个）。
//   · **交付包目录不存在时整条跳过**（CI / 仓库副本环境）—— 那时它对交付物是**完全空转**的。

const fs = require('fs');
const path = require('path');
const { REPO, DELIVERY } = require('./_paths');
const GUARD = require('./_paths').GUARD;

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

// ---- 第534轮加的判据：bundle / 源码 zip 必须与当前 HEAD 同步 ----
// 背景：交付包里的 `zl2-ios-完整仓库.bundle` 与 `zl2-ios-源码.zip` 还停在 build-243 那天，
// 而仓库已经往前走了十几个提交 —— 文档却写着"全部提交历史"。这是第172轮那条
// 「交付物里每样都得是同一个版本」的另一种形态：IPA 落后是已知的（只能等 CI 重建），
// 但 **bundle / 源码 zip 随时能重新生成**，落后没有任何理由。
//
// 两条都用**内容**判，不看 mtime（`touch` 一下就能骗过时间戳）：
//   · bundle：`git bundle list-heads` 里的 HEAD 必须等于 `git rev-parse HEAD`
//   · 源码 zip：包里 `CHANGELOG.md` 的字节必须与仓库里那份一致（每次改动都会写 CHANGELOG，它是最灵敏的探针）
let staleArtifacts = [];
const cp = require('child_process');
const zlib = require('zlib');

function readZipEntry(buf, want) {
  let eocd = -1;
  for (let i = buf.length - 22; i >= 0 && i > buf.length - 66000; i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) return null;
  const count = buf.readUInt16LE(eocd + 10);
  let off = buf.readUInt32LE(eocd + 16);
  for (let n = 0; n < count; n++) {
    if (buf.readUInt32LE(off) !== 0x02014b50) return null;
    const nameLen = buf.readUInt16LE(off + 28);
    const extraLen = buf.readUInt16LE(off + 30);
    const commentLen = buf.readUInt16LE(off + 32);
    const name = buf.toString('utf8', off + 46, off + 46 + nameLen);
    if (name === want) {
      const method = buf.readUInt16LE(off + 10);
      const compSize = buf.readUInt32LE(off + 20);
      const lo = buf.readUInt32LE(off + 42);
      const nl = buf.readUInt16LE(lo + 26);
      const el = buf.readUInt16LE(lo + 28);
      const start = lo + 30 + nl + el;
      const data = buf.subarray(start, start + compSize);
      try { return method === 0 ? data : zlib.inflateRawSync(data); } catch { return null; }
    }
    off += 46 + nameLen + extraLen + commentLen;
  }
  return null;
}

try {
  const head = cp.execSync(`git -C "${REPO}" rev-parse HEAD`, { encoding: 'utf8' }).trim();

  const bundlePath = path.join(DELIVERY, 'zl2-ios-完整仓库.bundle');
  if (fs.existsSync(bundlePath)) {
    const heads = cp.execSync(`git bundle list-heads "${bundlePath}"`, { encoding: 'utf8' });
    const hit = heads.split('\n').map(l => l.trim().split(/\s+/)).find(p => p[1] === 'HEAD');
    const sha = hit ? hit[0] : '';
    if (!sha) staleArtifacts.push('bundle 里读不到 HEAD（`git bundle list-heads` 没给出）');
    else if (sha !== head) staleArtifacts.push(`bundle 里的 HEAD 是 ${sha.slice(0, 7)}，仓库是 ${head.slice(0, 7)}`);
  }

  const zipPath = path.join(DELIVERY, 'zl2-ios-源码.zip');
  if (fs.existsSync(zipPath)) {
    const inZip = readZipEntry(fs.readFileSync(zipPath), 'CHANGELOG.md');
    const inRepo = fs.readFileSync(path.join(REPO, 'CHANGELOG.md'));
    if (!inZip) staleArtifacts.push('源码 zip 里读不到 CHANGELOG.md');
    else if (!inZip.equals(inRepo)) staleArtifacts.push('源码 zip 里的 CHANGELOG.md 和仓库里的不一致（zip 是旧的）');
  }
} catch (e) {
  staleArtifacts.push('核对 bundle / 源码 zip 时出错：' + String(e.message || e).split('\n')[0]);
}

if (staleArtifacts.length) {
  console.log('⚠ 交付包的源码类产物落后于仓库：');
  for (const s of staleArtifacts) console.log('  · ' + s);
  console.log('  修法：跑 `scripts/刷新交付包产物.ps1`（重新生成 bundle + 源码 zip，约两分钟）。');
  console.log('');
}

process.exit(orphans.length + drifted.length === 0 && !ipaStale && staleArtifacts.length === 0 ? 0 : 1);
