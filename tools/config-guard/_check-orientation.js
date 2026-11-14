// 声明了竖屏就必须有"游戏时切横屏"的逻辑（第165轮）
//
// 背景：启动器界面是 `VStack` 竖排设计，游戏是横屏。
// `project.yml` 给 iPhone 声明了 `UIInterfaceOrientationPortrait`，
// 那么 `CoreBridge` 在进 `launchJVM` 之前必须把 `ZLAppDelegate.orientationLock`
// 切到 `.landscapeRight`，否则**游戏会以竖屏方向渲染横屏内容**（画面被裁切/拉伸）。
//
// 反过来：如果只声明横屏（不给 Portrait），那就不需要切换 —— 启动器和游戏都是横的。
//
// 这条检查守的是"有人把切换逻辑删了但忘了改声明"。
//
// **局限**：
// · 只查 `UISupportedInterfaceOrientations`（iPhone）那一段，不管 `~ipad`。
// · 只数 `.landscapeRight` / `.landscape` 的出现次数，判不了切换时机对不对
//   （那要真机看：进游戏是否转横屏、退出是否转回竖屏）。
const fs = require('fs');
const path = require('path');

const { REPO, SRC } = require('./_paths');

const yml = fs.readFileSync(path.join(REPO, 'project.yml'), 'utf8');
const bridge = fs.readFileSync(path.join(SRC, 'CoreBridge.swift'), 'utf8');

// 取 iPhone 那段 UISupportedInterfaceOrientations（到 ~ipad 之前）
const start = yml.indexOf('UISupportedInterfaceOrientations:');
if (start < 0) { console.log('✗ project.yml 里找不到 UISupportedInterfaceOrientations'); process.exit(1); }
const ipadIdx = yml.indexOf('UISupportedInterfaceOrientations~ipad:', start);
const seg = yml.slice(start, ipadIdx > 0 ? ipadIdx : start + 600);

const hasPortrait = /UIInterfaceOrientationPortrait/.test(seg);
const rotations = (bridge.match(/orientationLock\s*=\s*\.landscape/g) || []).length;
const backToPortrait = (bridge.match(/orientationLock\s*=\s*\.portrait/g) || []).length;

console.log(`iPhone 声明了竖屏：${hasPortrait ? '是' : '否'}`);
console.log(`CoreBridge 里切横屏 ${rotations} 次 · 切回竖屏 ${backToPortrait} 次`);
console.log('');

const problems = [];
if (hasPortrait && rotations === 0) {
  problems.push('声明了竖屏，但代码里**没有**切横屏的逻辑 —— 游戏会竖屏渲染横屏内容（画面裁切/拉伸）');
}
if (hasPortrait && rotations !== backToPortrait) {
  problems.push(`切横屏 ${rotations} 次、切回竖屏 ${backToPortrait} 次 —— **不配对**（可能退出游戏后还是横的）`);
}
if (!hasPortrait && rotations > 0) {
  problems.push('代码里有切方向逻辑，但 project.yml 没声明竖屏 —— 那 `orientationLock` 永远是横屏，切换是死代码');
}

if (problems.length === 0) {
  console.log('✓ 方向声明与切换逻辑配对');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 个问题：`);
for (const p of problems) console.log('  · ' + p);
console.log('');
console.log('修法看情况：如果启动器是竖屏设计 → 声明 Portrait + 在 launchJVM 前后切方向；');
console.log('            如果全 App 都横屏 → 去掉 Portrait，同时删掉切换逻辑。');
process.exit(1);
