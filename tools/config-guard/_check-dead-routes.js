// 死路由检查（声明了目的地，但没有任何导航过去）
//
// 起因：ios-zl2 第75轮扫 `AppRoute` 时发现 9 个 case **从来没人导航过去**：
//   .controlEditor .selectGameVersion .exportPack .crashLog .cleanFiles
//   .controlLayout .searchID .room .gameDirs（后三者后来确认有入口，见下）
// 它们对应的屏幕只在 `navigationDestination` 的 switch 里被构造一次，
// 等于页面写了、用户永远点不到 —— 和"View 写了没挂载"是同一类，但更隐蔽：
// `_check-orphan-views` 查不出来（因为这些 View 确实被 switch 引用了一次）。
//
// 判据：对每个 `case x`，在全部源码里找导航写法：
//   .append(.x        path.append(AppRoute.x      NavigationLink(value: .x
//   onOpen(.x         （本项目自定义的回调式导航）
// 一个都没有 → 死路由。带参数的路由（case x(T)）同样用 `(.x(` 前缀判断。
//
// 注意：这不是"错误"，是清理线索。有些路由可能是留给未来的，那也应该有注释说明。
//
// **局限**（不查什么）：
//   · **只判"有没有代码指向这个 case"**（`path.append(.x)` / `.sheet` 等）。`NavigationLink(destination:)`
//     直接写视图、或目的地分支里的隐式跳转，判据可能覆盖不到。
//   · **历史上"路由死但页面另有入口"的那些靠 `ALLOW` 登记 —— 现在只剩 `.room` 一个**（别再手写"几个"，跑一次看输出）。第157轮加了"登记必须真实存在"，
//     但**"页面另有入口"这句理由本身没人核**。
//   · **判不了"用户真的能走到"**：路由接上了，中间还可能有"按钮置灰""条件恒假"
//     （第133轮那个 `if enableTerracotta` 就是双重死代码 —— 路由有人接、入口恒不成立）。

const fs = require('fs');
const path = require('path');const { SRC } = require('./_paths');
const APP = path.join(SRC, 'ZL2App.swift');

const appSrc = fs.readFileSync(APP, 'utf8');
const allSrc = fs.readdirSync(SRC)
  .filter(f => f.endsWith('.swift'))
  .map(f => fs.readFileSync(path.join(SRC, f), 'utf8'))
  .join('\n');

// 从 enum AppRoute 块里取 case 名
const start = appSrc.indexOf('enum AppRoute');
if (start < 0) {
  console.log('✗ 找不到 enum AppRoute');
  process.exit(1);
}
const end = appSrc.indexOf('\n}', start);
const block = appSrc.slice(start, end < 0 ? start + 2000 : end);
const cases = [...block.matchAll(/case\s+(\w+)/g)].map(m => m[1]);

// 导航写法：逐行统计，跳过"目的地 switch"里那些 `case .x:` 行
// （那些只是声明目的地，不是导航过去）
const lines = allSrc.split('\n');
const navLines = lines.filter(l => {
  const s = l.trim();
  if (/^case\s+\./.test(s)) return false;          // switch 的 case
  if (/^\/\//.test(s)) return false;               // 注释
  return true;
});
const navText = navLines.join('\n');

// 已知的死路由（页面被取代 / 屏幕另有入口 / 明确是演示页）。
// 新增的死路由**不要**往这里加，先判断该接入口还是该删。
const ALLOW = {
  // 明确未接入的功能页（保留是有意的，理由如下）
  room:             'MultiplayerRoomScreen **已接入路由**（ZL2App 的 case .room 里渲染它），但界面没有导航到它的按钮 —— 远程联机需要 Network Extension（付费开发者账号）。所以这是「路由没入口」，不是「页面没实现」',
  // 第76-78轮已删除：exportPack / crashLog / selectGameVersion（页面被取代）
  //                searchID / serverList（已接上入口）
  //                gameDirs / cleanFiles / exportPackNew / controlLayout / logView
  //                （路由死但页面另有 sheet 入口，路由本身冗余，已清掉）
};

const dead = [];
for (const c of cases) {
  if (ALLOW[c]) continue;
  // 任意位置出现 `.x` 或 `AppRoute.x` 都算引用（append / onOpen / NavigationLink / 其它）
  const re = new RegExp(`(?:\\.|AppRoute\\.)${c}\\b`);
  if (!re.test(navText)) dead.push(c);
}

console.log(`AppRoute 共 ${cases.length} 个 case`);
console.log('');

// 提取某条路由目的地分支里"挂了什么"（修饰符 / 内部导航）。
// 为了抓一类具体问题：**有用的东西挂在死路由的目的地上 → 永远不生效**。
// 第78轮实例：`.zlGuide(.controlEditor)`（编辑器首次引导）只挂在死路由
// `.controlLayout` 的目的地，所以引导从来没显示过。
function destinationExtras(route) {
  const lines = allSrc.split('\n');
  const startIdx = lines.findIndex(l => new RegExp('^\\s*case \\.' + route + ':').test(l));
  if (startIdx < 0) return [];
  const extras = [];
  for (let i = startIdx + 1; i < lines.length; i++) {
    const s = lines[i].trim();
    if (/^case \./.test(s)) break;
    if (/^\.\w+\(/.test(s) || /path\.append\(/.test(s) || /onOpen\(/.test(s)) {
      extras.push(s.slice(0, 90));
    }
    if (extras.length >= 4) break;
  }
  return extras;
}

// **第157轮加的判据**：ALLOW 里登记的 case 必须真实存在于 AppRoute。
// 实例：`terracotta` 的 case 第132轮就随 TerracottaScreen 删了，但登记一直留着，
// 输出照旧说"已登记 2 个"，让人以为还有这个路由 —— **多余的登记会误导**。
const staleAllow = Object.keys(ALLOW).filter(k => !cases.includes(k));
if (staleAllow.length > 0) {
  console.log('⚠ ALLOW 里这些登记已经过时（AppRoute 里没这个 case 了）：');
  for (const k of staleAllow) console.log("    ." + k);
  console.log('  删掉它们 —— 多余的登记会让人以为还有这个路由。');
  process.exit(1);
}

console.log('· 已登记为已知死路由（' + Object.keys(ALLOW).length + ' 个，不判失败）：');
for (const k of Object.keys(ALLOW)) {
  console.log('    .' + k + '  —— ' + ALLOW[k]);
  const ex = destinationExtras(k);
  if (ex.length) {
    console.log('        ⚠ 它的目的地上还挂着：');
    for (const e of ex) console.log('            ' + e);
    console.log('        （没人走这条路由 → 上面这些也永远不生效，考虑挪到真实入口）');
  }
}
console.log('');

if (dead.length === 0) {
  console.log('✓ 没有新增的死路由');
  process.exit(0);
}

console.log(`⚠ ${dead.length} 个路由从没被导航（对应页面用户点不到）：`);
for (const c of dead) {
  // 找出它构造了哪个屏幕
  const m = allSrc.match(new RegExp(`case\\s+\\.${c}\\s*:\\s*([A-Za-z_][\\w]*)\\s*\\(`));
  const screen = m ? m[1] : '（未能识别）';
  console.log(`    .${c}   →  ${screen}`);
}
console.log('');
console.log('处理方式二选一：');
console.log('  ① 接上入口（如果这是该有的功能）');
console.log('  ② 删掉路由和屏幕（如果已被别的页面取代）');
console.log('  ③ 确实是留给未来的 → 在 case 上写注释说明，并把它加进本脚本的 ALLOW');
process.exit(1);
