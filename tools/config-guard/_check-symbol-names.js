// SF Symbol 名必须来自"已验证清单"（第159轮）
//
// 背景：`Image(systemName: "xxx")` 的名字是字符串 —— 拼错**编译不报错**，
// 运行期 `Image` 对无效名**不报错、不崩溃，只渲染成空白**。
// 第159轮实例：`folder.fill.badge.person.crop` 不存在（只有 `folder.badge.person.crop`），
// "当前游戏目录"卡片的图标一直是空的，没人发现。
//
// 没有 SF Symbols 完整列表就没法自动验证，所以用**基线冻结**（第133轮的方法）：
// 把当前**人工核实过**的名字固化在下面。新增的名字 → 报错，要求人工确认后登记。
//
// **局限**：
// · 清单是**冻结快照**，不是权威列表 —— 它只保证"没引入新的未知名字"，
//   不保证清单里的每个都真的存在（那 66 个是第159轮逐个看过的）。
// · 判不了"名字存在但和语义不搭"（比如用 `trash` 表示"设置"）。
// · 只能查 `systemName:` 直接写字面量的情况；用变量传名字查不到。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

// 第159轮逐个核实过的 66 个名字（含 SF Symbols 版本适配）
const VERIFIED = new Set([
  'antenna.radiowaves.left.and.right', 'arrow.clockwise', 'arrow.counterclockwise',
  'arrow.down.circle.fill', 'arrow.down.to.line', 'arrow.triangle.2.circlepath',
  'arrow.up.right', 'arrow.up.right.square', 'checkmark', 'checkmark.circle',
  'checkmark.circle.fill', 'checkmark.seal.fill', 'chevron.down', 'chevron.left',
  'chevron.right', 'circle', 'cube', 'cube.fill', 'cup.and.saucer.fill',
  'doc.on.doc', 'doc.text', 'doc.text.fill', 'ellipsis', 'ellipsis.circle',
  'exclamationmark.bubble', 'exclamationmark.circle.fill', 'exclamationmark.triangle.fill',
  'eye.slash.fill', 'folder', 'folder.fill', 'folder.badge.person.crop',
  'gearshape.fill', 'heart.fill', 'info.circle', 'info.circle.fill', 'iphone',
  'lightbulb', 'link', 'list.bullet.clipboard', 'lock.fill', 'magnifyingglass',
  'map.fill', 'number', 'number.circle', 'pencil', 'person.badge.key',
  'person.badge.key.fill', 'person.crop.rectangle', 'person.fill', 'photo',
  'photo.on.rectangle.angled', 'plus', 'plus.circle.fill', 'puzzlepiece.fill',
  'safari', 'server.rack', 'shippingbox', 'slider.horizontal.3', 'sparkles',
  'square.and.arrow.up', 'square.stack.3d.up.fill', 'star.fill', 'sun.max.fill',
  'trash', 'wrench.and.screwdriver.fill', 'xmark', 'xmark.circle.fill',
]);

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const unknown = [];

for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');
  const lines = src.split(/\r?\n/);
  lines.forEach((line, i) => {
    if (line.trim().startsWith('//')) return;
    for (const m of line.matchAll(/systemName:\s*"([^"]+)"/g)) {
      const n = m[1];
      if (!VERIFIED.has(n)) unknown.push({ file: f, line: i + 1, name: n });
    }
  });
}

console.log(`已验证的 SF Symbol 名：${VERIFIED.size} 个`);
console.log(`不在清单里的：${unknown.length} 处`);
console.log('');

if (unknown.length === 0) {
  console.log('✓ 所有 systemName 都来自已验证清单');
  process.exit(0);
}

const byName = {};
for (const u of unknown) (byName[u.name] ||= []).push(u.file + ':' + u.line);

console.log(`⚠ ${Object.keys(byName).length} 个新名字（需要人工确认是否存在）：`);
for (const [n, where] of Object.entries(byName)) {
  console.log(`  ${n}  ← ${where.join(' · ')}`);
}
console.log('');
console.log('为什么必查：`Image(systemName:)` 对无效名**不报错、不崩溃，只渲染成空白**。');
console.log('  第159轮就发现过一个：`folder.fill.badge.person.crop` 不存在（只有 folder.badge.person.crop），');
console.log('  "当前游戏目录"卡片的图标一直是空的。');
console.log('');
console.log('处理：在真实设备/SF Symbols App 里确认存在后，加进脚本的 VERIFIED 清单。');
process.exit(1);
