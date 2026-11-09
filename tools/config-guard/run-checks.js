#!/usr/bin/env node
// 跨平台跑「和 _run-all.ps1 同一份清单」的检查
//
// 为什么需要它：
//   `_run-all.ps1` 是 PowerShell 的，只能在 Windows 跑；而 CI 是 macOS。
//   但**清单不能有两份** —— 两份必然漂（第79/87轮已经栽过一次"统计口径不同"）。
//   所以这个脚本直接**解析 `_run-all.ps1` 里的数组**，把它当唯一来源，
//   然后逐个用 node / pwsh 执行。
//
// 用法：
//   node run-checks.js                 # 跑 $checks（默认）
//   node run-checks.js --with-tests    # 再跑 $tests（契约测试）
//   node run-checks.js --quiet         # 只输出失败的
//
// 退出码：0 全通过；1 有失败。CI 直接用它。

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const GUARD = __dirname;
const RUN_ALL = path.join(GUARD, '_run-all.ps1');

const argv = process.argv.slice(2);
const withTests = argv.includes('--with-tests');
const quiet = argv.includes('--quiet');

if (!fs.existsSync(RUN_ALL)) {
  console.error('✗ 找不到 _run-all.ps1（清单的唯一来源）');
  process.exit(1);
}
const src = fs.readFileSync(RUN_ALL, 'utf8');

// 从 _run-all.ps1 里切出 $checks / $tests 两段，再抽三元组的第一项
function extract(sectionName) {
  const start = src.indexOf('$' + sectionName + ' = @(');
  if (start < 0) return [];
  const end = src.indexOf('\n)', start);
  const block = src.slice(start, end < 0 ? start + 8000 : end);
  const out = [];
  for (const m of block.matchAll(/@\('([^']+\.(?:js|ps1))'\s*,\s*'(\w+)'\s*,\s*'([^']*)'\)/g)) {
    out.push({ file: m[1], kind: m[2], desc: m[3] });
  }
  return out;
}

const checks = extract('checks');
const tests = extract('tests');
const plan = withTests ? checks.concat(tests) : checks;

if (plan.length === 0) {
  console.error('✗ 没能从 _run-all.ps1 解析出任何检查（数组格式变了？）');
  process.exit(1);
}

// PowerShell 是否可用（macOS / Linux runner 通常自带 pwsh）
const hasPwsh = (() => {
  const r = spawnSync('pwsh', ['-NoProfile', '-Command', 'exit 0'], { stdio: 'ignore' });
  return r.status === 0;
})();

const results = [];
for (const item of plan) {
  const full = path.join(GUARD, item.file);
  if (!fs.existsSync(full)) {
    results.push({ ...item, ok: false, note: '文件不存在' });
    continue;
  }

  let r;
  if (item.kind === 'ps1' || item.file.endsWith('.ps1')) {
    if (!hasPwsh) {
      results.push({ ...item, ok: true, note: '跳过（本环境没有 pwsh）' });
      continue;
    }
    r = spawnSync('pwsh', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', full], {
      encoding: 'utf8', timeout: 180000,
    });
  } else {
    r = spawnSync(process.execPath, [full], { encoding: 'utf8', timeout: 180000 });
  }

  const ok = r.status === 0;
  const tail = ((r.stdout || '') + (r.stderr || ''))
    .trim().split('\n').filter(l => l.trim()).slice(-1)[0] || '';
  results.push({ ...item, ok, note: ok ? '' : tail.slice(0, 120) });
  if (!ok && !quiet) {
    console.log(`✗ ${item.file}  (${item.desc})`);
    if (tail) console.log('  ' + tail.slice(0, 160));
  }
}

const failed = results.filter(x => !x.ok);
if (!quiet) {
  console.log('');
  console.log('=== ' + (plan.length - failed.length) + ' 项通过，' + failed.length + ' 项失败 ===');
}
if (failed.length) {
  console.log('失败明细：');
  for (const f of failed) console.log(`  ✗ ${f.file}  ${f.note}`);
  process.exit(1);
}
console.log('全部通过。');
