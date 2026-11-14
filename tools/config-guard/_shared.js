// 跨检查共享的常量（不新建脚本的地方来这里拿，别各写一份）
//
// **为什么有这个文件**：第 213 和 224 轮各踩了同一个坑 ——
//   · `_check-check-metadata` 认 **6 种**"局限段"写法
//   · 我临时写的审计脚本只认 **2 种**（`**局限**` / `局限：`）
//   → 拿到 6 个假阳性 / 2 个假阴性，还差点以为"检查坏了"。
//
// 根因不是我不会写正则，是**同一件事的写法清单散在各处**。
// 所以把它抽到这里：任何要判"有没有局限段"的脚本，`require('./_shared')` 即可。
//
// **加新写法时改这里一处**，所有用它的脚本自动跟上。

/** 判定"检查有没有写局限段"的 6 种写法 */
// **和 `_check-check-metadata` 第136轮的原判据逐字一致** —— 这次只抽位置，不改语义。
// （第136轮踩过"判据用裸 /局限/ 被探针文案命中"，所以裸词也保留：收紧要另开一轮做注入验证。）
const LIMIT_MARKERS = /\*\*局限\*\*|局限：|查不到什么|不覆盖|失效条件|只认哪些/;

/** 局限段"够不够具体"的信号词（第224轮试跑用过，暂未做成检查） */
const LIMIT_SPECIFIC = /`|\d|第\s*\d+\s*轮|不查|只认|查不到|判不了|看不见|误报|漏|白名单|ALLOW|前提/;


/**
 * 读 `SettingsScreen.swift` 的四个置灰集合（platformOnly / notWired / renderOnly / launcherLook）。
 *
 * **为什么抽出来**：`_gen-settings-audit.js`（生成文档）和 `_check-settings-audit.js`（校验文档）
 * 各写了一份 `extractSet(name)`，函数体逐字等价 —— 第 225 轮那条"同一个东西写过两次就该抽"。
 *
 * **已知限制**：只匹配纯字母的键名（`/"([a-zA-Z]+)"/`）。将来出现含数字或下划线的设置键
 * （比如 `gl4esRenderer`、`menu_ball_pos`）会被静默漏掉 —— 要改就得两边一起改，这正是抽取的意义。
 */
function readSettingsSets(settingsScreenPath) {
  const fs = require('fs');
  const src = fs.readFileSync(settingsScreenPath, 'utf8');
  const SETS = ['platformOnly', 'notWired', 'renderOnly', 'launcherLook'];
  const out = {};
  for (const name of SETS) {
    const start = src.indexOf('static let ' + name);
    if (start < 0) { out[name] = []; continue; }
    const end = src.indexOf(']', start);
    out[name] = [...src.slice(start, end).matchAll(/"([a-zA-Z]+)"/g)].map(m => m[1]);
  }
  return out;
}

module.exports = { LIMIT_MARKERS, LIMIT_SPECIFIC, readSettingsSets };
