// 推送脚本 ↔ CI workflow 的契约
//
// 起因：ios-zl2 第98轮核对 `推送并取回IPA.ps1` 与 `.github/workflows/build.yml` 之间的隐含契约，
// 发现三处会咬人的地方：
//   · 脚本默认等 30 分钟，而 CI 的上限是 45 分钟 —— 构建慢时脚本会先放弃，
//     报"构建没成功"，其实人家还在跑
//   · 脚本用 `name -match "ipa|zl2"` 模糊匹配产物，一旦 CI 多传一个 artifact 就可能抓错
//   · CI 现在会在编译前跑静态检查，脚本的失败提示却只说"去看日志"
//
// 这类"两个文件约定同一件事"的契约最容易漂，所以固化成检查。
//
// **局限**（不查什么）：
//   · **只查这六条**：超时对齐 / artifact 名 / 产物是 `.ipa` / 失败提示提静态检查 /
//     四个 `core/resources/*` 目录存在 / `project.yml` 里提到的 `.sh` 存在。
//     **CI 里其它隐含约定全看不见**：secrets 名、runner 版本（`macos-14` 还是 `-15`）、
//     Xcode 版本、缓存键、`concurrency` 组。
//   · **判不了"这套 workflow 真的能跑通"**。那是 `_check-workflow`（结构）+ **真推一次**才知道。
//     本检查只能说"两边说到一起了"，不能说"构建会成功"。
//   · **解析靠正则抓文本**：如果超时改写成 `$Timeout = 45 * 60`、或 artifact 名存进变量，
//     正则抓不到具体值 → **会误报**（说没对齐，其实对齐了）。
//   · **只认 `推送并取回IPA.ps1` 这一个脚本**。将来若出现第二个推送入口，它不在范围。

const fs = require('fs');
const path = require('path');

const { REPO } = require('./_paths');

const WF = path.join(REPO, '.github', 'workflows', 'build.yml');
const SCRIPT = path.join(REPO, 'scripts', '推送并取回IPA.ps1');

const problems = [];

let wf = '';
try { wf = fs.readFileSync(WF, 'utf8'); }
catch { console.log('✗ 找不到 .github/workflows/build.yml'); process.exit(1); }

let sh = '';
try { sh = fs.readFileSync(SCRIPT, 'utf8'); }
catch { console.log('✗ 找不到 scripts/推送并取回IPA.ps1'); process.exit(1); }

// ---- 1. 超时：脚本不能比 CI 先放弃 ----
const wfTimeout = (wf.match(/timeout-minutes:\s*(\d+)/) || [])[1];
const shTimeout = (sh.match(/\[int\]\$TimeoutMinutes\s*=\s*(\d+)/) || [])[1];
if (!wfTimeout) problems.push('build.yml 里找不到 timeout-minutes');
if (!shTimeout) problems.push('推送脚本里找不到 $TimeoutMinutes 默认值');
if (wfTimeout && shTimeout && Number(shTimeout) < Number(wfTimeout)) {
  problems.push(`脚本只等 ${shTimeout} 分钟，而 CI 上限 ${wfTimeout} 分钟 —— 构建慢时脚本会先判失败`);
}

// ---- 2. 产物名：脚本要精确认识 CI 上传的 artifact ----
const artName = (wf.match(/uses:\s*actions\/upload-artifact[\s\S]{0,200}?name:\s*([A-Za-z0-9_.-]+)/) || [])[1];
if (!artName) problems.push('build.yml 里找不到 upload-artifact 的 name');
if (artName && !sh.includes(artName)) {
  problems.push(`CI 上传的 artifact 叫 "${artName}"，但推送脚本里没出现这个字符串 —— 可能抓错产物`);
}

// ---- 3. workflow 必须真的产出 .ipa ----
if (!/out\/[^"' ]*\.ipa|\.ipa"/.test(wf)) {
  problems.push('build.yml 里看不出在打包 .ipa —— 脚本下载后找不到包');
}

// ---- 4. 静态检查与失败提示 ----
if (wf.includes('run-checks.js') && !sh.includes('Static checks')) {
  problems.push('CI 已经有静态检查步骤，但脚本的失败提示没提它 —— 排障时会指错方向');
}

// ---- 5. CI 打包步骤引用的资源必须真实存在 ----
// 第99轮加：CI 里写 `cp -R core/resources/$d "$APP/$d"`，目录改了名不会报错 ——
// 只会让打出来的 IPA 缺 jar，然后启动时 UnsatisfiedLinkError。
for (const d of ['Frameworks', 'libs', 'libs_caciocavallo', 'libs_caciocavallo17']) {
  const full = path.join(REPO, 'core', 'resources', d);
  if (!fs.existsSync(full)) problems.push(`CI 会打包 core/resources/${d}，但磁盘上没有这个目录`);
}
const jreDir = path.join(REPO, 'jre');
if (fs.existsSync(jreDir)) {
  const tars = fs.readdirSync(jreDir).filter(f => /^jre\d+-ios-aarch64\.tar\.xz$/.test(f));
  if (tars.length === 0) problems.push('jre/ 里没有任何 jre<N>-ios-aarch64.tar.xz —— CI 会退回下载（更慢且可能失败）');
}

// ---- 6. 配置里提到的 .sh 脚本必须存在 ----
// 第99轮加：project.yml 注释写着"版本号由 CI 用 zl2-version.sh 注入"，
// 而那个脚本根本不存在（CI 是用内联 sed 做的）—— 这类"注释引用"也会误导接手的人。
const py = path.join(REPO, 'project.yml');
if (fs.existsSync(py)) {
  const yml = fs.readFileSync(py, 'utf8');
  for (const m of yml.matchAll(/([A-Za-z0-9_.-]+\.sh)\b/g)) {
    const name = m[1];
    const found = [
      path.join(REPO, name),
      path.join(REPO, 'scripts', name),
      path.join(REPO, 'tools', name),
    ].some(x => fs.existsSync(x));
    if (!found) problems.push(`project.yml 提到 ${name}，但仓库里找不到这个脚本`);
  }
}
console.log(`CI timeout=${wfTimeout || '?'} 分钟 · artifact=${artName || '?'} · 脚本等待=${shTimeout || '?'} 分钟`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 推送脚本与 CI workflow 的契约一致');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处对不上：`);
for (const p of problems) console.log(`  · ${p}`);
console.log('');
console.log('修法：改脚本或改 workflow，让它们约定同一组事实。');
process.exit(1);
