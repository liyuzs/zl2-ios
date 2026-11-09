// 启动前预检的契约测试
//
// 起因：写 ZLPreflight 时我把「当前控制布局」从 UserDefaults 读了：
//     UserDefaults.standard.string(forKey: "control.default_ctrl") ?? "default"
// 而它实际存在**核心的 plist** 里（setPrefObject），值还自带 .json 后缀。
// 后果是预检永远只查 controlmap/default.json —— 用户换了布局就误报「不存在」，
// 而误报比不报更糟：会让人去重装一个其实没问题的版本。
//
// 这个脚本锁住两条约定：
//   1. 布局名必须来自 CoreLayoutExporter.coreActiveLayoutName（它从核心偏好读，带兜底）
//   2. 检查 client jar 时必须考虑 inheritsFrom（加载器版本没有自己的 jar）
// 另外把「结论三态」的判定逻辑镜像跑一遍。

const PATHS = require('./_paths');
const fs = require('fs');
const path = require('path');

const SRC = path.join(PATHS.SRC, "ZLPreflight.swift");
const text = fs.readFileSync(SRC, 'utf8');

let pass = 0;
let fail = 0;
function ok(name) { pass++; console.log(`  ✓ ${name}`); }
function bad(name, why) { fail++; console.log(`  ✗ ${name}\n      ${why}`); }
function must(cond, name, why) { cond ? ok(name) : bad(name, why); }

console.log('=== 1. 控制布局名的来源 ===');
must(text.includes('CoreLayoutExporter.coreActiveLayoutName'),
     '用 coreActiveLayoutName 取当前布局',
     '应从核心偏好读（getPrefObject），而不是 UserDefaults');
must(!/UserDefaults[^\n]*control\.default_ctrl/.test(text),
     '没有从 UserDefaults 读 control.default_ctrl',
     '这个键存在核心 plist 里，UserDefaults 那份永远拿不到，会静默变成默认值');

console.log('\n=== 2. client jar 要考虑 inheritsFrom ===');
must(text.includes('inheritsFrom'),
     '检查了 inheritsFrom',
     '加载器版本（Fabric/Quilt）自己没有 jar，要用父版本的');

console.log('\n=== 3. Java 大版本要走统一判定 ===');
must(text.includes('CoreBridge.requiredJavaVersion'),
     '用 requiredJavaVersion 判定，而不是自己猜',
     '版本→Java 的映射有 1.20.5 分界等细节，重复实现必错');
must(text.includes('CoreBridge.hasRuntime'),
     '用 hasRuntime 判断运行时在不在',
     '应复用已有实现');

console.log('\n=== 4. 结论三态（镜像 ZLPreflight.summary）===');
function summary(items) {
  const fails = items.filter(i => i.level === 'fail').length;
  const warns = items.filter(i => i.level === 'warn').length;
  if (fails > 0) return 'fail';
  if (warns > 0) return 'warn';
  return 'ok';
}
const cases = [
  { name: '全 ok → ok', items: [{ level: 'ok' }, { level: 'ok' }], want: 'ok' },
  { name: '有 warn → warn', items: [{ level: 'ok' }, { level: 'warn' }], want: 'warn' },
  { name: '有 fail → fail', items: [{ level: 'warn' }, { level: 'fail' }], want: 'fail' },
  { name: 'fail+warn → fail', items: [{ level: 'fail' }, { level: 'warn' }], want: 'fail' },
  { name: '空 → ok（预检不会为空，但逻辑上按全通过）', items: [], want: 'ok' },
];
for (const c of cases) {
  const got = summary(c.items);
  got === c.want ? ok(c.name) : bad(c.name, `期望 ${c.want}，实际 ${got}`);
}

console.log('\n=== 5. 只提示不阻止（不能出现"禁用启动"的判定）===');
must(!/canLaunch|shouldBlockLaunch/.test(text),
     '预检没有阻止启动的返回值',
     '误判成「不能启动」会让用户永远试不了，比让他多试一次更糟');

console.log('');
console.log(`结果：通过 ${pass}，失败 ${fail}`);
process.exit(fail === 0 ? 0 : 1);
