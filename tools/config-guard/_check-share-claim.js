// 文案承诺的"从其他 App 分享进来"必须有 CFBundleDocumentTypes（第166轮）
//
// 第166轮发现：`FileManagerScreen` 的空状态写着「或者从其他 App 把文件分享到 CraftLauncher 里」，
// 但 `project.yml` **没有 `CFBundleDocumentTypes`**、代码也没有 `onOpenURL` 接收
// → 对方 App 的「用其他应用打开」里根本不会出现 CraftLauncher，**那条路走不通**。
//
// 这是"文案教了做不到的操作"的一个特殊形态：**承诺的不是代码能力，而是系统级声明**
// （`CFBundleDocumentTypes` 写在 `project.yml` 里，编译器完全不管）。
//
// **局限**：
// · 只认几个关键词（"从其他 App" / "分享到"/"用其他应用打开"）。换个说法（"导出到"）查不到。
// · 只查 `CFBundleDocumentTypes` 这一个声明。文案承诺别的系统能力（通知 / 定位 / 相册）不在这条范围。
// · 判不了"声明了但 onOpenURL 没实现" —— 那种情况会在真机上表现为点了没反应，只能靠回读代码。
const fs = require('fs');
const path = require('path');

const { REPO, SRC } = require('./_paths');

const yml = fs.readFileSync(path.join(REPO, 'project.yml'), 'utf8');
const hasDocTypes = /CFBundleDocumentTypes/.test(yml);

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const KEYWORDS = /从其他 ?App|分享到 ?CraftLauncher|用其他应用打开|用其他 ?App ?打开/;

const claims = [];
for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');
  const lines = src.split(/\r?\n/);
  lines.forEach((line, i) => {
    if (line.trim().startsWith('//')) return;
    const m = line.match(/"([^"]{6,})"/);        // 只查字符串字面量里的
    if (!m) return;
    if (!KEYWORDS.test(m[1])) return;
    claims.push({ file: f, line: i + 1, text: m[1].slice(0, 60) });
  });
}

console.log(`project.yml 声明 CFBundleDocumentTypes：${hasDocTypes ? '是' : '否'}`);
console.log(`文案里承诺"从其他 App 分享/打开"的地方：${claims.length} 处`);
console.log('');

if (claims.length === 0) {
  console.log('✓ 没有文案承诺"从其他 App 分享进来"（或已改成准确说法）');
  process.exit(0);
}

if (hasDocTypes) {
  console.log('（有 CFBundleDocumentTypes 声明，文案可以这么写 —— 但记得确认 onOpenURL 也实现了）');
  for (const c of claims) console.log(`    ${c.file}:${c.line}  "${c.text}"`);
  process.exit(0);
}

console.log(`⚠ ${claims.length} 处文案承诺了系统做不到的事：`);
for (const c of claims) {
  console.log(`  ${c.file}:${c.line}  "${c.text}"`);
}
console.log('');
console.log('为什么：`project.yml` 没有 `CFBundleDocumentTypes`，对方 App 的「用其他应用打开」里');
console.log('  **不会出现** CraftLauncher。用户按文案去试，会发现"根本找不到这个 App"。');
console.log('修法二选一：①在 project.yml 声明 CFBundleDocumentTypes + 实现 onOpenURL 接收');
console.log('            ②改文案，只说能做到的（如"用「文件」App 拖进 Documents 文件夹"）');
process.exit(1);
