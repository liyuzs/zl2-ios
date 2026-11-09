// 孤儿 View 检查（写了没挂载）
//
// 起因：ios-zl2 第67轮扫 `struct X: View` 时发现 6 个**声明了但从没被实例化**的
// 组件，其中两个是彩蛋特效：
//   · ZLStarBurst —— 注释写着「点哪里冒哪里的小星星」
//   · ZLHeartPop  —— 「爱心（点头像）」
// 代码写好了、动画也写好了，但**从没接到任何界面上**，所以彩蛋只有一句话、
// 没有视觉效果。另外三个是重复的进度数字组件和一个空状态波浪线。
//
// 这类"写了没挂载"比 bug 更隐蔽：代码能编译、检查全绿，只是用户永远看不到。
//
// 判据：`struct NAME: View` 的 NAME 在整个 src 目录里只出现 1 次（就是它自己的
// 声明）→ 没有人用它。
//
// 注意误报可能：
//   · 通过泛型/反射动态引用（本项目没有）
//   · 只在条件编译里用（本项目没有）
// 所以本检查直接判失败。

const fs = require('fs');
const path = require('path');
const { SRC } = require('./_paths');
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

const texts = new Map();
for (const f of files) texts.set(f, fs.readFileSync(path.join(SRC, f), 'utf8'));
const joined = [...texts.values()].join('\n');

const orphans = [];
let declared = 0;

for (const [name, text] of texts) {
  const re = /^[ \t]*(?:public |internal |private |fileprivate |final )?struct\s+([A-Za-z_]\w*)\s*:\s*View\b/gm;
  let m;
  while ((m = re.exec(text)) !== null) {
    declared++;
    const view = m[1];
    const count = (joined.match(new RegExp(`\\b${view}\\b`, 'g')) || []).length;
    if (count <= 1) {
      const line = text.slice(0, m.index).split('\n').length;
      orphans.push({ name, view, line });
    }
  }
}

console.log(`声明为 View 的 struct：${declared} 个`);
console.log('');

if (orphans.length === 0) {
  console.log('✓ 每个 View 都至少被引用一次（没有"写了没挂载"）');
  process.exit(0);
}

console.log(`⚠ ${orphans.length} 个 View 从没被实例化（代码写了但用户看不到）：`);
for (const o of orphans) {
  console.log(`    ${o.view}   ${o.name}:${o.line}`);
}
console.log('');
console.log('修法二选一：① 接到界面上（如果它代表某个该有的功能）② 删掉（如果已经不需要）');
process.exit(1);
