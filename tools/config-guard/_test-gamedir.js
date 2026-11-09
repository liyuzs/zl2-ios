// 游戏目录对齐测试
//
// 我们装的版本在：<Documents>/instances/<实例名>/.minecraft/versions/<id>/
// 核心算的游戏目录：<AME_HOME>/instances/<general.game_directory>/<profile.gameDir>
//                  经 stringByStandardizingPath 处理
//
// 两个路径不一致时，表现是「版本明明装好了，启动却说找不到」。
// 这个脚本把两边的公式都复刻出来，断言结果相同。

const path = require('path');

const DOCS = '/var/mobile/Containers/Data/Application/APP/Documents';

// 我们的路径（Swift: VersionRepository.mcRoot）
function ourGameDir(instanceName) {
  return `${DOCS}/instances/${instanceName}/.minecraft`;
}

// 核心的路径（ObjC: JavaLauncher.m:179-182 + stringByStandardizingPath）
// [NSString stringWithFormat:@"%s/instances/%@/%@", AME_HOME, general.game_directory, profileGameDir]
// .stringByStandardizingPath
function coreGameDir(ameHome, generalGameDirectory, profileGameDir) {
  const raw = `${ameHome}/instances/${generalGameDirectory}/${profileGameDir}`;
  // 模拟 stringByStandardizingPath：合并多余的 /，去掉 "." 组件，处理 ".."
  const parts = raw.split('/');
  const out = [];
  for (const p of parts) {
    if (p === '' && out.length > 0) continue;   // 合并连续的 /
    if (p === '.') continue;                     // 去掉 . 组件
    if (p === '..') { out.pop(); continue; }
    out.push(p);
  }
  let s = out.join('/');
  if (!s.startsWith('/')) s = '/' + s;
  return s;
}

// Swift 侧 applyUserSettings 的写法
function swiftSettingOf(instanceName) {
  return `${instanceName}/.minecraft`;
}

let pass = 0, fail = 0;
function eq(label, a, b) {
  if (a === b) { pass++; console.log(`  ✓ ${label}`); }
  else { fail++; console.log(`  ✗ ${label}\n      我们: ${a}\n      核心: ${b}`); }
}

console.log('=== 修复后：两者必须相等 ===');
['default', '我的世界', 'test-1'].forEach(inst => {
  const ours = ourGameDir(inst);
  const core = coreGameDir(DOCS, swiftSettingOf(inst), '.');   // profile gameDir 默认 "."
  eq(`实例 "${inst}"`, ours, core);
});

console.log('');
console.log('=== 回归对比：修复前不相等 ===');
{
  const inst = 'default';
  const ours = ourGameDir(inst);
  // 修复前：Swift 从没写过 general.game_directory，核心用硬编码默认 "default"
  const coreBefore = coreGameDir(DOCS, 'default', '.');
  if (ours !== coreBefore) {
    pass++;
    console.log(`  ✓ 确认修复前不一致`);
    console.log(`      我们: ${ours}`);
    console.log(`      核心: ${coreBefore}`);
  } else {
    fail++;
    console.log(`  ✗ 修复前竟然一致，说明根因判断有误`);
  }
}

console.log('');
console.log('=== 极端情况：实例名带空格 / 中文 ===');
['我的 世界', 'a b'].forEach(inst => {
  const ours = ourGameDir(inst);
  const core = coreGameDir(DOCS, swiftSettingOf(inst), '.');
  eq(`实例 "${inst}"`, ours, core);
});

console.log('');
console.log(`结果：通过 ${pass}，失败 ${fail}`);
process.exit(fail === 0 ? 0 : 1);
