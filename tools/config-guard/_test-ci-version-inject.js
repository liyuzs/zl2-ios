// 契约测试：**两条构建通道里的版本注入脚本，真的能把 project.yml 改对**
//
// 起因：版本注入是"包能不能自称正确版本号"的唯一环节。它已经错过两次 ——
//   · 第18轮：GitHub Actions 那条通道原来根本没有注入（产出的包自称 0.1.0(1)）
//   · 第521轮：`codemagic.yaml` 那条通道又漏了一次，同一个 bug 换了通道复发
// 之前验它的方式都是**人工**跑一遍（第18轮在真 GNU bash 里跑过、第258轮在 CI 里被 BSD sed 打脸）。
// 人工跑一次 = 下次不会再跑（第123轮那条）。所以固化成测试：
// **把两条通道里的注入脚本原样抠出来，在本机 bash 里对一份 project.yml 副本跑一遍**，
// 断言结果真的是 `1.0.<号码>` 而不是静态的 1.0.0 / 1。
//
// 它验证的是"脚本内容对不对"，与 `_check-workflow`（结构/顺序）、
// `_check-ci-contract`（有没有这一步）互补 —— 三者合起来才叫"注入这条链是通的"。
//
// **局限**（不查什么）：
//   · **不验 BSD sed**：本机是 GNU sed（Git for Windows 自带）。BSD 的 `-i` 差异
//     （第258轮那次）**只能靠推到 macOS 上才知道**；本测试只能证明"脚本逻辑正确"，
//     证明不了"两个平台都跑得动"。判据已避开 `-i`，但这是纪律不是证明。
//   · **把 `/tmp/` 改成了 `./tmp/`**：为的是不在用户机器上抢同一个临时路径。
//     语义（写出来再读回去）不变，但严格说不是逐字执行 CI 里的那一段。
//   · **`${{ github.run_number }}` 用固定数字替换**（2001 / 2002），不验"真实 run 号会不会拿到"。
//   · **不验注入之后工程能不能编**（那要 macOS + XcodeGen）。
//   · 只在**有 bash 的机器**上有效；没有 bash 时它会 `exit 0` 并说明原因（不假装通过）。

const fs = require('fs');
const path = require('path');
const os = require('os');
const cp = require('child_process');
const { REPO } = require('./_paths');

const BASH_CANDIDATES = [
  'C:\\Program Files\\Git\\bin\\bash.exe',
  'C:\\Program Files (x86)\\Git\\bin\\bash.exe',
];

const CHANNELS = [
  {
    file: path.join(REPO, '.github', 'workflows', 'build.yml'),
    stepName: 'Inject version',
    number: '2001',
    // GitHub Actions 的表达式：真实运行时由 runner 替换
    subst: s => s.split('${{ github.run_number }}').join('2001'),
  },
  {
    file: path.join(REPO, 'codemagic.yaml'),
    stepName: '注入版本号',
    number: '2002',
    subst: s => s,
  },
];

function findBash() {
  for (const b of BASH_CANDIDATES) if (fs.existsSync(b)) return b;
  return null;
}

// 从 workflow 里抠出某个步骤的块标量正文（去掉公共缩进）
function extractStepBody(text, stepName) {
  const lines = text.split(/\r?\n/);
  const startIdx = lines.findIndex(l => new RegExp('^\\s*- name:\\s*' + stepName + '\\s*$').test(l));
  if (startIdx < 0) throw new Error('找不到步骤「' + stepName + '」');
  // 从步骤行往下找 `run: |` 或 `script: |`
  let bodyStart = -1;
  let blockIndent = -1;
  for (let i = startIdx + 1; i < lines.length; i++) {
    const m = lines[i].match(/^(\s*)(run|script):\s*\|/);
    if (m) { blockIndent = m[1].length; bodyStart = i + 1; break; }
    if (/^\s*- name:/.test(lines[i])) break;   // 撞到下一个步骤 = 这个步骤没有块标量
  }
  if (bodyStart < 0) throw new Error('步骤「' + stepName + '」里没有 run: | / script: |');
  const body = [];
  for (let i = bodyStart; i < lines.length; i++) {
    const l = lines[i];
    if (l.trim() === '') { body.push(''); continue; }
    const ind = l.match(/^(\s*)/)[1].length;
    if (ind <= blockIndent) break;             // 回到同级 = 块结束
    body.push(l);
  }
  // 去公共缩进
  const nonEmpty = body.filter(l => l.trim() !== '');
  const minIndent = Math.min(...nonEmpty.map(l => l.match(/^(\s*)/)[1].length));
  return body.map(l => l.trim() === '' ? '' : l.slice(minIndent)).join('\n');
}

