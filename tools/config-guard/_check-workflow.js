// 极简 YAML 结构校验：针对 **CI workflow 的 block scalar 缩进**。
// 支持两种写法：GitHub Actions（`run: |`）与 Codemagic（`script: |`）。
// 不追求完整 YAML 规范，只要能抓出「步骤缩进错、run 内容被截断、块标量丢失」这几类致命错。
//
// **扫描范围（前提，不是局限）**：不给参数时验**全部**已知构建通道 ——
//   `.github/workflows/*.yml|*.yaml` + 仓库根的 `codemagic.yaml`。
//   第 521 轮发现原来只验 `build.yml`：`codemagic.yaml`（16901 字节、12 步）与
//   `easytier-probe.yml`（6 步，拉 EasyTier 静态库那条通道）**从来没被这条检查看过** ——
//   而它们一样会把 CI 跑挂。想验单个文件仍可 `node _check-workflow.js <路径>`。
//   放在别处的 workflow 文件它看不见，加新通道时请放进这两处之一。
//
// **局限**（不查什么）—— **这条检查的局限特别重要，因为 workflow 错了 CI 就跑不起来**：
//   · **不是 YAML 解析器**。只做"缩进 + 块标量"的结构校验，**不验证 YAML 语法本身**
//     （比如引号没闭合、锚点写错、多行折叠符用错，它都发现不了）。
//   · **不查 action 的版本号对不对**（`actions/checkout@v4` 写成 `@v99` 也通过）。
//   · **不查 secrets / 环境变量名拼错**（那要跟仓库的 secrets 列表对，本地拿不到）。
//   · **不查 CI 逻辑是否正确**（步骤顺序、条件表达式、矩阵展开）—— 只查"结构上像不像一个能跑的 workflow"。
//   · **只强制要求主 workflow（`build.yml`）有版本注入**；其它 workflow 有就检查、没有不报
//     （否则拿这条去验别的文件会得到假阳性 —— 第250轮「判据有适用范围」）。
//   · **判据钉在"当时的正确写法"上**：第259轮要求过 `sed -i -f`，而那是第258轮已推翻的写法；
//     现在改成"要求 `sed -f`、禁止 `sed -i`"。以后工具链结论变了，这里要跟着改。
//   · 真正能不能跑，只能推上去看 Actions / Codemagic 的输出。
//     **这条检查的价值是"在推之前挡掉明显的结构错误"。**
const fs = require('fs');
const nodePath = require('path');
const PATHS = require('./_paths');

// 目标文件：显式参数 → 只验那一个；不给参数 → 验全部已知通道
function collectTargets() {
  const arg = process.argv[2];
  if (arg) return [nodePath.resolve(arg)];
  const out = [];
  const wfDir = nodePath.join(PATHS.REPO, '.github', 'workflows');
  if (fs.existsSync(wfDir)) {
    fs.readdirSync(wfDir).sort().forEach(f => {
      if (/\.ya?ml$/i.test(f)) out.push(nodePath.join(wfDir, f));
    });
  }
  ['codemagic.yaml', 'codemagic.yml'].forEach(f => {
    const p = nodePath.join(PATHS.REPO, f);
    if (fs.existsSync(p)) out.push(p);
  });
  return out;
}

