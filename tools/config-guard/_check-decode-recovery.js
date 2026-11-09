// 解码失败必须备份原始数据
//
// 起因：ios-zl2 第81轮查持久化向后兼容时发现，4 处「读用户数据」都是这个形状：
//     guard let data = UserDefaults.standard.data(forKey: key),
//           let arr = try? JSONDecoder().decode([T].self, from: data) else { return [] }
// 解码失败就当"没有数据"，随后用户只要改一次东西，save() 就把**原来那份解不开的数据**
// 覆盖掉了 —— 永久丢失，而且没有任何提示。
//
// 触发它不需要用户做错什么：新版本给 Account / ServerCodable / ControlAppearance
// 加一个非可选字段、改一次 CodingKeys，老数据就解不开了。用户看到的是
// 「账号全没了」「服务器列表空了」「我调的布局变回默认了」。
//
// 现在这 4 处都调 `ZLRecovery.preserveRawData(_:for:)`：失败先备份原始字节，
// 再走"当作没有数据"的分支。诊断页会列出备份，用户/开发者能找到数据。
//
// 本检查：读用户数据的这几个文件里，只要用 `try? ... decode(` 就必须出现 ZLRecovery。

const fs = require('fs');
const path = require('path');
const { SRC } = require('./_paths');
// 持久化用户数据、且用 try? 解码的文件（新加这类文件时往这里加）
const WATCH = [
  'AccountService.swift',      // 账号
  'ServerListScreen.swift',    // 服务器列表
  'ControlEditor.swift',       // 控制布局外观
  'ControlManageScreen.swift', // 布局清单
];

// 允许不备份的解码：解不开也无所谓的小东西
const ALLOW = [
  { file: 'ControlLayoutModel.swift', why: '解码单个 UInt64，失败给 0 是安全默认' },
  { file: 'MojangAPI.swift',          why: '解 JSON 字段的两种形态，不是持久化数据' },
  { file: 'ResourceManagerScreen.swift', why: '读的是游戏自己生成的 pack.mcmeta（只读，不覆盖）' },
  { file: 'ZLLayerSwitcher.swift',    why: '清单文件只读使用，丢失可由导出重新生成' },
];

const problems = [];

// 只看代码，不看注释 —— 这个助手文件的**注释里**就写着 `try? JSONDecoder().decode(...)`，
// 不剥掉注释会把自己报成问题（第81轮实测踩到）。
const stripComments = src => src
  .split('\n')
  .filter(l => { const s = l.trim(); return !s.startsWith('//') && !s.startsWith('*') && !s.startsWith('/*'); })
  .join('\n');

// 1. 被监视的文件必须 import/使用 ZLRecovery
for (const f of WATCH) {
  const text = stripComments(fs.readFileSync(path.join(SRC, f), 'utf8'));
  const hasDecode = /try\?\s+[\w.()]*decode\(/.test(text);
  if (!hasDecode) continue;                        // 没解码就不用管
  if (!text.includes('ZLRecovery.preserveRawData')) {
    problems.push({ file: f, why: '有 try? 解码却没有 ZLRecovery.preserveRawData（失败会静默丢数据）' });
  }
}

// 2. 反过来：全仓扫一遍，凡是 try? 解码 UserDefaults 数据却没备份的，提示一下
const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
for (const f of files) {
  if (WATCH.includes(f)) continue;
  if (ALLOW.some(a => a.file === f)) continue;
  const text = stripComments(fs.readFileSync(path.join(SRC, f), 'utf8'));
  // 只看「从 UserDefaults 拿 data 再解码」这种形态
  if (/UserDefaults\.standard\.data\(forKey:/.test(text) && /try\?\s+[\w.()]*decode\(/.test(text)) {
    if (!text.includes('ZLRecovery.preserveRawData')) {
      problems.push({ file: f, why: '从 UserDefaults 取 data 后 try? 解码，但没备份' });
    }
  }
}

console.log(`检查 ${WATCH.length} 个持久化文件 + 全仓兜底`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 解码失败的路径都会先备份原始数据');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处解不出也不备份（会静默丢数据）：`);
for (const p of problems) console.log(`  ${p.file}  —— ${p.why}`);
console.log('');
console.log('修法：解码失败分支调 ZLRecovery.preserveRawData(data, for: key)；');
console.log('      确实无所谓的（只读文件等）加进本脚本的 ALLOW 并写理由。');
process.exit(1);