const bash = findBash();
if (!bash) {
  console.log('· 本机没有 bash（Git for Windows 自带那个）—— 跳过版本注入的行为测试');
  console.log('  跳过 ≠ 通过：有 bash 的机器（含 CI）必须跑这条。');
  process.exit(0);
}

const problems = [];
let checked = 0;

for (const ch of CHANNELS) {
  if (!fs.existsSync(ch.file)) { problems.push('缺通道文件：' + path.basename(ch.file)); continue; }
  let script;
  try {
    const raw = fs.readFileSync(ch.file, 'utf8');
    script = ch.subst(extractStepBody(raw, ch.stepName));
  } catch (e) {
    problems.push(path.basename(ch.file) + '：' + e.message);
    continue;
  }
  // 把 /tmp/ 换成本目录下的 tmp/，避免与别的进程抢同一个临时文件
  script = script.split('/tmp/').join('./tmp/');
  if (!/sed\s+-f/.test(script)) {
    problems.push(path.basename(ch.file) + '：抠出来的注入脚本里没有 `sed -f`，可能抠错了块');
    continue;
  }

  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'zl2inject-'));
  fs.mkdirSync(path.join(dir, 'tmp'));
  fs.copyFileSync(path.join(REPO, 'project.yml'), path.join(dir, 'project.yml'));
  fs.writeFileSync(path.join(dir, 'inject.sh'), script, 'utf8');

  const r = cp.spawnSync(bash, ['inject.sh'], {
    cwd: dir,
    encoding: 'utf8',
    env: Object.assign({}, process.env, { BUILD_NUMBER: ch.number }),
    timeout: 60000,
  });
  const out = (r.stdout || '') + (r.stderr || '');
  if (r.status !== 0) {
    problems.push(path.basename(ch.file) + '：注入脚本退出码 ' + r.status + '\n      ' + out.trim().split('\n').slice(-3).join('\n      '));
    continue;
  }
  const after = fs.readFileSync(path.join(dir, 'project.yml'), 'utf8');
  const wantVer = 'MARKETING_VERSION: "1.0.' + ch.number + '"';
  const wantBuild = 'CURRENT_PROJECT_VERSION: "' + ch.number + '"';
  if (!after.includes(wantVer)) problems.push(path.basename(ch.file) + '：注入后找不到 ' + wantVer + '（脚本没改对 MARKETING_VERSION）');
  if (!after.includes(wantBuild)) problems.push(path.basename(ch.file) + '：注入后找不到 ' + wantBuild + '（build 号没注入）');
  if (/MARKETING_VERSION:\s*"1\.0\.0"/.test(after)) problems.push(path.basename(ch.file) + '：注入后仍留着静态 1.0.0');
  checked++;
  // 清理
  try { fs.rmSync(dir, { recursive: true, force: true }); } catch { }
}

if (checked === 0 && problems.length === 0) {
  console.log('✗ 一条通道都没验到 —— 这不是"没问题"，是"没看到东西"');
  process.exit(1);
}

if (problems.length === 0) {
  console.log(`✓ 版本注入行为正确（${checked} 条通道，注入后 project.yml 变成 1.0.<号码>）`);
  process.exit(0);
}
console.log('✗ 版本注入有问题：');
for (const p of problems) console.log('  · ' + p);
process.exit(1);