function checkFile(wfPath) {
  const raw = fs.readFileSync(wfPath, 'utf8');
  const lines = raw.split(/\r?\n/);
  const problems = [];
  const problem = msg => problems.push(msg);

  // 1) 顶层必须出现 steps: 且每个 - name: 在 jobs.<id>.steps 下
  const stepLines = [];
  lines.forEach((l, i) => {
    const m = l.match(/^(\s*)- name:\s*(.+)$/);
    if (m) stepLines.push({ indent: m[1].length, name: m[2].trim(), line: i + 1 });
  });

  if (stepLines.length === 0) problem('没有找到任何 - name: 步骤');

  // 2) 所有步骤缩进必须一致
  const indents = new Set(stepLines.map(s => s.indent));
  if (indents.size !== 1) {
    problem(`步骤缩进不一致：${[...indents].join(', ')}（会导致 YAML 结构错乱）`);
  }

  // 3) block scalar（run: |）后面的内容必须比 run: 更深
  stepLines.forEach((s, idx) => {
    // 找这个步骤块的范围
    const start = s.line - 1;
    const end = idx + 1 < stepLines.length ? stepLines[idx + 1].line - 1 : lines.length;
    const block = lines.slice(start, end);
    // 两种块标量写法都要认：GitHub Actions 用 `run: |`，Codemagic 用 `script: |`。
    // 第259轮发现原来只认 `run:` → **对 codemagic.yaml 这一条判据直接 return 了**，
    // 等于它的多行脚本缩进错误从来没被检查过。
    const runIdx = block.findIndex(l => /^\s*(run|script):\s*\|/.test(l));
    if (runIdx < 0) return;
    const runIndent = block[runIdx].match(/^(\s*)/)[1].length;
    // run 内容从下一行开始
    let contentLines = 0;
    for (let i = runIdx + 1; i < block.length; i++) {
      const l = block[i];
      if (l.trim() === '') { contentLines++; continue; }
      const ind = l.match(/^(\s*)/)[1].length;
      if (ind <= runIndent) break;   // 回到同级 = 块结束
      contentLines++;
    }
    if (contentLines === 0) problem(`步骤「${s.name}」的块标量（run:/script: |）后面没有内容`);
  });

  // 4) 版本注入步骤的专项检查：printf 三行续行必须都在
  //
  // **步骤名有两种**：GitHub Actions 那份叫 `Inject version`，Codemagic 那份叫 `注入版本号`
  // （第259轮补的 —— 之前 `codemagic.yaml` **完全没有版本注入**，构建出来的包版本号是
  //  project.yml 里的静态 "1.0.0"/"1"，和 build-243 无法区分，「检查更新」也会误判）。
  //
  // **强制要求只对主 workflow**：`build.yml` 必须有；其它 workflow（如 codemagic.yaml）有就检查、
  // 没有不报。否则拿这条去验别的文件会得到假阳性 —— 判据有适用范围（第250轮）。
  const isMainWorkflow = nodePath.basename(wfPath) === 'build.yml';
  const iv = stepLines.find(s => s.name === 'Inject version' || s.name === '注入版本号');
  if (!iv) {
    if (isMainWorkflow) {
      problem('主 workflow 里没有版本注入步骤 —— 产出的包会自称 1.0.0(1)，第18轮那个 bug 会复发');
    }
  } else {
    const start = iv.line - 1;
    const idx = stepLines.indexOf(iv);
    const end = idx + 1 < stepLines.length ? stepLines[idx + 1].line - 1 : lines.length;
    const body = lines.slice(start, end).join('\n');

    // **先剥整行注释再判**。
    // 第259轮发现：原来的判据要求 `sed -i -f`，而 `build.yml` 之所以"通过"，
    // 是因为**注释里**写着「原来写的是 `sed -i -f /tmp/zl2-version.sed`」——
    // 注释把它满足了。（第143/150/175 轮同一个坑：注释被当成代码。）
    const bodyCode = body.split('\n').filter(l => !/^\s*#/.test(l)).join('\n');

    const checks = [
      [/VER=/, '缺少版本变量（VER=）'],
      [/printf/, '缺少 printf'],
      [/MARKETING_VERSION/, '缺少 MARKETING_VERSION 替换'],
      [/CURRENT_PROJECT_VERSION/, '缺少 CURRENT_PROJECT_VERSION 替换'],
      [/sed -f/, '缺少 sed -f 执行'],
      [/exit 1/, '缺少失败断言'],
    ];
    checks.forEach(([re, msg]) => { if (!re.test(bodyCode)) problem(msg); });

    // **绝对不能出现 `sed -i`**。
    // macOS 是 BSD sed，`-i` 必须跟一个备份后缀；写成 `-i -f x.sed` 会让三个参数全部错位
    // → `sed: 1: "/tmp/x.sed": invalid command code z`（第258轮 CI 第239次构建就是这么挂的）。
    // 正确写法是 `sed -f x.sed in > out && mv out in`（不碰 `-i`）。
    if (/sed\s+-i\b/.test(bodyCode)) {
      problem('用了 `sed -i` —— BSD sed 的 `-i` 必须跟备份后缀，`-i -f` 会让参数错位；改用 `sed -f x.sed in > out && mv out in`');
    }

    // 绝对不能残留 heredoc 结束符被缩进的问题
    if (/^\s+SEDEOF\s*$/m.test(body)) problem('heredoc 结束符被缩进（POSIX shell 无法识别）');
    // printf 的三行续行：两个反斜杠续行
    const contCount = (bodyCode.match(/\\\s*$/gm) || []).length;
    if (contCount < 2) problem(`printf 续行不足（找到 ${contCount} 个，至少 2 个）`);
  }

  // 5) 检查是否有 tab 混入（YAML 禁止 tab 缩进）
  lines.forEach((l, i) => {
    if (/^\t/.test(l)) problem(`第 ${i + 1} 行用 tab 缩进`);
  });

  return { problems, stepLines };
}

const targets = collectTargets();

// **零目标保护**：一个文件都没找到时，"全部通过"是空真（第137/139 轮那条）。
if (targets.length === 0) {
  console.log('✗ 一个 workflow 文件都没找到（.github/workflows/*.yml 与 codemagic.yaml 都不存在）——');
  console.log('  这不是"没问题"，是"没看到东西"。请核对 PATHS.REPO 与目录结构。');
  process.exit(1);
}

const multi = targets.length > 1;
let totalSteps = 0;
let failedFiles = 0;

for (const t of targets) {
  const rel = nodePath.relative(PATHS.REPO, t).replace(/\\/g, '/') || t;
  if (!fs.existsSync(t)) {
    console.log(`✗ ${rel}：文件读不到（改名或删了）—— 读不到就等于没查`);
    failedFiles++;
    continue;
  }
  const { problems, stepLines } = checkFile(t);
  totalSteps += stepLines.length;
  if (multi) console.log(`--- ${rel} ---`);
  if (problems.length === 0) {
    if (multi) {
      console.log(`✓ ${stepLines.length} 个步骤`);
    } else {
      console.log(`✓ workflow 结构校验通过（${stepLines.length} 个步骤）`);
      stepLines.forEach(s => console.log(`   - ${s.name}`));
    }
  } else {
    failedFiles++;
    console.log('✗ 发现问题：');
    problems.forEach(p => console.log('   - ' + p));
  }
}

if (multi) {
  console.log(`\n共校验 ${targets.length} 个 workflow 文件 · 步骤合计 ${totalSteps} 个 · ` +
    `${targets.length - failedFiles} 通过 / ${failedFiles} 失败`);
}

process.exit(failedFiles === 0 ? 0 : 1);
