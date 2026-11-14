// `setRoute("xxx")` 的字符串必须都有对应的消费分支（第161轮）
//
// "字符串当凭据"的第六类，而且是**双向**的：
//   写侧：`ZLPendingAction.setRoute("xxx")` 的调用
//   读侧：`handlePendingAction()` 里 `switch route { case "xxx": ... }` 的分支
//
// 第161轮实例：`ZL2App:34`（长按图标「设置」）写 `setRoute("settings")`，
// 但读侧的 switch 只有 download / versionList / multiplayer → `default: break` **静默丢弃**。
// 用户可见后果：长按图标点「设置」，App 打开但**不跳到设置页**。
//
// **局限**：
// · 只查 `ZLPendingAction.setRoute` 这一条路（别的待办机制各自要有自己的检查）。
// · 只比"有没有这个字符串 case"，判不了 case 里 append 的 AppRoute 对不对。
// · 读侧若有 `default:` 兜底，未知路由不会崩，但也不会生效 —— 所以必须静态比对。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));

// 写侧：所有 setRoute("xxx")
const written = new Set();
for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');
  for (const m of src.matchAll(/setRoute\(\s*"([^"]+)"\s*\)/g)) written.add(m[1]);
}

// 读侧：handlePendingAction 里 switch route 的 case
const app = fs.readFileSync(path.join(SRC, 'ZL2App.swift'), 'utf8');
const start = app.indexOf('private func handlePendingAction()');
if (start < 0) { console.log('✗ 找不到 handlePendingAction'); process.exit(1); }
const seg = app.slice(start, start + 2000);
const swStart = seg.indexOf('switch route {');
if (swStart < 0) { console.log('✗ 找不到 switch route'); process.exit(1); }
// 取到配对的 }
let depth = 0, end = -1;
for (let i = seg.indexOf('{', swStart); i < seg.length; i++) {
  if (seg[i] === '{') depth++;
  else if (seg[i] === '}') { depth--; if (depth === 0) { end = i; break; } }
}
const swBody = seg.slice(swStart, end + 1);
const handled = new Set([...swBody.matchAll(/case\s+"([^"]+)"/g)].map(m => m[1]));

console.log(`写侧 setRoute 用到的路由名：${written.size} 个 —— ${[...written].join('、')}`);
console.log(`读侧 switch 处理的路由名：${handled.size} 个 —— ${[...handled].join('、')}`);
console.log('');

const broken = [...written].filter(r => !handled.has(r));
const unused = [...handled].filter(r => !written.has(r));

if (broken.length === 0) {
  console.log('✓ 每个 setRoute 写进去的路由名都有对应的消费分支');
  if (unused.length > 0) {
    console.log(`\n（另有 ${unused.length} 个分支从没人写：${unused.join('、')} —— 预防性的，不算问题）`);
  }
  process.exit(0);
}

console.log(`⚠ ${broken.length} 个路由名**写了但没人消费**（会被 default 静默丢弃）：`);
for (const r of broken) console.log(`    "${r}"`);
console.log('');
console.log('用户可见后果：触发那个入口后 App 会打开，但**不跳到预期页面**，也没有任何提示。');
console.log('修法：在 `handlePendingAction()` 的 switch 里补 `case "' + broken[0] + '": path.append(...)`。');
process.exit(1);
