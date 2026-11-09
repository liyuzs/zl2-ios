// README 声明 ↔ 代码实现 的契约
//
// 起因：ios-zl2 第69/70/71 轮连续在 README 里查出三处"说了但代码不是那样"：
//   · 「不以 ZL2 命名」 → 界面 8 处自称 ZL2（第69轮）
//   · 「支持 1.8 ~ 26+」 → 1.11 及更早需要 Java 8，包里没带（第70轮）
//   · 「内存按物理内存 1/3 自适应」 → 实际是默认 25%、手动上限 50%（第71轮）
//
// 这类问题双方单独看都对，错在两者之间没人核对。所以把 README 里**能被机器验证的
// 具体数值/事实**逐条写成断言：改了代码没改文档、或改了文档没改代码，都会红。
//
// 只登记「能明确对应到某段代码」的声明，笼统的形容词不查。

const PATHS = require('./_paths');
const fs = require('fs');
const path = require('path');

const ROOT = PATHS.REPO;
const read = p => fs.readFileSync(path.join(ROOT, p), 'utf8');

const readme = read('README.md');
const coreBridge = read('src/CoreBridge.swift');
const plPrefs = read('core/PLPreferences.m');
const launcher = read('core/JavaLauncher.m');

// 每条：README 里必须出现的字样 / 代码里必须有的实现 / 说明
const CLAIMS = [
  {
    claim: /内存默认按物理内存\s*25%\s*自动分配/,
    code: /\*\s*0\.25/,
    in: plPrefs,
    why: 'README 说默认 25%，代码里应是 PLPreferences 的 allocated_memory 默认值 × 0.25',
  },
  {
    claim: /上限会压到\s*50%/,
    code: /ramMB\s*\/\s*2/,
    in: coreBridge,
    why: 'README 说手动上限 50%，代码里应是 physicalMemory/2',
  },
  {
    claim: /视距\s*4/,
    code: /renderDistance:4/,
    in: coreBridge,
    why: 'README 说首次写入视距 4',
  },
  {
    claim: /粒子最少/,
    code: /particles:2/,
    in: coreBridge,
    why: 'README 说粒子最少（MC options 里 2 = minimal）',
  },
  {
    claim: /G1GC/,
    code: /-XX:\+UseG1GC/,
    in: launcher,
    why: 'README 说用 G1GC',
  },
  {
    claim: /MaxGCPauseMillis=20/,
    code: /-XX:MaxGCPauseMillis=20/,
    in: launcher,
    why: 'README 说 MaxGCPauseMillis=20',
  },
  {
    claim: /1\.12\s*~\s*26\+/,
    // ≤1.11 返回 8（不支持），1.12~1.16 返回 17 —— 两者都要在
    code: /if mi >= 12 \{ return 17 \}/,
    in: coreBridge,
    why: 'README 说支持 1.12+，代码里 1.12~1.16 应落到 Java 17',
  },
  {
    claim: /1\.12\s*~\s*26\+/,
    code: /return 8\s+\/\/\s*≤1\.11/,
    in: coreBridge,
    why: 'README 说 1.11 及更早不支持，代码里应明确返回 8',
  },
];

let pass = 0;
const fail = [];

for (const c of CLAIMS) {
  const inDoc = c.claim.test(readme);
  const inCode = c.code.test(c.in);
  if (inDoc && inCode) { pass++; continue; }
  fail.push({
    why: c.why,
    missingInDoc: !inDoc,
    missingInCode: !inCode,
  });
}

console.log(`核对 ${CLAIMS.length} 条 README 声明`);
console.log('');

if (fail.length === 0) {
  console.log('✓ README 里能机器验证的声明，与代码实现一致');
  process.exit(0);
}

console.log(`⚠ ${fail.length} 条对不上：`);
for (const f of fail) {
  console.log(`\n  ${f.why}`);
  if (f.missingInDoc) console.log('    · README 里找不到这条声明（可能被改写/删了）');
  if (f.missingInCode) console.log('    · 代码里找不到对应实现（可能改了实现没改文档）');
}
console.log('');
console.log('修法：让两边对齐 —— 改文档或改代码，别放着。');
process.exit(1);
