// project.yml 的 UIApplicationShortcutItemType 必须都有对应的 case（第160轮）
//
// "用字符串当凭据"的第五类（前四类：通知名 129 / 设置项 key 158 / UserDefaults 键 158 / SF Symbol 名 159）。
// 这一类的特殊之处：**跨文件类型** —— 声明在 `project.yml`（YAML），处理在 `ZL2App.swift`（Swift）。
//
// 失效形态：在 project.yml 加了快捷项但忘了在 Swift 里写 case →
// 长按图标点了**没反应**，`completionHandler(false)` 静默失败，没有任何提示。
//
// **局限**：
// · 只查 `UIApplicationShortcutItemType`（长按图标菜单）。Siri 快捷指令走 `AppIntent`，是另一套。
// · 只比"有没有对应的 case"，判不了 case 里的行为对不对。
// · project.yml 若改成别的配置格式（如 Info.plist 直接写），这条查不到。
const fs = require('fs');
const path = require('path');

const { REPO, SRC } = require('./_paths');

const yml = fs.readFileSync(path.join(REPO, 'project.yml'), 'utf8');
const app = fs.readFileSync(path.join(SRC, 'ZL2App.swift'), 'utf8');

// project.yml 里声明的 type
const declared = [...yml.matchAll(/UIApplicationShortcutItemType:\s*(\S+)/g)].map(m => m[1].trim());

// ZL2App 里处理的 type（case "..." 后面可能跟冒号）
const handled = new Set([...app.matchAll(/case\s+"([^"]+)":/g)].map(m => m[1]));

console.log(`project.yml 声明 ${declared.length} 个快捷项 · ZL2App 处理 ${handled.size} 个字符串 case`);
console.log('');

const missing = declared.filter(t => !handled.has(t));
if (missing.length === 0) {
  console.log('✓ 每个声明的快捷项都有对应的 case');
  for (const t of declared) console.log(`    ${t}`);
  process.exit(0);
}

console.log(`⚠ ${missing.length} 个快捷项在 ZL2App 里没有对应的 case：`);
for (const t of missing) console.log(`    ${t}`);
console.log('');
console.log('后果：长按 App 图标点这一项 **没反应** —— `completionHandler(false)` 静默失败，无任何提示。');
console.log('修法：在 `ZLAppDelegate.application(_:performActionFor:completionHandler:)` 里补 case。');
process.exit(1);
