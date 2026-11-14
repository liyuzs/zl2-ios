// 下载后写盘的文件，必须有内容魔数校验（第150轮）
//
// 背景：第40轮给 `VersionInstaller` / `ModrinthAPI` 加了 PK 魔数校验（jar/zip 以 PK 开头）。
// 但同一类校验在别的模块漏了整整 110 轮 —— 第149–150轮连续发现：
//   · `ZLYggdrasil.downloadSkin`（PNG 只判 `data.count > 100`）
//   · `ZLYggdrasil.ensureDownloaded`（authlib jar 只判 `> 100_000`，HTML 错误页会被存成 jar
//     → `isReady` 为 true → `-javaagent` 指向无效 jar → JVM 启动直接失败）
//   · `LoaderInstaller`（库 jar 直接写盘，无校验，且 `failedLibs` 也不会记）
//
// 判据：一个文件里同时有"下载"和"写盘"，就必须出现内容魔数校验的痕迹。
//
// **局限**：
// · 只认 `0x50` / `0x89` / `hasPrefix("PK")` / `isValidJar` 这几种写法。用别的等价写法会漏。
// · 判不了"校验是否覆盖了每一处写盘"（只要文件里出现一次就算过）。
// · 只认 `data(for:` / `session.download(` / `fetch(` 这三种下载形态。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

const DOWNLOAD = /data\(for:|session\.download\(|\bfetch\(/;
const WRITE = /\.write\(to:|\.copyItem\(|\.moveItem\(/;
// 内容校验的痕迹
const MAGIC = /0x50|0x89|hasPrefix\("PK"\)|isValidJar|zlSHA1|SHA256\.hash|Insecure\.SHA1/;

// **扫描前剥注释**（第150轮）：注释里写着 "PK = 0x50 0x4B" 会被 MAGIC 命中，
// 删掉真正的校验也照样报 ✓ —— 与第143轮"注释算引用"同一个坑。
const stripComments = src => src
  .replace(/\/\*[\s\S]*?\*\//g, a => a.replace(/[^\n]/g, " "))
  .split(/\r?\n/)
  .map(l => {
    const t = l.trim();
    if (t.startsWith("//")) return "";
    return l;
  })
  .join("\n");

// 允许不校验魔数的：内容类型不定的**通用下载器**（用别的方式保证完整性）
const ALLOW = {
  // `MojangAPI` 的流式下载器要下 assets / jar / json 各种东西，内容类型不定，没法判魔数。
  // 但它有更强的保障：非 2xx 一律抛错 · **下载截断检测**（received < expectedSize 抛错）·
  // `.part` 临时文件 + 失败清理 + 原子替换。size 校验覆盖了「被截断」这种主要失效。
  'MojangAPI.swift': 'general-purpose stream downloader',
};


const rows = [];
const allowed = [];

for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');
  const hasDownload = DOWNLOAD.test(src);
  const hasWrite = WRITE.test(src);
  if (!hasDownload || !hasWrite) continue;

  if (ALLOW[f]) { allowed.push(f); continue; }
  rows.push({ file: f, hasMagic: MAGIC.test(stripComments(src)) });
}

console.log(`既有下载又有写盘的文件：${rows.length + allowed.length} 个（ALLOW 白名单 ${allowed.length} 个）\n`);

const missing = rows.filter(r => !r.hasMagic);
const ok = rows.filter(r => r.hasMagic);

console.log(`=== 有内容校验（${ok.length} 个）===`);
for (const r of ok) console.log(`  ✓ ${r.file}`);

console.log(`\n=== **没有内容校验**（${missing.length} 个）===`);
for (const r of missing) console.log(`  ⚠ ${r.file}`);

console.log('');
if (missing.length === 0) {
  console.log('✓ 每个"下载后写盘"的模块都校验了内容（魔数或哈希）');
  process.exit(0);
}

console.log('为什么重要：服务器可能返回网页错误页（HTTP 200 + HTML）。');
console.log('  只判大小的活，HTML 会被存成 .jar/.png ——');
console.log('  jar 无效 → 启动 ClassNotFoundException；jar 无效的 -javaagent → JVM 直接起不来。');
console.log('');
console.log('修法：写盘前校验魔数 ——');
console.log('  · jar/zip：`data[0] == 0x50, data[1] == 0x4B`（"PK"）');
console.log('  · png：`[UInt8](data.prefix(4)) == [0x89, 0x50, 0x4E, 0x47]`');
console.log('  · 或校验 SHA-1（Mojang 资源自带）');
process.exit(1);
