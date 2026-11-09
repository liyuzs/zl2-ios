// 微软设备码登录的轮询契约
//
// 起因：MicrosoftAuth.pollToken 原先把 `slow_down` 和 `authorization_pending`
// 写成同一个分支（都只是 continue），间隔是常量。而 RFC 8628 规定：
// 服务端返回 `slow_down` 时，客户端**必须把轮询间隔增加 5 秒**。
// 不增加的话服务端会持续要求放慢，直到 deadline 耗尽才报 "expired" ——
// 用户明明在手机上点完了授权，登录却失败，而且看不出原因。
//
// 这类"两个语义不同的分支写成一样"的 bug 很难靠读代码发现（两行长得一样），
// 但改回去也只需要一次手滑。所以锁住：
//   1. slow_down 分支必须提高间隔（出现 `+= 5` 之类的递增）
//   2. 轮询间隔必须是可变变量，不能是常量表达式
//   3. 轮询必须有 deadline（不能无限循环）
//   4. 未知错误要有日志，不能纯 continue

const fs = require('fs');

const SRC = 'D:\\ios-zl2\\src\\MicrosoftAuth.swift';
const text = fs.readFileSync(SRC, 'utf8');

let pass = 0;
let fail = 0;
function must(cond, name, why) {
  if (cond) { pass++; console.log(`  ✓ ${name}`); }
  else { fail++; console.log(`  ✗ ${name}\n      ${why}`); }
}

// 取 pollToken 函数体（从 func pollToken 到下一个 "    }" 前的 MARK）
const start = text.indexOf('func pollToken');
if (start < 0) {
  console.log('✗ 找不到 pollToken —— 函数可能被改名了');
  process.exit(1);
}
const nextMarker = text.indexOf('// MARK:', start);
const body = text.slice(start, nextMarker > 0 ? nextMarker : text.length);

console.log('=== 1. slow_down 必须提高轮询间隔 ===');
const slowDownIdx = body.indexOf('"slow_down"');
must(slowDownIdx >= 0, '存在 slow_down 分支', 'RFC 8628 明确列了这个错误码');
if (slowDownIdx >= 0) {
  // 取该 case 到下一个 case 之间的代码
  const caseStart = body.lastIndexOf('case "slow_down"', slowDownIdx);
  const nextCase = body.indexOf('case "', slowDownIdx + 12);
  const caseBody = body.slice(caseStart, nextCase > 0 ? nextCase : caseStart + 400);
  must(/\+=/.test(caseBody), 'slow_down 分支里有递增（如 pollInterval += 5）',
       '只 continue 不增加间隔，服务端会一直要求放慢，最后误报过期');
}

console.log('\n=== 2. 轮询间隔是可变变量 ===');
must(/var\s+pollInterval/.test(body), 'pollInterval 用 var 声明',
     '用 let 或常量就没有办法在 slow_down 时提高');
must(/Task\.sleep[^\n]*pollInterval/.test(body), 'sleep 用的是 pollInterval 而不是常量',
     'sleep 里写死 max(info.interval, 3) 等于永远不会放慢');

console.log('\n=== 3. 有 deadline，不会无限轮询 ===');
must(/deadline/.test(body), '存在 deadline', '没有超时就会一直转圈');
must(/while\s+Date\(\)\s*<\s*deadline/.test(body), '循环受 deadline 约束',
     '循环条件必须检查 deadline');

console.log('\n=== 4. 未知错误要留痕 ===');
must(/default:[\s\S]{0,200}NSLog/.test(body), 'default 分支里有 NSLog',
     '未知错误纯 continue 的话，现场只剩"转很久然后说过期"，无法排查');

console.log('');
console.log(`结果：通过 ${pass}，失败 ${fail}`);
process.exit(fail === 0 ? 0 : 1);
