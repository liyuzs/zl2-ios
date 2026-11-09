// MOTD 解析契约（镜像 MinecraftPing.flattenChat）
//
// 起因：服务器状态里的 `description` 有三种形态：
//   ① 纯字符串                        "A Minecraft Server"
//   ② 富文本对象                      {"text": "A Minecraft Server"}
//   ③ 富文本对象 + extra 数组         {"text": "", "extra": [{"text":"A "},{"text":"B","color":"gold"}]}
// 原来只取 `desc["text"]`，形态 ③ 会得到空字符串 ——
// 服务器列表里那一行 MOTD 就是空白，看起来像"服务器没返回信息"。
//
// 这个脚本镜像 flattenChat 的逻辑，验证三种形态都能拿到文本。

function flattenChat(any) {
  if (typeof any === 'string') return any;
  if (Array.isArray(any)) return any.map(flattenChat).join('');
  if (any && typeof any === 'object') {
    let out = typeof any.text === 'string' ? any.text : '';
    if (any.extra !== undefined) out += flattenChat(any.extra);
    return out;
  }
  return '';
}

let pass = 0, fail = 0;
function eq(name, got, want) {
  if (got === want) { pass++; console.log(`  ✓ ${name}  → "${got}"`); }
  else { fail++; console.log(`  ✗ ${name}\n      期望 "${want}"，实际 "${got}"`); }
}

console.log('=== 三种形态 ===');
eq('① 纯字符串', flattenChat('A Minecraft Server'), 'A Minecraft Server');
eq('② text 对象', flattenChat({ text: 'A Minecraft Server' }), 'A Minecraft Server');
eq('③ text + extra', flattenChat({
  text: '',
  extra: [{ text: 'A ' }, { text: 'B', color: 'gold' }],
}), 'A B');

console.log('\n=== 边界 ===');
eq('extra 里再套 extra', flattenChat({
  text: 'x',
  extra: { text: 'y', extra: [{ text: 'z' }] },
}), 'xyz');
eq('顶层是数组', flattenChat([{ text: 'a' }, 'b', { text: 'c' }]), 'abc');
eq('null', flattenChat(null), '');
eq('数字（异常输入）', flattenChat(42), '');
eq('空对象', flattenChat({}), '');
eq('只有 text 没有 extra', flattenChat({ text: 'only' }), 'only');
eq('extra 是空数组', flattenChat({ text: 'tail', extra: [] }), 'tail');

console.log('\n=== 现实里的常见形态（服务器带颜色分段）===');
eq('真实样例', flattenChat({
  text: '',
  extra: [
    { text: '[', color: 'gray' },
    { text: '1.20', color: 'green' },
    { text: '] ', color: 'gray' },
    { text: 'Welcome!', color: 'yellow' },
  ],
}), '[1.20] Welcome!');

console.log('');
console.log(`结果：通过 ${pass}，失败 ${fail}`);
process.exit(fail === 0 ? 0 : 1);
