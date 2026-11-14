// 快捷指令待处理动作：写入方 / 消费方 / 时效 三方都要在
//
// 起因：ios-zl2 第90轮查「Siri / 快捷指令跳转」这条链路时发现三个问题：
//   ① `.task` 只在 RootView 首次出现时跑 → App 已在运行中收到快捷指令时，没人消费
//   ② `zl.pendingRoute` 没有时间戳 → 没被消费的路由会一直留着，下次冷启动突然跳页
//   ③ 写入点分散在三个文件里各写一遍 UserDefaults（每加一处都要记得补时间戳）
//
// 判据（结构完整性，不判断行为）：
//   1. `ZLPendingAction` 必须有 `setRoute(`（唯一写入口）和 `consumeRoute(`
//   2. `consumeRoute` 里必须读 `zl.pendingRouteAt` 并做过期判断
//   3. 除 `ZLPendingAction.setRoute` 之外，任何地方都不许直接 `set(...forKey: "zl.pendingRoute")`
//   4. RootView 必须同时有 `.task` 和 `scenePhase` 消费（冷启动 + 回到前台）
//
// **局限**（不查什么）：
//   · **只查结构，不查行为**（上面第 4 行自己就写了）。具体不查的：① `consumeRoute()` 里的分支逻辑对不对
//     ② 过期时间定 **2 分钟**合不合理 ③ `setRoute` 写的字符串**有没有对应的消费分支**
//     —— ③ 那个由 `_check-pending-routes` 管（第161轮就是它抓到 `"settings"` 没消费分支，真 bug）。
//   · **只认这 4 条结构**。如果将来换成 `onOpenURL` + `CFBundleURLSchemes` 那一套机制，
//     这 4 条全都不适用，**而检查会继续报 ✓**（"机制换了"这件事本身没人提醒）。
//   · **守不住"写入方被绕过"**：判据 3 只查 `set(...forKey: "zl.pendingRoute")` 这一种写法。
//     写成 `setValue(_:forKey:)` 或别的 UserDefaults API，看不见。
//   · **"`attemptAutoLaunch` 至少两处调用"是硬编码的 2** —— 合法重构变成一处或三处时，
//     判据会误报或漏报。它是"当时那条时序 bug 的形状"，不是不变量。

const fs = require('fs');
const path = require('path');
const { SRC } = require('./_paths');
const read = f => fs.readFileSync(path.join(SRC, f), 'utf8');

const problems = [];
const extras = read('ZLiOSExtras.swift');
const app = read('ZL2App.swift');

// 1. 唯一写入口与消费口
if (!/static func setRoute\(/.test(extras)) {
  problems.push('ZLiOSExtras.swift 缺少 ZLPendingAction.setRoute(_:) —— 写入点会散落各处');
}
if (!/static func consumeRoute\(/.test(extras)) {
  problems.push('ZLiOSExtras.swift 缺少 ZLPendingAction.consumeRoute()');
}

// 2. 时效
const consumeBlock = (() => {
  const i = extras.indexOf('static func consumeRoute');
  return i < 0 ? '' : extras.slice(i, i + 500);
})();
if (consumeBlock && !consumeBlock.includes('zl.pendingRouteAt')) {
  problems.push('consumeRoute() 没读过期时间戳（zl.pendingRouteAt）—— 没被消费的路由会在下次冷启动突然跳页');
}

// 3. 写入只能走 setRoute
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
for (const f of files) {
  const src = read(f);
  const lines = src.split('\n');
  lines.forEach((line, i) => {
    if (l => l) { /* noop */ }
    if (!/set\([^)]*forKey:\s*"zl\.pendingRoute"/.test(line)) return;
    if (f === 'ZLiOSExtras.swift') return;              // setRoute 本体在里面
    problems.push(`${f}:${i + 1} 直接写了 zl.pendingRoute —— 应改调 ZLPendingAction.setRoute(...)（否则会漏时间戳）`);
  });
}

// 3.5 自动启动意图：标志 + 时效 + 两处尝试
if (!/markAutoLaunchPending\(/.test(extras) || !/consumeAutoLaunchPending\(/.test(extras)) {
  problems.push('ZLiOSExtras.swift 缺少自动启动意图的 markAutoLaunchPending / consumeAutoLaunchPending');
}
const autoBlock = (() => {
  const i = extras.indexOf('static func consumeAutoLaunchPending');
  return i < 0 ? '' : extras.slice(i, i + 400);
})();
if (autoBlock && !autoBlock.includes('zl.pendingAutoLaunchAt')) {
  problems.push('consumeAutoLaunchPending() 没有过期判断 —— 旧的启动意图会在很久之后突然生效');
}
const home = read('HomeScreen.swift');
if (!/attemptAutoLaunch\(\)/.test(home)) {
  problems.push('HomeScreen.swift 没有 attemptAutoLaunch() —— 通知来得太早时启动意图会被丢掉');
}
// 两处都要调：onReceive（通知）与读完版本列表之后
const attempts = (home.match(/attemptAutoLaunch\(\)/g) || []).length;
if (attempts < 3) {   // 1 处定义 + 至少 2 处调用
  problems.push(`HomeScreen.swift 只调了 ${attempts - 1} 处 attemptAutoLaunch() —— 应在"收到通知"和"读完版本列表"两处都试`);
}
if (/guard !selectedVersion\.isEmpty[^\n]*else \{ return \}/.test(home) && !/attemptAutoLaunch/.test(home)) {
  problems.push('HomeScreen.swift 仍在用"条件不满足就直接 return"的一次性写法');
}

// 4. 前台消费
if (!/scenePhase/.test(app)) {
  problems.push('ZL2App.swift 里没有 scenePhase —— App 运行中收到的快捷指令不会被消费');
}
if (!/handlePendingAction\(\)/.test(app)) {
  problems.push('ZL2App.swift 里没有统一的 handlePendingAction() —— .task 与前台激活应共用同一段消费逻辑');
}

console.log('检查快捷指令待处理动作的四处结构');
console.log('');

if (problems.length === 0) {
  console.log('✓ 写入口唯一、消费有冷启+前台两条路径、路由有时效');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处结构缺失：`);
for (const p of problems) console.log(`  · ${p}`);
process.exit(1);
