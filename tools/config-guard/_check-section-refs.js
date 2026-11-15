// "第N节"引用必须带标题（第233轮）
//
// 起因：第231轮发现 `从这里开始.md` 第二句就写着「下面**第五节**有表」，
// 而**第四节**才是文件表 —— 编号会随插入/删除而漂，而**没人会去数**。
// 第232轮把交付包的 6 处引用都补上了标题（「第四节「这个文件夹里每个文件是什么」」）。
// 这个检查守的就是"别退回去"。
//
// 判据：交付包里面向读者的文档中，每个 `第N节` 出现处的**附近**必须有 `「`。
//   · 只扫"引用"（`## 六、已知问题` 这种节标题定义不含 `第N节`，天然不匹配）
//   · `CHANGELOG.md` / `README.md` 不在范围 —— 那里的"第五节"是在叙述历史，不是指路
//
// **局限**（不查什么）：
//   · **只判"旁边有没有 `「`"，不判"那个标题是不是对的那一节"** —— 写成「第五节「已知问题」」
//     （编号错、标题对）它能过；写成「第五节「两个提醒」」而实际是第四节，它也能过。
//     **真正的对错要靠人核**（第231轮就是人工核出来的）。
//   · **只扫 `DELIVERY` 里这几个文件名**。新增文档要记得加进 `DOCS`。
//   · **`「` 出现在 ±30 字符内就算过** —— 所以一句话里有两个引用时会互相"借用"标题。
const fs = require('fs');
const path = require('path');

const DELIVERY = 'D:\\ZL2-iOS交付包';

// **交付包目录不存在时整条跳过**（CI / 只检出源码的环境）。
// 这几条检查的对象是"交付包里那 13 个文件"，没有交付包的机器上它们无从下手 ——
// 报失败或崩溃都是错的（第 257 轮 CI 因为这条挂了整步静态检查）。
if (!fs.existsSync(DELIVERY)) {
  console.log('· 交付包目录不存在（' + DELIVERY + '），跳过 —— 这条检查只在有交付包的机器上有意义');
  process.exit(0);
}

const DOCS = ['从这里开始.md', '交接文档-当前.md', '项目状态-当前.md', '给朋友的安装指南.md', '真机验证清单-给朋友.md'];

const RE = /第[一二三四五六七八九十零]+(?:点[一二三四五六七八九])?节/g;
const problems = [];
let checked = 0;

for (const name of DOCS) {
  const p = path.join(DELIVERY, name);
  let text;
  try { text = fs.readFileSync(p, 'utf8'); } catch { problems.push({ doc: name, why: '（读不到）' }); continue; }

  let m;
  while ((m = RE.exec(text)) !== null) {
    checked++;
    const from = Math.max(0, m.index - 30);
    const to = Math.min(text.length, m.index + m[0].length + 30);
    const around = text.slice(from, to);
    if (!around.includes('「')) {
      const line = text.slice(0, m.index).split('\n').length;
      problems.push({ doc: name, line, snippet: text.slice(m.index, m.index + 40).split('\n')[0] });
    }
  }
}

console.log(`扫了 ${DOCS.length} 份交付文档：找到 ${checked} 处"第N节"引用`);
console.log(`没带标题的：${problems.length} 处\n`);

if (checked === 0) {
  console.log('⚠ 一处都没找到 —— 要么文档里没有这类引用，要么判据失效了（检查文件名是否改了）');
  process.exit(1);
}

if (problems.length === 0) {
  console.log('✓ 每处"第N节"引用旁边都带着标题（编号漂了也能靠标题找到）');
  process.exit(0);
}

console.log('⚠ 这些引用只有编号、没有标题（插一节就会指错，而没人会去数）：');
for (const p of problems) {
  console.log(`  ${p.doc}${p.line ? ' L' + p.line : ''}  ${p.snippet || p.why}`);
}
console.log('');
console.log('修法：写成「第N节「那一节的实际标题」」—— 编号留给快速导航，标题留给"错了也能找到"。');
process.exit(1);
