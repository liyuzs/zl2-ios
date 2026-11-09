// 控制布局格式契约测试
//
// 跨界面的东西最容易出「一边改了另一边没改」的静默错误：
// 导出器（Swift）写一份 JSON，核心（ObjC）按自己的规则解析。
// 两边的约定没有任何编译期检查，写错就是「进游戏按钮不对/摇杆没了/直接崩」。
//
// 这个脚本把两边的约定抽出来对撞：
//   A. 核心源码里：当前格式版本号是多少、认哪些顶层列表、版本号不匹配会怎样
//   B. 导出器源码里：实际写了哪个版本号、写了哪些顶层列表

const fs = require('fs');

const CORE_UTILS = 'D:\\ios-zl2\\core\\customcontrols\\CustomControlsUtils.m';
const EXPORT_SWIFT = 'D:\\ios-zl2\\src\\CoreLayoutExport.swift';

const core = fs.readFileSync(CORE_UTILS, 'utf8');
const swift = fs.readFileSync(EXPORT_SWIFT, 'utf8');

let pass = 0, fail = 0;
function check(label, ok, detail) {
  if (ok) { pass++; console.log(`  ✓ ${label}`); }
  else { fail++; console.log(`  ✗ ${label}${detail ? ' —— ' + detail : ''}`); }
}

console.log('=== A. 从核心源码读出约定 ===');

// A1. convertLayoutIfNecessary 里 case 8 → break，说明 8 是当前版本
const switchBlock = core.match(/BOOL convertLayoutIfNecessary[\s\S]*?\n\}/);
const hasCase8Break = switchBlock && /case 8:\s*\n\s*break;/.test(switchBlock[0]);
check('convertLayoutIfNecessary 里 case 8 直接 break（8 是当前格式）', hasCase8Break);

// A2. 核心自己生成默认布局时用的版本号
const genBlock = core.match(/void generateAndSaveDefaultControl\(\)[\s\S]*?\n\}/);
const genVersion = genBlock && genBlock[0].match(/dict\[@"version"\] = @\((\d+)\)/);
check('核心生成默认布局用的版本是 8',
      genVersion && genVersion[1] === '8',
      genVersion ? `实际 ${genVersion[1]}` : '没找到');

// A3. 核心认哪些顶层列表
const expectedLists = ['mControlDataList', 'mJoystickDataList', 'mDrawerDataList'];
console.log('  核心读取的顶层列表：');
expectedLists.forEach(k => {
  const used = core.includes(`@"${k}"`) || core.includes(`@"${k}"`);
  console.log(`    ${k}  ${used ? '✓ 核心在用' : '✗ 核心没用'}`);
});

// A4. 迁移链的现实：v1 会走到 convertV1Layout
const v1Exists = /void convertV1Layout/.test(core);
const v1CallsAddObjectNil = /\[keycodes addObject:btnDict\[@"keycode"\]\]/.test(core);
check('v1 迁移函数存在（写错版本号会触发它）', v1Exists);
check('v1 迁移里有 addObject:btnDict[keycode]（缺 keycode 会崩）',
      v1CallsAddObjectNil);

console.log('');
console.log('=== B. 从导出器源码读出实际行为 ===');

// B1. 导出器写的版本号
const emittedVersion = swift.match(/"version":\s*(\d+)/);
check('导出器写的 version 是 8',
      emittedVersion && emittedVersion[1] === '8',
      emittedVersion ? `实际 ${emittedVersion[1]}` : '没找到');

// B2. 三个列表都必须写出去
expectedLists.forEach(k => {
  const written = new RegExp(`"${k}":`).test(swift);
  check(`导出器写出 ${k}`, written);
});

// B3. 摇杆不能被塞进普通按钮列表
const joystickGoesToButtons = /buttons\.append\(convertJoystick/.test(swift);
const joystickGoesToJoysticks = /joysticks\.append\(convertJoystick/.test(swift);
check('摇杆追加到 joysticks 而不是 buttons', joystickGoesToJoysticks);
check('摇杆没有被误加到 buttons', !joystickGoesToButtons);

// B4. 不能残留 v1 才需要的字段名（keycode 单数 / transparency）
check('导出器没有写单数 keycode 键',
      !/[^s]"keycode":/.test(swift.replace(/"keycodes"/g, '')));
check('导出器没有写 transparency 键', !/"transparency":/.test(swift));

console.log('');
console.log('=== C. 契约一致性 ===');
check('版本号一致（核心 8 == 导出器 8）',
      genVersion && emittedVersion && genVersion[1] === emittedVersion[1]);

console.log('');
console.log(`结果：通过 ${pass}，失败 ${fail}`);
process.exit(fail === 0 ? 0 : 1);
