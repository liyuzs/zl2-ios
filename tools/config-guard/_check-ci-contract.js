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
