// 深色模式是否真的生效
//
// 起因：ios-zl2 第84轮查界面硬编码颜色时，顺手发现一个更根本的问题 ——
// **「深色模式」是死开关**：
//   · `ColorThemes.swift` 里 `ZLColorTheme` 所有访问器传的都是 `"...Light"` 键名
//     （primaryLight / backgroundLight / surfaceLight …）
//   · 色板里 35 组 × 7 主题的 `...Dark` 数据**完整存在**
//   · 甚至还有 `primaryDark` / `backgroundDark` / `surfaceDark` / `onSurfaceDark`
//     四个深色访问器 —— 但**全项目零调用**
//   · `ThemeManager.darkMode` 只被赋值、没人读
//
// **局限**（不查什么）：
//   · **只查结构，不查观感**：色板有没有切 Dark、RootView 有没有同步、Light/Dark 键成不成对 ——
//     但**查不到"切了之后好不好看"**（对比度够不够、某处硬编码在深色下看不看得清）。
//   · **32 处硬编码 `.white`/`.black` 没有被任何检查守着** —— 它们逐个人工看过（都是深色胶囊上的白字），
//     但将来新增一处"深色背景上的黑字"，本检查看不见。
//   · **只认 `ZLPalette.color(_:_:)` 这一个收口点**。如果有人绕过它直接读 `ZLPalette.raw[...]`，
//     深色不生效，而本检查照样报 ✓。
//   · 系统外观同步只查 `RootView` 有没有那两行 —— **查不到它是否被上游的 `preferredColorScheme` 钉死**
//     （第 85 轮就是这么被一行 `.preferredColorScheme(.light)` 抵消掉的，功能全废检查全绿）。
// 结果：用户开深色模式，界面颜色一点不变（只有系统控件变了）。
//
// 修法（一处改动覆盖全部）：`ZLPalette.color` 内部在 darkMode 时把 `...Light` 换成 `...Dark`，
// 找不到对应 Dark 键就退回 Light。再用 RootView 把系统 colorScheme 同步给 ThemeManager。
//
// 本检查保证：
//   1. `ZLPalette.color` 仍然是"会切 Dark 的那一版"（别被人改回去）
//   2. RootView 里有把 colorScheme 同步进 ThemeManager 的代码
//   3. 色板里 Light / Dark 两组键必须成对存在（少一组就会有角色永远取不到深色）

const fs = require('fs');
const path = require('path');
const { SRC } = require('./_paths');
const read = f => fs.readFileSync(path.join(SRC, f), 'utf8');

const problems = [];

// ---- 1. 色板必须真的会切 Dark ----
const palette = read('ColorThemes.swift');
// 判据盯"实现要点"：①识别 ...Light 后缀 ②去掉后缀拼出 ...Dark ③取之前确认该键存在
const switchesToDark = /hasSuffix\("Light"\)/.test(palette)
  && /dropLast\(/.test(palette)
  && /\+\s*"Dark"/.test(palette)
  && /raw\[darkKey\]/.test(palette);
if (!switchesToDark) {
  problems.push('ColorThemes.swift 的 ZLPalette.color 不再把 Light 换成 Dark（深色模式会重新变成死开关）');
}
if (!/ThemeManager\.shared\.darkMode/.test(palette)) {
  problems.push('ColorThemes.swift 取色时没有读 ThemeManager.shared.darkMode');
}

// ---- 2. RootView 要把系统外观同步进去 ----
const app = read('ZL2App.swift');
if (!/colorScheme/.test(app) || !/themeManager\.darkMode\s*=/.test(app)) {
  problems.push('ZL2App.swift 里没有把系统 colorScheme 同步给 themeManager.darkMode（深色模式不会跟随系统）');
}

// ---- 3. Light / Dark 键必须成对 ----
const light = new Set([...palette.matchAll(/"([a-zA-Z]+)Light"\s*:/g)].map(m => m[1]));
const dark = new Set([...palette.matchAll(/"([a-zA-Z]+)Dark"\s*:/g)].map(m => m[1]));
const onlyLight = [...light].filter(k => !dark.has(k));
const onlyDark = [...dark].filter(k => !light.has(k));
if (onlyLight.length) problems.push(`这些角色只有 Light 没有 Dark：${onlyLight.join(', ')}`);
if (onlyDark.length) problems.push(`这些角色只有 Dark 没有 Light：${onlyDark.join(', ')}`);
if (light.size === 0) problems.push('没解析到任何 Light 组（正则或结构变了？）');

console.log(`色板角色：Light ${light.size} 组 / Dark ${dark.size} 组`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 深色模式链路是通的（色板会切 Dark + 跟随系统 + 两组键齐全）');
  process.exit(0);
}

console.log('⚠ 深色模式有问题：');
for (const p of problems) console.log(`  · ${p}`);
console.log('');
console.log('修法见本脚本顶部注释。核心是：ZLPalette.color 里按 darkMode 换键，RootView 里同步系统外观。');
process.exit(1);
