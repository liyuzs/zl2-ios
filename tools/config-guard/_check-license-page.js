// 许可页 ↔ 实际打包内容 的一致性
//
// 起因：ios-zl2 第103轮把「关于与开源许可」页和 `Frameworks/`、`libs/*.jar`、`jre/` 对了一遍，
// 三类问题全都中：
//   A. 列了但没打包：MobileGlues（仓库里一个文件都没有，代码注释还写着"iOS 上根本不存在"）
//   B. 打包了但没列：AltKit / CAltKit、FreeType、shaderc、Gson、jsr305
//   C. 不完整：只写「OpenJDK 17」，而包里是 17 / 21 / 25
//
// 许可页错了不会报错、不影响运行，但对 GPL 衍生项目是**实质性的署名缺失** ——
// 而这个项目第 69 轮已经因为 GPL 第 7 条（命名）栽过一次，不能再靠人眼。
//
// 判据（按文件名里的关键词比对，不追求完备，只求抓住"新增了第三方却没署名"）：
//   1. Frameworks/ 里每个二进制/框架，其"可能的项目名"必须在许可页里出现过
//   2. libs/*.jar 同上
//   3. jre/ 里的每个大版本号，许可页必须提到
// 允许在 ALLOW 里登记"同一条目已覆盖"的映射（如 liblwjgl_* → LWJGL 3）。

// **局限**
// · 只校验"仓库里的文件"与"许可页列出的组件"双向对得上；有文件但许可页描述写错、许可类型标错，它查不出。
// · MAP 表是人工维护的：新增一个随包分发的二进制/库/框架，必须同时加进 MAP，否则会漏。
// · **失效条件**：组件改名（比如 `libfreetype.dylib` → `libfreetype.6.dylib`）时，MAP 里的旧名字会永远匹配不上 —— 表现为"检查报缺"，不是静默失效。
const fs = require('fs');
const path = require('path');

const { REPO } = require('./_paths');

const LICENSE = path.join(REPO, 'src', 'LicenseScreen.swift');
const FW = path.join(REPO, 'core', 'resources', 'Frameworks');
const LIBS = path.join(REPO, 'core', 'resources', 'libs');
const JRE = path.join(REPO, 'jre');

// 文件名关键词 → 许可页里应该出现的关键词
const MAP = [
  { file: /^liblwjgl/, page: 'LWJGL' },
  { file: /^libgl4es|^libOSMesa|^libglapi/, page: 'Mesa' },
  { file: /^libMoltenVK/, page: 'MoltenVK' },
  { file: /^libopenal/, page: 'OpenAL' },
  { file: /^libfreetype/, page: 'FreeType' },
  { file: /^libshaderc|^lwjgl-shaderc/, page: 'shaderc' },
  { file: /^AltKit|^CAltKit/, page: 'AltKit' },
  { file: /^UnzipKit/, page: 'UnzipKit' },
  { file: /^libEGL|^libGLESv2/, page: 'Mesa' },   // tinygl4angle 走 Mesa/ANGLE
  { file: /^libvirgl_test_server/, page: 'Mesa' },
  { file: /^gson/, page: 'Gson' },
  { file: /^jsr305/, page: 'jsr305' },
  { file: /^launcher\.jar|^arc_dns_injector/, page: 'Amethyst' },
  { file: /^lwjgl3-minecraft|^lwjgl-vulkan|^lwjgl-vma/, page: 'LWJGL' },
];

const problems = [];

let page = '';
try { page = fs.readFileSync(LICENSE, 'utf8'); }
catch { console.log('✗ 找不到 LicenseScreen.swift'); process.exit(1); }

function checkDir(dir, label) {
  let entries = [];
  try { entries = fs.readdirSync(dir); } catch { return; }
  for (const name of entries) {
    const rule = MAP.find(m => m.file.test(name));
    if (!rule) {
      problems.push(`${label}/${name} 没有对应的署名映射 —— 新增了第三方组件？请在 MAP 里登记它该对应许可页的哪一项`);
      continue;
    }
    if (!page.includes(rule.page)) {
      problems.push(`${label}/${name} 应在许可页提到「${rule.page}」，但页面里没有`);
    }
  }
}

checkDir(FW, 'Frameworks');
checkDir(LIBS, 'libs');

// JRE 大版本号
try {
  const tars = fs.readdirSync(JRE).filter(f => /^jre(\d+)-/.test(f));
  for (const t of tars) {
    const v = t.match(/^jre(\d+)-/)[1];
    if (!page.includes(v)) problems.push(`jre/ 里有 Java ${v}，但许可页的 OpenJDK 条目没提到 ${v}`);
  }
} catch {}

// 反向：页面列了但磁盘没有的（只查最明显的几个名字）
for (const gone of ['MobileGlues']) {
  if (!page.includes(gone)) continue;
  const exists = fs.existsSync(path.join(REPO, 'core', 'resources', 'Frameworks'))
    && fs.readdirSync(path.join(REPO, 'core', 'resources', 'Frameworks')).some(f => new RegExp(gone, 'i').test(f));
  if (!exists) problems.push(`许可页列了 ${gone}，但仓库里找不到它的任何文件 —— 要么补文件，要么删条目`);
}

console.log('核对许可页 ↔ Frameworks / libs / jre');
console.log('');

if (problems.length === 0) {
  console.log('✓ 许可页与随包分发的内容对得上');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处不一致：`);
for (const p of problems) console.log(`  · ${p}`);
console.log('');
console.log('修法：给漏掉的组件补署名条目；删掉没有对应文件的条目；或在 MAP 里登记"同一署名已覆盖"。');
process.exit(1);
